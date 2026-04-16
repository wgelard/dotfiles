[[ -f ~/.bashrc ]] && source ~/.bashrc

# ---------------------------------------------------------------------------
# delta — use as git pager only when available
# ---------------------------------------------------------------------------
if command -v delta &>/dev/null; then
    export GIT_PAGER='delta'
    export GIT_EXTERNAL_DIFF='delta'
fi

# ---------------------------------------------------------------------------
# Shell completions (carapace)
# ---------------------------------------------------------------------------
export CARAPACE_BRIDGES='zsh,fish,bash,inshellisense'
source <(carapace _carapace)

# ---------------------------------------------------------------------------
# Better defaults — replace built-ins with modern alternatives
# ---------------------------------------------------------------------------
command -v eza  &>/dev/null && alias ls='eza --icons'
command -v eza  &>/dev/null && alias ll='eza -la --icons --git'
command -v bat  &>/dev/null && alias cat='bat --style=auto'
command -v zoxide &>/dev/null && eval "$(zoxide init bash)" && alias cd='z'

# ---------------------------------------------------------------------------
# Navigation shortcuts
# ---------------------------------------------------------------------------
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# ---------------------------------------------------------------------------
# Git shortcuts (complements git aliases in .gitconfig)
# ---------------------------------------------------------------------------
alias g='git'
alias lg='lazygit'

# ---------------------------------------------------------------------------
# ripgrep / fd
# ---------------------------------------------------------------------------
# fd is installed as fdfind on Debian/Ubuntu — prefer fd if both exist
command -v fdfind &>/dev/null && ! command -v fd &>/dev/null && alias fd='fdfind'

# ---------------------------------------------------------------------------
# fzf — fuzzy finder (Ctrl+R history, Ctrl+T file picker, Alt+C cd)
# ---------------------------------------------------------------------------
if command -v fzf &>/dev/null; then
    eval "$(fzf --bash)"
    # Use fd for fzf file listing (respects .gitignore)
    if command -v fd &>/dev/null || command -v fdfind &>/dev/null; then
        export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
        export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
        export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
    fi
fi

# ---------------------------------------------------------------------------
# Starship prompt
# ---------------------------------------------------------------------------
command -v starship &>/dev/null && eval "$(starship init bash)"
