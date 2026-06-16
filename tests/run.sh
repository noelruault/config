#!/usr/bin/env zsh
# Test runner for the config repo.
#   tests/run.sh           run every tests/test_*.zsh + glow-stream go tests
#   tests/run.sh histrm    run only tests/test_histrm.zsh
#
# Each test file runs in its own `zsh -f` process: no user rc files, no
# oh-my-zsh, no aliases (rm -i, cp→rsync) leaking into assertions.

set -u
here=${0:A:h}
fails=0

typeset -a files
if [[ -n ${1:-} ]]; then
    files=( "$here/test_$1.zsh" )
    [[ -f $files[1] ]] || { print -u2 "run.sh: no such test: $1"; exit 2; }
else
    files=( "$here"/test_*.zsh )
fi

zmodload zsh/datetime
for f in $files; do
    print -P "%F{cyan}== ${f:t:r}%f"
    t0=$EPOCHREALTIME
    zsh -f "$f" || fails=$(( fails + 1 ))
    printf "  (%.0f ms)\n" $(( (EPOCHREALTIME - t0) * 1000 ))
done

# glow-stream has its own Go test suite; run it when go is available.
if [[ -z ${1:-} ]]; then
    if command -v go >/dev/null 2>&1; then
        print -P "%F{cyan}== glow-stream (go test)%f"
        ( cd "$here/../zshrc/scripts/glow-stream" && go test ./... ) || fails=$(( fails + 1 ))
    else
        print "== glow-stream: skipped (go not installed)"
    fi
fi

if (( fails )); then
    print -P "%F{red}$fails test file(s) failed%f"
    exit 1
fi
print -P "%F{green}all tests passed%f"
