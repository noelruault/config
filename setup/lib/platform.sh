# shellcheck shell=bash
# The only place that asks which operating system this is.
# Components declare a platform instead of probing; a Linux port adds components and package lists, not branches inside existing ones.

detect_os() {
    case "$(uname -s)" in
        Darwin) echo darwin ;;
        Linux) echo linux ;;
        *) echo unknown ;;
    esac
}

# SETUP_OS can be preset so the tests can walk the plan another platform would get.
SETUP_OS="${SETUP_OS:-$(detect_os)}"

platform_matches() {
    [ "$1" = all ] || [ "$1" = "$SETUP_OS" ]
}
