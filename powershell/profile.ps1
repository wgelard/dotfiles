# ---------------------------------------------------------------------------
# delta — use as git pager only when available
# ---------------------------------------------------------------------------
if (Get-Command delta -ErrorAction SilentlyContinue) {
    $env:GIT_PAGER = 'delta'
}

# ---------------------------------------------------------------------------
# Shell completions (carapace)
# ---------------------------------------------------------------------------
if (Get-Command carapace -ErrorAction SilentlyContinue) {
    $env:CARAPACE_BRIDGES = 'zsh,fish,bash,inshellisense'
    (carapace _carapace | Out-String) -replace '\x1b\[[0-9;]*m', '' | Invoke-Expression
}

# ---------------------------------------------------------------------------
# Smart cd (zoxide)
# ---------------------------------------------------------------------------
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
    Set-Alias -Name cd -Value z -Option AllScope -Force
}

# ---------------------------------------------------------------------------
# fzf — fuzzy finder (Ctrl+R history, Ctrl+T file picker)
# ---------------------------------------------------------------------------
if (Get-Command fzf -ErrorAction SilentlyContinue) {
    if (Get-Command fd -ErrorAction SilentlyContinue) {
        $env:FZF_DEFAULT_COMMAND = 'fd --type f --hidden --follow --exclude .git'
        $env:FZF_CTRL_T_COMMAND  = $env:FZF_DEFAULT_COMMAND
        $env:FZF_ALT_C_COMMAND   = 'fd --type d --hidden --follow --exclude .git'
    }
}

# ---------------------------------------------------------------------------
# Better defaults — replace built-ins with modern alternatives
# ---------------------------------------------------------------------------
if (Get-Command eza -ErrorAction SilentlyContinue) {
    function ls  { eza --icons @args }
    function ll  { eza -la --icons --git @args }
}

if (Get-Command bat -ErrorAction SilentlyContinue) {
    function cat { bat --style=auto @args }
}

# ---------------------------------------------------------------------------
# Git shortcuts
# ---------------------------------------------------------------------------
Set-Alias -Name g -Value git
if (Get-Command lazygit -ErrorAction SilentlyContinue) {
    Set-Alias -Name lg -Value lazygit
}

# ---------------------------------------------------------------------------
# Navigation shortcuts
# ---------------------------------------------------------------------------
function .. { cd .. }
function ... { cd ..\.. }
function .... { cd ..\..\.. }

# ---------------------------------------------------------------------------
# Starship prompt (must be last)
# ---------------------------------------------------------------------------
if (-not (Get-Command starship -ErrorAction SilentlyContinue)) {
    $starshipFallback = 'C:\Program Files\starship\bin'
    if (Test-Path $starshipFallback) {
        $env:PATH = "$starshipFallback;$env:PATH"
    }
}
if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (&starship init powershell)
}
