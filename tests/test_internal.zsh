#!/usr/bin/env zsh
# internal utils (i.pwgen, fileformat, gitloc lives in test_gitloc) + the two
# router primitives from routes (lsnoext, source_or_error).
source "${0:A:h}/lib.zsh"
t_sandbox
source "$REPO/zshrc/aliases/utils/internal"
unalias rm cp hs 2>/dev/null   # internal sets rm -i / cp→rsync; keep tests deterministic

t "i.pwgen default length 16"
pw=$(i.pwgen)
assert_eq "${#pw}" "16" "length"

t "i.pwgen custom length"
pw=$(i.pwgen 24)
assert_eq "${#pw}" "24" "length"

# Strip-and-compare instead of [[ match ]]; assert_eq "$?": binds check and
# oracle in one expression, so nothing inserted between them can break it.
t "i.pwgen contains all four character classes"
pw=$(i.pwgen 16 2)
assert_ne "${pw//[^A-Z]/}" "" "uppercase"
assert_ne "${pw//[^a-z]/}" "" "lowercase"
assert_ne "${pw//[^0-9]/}" "" "digit"
assert_ne "${pw//[a-zA-Z0-9]/}" "" "symbol"

t "i.pwgen rejects impossible num_each"
out=$(i.pwgen 4 2); rc=$?
assert_eq "$rc" "1" "exit code"
assert_contains "$out" "Error"

t "fileformat maps the current platform"
case "$(uname -s)" in
    Darwin) want=macho64 ;;
    Linux)  want=elf64 ;;
    *)      want="" ;;
esac
assert_eq "$(fileformat)" "$want"

# routes defines lsnoext + source_or_error, then walks PATHS; under the fake
# $HOME every dir is missing so the walk only prints warnings (discarded).
source "$REPO/zshrc/routes" >/dev/null 2>&1

t "source_or_error reports a missing file with rc 1"
out=$(source_or_error /no/such/file); rc=$?
assert_contains "$out" "doesn't exist"
assert_eq "$rc" "1" "exit code"

t "source_or_error sources an existing file with rc 0"
print -r -- 'TESTVAR=42' > "$T_DIR/f"
source_or_error "$T_DIR/f" >/dev/null; rc=$?
assert_eq "$rc" "0" "exit code"
assert_eq "$TESTVAR" "42"

t "lsnoext lists only extension-less files"
mkdir -p "$T_DIR/lx"
touch "$T_DIR/lx/a.txt" "$T_DIR/lx/b"
out=$(lsnoext "$T_DIR/lx")
assert_contains "$out" "/b"
assert_not_contains "$out" "a.txt"

t_done
