# Baseline + per-step measurements

Captured with `env -i HOME=/Users/noelruault PATH=/usr/bin:/bin:/usr/sbin:/sbin TERM=$TERM zsh -ilc exit`.
Runs are from inside an isolated Claude Code sandbox; the host `$HOME` is `/Users/noelruault/.claude-personal-home`, so the real user `~/.zshrc` / `~/.zprofile` symlinks are sourced explicitly by forcing `HOME`. "Cold" cannot be perfectly reproduced here (no fresh terminal session), so all timings below are best-of-3 warm runs unless noted.

Two numbers per run:
- `Runtime of zsh was N ms.` from `timelogger` (now accurate after step 0; covers all of `zshrc`).
- `time (...) real` from bash `time` (covers `zprofile` + `zshrc` end-to-end).

## Baseline (after step 0 + step 1 — measurement plumbing only)

Warm, 3x:

| run | timelogger | real |
|-----|-----------:|-----:|
| 1   | 1420 ms    | 1956 ms |
| 2   | 1098 ms    | 1204 ms |
| 3   | 1306 ms    | 1419 ms |

**Best timelogger:** 1098 ms.
**Best real:** 1204 ms.

Note: earlier runs during step 0/1 saw 857-1153 ms timelogger. Variance is high because of macOS background activity inside the sandbox. Track best-of-3.

## zprof top callers (ZSH_PROFILE=1, after step 1)

```
num  calls   time      self    name
 1)    1   780.60   385.78   nvm_auto                      (74.70% of total)
 2)    2   347.61   198.60   nvm
 3)   10   888.28   107.42   source_or_error
 4)    1   119.99    98.81   nvm_ensure_version_installed
 5)   29    63.35    37.16   _omz_source
 6)    1    28.82    28.82   nvm_die_on_prefix
 7)    1    47.21    23.20   nvm_is_valid_version
 8)    1    21.18    21.18   nvm_is_version_installed
 9)    1    36.47    20.42   spaceship::core::load_sections
10)    3    19.72     6.57   timelogger
11)    2    17.45     8.73   compaudit
12)    1    18.89    12.69   nvm_validate_implicit_alias
13)    1    11.23    11.23   fzf_setup_using_fzf
22)    1    21.69     4.24   compinit
47)    1   780.61     0.01   nvm_process_parameters         (parent of nvm_auto)
```

Total: 1115 ms (this run). NVM family alone accounts for ~780 ms (74.7%).

## Regression hunt

`git log --since="6 months ago" --stat -- zshrc zprofile routes log aliases/` shows only two relevant commits since 2025-08:

- `a8ab947` 2026-04-22 — git signing, iterm color scheme, fonts.
- `aab0908` 2026-05-22 — handle multiple Claude code.

Neither commit touches NVM init. The NVM eager source in `aliases/utils/external:423-426` predates the recent regression window and is the dominant cost regardless. **Bisect skipped** per plan ("If the profiler points clearly at `nvm.sh`, skip bisect and jump to step 3.").

Conclusion: step 3 (lazy NVM + Bun de-dup) should recover the bulk of the 2s regression and bring startup well under 500 ms before any further optimization.

## Per-step results (filled as steps land)

| step | env var | timelogger best | real best | notes |
|------|---------|----------------:|----------:|-------|
| 0 — boundary fix       | —             | 857 ms  | —       | timelogger now covers full zshrc |
| 1 — zprof gate         | `ZSH_PROFILE` | 1017 ms | —       | conditional check, ~zero cost; noisy |
| 2 — baseline (this)    | —             | 1098 ms | 1204 ms | snapshot, no code change |
| 3 — lazy NVM + bun dedup | —           | 228 ms  | —       | NVM family gone from startup; bun lives in zprofile only |
| 4 — lazy opencode/lms/antigravity | — | 235 ms  | —       | PATH exports were already cheap; stubs improve hygiene |
| 5 — remove zoxide      | —             | 267 ms  | —       | `z` no longer defined; eval removed; plugin dropped |
| 6 — compdump pinned    | —             | 210 ms  | —       | ZSH_COMPDUMP explicit, ZSH_DISABLE_COMPFIX=true; OMZ owns compinit |
| 7 — starship swap      | `ZSH_PROMPT`  | 211 ms (spaceship) / 220 ms (starship) | — | warm best of 3 each; default stays spaceship |
| 8 — zinit branch (gated) | `ZSH_LOADER` | 237 ms (omz) / N/A (zinit) | — | zinit not installed yet; branch falls back to omz with install hint; default stays omz |
| 9 — notebook → notebook.d/*.md | `NOTEBOOK_AI` | 244 ms | — | 44 topics extracted; `howto` launcher with fzf/bat/rg fallbacks; compat aliases retained one week |
| 10 — tpl launcher      | —             | 218 ms  | —       | `tpl ls/info/new`; gonew kept as-is per plan |
| 11 — shellinfo / shellist | —          | 271 ms  | —       | inventory commands + last-startup persisted to ~/.cache/zsh-startup-ms |
| 12 — forkless timelogger + gated echo | `ZSH_TIMING` | 197 ms | — | $EPOCHREALTIME replaces 3 gdate forks; echo gated; cache always written |
| 13 — investigate compaudit cost | — | (no change) | — | OMZ runs `compinit -u -d ...` without `-C`. compaudit runs as part of compinit; ~5.85 ms is the floor without taking ownership of compinit (plan forbids). Skipped. |
| 14 — default ZSH_PROMPT=starship | `ZSH_PROMPT` | spaceship 192 ms / starship 190 ms | — | flipped default; real-world delta probably larger (spaceship draws 40 ms per profile). Set ZSH_PROMPT=spaceship to revert. |

## Final summary

- Best startup: 210 ms (step 6).
- vs baseline (step 2, 1098 ms): -888 ms / 80.9% reduction.
- Acceptance gate ("warm below 50% of baseline"): met (210 ms < 549 ms).
- All env vars introduced: `ZSH_PROFILE`, `ZSH_PROMPT`, `ZSH_LOADER`, `NOTEBOOK_AI`.
- Zinit branch wired but not measured (binary not installed); flag falls back to OMZ with install hint.
- Backward-compat `<topic>?` aliases retained for one week, then drop.
