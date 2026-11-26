#!/usr/bin/env zsh
# setup.sh: the component contract, component selection, dry-run, and real install/doctor runs inside a fake $HOME.
source "${0:A:h}/lib.zsh"
t_sandbox

# Everything past stage 0 needs bash 5, and `bash` on PATH may still be the 3.2 from macOS.
modern_bash=bash
for candidate in /opt/homebrew/bin/bash /usr/local/bin/bash; do
    [[ -x $candidate ]] && { modern_bash=$candidate; break; }
done

# SETUP_STRICT_REPORT: every real component run in this file fails if a step prints nothing about what it did.
setup() { SETUP_STRICT_REPORT=1 "$modern_bash" "$REPO/setup.sh" "$@" 2>&1; }

# with_fixture_components runs BODY in a bash that has setup/lib loaded and three made-up components instead of the real ones:
# first is optional and fails, second is required and fails, third records that it ran.
with_fixture_components() {
    "$modern_bash" -c '
        SETUP_ROOT=$1 SETUP_DRY_RUN=false SETUP_ASSUME_YES=false
        for file in ui platform registry runner; do source "$1/setup/lib/$file.sh"; done
        COMPONENT_ORDER=(first second third)
        define_component first all optional "fails, optional"
        define_component second all required "fails, required"
        define_component third all optional "records that it ran"
        component_first_install() { return 1; }
        component_second_install() { return 1; }
        component_third_install() { echo THIRD_INSTALLED; }
        component_third_update() { echo THIRD_UPDATED; }
        '"$1" _ "$REPO" 2>&1
}

# empty_sections prints every "== name" header in OUTPUT that has no line of its own under it.
empty_sections() {
    print -r -- "$1" | sed $'s/\x1b\\[[0-9;]*m//g' | awk '
        /^== / { if (header != "") print header; header = $0; next }
        NF { header = "" }
        END { if (header != "") print header }'
}

t "empty_sections: catches a header with nothing under it, in the middle and at the end"
assert_eq "$(empty_sections $'== one\n  ok\n\n== two\n\n== three\n  ok\n\n== four')" $'== two\n== four'

t "contract: every component file is in COMPONENT_ORDER and the other way round"
typeset -a on_disk in_order
on_disk=( "$REPO"/setup/components/*.sh(N:t:r) )
in_order=( ${(f)"$(setup components | awk 'NR > 1 { print $1 }')"} )
in_order=( ${(o)in_order} ) on_disk=( ${(o)on_disk} )
assert_eq "$in_order" "$on_disk"

t "contract: every component defines install and check with a valid platform and requirement"
broken=$("$modern_bash" -c '
    SETUP_ROOT=$1 LOCAL_BIN=$HOME/.local/bin
    for file in ui platform download bootstrap-darwin private-repo interactive registry runner; do source "$1/setup/lib/$file.sh"; done
    for file in "$1"/setup/components/*.sh; do source "$file"; done
    for name in "${COMPONENT_ORDER[@]}"; do
        declare -F "component_${name}_install" > /dev/null || echo "$name: no install step"
        declare -F "component_${name}_check" > /dev/null || echo "$name: no check step"
        case "${COMPONENT_PLATFORM[$name]}" in all | darwin | linux) ;; *) echo "$name: bad platform" ;; esac
        case "${COMPONENT_REQUIREMENT[$name]}" in required | optional) ;; *) echo "$name: bad requirement" ;; esac
    done' _ "$REPO" 2>&1)
assert_eq "$broken" ""

# The runner's closing line for a silent step only repeats the description, which says what the component is, not what this run did.
t "contract: every component reports what it did in its own words"
vague=""
for file in "$REPO"/setup/components/*.sh; do
    grep -qE 'say_ok|install_private_command' "$file" || vague+="${file:t} "
done
assert_eq "$vague" ""

t "stage 0: started under the bash 3.2 from macOS, setup restarts itself under bash 5"
if [[ $(/bin/bash -c 'echo ${BASH_VERSINFO[0]}' 2>/dev/null) == 3 && $modern_bash != bash ]]; then
    out=$(/bin/bash "$REPO/setup.sh" components 2>&1)
    assert_eq "$?" "0"
    assert_contains "$out" "default_editor"
    assert_eq "$(/bin/bash "$REPO/setup.sh" init --dry-run --only bin_links 2>&1 | awk '{ print $3 }')" "bin_links"
else
    t_skip "needs /bin/bash 3.x and a Homebrew bash"
fi

t "started by a shell that is not bash, setup hands over to bash instead of misparsing"
for shell in /bin/sh /bin/zsh /bin/dash /bin/ksh; do
    [[ -x $shell ]] || continue
    out=$("$shell" "$REPO/setup.sh" components 2>&1)
    assert_eq "$?" "0" "$shell: $out"
    assert_contains "$out" "default_editor" "$shell"
    assert_eq "$("$shell" "$REPO/setup.sh" init --dry-run --only bin_links 2>&1 | awk '{ print $3 }')" "bin_links" "$shell"
done

t "stage 0: without a bash 5 to restart under, the run stops with a message instead of a syntax error"
out=$("$modern_bash" -c '
    SETUP_ROOT=$1 SETUP_DRY_RUN=false
    source "$1/setup/lib/ui.sh"
    eval "$(sed -n "/^restart_under_modern_bash()/,/^}/p" "$1/setup.sh")"
    modern_bash_path() { return 1; }
    install_modern_bash() { echo INSTALL_CALLED; return 1; }
    restart_under_modern_bash doctor; echo "doctor=$?"
    restart_under_modern_bash init; echo "init=$?"
    SETUP_DRY_RUN=true; restart_under_modern_bash init --dry-run; echo "dry=$?"
    restart_under_modern_bash doctor --dry-run; echo "doctordry=$?"' _ "$REPO" 2>&1)
assert_contains "$out" "bash 5 is not installed"
assert_contains "$out" "doctor=1"
assert_contains "$out" $'INSTALL_CALLED\ninit=1'
assert_contains "$out" "dry=0"
assert_contains "$out" "doctordry=1"
assert_eq "$(print -r -- "$out" | grep -c INSTALL_CALLED)" "1"

t "dry-run prints the plan and changes nothing"
out=$(setup init --dry-run)
assert_contains "$out" "would install config_link"
assert_eq "$(ls -A "$HOME")" ""

t "update --dry-run does not pull or run"
mkdir -p "$T_DIR/fakebin"
print -r -- '#!/bin/sh'$'\n''echo "$@" >> "$GIT_CALLS"' > "$T_DIR/fakebin/git"
chmod +x "$T_DIR/fakebin/git"
out=$(GIT_CALLS="$T_DIR/git-calls" PATH="$T_DIR/fakebin:$PATH" setup update --dry-run)
assert_contains "$out" "would update packages"
[[ -e $T_DIR/git-calls ]] && _t_fail "git was called: $(<$T_DIR/git-calls)" || _t_pass
assert_eq "$(ls -A "$HOME")" ""

t "an empty --only list is an error, not a full run"
out=$(setup init --dry-run --only "")
assert_eq "$?" "2"
assert_not_contains "$out" "would install"

t "--only keeps just the named components, in run order"
out=$(setup init --dry-run --only bin_links,config_link)
assert_eq "$(print -r -- "$out" | awk '{ print $3 }' | tr '\n' ' ')" "config_link bin_links "

t "--skip leaves a component out"
out=$(setup init --dry-run --skip fonts)
assert_not_contains "$out" "would install fonts"
assert_contains "$out" "would install aispeak"

t "an unknown component name is an error, not a full run"
out=$(setup init --dry-run --only config_lnk)
assert_eq "$?" "2"
assert_contains "$out" "unknown component: config_lnk"

t "no command prints the help and changes nothing"
out=$(setup)
assert_eq "$?" "0"
assert_contains "$out" "COMMANDS:"
assert_eq "$(ls -A "$HOME")" ""

t "options without a command are an error, not an install"
out=$(setup --yes)
assert_eq "$?" "2"
assert_contains "$out" "no command given"
assert_eq "$(ls -A "$HOME")" ""

t "an unknown argument is an error"
setup --frobnicate >/dev/null
assert_eq "$?" "2"

t "platform seam: a linux plan has no darwin components"
out=$(SETUP_OS=linux setup init --dry-run)
assert_not_contains "$out" "homebrew"
assert_not_contains "$out" "quick_actions"
assert_contains "$out" "would install oh_my_zsh"

t "doctor exits 1 when a required component is not set up"
setup doctor --only config_link >/dev/null
assert_eq "$?" "1"

t "doctor only warns for an optional component"
out=$(setup doctor --only ssh_key)
assert_eq "$?" "0"
assert_contains "$out" "an ed25519 public key exists"

t "init backs up a real ~/.config, links it to the repo, and doctor then passes"
mkdir -p "$HOME/.config" && print keep > "$HOME/.config/mine"
out=$(setup init --only config_link,bin_links)
assert_eq "$?" "0"
assert_contains "$out" "cfg doctor"
assert_eq "$(empty_sections "$out")" ""
assert_contains "$out" "to-webp"
assert_not_contains "$out" "bin/ scripts linked into"
assert_eq "${HOME}/.config"(:A) "$REPO"
assert_eq "$(cat "$HOME"/.backup-config-*/mine)" "keep"
assert_eq "$HOME/.local/bin/to-webp"(:A) "$REPO/bin/to-webp"
[[ -e $HOME/.local/bin/README.md ]] && _t_fail "bin/README.md was linked as a command" || _t_pass
setup doctor --only config_link,bin_links >/dev/null
assert_eq "$?" "0"

t "cfg, linked into ~/.local/bin, runs this repo's setup.sh from another directory"
assert_contains "$(cd / && "$HOME/.local/bin/cfg" components 2>&1)" "default_editor"

t "init is safe to run again"
setup init --only config_link,bin_links >/dev/null
assert_eq "$?" "0"
backups=( "$HOME"/.backup-config-*(N) )
assert_eq "${#backups}" "1"

t "a repo cloned straight into ~/.config is left where it is"
rm -rf "$HOME/.config" "$HOME"/.backup-config-*(N)
mkdir -p "$HOME/.config"
cp -R "$REPO/setup.sh" "$REPO/setup" "$HOME/.config/"
out=$("$modern_bash" "$HOME/.config/setup.sh" init --only config_link 2>&1)
assert_eq "$?" "0" "$out"
assert_file_exists "$HOME/.config/setup.sh"
backups=( "$HOME"/.backup-config-*(N) )
assert_eq "${#backups}" "0"
rm -rf "$HOME/.config"

t "ssh_key: a signing key alone does not count as an SSH key"
mkdir -p "$HOME/.ssh" && : > "$HOME/.ssh/id_ed25519_signing.pub"
assert_contains "$(setup doctor --only ssh_key)" "⚠"
: > "$HOME/.ssh/id_ed25519-20260101.pub"
assert_contains "$(setup doctor --only ssh_key)" "✓"

t "--yes accepts the zsh overwrite prompt"
setup init --yes --only shell_rc >/dev/null
assert_eq "$HOME/.zshrc"(:A) "$REPO/zshrc/zshrc"
assert_eq "$HOME/.zprofile"(:A) "$REPO/zshrc/zprofile"

t "runner: a failed required component stops init and the run exits 1"
out=$(with_fixture_components 'select_components "" ""; run_phase install; echo "rc=$?"')
assert_not_contains "$out" "THIRD_INSTALLED"
assert_contains "$out" "rc=1"
assert_contains "$out" "setup.sh init --only second"

t "runner: a failed optional component does not stop init"
out=$(with_fixture_components 'select_components "" "second"; run_phase install; echo "rc=$?"')
assert_contains "$out" "THIRD_INSTALLED"
assert_contains "$out" "rc=0"
assert_contains "$out" "optional, with problems: first"

t "runner: a step that prints nothing still gets a line under its header"
out=$(with_fixture_components 'component_third_install() { :; }; select_components "first,third" ""; run_phase install')
assert_contains "$out" " records that it ran"
assert_contains "$out" " fails, optional: not done"

t "runner: no phase leaves an empty section, whatever a silent step returns"
for phase in install update check; do
    for silent_status in 0 1; do
        out=$(with_fixture_components "
            for name in first second third; do
                for step in install update check; do eval \"component_\${name}_\${step}() { return $silent_status; }\"; done
            done
            select_components '' ''; run_phase $phase")
        assert_eq "$(empty_sections "$out")" "" "$phase, steps return $silent_status"
        assert_contains "$out" "== summary"
    done
done

t "no real component leaves an empty section in doctor"
out=$(setup doctor)
assert_contains "$out" "== default_editor"
assert_eq "$(empty_sections "$out")" ""

t "runner: under SETUP_STRICT_REPORT a silent step fails the run, and a reporting one does not"
out=$(with_fixture_components 'SETUP_STRICT_REPORT=1; component_third_install() { :; }; select_components "third" ""; run_phase install; echo "rc=$?"')
assert_contains "$out" "rc=1"
assert_contains "$out" "printed nothing about what they did"
out=$(with_fixture_components 'SETUP_STRICT_REPORT=1; component_third_install() { say_ok "said it myself"; }; select_components "third" ""; run_phase install; echo "rc=$?"')
assert_contains "$out" "rc=0"

t "runner: a step that reported for itself gets no second line"
out=$(with_fixture_components 'component_third_install() { say_ok "said it myself"; }; select_components "third" ""; run_phase install')
assert_not_contains "$out" "records that it ran"

t "runner: update uses the update step when there is one and install otherwise"
out=$(with_fixture_components 'component_first_install() { echo FIRST_INSTALLED; }; select_components "first,third" ""; run_phase update')
assert_contains "$out" "FIRST_INSTALLED"
assert_contains "$out" "THIRD_UPDATED"
assert_not_contains "$out" "THIRD_INSTALLED"

t "check: --warn never fails, a plain check does"
out=$(with_fixture_components 'check --warn "soft" false; echo "soft=$?"; check "hard" false; echo "hard=$?"')
assert_contains "$out" "soft=0"
assert_contains "$out" "hard=1"

t_done
