<#
.SYNOPSIS
    This script toggles the NUMLOCK key on and off every 60 seconds indefinitely.

.DESCRIPTION
    The script continuously runs in an infinite loop where it attempts to toggle the NUMLOCK key on and off.
    If an error occurs, the script catches the exception, logs the error message, and sleeps for 15 seconds before retrying.

.NOTES
    Author: Ris Adams
    Date: 2024-05-28
    Version: 1.0

.EXAMPLE
    To run this script, simply execute it in a PowerShell environment:
    .\ToggleNumLockLoop.ps1
#>

# Infinite loop to continuously toggle NUMLOCK key every 60 seconds
while ($true) {
  try {
    # Send NUMLOCK key press twice to toggle it on and off
    $wshell = New-Object -ComObject wscript.shell
    $wshell.sendkeys("{NUMLOCK}{NUMLOCK}")
    Start-Sleep -Seconds 60
  }
  catch {
    # If an error occurs, log the error message with the current date and time
    Write-Error "$(Get-Date) - $_.Exception.Message"
    Start-Sleep -Seconds 15
  }
}
