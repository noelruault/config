# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Personal zsh / macOS shell configuration. Sourced from `~/.zshrc` and `~/.zprofile` (those live in `$HOME`, this repo lives at `~/config/zshrc` and is symlinked / sourced from there). No build, no tests, no package manager. Edits take effect after `source ~/.zshrc` or starting a new shell.

## Load order (the "big picture")

Understanding what runs when is the main thing a future agent needs:

1. `~/.zprofile` → mirrors `zprofile` in this repo. Sets PATH for Homebrew, Go (`$(go env GOPATH)/bin`), Bun, OrbStack. Runs once per login shell.
2. `~/.zshrc` → mirrors `zshrc` in this repo. Runs per interactive shell. It:
   - Sources `log` first so `timelogger` is available, then wraps the whole startup in `timelogger zsh start … end` to print boot timing.
   - Declares oh-my-zsh `plugins=(…)` and sources `~/.oh-my-zsh/oh-my-zsh.sh`. Plugins listed there (e.g. `fzf`, `zsh-autosuggestions`, `zsh-syntax-highlighting`, `golang`, `zoxide`) must be installed separately, oh-my-zsh does not auto-install them.
   - Sources `routes`, which is the dispatcher.
3. `routes` sets seven exported path vars (`ZSH`, `ZSH_CUSTOM`, `ZSH_CUSTOM_CONFIG_FILES`, `ZSH_CUSTOM_CONFIG_ALIASES`, `ZSH_CUSTOM_CONFIG_TEMPLATES`, `ZSH_CUSTOM_CONFIG_NOTEBOOK`, `ZSH_CUSTOM_CONFIG_SCRIPTS`) and, for each, sources `$DIR/init` if present (templates, notebook.d, and scripts have no `init`, so nothing is sourced for those). So:
   - `config/init` sources everything under `config/helpers/` (iTerm2 shell integration, `fix_zsh`, `default`).
   - `aliases/init` sources all non-`_`-prefixed files under `aliases/utils/`, then `aliases/os/macos` (or skips on non-Darwin), then everything under `aliases/secrets/`.
4. `routes` then unconditionally sources `aliases/integrations/docker`. Other integrations (`kubernetes`, `javascript`, `gcloud`) are commented out and opt-in by uncommenting in `routes`.

Net effect: any file added under `aliases/utils/` (without a `_` prefix) or `aliases/integrations/docker/` is auto-loaded on next shell start. Files prefixed with `_` are skipped by the loader. Project starter templates live at the repo root under `templates/_<name>/` (outside `aliases/`) and are exported as `$ZSH_CUSTOM_CONFIG_TEMPLATES`.

## Design intent

Three concerns kept deliberately separate:

1. **Router** (`routes`) — single dispatcher that decides what gets loaded. No business logic lives here, only path declarations and the `init` walk. Anything new should plug into the router's conventions rather than be sourced directly from `zshrc`.
2. **OS portability** (`aliases/os/`) — macOS is the primary target; `linux` is kept as a fallback from prior usage and is no longer actively maintained. `aliases/init` picks one via `uname` and silently no-ops on anything else. When adding OS-specific behavior, drop it into the matching file; do not branch on `uname` inside `utils/*`.
3. **Offline notebook** (`aliases/utils/notebook` launcher + `notebook.d/*.md` content at the repo root) — personal cheatsheet system. Each topic is one markdown file in `notebook.d/`. Path exported as `$ZSH_CUSTOM_CONFIG_NOTEBOOK`. Run `howto?` (or `notebook?`) to list topics; `howto <topic>` to render one; `howto add <topic>` to author a new one in `$EDITOR`. Used to recall syntax for `awk`, `bash`, etc. without leaving the terminal.
4. **AI Q&A over the notebook** (`howto ask <filter> "<query>"`) — pipes matched topic content through a local or cloud LLM and prints the answer. Provider selected by `$NOTEBOOK_AI` (`claude` default, `opencode`, `lms`, `ollama`). For `ollama`: calls the daemon's HTTP API (`localhost:11434/api/generate`, `stream:true`), tags thinking vs answer tokens via `jq`, then perl pipes each section through `scripts/glow-stream/glow-stream` (Go binary, lipgloss/table). Thinking section streams live in gray; answer streams line-by-line with full markdown rendering. `howto setup` (renders `notebook.d/notebook-ai.md`) walks through Ollama install + Gemma 4 pull. `howto -h` shows usage. Override hide-thinking via `OLLAMA_HIDE_THINKING=1` or `--no-think` flag per call.

## Directory map

- `zshrc`, `zprofile` → canonical copies of the dotfiles in `$HOME`.
- `routes` → router/dispatcher (see "Design intent" and "Load order").
- `log` → defines `timelogger <name> start|end` and `alert_unused_logs`. Uses `gdate` (GNU date from Homebrew `coreutils`) for ms precision.
- `aliases/init` → loads utils + OS-specific + secrets.
- `aliases/utils/internal`, `aliases/utils/external` → the bulk of personal aliases / functions (git, Go, password gen, `gitloc`, etc.). `external` is the largest file and the most-edited.
- `aliases/utils/notebook` → notebook launcher (`howto` / `howto?` / `howto add` / `howto ask`). Reads `$ZSH_CUSTOM_CONFIG_NOTEBOOK`.
- `notebook.d/*.md` (repo root) → notebook content, one topic per file. Path exported as `$ZSH_CUSTOM_CONFIG_NOTEBOOK`.
- `templates/_<name>/` (repo root, **not** under `aliases/`) → starter files for new projects, NOT sourced. Consumed by `tpl` (in `aliases/utils/tpl`) and `jsnew` (in `aliases/utils/external`). Path exported as `$ZSH_CUSTOM_CONFIG_TEMPLATES`.
- `scripts/*.sh` (repo root) → standalone shell scripts invoked by aliases (`clean_and_unmount.sh`, `memusg.sh`), not sourced as functions. Path exported as `$ZSH_CUSTOM_CONFIG_SCRIPTS`.
- `scripts/glow-stream/` → Go module producing the `glow-stream` binary used by `howto ask` to render markdown answers from a local LLM. Source: `main.go` (line-buffered markdown → ANSI rewriter with table support via `charmbracelet/lipgloss/table`). Tests: `main_test.go` (`go test ./...`, 24 cases). Rebuild after edits: `cd scripts/glow-stream && go build .`. Binary is checked in (gitignore via top-level `.gitignore` if you ever want to drop it).
- `aliases/os/macos` → primary OS file. Holds `killport`, `killprocess`, `myip`, `flushdns`, `netbounce`, etc.
- `aliases/os/linux` → legacy fallback, retained but not actively used.
- `aliases/secrets/secrets` → API tokens and private aliases. Auto-created if missing. Treat as sensitive; do not echo contents or commit changes that expose values.
- `aliases/integrations/docker/` → always-on docker helpers.
- `aliases/integrations/{javascript,kubernetes,gcloud}` → opt-in, sourced only when uncommented in `routes`.
- `config/helpers/` → non-alias shell glue (iTerm2 integration, `fix_zsh` history fixes, `default` settings).

## Conventions to follow when editing

- New helper functions go in `aliases/utils/external` (general) or `aliases/utils/internal` (lower-level / building blocks). Putting a file in `aliases/utils/` is enough to make it load, no registration step.
- macOS-only commands belong in `aliases/os/macos`, not in `utils/*` (the OS gate in `aliases/init` is the only thing that keeps them off Linux).
- To add a new optional integration: create `aliases/integrations/<name>` and explicitly `source` it from `routes` (the integrations dir is not auto-walked).
- Prefix template files with `_` so the loader skips them (`lsnoext … | grep -v "/_"`).
- Use `source_or_error` (defined in `routes`) rather than bare `source` so missing files warn instead of breaking shell startup.
- Wrap slow sections in `timelogger NAME start … end`; the integrations block already alerts if it exceeds 500 ms.

## Reloading / testing changes

- Reload current shell: `source ~/.zshrc` or just `zsh`.
- Inspect what got loaded: `alias` (lists all active aliases). To print `Runtime of zsh was N ms.` from the wrapping `timelogger`, set `ZSH_TIMING=1`. By default the line is suppressed; the value is still written to `~/.cache/zsh-startup-ms` and surfaced by `shellinfo`.
- Debug the routes dispatcher by uncommenting the `echo "${key}=${PATHS[${key}]}"` line in `routes`.
- Profile startup per function: `ZSH_PROFILE=1 zsh -ilc exit`. Loads `zsh/zprof` at the top of `zshrc` and calls `zprof` at the true end so the table covers all of zshrc, including the external tool init block. Use `zsh -ilc exit` (interactive + login) so `zprofile` is also sourced.
