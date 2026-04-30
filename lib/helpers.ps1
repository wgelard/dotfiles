#Requires -Version 5.1
# Shared helper functions for dotfiles scripts.
# Dot-source this from other scripts: . "$PSScriptRoot\..\lib\helpers.ps1"
# or: . "$PSScriptRoot\lib\helpers.ps1" (from repo root scripts)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Resolve DotfilesDir — works whether called from root or lib/
# ---------------------------------------------------------------------------
if (-not (Get-Variable DotfilesDir -Scope Script -ErrorAction SilentlyContinue)) {
    if ((Split-Path $PSScriptRoot -Leaf) -eq 'lib') {
        $script:DotfilesDir = Split-Path $PSScriptRoot
    } else {
        $script:DotfilesDir = $PSScriptRoot
    }
}

# ---------------------------------------------------------------------------
# BackupDir — one per session, created on demand
# ---------------------------------------------------------------------------
if (-not (Get-Variable BackupDir -Scope Script -ErrorAction SilentlyContinue)) {
    $script:BackupDir = Join-Path $HOME ".dotfiles-backup\$(Get-Date -Format 'yyyy-MM-dd_HHmmss')"
}

# ---------------------------------------------------------------------------
# Symlink capability check
# ---------------------------------------------------------------------------
function Assert-SymlinkCapability {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
    $devModeKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock"
    $devMode = (Get-ItemProperty $devModeKey -ErrorAction SilentlyContinue)?.AllowDevelopmentWithoutDevLicense -eq 1

    if (-not $isAdmin -and -not $devMode) {
        Write-Error @"
Symlinks require either:
  - Developer Mode (Settings > System > For developers > Developer Mode ON)
  - Running this script as Administrator

Enable Developer Mode and re-run, or right-click PowerShell > 'Run as administrator'.
"@
        exit 1
    }
}

# ---------------------------------------------------------------------------
# PATH refresh
# ---------------------------------------------------------------------------
function Update-SessionPath {
    $env:PATH = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine') + ';' +
                [System.Environment]::GetEnvironmentVariable('PATH', 'User')
}

# ---------------------------------------------------------------------------
# winget install helper
# ---------------------------------------------------------------------------
function Install-WingetPackage {
    param(
        [string]$Id,
        [string]$Name,
        [string]$Scope = 'user'
    )
    $list = winget list --id $Id --exact --accept-source-agreements 2>&1
    if ($list -match [regex]::Escape($Id)) {
        Write-Host "→ $Name already installed, skipping."
        return
    }
    Write-Host "→ Installing $Name..."
    winget install --id $Id --scope $Scope --silent --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -notin @(0, -1978335189)) {
        Write-Warning "winget returned exit code $LASTEXITCODE for $Id"
    }
}

# ---------------------------------------------------------------------------
# winget uninstall helper
# ---------------------------------------------------------------------------
function Uninstall-WingetPackage {
    param(
        [string]$Id,
        [string]$Name,
        [switch]$AllVersions
    )
    $installed = winget list --id $Id --exact --accept-source-agreements 2>&1
    if ($installed -match [regex]::Escape($Id)) {
        Write-Host "→ Uninstalling $Name..."
        if ($AllVersions) {
            winget uninstall --id $Id --all-versions --silent --accept-source-agreements
        } else {
            winget uninstall --id $Id --silent --accept-source-agreements
        }
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  ! Failed to uninstall $Name (likely needs elevation)."
            Write-Host "  Run from an elevated PowerShell:"
            Write-Host "      winget uninstall --id $Id --all-versions"
        }
    } else {
        Write-Host "→ $Name not installed, skipping."
    }
}

# ---------------------------------------------------------------------------
# Symlink helper (with backup)
# ---------------------------------------------------------------------------
function New-DotfilesSymlink {
    param([string]$Target, [string]$Source)

    if (Test-Path $Target) {
        $item = Get-Item $Target -Force
        if ($item.LinkType -eq 'SymbolicLink' -and $item.Target -eq $Source) {
            Write-Host "→ Already linked: $Target"
            return
        }
        New-Item -ItemType Directory -Path $script:BackupDir -Force | Out-Null
        $dest = Join-Path $script:BackupDir (Split-Path $Target -Leaf)
        Copy-Item $Target $dest -Force
        Write-Host "→ Backed up: $Target"
        Write-Host "          → $dest"
        Remove-Item $Target -Force
    }

    New-Item -ItemType SymbolicLink -Path $Target -Target $Source | Out-Null
    Write-Host "→ Linked: $Target"
    Write-Host "       → $Source"
}

# ---------------------------------------------------------------------------
# Tool group definitions
# ---------------------------------------------------------------------------
$script:ProductivityTools = @(
    [pscustomobject]@{ Id = "ajeetdsouza.zoxide";      Name = "zoxide";    Cmd = "zoxide" }
    [pscustomobject]@{ Id = "junegunn.fzf";            Name = "fzf";       Cmd = "fzf" }
    [pscustomobject]@{ Id = "JesseDuffield.lazygit";   Name = "lazygit";   Cmd = "lazygit" }
)

$script:VisualTools = @(
    [pscustomobject]@{ Id = "Starship.Starship";       Name = "starship";  Cmd = "starship" }
    [pscustomobject]@{ Id = "eza-community.eza";       Name = "eza";       Cmd = "eza" }
    [pscustomobject]@{ Id = "sharkdp.bat";             Name = "bat";       Cmd = "bat" }
)

$script:AITools = @(
    [pscustomobject]@{ Id = "GitHub.Copilot";  Name = "Copilot CLI";  Cmd = "copilot" }
    [pscustomobject]@{ Id = "SST.opencode";    Name = "opencode";     Cmd = "opencode" }
)


