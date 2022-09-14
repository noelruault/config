read -p "Enter name: " NAME
read -p "Enter email: " EMAIL

git config --global core.excludesfile ~/.config/git/gitignore_global
git config --global include.path ~/.config/git/gitconfig_global

git config --global user.name "$NAME"
git config --global user.email "$EMAIL"

cat ~/.gitconfig
echo "\n🌍 Configured global .gitignore and .gitconfig files (~/.gitconfig)"
