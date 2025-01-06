Add-Type -AssemblyName System.Speech

$speak = New-Object System.Speech.Synthesis.SpeechSynthesizer

$speak.GetInstalledVoices().VoiceInfo

$speak.SelectVoice('Microsoft Zira Desktop')
$speak.Speak("Hello, World")