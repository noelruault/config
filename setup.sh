#!/bin/bash
# Script to execute a first time set-up of zsh config files.

cat setup.sh

PLUGINS=~/.oh-my-zsh/custom
if [ -d "$PLUGINS" ]
then
    echo "Directory '$PLUGINS' already exists." && cd "$PLUGINS";
else
    echo "Creating directory '$PLUGINS'" && mkdir "$PLUGINS" && cd "$_"
fi

cd && git clone https://github.com/noelruault/config.git

# A symbolic link, also termed a soft link, is a special kind of file
# that points to another file, much like a shortcut in Windows or a Macintosh alias.
#  .config/ (the folder that will be sync with the repository)
#  .zshrc-config/ (the folder which would be changed by the user)

ln -sF $HOME/config $HOME/.config
ln -sF $HOME/config/zshrc-config $HOME/.zshrc-config
ln -sF $HOME/config/zshrc-config/zshrc $HOME/.zshrc
ln -sF $HOME/config/code-editors/vim/vimrc $HOME/.vimrc

### SET PROFILE ###
# Many system-wide settings including PATH are set in /etc/profile
# source /etc/profile # System-wide .profile for sh(1)

# .zshrc is not the right place to set $PATH or any other environment variable.
# Environment variables should be set in ~/.zprofile
ln -sF $HOME/config/zshrc-config/zprofile $HOME/.zprofile


brew install coreutils # gdate
brew install fzf # fzf
# Troubleshooting: https://spaceship-prompt.sh/troubleshooting/
git clone https://github.com/spaceship-prompt/spaceship-prompt.git "$ZSH_CUSTOM/themes/spaceship-prompt" --depth=1 && ln -s "$ZSH_CUSTOM/themes/spaceship-prompt/spaceship.zsh-theme" "$ZSH_CUSTOM/themes/spaceship.zsh-theme" # zsh theme: Spaceship
git clone https://github.com/zsh-users/zsh-syntax-highlighting ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting # zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions  # zsh-autosuggestionszsh-autosuggestions

mkdir ~/.config/zshrc-config/aliases/private/
touch ~/.config/zshrc-config/aliases/private/secrets && chmod +x ~/.config/zshrc-config/aliases/private/secrets

# Clean directories
cd && rm -rf "~/zsh-autosuggestions ~/zsh-syntax-highlighting"

# TODO install brew
# TODO install fonts
