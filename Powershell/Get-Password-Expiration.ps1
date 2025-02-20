<#
.SYNOPSIS
    Checks and displays the current user's Active Directory password expiration status.

.DESCRIPTION
    This script retrieves the current user's Active Directory account information,
    calculates when their password will expire based on domain policy, and displays
    the remaining time until expiration with appropriate warnings.

    The script performs the following:
    - Retrieves current user's AD account using ADSI search
    - Calculates password expiration based on domain password policy
    - Displays password last set date, expiration date, and time remaining
    - Provides warning if password expires within 7 days

.NOTES
    File Name      : Get-ADPasswordExpiration.ps1
    Author         : Ris Adams
    Prerequisite   : PowerShell 5.1 or later
    Version        : 1.0

    Required Permissions:
    - Active Directory domain membership
    - User account with basic read access to AD
    - PowerShell execution policy that allows script execution

.EXAMPLE
    .\Get-ADPasswordExpiration.ps1
    Displays password expiration information for the current user.

.OUTPUTS
    Displays formatted text output with:
    - Last password change date
    - Password expiration date
    - Time remaining until expiration
    - Warning if password expires within 7 days
#>

[CmdletBinding()]
param()

function Write-ColorMessage {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Message,

    [Parameter(Mandatory = $false)]
    [System.ConsoleColor]$ForegroundColor = 'White'
  )

  Write-Host $Message -ForegroundColor $ForegroundColor
}

function Get-PasswordExpirationInfo {
  [CmdletBinding()]
  param()

  try {
    # Verify domain connectivity
    if (-not (Test-ComputerSecureChannel)) {
      throw "Computer is not connected to the domain"
    }

    # Get current user's AD account information
    $adsiSearcher = [ADSISEARCHER]"(&(objectCategory=User)(samAccountName=$env:USERNAME))"
    $user = $adsiSearcher.FindOne()

    if ($null -eq $user) {
      throw "Unable to find AD user account for $env:USERNAME"
    }

    # Convert pwdLastSet from FileTime to DateTime
    $pwdLastSet = [datetime]::FromFileTime($user.Properties.pwdlastset[0])

    # Get domain password policy
    $domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
    $root = $domain.GetDirectoryEntry()

    # Convert maxPwdAge from COM object and calculate expiration
    $maxPwdAgeValue = $root.ConvertLargeIntegerToInt64($root.Properties["maxPwdAge"].Value)
    $maxPwdAge = [TimeSpan]::FromTicks([math]::Abs($maxPwdAgeValue))
    $expirationDate = $pwdLastSet.Add($maxPwdAge)
    $timeRemaining = $expirationDate - (Get-Date)

    # Return results object
    return @{
      PwdLastSet     = $pwdLastSet
      ExpirationDate = $expirationDate
      TimeRemaining  = $timeRemaining
    }
  }
  catch {
    throw "Failed to retrieve password expiration info: $($_.Exception.Message)"
  }
}

# Main script execution
try {
  Write-ColorMessage "Checking password expiration status..." -ForegroundColor Cyan

  $pwdInfo = Get-PasswordExpirationInfo

  # Display results
  Write-ColorMessage "`nPassword Information:" -ForegroundColor Cyan
  Write-ColorMessage "Last password change: $($pwdInfo.PwdLastSet.ToString('g'))"
  Write-ColorMessage "Password expires on: $($pwdInfo.ExpirationDate.ToString('g'))"

  Write-ColorMessage "`nTime remaining until password expiration:" -ForegroundColor Cyan
  Write-ColorMessage "$($pwdInfo.TimeRemaining.Days) days, $($pwdInfo.TimeRemaining.Hours) hours, $($pwdInfo.TimeRemaining.Minutes) minutes" -ForegroundColor Yellow

  # Warning for imminent expiration
  if ($pwdInfo.TimeRemaining.Days -lt 7) {
    Write-ColorMessage "`nWARNING: Password will expire in less than 7 days!" -ForegroundColor Red
  }
}
catch {
  Write-ColorMessage "`nError: $($_.Exception.Message)" -ForegroundColor Red
  Write-ColorMessage "Script execution failed. Ensure you are connected to the domain and have appropriate permissions." -ForegroundColor Red
  exit 1
}
