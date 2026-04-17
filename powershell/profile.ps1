# ---------------------------------------------------------------------------
# Enable VT/ANSI processing — must be first.
# VS Code's shell integration injects ANSI reset sequences before the console
# VT flag is set, causing \x1b[0m to appear as literal text on startup.
# This is a no-op on PS7 (always enabled) and on non-Windows.
# ---------------------------------------------------------------------------
if ($IsWindows -or $env:OS -eq 'Windows_NT') {
    $null = [System.Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    try {
        $kernel32 = Add-Type -PassThru -Name 'Kernel32Vt' -Namespace '' -MemberDefinition @'
            [DllImport("kernel32.dll")] public static extern IntPtr GetStdHandle(int h);
            [DllImport("kernel32.dll")] public static extern bool GetConsoleMode(IntPtr h, out uint m);
            [DllImport("kernel32.dll")] public static extern bool SetConsoleMode(IntPtr h, uint m);
'@ -ErrorAction SilentlyContinue
        if ($kernel32) {
            $h = $kernel32::GetStdHandle(-11)   # STD_OUTPUT_HANDLE
            $m = 0u
            if ($kernel32::GetConsoleMode($h, [ref]$m)) {
                $kernel32::SetConsoleMode($h, $m -bor 4) | Out-Null  # ENABLE_VIRTUAL_TERMINAL_PROCESSING
            }
        }
    } catch {}
}

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
    (carapace _carapace | Out-String) -replace "$([char]27)\[[0-9;]*m", '' | Invoke-Expression
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
    # Ensure VT/ANSI processing is active before starship init.
    # VS Code's PowerShell extension pty may not set this, causing \x1b[0m to
    # print as literal text instead of being interpreted as an ANSI reset.
    $env:TERM = 'xterm-256color'
    Invoke-Expression (&starship init powershell)
}
