param(
  [string[]]$IssueKeys,
  [string]$JiraApiTokenPath = ".\jira_token.txt",
  [string]$Export,
  [switch]$Debug = $false
)

if ($Debug) {
  $DebugPreference = "Continue"
}

# Define your JIRA instance URL and the API endpoint you want to access
$JiraBaseUrl = "XXXX"
$ApiEndpoint = "rest/agile/1.0/issue"

$JiraApiToken = Get-Content -Path $JiraApiTokenPath -Raw
$headers = @{
  Authorization = "Bearer ${JiraApiToken}"
  Accept        = "application/json"
}

# Function to format TimeSpan into a human-readable string
function Format-TimeSpan {
  param([TimeSpan]$TimeSpan)
  $components = @()
  if ($TimeSpan.Days -ne 0) { $components += "$($TimeSpan.Days) day(s)" }
  if ($TimeSpan.Hours -ne 0) { $components += "$($TimeSpan.Hours) hour(s)" }
  if ($TimeSpan.Minutes -ne 0) { $components += "$($TimeSpan.Minutes) minute(s)" }
  if ($TimeSpan.Seconds -ne 0 -and $TimeSpan.TotalDays -lt 1) { $components += "$($TimeSpan.Seconds) second(s)" }
  if ($components.Count -eq 0) { $components = "0 seconds" }
  else { $components = $components -join ", " }
  return $components
}

# Initialize a collection to hold all status changes
$allStatusChanges = @()

# Loop through each IssueKey
foreach ($IssueKey in $IssueKeys) {

  Write-Debug "Processing Issue: $IssueKey"

  # Construct the full API URL, including the changelog
  $ApiUrl = "${JiraBaseUrl}/${ApiEndpoint}/${IssueKey}?expand=changelog"

  Write-Debug $headers.Authorization
  Write-Debug $ApiUrl

  # Send the HTTP GET request to the JIRA API
  try {
    $response = Invoke-RestMethod -Uri $ApiUrl -Method Get -Headers $headers

    # Initialize variables
    $issueKey = $IssueKey
    $issueCreatedDate = [DateTime]$response.fields.created
    $events = @()

    # Process the response to extract status and sprint changes
    $changelog = $response.changelog

    # Handle pagination if changelog is large
    $maxResults = 1000  # Adjust as needed
    $startAt = 0
    $changelogEntries = @()

    do {
      $changelogUrl = "${JiraBaseUrl}/rest/api/2/issue/${IssueKey}?expand=changelog&startAt=${startAt}&maxResults=${maxResults}"
      $changelogResponse = Invoke-RestMethod -Uri $changelogUrl -Method Get -Headers $headers
      $changelogEntries += $changelogResponse.changelog.histories
      $startAt += $maxResults
      $totalEntries = $changelogResponse.changelog.total
    } while ($changelogEntries.Count -lt $totalEntries)

    # Combine initial event with changelog events
    # Add initial status and sprint events based on the earliest changes
    $initialStatus = $null
    $initialSprint = $null
    $initialAssignee = $null

    # Find initial status, sprint, and assignee from changelog
    foreach ($history in $changelogEntries | Sort-Object { [DateTime]$_.created }) {
      $created = [DateTime]$history.created
      $author = $history.author.displayName
      foreach ($item in $history.items) {
        if ($item.field -eq 'status') {
          $event = [PSCustomObject]@{
            DateTime   = $created
            Author     = $author
            EventType  = 'StatusChange'
            FromStatus = $item.fromString
            ToStatus   = $item.toString
          }
          $events += $event
        }
        elseif ($item.field -eq 'Sprint') {
          $event = [PSCustomObject]@{
            DateTime   = $created
            Author     = $author
            EventType  = 'SprintChange'
            FromSprint = $item.fromString
            ToSprint   = $item.toString
          }
          $events += $event
        }
        elseif ($item.field -eq 'assignee') {
          $event = [PSCustomObject]@{
            DateTime     = $created
            Author       = $author
            EventType    = 'AssigneeChange'
            FromAssignee = $item.fromString
            ToAssignee   = $item.toString
          }
          $events += $event
        }
      }
    }

    # If no initial status change is found in the changelog, assume initial status from issue creation
    if (-not ($events | Where-Object { $_.EventType -eq 'StatusChange' })) {
      # Assume the initial status is the issue's original status (often "To Do")
      $initialStatus = $response.fields.status.name
      $initialStatusEvent = [PSCustomObject]@{
        DateTime   = $issueCreatedDate
        Author     = $response.fields.reporter.displayName
        EventType  = 'StatusChange'
        FromStatus = $null
        ToStatus   = $initialStatus
      }
      $events += $initialStatusEvent
    }

    # If no sprint changes are found, check if the issue was ever assigned to a sprint
    $sprintField = 'customfield_10007'  # Replace with your actual custom field ID for sprint
    $sprints = $response.fields.$sprintField
    if ($sprints) {
      # Parse sprint information from the custom field
      $sprintNames = @()
      foreach ($sprint in $sprints) {
        if ($sprint -match 'name=(.+?),') {
          $sprintName = $Matches[1]
          $sprintNames += $sprintName
        }
      }
      if ($sprintNames.Count -gt 0) {
        # Add an initial sprint event
        $initialSprintEvent = [PSCustomObject]@{
          DateTime   = $issueCreatedDate
          Author     = $response.fields.reporter.displayName
          EventType  = 'SprintChange'
          FromSprint = $null
          ToSprint   = $sprintNames[0]
        }
        $events += $initialSprintEvent
      }
    }

    # Sort the events by DateTime
    $events = $events | Sort-Object DateTime

    # Initialize variables for processing events
    $currentSprint = $null
    $statusChanges = @()

    # Process events to track sprint assignments and status changes
    foreach ($event in $events) {
      if ($event.EventType -eq 'SprintChange') {
        # Update the current sprint
        $currentSprint = $event.ToSprint
      }
      elseif ($event.EventType -eq 'StatusChange') {
        # Record the status change along with the current sprint
        $statusChange = [PSCustomObject]@{
          IssueKey   = $issueKey
          SprintName = $currentSprint
          DateTime   = $event.DateTime
          Author     = $event.Author
          FromStatus = $event.FromStatus
          ToStatus   = $event.ToStatus
        }
        $statusChanges += $statusChange
      }
    }

    # Sort the status changes by DateTime
    $statusChanges = $statusChanges | Sort-Object DateTime

    # Calculate the time spent in each status
    for ($i = 0; $i -lt $statusChanges.Count; $i++) {
      $currentChange = $statusChanges[$i]
      if ($i -lt $statusChanges.Count - 1) {
        $nextChange = $statusChanges[$i + 1]
        $timeInStatus = $nextChange.DateTime - $currentChange.DateTime
      }
      else {
        # For the last status, calculate time until now or until resolution date
        if ($response.fields.resolutiondate) {
          $endTime = [DateTime]$response.fields.resolutiondate
        }
        else {
          $endTime = Get-Date
        }
        $timeInStatus = $endTime - $currentChange.DateTime
      }
      # Store the raw TimeInStatus
      $currentChange | Add-Member -NotePropertyName TimeInStatusRaw -NotePropertyValue $timeInStatus
      # Format the TimeInStatus to be more human-readable
      $formattedTimeInStatus = Format-TimeSpan -TimeSpan $timeInStatus
      $currentChange | Add-Member -NotePropertyName TimeInStatus -NotePropertyValue $formattedTimeInStatus
    }

    # Add the status changes for this issue to the collection of all status changes
    $allStatusChanges += $statusChanges

  }
  catch {
    # Handle any errors that occur
    Write-Host "An error occurred while processing issue ${IssueKey}:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    if ($_.Exception.Response) {
      $streamReader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
      $responseBody = $streamReader.ReadToEnd()
      Write-Debug "Response Body:"
      Write-Debug $responseBody
    }
  }
}

# Output the combined report
$finalReport = $allStatusChanges | Select-Object IssueKey, SprintName, DateTime, Author, FromStatus, ToStatus, TimeInStatusRaw, TimeInStatus | Sort-Object IssueKey, DateTime

$finalReport | Format-Table -AutoSize

# Export the report to CSV if the -Export parameter is provided
if ($Export) {
  try {
    $finalReport | Export-Csv -Path $Export -NoTypeInformation
    Write-Host "Report exported to $Export" -ForegroundColor Green
  }
  catch {
    Write-Host "An error occurred while exporting the report:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
  }
}
