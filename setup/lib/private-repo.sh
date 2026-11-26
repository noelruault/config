# shellcheck shell=bash
# Commands built from private repos under github.com/noelruault.
# A machine without access to them is normal, so every failure here warns and returns 0.

GO_SRC_NOELRUAULT="$HOME/go/src/github.com/noelruault"

# clone_private_repo clones OWNER/NAME into DIR unless it is already there.
# It probes access first (gh when authenticated, then SSH with a short timeout) and returns non-zero without side effects when this machine has no rights to the repo.
clone_private_repo() {
    local repo="$1" dir="$2"
    [ -d "$dir/.git" ] && return 0
    mkdir -p "$(dirname "$dir")"
    if command -v gh > /dev/null 2>&1 && gh repo view "$repo" > /dev/null 2>&1; then
        gh repo clone "$repo" "$dir" 2> /dev/null && return 0
    fi
    GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=5" \
        git clone "git@github.com:$repo.git" "$dir" 2> /dev/null
}

#   install_private_command install|update NAME OWNER/REPO BUILD_CMD LINK_BIN...
# Binaries stay inside the clone and are symlinked, never copied: loopctl finds its loops/ directory beside its own binary.
install_private_command() {
    local mode="$1" name="$2" repo="$3" build_cmd="$4"
    shift 4
    local dir="$GO_SRC_NOELRUAULT/${repo#*/}" bin needs_build=false
    if ! clone_private_repo "$repo" "$dir"; then
        say_warn "$name: no access to github.com/$repo (needs 'gh auth login' or an SSH key with rights), skipping"
        return 0
    fi
    if ! command -v go > /dev/null 2>&1; then
        say_warn "$name: Go toolchain not found, skipping the build"
        return 0
    fi
    if [ "$mode" = update ]; then
        git -C "$dir" pull --ff-only > /dev/null 2>&1 || say_warn "$name: could not pull $dir, building the current checkout"
        needs_build=true
    fi
    for bin in "$@"; do
        [ -x "$dir/$bin" ] || needs_build=true
    done
    if [ "$needs_build" = true ] && ! (cd "$dir" && eval "$build_cmd"); then
        say_warn "$name: build failed ('$build_cmd' in $dir), skipping"
        return 0
    fi
    mkdir -p "$LOCAL_BIN"
    for bin in "$@"; do
        if [ -x "$dir/$bin" ]; then
            ln -sf "$dir/$bin" "$LOCAL_BIN/$(basename "$bin")"
            say_ok "$name: $LOCAL_BIN/$(basename "$bin") -> $dir/$bin"
        else
            say_warn "$name: expected binary $dir/$bin is missing after the build"
        fi
    done
}
