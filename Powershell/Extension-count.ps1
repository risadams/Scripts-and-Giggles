<#
.SYNOPSIS
Lists unique file extensions and their count in all folders under the current directory.

.DESCRIPTION
This PowerShell script retrieves all files in the current directory and its subfolders,
counts the occurrences of each unique file extension (case insensitive), and displays the results.

.EXAMPLE
.\ListFileExtensions.ps1
This command runs the script in the current directory and displays the list of unique file extensions and their counts.

.NOTES
Author: Ris Adams
Date: 2024-07-02
Version: 1.0
#>

# Get the current directory path
$currentDirectory = Get-Location

# Initialize a hashtable to store file extensions and their counts
$extensionCount = @{}

# Get all files in the current directory and its subfolders
$files = Get-ChildItem -Path $currentDirectory -Recurse -File

# Loop through each file and count the file extensions
foreach ($file in $files) {
  $extension = $file.Extension.ToLower()
    
  # Exclude files without an extension (e.g., files with no file type)
  if ($extension -ne '') {
    if ($extensionCount.ContainsKey($extension)) {
      $extensionCount[$extension]++
    }
    else {
      $extensionCount[$extension] = 1
    }
  }
}

# Display the results
Write-Host "List of unique file extensions and their counts in all folders under the current directory:"
$extensionCount.GetEnumerator() | ForEach-Object {
  Write-Host "$($_.Key): $($_.Value) file(s)"
}
