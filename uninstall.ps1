#Requires -Version 5.1
<#
.SYNOPSIS
    Uninstall optional tools and/or restore dotfiles from backup.
.DESCRIPTION
    Removes productivity tools, visual tools, or both. Can also restore
    dotfiles from a timestamped backup created by bootstrap.ps1.
    Does NOT remove core tools (git, VS Code, Beyond Compare, difftastic, delta,
    carapace, gh, ripgrep, fd, tldr, mergiraf) — those are considered essential.
.PARAMETER Productivity
    Uninstall productivity tools (zoxide, fzf, lazygit).
.PARAMETER Visual
    Uninstall visual tools (starship, eza, bat) and revert terminal fonts.
.PARAMETER All
    Uninstall both productivity and visual tools, remove symlinks and PS profile stubs,
    then offer to restore from backup.
.PARAMETER Restore
    Restore dotfiles from a backup (latest by default).
.PARAMETER BackupTimestamp
    Specify a backup timestamp to restore from (e.g. 2026-04-15_143022).
    Only used with -Restore or -All.
.EXAMPLE
    .\uninstall.ps1 -Productivity
    .\uninstall.ps1 -Visual
    .\uninstall.ps1 -All
    .\uninstall.ps1 -Restore
    .\uninstall.ps1 -Restore -BackupTimestamp 2026-04-15_143022
    .\uninstall.ps1              # interactive menu
#>

[CmdletBinding()]
param(
    [switch]$Productivity,
    [switch]$Visual,
    [switch]$All,
    [switch]$Restore,
    [string]$BackupTimestamp
)

. "$PSScriptRoot\lib\helpers.ps1"

# ---------------------------------------------------------------------------
# Interactive mode — no switches provided
# ---------------------------------------------------------------------------
if (-not $Productivity -and -not $Visual -and -not $All -and -not $Restore) {
    Write-Host "What to do?"
    Write-Host "  1. Uninstall productivity tools (zoxide, fzf, lazygit)"
    Write-Host "  2. Uninstall visual tools (starship, eza, bat, fonts)"
    Write-Host "  3. Uninstall all optional tools + undo config"
    Write-Host "  4. Restore dotfiles from backup"
    Write-Host "  5. Cancel"
    $choice = Read-Host "  Choice [1-5]"
    switch ($choice.Trim()) {
        '1' { $Productivity = $true }
        '2' { $Visual = $true }
        '3' { $All = $true }
        '4' { $Restore = $true }
        default { Write-Host "→ Cancelled."; exit 0 }
    }
}

if ($All) { $Productivity = $true; $Visual = $true }

# ---------------------------------------------------------------------------
# Uninstall productivity tools
# ---------------------------------------------------------------------------
if ($Productivity) {
    Write-Host ""
    Write-Host "=== Uninstalling productivity tools ==="
    foreach ($tool in $ProductivityTools) {
        Uninstall-WingetPackage -Id $tool.Id -Name $tool.Name
    }
}

# ---------------------------------------------------------------------------
# Uninstall visual tools + revert fonts
# ---------------------------------------------------------------------------
if ($Visual) {
    Write-Host ""
    Write-Host "=== Uninstalling visual tools ==="
    foreach ($tool in $VisualTools) {
        $allVer = $tool.Id -eq 'Starship.Starship'
        Uninstall-WingetPackage -Id $tool.Id -Name $tool.Name -AllVersions:$allVer
    }

    # FiraCode Nerd Font
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        $scoopList = scoop list 2>$null
        if ($scoopList -match 'FiraCode-NF') {
            Write-Host ""
            Write-Host "→ FiraCode Nerd Font: cannot remove while Windows Terminal or VS Code are open."
            Write-Host "  After closing them, run from a plain PowerShell window (Win+R → powershell):"
            Write-Host "      scoop uninstall nerd-fonts/FiraCode-NF"
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
        $wtFont = $json.profiles?.defaults?.font
        if ($wtFont -and $wtFont.PSObject.Properties['face'] -and $wtFont.face -eq 'FiraCode Nerd Font') {
            $wtFont.PSObject.Properties.Remove('face')
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
        $prop = $vsJson.PSObject.Properties['terminal.integrated.fontFamily']
        if ($prop -and $prop.Value -eq 'FiraCode Nerd Font') {
            $vsJson.PSObject.Properties.Remove('terminal.integrated.fontFamily')
            $vsJson | ConvertTo-Json -Depth 20 | Set-Content $vsCodeSettings -Encoding UTF8
            Write-Host "→ VS Code terminal font reverted to default ($vsCodeSettings)."
        }
    }

    # Remove starship config
    $starshipToml = Join-Path $HOME ".config\starship.toml"
    if (Test-Path $starshipToml) {
        Remove-Item $starshipToml -Force
        Write-Host "→ Removed starship config: $starshipToml"
    }

    Write-Host "→ Visual cleanup complete."
}

# ---------------------------------------------------------------------------
# -All: also undo symlinks + PS profile stubs, then offer restore
# ---------------------------------------------------------------------------
if ($All) {
    Write-Host ""
    Write-Host "=== Undoing config ==="

    # Remove symlinks
    $symlinks = @(
        Join-Path $HOME ".gitconfig"
        Join-Path $HOME ".gitattributes"
        Join-Path $HOME ".bash_profile"
    )
    foreach ($link in $symlinks) {
        if (Test-Path $link) {
            $item = Get-Item $link -Force
            if ($item.LinkType -eq 'SymbolicLink') {
                Remove-Item $link -Force
                Write-Host "→ Removed symlink: $link"
            } else {
                Write-Host "→ $link is not a symlink, skipping."
            }
        }
    }

    # Remove PS profile stubs
    $psProfilePaths = @(
        Join-Path ([Environment]::GetFolderPath('MyDocuments')) "PowerShell\Microsoft.PowerShell_profile.ps1"
        Join-Path ([Environment]::GetFolderPath('MyDocuments')) "WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
    )
    foreach ($psProfile in $psProfilePaths) {
        if (Test-Path $psProfile) {
            $content = Get-Content $psProfile -Raw -ErrorAction SilentlyContinue
            if ($content -match 'dotfiles') {
                Remove-Item $psProfile -Force
                Write-Host "→ Removed PS profile stub: $psProfile"
            }
        }
    }

    # Remove .gitconfig.local
    $localConfig = Join-Path $HOME ".gitconfig.local"
    if (Test-Path $localConfig) {
        $removeLocal = Read-Host "→ Remove $localConfig (git identity + BC config)? [y/N]"
        if ($removeLocal -match '^[Yy]') {
            Remove-Item $localConfig -Force
            Write-Host "→ Removed: $localConfig"
        }
    }

    # Offer backup restore
    $doRestore = Read-Host "→ Restore dotfiles from backup? [Y/n]"
    if ($doRestore -notmatch '^[Nn]') {
        $Restore = $true
    }
}

# ---------------------------------------------------------------------------
# Restore from backup
# ---------------------------------------------------------------------------
if ($Restore) {
    Write-Host ""
    Write-Host "=== Restoring from backup ==="

    $BackupRoot = Join-Path $HOME ".dotfiles-backup"

    if (-not (Test-Path $BackupRoot)) {
        Write-Warning "No backups found at $BackupRoot — nothing to restore."
    } else {
        $backups = @(Get-ChildItem $BackupRoot -Directory | Sort-Object Name)

        if ($backups.Count -eq 0) {
            Write-Warning "No backup folders found in $BackupRoot."
        } else {
            Write-Host "Available backups:"
            $backups | ForEach-Object { Write-Host "  $($_.Name)" }
            Write-Host ""

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

            $RestoreDir = $chosen.FullName

            # Dotfiles
            $dotfiles = @(
                [pscustomobject]@{ Name = ".gitconfig";                                    Target = Join-Path $HOME ".gitconfig" }
                [pscustomobject]@{ Name = ".gitattributes";                                Target = Join-Path $HOME ".gitattributes" }
                [pscustomobject]@{ Name = ".bash_profile";                                 Target = Join-Path $HOME ".bash_profile" }
                [pscustomobject]@{ Name = "starship.toml";                                 Target = Join-Path $HOME ".config\starship.toml" }
                [pscustomobject]@{ Name = "PowerShell_Microsoft.PowerShell_profile.ps1";   Target = Join-Path ([Environment]::GetFolderPath('MyDocuments')) "PowerShell\Microsoft.PowerShell_profile.ps1" }
                [pscustomobject]@{ Name = "WindowsPowerShell_Microsoft.PowerShell_profile.ps1"; Target = Join-Path ([Environment]::GetFolderPath('MyDocuments')) "WindowsPowerShell\Microsoft.PowerShell_profile.ps1" }
            )

            foreach ($df in $dotfiles) {
                $backup = Join-Path $RestoreDir $df.Name
                if (-not (Test-Path $backup)) {
                    Write-Host "→ No backup for $($df.Name), skipping."
                    continue
                }
                if (Test-Path $df.Target) {
                    Remove-Item $df.Target -Force
                    Write-Host "→ Removed: $($df.Target)"
                }
                Copy-Item $backup $df.Target
                Write-Host "→ Restored: $($df.Target)"
                Write-Host "        ← $backup"
            }

            # Windows Terminal settings
            $wtBackup = Join-Path $RestoreDir "wt_settings.json"
            if (Test-Path $wtBackup) {
                $wtTargetPaths = @(
                    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
                    "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
                )
                $wtTarget = $wtTargetPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
                if ($wtTarget) {
                    Copy-Item $wtBackup $wtTarget -Force
                    Write-Host "→ Restored: $wtTarget"
                } else {
                    Write-Host "→ No Windows Terminal settings.json found, skipping."
                }
            }

            # VS Code settings
            $vsRestorations = @(
                [pscustomobject]@{ Backup = "vscode_Code_settings.json";            Target = "$env:APPDATA\Code\User\settings.json" }
                [pscustomobject]@{ Backup = "vscode_Code - Insiders_settings.json"; Target = "$env:APPDATA\Code - Insiders\User\settings.json" }
                [pscustomobject]@{ Backup = "vscode_settings.json";                 Target = "$env:APPDATA\Code\User\settings.json" }
            )
            foreach ($vsr in $vsRestorations) {
                $vsBackup = Join-Path $RestoreDir $vsr.Backup
                if (-not (Test-Path $vsBackup)) { continue }
                $vsDir = Split-Path $vsr.Target
                if (-not (Test-Path $vsDir)) { continue }
                Copy-Item $vsBackup $vsr.Target -Force
                Write-Host "→ Restored: $($vsr.Target)"
            }
        }
    }
}

Write-Host ""
Write-Host "Done. Open a new shell session to apply changes."
