# vim

mkdir -p ~/.vim && cd $_ && git init

## Update all plugins

git submodule foreach git pull origin master
    # git add .
    # git commit -m "update submodules"

## Plugins

git clone https://github.com/fatih/vim-go.git ~/.vim/pack/plugins/start/vim-go
:GoInstallBinaries

git clone https://github.com/preservim/nerdtree.git ~/.vim/pack/vendor/start/nerdtree
vim -u NONE -c "helptags ~/.vim/pack/vendor/start/nerdtree/doc" -c q
