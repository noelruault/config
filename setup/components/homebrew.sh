# shellcheck shell=bash
# On a fresh machine stage 0 (setup/lib/bootstrap-darwin.sh) has already installed Homebrew to get bash 5; this component keeps it updated and checked.
define_component homebrew darwin required "Homebrew"

component_homebrew_install() {
    if load_brew_into_path; then
        say_ok "Homebrew is already installed"
        return 0
    fi
    run_remote_installer https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh /bin/bash || return 1
    load_brew_into_path || return 1
    say_ok "Homebrew installed at $(brew --prefix)"
}

component_homebrew_update() {
    load_brew_into_path || return 1
    brew update
}

component_homebrew_check() {
    check --hint "run: setup.sh init --only homebrew" "brew is installed" load_brew_into_path
}
