#!/usr/bin/env bash
# Uninstall dotfiles config and/or restore from backup.
# Usage:
#   bash uninstall.sh              # interactive menu
#   bash uninstall.sh --all        # remove symlinks + gitconfig.local + offer restore
#   bash uninstall.sh --restore    # restore from latest backup
#   bash uninstall.sh --restore 2026-04-15_143022  # restore specific backup

set -euo pipefail

BACKUP_ROOT="${HOME}/.dotfiles-backup"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
do_uninstall() {
    echo ""
    echo "=== Removing dotfiles config ==="

    local symlinks=("${HOME}/.gitconfig" "${HOME}/.gitattributes" "${HOME}/.bash_profile")
    for link in "${symlinks[@]}"; do
        if [[ -L "$link" ]]; then
            rm -f "$link"
            echo "→ Removed symlink: $link"
        elif [[ -e "$link" ]]; then
            echo "→ $link is not a symlink, skipping."
        fi
    done

    local local_config="${HOME}/.gitconfig.local"
    if [[ -f "$local_config" ]]; then
        read -rp "→ Remove $local_config (git identity)? [y/N] " remove_local
        if [[ "$remove_local" =~ ^[Yy] ]]; then
            rm -f "$local_config"
            echo "→ Removed: $local_config"
        fi
    fi
}

do_restore() {
    local timestamp="${1:-}"

    echo ""
    echo "=== Restoring from backup ==="

    if [[ ! -d "$BACKUP_ROOT" ]]; then
        echo "→ No backups found at $BACKUP_ROOT — nothing to restore."
        return
    fi

    mapfile -t backups < <(find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d | sort)

    if [[ ${#backups[@]} -eq 0 ]]; then
        echo "→ No backup folders found in $BACKUP_ROOT."
        return
    fi

    echo "Available backups:"
    for b in "${backups[@]}"; do
        echo "  $(basename "$b")"
    done
    echo ""

    local backup_dir
    if [[ -n "$timestamp" ]]; then
        backup_dir="${BACKUP_ROOT}/${timestamp}"
        if [[ ! -d "$backup_dir" ]]; then
            echo "Error: Backup '$timestamp' not found in $BACKUP_ROOT." >&2
            exit 1
        fi
    else
        backup_dir="${backups[-1]}"
        echo "→ Using latest backup: $(basename "$backup_dir")"
    fi

    declare -A dotfiles=(
        [".gitconfig"]="${HOME}/.gitconfig"
        [".gitattributes"]="${HOME}/.gitattributes"
        [".bash_profile"]="${HOME}/.bash_profile"
    )

    for name in "${!dotfiles[@]}"; do
        local target="${dotfiles[$name]}"
        local backup="${backup_dir}/${name}"

        if [[ ! -f "$backup" ]]; then
            echo "→ No backup for ${name}, skipping."
            continue
        fi

        if [[ -e "$target" || -L "$target" ]]; then
            rm -f "$target"
            echo "→ Removed: $target"
        fi

        cp "$backup" "$target"
        echo "→ Restored: $target"
        echo "        ← $backup"
    done
}

# ---------------------------------------------------------------------------
# Parse args
# ---------------------------------------------------------------------------
action=""
timestamp=""

case "${1:-}" in
    --all)     action="all" ;;
    --restore) action="restore"; timestamp="${2:-}" ;;
    "")        action="interactive" ;;
    *)
        echo "Usage: bash uninstall.sh [--all | --restore [timestamp]]" >&2
        exit 1
        ;;
esac

# ---------------------------------------------------------------------------
# Interactive menu
# ---------------------------------------------------------------------------
if [[ "$action" == "interactive" ]]; then
    echo "What to do?"
    echo "  1. Remove dotfiles config (symlinks + gitconfig.local)"
    echo "  2. Restore dotfiles from backup"
    echo "  3. Both (remove config then restore from backup)"
    echo "  4. Cancel"
    read -rp "  Choice [1-4]: " choice
    case "$choice" in
        1) action="uninstall" ;;
        2) action="restore" ;;
        3) action="all" ;;
        *) echo "→ Cancelled."; exit 0 ;;
    esac
fi

# ---------------------------------------------------------------------------
# Execute
# ---------------------------------------------------------------------------
case "$action" in
    uninstall)
        do_uninstall
        ;;
    restore)
        do_restore "$timestamp"
        ;;
    all)
        do_uninstall
        read -rp "→ Restore dotfiles from backup? [Y/n] " do_restore_prompt
        if [[ ! "$do_restore_prompt" =~ ^[Nn] ]]; then
            do_restore "$timestamp"
        fi
        ;;
esac

echo ""
echo "Done. Open a new shell to apply changes."
