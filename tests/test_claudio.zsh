#!/usr/bin/env zsh
# claudio helpers, exercised against a sandboxed $HOME and a fake `claude` on
# PATH — the real binary and the macOS Keychain are never touched. Auth is full-scope login isolated per account by CLAUDE_CONFIG_DIR (claude keys its
# Keychain slot by config dir), so there is no shared slot to race on. We verify the per-account config dir / launch env (_claudio_config_dir, _claudio_run,
# _claudio_login, _claudio_status) and the session copy/offer helpers.
source "${0:A:h}/lib.zsh"
t_sandbox
# No stderr suppression: if external ever fails to source, that should be loud, not a wall of "expected [x], got []" failures.
source "$REPO/zshrc/aliases/utils/external"

t "extract: --resume <id>"
assert_eq "$(_claudio_extract_resume_id --resume abc123)" "abc123"

t "extract: --resume=<id>"
assert_eq "$(_claudio_extract_resume_id --resume=abc)" "abc"

t "extract: -r <id>"
assert_eq "$(_claudio_extract_resume_id -r abc)" "abc"

t "extract: -r=<id>"
assert_eq "$(_claudio_extract_resume_id -r=abc)" "abc"

t "extract: id found among other args"
assert_eq "$(_claudio_extract_resume_id --verbose --resume deadbeef --foo)" "deadbeef"

t "extract: absent gives rc 1 and empty output"
out=$(_claudio_extract_resume_id --foo bar); rc=$?
assert_eq "$rc" "1" "exit code"
assert_eq "$out" "" "output"

mkdir -p "$CLAUDE_HOME_PERSONAL/.claude/projects/p" "$CLAUDE_HOME_WORK/.claude/projects/p"
touch "$CLAUDE_HOME_PERSONAL/.claude/projects/p/sess-p.jsonl"
touch "$CLAUDE_HOME_WORK/.claude/projects/p/sess-w.jsonl"
touch "$CLAUDE_HOME_PERSONAL/.claude/projects/p/sess-b.jsonl"
touch "$CLAUDE_HOME_WORK/.claude/projects/p/sess-b.jsonl"

t "session only in personal home"
assert_eq "$(_claudio_account_for_session sess-p)" "personal"

t "session only in work home"
assert_eq "$(_claudio_account_for_session sess-w)" "work"

t "session in both homes is ambiguous, rc 2"
out=$(_claudio_account_for_session sess-b); rc=$?
assert_eq "$out" "ambiguous"
assert_eq "$rc" "2" "exit code"

t "unknown session gives rc 1"
_claudio_account_for_session no-such-session >/dev/null
assert_eq "$?" "1" "exit code"

# ---- _claudio_home_for_account ------------------------------------------
t "home_for_account: unknown account gives rc 1"
_claudio_home_for_account bogus >/dev/null
assert_eq "$?" "1" "exit code"
assert_eq "$(_claudio_home_for_account work)" "$CLAUDE_HOME_WORK" "work maps to work home"

# ---- _claudio_copy_session ---------------------------------------------- work home has projects/myslug/csess.jsonl + a todo file keyed by the id.
mkdir -p "$CLAUDE_HOME_WORK/.claude/projects/myslug" "$CLAUDE_HOME_WORK/.claude/todos"
print -r -- 'transcript-body' > "$CLAUDE_HOME_WORK/.claude/projects/myslug/csess.jsonl"
print -r -- 'todo-body' > "$CLAUDE_HOME_WORK/.claude/todos/csess-agent-x.json"

t "copy_session mirrors the transcript under the same slug in the dest home"
_claudio_copy_session csess work personal; rc=$?
assert_eq "$rc" "0" "exit code"
assert_file_exists "$CLAUDE_HOME_PERSONAL/.claude/projects/myslug/csess.jsonl"
assert_eq "$(cat $CLAUDE_HOME_PERSONAL/.claude/projects/myslug/csess.jsonl)" "transcript-body" "content copied"

t "copy_session brings along id-keyed todo files"
assert_file_exists "$CLAUDE_HOME_PERSONAL/.claude/todos/csess-agent-x.json"

t "copy_session keeps the original in the source home"
assert_file_exists "$CLAUDE_HOME_WORK/.claude/projects/myslug/csess.jsonl"

t "copy_session returns 1 when the transcript is absent"
_claudio_copy_session ghost work personal
assert_eq "$?" "1" "exit code"

# ---- _claudio_offer_session_copy ----------------------------------------
# Scrub PATH so `command -v gum` fails and the read-from-stdin branch is used;
# everything the helpers need (find/cp/mkdir) lives in /usr/bin:/bin.
PATH="/usr/bin:/bin"
mkdir -p "$CLAUDE_HOME_WORK/.claude/projects/myslug"
print -r -- 'o' > "$CLAUDE_HOME_WORK/.claude/projects/myslug/osess.jsonl"   # work-only
print -r -- 'd' > "$CLAUDE_HOME_WORK/.claude/projects/myslug/dsess.jsonl"   # work-only

t "offer: no --resume is a silent no-op"
out=$(_claudio_offer_session_copy personal --foo bar </dev/null 2>&1); rc=$?
assert_eq "$rc" "0" "exit code"
assert_eq "$out" "" "no output"

t "offer: session already in target home is a no-op"
out=$(_claudio_offer_session_copy personal --resume sess-p </dev/null 2>&1)
assert_eq "$out" "" "no prompt, no output"

t "offer: session not found anywhere is a no-op"
out=$(_claudio_offer_session_copy personal --resume nope </dev/null 2>&1)
assert_eq "$out" "" "no prompt, no output"

t "offer: confirming copies the session into the target home"
out=$(_claudio_offer_session_copy personal --resume osess <<< 'y' 2>&1)
assert_file_exists "$CLAUDE_HOME_PERSONAL/.claude/projects/myslug/osess.jsonl"
assert_contains "$out" "copied session osess"

t "offer: declining leaves the session where it was"
out=$(_claudio_offer_session_copy personal --resume dsess <<< 'n' 2>&1)
assert_eq "$(find $CLAUDE_HOME_PERSONAL/.claude/projects -name dsess.jsonl)" "" "not copied"
assert_contains "$out" "leaving it in work"

# ==========================================================================
# Auth: full-scope login per account, isolated by CLAUDE_CONFIG_DIR.
# A fake `claude` on PATH echoes the auth-relevant env + args, so we assert what claudio passes without ever touching the real binary or Keychain. The core guarantee: each account gets its OWN CLAUDE_CONFIG_DIR (=> its own Keychain slot), so --1 and --2 never share a slot -- nothing to race on.
# ==========================================================================
# PATH was scrubbed to /usr/bin:/bin above; prepend a stub bin dir.
mkdir -p "$T_DIR/bin"
_fake_claude() { cat > "$T_DIR/bin/claude"; chmod +x "$T_DIR/bin/claude"; }
PATH="$T_DIR/bin:/usr/bin:/bin"
_fake_claude <<'SH'
#!/bin/sh
echo "CLAUDE_RAN home=$HOME configdir=$CLAUDE_CONFIG_DIR token=${CLAUDE_CODE_OAUTH_TOKEN:-unset} apikey=${ANTHROPIC_API_KEY:-unset} args=$*"
SH

# Fake `security` + `curl` so _claudio_usage (called by _claudio_status) never
# reads the real Keychain or hits the network. security returns a slot JSON with
# a token; curl returns a canned /api/oauth/usage body. Overridden per-test below.
cat > "$T_DIR/bin/security" <<'SEC'
#!/bin/sh
echo '{"claudeAiOauth":{"accessToken":"sk-ant-oat01-KEYTEST-NOTREAL","refreshToken":"r","expiresAt":9999999999999,"scopes":["user:profile"]}}'
SEC
chmod +x "$T_DIR/bin/security"
cat > "$T_DIR/bin/curl" <<'CURL'
#!/bin/sh
echo '{"five_hour":{"utilization":50.0},"seven_day":{"utilization":19.0},"extra_usage":{"is_enabled":false,"utilization":null}}'
CURL
chmod +x "$T_DIR/bin/curl"

# ---- _claudio_config_dir: per-account config dir => per-account keychain slot
t "config_dir maps each account to its per-home .claude dir"
assert_eq "$(_claudio_config_dir personal)" "$CLAUDE_HOME_PERSONAL/.claude" "personal"
assert_eq "$(_claudio_config_dir work)" "$CLAUDE_HOME_WORK/.claude" "work"

t "the two accounts get DISTINCT config dirs (no shared slot to race on)"
cdp=$(_claudio_config_dir personal); cdw=$(_claudio_config_dir work)
assert_eq "$([[ "$cdp" != "$cdw" ]] && echo distinct || echo same)" "distinct"

t "distinct config dirs hash to distinct keychain services (claude's own keying)"
# claude keys its slot "Claude Code-credentials-<sha256(configdir)[:8]>"; distinct dirs -> distinct services -> both accounts stay logged in concurrently.
hp=$(printf '%s' "$cdp" | shasum -a 256 | cut -c1-8)
hw=$(printf '%s' "$cdw" | shasum -a 256 | cut -c1-8)
assert_eq "$([[ "$hp" != "$hw" ]] && echo distinct || echo same)" "distinct"

# ---- _claudio_run: per-account CLAUDE_CONFIG_DIR + HOME, drops stray auth env
t "run launches personal with its own CLAUDE_CONFIG_DIR and drops stray API/OAuth env"
export ANTHROPIC_API_KEY=should-be-dropped
export CLAUDE_CODE_OAUTH_TOKEN=should-be-dropped
out=$(_claudio_run personal </dev/null 2>&1)
unset ANTHROPIC_API_KEY CLAUDE_CODE_OAUTH_TOKEN
assert_contains "$out" "configdir=$CLAUDE_HOME_PERSONAL/.claude" "personal config dir"
assert_contains "$out" "home=$CLAUDE_HOME_PERSONAL" "personal home"
assert_contains "$out" "token=unset" "stray OAuth token dropped"
assert_contains "$out" "apikey=unset" "stray API key dropped"

t "run launches work with the work config dir (no cross-contamination)"
out=$(_claudio_run work </dev/null 2>&1)
assert_contains "$out" "configdir=$CLAUDE_HOME_WORK/.claude" "work config dir"
assert_contains "$out" "home=$CLAUDE_HOME_WORK" "work home"

t "run: unknown account gives rc 2"
_claudio_run bogus </dev/null >/dev/null 2>&1
assert_eq "$?" "2" "exit code"

# ---- _claudio_login: full-scope 'claude auth login' under the account's dir --
t "login runs 'claude auth login' under the account's CLAUDE_CONFIG_DIR"
out=$(_claudio_login personal </dev/null 2>&1)
assert_contains "$out" "args=auth login" "invokes auth login"
assert_contains "$out" "configdir=$CLAUDE_HOME_PERSONAL/.claude" "personal keychain slot"
assert_contains "$out" "token=unset" "no stray token forced onto the login"

t "login: unknown account gives rc 2"
_claudio_login bogus </dev/null >/dev/null 2>&1
assert_eq "$?" "2" "exit code"

# ---- _claudio_status: read the account's own slot, name the flag ----------
t "status runs 'claude auth status' under the account's CLAUDE_CONFIG_DIR"
out=$(_claudio_status work </dev/null 2>&1)
assert_contains "$out" "args=auth status" "invokes auth status"
assert_contains "$out" "configdir=$CLAUDE_HOME_WORK/.claude" "work keychain slot"

t "status header names the flag and account role"
out=$(_claudio_status work </dev/null 2>&1)
assert_contains "$out" "[--2] work account" "flag + role in header"
out=$(_claudio_status personal </dev/null 2>&1)
assert_contains "$out" "[--1] personal account" "flag + role in header"

# Swap in a fake that prints claude's real 'not logged in' hint, to check the rewrite from 'claude auth login' -> the claudio command for this account.
_fake_claude <<'SH'
#!/bin/sh
echo "Not logged in. Run claude auth login to authenticate."
SH
t "status rewrites claude's generic login hint to 'claudio <flag> login'"
out=$(_claudio_status personal </dev/null 2>&1)
assert_contains "$out" "claudio --1 login" "points at the account-specific command"
assert_eq "$(printf '%s' "$out" | grep -c 'claude auth login')" "0" "no bare 'claude auth login' left"

# ---- _claudio_usage: live usage % from the account's OWN slot token ---------
# security + curl are faked (set up after the fake claude, above), so this reads
# a canned slot token + canned /api/oauth/usage body -- no real Keychain, no net.
t "usage prints session + week % parsed from the endpoint"
out=$(_claudio_usage work 2>&1)
assert_contains "$out" "session 50%" "five_hour utilization"
assert_contains "$out" "week 19%" "seven_day utilization"

t "usage: unknown account -> rc 1, no output"
out=$(_claudio_usage bogus 2>&1); rc=$?
assert_eq "$rc" "1" "exit code"
assert_eq "$out" "" "no output"

# curl that fails -> usage must degrade silently (offline must not break status)
cat > "$T_DIR/bin/curl" <<'CURL'
#!/bin/sh
exit 7
CURL
chmod +x "$T_DIR/bin/curl"
t "usage degrades silently when the endpoint is unreachable"
out=$(_claudio_usage work 2>&1); rc=$?
assert_eq "$out" "" "no output"
assert_eq "$rc" "1" "exit code"

t_done
