#!/bin/bash
# Script to update plugin dependencies of zsh.

cat update.sh

PLUGINS=~/config/zshrc-config/plugins
[ -d "$PLUGINS" ] && echo "Directory '$PLUGINS' already exists. Proceeding to update..." && cd $PLUGINS || echo "Creating directory '$PLUGINS'" && mkdir $PLUGINS

brew upgrade coreutils # gdate
brew upgrade fzf # fzf
git clone https://github.com/spaceship-prompt/spaceship-prompt.git "$ZSH_CUSTOM/themes/spaceship-prompt" --depth=1  && ln -s "$ZSH_CUSTOM/themes/spaceship-prompt/spaceship.zsh-theme" "$ZSH_CUSTOM/themes/spaceship.zsh-theme" # zsh theme: Spaceship
git clone https://github.com/zsh-users/zsh-syntax-highlighting ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting # zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions  # zsh-autosuggestionszsh-autosuggestions
