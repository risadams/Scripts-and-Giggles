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

    Author: Ris Adams
    Date: 2024-07-03
    Version: 1.1 -> Abstracted to avoid issues with duplicate files

.EXAMPLE
    To run this script, simply execute it in a PowerShell environment:
    .\Alpha-Sort.ps1
#>

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

# Function to move an item to the appropriate directory
function Move-ItemToDirectory {
  param (
      [string]$itemPath,
      [string]$destinationDirectory
  )

  # Create the destination directory if it does not exist
  if (-not (Test-Path -Path $destinationDirectory)) {
      New-Item -Path $destinationDirectory -ItemType "directory"
  }

  # Define the destination path
  $destinationPath = Join-Path -Path $destinationDirectory -ChildPath (Get-Item $itemPath).Name

  # Move the item if it does not already exist at the destination
  if (-not (Test-Path -Path $destinationPath)) {
      Move-Item -Path $itemPath -Destination $destinationDirectory
  } else {
      Write-Host "Skipping duplicate file: $itemPath"
  }
}

# Get all items in the current directory
$items = Get-ChildItem -Path .\

# Initialize an empty list to store directory names
$list = @()

# Loop through ASCII values for uppercase letters A to Z (65 to 90)
65..90 | ForEach-Object {
  # Convert ASCII value to corresponding character
  $letter = [char]$_
  $list += $letter
}

# Loop through each item
foreach ($item in $items) {
  # Skip directories created earlier
  if ($list -contains $item.Name) {
      continue
  }

  # Get the sorting letter for the item
  $sortLetter = Get-SortingLetter -name $item.Name

  # If the sorting letter is a letter, move it to the corresponding directory
  if ($sortLetter -match "[A-Z]") {
      Move-ItemToDirectory -itemPath $item.FullName -destinationDirectory .\$sortLetter
  } else {
      # Move items that do not start with a letter to the "0-9" directory
      Move-ItemToDirectory -itemPath $item.FullName -destinationDirectory .\0-9
  }
}