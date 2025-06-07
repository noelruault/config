#!/bin/bash
# Script to execute a first time set-up of zsh config files. This script mainly uses symbolic links to overwrite the default configuration.
# A symbolic link, also termed a soft link, is a special kind of file that points to another file, much like a shortcut in Windows or a Macintosh alias.

CURRENT_SCRIPT=$(dirname "$0")
CURRENT_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")

# Backup existing configuration
backup_config() {
    local config_dir="$1"
    if [ -d "$config_dir" ] && ! [ -L "$config_dir" ]; then
        local dest="$HOME/.backup-config-$(date +'%Y%m%d')"
        mv "$config_dir" "$dest"
        echo "Current configuration backed up at $dest"
    fi
}

# Install Homebrew
install_homebrew() {
    if ! command -v brew &> /dev/null; then
        echo "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        echo >> /Users/"$(whoami)"/.zprofile
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> /Users/"$(whoami)"/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        echo "Homebrew is already installed."
    fi
}

# Install a brew package if not installed
install_brew_package() {
    local package="$1"
    brew list "$package" &> /dev/null || brew install "$package"
}

# Set up latest bash via Homebrew
setup_bash() {
    install_brew_package bash
    local brew_bash_path=$(which -a bash | head -n 1)
    if ! grep -Fxq "$brew_bash_path" /etc/shells; then
        echo "$brew_bash_path" | sudo tee -a /etc/shells
        sudo chsh -s "$brew_bash_path"
    else
        echo "Latest Homebrew bash version already configured."
    fi
}

# Install Oh-My-Zsh
install_oh_my_zsh() {
    if [ ! -d ~/.oh-my-zsh ]; then
        echo "Installing Oh-My-Zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    else
        echo "Oh-My-Zsh is already installed."
    fi
}

# Install Zsh plugins
install_zsh_plugins() {
    local plugin_url="$1"
    local plugin_dir="$2"
    if [ ! -d "$plugin_dir" ]; then
        git clone "$plugin_url" "$plugin_dir"
    fi
}

# Install fonts (macOS only)
install_fonts() {
    if [[ $OSTYPE == 'darwin'* ]]; then
        echo "Installing fonts..."
        # Iterate over all subdirectories in fonts and copy them
        for font_dir in "$CURRENT_DIR/fonts"/*; do
            if [ -d "$font_dir" ]; then
                cp -r "$font_dir"/* ~/Library/Fonts || echo "Failed to copy fonts from $font_dir"
            fi
        done
    fi
}

# Overwrite config with symlinks
overwrite_config() {
    local src="$1"
    local dest="$2"
    if [ -e "$src" ]; then
        rm -f "$dest" && ln -sF "$src" "$dest"
        echo "Symlink created from $src to $dest"
    else
        echo "Source $src not found. Skipping."
    fi
}

# Prompt user for confirmation
prompt_user() {
    local prompt_message="$1"
    local default_answer="y"
    read -p "$prompt_message ([y]/n) " answer </dev/tty
    answer=${answer:-$default_answer}
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Main script execution starts here
backup_config "$HOME/.config"
overwrite_config "$HOME/config" "$HOME/.config"

install_homebrew
setup_bash
install_brew_package git
install_brew_package fzf
install_brew_package coreutils

install_oh_my_zsh

# Install Zsh plugins and themes
ZSH_CUSTOM=${ZSH_CUSTOM:-~/.oh-my-zsh/custom}
install_zsh_plugins "https://github.com/zsh-users/zsh-syntax-highlighting" "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
install_zsh_plugins "https://github.com/zsh-users/zsh-autosuggestions" "$ZSH_CUSTOM/plugins/zsh-autosuggestions"

SPACESHIP="$ZSH_CUSTOM/themes/spaceship-prompt"
if [ ! -d "$SPACESHIP" ]; then
    git clone https://github.com/spaceship-prompt/spaceship-prompt.git "$SPACESHIP" --depth=1
    ln -s "$SPACESHIP/spaceship.zsh-theme" "$ZSH_CUSTOM/themes/spaceship.zsh-theme"
fi

install_fonts

# Overwrite ZSH configuration
if prompt_user "Do you want to overwrite current zsh configuration?"; then
    overwrite_config "$HOME/config/zshrc/zshrc" "$HOME/.zshrc"
    overwrite_config "$HOME/config/zshrc/zprofile" "$HOME/.zprofile"
fi

# Overwrite Git configuration
if prompt_user "Do you want to overwrite current git configuration?"; then
    git_config_script="$CURRENT_DIR/git/git-config.sh"
    if [ -f "$git_config_script" ]; then
        source "$git_config_script" || echo "Error executing $git_config_script"
    else
        echo "$git_config_script not found, skipping."
    fi
fi

# Generate SSH keys if needed
if prompt_user "Do you want to generate SSH keys?"; then
    ssh_gen_script="$CURRENT_DIR/git/ssh-gen.sh"
    if [ -f "$ssh_gen_script" ]; then
        source "$ssh_gen_script" || echo "Error executing $ssh_gen_script"
    else
        echo "$ssh_gen_script not found, skipping."
    fi
fi

# TODO:
# https://iterm2colorschemes.com
