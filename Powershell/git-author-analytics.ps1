<#
.SYNOPSIS
    Retrieves all git commits from the current branch, processes them, and exports the data to a CSV file.

.DESCRIPTION
    This script retrieves all commits from all time on the 'baseline' branch using git log.
    It splits the log into an array of commits, creates custom objects for each commit, 
    and exports the list of commits to a specified CSV file.

.NOTES
    Author: Ris Adams
    Date: 2024-05-28
    Version: 1.0

.EXAMPLE
    To run this script, simply execute it in a PowerShell environment:
    .\git-author-analytics.ps1 -outputPath C:\temp\filename.csv
#>

Param(
  [Parameter(Mandatory = $true)]
  [string]$outputPath
)

# Get all commits from all time on the branch
$commitLog = git log --all --format="%ad,%an" --date=iso

# Split the log into an array of commits
$commits = $commitLog -split "`n"

# Create a list to hold custom objects for each commit
$commitList = New-Object System.Collections.Generic.List[Object]

foreach ($commit in $commits) {
  if ($commit -ne "") {
    $details = $commit -split ","
    $date = $details[0]
    $author = $details[1]

    # Create a custom object
    $obj = New-Object PSObject -Property @{
      Date   = $date
      Author = $author
      Count  = 1
    }

    # Add the custom object to the list
    $commitList.Add($obj)
  }
}

# Export the list to a CSV file
$commitList | Export-Csv -Path $outputPath -NoTypeInformation
