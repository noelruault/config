
  GENERATE:	ssh-keygen -t rsa -b 4096 # -m PEM
  COPY:		pbcopy < ~/.ssh/id_rsa.pub
  SSH CONFIG:
    - (optional) git config --global --add url.git@github.com:.insteadOf https://github.com/
    - ssh-add -K ~/.ssh/[your-private-key]
    - In .ssh/config file, add the following lines:
        Host *
        UseKeychain yes
        AddKeysToAgent yes
        IdentityFile ~/.ssh/id_rsa

    Reference: https://apple.stackexchange.com/a/250572
    Referende: https://help.github.com/en/github/authenticating-to-github/adding-a-new-ssh-key-to-your-github-account
    *(Golang issues with ssh keys) Reference: https://github.com/golang/go/issues/18692
  
