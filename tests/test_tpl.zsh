#!/usr/bin/env zsh
# tpl: template launcher (ls / info / new) against a sandboxed templates dir.
source "${0:A:h}/lib.zsh"
t_sandbox
source "$REPO/zshrc/aliases/utils/tpl"

# Scrub PATH so `code` can never launch an editor from a test.
PATH="/usr/bin:/bin"

export ZSH_CUSTOM_CONFIG_TEMPLATES="$T_DIR/templates"
mkdir -p "$ZSH_CUSTOM_CONFIG_TEMPLATES/_demo" "$ZSH_CUSTOM_CONFIG_TEMPLATES/_bare"
print -r -- 'demo template readme' > "$ZSH_CUSTOM_CONFIG_TEMPLATES/_demo/README.md"
print -r -- 'placeholder' > "$ZSH_CUSTOM_CONFIG_TEMPLATES/_bare/file.txt"
print -r -- '#!/bin/sh' > "$ZSH_CUSTOM_CONFIG_TEMPLATES/_demo/.init.sh"
print -r -- 'touch .init-ran' >> "$ZSH_CUSTOM_CONFIG_TEMPLATES/_demo/.init.sh"
chmod +x "$ZSH_CUSTOM_CONFIG_TEMPLATES/_demo/.init.sh"

t "ls strips the underscore prefix"
out=$(tpl ls)
assert_eq "$out" $'bare\ndemo'

t "info prints README when present"
assert_contains "$(tpl info demo)" "demo template readme"

t "info falls back to ls -la without README"
assert_contains "$(tpl info bare)" "file.txt"

t "info on unknown template fails"
tpl info nope >/dev/null 2>&1
assert_eq "$?" "1" "exit code"

t "new copies the template and runs .init.sh"
out=$(tpl new demo "$T_DIR/proj" 2>&1); rc=$?
assert_eq "$rc" "0" "exit code"
assert_file_exists "$T_DIR/proj/README.md"
assert_file_exists "$T_DIR/proj/.init-ran" ".init.sh ran in dest"

t "new refuses an existing destination"
out=$(tpl new demo "$T_DIR/proj" 2>&1)
assert_eq "$?" "1" "exit code"
assert_contains "$out" "already exists"

t "new on unknown template fails"
tpl new nope "$T_DIR/other" >/dev/null 2>&1
assert_eq "$?" "1" "exit code"
[[ ! -e "$T_DIR/other" ]]; assert_eq "$?" "0" "no partial destination created"

t "bad subcommand prints usage and fails"
out=$(tpl frobnicate 2>&1)
assert_eq "$?" "1" "exit code"
assert_contains "$out" "usage"

t_done
