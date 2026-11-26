# shellcheck shell=bash
# Plain text opens in Zed and shell scripts follow whatever plain text opens in (bin/default-editor), instead of the terminal that claims .sh.
define_component default_editor darwin optional "default editor for text and shell scripts"

DEFAULT_EDITOR_LABEL=com.noelruault.default-editor
DEFAULT_EDITOR_PLIST="$HOME/Library/LaunchAgents/$DEFAULT_EDITOR_LABEL.plist"

component_default_editor_install() {
    if [ ! -x "$LOCAL_BIN/default-editor" ]; then
        say_warn "$LOCAL_BIN/default-editor is missing (run: setup.sh init --only bin_links)"
        return 1
    fi
    if [ -d /Applications/Zed.app ]; then
        if "$LOCAL_BIN/default-editor" Zed; then
            say_ok "plain text and shell scripts open in Zed"
        else
            say_warn "could not make Zed the default editor"
        fi
    elif "$LOCAL_BIN/default-editor"; then
        say_ok "shell scripts open in the app that opens plain text (Zed is not installed)"
    else
        say_warn "could not apply the default editor"
    fi
    mkdir -p "$(dirname "$DEFAULT_EDITOR_PLIST")"
    # The agent watches LaunchServices' handler plist, so a later Finder "Change All" on a .txt carries shell scripts with it.
    cat > "$DEFAULT_EDITOR_PLIST" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>$DEFAULT_EDITOR_LABEL</string>
    <key>ProgramArguments</key><array><string>$LOCAL_BIN/default-editor</string></array>
    <key>WatchPaths</key><array><string>$HOME/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist</string></array>
    <key>RunAtLoad</key><true/>
    <key>StandardErrorPath</key><string>$HOME/Library/Logs/default-editor.log</string>
</dict>
</plist>
PLIST
    launchctl bootout "gui/$(id -u)/$DEFAULT_EDITOR_LABEL" 2> /dev/null
    if ! launchctl bootstrap "gui/$(id -u)" "$DEFAULT_EDITOR_PLIST"; then
        say_warn "LaunchAgent not loaded; shell scripts will not follow later default-editor changes"
        return 1
    fi
    say_ok "LaunchAgent $DEFAULT_EDITOR_LABEL loaded"
}

component_default_editor_check() {
    check --warn --hint "run: setup.sh init --only default_editor" "the default-editor LaunchAgent is loaded" launchctl print "gui/$(id -u)/$DEFAULT_EDITOR_LABEL"
}
