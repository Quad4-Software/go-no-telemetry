# Build a Windows Setup.exe from an extracted offline kit using Inno Setup.
param(
    [Parameter(Mandatory = $true)]
    [string]$KitDir,
    [string]$Tag = "",
    [string]$OutputDir = ""
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Iss = Join-Path $Root "scripts\installer\go-no-telemtry.iss"

if (-not (Test-Path $KitDir)) { throw "Kit directory not found: $KitDir" }
if (-not (Test-Path (Join-Path $KitDir "install-offline-kit.ps1"))) {
    throw "Not a valid offline kit: missing install-offline-kit.ps1"
}

if (-not $Tag) {
    $manifest = Join-Path $KitDir "MANIFEST.json"
    if (Test-Path $manifest) {
        $Tag = (Get-Content $manifest -Raw | ConvertFrom-Json).tag
    }
    if (-not $Tag) { $Tag = "dev" }
}

$Iscc = @(
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $Iscc) {
    throw @"
Inno Setup 6 not found. Install from https://jrsoftware.org/isinfo.php
Then re-run:
  .\scripts\build-windows-installer.ps1 -KitDir '$KitDir'
"@
}

if (-not $OutputDir) { $OutputDir = $Root }

$staging = Join-Path $env:TEMP "go-no-telemtry-iss-staging"
if (Test-Path $staging) { Remove-Item -Recurse -Force $staging }
New-Item -ItemType Directory -Path $staging | Out-Null
Copy-Item -Path (Join-Path $KitDir "*") -Destination $staging -Recurse -Force

Write-Host "Building Setup.exe for tag $Tag ..."
& $Iscc "/DKitDir=$staging" "/DKitTag=$Tag" "/O$OutputDir" $Iss

Remove-Item -Recurse -Force $staging
Write-Host "Done. Output in: $OutputDir"
