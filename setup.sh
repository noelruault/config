#!/bin/bash
# Script to execute a first time set-up of zsh config files. This script mainly uses symbolic links to overwrite the default configuration.
# A symbolic link, also termed a soft link, is a special kind of file that points to another file, much like a shortcut in Windows or a Macintosh alias.

CURRENT_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")

# Backup existing configuration
backup_config() {
    local config_dir="$1"
    if [ -d "$config_dir" ] && ! [ -L "$config_dir" ]; then
        local dest
        dest="$HOME/.backup-config-$(date +'%Y%m%d')"
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
        # shellcheck disable=SC2016  # literal $(...) is intended in the written line
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
    local brew_bash_path
    brew_bash_path=$(which -a bash | head -n 1)
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

# Install fonts (macOS only).
# Fonts are commercially licensed, so they live in a private repo instead of
# being committed here. Cloned on demand into .fonts-private/ (gitignored).
# Requires git auth (SSH key) to the private repo; skips cleanly without it.
FONTS_REPO="git@github.com:noelruault/fonts.git"
install_fonts() {
    if [[ $OSTYPE == 'darwin'* ]]; then
        local fonts_dir="$CURRENT_DIR/.fonts-private"
        echo "Installing fonts..."
        if [ ! -d "$fonts_dir/.git" ]; then
            git clone --depth=1 "$FONTS_REPO" "$fonts_dir" 2>/dev/null || {
                echo "Fonts: no git access to $FONTS_REPO, skipping."
                return
            }
        else
            git -C "$fonts_dir" pull --ff-only 2>/dev/null || true
        fi
        # Only macOS-installable formats; skip web assets (woff/woff2/eot/css).
        find "$fonts_dir" -type f \
            \( -iname '*.ttf' -o -iname '*.otf' -o -iname '*.ttc' -o -iname '*.dfont' \) \
            -exec cp {} ~/Library/Fonts/ \; \
            || echo "Failed to copy fonts from $fonts_dir"
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
    read -rp "$prompt_message ([y]/n) " answer </dev/tty
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
install_brew_package shfmt
install_brew_package shellcheck
# neovim runs the config at nvim/ (active via the ~/.config -> ~/config symlink).
# Plugins (lazy.nvim) bootstrap themselves on first `nvim` launch.
install_brew_package neovim

# install_brew_package docker
# install_brew_package colima
# install_brew_package docker-compose
# install_brew_package docker-credential-helper
# install_brew_package kubectl

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

# Overwrite ZSH configuration
if prompt_user "Do you want to overwrite current zsh configuration?"; then
    overwrite_config "$HOME/config/zshrc/zshrc" "$HOME/.zshrc"
    overwrite_config "$HOME/config/zshrc/zprofile" "$HOME/.zprofile"
fi

# Overwrite Git configuration
if prompt_user "Do you want to overwrite current git configuration?"; then
    git_config_script="$CURRENT_DIR/git/git-config.sh"
    if [ -f "$git_config_script" ]; then
        # shellcheck disable=SC1090  # runtime path, not resolvable statically
        source "$git_config_script" || echo "Error executing $git_config_script"
    else
        echo "$git_config_script not found, skipping."
    fi
fi

# Generate SSH keys if needed
if prompt_user "Do you want to generate SSH keys?"; then
    ssh_gen_script="$CURRENT_DIR/git/ssh-gen.sh"
    if [ -f "$ssh_gen_script" ]; then
        # shellcheck disable=SC1090  # runtime path, not resolvable statically
        source "$ssh_gen_script" || echo "Error executing $ssh_gen_script"
    else
        echo "$ssh_gen_script not found, skipping."
    fi
fi

# Configure SSH commit signing
if prompt_user "Do you want to configure SSH commit signing?"; then
    git_signing_script="$CURRENT_DIR/git/git-signing.sh"
    if [ -f "$git_signing_script" ]; then
        # shellcheck disable=SC1090  # runtime path, not resolvable statically
        source "$git_signing_script" || echo "Error executing $git_signing_script"
    else
        echo "$git_signing_script not found, skipping."
    fi
fi

# Fonts last: the private fonts repo is cloned over SSH, so this must run after
# SSH key generation / signing above, otherwise a fresh machine has no auth yet.
install_fonts

# TODO:
# https://iterm2colorschemes.com
