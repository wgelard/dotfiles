#!/usr/bin/env bash
# Restore dotfiles from a backup created by bootstrap.sh.
# Usage: bash restore.sh [timestamp]
# Timestamp format: 2026-04-15_143022 (defaults to most recent)

set -euo pipefail

BACKUP_ROOT="${HOME}/.dotfiles-backup"

if [[ ! -d "$BACKUP_ROOT" ]]; then
    echo "Error: No backups found at $BACKUP_ROOT — nothing to restore." >&2
    exit 1
fi

# List available backups (sorted)
mapfile -t backups < <(find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d | sort)

if [[ ${#backups[@]} -eq 0 ]]; then
    echo "Error: No backup folders found in $BACKUP_ROOT." >&2
    exit 1
fi

echo "Available backups:"
for b in "${backups[@]}"; do
    echo "  $(basename "$b")"
done
echo ""

# Pick backup to restore from
if [[ -n "${1:-}" ]]; then
    BACKUP_DIR="${BACKUP_ROOT}/$1"
    if [[ ! -d "$BACKUP_DIR" ]]; then
        echo "Error: Backup '$1' not found in $BACKUP_ROOT." >&2
        exit 1
    fi
else
    BACKUP_DIR="${backups[-1]}"
    echo "→ Using latest backup: $(basename "$BACKUP_DIR")"
fi

# Files managed by bootstrap.sh
declare -A dotfiles=(
    [".gitconfig"]="${HOME}/.gitconfig"
    [".gitattributes"]="${HOME}/.gitattributes"
    [".bash_profile"]="${HOME}/.bash_profile"
)

for name in "${!dotfiles[@]}"; do
    target="${dotfiles[$name]}"
    backup="${BACKUP_DIR}/${name}"

    if [[ ! -f "$backup" ]]; then
        echo "→ No backup for ${name}, skipping."
        continue
    fi

    # Remove existing symlink or file
    if [[ -e "$target" || -L "$target" ]]; then
        rm -f "$target"
        echo "→ Removed: $target"
    fi

    cp "$backup" "$target"
    echo "→ Restored: $target"
    echo "        ← $backup"
done

echo ""
echo "Restore complete."
