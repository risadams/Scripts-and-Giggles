<#!
.SYNOPSIS
Converts letters and digits into their NATO phonetic alphabet equivalents.

.DESCRIPTION
Accepts text from the command line or pipeline, splits it into words, and
outputs the matching NATO terms (or the original symbol when no match exists).

.PARAMETER Text
One or more strings to translate. Remaining arguments and pipeline input are
both accepted.

.PARAMETER Normalize
Removes accents/diacritics before lookup so "café" becomes "Cafe" for NATO
mapping.

.EXAMPLE
pwsh Powershell/to-nato.ps1 "Hello World 123"
Hotel Echo Lima Lima Oscar
Whiskey Oscar Romeo Lima Delta
One Two Three

.EXAMPLE
"Weekend Ops" | pwsh Powershell/to-nato.ps1
Whiskey Echo Echo Kilo Echo November Delta
Oscar Papa Sierra

.EXAMPLE
Get-Content words.txt | pwsh Powershell/to-nato.ps1
Reads each line from words.txt and prints the NATO translation.

.EXAMPLE
"café" | pwsh Powershell/to-nato.ps1 -Normalize
Charlie Alfa Foxtrot Echo

.NOTES
    Author: Ris Adams
    Date: 2025-11-12
    Version: 1.1
#>
[CmdletBinding()]
param(
  [Parameter(ValueFromPipeline = $true, ValueFromRemainingArguments = $true)]
  [string[]]$Text,

  [switch]$Normalize = $true
)

begin {
  Set-StrictMode -Version Latest

  function Remove-Diacritics {
    param(
      [string]$Value
    )

    if (-not $Value) {
      return $Value
    }

    $normalized = $Value.Normalize([System.Text.NormalizationForm]::FormD)
    $builder = [System.Text.StringBuilder]::new()

    foreach ($ch in $normalized.ToCharArray()) {
      if ([System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($ch) -ne [System.Globalization.UnicodeCategory]::NonSpacingMark) {
        [void]$builder.Append($ch)
      }
    }

    $builder.ToString().Normalize([System.Text.NormalizationForm]::FormC)
  }

  $dictionary = @{
    'a' = 'Alfa'
    'b' = 'Bravo'
    'c' = 'Charlie'
    'd' = 'Delta'
    'e' = 'Echo'
    'f' = 'Foxtrot'
    'g' = 'Golf'
    'h' = 'Hotel'
    'i' = 'India'
    'j' = 'Juliett'
    'k' = 'Kilo'
    'l' = 'Lima'
    'm' = 'Mike'
    'n' = 'November'
    'o' = 'Oscar'
    'p' = 'Papa'
    'q' = 'Quebec'
    'r' = 'Romeo'
    's' = 'Sierra'
    't' = 'Tango'
    'u' = 'Uniform'
    'v' = 'Victor'
    'w' = 'Whiskey'
    'x' = 'X-ray'
    'y' = 'Yankee'
    'z' = 'Zulu'
    '1' = 'One'
    '2' = 'Two'
    '3' = 'Three'
    '4' = 'Four'
    '5' = 'Five'
    '6' = 'Six'
    '7' = 'Seven'
    '8' = 'Eight'
    '9' = 'Nine'
    '0' = 'Zero'
  }
}

process {
  if (-not $Text) {
    return
  }

  foreach ($item in $Text) {
    if ([string]::IsNullOrWhiteSpace($item)) {
      continue
    }

    foreach ($word in $item -split '\s+' | Where-Object { $_ }) {
      $letters = foreach ($character in $word.ToLowerInvariant().ToCharArray()) {
        $key = [string]$character
        if ($dictionary.ContainsKey($key)) {
          $dictionary[$key]
        }
        else {
          $key
        }
      }

      if ($letters) {
        $letters -join ' ' | Write-Output
      }
    }
  }
}
