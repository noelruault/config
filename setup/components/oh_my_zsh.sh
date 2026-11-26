# shellcheck shell=bash
define_component oh_my_zsh all optional "oh-my-zsh, its plugins and the spaceship theme"

# The installer puts oh-my-zsh in $ZSH when that is set, and refuses to run if that folder exists, so this looks in the same place.
OH_MY_ZSH_DIR="${ZSH:-$HOME/.oh-my-zsh}"
OH_MY_ZSH_CUSTOM="${ZSH_CUSTOM:-$OH_MY_ZSH_DIR/custom}"

# "git url|directory under the custom dir" for everything cloned beside oh-my-zsh.
OH_MY_ZSH_EXTRAS=(
    "https://github.com/zsh-users/zsh-syntax-highlighting|plugins/zsh-syntax-highlighting"
    "https://github.com/zsh-users/zsh-autosuggestions|plugins/zsh-autosuggestions"
    "https://github.com/spaceship-prompt/spaceship-prompt.git|themes/spaceship-prompt"
)

component_oh_my_zsh_install() {
    if [ -d "$OH_MY_ZSH_DIR" ]; then
        say_ok "oh-my-zsh is already installed"
    else
        # RUNZSH=no: the installer otherwise ends by starting an interactive zsh, which would hold the rest of setup until that shell exits.
        RUNZSH=no run_remote_installer https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh sh || return 1
        say_ok "oh-my-zsh installed in $OH_MY_ZSH_DIR"
    fi
    local extra directory
    for extra in "${OH_MY_ZSH_EXTRAS[@]}"; do
        directory="$OH_MY_ZSH_CUSTOM/${extra#*|}"
        if [ -d "$directory" ]; then
            say_ok "${extra#*|} is already cloned"
            continue
        fi
        git clone --depth=1 "${extra%%|*}" "$directory" || return 1
        say_ok "${extra#*|} cloned"
    done
    ln -sfn "$OH_MY_ZSH_CUSTOM/themes/spaceship-prompt/spaceship.zsh-theme" "$OH_MY_ZSH_CUSTOM/themes/spaceship.zsh-theme"
}

component_oh_my_zsh_update() {
    component_oh_my_zsh_install || return 1
    local extra status=0
    git -C "$OH_MY_ZSH_DIR" pull --ff-only > /dev/null || status=1
    for extra in "${OH_MY_ZSH_EXTRAS[@]}"; do
        git -C "$OH_MY_ZSH_CUSTOM/${extra#*|}" pull --ff-only > /dev/null || status=1
    done
    return "$status"
}

component_oh_my_zsh_check() {
    local extra status=0
    check --hint "run: setup.sh init --only oh_my_zsh" "oh-my-zsh is installed" test -d "$OH_MY_ZSH_DIR" || status=1
    for extra in "${OH_MY_ZSH_EXTRAS[@]}"; do
        check --hint "run: setup.sh init --only oh_my_zsh" "${extra#*|} is cloned" test -d "$OH_MY_ZSH_CUSTOM/${extra#*|}" || status=1
    done
    return "$status"
}
