#Requires -Version 5.1
<#
.SYNOPSIS
    Bootstrap a new Windows machine from the dotfiles repository.
.DESCRIPTION
    Orchestrates the full setup:
    1. Core tools + git config + symlinks  (lib/setup.ps1)
    2. Optional productivity tools         (zoxide, fzf, lazygit)
    3. Optional visual customization       (starship, eza, bat, FiraCode NF)
.NOTES
    Safe to re-run — already-installed items are skipped.
    Requires Developer Mode OR run as Administrator for symlinks.
#>

. "$PSScriptRoot\lib\helpers.ps1"

# ---------------------------------------------------------------------------
# 1. Core setup
# ---------------------------------------------------------------------------
& "$PSScriptRoot\lib\setup.ps1"

Update-SessionPath

# ---------------------------------------------------------------------------
# 2. Productivity tools (invisible to observers)
# ---------------------------------------------------------------------------
Write-Host ""
$missingProductivity = $ProductivityTools | Where-Object { -not (Get-Command $_.Cmd -ErrorAction SilentlyContinue) }
if ($missingProductivity) {
    $missingNames = ($missingProductivity | ForEach-Object { $_.Name }) -join ', '
    $installProductivity = Read-Host "→ Install productivity tools ($missingNames)? [Y/n]"
    if ($installProductivity -notmatch '^[Nn]') {
        foreach ($tool in $missingProductivity) {
            Install-WingetPackage -Id $tool.Id -Name $tool.Name
        }
    } else {
        Write-Host "→ Skipping productivity tools."
    }
} else {
    Write-Host "→ Productivity tools (zoxide, fzf, lazygit) already installed."
}

# ---------------------------------------------------------------------------
# 3. Visual customization (prompt, ls colors, font)
# ---------------------------------------------------------------------------
Write-Host ""
$missingVisual = $VisualTools | Where-Object { -not (Get-Command $_.Cmd -ErrorAction SilentlyContinue) }
$visualEnabled = $false
if ($missingVisual) {
    $missingNames = ($missingVisual | ForEach-Object { $_.Name }) -join ', '
    Write-Host "  Visual tools make your terminal look customized (Catppuccin prompt, colored ls, Nerd Font)."
    Write-Host "  Skip this on work machines if a fancy terminal might raise eyebrows."
    $installVisual = Read-Host "→ Install visual customization ($missingNames, FiraCode Nerd Font)? [Y/n]"
    $visualEnabled = $installVisual -notmatch '^[Nn]'
    if ($visualEnabled) {
        foreach ($tool in $missingVisual) {
            Install-WingetPackage -Id $tool.Id -Name $tool.Name
        }
    } else {
        Write-Host "→ Skipping visual tools. Terminal will use default appearance."
    }
} else {
    Write-Host "→ Visual tools (starship, eza, bat) already installed."
    $visualEnabled = $true
}

Update-SessionPath

# ---------------------------------------------------------------------------
# 4. FiraCode Nerd Font + terminal font config (visual group only)
# ---------------------------------------------------------------------------
Write-Host ""
if ($visualEnabled) {
    $fontInstalled = Get-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts' -ErrorAction SilentlyContinue |
        Get-Member -MemberType NoteProperty | Where-Object { $_.Name -match 'FiraCode.*Nerd' }
    if ($fontInstalled) {
        Write-Host "→ FiraCode Nerd Font already installed, skipping."
    } else {
        if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
            Write-Host "→ Installing scoop (required for Nerd Fonts)..."
            Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
            Invoke-RestMethod get.scoop.sh | Invoke-Expression
            Update-SessionPath
        }
        Write-Host "→ Installing FiraCode Nerd Font via scoop..."
        scoop bucket add nerd-fonts 2>$null
        scoop install nerd-fonts/FiraCode-NF
        Write-Host "→ FiraCode Nerd Font installed."
    }

    # Windows Terminal font
    $wtSettingsPaths = @(
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
        "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
    )
    $wtSettings = $wtSettingsPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($wtSettings) {
        New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
        Copy-Item $wtSettings (Join-Path $BackupDir "wt_settings.json") -Force
        Write-Host "→ Backed up Windows Terminal settings: $wtSettings"
        $json = Get-Content $wtSettings -Raw | ConvertFrom-Json
        if (-not $json.profiles) { $json | Add-Member -NotePropertyName profiles -NotePropertyValue ([pscustomobject]@{}) }
        if (-not $json.profiles.defaults) { $json.profiles | Add-Member -NotePropertyName defaults -NotePropertyValue ([pscustomobject]@{}) }
        if (-not $json.profiles.defaults.font) { $json.profiles.defaults | Add-Member -NotePropertyName font -NotePropertyValue ([pscustomobject]@{}) }
        $json.profiles.defaults.font | Add-Member -NotePropertyName face -NotePropertyValue 'FiraCode Nerd Font' -Force
        $json | ConvertTo-Json -Depth 20 | Set-Content $wtSettings -Encoding UTF8
        Write-Host "→ Windows Terminal font set to 'FiraCode Nerd Font'."
    } else {
        Write-Host "→ Windows Terminal settings.json not found — set font manually to 'FiraCode Nerd Font'."
    }

    # VS Code terminal font
    $vsCodeSettingsPaths = @(
        "$env:APPDATA\Code\User\settings.json"
        "$env:APPDATA\Code - Insiders\User\settings.json"
    )
    foreach ($vsCodeSettings in $vsCodeSettingsPaths | Where-Object { Test-Path $_ }) {
        New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
        $vsAppName    = Split-Path (Split-Path $vsCodeSettings -Parent) -Parent | Split-Path -Leaf
        $vsBackupName = "vscode_${vsAppName}_settings.json"
        Copy-Item $vsCodeSettings (Join-Path $BackupDir $vsBackupName) -Force
        Write-Host "→ Backed up VS Code settings: $vsCodeSettings"
        $vsJson = Get-Content $vsCodeSettings -Raw | ConvertFrom-Json
        $vsJson | Add-Member -NotePropertyName 'terminal.integrated.fontFamily' -NotePropertyValue 'FiraCode Nerd Font' -Force
        $vsJson | ConvertTo-Json -Depth 20 | Set-Content $vsCodeSettings -Encoding UTF8
        Write-Host "→ VS Code terminal font set to 'FiraCode Nerd Font' ($vsCodeSettings)."
    }

    # Starship preset
    $starshipDir = Join-Path $HOME ".config"
    if (-not (Test-Path $starshipDir)) { New-Item -ItemType Directory -Path $starshipDir -Force | Out-Null }
    if (-not (Get-Command starship -ErrorAction SilentlyContinue)) {
        $starshipFallback = 'C:\Program Files\starship\bin'
        if (Test-Path $starshipFallback) { $env:PATH = "$starshipFallback;$env:PATH" }
    }
    if (Get-Command starship -ErrorAction SilentlyContinue) {
        $starshipToml = Join-Path $starshipDir "starship.toml"
        if (Test-Path $starshipToml) {
            Write-Host "→ Starship: ~/.config/starship.toml already exists, skipping preset."
        } else {
            starship preset catppuccin-powerline -o $starshipToml
            Write-Host "→ Starship: catppuccin-powerline preset applied."
        }
    } else {
        Write-Warning "starship not found — skipping preset. Run bootstrap again after installing starship."
    }
} else {
    Write-Host "→ Skipping font installation and terminal font config."
}

# ---------------------------------------------------------------------------
# 5. AI tools (Copilot CLI, opencode)
# ---------------------------------------------------------------------------
Write-Host ""
$missingAI = $AITools | Where-Object { -not (Get-Command $_.Cmd -ErrorAction SilentlyContinue) }
if ($missingAI) {
    $missingNames = ($missingAI | ForEach-Object { $_.Name }) -join ', '
    Write-Host "  AI tools bring AI-powered coding assistance to your terminal."
    Write-Host "  Both require a GitHub Copilot subscription to use."
    $installAI = Read-Host "→ Install AI tools ($missingNames)? [y/N]"
    if ($installAI -match '^[Yy]') {
        foreach ($tool in $missingAI) {
            Install-WingetPackage -Id $tool.Id -Name $tool.Name
        }
        Update-SessionPath
    } else {
        Write-Host "→ Skipping AI tools."
    }
} else {
    Write-Host "→ AI tools (Copilot CLI, opencode) already installed."
}

# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "Bootstrap complete. PATH refreshed — newly installed tools are available in this session."
