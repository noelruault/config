# shellcheck shell=bash
# Terminal output and prompts. Components print through these, never with a bare echo.

# SETUP_LINES_SAID counts the lines printed under the current header. The runner reads it to give a step that printed nothing a closing line, so no section is left empty.
SETUP_LINES_SAID=0
count_line() { SETUP_LINES_SAID=$((SETUP_LINES_SAID + 1)); }

say_header() {
    SETUP_LINES_SAID=0
    printf '\n\033[1m== %s\033[0m\n' "$*"
}
say_info() {
    count_line
    printf '  %s\n' "$*"
}
say_ok() {
    count_line
    printf '  \033[32m✓\033[0m %s\n' "$*"
}
say_warn() {
    count_line
    printf '  \033[33m⚠\033[0m %s\n' "$*" >&2
}
say_fail() {
    count_line
    printf '  \033[31m✗\033[0m %s\n' "$*" >&2
}

# has_terminal succeeds when a prompt can reach a person. /dev/tty exists even without a controlling terminal, so it has to be opened to find out.
has_terminal() {
    { : < /dev/tty; } 2> /dev/null
}

# confirm asks a yes/no question with yes as the default. Without a terminal it answers no, so an unattended run never takes a step that was meant to be agreed to.
confirm() {
    local question="$1" answer
    if [ "$SETUP_ASSUME_YES" = true ]; then
        return 0
    fi
    if ! has_terminal; then
        say_warn "no terminal to ask \"$question\", answering no (pass --yes to accept)"
        return 1
    fi
    read -rp "  $question ([y]/n) " answer < /dev/tty
    [[ "${answer:-y}" =~ ^[Yy]$ ]]
}

# check prints one doctor line for LABEL from the exit status of CMD.
#   check [--warn] [--hint TEXT] LABEL CMD...
# It returns 1 only for a failure without --warn, so a check step can collect real problems with `check ... || status=1`.
check() {
    local warn_only=false hint=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --warn) warn_only=true ;;
            --hint)
                hint="$2"
                shift
                ;;
            *) break ;;
        esac
        shift
    done
    local label="$1"
    shift
    if "$@" > /dev/null 2>&1; then
        say_ok "$label"
        return 0
    fi
    if [ "$warn_only" = true ]; then
        say_warn "$label${hint:+ ($hint)}"
        return 0
    fi
    say_fail "$label${hint:+ ($hint)}"
    return 1
}
