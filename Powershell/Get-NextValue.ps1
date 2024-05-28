<#
.SYNOPSIS
    Selects a random name from a given list and removes it from the list.

.DESCRIPTION
    The Get-NextValue function selects a random name from a provided list,
    prints it, and then removes it from the list. If the list is empty, 
    the function simply returns without doing anything.

.PARAMETER Names
    A reference to an array or a collection of names. The function modifies 
    this collection by removing the selected name.

.EXAMPLE
    $devs = [System.Collections.ArrayList]@("Alice", "Bob", "Charlie", "Dana", "Eli")
    Get-NextValue ([ref]$devs)
    This example shows how to use the Get-NextValue function with an ArrayList 
    of names. Each time the function is called, it will print and remove a 
    random name from the list.

.NOTES
    Make sure the provided list (e.g., ArrayList) supports dynamic modifications 
    like adding or removing items. Standard arrays in PowerShell are of fixed size 
    and will not work with this function as is.

.LINK
    Get-Random
#>
function Get-NextValue {
  param (
    [ref]$Names
  )

  $nameList = $Names.Value

  if ($nameList.Count -eq 0) {
    return
  }

  $randomIndex = Get-Random -Minimum 0 -Maximum $nameList.Count
  $selectedName = $nameList[$randomIndex]
  Write-Host $selectedName

  $nameList.RemoveAt($randomIndex)
}
