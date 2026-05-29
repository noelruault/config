
    ## interactive login shell, or with --login
    /etc/profile
    ~/.bash_profile
    ~/.bash_login
    ~/.profile
    # exit builtin command: ~/.bash_logout

    ## interactive non-login shell
    ~/.bashrc

    man path_helper
    $ /usr/libexec/path_helper  # Check man docs for more info

    $ ls -aFGl / | grep private
        lrwxr-xr-x@   1 root  wheel     11 Oct  6  2018 etc@ -> private/etc
        drwxr-xr-x    6 root  wheel    192 Feb 24 11:57 private/
        lrwxr-xr-x@   1 root  wheel     11 Oct  6  2018 tmp@ -> private/tmp
        lrwxr-xr-x@   1 root  wheel     11 Oct  6  2018 var@ -> private/var
    # INFO: /etc/bashrc is not automatically read in under any circumstance.
    # The only way it gets included, is if its referenced in your ~/.bashrc file
    # [[Source: https://www.linuxquestions.org/questions/linux-general-1/etc-profile-v-s-etc-bashrc-273992/ ]]

    [[Source: https://www.gnu.org/software/bash/manual/bash.pdf]]
    ???: Why dotfiles and /etc/* files?? I mean, why two definitions of the same file?
  
