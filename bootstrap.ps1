#Requires -Version 5.1
<#
.SYNOPSIS
    Bootstrap a new Windows machine from the dotfiles repository.
.DESCRIPTION
    - Installs tools via winget (git, difftastic, delta, carapace, gh, ripgrep, fd, tldr)
    - Optionally installs shell enhancement tools (starship, zoxide, fzf, eza, bat, lazygit)
    - Optionally installs Beyond Compare 4 (paid ~$60) via winget if user confirms
    - Installs mergiraf via scoop (or cargo binstall as fallback)
    - Prompts for git identity and writes ~/.gitconfig.local (not committed)
    - Symlinks ~/.gitconfig, ~/.gitattributes, ~/.bash_profile to this repo
.NOTES
    Requires Developer Mode OR run as Administrator for symlink creation.
    Enable Developer Mode: Settings > System > For developers > Developer Mode
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$DotfilesDir = $PSScriptRoot

# ---------------------------------------------------------------------------
# 1. Verify symlink capability
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
# 2. Install tools via winget
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

$packages = @(
    [pscustomobject]@{ Id = "Git.Git";                          Name = "Git for Windows";  Cmd = "git" }
    [pscustomobject]@{ Id = "Wilfred.difftastic";               Name = "difftastic";       Cmd = "difft" }
    [pscustomobject]@{ Id = "dandavison.delta";                 Name = "delta";            Cmd = "delta" }
    [pscustomobject]@{ Id = "rsteube.Carapace";                 Name = "carapace";         Cmd = "carapace" }
    [pscustomobject]@{ Id = "GitHub.cli";                       Name = "GitHub CLI";       Cmd = "gh" }
    [pscustomobject]@{ Id = "BurntSushi.ripgrep.MSVC";          Name = "ripgrep";          Cmd = "rg" }
    [pscustomobject]@{ Id = "sharkdp.fd";                       Name = "fd";               Cmd = "fd" }
    [pscustomobject]@{ Id = "tldr-pages.tlrc";                  Name = "tldr";             Cmd = "tldr" }
)

foreach ($pkg in $packages) {
    if ($pkg.Cmd -and (Get-Command $pkg.Cmd -ErrorAction SilentlyContinue)) {
        Write-Host "→ $($pkg.Name) already installed, skipping."
    } else {
        Install-WingetPackage -Id $pkg.Id -Name $pkg.Name
    }
}

# Refresh PATH now so Get-Command picks up anything just installed
# (and tools already installed in previous sessions)
$env:PATH = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine') + ';' +
            [System.Environment]::GetEnvironmentVariable('PATH', 'User')

# ---------------------------------------------------------------------------
# 2b. Beyond Compare — set as default if present, offer install if not
# ---------------------------------------------------------------------------
Write-Host ""
$bcPaths = @(
    "$env:ProgramFiles\Beyond Compare 4\BComp.exe"
    "${env:ProgramFiles(x86)}\Beyond Compare 4\BComp.exe"
    "$env:LOCALAPPDATA\Programs\Beyond Compare 4\BComp.exe"
)
$bcExe = $bcPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
$bcPresent = $bcExe -or (Get-Command bcomp -ErrorAction SilentlyContinue)

function Write-BcConfig {
    param([string]$BcExePath)
    # Add BC directory to user PATH permanently so bcomp works in any shell
    # (avoids quoting issues with spaces in path inside gitconfig cmd)
    $bcDir = Split-Path $BcExePath
    $currentUserPath = [System.Environment]::GetEnvironmentVariable('PATH', 'User')
    if ($currentUserPath -notmatch [regex]::Escape($bcDir)) {
        [System.Environment]::SetEnvironmentVariable('PATH', "$currentUserPath;$bcDir", 'User')
        $env:PATH = "$env:PATH;$bcDir"
        Write-Host "→ Added '$bcDir' to user PATH."
    }

    $localConfig = Join-Path $HOME ".gitconfig.local"
    $bcOverride = @"

[diff]
	guitool = bc
[merge]
	tool = bc
	guitool = bc
[difftool "bc"]
	cmd = bcomp "`$LOCAL" "`$REMOTE"
[mergetool "bc"]
	cmd = bcomp "`$LOCAL" "`$REMOTE" "`$BASE" "`$MERGED"
"@
    if (Test-Path $localConfig) {
        $existing = Get-Content $localConfig -Raw
        if ($existing -notmatch 'guitool\s*=\s*bc') {
            Add-Content $localConfig $bcOverride
        }
    } else {
        Add-Content $localConfig $bcOverride
    }
}

if ($bcPresent) {
    Write-Host "→ Beyond Compare detected — setting as default GUI diff/merge tool."
    $exePath = if ($bcExe) { $bcExe } else { (Get-Command bcomp).Source }
    Write-BcConfig -BcExePath $exePath
} else {
    $installBC = Read-Host "→ Install Beyond Compare 4 (paid ~`$60, best-in-class GUI diff/merge)? [y/N]"
    if ($installBC -match '^[Yy]') {
        Install-WingetPackage -Id "ScooterSoftware.BeyondCompare.4" -Name "Beyond Compare 4"
        Write-Host "→ Beyond Compare installed — setting as default GUI diff/merge tool."
        # Refresh PATH then find the exe
        $env:PATH = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine') + ';' +
                    [System.Environment]::GetEnvironmentVariable('PATH', 'User')
        $installedExe = $bcPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
        if (-not $installedExe) { $installedExe = (Get-Command bcomp -ErrorAction SilentlyContinue)?.Source }
        if ($installedExe) { Write-BcConfig -BcExePath $installedExe }
    } else {
        Write-Host "→ Skipping Beyond Compare 4. VS Code will be used as the default GUI diff/merge tool."
        Write-Host "   To use BC later: git dbc (diff)  or  git mbc (merge)"
    }
}

# ---------------------------------------------------------------------------
# 2c. Optionally install shell enhancement tools
# ---------------------------------------------------------------------------
Write-Host ""
$shellTools = @(
    [pscustomobject]@{ Id = "Starship.Starship";       Name = "starship";  Cmd = "starship" }
    [pscustomobject]@{ Id = "ajeetdsouza.zoxide";      Name = "zoxide";    Cmd = "zoxide" }
    [pscustomobject]@{ Id = "junegunn.fzf";            Name = "fzf";       Cmd = "fzf" }
    [pscustomobject]@{ Id = "eza-community.eza";       Name = "eza";       Cmd = "eza" }
    [pscustomobject]@{ Id = "sharkdp.bat";             Name = "bat";       Cmd = "bat" }
    [pscustomobject]@{ Id = "JesseDuffield.lazygit";   Name = "lazygit";   Cmd = "lazygit" }
)

$installShell = Read-Host "→ Install shell enhancement tools (starship, zoxide, fzf, eza, bat, lazygit)? [Y/n]"
if ($installShell -notmatch '^[Nn]') {
    foreach ($tool in $shellTools) {
        if (Get-Command $tool.Cmd -ErrorAction SilentlyContinue) {
            Write-Host "→ $($tool.Name) already installed, skipping."
        } else {
            Install-WingetPackage -Id $tool.Id -Name $tool.Name
        }
    }
    # Refresh PATH so newly installed tools (e.g. starship) are available immediately
    $env:PATH = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine') + ';' +
                [System.Environment]::GetEnvironmentVariable('PATH', 'User')
} else {
    Write-Host "→ Skipping shell tools. Install any time — they activate automatically via the Git Bash profile."
}

# ---------------------------------------------------------------------------
# 3. Install FiraCode Nerd Font and configure Windows Terminal
# ---------------------------------------------------------------------------
Write-Host ""
$fontInstalled = Get-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts' -ErrorAction SilentlyContinue |
    Get-Member -MemberType NoteProperty | Where-Object { $_.Name -match 'FiraCode.*Nerd' }
if ($fontInstalled) {
    Write-Host "→ FiraCode Nerd Font already installed, skipping."
} else {
    # Ensure scoop is available (no admin required)
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        Write-Host "→ Installing scoop (required for Nerd Fonts)..."
        Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        Invoke-RestMethod get.scoop.sh | Invoke-Expression
        # Refresh PATH so scoop is usable immediately
        $env:PATH = [System.Environment]::GetEnvironmentVariable('PATH', 'Machine') + ';' +
                    [System.Environment]::GetEnvironmentVariable('PATH', 'User')
    }
    Write-Host "→ Installing FiraCode Nerd Font via scoop..."
    scoop bucket add nerd-fonts 2>$null
    scoop install nerd-fonts/FiraCode-NF
    Write-Host "→ FiraCode Nerd Font installed."
}

# Set FiraCode Nerd Font as default in Windows Terminal settings.json
$wtSettingsPaths = @(
    "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
)
$wtSettings = $wtSettingsPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($wtSettings) {
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

# Set FiraCode Nerd Font in VS Code terminal
$vsCodeSettingsPaths = @(
    "$env:APPDATA\Code\User\settings.json"
    "$env:APPDATA\Code - Insiders\User\settings.json"
)
foreach ($vsCodeSettings in $vsCodeSettingsPaths | Where-Object { Test-Path $_ }) {
    $vsJson = Get-Content $vsCodeSettings -Raw | ConvertFrom-Json
    $vsJson | Add-Member -NotePropertyName 'terminal.integrated.fontFamily' -NotePropertyValue 'FiraCode Nerd Font' -Force
    $vsJson | ConvertTo-Json -Depth 20 | Set-Content $vsCodeSettings -Encoding UTF8
    Write-Host "→ VS Code terminal font set to 'FiraCode Nerd Font' ($vsCodeSettings)."
}

# ---------------------------------------------------------------------------
# 4. Install mergiraf (no winget package — try scoop, then cargo binstall)
# ---------------------------------------------------------------------------
if (Get-Command mergiraf -ErrorAction SilentlyContinue) {
    Write-Host "→ mergiraf already installed, skipping."
} elseif (Get-Command scoop -ErrorAction SilentlyContinue) {
    Write-Host "→ Installing mergiraf via scoop..."
    scoop install mergiraf
} elseif (Get-Command cargo -ErrorAction SilentlyContinue) {
    Write-Host "→ Installing mergiraf via cargo binstall..."
    cargo binstall --no-confirm mergiraf
} else {
    Write-Warning @"
mergiraf could not be installed automatically.
Install it manually:
  - scoop: scoop install mergiraf
  - cargo: cargo binstall mergiraf
  - binary: https://codeberg.org/mergiraf/mergiraf/releases
"@
}

# ---------------------------------------------------------------------------
# 5. Write ~/.gitconfig.local with git identity (not committed to repo)
# ---------------------------------------------------------------------------
$localConfig = Join-Path $HOME ".gitconfig.local"
if (Test-Path $localConfig) {
    Write-Host "→ $localConfig already exists, skipping identity prompt."
} else {
    Write-Host ""
    Write-Host "Git identity (will be written to ~/.gitconfig.local, NOT committed):"
    $gitName  = Read-Host "  user.name"
    $gitEmail = Read-Host "  user.email"
    @"
[user]
	name = $gitName
	email = $gitEmail
"@ | Set-Content -Encoding UTF8 $localConfig
    Write-Host "→ Written: $localConfig"
}

# ---------------------------------------------------------------------------
# 6. Symlink dotfiles (backing up any real file first)
# ---------------------------------------------------------------------------
$BackupDir = Join-Path $HOME ".dotfiles-backup\$(Get-Date -Format 'yyyy-MM-dd_HHmmss')"

function New-Symlink {
    param([string]$Target, [string]$Source)

    if (Test-Path $Target) {
        $item = Get-Item $Target -Force
        # Already a symlink pointing to this repo — nothing to do
        if ($item.LinkType -eq 'SymbolicLink' -and $item.Target -eq $Source) {
            Write-Host "→ Already linked: $Target"
            return
        }
        # Real file (or symlink elsewhere) — back it up before replacing
        New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
        $dest = Join-Path $BackupDir (Split-Path $Target -Leaf)
        Copy-Item $Target $dest -Force
        Write-Host "→ Backed up: $Target"
        Write-Host "          → $dest"
        Remove-Item $Target -Force
    }

    New-Item -ItemType SymbolicLink -Path $Target -Target $Source | Out-Null
    Write-Host "→ Linked: $Target"
    Write-Host "       → $Source"
}

New-Symlink -Target (Join-Path $HOME ".gitconfig")     -Source (Join-Path $DotfilesDir "git\.gitconfig")
New-Symlink -Target (Join-Path $HOME ".gitattributes") -Source (Join-Path $DotfilesDir "git\.gitattributes")
New-Symlink -Target (Join-Path $HOME ".bash_profile")  -Source (Join-Path $DotfilesDir "bash\.bash_profile")

# PowerShell profiles — write a dot-source stub to both PS5 and PS7 locations.
# $PROFILE is typically inside OneDrive which doesn't support symlinks, so we
# write a small stub instead of symlinking.
$psProfileStub = ". `"$(Join-Path $DotfilesDir 'powershell\profile.ps1')`""
$psProfilePaths = @(
    Join-Path ([Environment]::GetFolderPath('MyDocuments')) "PowerShell\Microsoft.PowerShell_profile.ps1"
    Join-Path ([Environment]::GetFolderPath('MyDocuments')) "WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
)
foreach ($psProfile in $psProfilePaths) {
    $psProfileDir = Split-Path $psProfile
    if (-not (Test-Path $psProfileDir)) { New-Item -ItemType Directory -Path $psProfileDir -Force | Out-Null }
    if (Test-Path $psProfile) {
        $existing = Get-Content $psProfile -Raw -ErrorAction SilentlyContinue
        if ($existing -match [regex]::Escape($DotfilesDir)) {
            Write-Host "→ PowerShell profile stub already present: $psProfile"
            continue
        }
        # Back up existing profile before overwriting
        New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
        $backupName = "$(Split-Path $psProfileDir -Leaf)_$(Split-Path $psProfile -Leaf)"
        Copy-Item $psProfile (Join-Path $BackupDir $backupName) -Force
        Write-Host "→ Backed up existing profile: $psProfile"
    }
    Set-Content -Path $psProfile -Value $psProfileStub -Encoding UTF8
    Write-Host "→ PowerShell profile stub written: $psProfile"
}

# Starship config — apply catppuccin-powerline preset directly (no symlink needed)
$starshipDir = Join-Path $HOME ".config"
if (-not (Test-Path $starshipDir)) { New-Item -ItemType Directory -Path $starshipDir -Force | Out-Null }
# winget installs starship to Program Files — add to PATH if not yet visible
if (-not (Get-Command starship -ErrorAction SilentlyContinue)) {
    $starshipFallback = 'C:\Program Files\starship\bin'
    if (Test-Path $starshipFallback) { $env:PATH = "$starshipFallback;$env:PATH" }
}
if (Get-Command starship -ErrorAction SilentlyContinue) {
    starship preset catppuccin-powerline -o (Join-Path $starshipDir "starship.toml")
    Write-Host "→ Starship: catppuccin-powerline preset applied."
} else {
    Write-Warning "starship not found — skipping preset. Run bootstrap again after installing starship."
}

# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "Bootstrap complete. PATH refreshed — newly installed tools are available in this session."
