<#
.SYNOPSIS
    Organizes files and directories by moving them into folders named after their initial character.

.DESCRIPTION
    This script creates directories for each uppercase letter (A-Z) and moves items that start with 
those letters into the corresponding directory. Items that do not start with an uppercase letter 
are moved into a directory named "0-9".

.NOTES
    Author: Ris Adams
    Date: 2024-07-02
    Version: 1.0

.EXAMPLE
    To run this script, simply execute it in a PowerShell environment:
    .\ToggleNumLockLoop.ps1
#>

# Initialize an empty list to store directory names
$list = @()

# Loop through ASCII values for uppercase letters A to Z (65 to 90)
65..90 | ForEach-Object {
  # Convert ASCII value to corresponding character
  $letter = [char]$_
  New-Item -Path .\ -Name $letter -ItemType "directory"
  $list += $letter
}

# Function to get the sorting letter for a file
function Get-SortingLetter {
  param (
    [string]$name
  )
  
  if ($name -like "the *") {
    $name = $name -replace "^the\s+", ""
  }
  return [char]::ToUpper($name[0])
}

# Get all items in the current directory
$items = Get-ChildItem -Path .\

# Loop through each item
foreach ($item in $items) {
  # Skip directories created earlier
  if ($list -contains $item.Name) {
    continue
  }

  # Get the sorting letter for the item
  $sortLetter = Get-SortingLetter -name $item.Name

  # If the sorting letter is not a letter, move it to the "0-9" directory
  if ($sortLetter -match "[A-Z]") {
    # Create the directory if it doesn't exist
    if (-not (Test-Path -Path .\$sortLetter)) {
      New-Item -Path .\ -Name $sortLetter -ItemType "directory"
    }
    move-item $item.FullName .\$sortLetter
  } else {
    # Create the "0-9" directory if it doesn't exist
    if (-not (Test-Path -Path .\0-9)) {
      New-Item -Path .\ -Name "0-9" -ItemType "directory"
    }
    move-item $item.FullName .\0-9
  }
}