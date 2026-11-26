# shellcheck shell=bash

# macOS ships bash 3.2; stage 0 installs a current one and this lists it as a valid login shell.
define_component login_shell darwin optional "Homebrew bash listed in /etc/shells"

brew_bash_is_listed() {
    local brew_bash
    brew_bash=$(modern_bash_path) || return 1
    grep -Fxq "$brew_bash" /etc/shells
}

component_login_shell_install() {
    local brew_bash
    if ! brew_bash=$(modern_bash_path); then
        say_warn "Homebrew bash is not installed (run: setup.sh init --only packages)"
        return 1
    fi
    if brew_bash_is_listed; then
        say_ok "$brew_bash is already in /etc/shells"
        return 0
    fi
    if ! has_terminal; then
        say_warn "adding to /etc/shells needs sudo and there is no terminal to ask for the password"
        return 1
    fi
    echo "$brew_bash" | sudo tee -a /etc/shells > /dev/null || return 1
    say_ok "$brew_bash added to /etc/shells"
}

component_login_shell_check() {
    check --warn --hint "run: setup.sh init --only login_shell" "Homebrew bash is in /etc/shells" brew_bash_is_listed
}
