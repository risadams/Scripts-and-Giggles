<#
.SYNOPSIS
    Retrieves all environment variables, sorts them by name, and outputs them as a string.

.DESCRIPTION
    This script uses the Get-ChildItem cmdlet to retrieve all environment variables. 
    It then enumerates the collection, sorts the environment variables by their name property,
    and outputs the sorted list as a string.

.NOTES
    Author: Ris Adams
    Date: 2024-05-28
    Version: 1.0

    .EXAMPLE
    To run this script, simply execute it in a PowerShell environment:
    .\display-env.ps1
#>
(Get-ChildItem env:*).GetEnumerator() | Sort-Object Name | Out-String
