# CONFIGURATION

## Git config

```git
# This is Git's per-user configuration file. (~/.gitconfig)

[user]
name = Noël Ruault
email = person@company.xyz

[core]
excludesfile = ~/.config/git/gitignore_global

[include]
path = ~/.config/git/gitconfig_global
```

## SSH config

```
Host github.com
    HostName github.com
    User personal-email@gmail.com
    IdentityFile ~/.ssh/id_ed25519.pub
    PreferredAuthentications publickey
    IdentitiesOnly yes
```
