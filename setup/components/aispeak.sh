# shellcheck shell=bash
# The shell loader (zshrc/aliases/utils/aispeak) sources aispeak only when this clone exists.
define_component aispeak all optional "aispeak, the offline voice assistant"

AISPEAK_DIR="$GO_SRC_NOELRUAULT/aispeak"

component_aispeak_install() {
    if [ -d "$AISPEAK_DIR/.git" ]; then
        if git -C "$AISPEAK_DIR" pull --ff-only > /dev/null 2>&1; then
            say_ok "pulled $AISPEAK_DIR"
        else
            say_warn "could not pull $AISPEAK_DIR, using the current checkout"
        fi
    elif ! clone_private_repo noelruault/aispeak "$AISPEAK_DIR"; then
        say_warn "no access to github.com/noelruault/aispeak, skipping"
        return 0
    else
        say_ok "cloned into $AISPEAK_DIR"
    fi
    # Both steps below are best-effort: aispeak builds its speech binary and fetches its docs by itself on first use when they are missing.
    if command -v swiftc > /dev/null 2>&1 && [ -x "$AISPEAK_DIR/speech-stt/build.sh" ]; then
        "$AISPEAK_DIR/speech-stt/build.sh" > /dev/null 2>&1 || say_warn "speech binary not prebuilt, it builds on first run"
    fi
    local docs_root="${XDG_DATA_HOME:-$HOME/.local/share}/aispeak/docs"
    if [ ! -d "$docs_root/vim-en" ] && [ -x "$AISPEAK_DIR/scripts/fetch-docs.sh" ]; then
        "$AISPEAK_DIR/scripts/fetch-docs.sh" all > /dev/null 2>&1 || say_warn "doc corpora not fetched, 'aispeak --topic' has nothing to read yet"
    fi
}

component_aispeak_check() {
    check --warn --hint "run: setup.sh init --only aispeak" "aispeak is cloned" test -d "$AISPEAK_DIR/.git"
}
