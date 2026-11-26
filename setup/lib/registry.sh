# shellcheck shell=bash
# The component list. init, update and doctor all walk COMPONENT_ORDER, so a tool cannot be installed by one command and forgotten by another.

# Run order. Later components may rely on earlier ones: packages needs homebrew, the private clones need the SSH key, default_editor needs bin_links.
COMPONENT_ORDER=(
    config_link
    homebrew
    packages
    login_shell
    oh_my_zsh
    shell_rc
    git_config
    ssh_key
    git_signing
    fonts
    aispeak
    loopctl
    router
    bin_links
    quick_actions
    default_editor
)

# -g because this file is sourced from inside main(): without it the maps would be locals of whichever function did the sourcing.
declare -gA COMPONENT_PLATFORM=() COMPONENT_REQUIREMENT=() COMPONENT_DESCRIPTION=()
SELECTED_COMPONENTS=()

# define_component takes NAME, all|darwin|linux, required|optional and a description.
# A required component stops init when its install fails and makes doctor fail when its check does; an optional one only warns.
define_component() {
    COMPONENT_PLATFORM[$1]="$2"
    COMPONENT_REQUIREMENT[$1]="$3"
    COMPONENT_DESCRIPTION[$1]="$4"
}

list_contains() {
    local wanted="$1" item
    shift
    for item in "$@"; do
        [ "$item" = "$wanted" ] && return 0
    done
    return 1
}

# select_components fills SELECTED_COMPONENTS from COMPONENT_ORDER, narrowed by the --only and --skip lists.
# A name that is not a component is an error: a typo must not silently run everything.
select_components() {
    local only_list=() skip_list=() name
    IFS=',' read -ra only_list <<< "$1"
    IFS=',' read -ra skip_list <<< "$2"
    for name in "${only_list[@]}" "${skip_list[@]}"; do
        if ! list_contains "$name" "${COMPONENT_ORDER[@]}"; then
            say_fail "unknown component: $name (run: setup.sh components)"
            return 1
        fi
    done
    SELECTED_COMPONENTS=()
    for name in "${COMPONENT_ORDER[@]}"; do
        if [ ${#only_list[@]} -gt 0 ] && ! list_contains "$name" "${only_list[@]}"; then
            continue
        fi
        if list_contains "$name" "${skip_list[@]}"; then
            continue
        fi
        SELECTED_COMPONENTS+=("$name")
    done
}

list_components() {
    local name
    printf '%-16s %-8s %-9s %s\n' COMPONENT PLATFORM REQUIRED DESCRIPTION
    for name in "${SELECTED_COMPONENTS[@]}"; do
        printf '%-16s %-8s %-9s %s\n' "$name" "${COMPONENT_PLATFORM[$name]}" "${COMPONENT_REQUIREMENT[$name]}" "${COMPONENT_DESCRIPTION[$name]}"
    done
}
