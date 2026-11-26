# shellcheck shell=bash
# Packages are data: add one to the Brewfile at the repo root, not to a component.
define_component packages darwin required "Brewfile packages"

component_packages_install() {
    brew bundle install --file="$SETUP_ROOT/Brewfile" --no-upgrade || return 1
    say_ok "every entry in $SETUP_ROOT/Brewfile is installed"
}

component_packages_update() {
    brew bundle install --file="$SETUP_ROOT/Brewfile" --upgrade || return 1
    say_ok "every entry in $SETUP_ROOT/Brewfile is installed and upgraded"
}

component_packages_check() {
    # Without HOMEBREW_NO_AUTO_UPDATE `brew bundle` may run `brew update` first, and doctor must not change anything.
    check --hint "run: setup.sh init --only packages" "every Brewfile package is installed" env HOMEBREW_NO_AUTO_UPDATE=1 brew bundle check --file="$SETUP_ROOT/Brewfile" --no-upgrade
}
