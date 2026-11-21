# Registers the bopomofo OAuth callback URL protocol for the current user so
# browser-based Google sign-in can hand the redirect back to the app
# (io.github.williamli0623.bopomofo://login-callback). Run once after
# unpacking the Windows zip, from the folder that contains bopomofo.exe:
#
#   powershell -ExecutionPolicy Bypass -File .\register_windows_protocol.ps1
#
[CmdletBinding()]
param(
  # Defaults to bopomofo.exe next to this script.
  [string]$ExecutablePath = (Join-Path $PSScriptRoot 'bopomofo.exe')
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $ExecutablePath)) {
  throw "bopomofo.exe not found at $ExecutablePath. Pass -ExecutablePath to point at the unpacked app."
}

$scheme = 'io.github.williamli0623.bopomofo'
$key = "HKCU:\Software\Classes\$scheme"
$command = New-Item -Path "$key\shell\open\command" -Force
$resolved = (Resolve-Path -LiteralPath $ExecutablePath).Path

New-Item -Path $key -Force | Out-Null
Set-ItemProperty -Path $key -Name '(Default)' -Value 'URL:Bopomofo'
Set-ItemProperty -Path $key -Name 'URL Protocol' -Value ''
Set-ItemProperty -Path "$key\shell\open\command" -Name '(Default)' -Value ('"{0}" "%1"' -f $resolved)

Write-Host "Registered $scheme:// callback to: $resolved"
Write-Host 'Google sign-in in the app now returns through the browser. To undo, delete the registry key:'
Write-Host "  Remove-Item -Recurse $key"
