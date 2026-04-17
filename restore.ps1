#Requires -Version 5.1
<#
.SYNOPSIS
    Restore dotfiles from a backup created by bootstrap.ps1.
.DESCRIPTION
    Lists timestamped backups in ~/.dotfiles-backup/, restores the latest by default.
    Removes existing symlinks and copies the backed-up files back into place.
.PARAMETER BackupTimestamp
    Optionally specify a backup timestamp folder name (e.g. 2026-04-15_143022).
    Defaults to the most recent backup.
#>

param(
    [string]$BackupTimestamp
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$BackupRoot = Join-Path $HOME ".dotfiles-backup"

if (-not (Test-Path $BackupRoot)) {
    Write-Error "No backups found at $BackupRoot — nothing to restore."
    exit 1
}

$backups = Get-ChildItem $BackupRoot -Directory | Sort-Object Name

if ($backups.Count -eq 0) {
    Write-Error "No backup folders found in $BackupRoot."
    exit 1
}

# List available backups
Write-Host "Available backups:"
$backups | ForEach-Object { Write-Host "  $($_.Name)" }
Write-Host ""

# Pick backup to restore from
if ($BackupTimestamp) {
    $chosen = $backups | Where-Object { $_.Name -eq $BackupTimestamp }
    if (-not $chosen) {
        Write-Error "Backup '$BackupTimestamp' not found in $BackupRoot."
        exit 1
    }
} else {
    $chosen = $backups | Select-Object -Last 1
    Write-Host "→ Using latest backup: $($chosen.Name)"
}

$BackupDir = $chosen.FullName

# Files managed by bootstrap
$dotfiles = @(
    [pscustomobject]@{ Name = ".gitconfig";                                    Target = Join-Path $HOME ".gitconfig" }
    [pscustomobject]@{ Name = ".gitattributes";                                Target = Join-Path $HOME ".gitattributes" }
    [pscustomobject]@{ Name = ".bash_profile";                                 Target = Join-Path $HOME ".bash_profile" }
    [pscustomobject]@{ Name = "starship.toml";                                 Target = Join-Path $HOME ".config\starship.toml" }
    # PowerShell stubs — backed up with folder-prefixed names
    [pscustomobject]@{ Name = "PowerShell_Microsoft.PowerShell_profile.ps1";   Target = Join-Path ([Environment]::GetFolderPath('MyDocuments')) "PowerShell\Microsoft.PowerShell_profile.ps1" }
    [pscustomobject]@{ Name = "WindowsPowerShell_Microsoft.PowerShell_profile.ps1"; Target = Join-Path ([Environment]::GetFolderPath('MyDocuments')) "WindowsPowerShell\Microsoft.PowerShell_profile.ps1" }
)

foreach ($df in $dotfiles) {
    $backup = Join-Path $BackupDir $df.Name
    if (-not (Test-Path $backup)) {
        Write-Host "→ No backup for $($df.Name), skipping."
        continue
    }

    # Remove existing symlink or file
    if (Test-Path $df.Target) {
        Remove-Item $df.Target -Force
        Write-Host "→ Removed: $($df.Target)"
    }

    Copy-Item $backup $df.Target
    Write-Host "→ Restored: $($df.Target)"
    Write-Host "        ← $backup"
}

Write-Host ""
Write-Host "Restore complete. Open a new shell session to apply changes."

# ---------------------------------------------------------------------------
# Optional: uninstall visual tools installed by bootstrap
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "Visual tools that may have been installed by bootstrap:"
Write-Host "  starship, eza, bat, FiraCode Nerd Font"
$uninstallVisual = Read-Host "→ Uninstall visual tools and revert terminal fonts? [y/N]"
if ($uninstallVisual -match '^[Yy]') {
    $visualPackages = @(
        [pscustomobject]@{ Id = "Starship.Starship";   Name = "starship" }
        [pscustomobject]@{ Id = "eza-community.eza";   Name = "eza" }
        [pscustomobject]@{ Id = "sharkdp.bat";         Name = "bat" }
    )
    foreach ($pkg in $visualPackages) {
        $installed = winget list --id $pkg.Id --exact --accept-source-agreements 2>&1
        if ($installed -match [regex]::Escape($pkg.Id)) {
            Write-Host "→ Uninstalling $($pkg.Name)..."
            winget uninstall --id $pkg.Id --silent --accept-source-agreements
        } else {
            Write-Host "→ $($pkg.Name) not installed, skipping."
        }
    }

    # Uninstall FiraCode Nerd Font via scoop
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        $scoopList = scoop list 2>$null
        if ($scoopList -match 'FiraCode-NF') {
            Write-Host "→ Uninstalling FiraCode Nerd Font via scoop..."
            scoop uninstall nerd-fonts/FiraCode-NF
        } else {
            Write-Host "→ FiraCode Nerd Font not installed via scoop, skipping."
        }
    }

    # Revert Windows Terminal font
    $wtSettingsPaths = @(
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
        "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
    )
    $wtSettings = $wtSettingsPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($wtSettings) {
        $json = Get-Content $wtSettings -Raw | ConvertFrom-Json
        if ($json.profiles?.defaults?.font?.face -eq 'FiraCode Nerd Font') {
            $json.profiles.defaults.font.PSObject.Properties.Remove('face')
            $json | ConvertTo-Json -Depth 20 | Set-Content $wtSettings -Encoding UTF8
            Write-Host "→ Windows Terminal font reverted to default."
        }
    }

    # Revert VS Code terminal font
    $vsCodeSettingsPaths = @(
        "$env:APPDATA\Code\User\settings.json"
        "$env:APPDATA\Code - Insiders\User\settings.json"
    )
    foreach ($vsCodeSettings in $vsCodeSettingsPaths | Where-Object { Test-Path $_ }) {
        $vsJson = Get-Content $vsCodeSettings -Raw | ConvertFrom-Json
        if ($vsJson.'terminal.integrated.fontFamily' -eq 'FiraCode Nerd Font') {
            $vsJson.PSObject.Properties.Remove('terminal.integrated.fontFamily')
            $vsJson | ConvertTo-Json -Depth 20 | Set-Content $vsCodeSettings -Encoding UTF8
            Write-Host "→ VS Code terminal font reverted to default ($vsCodeSettings)."
        }
    }

    Write-Host "→ Visual cleanup complete. Open a new terminal to confirm."
}
