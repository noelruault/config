#!/bin/bash

if [[ -z "$ZSH_CUSTOM" ]]; then
    echo "ZSH_CUSTOM path not configured" && exit 1
fi

## git
brew install git

## brew - https://brew.sh/#install
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

## fzf - https://github.com/junegunn/fzf#using-homebrew-or-linuxbrew
brew install fzf
"$(brew --prefix)"/opt/fzf/install

## oh-my-zsh - https://ohmyz.sh/#install
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

### spaceship - https://github.com/denysdovhan/spaceship-prompt#oh-my-zsh
git clone https://github.com/denysdovhan/spaceship-prompt.git "$ZSH_CUSTOM/themes/spaceship-prompt" --depth=1

### zsh-autosuggestions - https://github.com/zsh-users/zsh-autosuggestions/blob/master/INSTALL.md#oh-my-zsh
git clone https://github.com/zsh-users/zsh-autosuggestions "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}"/plugins/zsh-autosuggestions

## gdate and other bash stuff
brew install coreutils

## MySQL
# brew install mysql mysql-client

## Upgrading bash used by zsh when using 'bash' command: https://itnext.io/upgrading-bash-on-macos-7138bd1066ba
brew install bash
BREW_BASH_PATH=$(which -a bash | head -n 1) # get the first line of output from "which -a bash"
if grep -Fxq "/etc/shells" "$BREW_BASH_PATH"; then
    echo "latest homebrew bash version already configured"
else
    echo "$BREW_BASH_PATH" | sudo tee -a /etc/shells;
    sudo chsh -s "$BREW_BASH_PATH"
fi
