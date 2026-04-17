# dotfiles

Personal dotfiles with fully automatic bootstrap for Windows (Git Bash + PowerShell) and minimal setup for Linux.

## What's included

| Path | Purpose |
|---|---|
| `bootstrap.ps1` | Orchestrator — runs core setup then offers optional tool groups |
| `uninstall.ps1` | Remove optional tools and/or restore from backup |
| `bootstrap.sh` | Linux bootstrap — symlinks, difftastic/mergiraf check, identity |
| `uninstall.sh` | Linux uninstall — remove config and/or restore from backup |
| `lib/helpers.ps1` | Shared functions (winget install/uninstall, symlinks, PATH refresh) |
| `lib/setup.ps1` | Core tools + git config + symlinks + identity prompt |
| `git/.gitconfig` | Git aliases, difftastic (inline diffs), VS Code/Beyond Compare (GUI diff/merge), mergiraf merge driver |
| `git/.gitattributes` | Applies mergiraf as the default merge driver for all files |
| `bash/.bash_profile` | Shell aliases, tool inits (carapace, zoxide, fzf, starship, eza, bat) — used in Git Bash |
| `bash/.bash_profile_linux` | Minimal Linux profile — git aliases and lazygit only |
| `powershell/profile.ps1` | PowerShell profile — same aliases and tool inits as Git Bash |

`~/.gitconfig.local` holds your name, email, and machine-specific settings (e.g. BC path) — **never committed**.

---

## Quick start

### Windows

> Requires **Developer Mode** (`Settings > System > For developers`) **or** an elevated (Administrator) shell.

```powershell
git clone https://github.com/<you>/dotfiles.git "$HOME\dotfiles"
cd "$HOME\dotfiles"
.\bootstrap.ps1
```

What it does (`lib/setup.ps1` — core):
1. Installs Git, VS Code, difftastic, delta, carapace, GitHub CLI, ripgrep, fd, and tldr via **winget** (skips any already on PATH)
2. Detects Beyond Compare — sets as default diff/merge tool if present, otherwise offers to install it
3. Installs **mergiraf** via scoop (or cargo binstall as fallback)
4. Fetches git identity from your chosen provider (GitHub.com, GitHub Enterprise, GitLab, or manual) and writes `~/.gitconfig.local`
5. Symlinks `~/.gitconfig`, `~/.gitattributes`, and `~/.bash_profile` into this repo
6. Writes a dot-source stub to PowerShell profiles (PS5 + PS7) — avoids OneDrive symlink issues

Then asks about optional groups:

7. Productivity tools (zoxide, fzf, lazygit) — only asks if something is missing
8. Visual tools (starship, eza, bat, FiraCode Nerd Font) — skip on work machines if needed
9. Applies the **Catppuccin Powerline** starship preset to `~/.config/starship.toml` (visual group only)

### Linux

Only git config — no Windows-specific tools, no scoop, no font patching.

```bash
git clone https://github.com/<you>/dotfiles.git ~/dotfiles
cd ~/dotfiles
bash bootstrap.sh
```

What it does:
1. Symlinks `~/.gitconfig` and `~/.gitattributes`
2. Symlinks a minimal `~/.bash_profile` — git aliases (`g`, `lg`) and optional lazygit
3. Checks for difftastic and mergiraf — shows install hints if missing
4. Prompts for git identity if `~/.gitconfig.local` is absent (or shows existing identity for confirmation)

No starship on Linux — use [oh-my-zsh](https://ohmyz.sh) or your preferred zsh setup independently.

---

## Tools

### Git aliases

| Alias | Command | Description |
|---|---|---|
| `git lg` | `log --graph` | Visual commit graph with author, date, refs |
| `git st` | `status` | |
| `git co <branch>` | `checkout` | |
| `git cob <branch>` | `checkout -b` | Create and switch to new branch |
| `git sw <branch>` | `switch` | Modern replacement for `co` |
| `git swc <branch>` | `switch -c` | Modern replacement for `cob` |
| `git c` | `commit` | |
| `git p` | `push` | |
| `git pushf` | `push --force-with-lease` | Safe force-push — refuses if someone else pushed |
| `git f` | `fetch -p` | Fetch and prune deleted remote branches |
| `git b` | `branch -vv` | Local branches with tracking info |
| `git ba` | `branch -a` | All branches including remotes |
| `git bd` / `git bD` | `branch -d/-D` | Delete branch (safe / force) |
| `git dc` | `diff --cached` | Diff staged changes |
| `git undo` | `reset --soft HEAD~1` | Undo last commit, keep changes staged |
| `git unstage <file>` | `restore --staged` | Unstage a file |
| `git amend` | `commit --amend --no-edit` | Amend last commit without changing the message |
| `git rbi HEAD~<n>` | `rebase -i` | Interactive rebase — squash, reorder, edit last n commits |
| `git rbc` | `rebase --continue` | Continue rebase after resolving conflicts |
| `git rba` | `rebase --abort` | Bail out of a rebase |
| `git cp <hash>` | `cherry-pick` | Apply a single commit onto current branch |
| `git stash-all` | `stash push --include-untracked` | Stash everything including new untracked files |
| `git wt` | `worktree` | Manage worktrees |
| `git wta <path> -b <branch>` | `worktree add` | Create a new worktree on a new branch |
| `git root` | `rev-parse --show-toplevel` | Print repo root path |
| `git aliases` | `config --get-regexp alias` | List all aliases |
| `git merges` | `log --merges` | Show only merge commits |
| `git dbc` | `difftool -t bc` | Open diff in Beyond Compare |
| `git mbc` | `mergetool -t bc` | Resolve conflicts in Beyond Compare |

---

### [difftastic](https://difftastic.wilfred.me.uk/) — syntax-aware inline diffs

Replaces the default `git diff` output. Understands code structure, so reformats and moved code don't show as noise.

```bash
git diff                  # uses difftastic automatically
git diff HEAD~3           # diff against 3 commits ago
git difftool              # opens VS Code side-by-side
git difftool -t bc        # opens Beyond Compare  (or: git dbc)
```

---

### [delta](https://dandavison.github.io/delta/) — pager for git log and show

Adds syntax highlighting and line numbers to `git log -p`, `git show`, and `git blame` output. Activated automatically via `GIT_PAGER` in the shell profile when delta is on PATH.

```bash
git log -p                # automatically paged through delta
git show HEAD             # diff of last commit, syntax-highlighted
```

---

### [mergiraf](https://codeberg.org/mergiraf/mergiraf) — structured merge driver

Applied automatically to all files during `git merge` and `git rebase`. Uses the file's syntax tree to resolve conflicts that would otherwise require manual intervention.

No manual steps needed — it runs transparently. Falls back to standard git conflict markers if it can't resolve.

---

### [carapace](https://carapace.sh/) — shell completions

Provides tab-completions for hundreds of CLI tools (git, gh, docker, kubectl, cargo, …) in both Bash and PowerShell.

```bash
git push <TAB>            # completes remote names and branches
gh pr <TAB>               # completes pr subcommands
```

---

### [gh](https://cli.github.com/) — GitHub CLI

```bash
gh repo clone owner/repo
gh pr create --fill
gh pr list
gh pr checkout 42
gh issue list --assignee @me
gh run watch
```

---

### [ripgrep](https://github.com/BurntSushi/ripgrep) (`rg`) — fast grep

```bash
rg "TODO"
rg -t js "useState"
rg -l "deprecated"
```

---

### [fd](https://github.com/sharkdp/fd) — fast find

```bash
fd ".env"
fd -e ts
fd "test" src/
```

---

### [tldr](https://tldr.sh/) — simplified man pages

```bash
tldr tar
tldr git rebase
tldr docker
```

---

### Shell aliases

| Alias | Replaces | Notes |
|---|---|---|
| `ls` | `eza --icons` | Coloured output with file icons (requires Nerd Font) |
| `ll` | `eza -la --icons --git` | Long listing with git status per file |
| `cat` | `bat --style=auto` | Syntax highlighting, line numbers, paging |
| `cd` | `zoxide (z)` | Smart jump — learns your most-used dirs |
| `..` / `...` / `....` | `cd ..` etc. | Quick directory traversal |
| `g` | `git` | |
| `lg` | `lazygit` | Full terminal git UI |

`fzf` keybindings:
- **`Ctrl+R`** — fuzzy search shell history
- **`Ctrl+T`** — fuzzy file picker
- **`Alt+C`** — fuzzy `cd` into a subdirectory

---

### [starship](https://starship.rs/) — cross-shell prompt

[Catppuccin Powerline](https://starship.rs/presets/catppuccin-powerline) preset applied automatically by the bootstrap. Works in both Git Bash and PowerShell. Requires **FiraCode Nerd Font** (also installed by the bootstrap).

To switch flavour, edit `~/.config/starship.toml` and change `palette = 'catppuccin_mocha'` to `catppuccin_frappe`, `catppuccin_macchiato`, or `catppuccin_latte`.

---

### Optional tools (prompted during bootstrap)

| Tool | Why | winget ID |
|---|---|---|
| [starship](https://starship.rs) | Cross-shell prompt | `Starship.Starship` |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | Smart `cd` replacement | `ajeetdsouza.zoxide` |
| [fzf](https://github.com/junegunn/fzf) | Fuzzy finder | `junegunn.fzf` |
| [eza](https://eza.rocks) | Modern `ls` | `eza-community.eza` |
| [bat](https://github.com/sharkdp/bat) | `cat` with syntax highlighting | `sharkdp.bat` |
| [lazygit](https://github.com/jesseduffield/lazygit) | Terminal git UI | `JesseDuffield.lazygit` |

---

## Prerequisites

- Windows 10 1903+ or Windows 11 (winget built-in)
- Developer Mode **or** run PowerShell as Administrator (needed for symlinks)
- [scoop](https://scoop.sh) is installed automatically by the bootstrap if not present (needed for FiraCode NF and mergiraf)

### Enabling Developer Mode (recommended)

Allows symlinks without admin. One-time setup:

1. Open **Settings** → **System** → **For developers** (or search "developer settings")
2. Toggle **Developer Mode** on
3. Confirm the UAC prompt

Then run the bootstrap from a normal (non-elevated) PowerShell.

### Alternative: run as Administrator

If you can't enable Developer Mode (e.g. managed corporate machine):

1. Right-click **Windows Terminal** or **PowerShell** → **Run as administrator**
2. Run the bootstrap from that elevated session

> **Note:** Some winget packages (e.g. starship, which uses an MSI installer) require elevation to *uninstall* even if they installed without it. If `uninstall.ps1` fails to remove them, re-run it from an elevated shell.

---

## Uninstalling & restoring

Before replacing any existing dotfile, the bootstrap automatically backs it up to `~/.dotfiles-backup/<timestamp>/`.

### Windows

```powershell
.\uninstall.ps1           # interactive menu — guides you through options
.\uninstall.ps1 -All      # remove all optional tools + undo config + offer backup restore
```

#### All options

```powershell
.\uninstall.ps1 -Productivity                                # remove zoxide, fzf, lazygit
.\uninstall.ps1 -Visual                                       # remove starship, eza, bat + revert fonts
.\uninstall.ps1 -All                                          # remove all optional tools + undo config + offer backup restore
.\uninstall.ps1 -Restore                                      # restore dotfiles from latest backup
.\uninstall.ps1 -Restore -BackupTimestamp 2026-04-15_143022    # restore from specific backup
```

> Core tools (git, VS Code, Beyond Compare, difftastic, delta, carapace, gh, ripgrep, fd, tldr, mergiraf) are **not removed** by `uninstall.ps1`.

### Linux

```bash
bash uninstall.sh              # interactive menu
bash uninstall.sh --all        # remove config + offer backup restore
bash uninstall.sh --restore    # restore from latest backup
bash uninstall.sh --restore 2026-04-15_143022  # specific backup
```

---

## Updating

### Windows

```powershell
cd "$HOME\dotfiles"
git pull
.\bootstrap.ps1          # safe to re-run — already-installed items are skipped
```

### Linux

```bash
cd ~/dotfiles
git pull
bash bootstrap.sh
```

---

## Adding a new dotfile

1. Add the file to the appropriate subfolder (`git/`, `bash/`, `powershell/`)
2. Add a `New-DotfilesSymlink` call in `lib/setup.ps1`
3. Commit and push

---

## Notes

- **VS Code** is the default GUI diff/merge tool. Beyond Compare 4 is detected automatically and set as default if present (via full path in `~/.gitconfig.local`). Switch manually with `git dbc` (diff) or `git mbc` (merge).
- `~/.gitconfig.local` is created by the bootstrap and holds your identity + BC config. It is listed in `.gitignore` and never committed.
