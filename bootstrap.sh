#!/usr/bin/env bash
# Bootstrap a new Linux machine from the dotfiles repository.
# Usage: bash bootstrap.sh

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# 1. Detect package manager and install tools
# ---------------------------------------------------------------------------
install_packages() {
    if command -v apt-get &>/dev/null; then
        echo "→ Installing tools via apt..."
        sudo apt-get update -q
        sudo apt-get install -y git ripgrep fd-find jq tldr

        if ! command -v difft &>/dev/null; then
            if command -v cargo &>/dev/null; then
                echo "→ Installing difftastic via cargo..."
                cargo install difftastic
            else
                echo "WARNING: difftastic not available via apt and cargo not found."
                echo "  Install Rust (https://rustup.rs) then run: cargo install difftastic"
            fi
        fi

        if ! command -v carapace &>/dev/null; then
            if command -v cargo &>/dev/null; then
                echo "→ Installing carapace via cargo..."
                cargo install carapace-bin
            else
                echo "WARNING: carapace not available via apt and cargo not found."
                echo "  Install Rust (https://rustup.rs) then run: cargo install carapace-bin"
            fi
        fi

        if ! command -v delta &>/dev/null; then
            if command -v cargo &>/dev/null; then
                echo "→ Installing delta via cargo..."
                cargo install git-delta
            else
                echo "WARNING: delta not available via apt and cargo not found."
                echo "  Install Rust (https://rustup.rs) then run: cargo install git-delta"
            fi
        fi

        # fd is installed as fdfind on Debian/Ubuntu — create a local symlink
        if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
            mkdir -p "$HOME/.local/bin"
            ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
            echo "→ Linked fdfind → ~/.local/bin/fd"
        fi
    else
        echo "WARNING: No supported package manager found (apt). Install git, ripgrep, fd, difftastic, carapace, delta, jq, tldr, and yq manually."
    fi
}

install_packages

# ---------------------------------------------------------------------------
# 2. Install mergiraf (no standard package — use cargo binstall or cargo)
# ---------------------------------------------------------------------------
if command -v mergiraf &>/dev/null; then
    echo "→ mergiraf already installed, skipping."
elif command -v cargo-binstall &>/dev/null; then
    echo "→ Installing mergiraf via cargo binstall..."
    cargo binstall --no-confirm mergiraf
elif command -v cargo &>/dev/null; then
    echo "→ Installing mergiraf via cargo (this may take a few minutes)..."
    cargo install --locked mergiraf
else
    echo "WARNING: mergiraf could not be installed automatically."
    echo "  Install Rust (https://rustup.rs) then run: cargo binstall mergiraf"
    echo "  Or download a binary from: https://codeberg.org/mergiraf/mergiraf/releases"
fi

# ---------------------------------------------------------------------------
# 2b. Optionally install shell enhancement tools
# ---------------------------------------------------------------------------
echo ""
read -rp "→ Install shell enhancement tools (starship, zoxide, fzf, eza, bat, lazygit)? [y/N] " install_shell
if [[ "$install_shell" =~ ^[Yy] ]]; then
    # starship
    if command -v starship &>/dev/null; then
        echo "→ starship already installed, skipping."
    else
        echo "→ Installing starship..."
        curl -sS https://starship.rs/install.sh | sh -s -- --yes
    fi

    # zoxide
    if command -v zoxide &>/dev/null; then
        echo "→ zoxide already installed, skipping."
    elif command -v apt-get &>/dev/null; then
        sudo apt-get install -y zoxide
    fi

    # fzf
    if command -v fzf &>/dev/null; then
        echo "→ fzf already installed, skipping."
    elif command -v apt-get &>/dev/null; then
        sudo apt-get install -y fzf
    fi

    # eza (not in apt — install via cargo)
    if command -v eza &>/dev/null; then
        echo "→ eza already installed, skipping."
    elif command -v cargo &>/dev/null; then
        echo "→ Installing eza via cargo..."
        cargo install eza
    else
        echo "WARNING: eza requires cargo. Install Rust (https://rustup.rs) then run: cargo install eza"
    fi

    # bat
    if command -v bat &>/dev/null; then
        echo "→ bat already installed, skipping."
    elif command -v apt-get &>/dev/null; then
        sudo apt-get install -y bat
        # bat may be installed as batcat on Debian/Ubuntu
        if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
            mkdir -p "$HOME/.local/bin"
            ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
            echo "→ Linked batcat → ~/.local/bin/bat"
        fi
    fi

    # lazygit
    if command -v lazygit &>/dev/null; then
        echo "→ lazygit already installed, skipping."
    elif command -v apt-get &>/dev/null; then
        LAZYGIT_VERSION=$(curl -s https://api.github.com/repos/jesseduffield/lazygit/releases/latest | jq -r '.tag_name' | tr -d 'v')
        curl -sLo /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
        tar -xf /tmp/lazygit.tar.gz -C /tmp lazygit
        sudo install /tmp/lazygit /usr/local/bin
        echo "→ Installed lazygit $LAZYGIT_VERSION"
    fi
else
    echo "→ Skipping shell tools. Install any time — they activate automatically via .bash_profile."
fi

# ---------------------------------------------------------------------------
# 3. Write ~/.gitconfig.local with git identity (not committed to repo)
# ---------------------------------------------------------------------------
if [[ -f "$HOME/.gitconfig.local" ]]; then
    echo "→ ~/.gitconfig.local already exists, skipping identity prompt."
else
    echo ""
    echo "Git identity (will be written to ~/.gitconfig.local, NOT committed):"
    read -rp "  user.name:  " git_name
    read -rp "  user.email: " git_email
    cat > "$HOME/.gitconfig.local" <<EOF
[user]
	name = $git_name
	email = $git_email
EOF
    echo "→ Written: ~/.gitconfig.local"
fi

# ---------------------------------------------------------------------------
# 4. Symlink dotfiles (backing up any real file first)
# ---------------------------------------------------------------------------
BACKUP_DIR="$HOME/.dotfiles-backup/$(date '+%Y-%m-%d_%H%M%S')"

symlink() {
    local src="$1"
    local dst="$2"

    if [[ -e "$dst" || -L "$dst" ]]; then
        # Already a symlink pointing to this repo — nothing to do
        if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
            echo "→ Already linked: $dst"
            return
        fi
        # Real file (or symlink elsewhere) — back it up before replacing
        mkdir -p "$BACKUP_DIR"
        cp -P "$dst" "$BACKUP_DIR/$(basename "$dst")"
        echo "→ Backed up: $dst"
        echo "          → $BACKUP_DIR/$(basename "$dst")"
        rm -f "$dst"
    fi

    ln -s "$src" "$dst"
    echo "→ Linked: $dst"
    echo "       → $src"
}

symlink "$DOTFILES_DIR/git/.gitconfig"      "$HOME/.gitconfig"
symlink "$DOTFILES_DIR/git/.gitattributes"  "$HOME/.gitattributes"
symlink "$DOTFILES_DIR/bash/.bash_profile"  "$HOME/.bash_profile"

# Starship config — apply catppuccin-powerline preset directly (no symlink needed)
mkdir -p "$HOME/.config"
if command -v starship &>/dev/null; then
    starship preset catppuccin-powerline -o "$HOME/.config/starship.toml"
    echo "→ Starship: catppuccin-powerline preset applied."
else
    echo "→ starship not found — skipping preset. Run bootstrap again after installing starship."
fi

# ---------------------------------------------------------------------------
echo ""
echo "Bootstrap complete. Open a new shell session to apply changes."
