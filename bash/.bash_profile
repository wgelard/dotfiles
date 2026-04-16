[[ -f ~/.bashrc ]] && source ~/.bashrc

# ---------------------------------------------------------------------------
# delta — use as git pager only when available
# ---------------------------------------------------------------------------
if command -v delta &>/dev/null; then
    export GIT_PAGER='delta'
fi

# ---------------------------------------------------------------------------
# Shell completions (carapace)
# ---------------------------------------------------------------------------
if command -v carapace &>/dev/null; then
    export CARAPACE_BRIDGES='zsh,fish,bash,inshellisense'
    source <(carapace _carapace)
fi

# ---------------------------------------------------------------------------
# Better defaults — replace built-ins with modern alternatives
# ---------------------------------------------------------------------------
command -v eza  &>/dev/null && alias ls='eza --icons'
command -v eza  &>/dev/null && alias ll='eza -la --icons --git'
command -v bat  &>/dev/null && alias cat='bat --style=auto'

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
command -v lazygit &>/dev/null && alias lg='lazygit'

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
# Starship prompt (must be second-to-last — before zoxide)
# ---------------------------------------------------------------------------
command -v starship &>/dev/null && eval "$(starship init bash)"

# ---------------------------------------------------------------------------
# zoxide — must be initialised last
# ---------------------------------------------------------------------------
if command -v zoxide &>/dev/null; then
    eval "$(zoxide init bash)"
    alias cd='z'
fi
