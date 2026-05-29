#!/bin/bash

# Script for cleaning MacOS related trash (dot files and folders)
# from a removable disk and unmounting that disk.
# Script does sanity checks, should be safe, but use at your own risk!

# Newest version can always be found at https://gist.github.com/pawelszydlo/5eacd49d7e57bce71e96171e9fad1cd2


# Display a dialog box.
# $1 - title
# $2 - message
# $3 - icon (default "caution")
# $4 - buttons (default "OK")
# Prints the button that was pressed.
function osa_message {
    local answer=$(osascript -e "display dialog \"$2\" buttons ${4:-\"OK\"} \
    default button 1 with title \"$1\" with icon ${3:-caution}")
    echo ${answer#"button returned:"}
}

# Check if path was passed as an argument.
if [ $# -eq 0 ]; then
    # No? Get current Finder path (useful for running this from Finder toolbar).
    folder=$(osascript -e 'tell application "Finder" to POSIX path of (folder of front window as alias)')
else
	folder="$1"
fi

# Strip trailing slash.
folder=${folder%/}

# Check if disk can be unmounted.
if ! $(diskutil info $folder | \
    grep -q "\s\+Removable Media:\s\+Removable"); then
    osa_message "Error" "Device at $folder is not marked as removable." stop > /dev/null
    exit
fi

# Ask to proceed.
proceed=$(osa_message \
"Unmount $folder?" \
"Do you want to remove all Mac related hidden files and folders and eject disk?" \
"caution" \
"{\"Eject\", \"Cancel\"}")

if [ "$proceed" == "Eject" ]; then
    # Remove all meta data (._ files).
    dot_clean -m $folder
    # Remove trashes.
    rm -rf "$folder/.Trashes"
    # Remove spotlight data.
    rm -rf "$folder/.Spotlight-V100"
    # Remove other stuff.
    rm -rf "$folder/.fseventsd"

    # Eject the disk.
    if ! eject_output=$(diskutil eject $folder 2>&1); then
    	# Something went wrong when ejecting.
    	osa_message "Error" "$eject_output" stop > /dev/null
    fi
fi
