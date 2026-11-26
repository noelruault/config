# shellcheck shell=bash
# Linked, not copied, so editing a script in bin/ takes effect at once.
define_component bin_links all optional "bin/ scripts linked into ~/.local/bin"

# bin_scripts prints every file in bin/ that is a command, one per line. README.md documents the directory and is not one.
bin_scripts() {
    local script
    for script in "$SETUP_ROOT"/bin/*; do
        [ -f "$script" ] || continue
        [ "${script##*.}" = md ] && continue
        echo "$script"
    done
}

component_bin_links_install() {
    local script linked=()
    mkdir -p "$LOCAL_BIN"
    while IFS= read -r script; do
        [ -n "$script" ] || continue
        chmod +x "$script"
        ln -sfn "$script" "$LOCAL_BIN/$(basename "$script")" || return 1
        linked+=("$(basename "$script")")
    done <<< "$(bin_scripts)"
    say_ok "in $LOCAL_BIN: ${linked[*]}"
}

component_bin_links_check() {
    local script status=0
    while IFS= read -r script; do
        [ -n "$script" ] || continue
        check --hint "run: setup.sh init --only bin_links" "$(basename "$script") is linked into $LOCAL_BIN" test "$LOCAL_BIN/$(basename "$script")" -ef "$script" || status=1
    done <<< "$(bin_scripts)"
    return "$status"
}
