# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Personal macOS dotfiles / machine-setup repo. Cloned to `~/config`, then `setup.sh` bootstraps a fresh machine. No build, no app, no package manager at the root. "Installing" means symlinking dotfiles into `$HOME`/`$HOME/.config`, installing Homebrew packages, and copying fonts.

The shell configuration under `zshrc/` is the largest and most-active subsystem and has **its own `zshrc/CLAUDE.md`** with a detailed load-order / router breakdown. Read that before editing anything under `zshrc/`. This root file covers the repo as a whole.

## Bootstrap (the "big picture")

`setup.sh` is the single entry point. Order matters:

1. `backup_config` moves any existing `~/.config` to `~/.backup-config-<date>` (only if it is a real dir, not already a symlink).
2. `overwrite_config "$HOME/config" "$HOME/.config"` — **symlinks `~/.config` → `~/config`**. This is the keystone: after this, everything the repo exposes under `~/.config/...` is live-edited from the repo. `zshrc`/`zprofile` are sourced from there.
3. Installs Homebrew, latest `bash` (and `chsh`es to it), then brew packages: `git fzf coreutils shfmt shellcheck`. (`coreutils` matters: `zshrc/log` uses `gdate` for ms timing.)
4. Installs oh-my-zsh + plugins (`zsh-syntax-highlighting`, `zsh-autosuggestions`) + `spaceship-prompt` theme. Note `zshrc/zshrc` now defaults `ZSH_PROMPT=starship`; spaceship is the fallback.
5. `install_fonts` copies `fonts/**` into `~/Library/Fonts` (macOS only).
6. Prompts (default-yes) to symlink `~/.zshrc`/`~/.zprofile`, run `git/git-config.sh`, `git/ssh-gen.sh`, `git/git-signing.sh`.

`setup.sh` is idempotent by design — every install step guards on "already present". Re-running it to pick up new steps is the expected workflow, not a fresh clone.

## What is and isn't tracked (critical gitignore mechanic)

`.gitignore` does `/*/ ` (ignore **all** root subdirectories) then un-ignores a whitelist:

```
/*/                 # ignore every top-level dir
!code-editors !git !iterm2 !zshrc !fonts
```

So only `code-editors/`, `git/`, `iterm2/`, `zshrc/`, `fonts/` (plus root files) are version-controlled. Directories like `nvim/`, `zed/`, `opencode/`, `gh/`, `uv/`, `github-copilot/`, `containers/`, `jira/`, `.jira/` exist on disk but are **ignored** — they are local-only or managed elsewhere. When adding a new tracked config area you must add a matching `!<dir>` line, or git silently ignores it.

`*secret*` is globally ignored. `zshrc/aliases/secrets/` is sensitive even where tracked — never echo or commit its contents.

## Repo layout (tracked areas only)

- `setup.sh` — bootstrap orchestrator (see above).
- `zshrc/` — shell config subsystem. **Has its own CLAUDE.md.** Router-based loader (`routes`), aliases, offline notebook (`howto`), a Go helper at `scripts/glow-stream/`.
- `git/` — git setup scripts run by `setup.sh`: `git-config.sh` (user + `core.excludesfile`/`include.path` → `~/.config/git/gitignore_global`,`gitconfig_global`), `ssh-gen.sh`, `git-signing.sh` (SSH commit signing), `github-download.sh`, plus `gitconfig_global`, `gitignore_global`, `hooks/`, `ignore`.
- `code-editors/` — `vscode/`, `vim/`, `psql/` settings.
- `iterm2/` — profiles (`iterm-profiles.json`), keymap, color schemes, plist. `AppSupport` is re-ignored.
- `fonts/` — `Mono/` + `Other/` font files, copied to `~/Library/Fonts` by `setup.sh`. ~34 MB, 400+ files committed. See note below.
- `tests/` — zero-dependency zsh test suite. `tests/run.sh` runs every `tests/test_*.zsh` (each in its own `zsh -f`, sandboxed fake `$HOME`) plus glow-stream's `go test`. Run it after touching anything under `zshrc/`. New suite = new `tests/test_<name>.zsh` sourcing `tests/lib.zsh`; no registration step.

## Conventions

- Editing a tracked dotfile takes effect immediately via the `~/.config → ~/config` symlink; no copy step. Editing `zshrc/zshrc` needs `source ~/.zshrc` (or a new shell).
- New install steps go in `setup.sh` and must guard on "already installed" to keep it idempotent.
- New tracked config area → create the dir **and** add `!<dir>` to `.gitignore`.
- The `git/*.sh` scripts are `source`d by `setup.sh` (not exec'd) and assume the `~/.config` symlink already exists.
- Run `tests/run.sh` before committing shell changes; `tests/test_syntax.zsh` parse-checks every tracked shell file, so even files without a dedicated suite get covered.

## Note on fonts

`fonts/` is committed into this repo. The repo is currently **public**, so any non-freely-licensed fonts there are publicly exposed (including in history). If asked to manage fonts, treat licensed/paid fonts as sensitive: relocating them to a private repo requires both moving the files and purging git history (`git filter-repo`), not just a delete commit.
