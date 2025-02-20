<#
.SYNOPSIS
    Reports on Confluence page changes over a specified time period.

.DESCRIPTION
    This script queries the Confluence API to identify pages that have been added or modified
    within a specified number of days. It supports multiple output formats and provides
    clickable links in console output for easy navigation to modified pages.

.PARAMETER ConfluenceUrl
    The base URL of your Confluence instance.

.PARAMETER ConfluenceApiTokenPath
    Path to a file containing the Confluence API token.

.PARAMETER DaysBack
    Number of days to look back for changes. Default is 7.

.PARAMETER SpaceKey
    The Confluence space key to filter results. Default is 'PP'.

.PARAMETER OutputFormat
    The desired output format. Valid values are 'CSV', 'JSON', or 'Console'. Default is 'Console'.

.PARAMETER OutputPath
    Path where the output file should be saved when using CSV or JSON format.
    Default is "./confluence_changes.[json|csv]"

.EXAMPLE
    .\Report-ConfluenceChanges.ps1
    Returns changes from the last 7 days in console output format.

.EXAMPLE
    .\Report-ConfluenceChanges.ps1 -DaysBack 14 -OutputFormat CSV
    Returns changes from the last 14 days in CSV format.

.EXAMPLE
    .\Report-ConfluenceChanges.ps1 -SpaceKey "TECH" -OutputFormat JSON
    Returns changes from the TECH space in JSON format.

.NOTES
    File Name      : Report-ConfluenceChanges.ps1
    Author         : Ris Adams
    Prerequisite   : PowerShell 5.1 or later
    Version        : 1.0
    Created        : 2025-01-15
    Last Modified  : 2025-01-15

    Changelog:
    1.0 - Initial release
    - Basic functionality to report on page changes
    - Support for CSV, JSON, and Console output
    - Clickable links in console output
    - Title truncation for readability
#>

[CmdletBinding()]
param (
    [string]$ConfluenceUrl = 'XXXX',
    [string]$ConfluenceApiTokenPath = ".\confluence_token.txt",
    [int]$DaysBack = 7,
    [string]$SpaceKey = 'XXXX',
    [Parameter(Mandatory = $false)]
    [ValidateSet('CSV', 'JSON', 'Console')]
    [string]$OutputFormat = 'Console',
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = ".\confluence_changes.$(if ($OutputFormat -eq 'JSON') { 'json' } else { 'csv' })"
)

<#
.SYNOPSIS
    Creates an authentication header using the API token.

.DESCRIPTION
    Reads the API token from the specified file and creates an authentication header
    for use with the Confluence API.

.RETURNS
    Hashtable containing the Authorization and Content-Type headers.
#>
function Get-AuthHeader {
    $ApiToken = (Get-Content -Path $ConfluenceApiTokenPath -Raw).Trim()
    return @{
        Authorization  = "Bearer ${ApiToken}"
        'Content-Type' = 'application/json'
    }
}

<#
.SYNOPSIS
    Creates a clickable link for console output.

.DESCRIPTION
    Generates an ANSI escape sequence that creates a clickable link in compatible
    terminal emulators (like Windows Terminal).

.PARAMETER Text
    The text to display for the link.

.PARAMETER Url
    The URL to navigate to when the link is clicked.

.RETURNS
    String containing the ANSI escape sequence for the clickable link.
#>
function Get-ClickableLink {
    param (
        [string]$Text,
        [string]$Url
    )
    return "$([char]0x1b)]8;;$Url$([char]0x1b)\$Text$([char]0x1b)]8;;$([char]0x1b)\"
}

<#
.SYNOPSIS
    Truncates text to a specified length and adds an ellipsis.

.DESCRIPTION
    If the input text is longer than the specified maximum length,
    truncates it and adds an ellipsis (...) to indicate truncation.

.PARAMETER Text
    The text to truncate.

.PARAMETER MaxLength
    The maximum length of the text before truncation. Default is 50.

.RETURNS
    The truncated text string with ellipsis if necessary.
#>
function Get-TruncatedText {
    param (
        [string]$Text,
        [int]$MaxLength = 50
    )

    if ($Text.Length -gt $MaxLength) {
        return $Text.Substring(0, $MaxLength - 3) + "..."
    }
    return $Text
}

<#
.SYNOPSIS
    Handles paginated API calls to Confluence.

.DESCRIPTION
    Makes repeated calls to the Confluence API, handling pagination automatically
    and combining results from all pages.

.PARAMETER Endpoint
    The API endpoint URL to call.

.PARAMETER Headers
    The headers to use for the API call.

.PARAMETER Method
    The HTTP method to use. Default is 'Get'.

.RETURNS
    Array of results from all API calls combined.
#>
function Invoke-ConfluenceApi {
    param (
        [string]$Endpoint,
        [hashtable]$Headers,
        [string]$Method = 'Get'
    )

    $results = @()
    $start = 0
    $limit = 100

    do {
        $uri = "$Endpoint&start=$start&limit=$limit"
        try {
            Write-Verbose "Calling API: $uri"
            $response = Invoke-RestMethod -Uri $uri -Headers $Headers -Method $Method
            if ($response.results) {
                $results += $response.results
            }
            $start += $limit
        }
        catch {
            Write-Error "API call failed: $_"
            throw
        }
    } while ($response.size -eq $limit)

    return $results
}

<#
.SYNOPSIS
    Determines whether a page was added or modified.

.DESCRIPTION
    Analyzes the page history to determine if it was newly added or modified
    within the specified time period.

.PARAMETER Page
    The page object from the Confluence API.

.RETURNS
    String indicating whether the page was "Added" or "Modified".
#>
function Get-ChangeType {
    param (
        [Parameter(Mandatory = $true)]
        [object]$Page
    )

    if ($Page.version.number -eq 1) {
        return "Added"
    }

    $createdDate = [DateTime]::Parse($Page.history.createdDate)
    $lastModified = [DateTime]::Parse($Page.version.when)
    $fromDate = (Get-Date).AddDays(-$DaysBack)

    if ($createdDate -ge $fromDate) {
        return "Added"
    }
    else {
        return "Modified"
    }
}

# Calculate date range
$fromDate = (Get-Date).AddDays(-$DaysBack).ToString("yyyy-MM-dd")

# Build base API URL with proper CQL query
$baseUrl = $ConfluenceUrl.TrimEnd('/')
$cqlQuery = "lastmodified >= '$fromDate' AND type = 'page'"

if ($SpaceKey) {
    $cqlQuery += " AND space = '$SpaceKey'"
}

$apiUrl = "$baseUrl/rest/api/content/search?cql=$([System.Web.HttpUtility]::UrlEncode($cqlQuery))"
$apiUrl += "&expand=version,history,space,body.view,_links"

# Get auth header
$headers = Get-AuthHeader

# Get changed pages
try {
    Write-Verbose "Using API URL: $apiUrl"
    $changedPages = Invoke-ConfluenceApi -Endpoint $apiUrl -Headers $headers

    if ($null -eq $changedPages) {
        Write-Error "No results returned from API"
        exit 1
    }

    # Process results with change type
    $processedResults = $changedPages | ForEach-Object {
        $changeType = Get-ChangeType -Page $_
        $fullUrl = "$baseUrl/pages/viewpage.action?pageId=$($_.id)"
        $truncatedTitle = Get-TruncatedText -Text $_.title -MaxLength 50

        [PSCustomObject]@{
            ChangeType     = $changeType
            Title          = $_.title            # Keep original title for CSV/JSON
            TruncatedTitle = $truncatedTitle     # For display purposes
            SpaceKey      = $_.space.key
            LastModified   = $_.version.when
            LastModifiedBy = $_.version.by.displayName
            Version       = $_.version.number
            Id            = $_.id
            Type          = $_.type
            Url           = $fullUrl
            ClickableTitle = (Get-ClickableLink -Text $truncatedTitle -Url $fullUrl)
        }
    }

    # Group results by change type
    $groupedResults = $processedResults | Group-Object -Property ChangeType

    # Output results based on format
    switch ($OutputFormat) {
        'CSV' {
            $processedResults | Select-Object -Property * -ExcludeProperty ClickableTitle,TruncatedTitle | 
                Export-Csv -Path $OutputPath -NoTypeInformation
            Write-Host "Results exported to: $OutputPath"
        }
        'JSON' {
            $processedResults | Select-Object -Property * -ExcludeProperty ClickableTitle,TruncatedTitle | 
                ConvertTo-Json | Out-File $OutputPath
            Write-Host "Results exported to: $OutputPath"
        }
        'Console' {
            foreach ($group in $groupedResults) {
                Write-Host "`n$($group.Name) Items ($($group.Count)):" -ForegroundColor Yellow
                $group.Group | Format-Table -AutoSize @(
                    @{
                        Label = 'Title'
                        Expression = { $_.ClickableTitle }
                    },
                    'LastModified',
                    'LastModifiedBy',
                    'Version'
                )
            }
        }
    }

    # Output summary
    Write-Host "`nSummary:" -ForegroundColor Cyan
    $groupedResults | ForEach-Object {
        Write-Host "$($_.Name): $($_.Count) items"
    }
}
catch {
    Write-Error "Script execution failed: $_"
    exit 1
}
