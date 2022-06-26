# zshrc-config setup

**If you want to backup zshrc:**

    mv $HOME/.zshrc-config $HOME/zshrc-config-backup

**In order to create a symlink to the repo zshrc:**

    ln -s $HOME/.zshrc-config/ $HOME/.config/

**Remove dotfile:**

    mv $HOME/.zshrc-config $HOME/.backup-zshrc-config

**Link rc's:**

    ln -s $HOME/.zshrc-config/config/zshrc $HOME/.zshrc
    ln -s $HOME/.zshrc-config/config/psqlrc $HOME/.psqlrc
