#!/usr/bin/env bash
# Bootstrap dotfiles on Linux (minimal — git config only).
# No Windows-specific tools, no scoop, no font patching.
# For a rich shell experience on Linux, set up oh-my-zsh separately.

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="${HOME}/.dotfiles-backup/$(date +%Y-%m-%d_%H%M%S)"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
backup_and_link() {
    local target="$1"
    local source="$2"
    if [[ -e "$target" && ! -L "$target" ]]; then
        mkdir -p "$BACKUP_DIR"
        cp -a "$target" "$BACKUP_DIR/"
        echo "→ Backed up $(basename "$target") to $BACKUP_DIR"
    fi
    ln -sf "$source" "$target"
    echo "→ Linked $target"
}

# ---------------------------------------------------------------------------
# 1. Symlink git config
# ---------------------------------------------------------------------------
backup_and_link "${HOME}/.gitconfig"      "${DOTFILES_DIR}/git/.gitconfig"
backup_and_link "${HOME}/.gitattributes"  "${DOTFILES_DIR}/git/.gitattributes"

# ---------------------------------------------------------------------------
# 2. Symlink minimal bash profile
# ---------------------------------------------------------------------------
backup_and_link "${HOME}/.bash_profile"   "${DOTFILES_DIR}/bash/.bash_profile_linux"

# ---------------------------------------------------------------------------
# 3. Git identity — write ~/.gitconfig.local if absent
# ---------------------------------------------------------------------------
LOCAL_CONFIG="${HOME}/.gitconfig.local"
if [[ ! -f "$LOCAL_CONFIG" ]]; then
    echo ""
    read -rp "Git name  (e.g. Jane Doe): " git_name
    read -rp "Git email (e.g. jane@example.com): " git_email
    cat > "$LOCAL_CONFIG" <<EOF
[user]
	name = ${git_name}
	email = ${git_email}
EOF
    echo "→ Written $LOCAL_CONFIG"
else
    echo "→ $LOCAL_CONFIG already exists, skipping identity setup."
fi

echo ""
echo "Done. Open a new shell to pick up the git aliases."
echo "For a richer shell (prompt, completions, smart cd…) set up oh-my-zsh: https://ohmyz.sh"
