# shellcheck shell=bash
define_component shell_rc all optional "link ~/.zshrc and ~/.zprofile to this repo"

shell_rc_is_linked() {
    [ "$HOME/.zshrc" -ef "$SETUP_ROOT/zshrc/zshrc" ] && [ "$HOME/.zprofile" -ef "$SETUP_ROOT/zshrc/zprofile" ]
}

component_shell_rc_install() {
    if shell_rc_is_linked; then
        say_ok "zsh configuration already links to this repo"
        return 0
    fi
    if ! confirm "Overwrite the current zsh configuration?"; then
        say_info "left as it is"
        return 0
    fi
    ln -sfn "$SETUP_ROOT/zshrc/zshrc" "$HOME/.zshrc" || return 1
    ln -sfn "$SETUP_ROOT/zshrc/zprofile" "$HOME/.zprofile" || return 1
    say_ok "$HOME/.zshrc and $HOME/.zprofile link to $SETUP_ROOT/zshrc"
}

component_shell_rc_check() {
    check --hint "run: setup.sh init --only shell_rc" "$HOME/.zshrc and $HOME/.zprofile link to this repo" shell_rc_is_linked
}
