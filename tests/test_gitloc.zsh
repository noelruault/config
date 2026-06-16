#!/usr/bin/env zsh
# gitloc: per-extension line-churn aggregation over git diff --numstat.
source "${0:A:h}/lib.zsh"
t_sandbox
source "$REPO/zshrc/aliases/utils/internal"
unalias rm cp hs 2>/dev/null   # internal sets rm -i / cp→rsync; keep tests deterministic

export GIT_CONFIG_NOSYSTEM=1   # fake $HOME already hides the user gitconfig
mkdir -p "$T_DIR/repo" && cd "$T_DIR/repo" || exit 1
git init -q .
git config user.email test@test && git config user.name test

print -l 'line1' 'line2' > a.go
print -r -- 'hello' > b.md
print -r -- 'x' > noext
git add -A && git commit -qm base

# a.go: +2 -0, b.md: +1 -1, noext: +1 -0
print -l 'line3' 'line4' >> a.go
print -r -- 'goodbye' > b.md
print -r -- 'y' >> noext

t "groups churn by extension"
out=$(gitloc)
assert_contains "$(print -r -- $out | grep '^\.go')" "+2 -0 =2" ".go row"
assert_contains "$(print -r -- $out | grep '^\.md')" "+1 -1 =2" ".md row"
assert_contains "$(print -r -- $out | grep '(noext)')" "+1 -0 =1" "noext row"

t "TOTAL row sums all extensions"
assert_contains "$(print -r -- $out | grep '^TOTAL')" "+4 -1 =5" "total row"

t "--ignore-space hides whitespace-only churn"
git add -A && git commit -qm second
print -r -- 'goodbye   ' > b.md          # trailing-space-only change
assert_contains "$(gitloc | grep '^TOTAL')" "+1 -1 =2" "without flag: counted"
assert_contains "$(gitloc --ignore-space | grep '^TOTAL')" "+0 -0 =0" "with flag: ignored"

t_done
