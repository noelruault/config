# Plan: Refactor shell config for speed, modularity, and observability

## Goal

Cut interactive shell startup time, isolate external-tool init from the core load path, and add a single inventory command so it is always obvious what is loaded and what is deferred. Outcome: a new shell opens in under ~300 ms in fast mode and the user can swap between a fully-eager classic load and a deferred turbo load behind one flag.

## Revision history

- v1: initial plan (8 steps).
- v2: post-Copilot review. Reordered to put measurement + regression hunt before any optimization; corrected wrong assumptions about `claudio`, `compinit` ownership, zinit plugin parity, `gonew` semantics, and zsh glob-test syntax.

## Current pain (baseline to measure first)

- `zshrc` sources oh-my-zsh + plugins eagerly, then sources `routes`, which transitively loads `aliases/utils/*`, `aliases/os/macos`, `aliases/secrets/*`, and `aliases/integrations/docker` on every shell.
- External-tool init lines at the bottom of `zshrc` (Antigravity, opencode, lms, bun completions) run on every shell.
- Bun init / completions are sourced in three different places: `zprofile:27-33`, `zshrc:63-64`, `aliases/utils/external:419-420`. Each shell pays the cost more than once.
- `nvm.sh` is eager-loaded inside `aliases/utils/external` around line 423-426. NVM init is famously a major startup cost on macOS and is the leading suspect for the recent 2s regression.
- `internal` runs `eval "$(zoxide init zsh)"` unconditionally (zoxide is being removed).
- oh-my-zsh already runs `compinit` itself and writes `~/.zcompdump-${SHORT_HOST}-${ZSH_VERSION}`. Any custom `compinit` we add must coexist with that, not duplicate it.
- `timelogger zsh end` is called on line 50 of `zshrc`, *before* the bottom-of-file tool-init lines on lines 54-64. The "Runtime of zsh was N ms" line systematically under-reports.
- No way to opt into a fast/turbo mode or get a structured listing of what is loaded.

## Order of work

Sequence is chosen so each step is measurable on its own and rollback is one commit. Do not start step N+1 before step N is measured and committed. The first three steps are diagnostic; no optimization happens until step 4.

### Step 0 — Fix the measurement boundary (prerequisite)

Without this, every later step's "before vs after" number is wrong.

1. Move `timelogger zsh end` and `alert_unused_logs` to the actual end of `zshrc`, after the Antigravity / opencode / lms / Bun-completion block (current lines 54-64). The header banner currently lying between them ("THE END OF ZSHRC") is misleading; rename or relocate it.
2. Use `zsh -ilc exit` (interactive + login) for cold-startup measurement, not `zsh -i -c exit`. The `-l` flag is required to source `zprofile`, which is where Bun PATH, Go PATH, and OrbStack init currently live.
3. Commit. No behavior change beyond accurate timing.

### Step 1 — Enable env-gated profiler

1. Add to `zshrc`, top:
   ```zsh
   [[ -n $ZSH_PROFILE ]] && zmodload zsh/zprof
   ```
2. Add at the real end (after step 0's relocation):
   ```zsh
   [[ -n $ZSH_PROFILE ]] && zprof
   ```
3. Document in `CLAUDE.md`: `ZSH_PROFILE=1 zsh -ilc exit` to dump per-function profile.

### Step 2 — Record baseline + hunt the regression

1. Capture in `.plans/refactor-shell.baseline.md`:
   - `time (zsh -ilc exit)` cold (close terminal, fresh shell) — repeat 3x, record best.
   - Same, warm — repeat 3x.
   - `ZSH_PROFILE=1 zsh -ilc exit 2>&1 | head -60` — top callers.
2. Inspect recent history for the regression:
   ```zsh
   git -C ~/config/zshrc log --since="3 months ago" --stat -- zshrc zprofile routes log aliases/
   ```
3. If the profiler points clearly at `nvm.sh` or the Bun completion source line, skip bisect and jump to step 3. Otherwise, run a manual bisect:
   ```zsh
   git bisect start
   git bisect bad HEAD
   git bisect good <known-fast-commit>
   # for each: time zsh -ilc exit
   ```
4. Record the offending commit + the per-step ms attribution in `.plans/refactor-shell.baseline.md`.

### Step 3 — Audit + de-duplicate eager external init

This is the step most likely to recover the missing 2s. Targeted at known duplicates and known-slow inits, not speculative.

1. **NVM**: locate the eager `nvm.sh` source in `aliases/utils/external` (~line 423-426). Replace with a lazy wrapper:
   ```zsh
   # nvm: lazy
   export NVM_DIR="$HOME/.nvm"
   nvm() {
     unfunction nvm node npm npx 2>/dev/null
     [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
     [[ -s "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"
     nvm "$@"
   }
   node() { nvm use default >/dev/null 2>&1; node "$@"; }
   npm()  { nvm use default >/dev/null 2>&1; npm  "$@"; }
   npx()  { nvm use default >/dev/null 2>&1; npx  "$@"; }
   ```
   Re-measure. NVM lazy alone often saves 800-1500 ms.
2. **Bun**: pick exactly one location and delete the other two.
   - `zprofile:27-33` keeps PATH (needed for non-interactive shells and scripts).
   - Delete `zshrc:63-64` (duplicate of zprofile).
   - Delete `aliases/utils/external:419-420` (duplicate of zprofile).
3. Re-measure.

### Step 4 — Lazy-load pattern for remaining interactive-only tools

Tools that are *interactive-only* (no script ever invokes them non-interactively) can have their PATH set lazily.

1. Add `aliases/lazy/_helper`:
   ```zsh
   # lazy_cmd <name> <init-script-path>
   #   First invocation of <name>: source <init-script-path>, then re-dispatch
   #   the call. Subsequent invocations hit the real command directly.
   lazy_cmd() {
     local name=$1 init=$2
     eval "
       $name() {
         unfunction $name 2>/dev/null
         source '$init'
         $name \"\$@\"
       }
     "
   }
   ```
2. One init script per tool under `aliases/lazy/`:
   - `lazy/opencode` — prepends `~/.opencode/bin` to PATH.
   - `lazy/lms` — appends `~/.lmstudio/bin` to PATH.
   - `lazy/antigravity` — prepends `~/.antigravity/antigravity/bin` to PATH.

   Do **not** include `claudio`: `claudio` is already a function defined in `aliases/utils/external` (around lines 443-676), not a PATH-based external init. A lazy stub for it does nothing useful. If `claudio` itself is heavy at source time, that is a separate cleanup of the function body, not a PATH lazy-load.

   Do **not** include `bun`: handled in step 3.

3. Wire them in `routes` (not in `zshrc` directly):
   ```zsh
   source "$ZSH_CUSTOM_CONFIG_ALIASES/lazy/_helper"
   lazy_cmd opencode  "$ZSH_CUSTOM_CONFIG_ALIASES/lazy/opencode"
   lazy_cmd lms       "$ZSH_CUSTOM_CONFIG_ALIASES/lazy/lms"
   lazy_cmd antigravity "$ZSH_CUSTOM_CONFIG_ALIASES/lazy/antigravity"
   ```
4. Delete the corresponding eager lines from `zshrc` (currently 54-64; some are bun, already handled in step 3).
5. Re-measure.

Tradeoff to flag in the commit: completions for lazy tools do not exist until first invocation. Acceptable for interactive use; not acceptable if any script needs the tool.

### Step 5 — Remove zoxide

1. Delete `eval "$(zoxide init zsh)"` from `aliases/utils/internal:7`.
2. Remove `zoxide` from the `plugins=(…)` array in `zshrc:21-32`.
3. Leave the binary installed (homebrew); only the shell hook is removed.
4. Re-measure.

### Step 6 — Completion cache (loader-aware)

This step is loader-specific. Do not run a custom `compinit` in OMZ mode; OMZ owns it.

**OMZ mode (current default):**
1. Before sourcing oh-my-zsh, set `ZSH_COMPDUMP="$HOME/.zcompdump-${SHORT_HOST}-${ZSH_VERSION}"` (matches OMZ's default but makes it explicit).
2. Optionally set `ZSH_DISABLE_COMPFIX=true` if `compaudit` warnings are an issue on macOS.
3. Do **not** run our own `compinit` — leave it to `oh-my-zsh.sh`.
4. To verify: `ls -la ~/.zcompdump-*` shows OMZ's dump file is being reused.

**zinit mode (added in step 8):**
- Owns its own `compinit` via `zicompinit; zicdreplay`. Configured there.

For the "skip security audit if cache is recent" optimization: the correct form is a non-empty array test, not `[[ -n glob ]]`:
```zsh
local _zdump_dir=("$ZSH_COMPDUMP"(N.mh-24))
if (( ${#_zdump_dir} )); then
  compinit -C -d "$ZSH_COMPDUMP"
else
  compinit -d "$ZSH_COMPDUMP"
fi
```
(`mh-24` = modified within the last 24 hours. The earlier draft used `mh+24` which means *older* than 24 hours — opposite of intent.) But again, only relevant if we replace OMZ's compinit; in OMZ mode, skip this snippet entirely.

### Step 7 — Starship swap (gated, reversible)

Starship is already installed at `/usr/local/bin/starship`. Only attempt after steps 0-6 have brought startup into a stable, fast baseline.

1. Add a flag in `zshrc`:
   ```zsh
   : ${ZSH_PROMPT:=spaceship}
   ```
2. Branch:
   ```zsh
   if [[ $ZSH_PROMPT == starship ]]; then
     ZSH_THEME=""
     eval "$(starship init zsh)"
   else
     ZSH_THEME="spaceship"
   fi
   ```
3. Measure both. Pick the faster one as the new default; keep the other as a one-env-var fallback.

### Step 8 — Turbo mode via zinit (opt-in flag)

zinit is not installed yet. Largest, most invasive step; do not start until steps 0-7 are committed.

1. Install zinit (manual): clone to `~/.local/share/zinit/zinit.git` per upstream instructions.
2. Add a shared plugin list as the single source of truth so OMZ and zinit branches stay in sync. Current plugins from `zshrc:21-32`: `fzf`, `zsh-autosuggestions`, `zsh-syntax-highlighting`, `git`, `git-extras`, `gnu-utils`, `golang` (zoxide removed in step 5).
3. Add flag:
   ```zsh
   : ${ZSH_LOADER:=omz}
   ```
4. Branch:
   ```zsh
   case $ZSH_LOADER in
     omz)
       plugins=(fzf zsh-autosuggestions zsh-syntax-highlighting git git-extras gnu-utils golang)
       source "$HOME/.oh-my-zsh/oh-my-zsh.sh"
       ;;
     zinit)
       source ~/.local/share/zinit/zinit.git/zinit.zsh
       # core OMZ libs (compat with omz mode)
       zinit snippet OMZL::completion.zsh
       zinit snippet OMZL::history.zsh
       zinit snippet OMZL::key-bindings.zsh
       # plugins, deferred until after prompt
       zinit wait lucid for \
         OMZP::git \
         OMZP::git-extras \
         OMZP::gnu-utils \
         OMZP::golang \
         atinit"zicompinit; zicdreplay" \
           zdharma-continuum/fast-syntax-highlighting \
         atload"_zsh_autosuggest_start" \
           zsh-users/zsh-autosuggestions \
         junegunn/fzf
       ;;
   esac
   ```
   Note: `fzf` and `gnu-utils` are explicitly included; the v1 draft dropped them.
5. Measure: `ZSH_LOADER=omz time (zsh -ilc exit)` vs `ZSH_LOADER=zinit time (zsh -ilc exit)`. Capture first-prompt and time-to-fully-loaded.
6. Default stays `omz` until zinit branch is exercised for a week.

Tradeoff to flag: zinit turbo means autosuggestions/highlighting are unavailable for the first ~100 ms after prompt.

### Step 9 — Notebook → directory of markdown + AI hook

Lower priority than the startup-perf steps; this is a quality-of-life refactor, not a startup-time win.

1. New layout:
   ```
   aliases/utils/notebook.d/
     awk.md
     bash.md
     ...
   aliases/utils/notebook       # rewritten launcher
   ```
2. Migrate each `<topic>_doc` function in the current `notebook` file into `notebook.d/<topic>.md`. Preserve git history with `git mv` + manual extraction per topic.
3. New launcher API in `aliases/utils/notebook`:
   - `howto`               → fzf list of `notebook.d/*.md`, preview with `bat`. Fall back to `ls notebook.d/` if `fzf` / `bat` missing.
   - `howto <topic>`       → `bat notebook.d/<topic>.md`, falls back to `cat`.
   - `howto?`              → list topic names (basenames), one per line.
   - `howto ask "<q>"`     → **filter first, then pipe**. Either:
     - by topic-match: `howto ask awk "<q>"` cats only `notebook.d/awk.md`.
     - by ripgrep: cat only files where `rg -l "<keyword>"` matched.
     - by fzf-multi: interactive multi-select then cat selected.
     Then pipe to `claude -p "<q>"` (or `opencode` / `lms`) gated by `NOTEBOOK_AI=claude|opencode|lms`. Never cat all `*.md` unconditionally — context limits.
   - `howto add <topic>`   → opens `$EDITOR notebook.d/<topic>.md`.
4. Keep backward-compat aliases for the most-used topics for one week (e.g. `alias awk\?='howto awk'`), then drop.
5. Resolve `NOTEBOOK_AI=claude`: whether this means the upstream `claude` binary or your account-switching `claudio()` wrapper from `external`. Document the choice.

### Step 10 — Templates launcher

1. Current templates: `aliases/utils/templates/_*` (underscore-prefixed so the loader skips them).
2. New launcher `aliases/utils/tpl`:
   - `tpl ls`               → list `templates/_*` minus the underscore prefix.
   - `tpl info <name>`      → cat `templates/_<name>/README.md` if present, else `ls` the dir.
   - `tpl new <name> <dest>`→ `cp -R templates/_<name>/ <dest>/`, then run `<dest>/.init.sh` if executable, then `code <dest>`.
3. `gonew` is **not** a thin wrapper around `tpl new go`. The current `gonew` in `aliases/utils/external:80-100` has bespoke behavior: random-hex folder name when no arg, GOPATH-derived destination (`$(go env GOPATH)/src/github.com/$(whoami)/<name>`), boilerplate `main.go` write, `go mod init <full-import-path>`, `code .` open. Reproduce this either as the `templates/_go/.init.sh` hook or keep `gonew` as a standalone command. Either way, the existing behavior must not regress.
4. Convention for new templates: each `templates/_<name>/` may contain an executable `.init.sh` that runs in the destination after copy.

### Step 11 — `shellinfo` / `shellist`: inventory command (brew-like)

1. New file: `aliases/utils/shellinfo`. Defines two commands:
   - `shellist` (parallels `brew list`):
     ```
     ==> Loader / prompt
     loader=omz   prompt=spaceship   profile=off
     ==> Plugins
     fzf  zsh-autosuggestions  zsh-syntax-highlighting  git  git-extras  gnu-utils  golang
     ==> Integrations (eager)
     docker
     ==> Integrations (lazy)
     opencode  lms  antigravity  nvm
     ==> Utils
     external  internal  notebook  shellinfo  tpl
     ==> OS-specific
     macos
     ==> Notebook topics
     awk  bash  bashrc  ...
     ==> Templates
     go  javascript  wrangler
     ```
   - `shellinfo` (parallels `brew info`):
     ```
     Loader:   omz            (env ZSH_LOADER, set to "zinit" for turbo)
     Prompt:   spaceship      (env ZSH_PROMPT, set to "starship" to swap)
     Profile:  off            (env ZSH_PROFILE=1 to enable zprof)
     Startup:  312 ms         (last timelogger snapshot)
     8 plugins, 1 eager integration, 4 lazy integrations, 18 notebook topics
     ```
2. Source of truth: each subsystem registers itself into associative arrays declared in `routes`. **In-shell only**, never relied upon across subshells (associative array export is not portable in zsh). `shellinfo` and `shellist` are functions, so they run in the same shell that sourced `routes` — fine.
3. For the "last startup" line: `log` currently only prints `Runtime of zsh was N ms` without persisting it. Either (a) extend `timelogger` to write the final value to `~/.cache/zsh-startup-ms`, or (b) have `shellinfo` re-measure on demand via `time (zsh -ilc exit) 2>&1`. Option (a) is cheaper to call but adds a write to startup. Option (b) is slower but stateless. Pick (a).
4. Sort all listed sections so output is deterministic across shells.

## Acceptance checklist

- [ ] Baseline numbers recorded in `.plans/refactor-shell.baseline.md` (cold, warm, top callers, regression commit if found).
- [ ] `time (zsh -ilc exit)` warm is below 50% of baseline.
- [ ] `timelogger zsh end` fires at the true end of `zshrc`, after all tool inits.
- [ ] `ZSH_LOADER=omz` and `ZSH_LOADER=zinit` both work; switching is one env var; plugin set is identical between them.
- [ ] `ZSH_PROMPT=spaceship` and `ZSH_PROMPT=starship` both work; switching is one env var.
- [ ] `ZSH_PROFILE=1 zsh -ilc exit` produces a `zprof` table.
- [ ] `howto`, `howto <topic>`, `howto?`, `howto ask <filter> "<q>"`, `howto add <topic>` all work; `howto ask` never cats all topics.
- [ ] `tpl ls`, `tpl info <name>`, `tpl new <name> <dest>` all work; `gonew` retains its original behavior (random-hex name, GOPATH dest, boilerplate, go mod init, code .).
- [ ] `shellist` and `shellinfo` print accurate, sorted, up-to-date inventory.
- [ ] Zoxide no longer initialized in any interactive shell.
- [ ] Bun init is sourced exactly once (in `zprofile`), not in `zshrc` or `external`.
- [ ] NVM is lazy-loaded; first `node` / `npm` / `npx` / `nvm` call sources it; subsequent calls are direct.
- [ ] OMZ's `~/.zcompdump-*` is reused across sessions (no full security audit on every shell).

## Out of scope (intentionally)

- Touching `zprofile` PATH order beyond removing the duplicate Bun completion source.
- Rotating the JIRA token in `aliases/secrets/secrets`. Separate task.
- Migrating off oh-my-zsh entirely (zinit branch is opt-in, not the default).
- Adding new notebook topics. Migration only; new content is a separate task.
- Cleaning up the body of `claudio()` in `aliases/utils/external` if it turns out to be heavy at source time. Separate task once a profiler run actually flags it.

## Commit strategy

One commit per step (12 commits). Each commit message states the step number, the measured before/after for that step, and the env var (if any) introduced. Step 2 commit also adds the baseline file. If a step shows no improvement or a regression, revert that single commit rather than tweaking forward.
