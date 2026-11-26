#!/bin/bash
# Machine setup for this repo: install, update and check every component in setup/components.
# This file is stage 0: it runs under whatever bash started it, including the 3.2 that macOS ships, and restarts itself under bash 5 before any other code loads.
# shellcheck disable=SC2034  # LOCAL_BIN and SETUP_ASSUME_YES are read by the files sourced from setup/

# `sh setup.sh` or `zsh setup.sh` ignores the first line of this file. This hands over to bash before the first line a plain sh cannot parse.
# shellcheck disable=SC2292  # must stay POSIX: the shell reading this line may not be bash
[ -n "${BASH_VERSION:-}" ] || exec bash "$0" "$@"

# Stage 0 files must stay valid bash 3.2. Everything else in setup/ may use bash 5.
STAGE_ZERO_LIBS=(ui platform download)
MODERN_LIBS=(private-repo interactive registry runner)

usage() {
    cat << EOF
USAGE:
    setup.sh COMMAND [OPTIONS]

COMMANDS:
    init          install every component (safe to run again)
    update        pull this repo, then update every component
    doctor        check every component; exits 1 when a required one fails
    components    list what setup manages, in run order

OPTIONS:
    --dry-run       print the plan, change nothing
    --only a,b      limit the run to these components
    --skip a,b      leave these components out
    --yes           answer every yes/no prompt with yes
    -h, --help      show this help
EOF
}

# hint_shortcut tells whoever just typed the full path to setup.sh that bin_links gave them a shorter name for it.
hint_shortcut() {
    [ "$SETUP_DRY_RUN" = false ] && [ -x "$LOCAL_BIN/cfg" ] || return 0
    if command -v cfg > /dev/null 2>&1; then
        say_info "from now on: cfg doctor, cfg update (cfg alone lists the commands)"
    else
        say_info "in a new terminal: cfg doctor, cfg update (cfg alone lists the commands)"
    fi
}

source_libs() {
    local name
    for name in "$@"; do
        # shellcheck disable=SC1090  # path is built at runtime
        source "$SETUP_ROOT/setup/lib/$name.sh" || exit 1
    done
}

# restart_under_modern_bash replaces this process with the same command line running under bash 5, installing that bash first when init or update is allowed to.
# The platform's bootstrap file supplies modern_bash_path and install_modern_bash; a platform without one has to bring its own bash 5.
restart_under_modern_bash() {
    local command="$1" modern_bash=""
    shift
    if ! declare -F modern_bash_path > /dev/null; then
        say_fail "setup needs bash 5 or newer and this is bash $BASH_VERSION"
        return 1
    fi
    modern_bash=$(modern_bash_path)
    if [ -z "$modern_bash" ]; then
        case "$command" in
            init | update)
                if [ "$SETUP_DRY_RUN" = true ]; then
                    say_info "would install bash 5 first; run again after that for the full plan"
                    return 0
                fi
                install_modern_bash || return 1
                modern_bash=$(modern_bash_path)
                ;;
        esac
    fi
    if [ -z "$modern_bash" ]; then
        say_fail "bash 5 is not installed (run: setup.sh init)"
        return 1
    fi
    exec "$modern_bash" "$SETUP_ROOT/setup.sh" "$@"
}

main() {
    SETUP_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P) || exit 1
    LOCAL_BIN="$HOME/.local/bin"
    SETUP_DRY_RUN=false
    SETUP_ASSUME_YES=false

    local command="" only="" skip="" original_arguments=("$@")
    while [ $# -gt 0 ]; do
        case "$1" in
            init | update | doctor | components) command="$1" ;;
            --dry-run) SETUP_DRY_RUN=true ;;
            --yes) SETUP_ASSUME_YES=true ;;
            --only | --skip)
                # An empty list is refused too: `--only "$UNSET"` would otherwise select every component.
                if [ $# -lt 2 ] || [ -z "$2" ]; then
                    echo "setup.sh: $1 needs a comma-separated list" >&2
                    exit 2
                fi
                if [ "$1" = --only ]; then only="$2"; else skip="$2"; fi
                shift
                ;;
            -h | --help)
                usage
                exit 0
                ;;
            *)
                echo "setup.sh: unknown argument: $1" >&2
                usage >&2
                exit 2
                ;;
        esac
        shift
    done

    # No command is never an install: a bare `cfg` typed to see what it does must not start changing the machine.
    if [ -z "$command" ]; then
        if [ ${#original_arguments[@]} -eq 0 ]; then
            usage
            exit 0
        fi
        echo "setup.sh: no command given" >&2
        usage >&2
        exit 2
    fi

    source_libs "${STAGE_ZERO_LIBS[@]}"
    if [ -f "$SETUP_ROOT/setup/lib/bootstrap-$SETUP_OS.sh" ]; then
        source_libs "bootstrap-$SETUP_OS"
    fi
    if [ "${BASH_VERSINFO[0]}" -lt 5 ]; then
        restart_under_modern_bash "$command" "${original_arguments[@]}"
        exit $?
    fi

    # After a pull this process still holds the old setup.sh and stage 0 libs, so it starts over to run the code it just fetched. SETUP_PULLED stops the second pass from pulling again.
    if [ "$command" = update ] && [ "$SETUP_DRY_RUN" = false ] && [ -z "${SETUP_PULLED:-}" ]; then
        if git -C "$SETUP_ROOT" pull --ff-only; then
            SETUP_PULLED=1 exec "$BASH" "$SETUP_ROOT/setup.sh" "${original_arguments[@]}"
        fi
        say_warn "could not pull $SETUP_ROOT, updating from the current checkout"
    fi

    source_libs "${MODERN_LIBS[@]}"
    local file
    for file in "$SETUP_ROOT"/setup/components/*.sh; do
        # shellcheck disable=SC1090  # path is built at runtime
        source "$file" || exit 1
    done

    select_components "$only" "$skip" || exit 2

    case "$command" in
        init)
            run_phase install || exit 1
            hint_shortcut
            ;;
        update) run_phase update ;;
        doctor) run_phase check ;;
        components) list_components ;;
    esac
}

# main is called on the last line so bash has parsed the whole file before `update` pulls a newer copy over it.
main "$@"
