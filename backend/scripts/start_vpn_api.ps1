[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$ServerAddress,
  [Parameter(Mandatory = $true)]
  [string]$ClientAddress,
  [ValidateRange(1024, 65535)]
  [int]$Port = 3000,
  [switch]$CheckOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

foreach ($address in @($ServerAddress, $ClientAddress)) {
  $parsedAddress = $null
  if (-not [System.Net.IPAddress]::TryParse($address, [ref]$parsedAddress) -or
      $parsedAddress.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork -or
      [System.Net.IPAddress]::IsLoopback($parsedAddress) -or $address -eq '0.0.0.0') {
    throw 'Provide specific non-loopback IPv4 addresses; do not use a subnet or wildcard.'
  }
}

$localAddresses = @(Get-NetIPAddress -AddressFamily IPv4 | Select-Object -ExpandProperty IPAddress)
if ($ServerAddress -notin $localAddresses) {
  throw 'ServerAddress does not belong to this computer. Run this script inside the school server remote desktop.'
}
$backendPath = Split-Path -Parent $PSScriptRoot
$nodePath = (Get-Command node.exe -ErrorAction Stop).Source
if (-not (Test-Path -LiteralPath (Join-Path $backendPath '.env'))) {
  throw 'Missing backend/.env. Configure the database connection first.'
}
if (-not (Test-Path -LiteralPath (Join-Path $backendPath 'node_modules/express'))) {
  throw 'Backend dependencies are missing. Run npm.cmd ci in backend first.'
}
if (Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue) {
  throw "Port $Port is already in use. Stop the previous API with Ctrl+C before running this script."
}
Write-Host "Server API: http://${ServerAddress}:$Port/api"
Write-Host "Allowed development client: $ClientAddress"
Write-Host 'This is a temporary VPN-only HTTP test. Production requires HTTPS.'
if ($CheckOnly) {
  Write-Host 'Preflight passed. No configuration was changed.'
  return
}

$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  throw 'Run PowerShell as administrator inside the school server.'
}

$ruleName = 'SchoolFoodApp-VpnTest-' + [Guid]::NewGuid().ToString('N')
$ruleCreated = $false
$previousHost = $env:HOST
$previousPort = $env:PORT
$previousAllowedIps = $env:API_ALLOWED_IPS
Push-Location $backendPath
try {
  & $nodePath scripts/check_database.js
  if ($LASTEXITCODE -ne 0) { throw 'Database checks failed. No firewall rule was created.' }

  # Scope both the firewall and the API to the explicitly selected addresses.
  New-NetFirewallRule -Name $ruleName -DisplayName 'School Food App temporary VPN test' `
    -Group 'SchoolFoodApp.VpnTest' -Direction Inbound -Action Allow -Enabled True `
    -Protocol TCP -LocalPort $Port -LocalAddress $ServerAddress -RemoteAddress $ClientAddress `
    -Program $nodePath -Profile Any -EdgeTraversalPolicy Block | Out-Null
  $ruleCreated = $true
  $env:HOST = $ServerAddress
  $env:PORT = [string]$Port
  $env:API_ALLOWED_IPS = "$ClientAddress,$ServerAddress,127.0.0.1,::1"
  Write-Host 'Keep this window open. Press Ctrl+C to stop the API and remove this temporary firewall rule.'
  & $nodePath src/server.js
  if ($LASTEXITCODE -ne 0) { throw 'API stopped with an error. Review the error above.' }
} finally {
  $env:HOST = $previousHost
  $env:PORT = $previousPort
  $env:API_ALLOWED_IPS = $previousAllowedIps
  if ($ruleCreated) {
    Remove-NetFirewallRule -Name $ruleName -ErrorAction Continue
  }
  Pop-Location
}
