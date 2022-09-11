# vim

mkdir -p ~/.vim && cd $_ && git init

## Update all plugins

git submodule foreach git pull origin master
    # git add .
    # git commit -m "update submodules"
