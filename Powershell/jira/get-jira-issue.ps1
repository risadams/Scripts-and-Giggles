<#
.SYNOPSIS
Fetches details of a specified JIRA issue.

.DESCRIPTION
This script retrieves details of a JIRA issue by making an HTTP GET request to the JIRA API. 
It requires an issue key and optionally enables debug mode to output additional debugging information.

.PARAMETER JiraApiTokenPath
Specifies the filename containing the JIRA API Token. SEE: Update-Jira-Token for details.

.PARAMETER IssueKey
Specifies the key of the JIRA issue to retrieve details for.

.PARAMETER Debug
Enables debug mode which outputs additional debugging information. This is an optional switch.

.EXAMPLE
.\Get-Jira-Issue.ps1 -IssueKey "ABC-123"

.EXAMPLE
.\Get-Jira-Issue.ps1 -IssueKey "ABC-123" -Debug

.NOTES
This script assumes that the user has a valid JIRA API token and the JIRA instance URL is correctly specified.
#>

param(
  [string]$IssueKey,
  [string]$JiraApiTokenPath = ".\jira_token.txt",
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

# Construct the full API URL
$ApiUrl = "${JiraBaseUrl}/${ApiEndpoint}/${IssueKey}"

Write-Debug $headers.Authorization
Write-Debug $ApiUrl

# Send the HTTP GET request to the JIRA API
try {
  $response = Invoke-RestMethod -Uri $ApiUrl -Method Get -Headers $headers
  Write-Output $response | ConvertTo-Json
}
catch {
  # Handle any errors that occur
  Write-Host "An error occurred:" -ForegroundColor Red
  Write-Host $_.Exception.Message -ForegroundColor Red
  if ($_.Exception.Response) {
    $streamReader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
    $responseBody = $streamReader.ReadToEnd()
    Write-Debug "Response Body:" -ForegroundColor Yellow
    Write-Debug $responseBody -ForegroundColor Yellow
  }
}
