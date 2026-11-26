# shellcheck shell=bash
# The fonts are commercially licensed, so they live in a private repo and are cloned into the gitignored .fonts/ instead of being committed to this public one.
define_component fonts darwin optional "fonts from the private fonts repo"

FONTS_REPO="noelruault/fonts"
FONTS_DIR="$SETUP_ROOT/.fonts"

component_fonts_install() {
    if [ -d "$FONTS_DIR/.git" ]; then
        git -C "$FONTS_DIR" pull --ff-only > /dev/null 2>&1 || say_warn "could not pull $FONTS_DIR, installing what is there"
    elif ! clone_private_repo "$FONTS_REPO" "$FONTS_DIR"; then
        say_warn "no access to github.com/$FONTS_REPO, skipping"
        return 0
    fi
    local installed="$HOME/Library/Fonts" font status=0 copied=0
    mkdir -p "$installed" || return 1
    # Web formats (woff, woff2, eot) are left out: macOS cannot install them.
    # A loop, not `find -exec cp {} \;`: find exits 0 even when every cp failed.
    while IFS= read -r -d '' font; do
        if cp "$font" "$installed/"; then copied=$((copied + 1)); else status=1; fi
    done < <(find "$FONTS_DIR" -type f \( -iname '*.ttf' -o -iname '*.otf' -o -iname '*.ttc' -o -iname '*.dfont' \) -print0)
    say_ok "$copied font files copied into $installed"
    return "$status"
}

component_fonts_check() {
    check --warn --hint "run: setup.sh init --only fonts" "the fonts repo is cloned" test -d "$FONTS_DIR/.git"
}
