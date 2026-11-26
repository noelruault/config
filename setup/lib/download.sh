# shellcheck shell=bash
# Remote install scripts. This is the only file allowed to fetch one.

# run_remote_installer downloads URL in full before running it with INTERPRETER, so a dropped connection can never execute half a script.
#   run_remote_installer URL INTERPRETER [ARGS...]
run_remote_installer() {
    local url="$1" interpreter="$2" script status
    shift 2
    script=$(mktemp "${TMPDIR:-/tmp}/setup-installer.XXXXXX") || return 1
    if ! curl -fsSL --retry 3 --connect-timeout 15 -o "$script" "$url"; then
        rm -f "$script"
        say_fail "could not download $url"
        return 1
    fi
    "$interpreter" "$script" "$@"
    status=$?
    rm -f "$script"
    return "$status"
}
