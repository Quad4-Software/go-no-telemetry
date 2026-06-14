# Install go-no-telemtry from an extracted offline kit (Windows, air-gapped).
param(
    [Parameter(Position = 0)]
    [string]$Command = "help",
    [Parameter(Position = 1)]
    [string]$Name = "offline"
)

$ErrorActionPreference = "Stop"

$KitRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$GonotRoot = if ($env:GONOT_ROOT) { $env:GONOT_ROOT } else { Join-Path $env:USERPROFILE ".gonot" }
$GonotVersions = Join-Path $GonotRoot "versions"
$GonotBin = Join-Path $GonotRoot "bin"
$GonotCurrent = Join-Path $GonotRoot "current"
$SystemGoDir = if ($env:SYSTEM_GO_DIR) { $env:SYSTEM_GO_DIR } else { "C:\Program Files\go-no-telemtry" }

function Log($msg) { Write-Host "[install-offline-kit] $msg" }

function Get-Platform {
    if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { return "windows-arm64" }
    return "windows-amd64"
}

function Get-ManifestTag {
    $manifest = Join-Path $KitRoot "MANIFEST.json"
    if (-not (Test-Path $manifest)) { return $null }
    $json = Get-Content $manifest -Raw | ConvertFrom-Json
    return $json.tag
}

function Find-ReleaseArchive($Tag, $Platform) {
    $releases = Join-Path $KitRoot "releases"
    foreach ($ext in @(".zip", ".tar.gz")) {
        $path = Join-Path $releases "go-no-telemtry-$Tag.$Platform$ext"
        if (Test-Path $path) { return $path }
    }
    return $null
}

function Find-GoRoot($Dir) {
    $goExe = Get-ChildItem -Path $Dir -Recurse -Filter "go.exe" -ErrorAction SilentlyContinue |
        Where-Object { $_.DirectoryName -match '\\bin$' } |
        Select-Object -First 1
    if ($goExe) { return Split-Path $goExe.DirectoryName -Parent }
    $top = Get-ChildItem -Path $Dir -Directory | Select-Object -First 1
    if ($top -and (Test-Path (Join-Path $top.FullName "bin\go.exe"))) { return $top.FullName }
    return $null
}

function Install-GoRoot($GoRoot, [string]$DestType, [string]$InstallName) {
    if ($DestType -eq "gonot") {
        New-Item -ItemType Directory -Force -Path $GonotVersions, $GonotBin | Out-Null
        $dest = Join-Path $GonotVersions $InstallName
        if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
        Copy-Item -Recurse $GoRoot $dest
        Copy-Item -Force (Join-Path $dest "bin\go.exe") (Join-Path $GonotBin "go.exe")
        if (Test-Path (Join-Path $dest "bin\gofmt.exe")) {
            Copy-Item -Force (Join-Path $dest "bin\gofmt.exe") (Join-Path $GonotBin "gofmt.exe")
        }
        if (Test-Path $GonotCurrent) { Remove-Item -Force $GonotCurrent }
        cmd /c mklink /J "$GonotCurrent" "$dest" | Out-Null
        Log "Installed to $dest"
        & (Join-Path $GonotBin "go.exe") version
        Log "Add to PATH: $GonotBin"
    }
    else {
        Log "Installing system-wide to $SystemGoDir (requires Administrator)"
        if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
                [Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw "Administrator privileges required for system install"
        }
        if (Test-Path $SystemGoDir) { Remove-Item -Recurse -Force $SystemGoDir }
        Copy-Item -Recurse $GoRoot $SystemGoDir
        $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
        if ($machinePath -notlike "*$SystemGoDir\bin*") {
            [Environment]::SetEnvironmentVariable(
                "Path", "$machinePath;$SystemGoDir\bin", "Machine")
        }
        & (Join-Path $SystemGoDir "bin\go.exe") version
    }
}

function Invoke-Verify {
    $sums = Join-Path $KitRoot "SHA256SUMS"
    if (-not (Test-Path $sums)) { throw "SHA256SUMS not found" }
    Get-Content $sums | ForEach-Object {
        if ($_ -match '^([0-9a-fA-F]+)\s+(.+)$') {
            $expected = $Matches[1].ToLower()
            $rel = $Matches[2].TrimStart('./')
            $file = Join-Path $KitRoot ($rel -replace '/', '\')
            if (-not (Test-Path $file)) { throw "Missing file: $rel" }
            $actual = (Get-FileHash -Algorithm SHA256 $file).Hash.ToLower()
            if ($actual -ne $expected) { throw "Checksum mismatch: $rel" }
        }
    }
    Log "Checksums OK"
}

function Invoke-Prebuilt([string]$DestType, [string]$InstallName) {
    $plat = Get-Platform
    $tag = Get-ManifestTag
    if (-not $tag) { throw "Cannot read tag from MANIFEST.json" }
    $archive = Find-ReleaseArchive $tag $plat
    if (-not $archive) {
        throw "No prebuilt release for $plat (tag $tag). Check releases\ folder."
    }
    Log "Installing from $archive"
    $tmp = Join-Path $env:TEMP ("gonot-install-" + [guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Path $tmp | Out-Null
    try {
        if ($archive -like "*.zip") {
            Expand-Archive -Path $archive -DestinationPath $tmp -Force
        }
        else {
            throw "Windows kit expects .zip release archives; found: $archive"
        }
        $goRoot = Find-GoRoot $tmp
        if (-not $goRoot) { throw "Could not find go.exe in archive" }
        Install-GoRoot $goRoot $DestType $InstallName
    }
    finally {
        Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
    }
}

function Invoke-Build([string]$InstallName) {
    $plat = Get-Platform
    $bootstrap = Join-Path $KitRoot "bootstrap-bin\$plat\go"
    $goBootstrap = Join-Path $bootstrap "bin\go.exe"
    if (-not (Test-Path $goBootstrap)) {
        throw "Bundled bootstrap not found at $bootstrap"
    }
    $source = Join-Path $KitRoot "source"
    $srcDir = Join-Path $source "src"
    if (-not (Test-Path (Join-Path $srcDir "make.bat"))) {
        throw "Fork source not found at $source"
    }
    Log "Building from source (bootstrap: $bootstrap)"
    $env:GOROOT_BOOTSTRAP = $bootstrap
    Push-Location $srcDir
    try {
        cmd /c "make.bat"
    }
    finally {
        Pop-Location
    }
    $built = $source
    if (-not (Test-Path (Join-Path $built "bin\go.exe"))) {
        throw "Build failed: bin\go.exe not found"
    }
    & (Join-Path $built "bin\go.exe") version
    $telemetry = & (Join-Path $built "bin\go.exe") telemetry 2>&1
    if ($telemetry -ne "off") { throw "Telemetry is not disabled: $telemetry" }
    Install-GoRoot $built "gonot" $InstallName
}

function Show-Help {
    @"
Usage: install-offline-kit.ps1 <command> [name]

Commands:
  verify              Verify kit checksums
  prebuilt [name]     Install matching prebuilt release to %USERPROFILE%\.gonot
  prebuilt-system     Install matching prebuilt release to Program Files
  build [name]        Build from source using bundled bootstrap (offline)
  help                Show this help

Environment:
  GONOT_ROOT          Version manager root (default: %USERPROFILE%\.gonot)
  SYSTEM_GO_DIR       System install path (default: C:\Program Files\go-no-telemtry)
"@
}

switch ($Command.ToLower()) {
    "verify" { Invoke-Verify }
    "prebuilt" { Invoke-Prebuilt "gonot" $Name }
    "prebuilt-system" { Invoke-Prebuilt "system" $Name }
    "build" { Invoke-Build $Name }
    "help" { Show-Help }
    default { Show-Help; exit 1 }
}
