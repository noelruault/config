# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Personal macOS dotfiles / machine-setup repo. Cloned to `~/config`, then `setup.sh` bootstraps a fresh machine. No build, no app, no package manager at the root. "Installing" means symlinking dotfiles into `$HOME`/`$HOME/.config`, installing Homebrew packages, and copying fonts.

The shell configuration under `zshrc/` is the largest and most-active subsystem and has **its own `zshrc/CLAUDE.md`** with a detailed load-order / router breakdown. Read that before editing anything under `zshrc/`. This root file covers the repo as a whole.

## Bootstrap (the "big picture")

`setup.sh` is the single entry point and only parses the command line. Everything it manages is a **component**: one file in `setup/components/<name>.sh` with an install step, a check step and an optional update step. `setup.sh init`, `setup.sh update` and `setup.sh doctor` walk the same ordered list, `COMPONENT_ORDER` in `setup/lib/registry.sh`, so nothing is installed by one command and forgotten by another. `--dry-run`, `--only a,b`, `--skip a,b` and `--yes` apply to all three; `setup.sh components` prints the list.

**Two stages.** `setup.sh` plus `setup/lib/{ui,platform,download,bootstrap-<os>}.sh` are stage 0: they run under whatever bash started them, including the 3.2 macOS ships, and only find or install Homebrew's bash 5 and re-exec under it. Everything else in `setup/` is written for bash 5. On a machine with no bash 5, `init` and `update` install it (their `--dry-run` says so and exits 0), while `doctor` and `components` report it missing and exit 1.

Order matters:

1. `config_link` moves a real `~/.config` to `~/.backup-config-<timestamp>` and **symlinks `~/.config` → this repo**. This is the keystone: after it, everything the repo exposes under `~/.config/...` is live-edited from the repo. `zshrc`/`zprofile` are sourced from there.
2. `homebrew`, then `packages`, which installs the root `Brewfile` with `brew bundle`. A new package is a `Brewfile` line, never a component. (`coreutils` matters: `zshrc/log` uses `gdate` for ms timing.)
3. `login_shell` lists Homebrew's bash in `/etc/shells`. `oh_my_zsh` installs oh-my-zsh, `zsh-syntax-highlighting`, `zsh-autosuggestions` and the `spaceship-prompt` theme. Note `zshrc/zshrc` defaults `ZSH_PROMPT=starship`; spaceship is the fallback.
4. `shell_rc`, `git_config`, `ssh_key`, `git_signing` ask first (default yes) and are skipped once already done. The last three source the interactive `git/*.sh` scripts, so they need a terminal.
5. `fonts`, `aispeak`, `loopctl`, `router` clone private repos, which is why they come after the SSH key. No access is a warning, not a failure.
6. `bin_links`, `quick_actions`, `default_editor` link `bin/` into `~/.local/bin`, the Finder Quick Actions, and the default-editor LaunchAgent.

Each component declares a platform (`all` or `darwin`) and whether it is `required` (a failure stops init and fails doctor) or `optional` (warn and continue). `setup/lib/platform.sh` is the only file that asks which OS this is; macOS-only commands live in `darwin` components. A Linux port adds components and a package list, not branches.

Every install step is safe to run again. Re-running `setup.sh` to pick up new steps is the expected workflow, not a fresh clone.

**Read `GUIDELINES.md` before changing shell code.** Its mechanical rules are enforced by `tests/test_slop.zsh` and `tests/test_setup.zsh`, locally and in CI (`.github/workflows/tests.yml`).

## What is and isn't tracked (critical gitignore mechanic)

`.gitignore` does `/*/ ` (ignore **all** root subdirectories) then un-ignores a whitelist:

```
/*/                 # ignore every top-level dir
!apps !rcs !bin !quick-actions !git !iterm2 !zshrc !nvim !tests !setup !.github
```

So only those directories (plus root files such as `Brewfile`) are version-controlled. Directories like `zed/`, `opencode/`, `gh/`, `uv/`, `github-copilot/`, `containers/`, `jira/`, `.jira/` exist on disk but are **ignored** — they are local-only or managed elsewhere. When adding a new tracked config area you must add a matching `!<dir>` line, or git silently ignores it.

`*secret*` is globally ignored. `zshrc/aliases/secrets/` is sensitive even where tracked — never echo or commit its contents.

## Repo layout (tracked areas only)

- `setup.sh` — command-line entry point (see above). `setup/lib/` holds the runner, registry, output helpers and platform probe; `setup/components/` holds one file per component.
- `Brewfile` — every Homebrew package and tap setup installs.
- `GUIDELINES.md` — code rules; the enforced ones are tests.
- `.github/workflows/tests.yml` — two jobs on GitHub-hosted macOS runners, on every push, pull request and weekly: `tests` runs `tests/run.sh`; `fresh-machine` starts with only bash 3.2 and runs a real `setup.sh init --yes`, `doctor`, a second `init`, `update`, then the suite again with every Brewfile tool installed.
- `zshrc/` — shell config subsystem. **Has its own CLAUDE.md.** Router-based loader (`routes`), aliases, offline notebook (`howto`), a Go helper at `scripts/glow-stream/`.
- `git/` — git setup scripts run by `setup.sh`: `git-config.sh` (user + `core.excludesfile`/`include.path` → `~/.config/git/gitignore_global`,`gitconfig_global`), `ssh-gen.sh`, `git-signing.sh` (SSH commit signing), `github-download.sh`, plus `gitconfig_global`, `gitignore_global`, `hooks/`, `ignore`.
- `code-editors/` — `vscode/`, `vim/`, `psql/` settings.
- `iterm2/` — profiles (`iterm-profiles.json`), keymap, color schemes, plist. `AppSupport` is re-ignored.
- `tests/` — zero-dependency zsh test suite. `tests/run.sh` runs every `tests/test_*.zsh` (each in its own `zsh -f`, sandboxed fake `$HOME`) plus glow-stream's `go test`. Run it after touching anything under `zshrc/`. New suite = new `tests/test_<name>.zsh` sourcing `tests/lib.zsh`; no registration step.

## Conventions

- Editing a tracked dotfile takes effect immediately via the `~/.config → ~/config` symlink; no copy step. Editing `zshrc/zshrc` needs `source ~/.zshrc` (or a new shell).
- A new install step is a new component (`GUIDELINES.md`, "Adding a setup component"); its install must be safe to run again and it needs a check step.
- New tracked config area → create the dir **and** add `!<dir>` to `.gitignore`.
- The `git/*.sh` scripts are `source`d in a subshell by `run_interactive_script` (not exec'd) and assume the `~/.config` symlink already exists.
- Run `tests/run.sh` before committing shell changes; `tests/test_syntax.zsh` parse-checks every tracked shell file, so even files without a dedicated suite get covered.

## Note on fonts

Fonts are commercially licensed, so they live in a private repo that the `fonts` component clones into the gitignored `.fonts/`. This repo is **public**: never commit a font file here. Removing one that slipped in needs a history purge (`git filter-repo`), not just a delete commit.
