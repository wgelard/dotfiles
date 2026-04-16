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
    [pscustomobject]@{ Name = ".gitconfig";       Target = Join-Path $HOME ".gitconfig" }
    [pscustomobject]@{ Name = ".gitattributes";   Target = Join-Path $HOME ".gitattributes" }
    [pscustomobject]@{ Name = ".bash_profile";    Target = Join-Path $HOME ".bash_profile" }
    [pscustomobject]@{ Name = "profile.ps1";      Target = $PROFILE }
    [pscustomobject]@{ Name = "starship.toml";    Target = Join-Path $HOME ".config\starship.toml" }
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
