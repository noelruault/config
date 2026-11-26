#!/usr/bin/env zsh
# Mechanical half of GUIDELINES.md: each rule there that a pattern can decide is decided here, so a rule cannot be skipped by not reading the document.
# Every rule carries a sample that must trip it. A pattern that stops matching its own sample fails the suite instead of passing silently.
source "${0:A:h}/lib.zsh"

typeset -a shell_files setup_files platform_free_files
for f in ${(f)"$(git -C "$REPO" ls-files -co --exclude-standard)"}; do
    [[ -f $REPO/$f ]] || continue
    [[ $f == (*.md|zshrc/notebook.d/*|zshrc/templates/*|nvim/*|iterm2/*|quick-actions/*|tests/test_slop.zsh) ]] && continue
    grep -Iq . "$REPO/$f" 2>/dev/null || continue
    shell_files+=( "$f" )
    [[ $f == (setup.sh|setup/*) ]] && setup_files+=( "$f" )
done

# Stage 0 runs before bash 5 exists, under the 3.2 that macOS ships.
typeset -a stage_zero_files
stage_zero_files=( setup.sh setup/lib/{ui,platform,download}.sh ${(M)setup_files:#setup/lib/bootstrap-*.sh} )

# Platform-free: all of setup/ except the platform probe, the *-darwin.sh files and the components that declare darwin.
for f in $setup_files; do
    [[ $f == (setup/lib/platform.sh|*-darwin.sh) ]] && continue
    grep -qE '^define_component [a-z_]+ darwin ' "$REPO/$f" && continue
    platform_free_files+=( "$f" )
done

# forbid RULE SAMPLE PATTERN FILE... fails once per matching line, naming the rule to look up in GUIDELINES.md.
forbid() {
    local rule=$1 sample=$2 pattern=$3
    shift 3
    t "$rule: pattern catches its own sample"
    print -r -- "$sample" | grep -qE -- "$pattern" && _t_pass || _t_fail "pattern no longer matches [$sample]"
    t "$rule"
    local hits
    hits=$(cd "$REPO" && grep -nE -- "$pattern" "$@" /dev/null 2>/dev/null)
    [[ -z $hits ]] && _t_pass || _t_fail "see GUIDELINES.md \"$rule\""$'\n'"$hits"
}

forbid "remote-installer" 'curl -fsSL https://example.com/install.sh | bash' \
    '(curl|wget)[^|#]*\|[[:space:]]*(sudo[[:space:]]+)?([^[:space:]]*/)?(ba|z|da)?sh([[:space:]]|$)|(ba|z|da)?sh[[:space:]]+(-c[[:space:]]+"\$\(|<\()[[:space:]]*(curl|wget)' \
    ${shell_files:#setup/lib/download.sh}

forbid "disable-needs-reason" '# shellcheck disable=SC2034' \
    'shellcheck disable=[A-Z0-9,]+[[:space:]]*$' \
    $shell_files

forbid "packages-are-data" '    brew install ripgrep' \
    'brew[[:space:]]+(install|tap)[[:space:]]' \
    ${setup_files:#setup/lib/bootstrap-darwin.sh}

forbid "stage-zero-is-bash-3.2" 'declare -A seen=()' \
    '(declare|local|typeset)[[:space:]]+-[a-zA-Z]*[Ang]|mapfile|readarray|wait[[:space:]]+-n|\$\{[A-Za-z_][A-Za-z0-9_]*(\[[^]]*\])?(,,?|\^\^?|@[A-Za-z])|\[-[0-9]+\]|\|&|&>>|coproc' \
    $stage_zero_files

t "stage-zero-is-bash-3.2: the list matches what setup.sh loads before restarting"
declared=$(sed -n 's/^STAGE_ZERO_LIBS=(\(.*\))$/\1/p' "$REPO/setup.sh")
assert_eq "$declared" "ui platform download"

t "stage-zero-is-bash-3.2: every stage 0 file parses under /bin/bash"
if [[ $(/bin/bash -c 'echo ${BASH_VERSINFO[0]}' 2>/dev/null) == 3 ]]; then
    err=$(cd "$REPO" && for f in $stage_zero_files; do /bin/bash -n "$f" 2>&1; done)
    [[ -z $err ]] && _t_pass || _t_fail "$err"
else
    t_skip "/bin/bash is not 3.x here"
fi

forbid "no-swallowed-errors" 'git pull --ff-only || true' \
    '\|\|[[:space:]]*(true|:)([[:space:];)]|$)' \
    $setup_files

forbid "no-exit-in-components" '[ -d "$dir" ] || exit 1' \
    '^([^#]*[;&|([:space:]])?exit([[:space:];)]|$)' \
    ${setup_files:#setup.sh}

forbid "platform-seam: probe" 'if [[ $OSTYPE == darwin* ]]; then' \
    '\$\{?OSTYPE|uname([^[:alnum:]_]|$)|sw_vers' \
    ${setup_files:#setup/lib/platform.sh}

forbid "platform-seam: macOS-only command" 'launchctl bootstrap gui/501 file.plist' \
    '(^|[^a-z_-])(launchctl|osascript|pbcopy|pbpaste|brew|chsh)[[:space:]]|defaults[[:space:]]+(read|write)|/Library/' \
    $platform_free_files

t "lint: shellcheck style-clean on setup"
if command -v shellcheck >/dev/null 2>&1; then
    err=$(cd "$REPO" && shellcheck -S style $setup_files 2>&1)
    [[ $? -eq 0 ]] && _t_pass || _t_fail "$err"
else
    t_skip "shellcheck not installed"
fi

t "lint: shfmt-clean on setup"
if command -v shfmt >/dev/null 2>&1; then
    err=$(cd "$REPO" && shfmt -d -i 4 -ci -sr $setup_files 2>&1)
    [[ $? -eq 0 ]] && _t_pass || _t_fail "run: shfmt -w -i 4 -ci -sr setup.sh setup"$'\n'"$err"
else
    t_skip "shfmt not installed"
fi

t_done
