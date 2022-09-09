# config setup

**If you want to backup zshrc:**

    mv $HOME/config $HOME/config-backup

**In order to create a symlink to the repo zshrc:**

    ln -s $HOME/config/ $HOME/.config/

**Remove dotfile:**

    mv $HOME/config $HOME/.backup-config

**Link rc's:**

    ln -s $HOME/config/zshrc/zshrc $HOME/.zshrc
    ln -s $HOME/config/zshrc/zprofile $HOME/.zprofile
    ln -s $HOME/config/zshrc/psqlrc $HOME/.psqlrc
