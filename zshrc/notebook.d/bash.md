
  ANSI escape codes:

  Black        0;30     Dark Gray     1;30
  Red          0;31     Light Red     1;31
  Green        0;32     Light Green   1;32
  Brown/Orange 0;33     Yellow        1;33
  Blue         0;34     Light Blue    1;34
  Purple       0;35     Light Purple  1;35
  Cyan         0;36     Light Cyan    1;36
  Light Gray   0;37     White         1;37
  

How to get latest bash version on MACOSX
- https://stackoverflow.com/a/11704224
- https://itnext.io/upgrading-bash-on-macos-7138bd1066ba

From here on, the shell you're in is Bash 3.2, but 'bash' command points to Bash 5.X
To change your login shell, add /usr/local/bin/bash to /etc/shells and change the default shell with
   chsh -s /usr/local/bin/bash
   sudo chsh -s /usr/local/bin/bash

Note that '#!/bin/bash' shebang explicitly refers to the old version of Bash.
Point to '#!/usr/bin/env bash'. It's portable and will use the first Bash in your '$PATH'

BASH GUIDE: Square brackets
- https://stackoverflow.com/a/47576482

  
