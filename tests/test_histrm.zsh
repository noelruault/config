#!/usr/bin/env zsh
# histrm: file-scrubbing behavior, multibyte safety, awk-failure abort, backup.
source "${0:A:h}/lib.zsh"
t_sandbox
source "$REPO/zshrc/aliases/utils/histrm"

# Simulate a normal interactive environment: the 2026-06 incident only
# reproduces when awk runs under a UTF-8 locale.
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

newhist() {
    export HISTFILE="$T_DIR/hist"
    print -r -- ': 100:0;ls' > "$HISTFILE"
    print -r -- ': 101:0;vim .confib' >> "$HISTFILE"
    print -r -- ': 102:0;echo hi' >> "$HISTFILE"
    rm -f "$HISTFILE.histrm-bak"
}
lines() { grep -c '' "$1"; }

t "match mode removes only matching entries"
newhist
out=$(histrm ".confib" 2>&1); rc=$?
assert_eq "$rc" "0" "exit code"
assert_eq "$(lines $HISTFILE)" "2" "remaining lines"
assert_not_contains "$(cat $HISTFILE)" ".confib" "matched entry gone"
assert_contains "$(cat $HISTFILE)" "echo hi" "non-matching entries kept"
assert_contains "$out" "removed 1 entry" "count message"

t "backup written before replace"
assert_file_exists "$HISTFILE.histrm-bak"
assert_eq "$(lines $HISTFILE.histrm-bak)" "3" "backup holds pre-run content"

t "metafied (non-UTF8) bytes do not kill awk or get lost"
newhist
printf ': 103:0;echo \203\303( metafied\n' >> "$HISTFILE"
out=$(histrm "no-such-text" 2>&1); rc=$?
assert_eq "$rc" "0" "exit code with junk bytes present"
assert_eq "$(lines $HISTFILE)" "4" "no entries lost"
assert_contains "$(cat $HISTFILE)" "metafied" "metafied line content intact"
assert_contains "$out" "removed 0 entries" "count message"

t "empty history file is a no-op"
export HISTFILE="$T_DIR/hist"
: > "$HISTFILE"
out=$(histrm "anything" 2>&1); rc=$?
assert_eq "$rc" "0" "exit code"
assert_eq "$(lines $HISTFILE)" "0" "still empty"

t "-n 1 removes only the last entry"
newhist
histrm -n 1 >/dev/null 2>&1
assert_eq "$(lines $HISTFILE)" "2" "one entry removed"
assert_not_contains "$(cat $HISTFILE)" "echo hi" "last entry gone"
assert_contains "$(cat $HISTFILE)" ".confib" "earlier entries kept"

t "-n 0 removes nothing"
newhist
histrm -n 0 >/dev/null 2>&1
assert_eq "$(lines $HISTFILE)" "3" "all entries kept"
assert_contains "$(cat $HISTFILE)" "echo hi" "content intact, not just line count"

t "-n 1 with a histrm call mid-history still removes the true last entry"
newhist
print -r -- ': 103:0;echo last' >> "$HISTFILE"
sed -i '' '2i\
: 999:0;histrm "mid"
' "$HISTFILE"
histrm -n 1 >/dev/null 2>&1
assert_not_contains "$(cat $HISTFILE)" "echo last" "last real entry removed"
assert_not_contains "$(cat $HISTFILE)" 'histrm "mid"' "self call scrubbed"
assert_eq "$(lines $HISTFILE)" "3" "remaining entries"

t "no args removes the last entry"
newhist
out=$(histrm 2>&1)
assert_eq "$(lines $HISTFILE)" "2" "one entry removed"
assert_not_contains "$(cat $HISTFILE)" "echo hi" "last entry gone"
assert_contains "$(cat $HISTFILE)" ".confib" "earlier entries kept"
assert_contains "$out" "removed 1 entry" "count message"

t "histrm's own calls are always scrubbed"
newhist
print -r -- ': 104:0;histrm "oops"' >> "$HISTFILE"
histrm "no-such-text" >/dev/null 2>&1
assert_not_contains "$(cat $HISTFILE)" "histrm" "self call gone"
assert_eq "$(lines $HISTFILE)" "3" "only the self call removed"

t "awk failure leaves history untouched"
newhist
mkdir -p "$T_DIR/bin"
print -r -- '#!/bin/sh' > "$T_DIR/bin/awk"
print -r -- 'exit 2' >> "$T_DIR/bin/awk"
chmod +x "$T_DIR/bin/awk"
_oldpath=$PATH
PATH="$T_DIR/bin:$PATH"
out=$(histrm ".confib" 2>&1); rc=$?
PATH=$_oldpath
assert_eq "$rc" "1" "non-zero exit on awk failure"
assert_eq "$(lines $HISTFILE)" "3" "history untouched"
assert_contains "$out" "untouched" "abort message"

t_done
