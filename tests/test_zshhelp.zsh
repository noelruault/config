#!/usr/bin/env zsh
# _zshhelp_scan: the perl parser that pairs commands with their doc comments.
source "${0:A:h}/lib.zsh"
t_sandbox
source "$REPO/zshrc/aliases/utils/zshhelp"

fix="$T_DIR/fixture"
cat > "$fix" <<'EOF'
#!/bin/bash
# greets the user politely
hello() {
    echo hi
}

# https://example.com/docs
weird() {
    echo no
}

alias gg='git grep' # search the repo fast
alias xx='ls'

# pending comment killed by intervening code
export FOO=bar
dropped() {
    echo
}

# keyword form also works fine
function withkw() {
    echo
}

# first line of a two-line comment
# second line wins as description
twoline() {
    echo
}

#!do not describe me
shebangish() {
    echo
}
EOF

typeset -A got
while IFS=$'\t' read -r n d; do got[$n]=$d; done < <(_zshhelp_scan "$fix")

t "function with doc comment above"
assert_eq "${got[hello]-MISSING}" "greets the user politely"

t "URL-only comment is not a description"
assert_eq "${got[weird]-MISSING}" ""

t "alias with inline comment"
assert_eq "${got[gg]-MISSING}" "search the repo fast"

t "alias without comment"
assert_eq "${got[xx]-MISSING}" ""

t "code line between comment and definition drops the comment"
assert_eq "${got[dropped]-MISSING}" ""

t "function keyword form is recognized"
assert_eq "${got[withkw]-MISSING}" "keyword form also works fine"

t "multi-line comment: last line becomes the description"
assert_eq "${got[twoline]-MISSING}" "second line wins as description"

# A #!-comment directly above a definition (no prose line in between) is the
# case the ! filter actually guards; the old loop over all descriptions passed
# even with the filter broken, because prose comments overwrite $last anyway.
t "#!-style comment directly above a definition is rejected"
assert_eq "${got[shebangish]-MISSING}" ""

t_done
