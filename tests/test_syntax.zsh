#!/usr/bin/env zsh
# Repo-wide safety net: every shell file zsh sources must parse under zsh -n,
# every bash script under bash -n (+ shellcheck errors when installed).
# Catches future parse errors in files that have no dedicated suite.
source "${0:A:h}/lib.zsh"

typeset -a zfiles
zfiles=(
    "$REPO"/zshrc/zshrc "$REPO"/zshrc/zprofile "$REPO"/zshrc/routes "$REPO"/zshrc/log
    "$REPO"/zshrc/aliases/init
    "$REPO"/zshrc/aliases/utils/*(.N)
    "$REPO"/zshrc/aliases/os/*(.N)
    "$REPO"/zshrc/aliases/integrations/**/*(.N)
    "$REPO"/zshrc/aliases/lazy/*(.N)
    "$REPO"/zshrc/config/init(.N)
    "$REPO"/zshrc/config/helpers/*(.N)
)
for f in $zfiles; do
    [[ $f == *secret* ]] && continue
    t "zsh -n ${f#$REPO/}"
    err=$(zsh -fn "$f" 2>&1)
    [[ $? -eq 0 ]] && _t_pass || _t_fail "$err"
done

# Scripts: route by shebang. zsh scripts get zsh -n; bash/sh (or shebang-less,
# they are sourced by setup.sh which is bash) get bash -n + shellcheck.
typeset -a bfiles
for f in "$REPO"/setup.sh "$REPO"/git/*.sh(.N) "$REPO"/zshrc/scripts/*.sh(.N); do
    if [[ "$(head -n1 "$f")" == *zsh* ]]; then
        t "zsh -n ${f#$REPO/}"
        err=$(zsh -fn "$f" 2>&1)
        [[ $? -eq 0 ]] && _t_pass || _t_fail "$err"
    else
        bfiles+=( "$f" )
        t "bash -n ${f#$REPO/}"
        err=$(bash -n "$f" 2>&1)
        [[ $? -eq 0 ]] && _t_pass || _t_fail "$err"
    fi
done

if command -v shellcheck >/dev/null 2>&1; then
    for f in $bfiles; do
        t "shellcheck ${f#$REPO/}"
        err=$(shellcheck -S error "$f" 2>&1)
        [[ $? -eq 0 ]] && _t_pass || _t_fail "$err"
    done
else
    t "shellcheck lint pass"
    t_skip "shellcheck not installed"
fi

t_done
