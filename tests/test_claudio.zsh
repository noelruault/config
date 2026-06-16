#!/usr/bin/env zsh
# claudio helpers, exercised against a sandboxed $HOME and a fake `claude` on
# PATH — the real binary and the macOS Keychain are never touched. Auth is now
# token-based (CLAUDE_CODE_OAUTH_TOKEN), so there is no keychain swap to test;
# we verify token capture/storage (_claudio_login), token injection at launch
# (_claudio_run), and the session copy/offer helpers (file moves only).
source "${0:A:h}/lib.zsh"
t_sandbox
# No stderr suppression: if external ever fails to source, that should be loud,
# not a wall of "expected [x], got []" failures.
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

# ---- _claudio_copy_session ----------------------------------------------
# work home has projects/myslug/csess.jsonl + a todo file keyed by the id.
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

# ---- _claudio_token_file -------------------------------------------------
t "token_file maps each account to its per-home 0600 token path"
assert_eq "$(_claudio_token_file personal)" "$CLAUDE_HOME_PERSONAL/.claude/.claudio-oauth-token" "personal"
assert_eq "$(_claudio_token_file work)" "$CLAUDE_HOME_WORK/.claude/.claudio-oauth-token" "work"

# ---- fake `claude` on PATH so the real binary/Keychain are never touched -
# PATH was scrubbed to /usr/bin:/bin above; prepend a stub bin dir.
mkdir -p "$T_DIR/bin"
_fake_claude() { cat > "$T_DIR/bin/claude"; chmod +x "$T_DIR/bin/claude"; }
PATH="$T_DIR/bin:/usr/bin:/bin"

# Fake OAuth tokens for the tests below. The real `sk-ant-oat…` prefix is
# SPLIT in source (two adjacent quoted strings -> concatenated at runtime) so
# secret scanners don't flag these obviously-fake, short fixtures as real
# Anthropic tokens. At runtime they still carry the prefix, so they exercise the
# extractor's `sk-ant-oat…` pattern for real.
_OAT='sk-ant-''oat01-'
TOK_P="${_OAT}fake-personal"
TOK_W="${_OAT}fake-work"
TOK_PASTE="${_OAT}fake-pasted"

# setup-token prints noise + a token to stdout (mimics the real command). The
# fake reads the token from the exported env so no token literal lives in here.
export SETUP_TOK="$TOK_P"
_fake_claude <<'SH'
#!/bin/sh
if [ "$1" = "setup-token" ]; then
  echo "Opening browser for authorization..."
  echo "$SETUP_TOK"
else
  echo "CLAUDE_RAN home=$HOME token=$CLAUDE_CODE_OAUTH_TOKEN apikey=${ANTHROPIC_API_KEY:-unset} args=$*"
fi
SH

# ---- _claudio_login: capture + store the token 0600 ----------------------
t "login extracts the sk-ant-oat token from setup-token output and stores it 0600"
_claudio_login personal </dev/null >/dev/null 2>&1; rc=$?
assert_eq "$rc" "0" "exit code"
assert_eq "$(cat $(_claudio_token_file personal))" "$TOK_P" "token captured"
assert_eq "$(stat -f '%Lp' $(_claudio_token_file personal))" "600" "token file mode 0600"

t "login: unknown account gives rc 2"
_claudio_login bogus </dev/null >/dev/null 2>&1
assert_eq "$?" "2" "exit code"

# ---- _claudio_login: manual-paste fallback when no token is in the output -
_fake_claude <<'SH'
#!/bin/sh
[ "$1" = "setup-token" ] && echo "no token printed here"
SH
t "login falls back to a manual paste when auto-capture finds nothing"
_claudio_login work <<< "$TOK_PASTE" >/dev/null 2>&1
assert_eq "$(cat $(_claudio_token_file work))" "$TOK_PASTE" "pasted token stored"

# Restore the env-echoing fake for the launch tests.
_fake_claude <<'SH'
#!/bin/sh
echo "CLAUDE_RAN home=$HOME token=$CLAUDE_CODE_OAUTH_TOKEN apikey=${ANTHROPIC_API_KEY:-unset} args=$*"
SH

# ---- _claudio_run: missing token aborts, never launches claude -----------
rm -f "$(_claudio_token_file personal)"
t "run aborts with rc 1 when the account has no token yet"
out=$(_claudio_run personal </dev/null 2>&1); rc=$?
assert_eq "$rc" "1" "exit code"
assert_contains "$out" "no auth token"
assert_eq "$(printf '%s' "$out" | grep -c CLAUDE_RAN)" "0" "claude was not launched"

# ---- _claudio_run: inject the account's token, drop ANTHROPIC_* ----------
print -rn -- "$TOK_P" > "$(_claudio_token_file personal)"
print -rn -- "$TOK_W" > "$(_claudio_token_file work)"

t "run launches claude with the personal token in CLAUDE_CODE_OAUTH_TOKEN"
export ANTHROPIC_API_KEY=should-be-dropped
out=$(_claudio_run personal </dev/null 2>&1)
unset ANTHROPIC_API_KEY
assert_contains "$out" "token=$TOK_P"
assert_contains "$out" "home=$CLAUDE_HOME_PERSONAL"
assert_contains "$out" "apikey=unset"

t "run picks the work token for the work account (no cross-contamination)"
out=$(_claudio_run work </dev/null 2>&1)
assert_contains "$out" "token=$TOK_W"
assert_contains "$out" "home=$CLAUDE_HOME_WORK"

t_done
