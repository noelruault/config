#!/bin/bash
### USEFUL COMMANDS
# [INFO] FINDS AND COPY SUBLIME TEXT FILES TO THIS FOLDER
rsync -r "$(find $HOME -type d -name "*Sublime*Text*" 2>&1 | grep -v "find")/Packages/User/"*sublime* .
# [INFO] COPY SUBLIME CUSTOM SETTINGS TO SUBLIME FOLDER
# - ln * "$(find $HOME -type d -name "*Sublime*Text*" 2>&1 | grep -v "find")/Packages/User/"
