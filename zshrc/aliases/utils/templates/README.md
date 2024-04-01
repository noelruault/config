# README

templates will be skipped when automatically discovering and loading aliases, thanks to the addition of `grep -v "/_"` on the command located on the aliases' init file.

    lsnoext "$SCRIPT_DIR/utils" | grep -v "/_"
