# shellcheck shell=bash
# Stage 0 on macOS, so this file must stay valid bash 3.2: macOS ships no newer bash, and the one setup runs under comes from Homebrew.
# A file named *-darwin.sh is macOS-only by convention and may call macOS tools.

# load_brew_into_path puts brew on PATH for this run. A login shell gets it from zshrc/zprofile; a fresh machine running setup has not read that yet.
load_brew_into_path() {
    local brew
    for brew in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        if [ -x "$brew" ]; then
            eval "$("$brew" shellenv)"
            return 0
        fi
    done
    return 1
}

# modern_bash_path prints the path of a Homebrew bash that is version 5 or newer and fails when there is none.
modern_bash_path() {
    local candidate
    for candidate in /opt/homebrew/bin/bash /usr/local/bin/bash; do
        # shellcheck disable=SC2016  # the candidate bash must expand this, not the bash running setup
        if [ -x "$candidate" ] && "$candidate" -c '[ "${BASH_VERSINFO[0]}" -ge 5 ]'; then
            echo "$candidate"
            return 0
        fi
    done
    return 1
}

# install_modern_bash is the one place a package is installed outside the Brewfile: `brew bundle` runs in a component, and components only load once this bash exists.
install_modern_bash() {
    if ! load_brew_into_path; then
        say_header "homebrew (bash 5 comes from it)"
        run_remote_installer https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh /bin/bash || return 1
        load_brew_into_path || return 1
    fi
    say_header "bash 5"
    brew install bash
}
