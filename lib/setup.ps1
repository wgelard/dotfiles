#Requires -Version 5.1
<#
.SYNOPSIS
    Core setup — install essential tools, configure git, create symlinks.
.DESCRIPTION
    - Installs core tools via winget (git, difftastic, delta, carapace, gh, ripgrep, fd, tldr, VS Code)
    - Detects/offers Beyond Compare 4
    - Installs mergiraf via scoop (or cargo binstall)
    - Prompts for git identity and writes ~/.gitconfig.local
    - Symlinks ~/.gitconfig, ~/.gitattributes, ~/.bash_profile
    - Writes PowerShell profile dot-source stubs (PS5 + PS7)
.NOTES
    Called by bootstrap.ps1. Can also be run standalone.
    Requires Developer Mode OR Administrator for symlinks.
#>

. "$PSScriptRoot\helpers.ps1"

Assert-SymlinkCapability

# ---------------------------------------------------------------------------
# 1. Core tools via winget
# ---------------------------------------------------------------------------
$corePackages = @(
    [pscustomobject]@{ Id = "Git.Git";                          Name = "Git for Windows";  Cmd = "git" }
    [pscustomobject]@{ Id = "Wilfred.difftastic";               Name = "difftastic";       Cmd = "difft" }
    [pscustomobject]@{ Id = "dandavison.delta";                 Name = "delta";            Cmd = "delta" }
    [pscustomobject]@{ Id = "rsteube.Carapace";                 Name = "carapace";         Cmd = "carapace" }
    [pscustomobject]@{ Id = "GitHub.cli";                       Name = "GitHub CLI";       Cmd = "gh" }
    [pscustomobject]@{ Id = "BurntSushi.ripgrep.MSVC";          Name = "ripgrep";          Cmd = "rg" }
    [pscustomobject]@{ Id = "sharkdp.fd";                       Name = "fd";               Cmd = "fd" }
    [pscustomobject]@{ Id = "tldr-pages.tlrc";                  Name = "tldr";             Cmd = "tldr" }
    [pscustomobject]@{ Id = "Microsoft.VisualStudioCode";       Name = "VS Code";          Cmd = "code" }
)

foreach ($pkg in $corePackages) {
    if ($pkg.Cmd -and (Get-Command $pkg.Cmd -ErrorAction SilentlyContinue)) {
        Write-Host "→ $($pkg.Name) already installed, skipping."
    } else {
        Install-WingetPackage -Id $pkg.Id -Name $pkg.Name
    }
}

Update-SessionPath

# ---------------------------------------------------------------------------
# 2. Beyond Compare — detect or offer install
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
        Update-SessionPath
        $installedExe = $bcPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
        if (-not $installedExe) { $installedExe = (Get-Command bcomp -ErrorAction SilentlyContinue)?.Source }
        if ($installedExe) { Write-BcConfig -BcExePath $installedExe }
    } else {
        Write-Host "→ Skipping Beyond Compare 4. VS Code will be used as the default GUI diff/merge tool."
        Write-Host "   To use BC later: git dbc (diff)  or  git mbc (merge)"
    }
}

# ---------------------------------------------------------------------------
# 3. Install mergiraf (no winget package — try scoop, then cargo binstall)
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
# 4. Git identity — write ~/.gitconfig.local
# ---------------------------------------------------------------------------
$localConfig = Join-Path $HOME ".gitconfig.local"
$needIdentity = $true

if (Test-Path $localConfig) {
    $existingContent = Get-Content $localConfig -Raw
    $existingName  = if ($existingContent -match '(?m)^\s*name\s*=\s*(.+)$')  { $Matches[1].Trim() }
    $existingEmail = if ($existingContent -match '(?m)^\s*email\s*=\s*(.+)$') { $Matches[1].Trim() }

    if ($existingName -and $existingEmail) {
        Write-Host ""
        Write-Host "→ Found existing git identity in $localConfig :"
        Write-Host "    name:  $existingName"
        Write-Host "    email: $existingEmail"
        $reconfig = Read-Host "  Is this correct? [Y/n]"
        if ($reconfig -notmatch '^[Nn]') {
            $needIdentity = $false
        }
    } else {
        Write-Host ""
        Write-Host "→ $localConfig exists but has no git identity — prompting now."
    }
}

if ($needIdentity) {
    Write-Host ""
    $gitName  = $null
    $gitEmail = $null

    Write-Host "Git identity — which provider?"
    Write-Host "  1. GitHub (github.com)"
    Write-Host "  2. GitHub Enterprise (custom host)"
    Write-Host "  3. GitLab"
    Write-Host "  4. Enter manually"
    $providerChoice = Read-Host "  Choice [1-4]"

    switch ($providerChoice.Trim()) {
        '1' {
            if (Get-Command gh -ErrorAction SilentlyContinue) {
                $ghStatus = gh auth status --hostname github.com 2>&1
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "→ Launching GitHub.com browser login..."
                    gh auth login --hostname github.com --web --git-protocol https
                }
                try {
                    $gitName  = (gh api user --hostname github.com --jq '.name' 2>$null).Trim()
                    $gitEmail = (gh api user/emails --hostname github.com --jq '[.[] | select(.primary == true)] | .[0].email' 2>$null).Trim()
                } catch {}
            } else { Write-Host "→ gh CLI not found, falling back to manual." }
        }
        '2' {
            $gheHost = Read-Host "  GitHub Enterprise hostname (e.g. github.mycompany.com)"
            if (Get-Command gh -ErrorAction SilentlyContinue) {
                $ghStatus = gh auth status --hostname $gheHost 2>&1
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "→ Launching browser login for $gheHost..."
                    gh auth login --hostname $gheHost --web --git-protocol https
                }
                try {
                    $gitName  = (gh api user --hostname $gheHost --jq '.name' 2>$null).Trim()
                    $emailRaw = gh api user/emails --hostname $gheHost --jq '[.[] | select(.primary == true)] | .[0].email' 2>$null
                    if ($LASTEXITCODE -eq 0) { $gitEmail = $emailRaw.Trim() }
                } catch {}
            } else { Write-Host "→ gh CLI not found, falling back to manual." }
        }
        '3' {
            if (Get-Command glab -ErrorAction SilentlyContinue) {
                $glStatus = glab auth status 2>&1
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "→ Launching GitLab browser login..."
                    glab auth login --stdin
                }
                try {
                    $glUser   = glab api /user 2>$null | ConvertFrom-Json
                    $gitName  = $glUser.name.Trim()
                    $gitEmail = $glUser.email.Trim()
                } catch {}
            } else { Write-Host "→ glab CLI not found, falling back to manual." }
        }
    }

    if ($gitName -and $gitEmail) {
        Write-Host ""
        Write-Host "→ Identity detected:"
        Write-Host "    name:  $gitName"
        Write-Host "    email: $gitEmail"
        $confirm = Read-Host "  Use this identity? [Y/n]"
        if ($confirm -match '^[Nn]') { $gitName = $null; $gitEmail = $null }
    }

    if (-not $gitName) {
        do { $gitName  = Read-Host "  user.name" }  until ($gitName.Trim() -ne '')
    }
    if (-not $gitEmail) {
        do { $gitEmail = Read-Host "  user.email" } until ($gitEmail.Trim() -ne '')
    }

    $userBlock = @"
[user]
	name = $gitName
	email = $gitEmail
"@

    if (Test-Path $localConfig) {
        $content = Get-Content $localConfig -Raw
        if ($content -match '(?ms)^\[user\].*?(?=^\[|\z)') {
            $content = $content -replace '(?ms)^\[user\].*?(?=^\[|\z)', ($userBlock + "`n")
            Set-Content -Encoding UTF8 $localConfig $content.TrimEnd()
        } else {
            Add-Content $localConfig "`n$userBlock"
        }
    } else {
        Set-Content -Encoding UTF8 $localConfig $userBlock
    }
    Write-Host "→ Written: $localConfig"
}

# ---------------------------------------------------------------------------
# 5. Symlink dotfiles
# ---------------------------------------------------------------------------
New-DotfilesSymlink -Target (Join-Path $HOME ".gitconfig")     -Source (Join-Path $DotfilesDir "git\.gitconfig")
New-DotfilesSymlink -Target (Join-Path $HOME ".gitattributes") -Source (Join-Path $DotfilesDir "git\.gitattributes")
New-DotfilesSymlink -Target (Join-Path $HOME ".bash_profile")  -Source (Join-Path $DotfilesDir "bash\.bash_profile")

# ---------------------------------------------------------------------------
# 6. PowerShell profile stubs (PS5 + PS7)
# ---------------------------------------------------------------------------
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
        New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
        $backupName = "$(Split-Path $psProfileDir -Leaf)_$(Split-Path $psProfile -Leaf)"
        Copy-Item $psProfile (Join-Path $BackupDir $backupName) -Force
        Write-Host "→ Backed up existing profile: $psProfile"
    }
    Set-Content -Path $psProfile -Value $psProfileStub -Encoding UTF8
    Write-Host "→ PowerShell profile stub written: $psProfile"
}

Write-Host ""
Write-Host "Core setup complete."
