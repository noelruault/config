#!/bin/bash
# Script to execute a first time set-up of zsh config files. This script mainly uses symbolic links to overwrite the default configuration.
# A symbolic link, also termed a soft link, is a special kind of file that points to another file, much like a shortcut in Windows or a Macintosh alias.

### (deactivated) SET PROFILE ###
# Many system-wide settings including PATH are set in /etc/profile
# source /etc/profile # System-wide .profile for sh(1)

CURRENT_SCRIPT=$(dirname "$0")
CURRENT_DIR=$(dirname $(readlink -f "${BASH_SOURCE:-$0}"))

rm -f $HOME/.config && ln -sF ~/config $HOME/.config

## git
brew list git &> /dev/null || brew install git

## bash - Upgrading bash used by zsh when using 'bash' command: https://itnext.io/upgrading-bash-on-macos-7138bd1066ba
brew list bash &> /dev/null || brew install bash
BREW_BASH_PATH=$(which -a bash | head -n 1) # get the first line of output from "which -a bash"
if grep -Fxq "/etc/shells" "$BREW_BASH_PATH"; then
    echo "latest homebrew bash version already configured"
else
    echo "$BREW_BASH_PATH" | sudo tee -a /etc/shells;
    sudo chsh -s "$BREW_BASH_PATH"
fi

## brew - https://brew.sh/#install
if ! command -v brew &> /dev/null; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

## fzf - https://github.com/junegunn/fzf#using-homebrew-or-linuxbrew
brew list fzf &> /dev/null || brew install fzf && "$(brew --prefix)"/opt/fzf/install
brew list coreutils &> /dev/null || brew install coreutils

## oh-my-zsh - https://ohmyz.sh/#install
if ! [ -d ~/.oh-my-zsh ]; then
    sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# zsh-syntax-highlighting
SYNTAX_HIGHLIGHTING=${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
if ! [ -d ${SYNTAX_HIGHLIGHTING} ]; then
   git clone https://github.com/zsh-users/zsh-syntax-highlighting ${SYNTAX_HIGHLIGHTING}
fi

# zsh-autosuggestions
SUGGESTIONS=${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
if ! [ -d ${SUGGESTIONS} ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions ${SUGGESTIONS}
fi

# https://spaceship-prompt.sh/getting-started/#installing
# - troubleshooting spaceship: https://spaceship-prompt.sh/troubleshooting/
SPACESHIP=${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/themes/spaceship-prompt
if ! [ -d ${SPACESHIP} ]; then
    git clone https://github.com/spaceship-prompt/spaceship-prompt.git $SPACESHIP --depth=1
    ln -s $SPACESHIP/spaceship.zsh-theme ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/themes/spaceship.zsh-theme
fi

# Install fonts
if [[ $OSTYPE == 'darwin'* ]]; then
    cp -r $CURRENT_DIR/fonts/*/* ~/Library/Fonts
fi

# Overwrite current ZSH aliases and profile (if desired)
read -p "Do you want to overwrite current zsh configuration? ([y]/n) " answer </dev/tty
case $answer in
    [Yy]* ) break ;;
    [Nn]* ) exit ;;
    * ) echo "Please answer yes or no."; exit 1 ;;
esac

rm -f $HOME/.zshrc && ln -sF $HOME/config/zshrc/zshrc $HOME/.zshrc
rm -f $HOME/.zprofile && ln -sF $HOME/config/zshrc/zprofile $HOME/.zprofile
ln -sF $HOME/config/code-editors/vim/vimrc $HOME/.vimrc
#!/bin/bash
# Script to execute a first time set-up of zsh config files. This script mainly uses symbolic links to overwrite the default configuration.
# A symbolic link, also termed a soft link, is a special kind of file that points to another file, much like a shortcut in Windows or a Macintosh alias.

### (deactivated) SET PROFILE ###
# Many system-wide settings including PATH are set in /etc/profile
# source /etc/profile # System-wide .profile for sh(1)

CURRENT_SCRIPT=$(dirname "$0")
CURRENT_DIR=$(dirname $(readlink -f "${BASH_SOURCE:-$0}"))

rm -f $HOME/.config && ln -sF ~/config $HOME/.config

## git
brew list git &> /dev/null || brew install git

## bash - Upgrading bash used by zsh when using 'bash' command: https://itnext.io/upgrading-bash-on-macos-7138bd1066ba
brew list bash &> /dev/null || brew install bash
BREW_BASH_PATH=$(which -a bash | head -n 1) # get the first line of output from "which -a bash"
if grep -Fxq "/etc/shells" "$BREW_BASH_PATH"; then
    echo "latest homebrew bash version already configured"
else
    echo "$BREW_BASH_PATH" | sudo tee -a /etc/shells;
    sudo chsh -s "$BREW_BASH_PATH"
fi

## brew - https://brew.sh/#install
if ! command -v brew &> /dev/null; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

## fzf - https://github.com/junegunn/fzf#using-homebrew-or-linuxbrew
brew list fzf &> /dev/null || brew install fzf && "$(brew --prefix)"/opt/fzf/install
brew list coreutils &> /dev/null || brew install coreutils

## oh-my-zsh - https://ohmyz.sh/#install
if ! [ -d ~/.oh-my-zsh ]; then
    sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# zsh-syntax-highlighting
SYNTAX_HIGHLIGHTING=${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
if ! [ -d ${SYNTAX_HIGHLIGHTING} ]; then
   git clone https://github.com/zsh-users/zsh-syntax-highlighting ${SYNTAX_HIGHLIGHTING}
fi

# zsh-autosuggestions
SUGGESTIONS=${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
if ! [ -d ${SUGGESTIONS} ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions ${SUGGESTIONS}
fi

# https://spaceship-prompt.sh/getting-started/#installing
# - troubleshooting spaceship: https://spaceship-prompt.sh/troubleshooting/
SPACESHIP=${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/themes/spaceship-prompt
if ! [ -d ${SPACESHIP} ]; then
    git clone https://github.com/spaceship-prompt/spaceship-prompt.git $SPACESHIP --depth=1
    ln -s $SPACESHIP/spaceship.zsh-theme ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/themes/spaceship.zsh-theme
fi

# Install fonts
if [[ $OSTYPE == 'darwin'* ]]; then
    cp -r $CURRENT_DIR/fonts/*/* ~/Library/Fonts
fi

# Overwrite current ZSH aliases and profile (if desired)
read -p "Do you want to overwrite current zsh configuration? ([y]/n) " answer </dev/tty
case $answer in
    [Yy]* ) break ;;
    [Nn]* ) exit ;;
    * ) echo "Please answer yes or no."; exit 1 ;;
esac

rm -f $HOME/.zshrc && ln -sF $HOME/config/zshrc/zshrc $HOME/.zshrc
rm -f $HOME/.zprofile && ln -sF $HOME/config/zshrc/zprofile $HOME/.zprofile
ln -sF $HOME/config/code-editors/vim/vimrc $HOME/.vimrc
