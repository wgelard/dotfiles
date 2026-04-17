#!/usr/bin/env bash
# Bootstrap dotfiles on Linux (minimal — git config + essential tools).
# No Windows-specific tools, no scoop, no font patching, no Beyond Compare.
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

command_exists() {
    command -v "$1" &>/dev/null
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
# 3. Check for difftastic
# ---------------------------------------------------------------------------
echo ""
if command_exists difft; then
    echo "→ difftastic already installed."
else
    echo "→ difftastic not found. Install it for syntax-aware diffs:"
    echo "    brew install difftastic"
    echo "    cargo install difftastic"
    echo "    https://difftastic.wilfred.me.uk/"
fi

# ---------------------------------------------------------------------------
# 4. Check for mergiraf
# ---------------------------------------------------------------------------
if command_exists mergiraf; then
    echo "→ mergiraf already installed."
else
    echo "→ mergiraf not found. Install it for structured merge support:"
    echo "    cargo binstall mergiraf"
    echo "    https://codeberg.org/mergiraf/mergiraf/releases"
fi

# ---------------------------------------------------------------------------
# 5. Git identity — write ~/.gitconfig.local if absent
# ---------------------------------------------------------------------------
LOCAL_CONFIG="${HOME}/.gitconfig.local"
if [[ -f "$LOCAL_CONFIG" ]]; then
    existing_name=$(grep -oP '^\s*name\s*=\s*\K.+' "$LOCAL_CONFIG" 2>/dev/null || true)
    existing_email=$(grep -oP '^\s*email\s*=\s*\K.+' "$LOCAL_CONFIG" 2>/dev/null || true)

    if [[ -n "$existing_name" && -n "$existing_email" ]]; then
        echo ""
        echo "→ Found existing git identity in $LOCAL_CONFIG:"
        echo "    name:  $existing_name"
        echo "    email: $existing_email"
        read -rp "  Is this correct? [Y/n] " confirm
        if [[ "$confirm" =~ ^[Nn] ]]; then
            read -rp "Git name  (e.g. Jane Doe): " git_name
            read -rp "Git email (e.g. jane@example.com): " git_email
            # Replace [user] block in-place
            tmpfile=$(mktemp)
            awk -v name="$git_name" -v email="$git_email" '
                /^\[user\]/ { print "[user]"; print "\tname = " name; print "\temail = " email; skip=1; next }
                skip && /^\[/ { skip=0 }
                !skip { print }
            ' "$LOCAL_CONFIG" > "$tmpfile"
            mv "$tmpfile" "$LOCAL_CONFIG"
            echo "→ Updated: $LOCAL_CONFIG"
        fi
    else
        echo ""
        echo "→ $LOCAL_CONFIG exists but has no git identity — prompting now."
        read -rp "Git name  (e.g. Jane Doe): " git_name
        read -rp "Git email (e.g. jane@example.com): " git_email
        cat >> "$LOCAL_CONFIG" <<EOF

[user]
	name = ${git_name}
	email = ${git_email}
EOF
        echo "→ Appended identity to $LOCAL_CONFIG"
    fi
else
    echo ""
    read -rp "Git name  (e.g. Jane Doe): " git_name
    read -rp "Git email (e.g. jane@example.com): " git_email
    cat > "$LOCAL_CONFIG" <<EOF
[user]
	name = ${git_name}
	email = ${git_email}
EOF
    echo "→ Written $LOCAL_CONFIG"
fi

echo ""
echo "Done. Open a new shell to pick up the git aliases."
echo "For a richer shell (prompt, completions, smart cd…) set up oh-my-zsh: https://ohmyz.sh"
