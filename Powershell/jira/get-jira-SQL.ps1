<#
.SYNOPSIS
Fetches details of a specified JIRA issue.

.DESCRIPTION
This script retrieves details of a JIRA issue by making an HTTP GET request to the JIRA API. 
It requires an issue key and optionally enables debug mode to output additional debugging information.

.PARAMETER JiraApiTokenPath
Specifies the filename containing the JIRA API Token. SEE: Update-Jira-Token for details.

.PARAMETER JQL
Specifies the JQL to use for our query

.PARAMETER Debug
Enables debug mode which outputs additional debugging information. This is an optional switch.

.EXAMPLE
.\Get-Jira-JQL.ps1 JQL "project = ABC AND status = 'In Progress'"

.NOTES
This script assumes that the user has a valid JIRA API token and the JIRA instance URL is correctly specified.
#>

param(
  [string]$JQL,
  [string]$JiraApiTokenPath = ".\jira_token.txt",
  [switch]$Debug = $false
)

if ($Debug) {
  $DebugPreference = "Continue"
}

# Define your JIRA instance URL and the API endpoint you want to access
$JiraBaseUrl = "XXXX"
$ApiEndpoint = "rest/api/2/search"

$JiraApiToken = Get-Content -Path $JiraApiTokenPath -Raw
$headers = @{
  Authorization = "Bearer ${JiraApiToken}"
  Accept        = "application/json"
}

# Construct the full API URL
$ApiUrl = "${JiraBaseUrl}/${ApiEndpoint}?jql=$( [uri]::EscapeDataString($JQL) )"

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
