# claudio: two Claude accounts, one machine

`claudio` runs Claude Code as two fully isolated accounts (`--1` personal, `--2` work), concurrently, each with a **full-scope** login (remote-control + in-CLI usage %). Defined in `aliases/utils/external`.

Each account does its own browser `claude auth login` under its own `CLAUDE_CONFIG_DIR`. That's the whole trick (see below): claude keys its macOS Keychain slot by config dir, so the two accounts get two separate slots and never collide. No token files, no credential swap, no lock. Requires a Pro / Max / Team / Enterprise plan; bills the subscription, not API credits.

## ⚠️ INVARIANTS — do NOT break these (verified live 2026-07-07, claude v2.1.201)

This took real effort and three failed designs to get right. Before you touch anything auth-related in `_claudio_run` / `_claudio_login` / `_claudio_status`, internalize these load-bearing facts. If a "simplification" violates one, it is a regression, not a simplification.

1. **The isolation IS `CLAUDE_CONFIG_DIR`, and nothing else.** claude derives its Keychain slot as `Claude Code-credentials-<sha256(CLAUDE_CONFIG_DIR)[:8]>`. It MUST be set to `$home_dir/.claude` on EVERY `claude` invocation (launch, login, status). Drop it and the two accounts collapse onto one slot.
2. **`HOME` alone does NOT isolate the slot.** With `CLAUDE_CONFIG_DIR` unset, the slot is the suffix-less default `Claude Code-credentials` no matter what `HOME` is. Setting only `HOME` (claudio before 2026-07) put both accounts on that one slot, so the second login silently overwrote the first. That was THE bug. Never remove `CLAUDE_CONFIG_DIR` "because `HOME` already points there."
3. **Never reintroduce a shared-slot swap or a `$CLAUDE_CODE_OAUTH_TOKEN` file.** Two earlier designs did — a Keychain save/restore swap (raced under concurrency, cross-contaminated accounts) and inference-only `setup-token` files (no remote-control, no `/usage`). Per-config-dir slots make both pointless. If you feel you need a swap or a lock, you have already violated #1.
4. **Unset `ANTHROPIC_API_KEY`, `ANTHROPIC_AUTH_TOKEN`, `CLAUDE_CODE_OAUTH_TOKEN` before launching** (see precedence table). Any one of them outranks the Keychain login and would silently use the wrong creds or bill the API.
5. **Log in via the browser (`claude auth login`), full scope.** Not `setup-token` (inference-only). Full scope is what gives remote-control + `/usage`.

Live proof (do this yourself to re-confirm, no browser needed): write any JSON to service `Claude Code-credentials-$(printf %s "$DIR/.claude" | shasum -a256 | cut -c1-8)`, then `CLAUDE_CONFIG_DIR="$DIR/.claude" claude auth status --json` → `loggedIn:true` reads exactly that slot, and a different `$DIR` reads a different (empty) slot. Confirmed against v2.1.201 with the real default slot left untouched.

## How it works — why `CLAUDE_CONFIG_DIR` (verified against the binary)

claude stores its login secret in the macOS Keychain under service `Claude Code-credentials<suffix>`, account `$USER`. The suffix is derived from the config dir. From the v2.1.x binary:

```js
o = CLAUDE_CONFIG_DIR (or CLAUDE_SECURESTORAGE_CONFIG_DIR) is set
      ? `-${sha256(that dir).hex.slice(0,8)}`   // per-dir suffix
      : ""                                        // default slot, no suffix
service = `Claude Code-credentials${o}`
```

So a **distinct `CLAUDE_CONFIG_DIR` ⇒ a distinct Keychain slot**. Two full-scope logins coexist with zero cross-contamination, and both stay logged in at once. Verified on this machine:

- default slot (no config dir) holds whatever last plain login wrote,
- `CLAUDE_CONFIG_DIR=~/.claude-personal-home/.claude` → service `Claude Code-credentials-52f1fbd7`,
- `CLAUDE_CONFIG_DIR=~/.claude-work-home/.claude` → service `Claude Code-credentials-221a8dd9`.

**Correction to prior lore (and to anthropics/claude-code#20553):** the collision is NOT "every HOME, regardless of `CLAUDE_CONFIG_DIR`." Setting `HOME` alone does *not* change the slot — that's why the old claudio (HOME-only) collided both accounts onto the suffix-less default slot. Setting `CLAUDE_CONFIG_DIR` *does* change it. claudio now sets `CLAUDE_CONFIG_DIR="$home_dir/.claude"` on every login and launch.

History: an even older claudio swapped one full-scope grant in and out of the single default slot before/after each run; that raced under concurrency (mid-session refresh + owner-drift) and both accounts converged onto one login. A later version dodged the whole thing with inference-only `setup-token` files passed via `$CLAUDE_CODE_OAUTH_TOKEN` — concurrency-safe, but inference-only, so no remote-control and no `/usage`. The per-config-dir slot removes the original constraint entirely, so we're back to full-scope login for both, concurrent, no swap. Don't reintroduce a swap or a shared slot.

## Usage

    claudio              # choose account interactively, then launch claude
    claudio --1          # personal
    claudio --2          # work
    claudio --1 ...args  # pass args through to claude
    claudio --1 login    # full-scope browser login for personal (run once)
    claudio --2 login    # full-scope browser login for work    (run once)
    claudio login        # choose an account, then log it in
    claudio --1 status   # which real account is --1 logged into?
    claudio status       # both, to eyeball --1=personal / --2=work
    claudio --resume <id>           # auto-detect which home holds <id>
    claudio --1 --resume <id>       # offer to copy <id> from the other home first
    claudio -h           # help

State on disk: per-account config/projects/history live under `~/.claude-{personal,work}-home/.claude/`. The login secret lives in the macOS login Keychain under the per-dir service names above (not in a file).

## First-time setup (and re-auth)

Run `login` once per account. `claude auth login` runs its OWN browser OAuth, so the account belongs to **whichever account you authorize in the browser**, NOT to the `--1`/`--2` flag. Log into the matching account each time:

1. `claudio --1 login` → in the browser, log into your **personal** (`noelruault.engineer@gmail.com`) account → authorize.
2. `claudio --2 login` → in the browser, log into your **work** (`Noel.Ruault@webbeds.com`) account → authorize.

Tip: the browser may reuse an existing claude.ai cookie and silently authorize the wrong account. Use the account switcher on the consent screen (or an incognito window) so `--1` really gets personal and `--2` really gets work.

## Verify the mapping

`claudio status` prints both accounts' `claude auth status` (email + org) **plus a live `usage: session X% week Y%` line** (from `_claudio_usage` → `GET /api/oauth/usage`), so you can confirm `--1 = personal`, `--2 = work` and eyeball each account's session/weekly limits. You can also count the slots — two distinct ones means the isolation took:

    security dump-keychain 2>/dev/null | grep -c '"svce"<blob>="Claude Code-credentials'   # expect 2 after both logins

The usage line is READ-ONLY: `_claudio_usage` pulls the account's access token from its own Keychain slot and calls the usage endpoint directly. It never uses/refreshes the refresh token, so it can't rotate or clobber claude's grant (that rotation hazard is why the widget needs its own separate grant). If the access token is stale (401) or you're offline, the line is silently omitted — it never breaks `status`. Needs `jq` + `curl`.

## Concurrency

`claudio --1` and `claudio --2` are safe to run **at the same time** in different terminals. Distinct config dirs → distinct Keychain slots → distinct projects/history. There is no shared slot, owner file, or swap to race on. claude auto-refreshes each slot's token in place; the refresh writes back to that account's own slot only.

## Remote control & usage %

Both work out of the box: a browser `claude auth login` grant is full scope (`user:profile` + `user:sessions:claude_code` + `user:inference` + …). So `/remote-control` is accepted and `/usage` shows the session/week bars — no extra step. (The macos-widgets "Claude Usage" tile still uses its OWN separate grant; see the reference table — refresh tokens rotate, so consumers can't share one grant.)

## Migrating off the older designs

Vestigial files from the two previous designs can be deleted (they still hold live tokens, so do remove them):

    rm -f ~/.claude-{personal,work}-home/.claude/.claudio-oauth-token    # setup-token era
    rm -f ~/.claude-{personal,work}-home/.claude/.claudio-remote-creds   # brief remote-swap era
    rm -f ~/.claude-{personal,work}-home/.claude/.claudio-credentials.json  # oldest swap era

The suffix-less default Keychain slot (from any plain `claude` login) is unused by claudio now; harmless to leave, or wipe when no default-slot session is live:

    security delete-generic-password -s "Claude Code-credentials" -a "$USER"

## Reference: Claude OAuth on this machine (don't break this in a refactor)

Two separate credential consumers, deliberately decoupled:

| Purpose | Auth | Scope | Stored at | Code |
|---|---|---|---|---|
| **Run** claude (claudio) | full-scope browser `claude auth login`, isolated by `CLAUDE_CONFIG_DIR` | full (`user:profile` + `user:sessions:claude_code` + inference) | per-config-dir Keychain slot `Claude Code-credentials-<sha256(dir)[:8]>` | `aliases/utils/external` (`_claudio_login` / `_claudio_run` / `_claudio_status`) |
| **Read** usage % (macos-widgets "Claude Usage" tile) | full-scope OAuth grant (PKCE), self-refreshed | `user:profile` | `~/.claude-{personal,work}-home/.claude/.claude-usage-refresh-token` | `macos-widgets/publisher/lib/claude-oauth.sh` + `plugins/20-quota.sh`; seed with `publisher/claude-usage-login.sh <acct>` |

Why two: refresh tokens ROTATE on use, so the widget can't share claude's grant — each consumer needs its OWN or they cross-invalidate. (claudio's slots do share the login keychain file, but each is a distinct service, so they don't rotate over each other.)

### Claude auth precedence (highest wins)
1. Cloud provider (`CLAUDE_CODE_USE_BEDROCK` / `_VERTEX` / `_FOUNDRY`)
2. `ANTHROPIC_AUTH_TOKEN`
3. `ANTHROPIC_API_KEY` — an API key here **bills the API**. claudio `unset`s this and #2 before launch so it can't.
4. `apiKeyHelper`
5. `CLAUDE_CODE_OAUTH_TOKEN` — claudio also unsets this, so a stray token can't outrank the per-account login.
6. `/login` OAuth (macOS Keychain) — **what claudio uses now**, one slot per config dir. Subscription-billed, not API.

### Keychain slot keying (the mechanism, don't relearn it)
- Service = `Claude Code-credentials` + (`CLAUDE_CONFIG_DIR` or `CLAUDE_SECURESTORAGE_CONFIG_DIR` set ? `-<sha256(dir)[:8]>` : `""`); account = `$USER`.
- Set `CLAUDE_CONFIG_DIR` per account and each gets its own slot → concurrent full-scope. Setting only `HOME` does NOT (it lands on the suffix-less default slot). `CLAUDE_SECURESTORAGE_CONFIG_DIR` overrides just the slot suffix if you ever want it decoupled from the config dir.

### Endpoints / client (from the claude binary, v2.1.x)
- Usage: `GET https://api.anthropic.com/api/oauth/usage` + header `anthropic-beta: oauth-2025-04-20` → `{five_hour, seven_day, seven_day_sonnet, seven_day_opus}.{utilization, resets_at}`. Needs `user:profile` (claudio's full-scope login has it, so in-CLI `/usage` works).
- Client id: `9d1c250a-e61b-44d9-88ed-5944d1962f5e` (public Claude Code client)
- Authorize (SUBSCRIPTION): `https://claude.com/cai/oauth/authorize`  ← use this
- Authorize (Console/API): `https://platform.claude.com/oauth/authorize`  ← do NOT use for managed accounts
- Token: `https://platform.claude.com/v1/oauth/token`
- Redirect: `https://platform.claude.com/oauth/code/callback`
- PKCE S256, `code=true` (paste-code; no localhost callback server needed)

### Gotchas that cost hours (don't relearn them)
- **`HOME` alone doesn't isolate the Keychain slot; `CLAUDE_CONFIG_DIR` does.** This was the whole two-accounts-collide bug. Always set `CLAUDE_CONFIG_DIR` per account.
- **The Console authorize host is blocked for managed domains.** `platform.claude.com/oauth/authorize` tries to create a Console org; webbeds.com Enterprise policy blocks it ("blocking new organization creation"). The subscription host `claude.com/cai/oauth/authorize` authorizes against the existing team instead.
- **Refresh tokens rotate** on every use. One grant = one consumer. Never point both claude and the widget at the same grant.
- **Token endpoint rate-limits (429).** Space logins a few minutes apart; auth codes are single-use, so just re-run to mint a fresh one.
- **Billing:** subscription OAuth = subscription usage, never API. Only `ANTHROPIC_API_KEY` bills the API.

## Tests

`tests/test_claudio.zsh` verifies the per-account config dir (`_claudio_config_dir`), that `--1`/`--2` launch/login/status under distinct `CLAUDE_CONFIG_DIR`s (⇒ distinct Keychain slots, nothing to race on) with the API/OAuth env vars dropped, plus the resume auto-detect and cross-home session copy. Sandboxed `$HOME` + a fake `claude` on `PATH`; never invokes the real binary or the Keychain.
