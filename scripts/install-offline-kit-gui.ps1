# go-no-telemtry offline kit - Windows setup wizard (WinForms).
#Requires -Version 5.1
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$KitRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$InstallerPs1 = Join-Path $KitRoot "install-offline-kit.ps1"
$GonotBin = Join-Path $env:USERPROFILE ".gonot\bin"

function Get-KitTag {
    $manifest = Join-Path $KitRoot "MANIFEST.json"
    if (Test-Path $manifest) {
        try { return (Get-Content $manifest -Raw | ConvertFrom-Json).tag } catch {}
    }
    return "unknown"
}

function Add-PathForUser([string]$Dir) {
    $current = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($current -and ($current.Split(';') -contains $Dir)) { return }
    $new = if ($current) { "$current;$Dir" } else { $Dir }
    [Environment]::SetEnvironmentVariable("Path", $new, "User")
    $env:Path = "$env:Path;$Dir"
}

function Invoke-InstallerStep([scriptblock]$Block, [System.Windows.Forms.TextBox]$LogBox) {
    $LogBox.AppendText("$(Get-Date -Format 'HH:mm:ss') Starting...`r`n")
    [System.Windows.Forms.Application]::DoEvents()
    try {
        & $Block
        $LogBox.AppendText("$(Get-Date -Format 'HH:mm:ss') Done.`r`n")
        return $true
    }
    catch {
        $LogBox.AppendText("$(Get-Date -Format 'HH:mm:ss') ERROR: $($_.Exception.Message)`r`n")
        return $false
    }
}

$tag = Get-KitTag
$form = New-Object System.Windows.Forms.Form
$form.Text = "go-no-telemtry Setup"
$form.Size = New-Object System.Drawing.Size(520, 480)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

$title = New-Object System.Windows.Forms.Label
$title.Location = New-Object System.Drawing.Point(20, 16)
$title.Size = New-Object System.Drawing.Size(460, 28)
$title.Text = "go-no-telemtry Offline Installer"
$title.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($title)

$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Location = New-Object System.Drawing.Point(20, 48)
$subtitle.Size = New-Object System.Drawing.Size(460, 40)
$subtitle.Text = "Telemetry-free Go toolchain.`r`nKit version: $tag"
$form.Controls.Add($subtitle)

$modeLabel = New-Object System.Windows.Forms.Label
$modeLabel.Location = New-Object System.Drawing.Point(20, 96)
$modeLabel.Size = New-Object System.Drawing.Size(460, 20)
$modeLabel.Text = "Installation mode:"
$form.Controls.Add($modeLabel)

$prebuiltRadio = New-Object System.Windows.Forms.RadioButton
$prebuiltRadio.Location = New-Object System.Drawing.Point(36, 120)
$prebuiltRadio.Size = New-Object System.Drawing.Size(440, 24)
$prebuiltRadio.Text = "Install prebuilt binary (recommended, fast)"
$prebuiltRadio.Checked = $true
$form.Controls.Add($prebuiltRadio)

$buildRadio = New-Object System.Windows.Forms.RadioButton
$buildRadio.Location = New-Object System.Drawing.Point(36, 146)
$buildRadio.Size = New-Object System.Drawing.Size(440, 24)
$buildRadio.Text = "Build from source (offline, 30-90 min)"
$form.Controls.Add($buildRadio)

$nameLabel = New-Object System.Windows.Forms.Label
$nameLabel.Location = New-Object System.Drawing.Point(20, 182)
$nameLabel.Size = New-Object System.Drawing.Size(120, 20)
$nameLabel.Text = "Install name:"
$form.Controls.Add($nameLabel)

$nameBox = New-Object System.Windows.Forms.TextBox
$nameBox.Location = New-Object System.Drawing.Point(140, 180)
$nameBox.Size = New-Object System.Drawing.Size(340, 22)
$nameBox.Text = "prod"
$form.Controls.Add($nameBox)

$verifyCheck = New-Object System.Windows.Forms.CheckBox
$verifyCheck.Location = New-Object System.Drawing.Point(36, 214)
$verifyCheck.Size = New-Object System.Drawing.Size(440, 24)
$verifyCheck.Text = "Verify kit checksums before install"
$verifyCheck.Checked = $true
$form.Controls.Add($verifyCheck)

$pathCheck = New-Object System.Windows.Forms.CheckBox
$pathCheck.Location = New-Object System.Drawing.Point(36, 240)
$pathCheck.Size = New-Object System.Drawing.Size(440, 24)
$pathCheck.Text = "Add %USERPROFILE%\.gonot\bin to user PATH"
$pathCheck.Checked = $true
$form.Controls.Add($pathCheck)

$destLabel = New-Object System.Windows.Forms.Label
$destLabel.Location = New-Object System.Drawing.Point(20, 272)
$destLabel.Size = New-Object System.Drawing.Size(460, 20)
$destLabel.Text = "Install location: $env:USERPROFILE\.gonot\versions\<name>"
$destLabel.ForeColor = [System.Drawing.Color]::Gray
$form.Controls.Add($destLabel)

$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Location = New-Object System.Drawing.Point(20, 300)
$logBox.Size = New-Object System.Drawing.Size(460, 88)
$logBox.Multiline = $true
$logBox.ScrollBars = "Vertical"
$logBox.ReadOnly = $true
$logBox.Font = New-Object System.Drawing.Font("Consolas", 9)
$form.Controls.Add($logBox)

$installBtn = New-Object System.Windows.Forms.Button
$installBtn.Location = New-Object System.Drawing.Point(300, 400)
$installBtn.Size = New-Object System.Drawing.Size(90, 28)
$installBtn.Text = "Install"
$form.Controls.Add($installBtn)

$closeBtn = New-Object System.Windows.Forms.Button
$closeBtn.Location = New-Object System.Drawing.Point(390, 400)
$closeBtn.Size = New-Object System.Drawing.Size(90, 28)
$closeBtn.Text = "Close"
$form.Controls.Add($closeBtn)

$installBtn.Add_Click({
    $installBtn.Enabled = $false
    $name = $nameBox.Text.Trim()
    if (-not $name) { $name = "prod" }

    if ($verifyCheck.Checked) {
        $ok = Invoke-InstallerStep {
            & $InstallerPs1 verify 2>&1 | ForEach-Object { $logBox.AppendText("$_`r`n") }
        } $logBox
        if (-not $ok) {
            [System.Windows.Forms.MessageBox]::Show(
                "Checksum verification failed.", "Install aborted",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
            $installBtn.Enabled = $true
            return
        }
    }

    $cmd = if ($buildRadio.Checked) { "build" } else { "prebuilt" }
    $ok = Invoke-InstallerStep {
        & $InstallerPs1 $cmd $name 2>&1 | ForEach-Object { $logBox.AppendText("$_`r`n") }
    } $logBox

    if ($ok -and $pathCheck.Checked) {
        Add-PathForUser $GonotBin
        $logBox.AppendText("Added $GonotBin to user PATH.`r`n")
    }

    if ($ok) {
        $ver = & (Join-Path $GonotBin "go.exe") version 2>&1
        $logBox.AppendText("$ver`r`n")
        [System.Windows.Forms.MessageBox]::Show(
            "Installation complete.`r`n`r`n$ver`r`n`r`nOpen a new terminal to use go.",
            "go-no-telemtry",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
    }
    else {
        [System.Windows.Forms.MessageBox]::Show(
            "Installation failed. See log for details.", "Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    }
    $installBtn.Enabled = $true
})

$closeBtn.Add_Click({ $form.Close() })

[void]$form.ShowDialog()
