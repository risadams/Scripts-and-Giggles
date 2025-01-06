<#
.SYNOPSIS
    PowerShell-based Time-Based One-Time Password (TOTP) system with secure secret storage.

.DESCRIPTION
    This script includes:
    1. Functions to securely save and retrieve secrets in the Windows Registry.
    2. A function to generate TOTP codes according to RFC 6238.
    3. Supporting functions to handle Hex/Base32 conversions and time calculations.

.NOTES
    Author:      Ris Adams
    Date:        2025-01-06
    Purpose:     Demonstrate secure storage of TOTP secrets and generation of OTPs.
#>

################################################################################
#                          SECRET STORAGE FUNCTIONS                             #
################################################################################

<#
.SYNOPSIS
    Save a secret securely in the Windows Registry under a given name.

.DESCRIPTION
    Uses the Windows Data Protection API (DPAPI) via ConvertTo-SecureString and
    ConvertFrom-SecureString to encrypt the secret. The encrypted secret is stored
    in a registry key under HKEY_CURRENT_USER:\Software\TOTPSecrets.

.PARAMETER Name
    The name (key) used to identify the secret in the registry.

.PARAMETER Secret
    The secret value (e.g., Base32 TOTP key) to be encrypted and stored.

.EXAMPLE
    Save-Secret -Name "MyAppSecret" -Secret "JBSWY3DPEHPK3PXP"
#>
function Save-Secret {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [string]$Name,

    [Parameter(Mandatory = $true)]
    [string]$Secret
  )

  # Define the registry path
  $regPath = "HKCU:\Software\TOTPSecrets"

  # Ensure the registry key exists
  if (-not (Test-Path $regPath)) {
    New-Item -Path $regPath -Force | Out-Null
  }

  try {
    # Convert the secret to a secure string
    $secureSecret = ConvertTo-SecureString $Secret -AsPlainText -Force
    $dpapiString = ConvertFrom-SecureString $secureSecret

    # Save the encrypted secret in the registry
    Set-ItemProperty -Path $regPath -Name $Name -Value $dpapiString

    Write-Host "Secret saved securely under the name '$Name'." -ForegroundColor Green
  }
  catch {
    Write-Host "Failed to save the secret. Error: $_" -ForegroundColor Red
  }
}


<#
.SYNOPSIS
  Retrieve a previously saved secret from the Windows Registry.

.DESCRIPTION
  Reads an encrypted string from the registry and decrypts it using DPAPI.

.PARAMETER Name
  The registry key name where the secret was stored.

.EXAMPLE
  $mySecret = Get-Secret -Name "MyAppSecret"
  Write-Host "Retrieved Secret: $mySecret"
#>
function Get-Secret {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [string]$Name
  )

  # Define the registry path
  $regPath = "HKCU:\Software\TOTPSecrets"

  try {
    if (Test-Path $regPath) {
      # Retrieve the encrypted string from the registry
      $encryptedSecret = (Get-ItemProperty -Path $regPath -Name $Name).$Name
      $secureString = ConvertTo-SecureString $encryptedSecret

      # Convert the SecureString back into plaintext
      $plainText = [System.Net.NetworkCredential]::new("", $secureString).Password
      return $plainText
    }
    else {
      Write-Host "No secret found with the name '$Name'." -ForegroundColor Yellow
    }
  }
  catch {
    Write-Host "Failed to retrieve the secret. Error: $_" -ForegroundColor Red
  }
}

################################################################################
#                             TOTP FUNCTIONS                                   #
################################################################################

<#
.SYNOPSIS
  Retrieve a TOTP code using a secret stored in the Windows Registry.

.DESCRIPTION
  1. Looks up the secret by name using Get-Secret.
  2. Generates the OTP using HMAC-SHA1 hashing and dynamic truncation as per RFC 4226/6238.

.PARAMETER Name
  Name used to retrieve the secret (stored in the registry).

.PARAMETER LENGTH
  Desired length of the OTP, commonly 6.

.PARAMETER WINDOW
  Time interval in seconds (commonly 30 for TOTP).

.EXAMPLE
  $otp = Get-Otp -Name "MyAppSecret" -LENGTH 6 -WINDOW 30
  Write-Host "OTP: $otp"

.EXAMPLE
  $otp = Get-Otp -Name "MyAppSecret"
  Write-Host "OTP: $otp"
#>
function Get-Otp {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true)]
    [string]$Name,

    [Parameter(Mandatory = $false)]
    [int]$LENGTH = 6,

    [Parameter(Mandatory = $false)]
    [int]$WINDOW = 30
  )

  try {
    # Retrieve the secret securely
    $SECRET = Get-Secret -Name $Name

    if (-not $SECRET) {
      throw "No secret found with the name '$Name'."
    }

    # Convert secret to HMAC key
    $hmac = New-Object -TypeName System.Security.Cryptography.HMACSHA1
    $hmac.key = Convert-HexToByteArray(Convert-Base32ToHex($SECRET.ToUpper()))

    # Generate Time Byte Array
    $timeBytes = Get-TimeByteArray $WINDOW

    # Compute Hash
    $randHash = $hmac.ComputeHash($timeBytes)

    # Dynamic Truncation to extract the OTP
    $offset = $randHash[$randHash.Length - 1] -band 0x0f
    $fullOTP = ($randHash[$offset] -band 0x7f) * [math]::Pow(2, 24)
    $fullOTP += ($randHash[$offset + 1] -band 0xff) * [math]::Pow(2, 16)
    $fullOTP += ($randHash[$offset + 2] -band 0xff) * [math]::Pow(2, 8)
    $fullOTP += ($randHash[$offset + 3] -band 0xff)

    # Generate the final OTP
    $modNumber = [math]::Pow(10, $LENGTH)
    $otp = $fullOTP % $modNumber
    $otp = $otp.ToString("0" * $LENGTH)

    return $otp
  }
  catch {
    Write-Host "Failed to generate OTP. Error: $_" -ForegroundColor Red
    return $null
  }
}

<#
.SYNOPSIS
  Get the current time (in seconds) since Unix epoch, divided by the specified WINDOW.

.DESCRIPTION
  Generates a byte array corresponding to the truncated time window.

.PARAMETER WINDOW
  The time interval for the TOTP generation (e.g., 30 seconds).
#>
function Get-TimeByteArray($WINDOW) {
  $span = (New-TimeSpan -Start (Get-Date -Year 1970 -Month 1 -Day 1 -Hour 0 -Minute 0 -Second 0) -End (Get-Date).ToUniversalTime()).TotalSeconds

  $unixTime = [Convert]::ToInt64([Math]::Floor($span / $WINDOW))
  $byteArray = [BitConverter]::GetBytes($unixTime)
  [array]::Reverse($byteArray)  # Convert to Big-Endian
  return $byteArray
}

<#
.SYNOPSIS
  Convert a hexadecimal string into a byte array.

.PARAMETER hexString
  The input string in hexadecimal format.
#>
function Convert-HexToByteArray($hexString) {
  $byteArray = $hexString -replace '^0x', '' -split "(?<=\G\w{2})(?=\w{2})" |
  ForEach-Object { [Convert]::ToByte($_, 16) }
  return $byteArray
}

<#
.SYNOPSIS
  Convert a Base32 string into its hexadecimal equivalent.

.DESCRIPTION
  Follows the logic of mapping each Base32 character into 5 bits, then grouping bits into 4-bit chunks for hex output.

.PARAMETER base32
  The input string in Base32 format.
#>
function Convert-Base32ToHex($base32) {
  $base32chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
  $bits = ""
  $hex = ""

  for ($i = 0; $i -lt $base32.Length; $i++) {
    $val = $base32chars.IndexOf($base32.Chars($i))
    $binary = [Convert]::ToString($val, 2)
    $bits += Add-LeftPad $binary 5 '0'
  }

  for ($j = 0; $j + 4 -le $bits.Length; $j += 4) {
    $chunk = $bits.Substring($j, 4)
    $intChunk = [Convert]::ToInt32($chunk, 2)
    $hexChunk = Convert-IntToHex $intChunk
    $hex += $hexChunk
  }
  return $hex
}

<#
.SYNOPSIS
  Convert an integer to its hexadecimal string representation.

.PARAMETER num
  The integer value to convert.
#>
function Convert-IntToHex([int]$num) {
  return ('{0:x}' -f $num)
}

<#
.SYNOPSIS
  Pad a string on the left with a specified character until it reaches a given length.

.PARAMETER str
  The original string.

.PARAMETER len
  The desired total length.

.PARAMETER pad
  The padding character.
#>
function Add-LeftPad($str, $len, $pad) {
  if (($len + 1) -ge $str.Length) {
    while (($len - 1) -ge $str.Length) {
      $str = $pad + $str
    }
  }
  return $str
}
