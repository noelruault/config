# Shared assertions + sandbox for tests/test_*.zsh.
# Each test file is standalone and run via `zsh -f <file>` by run.sh:
#
#   source "${0:A:h}/lib.zsh"
#   t_sandbox                  # optional: fake $HOME + temp workdir in $T_DIR
#   t "case name"              # label the current case (used in failure output)
#   assert_eq "$got" "want"
#   t_done                     # print summary, exit 0/1

typeset -g _T_PASS=0 _T_FAIL=0 _T_SKIP=0 _T_CASE=""
typeset -g T_DIR

# Repo root = parent of the tests/ directory this file lives in.
typeset -g REPO=${${(%):-%x}:A:h:h}

t() { _T_CASE="$1"; }

_t_pass() {
    _T_PASS=$(( _T_PASS + 1 ))
    [[ -n ${TEST_VERBOSE:-} ]] && print "  ok $_T_PASS [$_T_CASE]"
    return 0
}
_t_fail() { _T_FAIL=$(( _T_FAIL + 1 )); print -u2 "  FAIL [$_T_CASE] $*"; return 0; }

# Mark the current case skipped (counted separately, shown in the summary).
t_skip() { _T_SKIP=$(( _T_SKIP + 1 )); print "  SKIP [$_T_CASE] $*"; }

assert_eq()           { [[ "$1" == "$2" ]] && _t_pass || _t_fail "${3:-}: expected [$2], got [$1]"; }
assert_ne()           { [[ "$1" != "$2" ]] && _t_pass || _t_fail "${3:-}: expected anything but [$2]"; }
assert_contains()     { [[ "$1" == *"$2"* ]] && _t_pass || _t_fail "${3:-}: missing [$2] in [$1]"; }
assert_not_contains() { [[ "$1" != *"$2"* ]] && _t_pass || _t_fail "${3:-}: unexpected [$2] in [$1]"; }
assert_file_exists()  { [[ -f "$1" ]] && _t_pass || _t_fail "${2:-}: missing file $1"; }

# Isolated workdir + fake $HOME so no test can touch the real history file,
# keychain, or config. Cleaned up on exit via zshexit: an EXIT trap set inside
# a function would fire when the function returns and wipe the sandbox early.
t_sandbox() {
    # Double-call would overwrite zshexit and leak the first T_DIR in /tmp.
    [[ -n ${T_DIR:-} ]] && { print -u2 "t_sandbox: called twice"; exit 1; }
    T_DIR=$(mktemp -d "${TMPDIR:-/tmp}/cfgtest.XXXXXX") || exit 1
    export HOME="$T_DIR/home"
    mkdir -p "$HOME"
    zshexit() { rm -rf "$T_DIR"; }
}

t_done() {
    local skips=""
    (( _T_SKIP )) && skips=", $_T_SKIP skipped"
    if (( _T_FAIL )); then
        print -u2 "  $_T_PASS passed, $_T_FAIL FAILED$skips"
        exit 1
    fi
    print "  $_T_PASS passed$skips"
    exit 0
}
