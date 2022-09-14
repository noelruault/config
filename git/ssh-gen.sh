read -p "Enter email: " EMAIL
SSH_FILENAME="id_ed25519-$(date +'%Y%m%d')"
echo "ℹ️ Email: $EMAIL Key: $SSH_FILENAME"

# -t = type, -C = comment, -f = output file path, -N = passphrase
ssh-keygen  -t ed25519 -C $EMAIL -f ~/.ssh/$SSH_FILENAME -N ""
echo "🌅 The ssh key has been generated."

eval "$(ssh-agent -s)"
ssh-add --apple-use-keychain ~/.ssh/$SSH_FILENAME
echo "🔐 The ssh key has been added to the apple keychain."

pbcopy < ~/.ssh/$SSH_FILENAME.pub
echo "📃 The ssh key has been copied to clipboard."

echo """
Configure the SSH keys to interact with repository providers
GitHub: https://github.com/settings/keys
GitLab: https://gitlab.com/-/profile/keys
"""
