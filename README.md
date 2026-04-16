# dotfiles

Personal dotfiles and machine bootstrap for Windows and Linux.

## What's included

| Path | Purpose |
|---|---|
| `git/.gitconfig` | Git aliases, difftastic (inline diffs), VS Code/Beyond Compare (GUI diff/merge), mergiraf merge driver |
| `git/.gitattributes` | Applies mergiraf as the default merge driver for all files |
| `bash/.bash_profile` | Shell aliases, tool inits (carapace, zoxide, fzf, starship, eza, bat) |
| `powershell/profile.ps1` | PowerShell equivalent of `.bash_profile` — same aliases and tool inits |
| `starship/starship.toml` | Starship prompt configuration (git status, lang versions, duration) |

`~/.gitconfig.local` holds your name and email and is **never committed** — the bootstrap scripts create it interactively.

---

## Quick start

### Windows (PowerShell)

> Requires **Developer Mode** (`Settings > System > For developers`) **or** an elevated (Administrator) shell.

```powershell
git clone https://github.com/<you>/dotfiles.git "$HOME\dotfiles"
cd "$HOME\dotfiles"
.\bootstrap.ps1
```

What it does:
1. Installs Git, difftastic, delta, carapace, GitHub CLI, ripgrep, fd, and tldr via **winget** (skips any already on PATH)
2. Detects Beyond Compare — sets as default diff/merge tool if present, otherwise offers to install it
3. Optionally installs shell enhancement tools + jq/yq (prompted): starship, zoxide, fzf, eza, bat, lazygit, jq, yq
2. Installs **mergiraf** via scoop (or cargo binstall as fallback)
3. Prompts for your git identity and writes `~/.gitconfig.local`
4. Symlinks `~/.gitconfig`, `~/.gitattributes`, `~/.bash_profile`, PowerShell `$PROFILE`, and `~/.config/starship.toml` into this repo

### Linux (Bash)

```bash
git clone https://github.com/<you>/dotfiles.git ~/dotfiles
cd ~/dotfiles
bash bootstrap.sh
```

What it does:
1. Installs git, ripgrep, fd, jq, and tldr via **apt**; difftastic, carapace, and delta via cargo if not in apt
2. Optionally installs shell enhancement tools: starship, zoxide, fzf, eza, bat, lazygit (prompted)
2. Installs **mergiraf** via cargo binstall or cargo (falls back to a manual-install warning)
3. Prompts for your git identity and writes `~/.gitconfig.local`
4. Symlinks `~/.gitconfig`, `~/.gitattributes`, `~/.bash_profile`, and `~/.config/starship.toml` into this repo

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

### difftastic — syntax-aware inline diffs

Replaces the default `git diff` output. Understands code structure, so reformats and moved code don't show as noise.

```bash
git diff                  # uses difftastic automatically
git diff HEAD~3           # diff against 3 commits ago
git difftool              # opens VS Code side-by-side
git difftool -t bc        # opens Beyond Compare  (or: git dbc)
```

---

### delta — pager for git log and show

Adds syntax highlighting and line numbers to `git log -p`, `git show`, and `git blame` output in the terminal.

```bash
git log -p                # automatically paged through delta
git show HEAD             # diff of last commit, syntax-highlighted
git blame src/main.js     # highlighted blame view
```

---

### mergiraf — structured merge driver

Applied automatically to all files during `git merge` and `git rebase`. Uses the file's syntax tree to resolve conflicts that would otherwise require manual intervention (e.g. two branches adding different imports to the same block).

No manual steps needed — it runs transparently. If it can't resolve a conflict it falls back to the standard git conflict markers.

---

### carapace — shell completions

Provides tab-completions for hundreds of CLI tools (git, gh, docker, kubectl, cargo, …) in Bash.

```bash
git push <TAB>            # completes remote names and branches
gh pr <TAB>               # completes pr subcommands
```

---

### gh — GitHub CLI

Interact with GitHub without leaving the terminal.

```bash
gh repo clone owner/repo
gh pr create --fill        # create a PR from current branch
gh pr list                 # list open PRs
gh pr checkout 42          # check out PR #42 locally
gh issue list --assignee @me
gh issue create
gh run list                # list recent CI runs
gh run watch               # watch current branch CI in real time
```

---

### ripgrep (`rg`) — fast grep

Faster than `grep`, respects `.gitignore` by default.

```bash
rg "TODO"                  # search current directory recursively
rg "function foo" src/     # search within a folder
rg -t js "useState"        # search only JS files
rg -l "deprecated"         # list files containing a match
rg --no-ignore "secret"    # include gitignored files
```

---

### fd — fast find

Friendlier and faster than `find`, also respects `.gitignore`.

```bash
fd ".env"                  # find files named .env
fd -e ts                   # find all .ts files
fd -t d node_modules       # find directories named node_modules
fd "test" src/             # find files matching "test" under src/
fd -x wc -l                # run wc -l on every result
```

---

### jq — JSON processor

Query, filter, and format JSON in the terminal. Essential for API work, CI logs, and config files.

```bash
curl -s https://api.github.com/repos/owner/repo | jq '.stargazers_count'
jq '.dependencies | keys' package.json     # list all dependencies
jq 'select(.level == "error")' app.log     # filter log entries
jq -r '.[] | "\(.name): \(.version)"'     # custom formatted output
```

---

### yq — YAML processor

Same as jq but for YAML. Invaluable for Kubernetes, docker-compose, GitHub Actions, and any YAML config.

```bash
yq '.services.web.image' docker-compose.yml
yq '.jobs | keys' .github/workflows/ci.yml
yq -i '.version = "2.0"' config.yaml       # edit in-place
```

---

### tldr — simplified man pages

Practical examples for any command, one `tldr <command>` away. Much faster than `man`.

```bash
tldr tar
tldr git rebase
tldr docker
tldr ssh
```

---

### Shell aliases (`.bash_profile`)

| Alias | Replaces | Notes |
|---|---|---|
| `ls` | `eza --icons` | Coloured output with file icons |
| `ll` | `eza -la --icons --git` | Long listing with git status per file |
| `cat` | `bat --style=auto` | Syntax highlighting, line numbers, paging |
| `cd` | `zoxide (z)` | Smart jump — learns your most-used dirs |
| `..` / `...` / `....` | `cd ..` etc. | Quick directory traversal |
| `g` | `git` | |
| `lg` | `lazygit` | Full terminal git UI |

`fzf` keybindings (active after install):
- **`Ctrl+R`** — fuzzy search shell history
- **`Ctrl+T`** — fuzzy file picker, inserts path at cursor
- **`Alt+C`** — fuzzy `cd` into a subdirectory

All aliases are guarded with `command -v` / `Get-Command` — if a tool isn't installed the alias is simply not set, so the profile never errors on a minimal machine.

---

### starship — cross-shell prompt

Configured via `starship/starship.toml` (symlinked to `~/.config/starship.toml`). Shows git branch/status, language versions, last command duration, and exit code indicator. Works identically in Git Bash and PowerShell.

```
~/projects/dotfiles on  main ⇡1 ~2 via  v20.11 took 3s
❯
```

Install: `winget install Starship.Starship` / `cargo install starship`

---

### Optional tools (prompted during bootstrap)

The bootstrap scripts will ask whether to install these. They activate automatically via the shell profiles once installed:

| Tool | Why | winget / apt |
|---|---|---|
| [starship](https://starship.rs) | Cross-shell prompt with git status, lang versions, exit codes | `Starship.Starship` / curl installer |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | Smart `cd` replacement | `ajeetdsouza.zoxide` / `zoxide` |
| [fzf](https://github.com/junegunn/fzf) | Fuzzy finder — supercharges `Ctrl+R` history | `junegunn.fzf` / `fzf` |
| [eza](https://eza.rocks) | Modern `ls` with icons and git status | `eza-community.eza` / cargo |
| [bat](https://github.com/sharkdp/bat) | `cat` with syntax highlighting | `sharkdp.bat` / `bat` |
| [lazygit](https://github.com/jesseduffield/lazygit) | Full terminal git UI | `JesseDuffield.lazygit` / GitHub release |

---

## Prerequisites

### Windows
- Windows 10 1903+ or Windows 11 (winget is built in)
- Developer Mode **or** run PowerShell as Administrator (needed for symlinks)
- Optional: [scoop](https://scoop.sh) or [Rust/cargo](https://rustup.rs) for mergiraf

### Linux
- Debian/Ubuntu: apt + optionally [Rust/cargo](https://rustup.rs) for difftastic, carapace, and mergiraf
- Other distros: install git, difftastic, carapace, and mergiraf manually

---

## Restoring

Before replacing any existing dotfile, the bootstrap scripts automatically back it up to `~/.dotfiles-backup/<timestamp>/`. To undo the bootstrap:

**Windows:**
```powershell
.\restore.ps1
```

**Linux:**
```bash
bash restore.sh
```

Both scripts list all available backups and restore from the latest by default. To restore from a specific backup:

```powershell
.\restore.ps1 -BackupTimestamp 2026-04-15_143022
```
```bash
bash restore.sh 2026-04-15_143022
```

---

## Updating

Just `git pull` inside the repo — the symlinks mean dotfiles are updated immediately. Then re-run the bootstrap script only if you want to install newly added tools.

```powershell
cd "$HOME\dotfiles"
git pull
# optionally: .\bootstrap.ps1  (safe to re-run, already-installed items are skipped)
```

---

## Adding a new dotfile

1. Add the file to the appropriate subfolder in this repo (e.g. `bash/`, `git/`)
2. Add a `New-Symlink` / `symlink` call to both bootstrap scripts
3. Commit and push

---

## Notes

- **VS Code** is the default GUI diff/merge tool (`git difftool`, `git mergetool`). Beyond Compare 4 is defined as a named tool and the Windows bootstrap will ask if you want to install it. Switch to it any time with `git dbc` (diff) or `git mbc` (merge), or set it as default by changing `[diff] guitool` and `[merge] tool` in `.gitconfig`. BC is invoked via `bcomp` on PATH — the BC installer adds this automatically.