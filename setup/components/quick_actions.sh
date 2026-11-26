# shellcheck shell=bash
# Linked, not copied, so editing a workflow here applies without reinstalling it.
define_component quick_actions darwin optional "Finder Quick Actions"

QUICK_ACTIONS_SERVICES="$HOME/Library/Services"

component_quick_actions_install() {
    local workflow
    mkdir -p "$QUICK_ACTIONS_SERVICES"
    for workflow in "$SETUP_ROOT"/quick-actions/*.workflow; do
        [ -d "$workflow" ] || continue
        ln -sfn "$workflow" "$QUICK_ACTIONS_SERVICES/$(basename "$workflow")" || return 1
        say_ok "$(basename "$workflow" .workflow)"
    done
    # -flush before -update: -update alone keeps the stale cache and leaves new actions out of Finder's Quick Actions > Customize list until logout.
    /System/Library/CoreServices/pbs -flush 2> /dev/null
    /System/Library/CoreServices/pbs -update 2> /dev/null
    return 0
}

component_quick_actions_check() {
    local workflow status=0
    for workflow in "$SETUP_ROOT"/quick-actions/*.workflow; do
        [ -d "$workflow" ] || continue
        check --hint "run: setup.sh init --only quick_actions" "$(basename "$workflow") is linked into Services" test "$QUICK_ACTIONS_SERVICES/$(basename "$workflow")" -ef "$workflow" || status=1
    done
    return "$status"
}
