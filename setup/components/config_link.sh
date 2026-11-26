# shellcheck shell=bash
# Everything else is read through ~/.config, so this link comes first.
define_component config_link all required "link ~/.config to this repo"

component_config_link_install() {
    local link="$HOME/.config"
    # -ef alone, without requiring a symlink: a repo cloned straight into ~/.config is already in place, and moving it to a backup would move the repo itself.
    if [ "$link" -ef "$SETUP_ROOT" ]; then
        say_ok "$link already points at $SETUP_ROOT"
        return 0
    fi
    if [ -d "$link" ] && [ ! -L "$link" ]; then
        local backup
        backup="$HOME/.backup-config-$(date +%Y%m%d-%H%M%S)"
        mv "$link" "$backup" || return 1
        say_info "existing $link moved to $backup"
    fi
    ln -sfn "$SETUP_ROOT" "$link" || return 1
    say_ok "$link -> $SETUP_ROOT"
}

component_config_link_check() {
    check --hint "run: setup.sh init --only config_link" "$HOME/.config points at this repo" test "$HOME/.config" -ef "$SETUP_ROOT"
}
