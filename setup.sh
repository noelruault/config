#!/bin/bash
# Script to execute a first time set-up of zsh config files. This script mainly uses symbolic links to overwrite the default configuration.
# A symbolic link, also termed a soft link, is a special kind of file that points to another file, much like a shortcut in Windows or a Macintosh alias.

CURRENT_DIR=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")

# Backup existing configuration
backup_config() {
    local config_dir="$1"
    if [ -d "$config_dir" ] && ! [ -L "$config_dir" ]; then
        local dest
        dest="$HOME/.backup-config-$(date +'%Y%m%d')"
        mv "$config_dir" "$dest"
        echo "Current configuration backed up at $dest"
    fi
}

# Install Homebrew
install_homebrew() {
    if ! command -v brew &> /dev/null; then
        echo "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        echo >> /Users/"$(whoami)"/.zprofile
        # shellcheck disable=SC2016  # literal $(...) is intended in the written line
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> /Users/"$(whoami)"/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        echo "Homebrew is already installed."
    fi
}

# Install a brew package if not installed
install_brew_package() {
    local package="$1"
    brew list "$package" &> /dev/null || brew install "$package"
}

# Set up latest bash via Homebrew
setup_bash() {
    install_brew_package bash
    local brew_bash_path
    brew_bash_path=$(which -a bash | head -n 1)
    if ! grep -Fxq "$brew_bash_path" /etc/shells; then
        echo "$brew_bash_path" | sudo tee -a /etc/shells
        sudo chsh -s "$brew_bash_path"
    else
        echo "Latest Homebrew bash version already configured."
    fi
}

# Install Oh-My-Zsh
install_oh_my_zsh() {
    if [ ! -d ~/.oh-my-zsh ]; then
        echo "Installing Oh-My-Zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    else
        echo "Oh-My-Zsh is already installed."
    fi
}

# Install Zsh plugins
install_zsh_plugins() {
    local plugin_url="$1"
    local plugin_dir="$2"
    if [ ! -d "$plugin_dir" ]; then
        git clone "$plugin_url" "$plugin_dir"
    fi
}

# Install fonts (macOS only).
# Fonts are commercially licensed, so they live in a private repo instead of
# being committed here. Cloned on demand into .fonts/ (gitignored).
# Requires git auth (SSH key) to the private repo; skips cleanly without it.
FONTS_REPO="git@github.com:noelruault/fonts.git"
install_fonts() {
    if [[ $OSTYPE == 'darwin'* ]]; then
        local fonts_dir="$CURRENT_DIR/.fonts"
        echo "Installing fonts..."
        if [ ! -d "$fonts_dir/.git" ]; then
            git clone --depth=1 "$FONTS_REPO" "$fonts_dir" 2>/dev/null || {
                echo "Fonts: no git access to $FONTS_REPO, skipping."
                return
            }
        else
            git -C "$fonts_dir" pull --ff-only 2>/dev/null || true
        fi
        # Only macOS-installable formats; skip web assets (woff/woff2/eot/css).
        find "$fonts_dir" -type f \
            \( -iname '*.ttf' -o -iname '*.otf' -o -iname '*.ttc' -o -iname '*.dfont' \) \
            -exec cp {} ~/Library/Fonts/ \; \
            || echo "Failed to copy fonts from $fonts_dir"
    fi
}

# Install aispeak, the offline voice assistant (private repo until public).
# Cloned on demand into the Go src tree; skips cleanly without git access, so
# anyone running this setup without rights to the repo just gets nothing.
# The shell loader (zshrc/aliases/utils/aispeak) sources it only if present.
AISPEAK_REPO="git@github.com:noelruault/aispeak.git"
AISPEAK_DIR="$HOME/go/src/github.com/noelruault/aispeak"
install_aispeak() {
    if [ -d "$AISPEAK_DIR/.git" ]; then
        git -C "$AISPEAK_DIR" pull --ff-only 2>/dev/null || true
    else
        mkdir -p "$(dirname "$AISPEAK_DIR")"
        git clone "$AISPEAK_REPO" "$AISPEAK_DIR" 2>/dev/null || {
            # No access (private repo / no key) — silently skip.
            return
        }
    fi
    # Pre-build the speech binary if we can; otherwise it builds on first run.
    if command -v swiftc >/dev/null 2>&1 && [ -x "$AISPEAK_DIR/speech-stt/build.sh" ]; then
        "$AISPEAK_DIR/speech-stt/build.sh" >/dev/null 2>&1 || true
    fi
    # Populate doc corpora once (English manual download + local Spanish import),
    # so `aispeak --topic vim-en|vim-es` works out of the box. Best-effort.
    local docs_root="${XDG_DATA_HOME:-$HOME/.local/share}/aispeak/docs"
    if [ ! -d "$docs_root/vim-en" ] && [ -x "$AISPEAK_DIR/scripts/fetch-docs.sh" ]; then
        "$AISPEAK_DIR/scripts/fetch-docs.sh" all >/dev/null 2>&1 || true
    fi
}

# loopctl + router: private Go CLIs (github.com/noelruault/{loopctl,router}).
# Cloned into the Go src tree and built in place — loopctl's binary directory
# is its home (it finds loops/ beside itself), so binaries are never copied,
# only symlinked into ~/.local/bin (put on PATH by zshrc/zshrc).
# Everything is best-effort: no repo access, no gh/git auth, or no Go
# toolchain prints a warning and setup carries on; it never fails the run.
LOCAL_BIN="$HOME/.local/bin"
GO_SRC_NOELRUAULT="$HOME/go/src/github.com/noelruault"

setup_warn() {
    echo "WARNING: $*" >&2
}

# Clone a private repo (owner/name) into a directory if not already there.
# Probes access softly first — gh (if authenticated), then git over SSH with a
# short timeout — and returns non-zero without side effects when this machine
# has no rights to the repo.
clone_private_repo() {
    local repo="$1" dir="$2"
    [ -d "$dir/.git" ] && return 0
    mkdir -p "$(dirname "$dir")"
    if command -v gh >/dev/null 2>&1 && gh repo view "$repo" >/dev/null 2>&1; then
        gh repo clone "$repo" "$dir" 2>/dev/null && return 0
    fi
    GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=5" \
        git clone "git@github.com:$repo.git" "$dir" 2>/dev/null
}

# install_command — generic installer for a command built from a private repo.
#
#   install_command <name> <owner/repo> <build-cmd> <link-bin> [link-bin...]
#
# Clones github.com/<owner/repo> into $GO_SRC_NOELRUAULT/<repo>, runs
# <build-cmd> inside it when any <link-bin> is missing (binaries live IN the
# repo — some tools, like loopctl, resolve their home from the binary's own
# directory, so we never copy them out), then symlinks each <link-bin> into
# ~/.local/bin. Every failure path warns and returns 0: setup never fails
# because one optional tool is unavailable. Adding a tool from now on is one
# wrapper line (plus any tool-specific post-hook).
install_command() {
    local name="$1" repo="$2" build_cmd="$3"
    shift 3
    local dir="$GO_SRC_NOELRUAULT/${repo#*/}" bin missing=0
    if ! clone_private_repo "$repo" "$dir"; then
        setup_warn "$name: no access to github.com/$repo (private repo; needs 'gh auth login' or an SSH key with rights) — skipping, '$name' command won't be available."
        return 0
    fi
    # All current tools are Go; extend this probe if a non-Go tool ever joins.
    if ! command -v go >/dev/null 2>&1; then
        setup_warn "$name: Go toolchain not found — skipping build. Install Go and re-run setup.sh."
        return 0
    fi
    for bin in "$@"; do [ -x "$dir/$bin" ] || missing=1; done
    if [ "$missing" = 1 ]; then
        (cd "$dir" && eval "$build_cmd") || {
            setup_warn "$name: build failed ('$build_cmd' in $dir) — skipping, '$name' command won't be available. If the clone is stale, try: git -C $dir pull && re-run setup.sh"
            return 0
        }
    fi
    mkdir -p "$LOCAL_BIN"
    for bin in "$@"; do
        if [ -x "$dir/$bin" ]; then
            ln -sf "$dir/$bin" "$LOCAL_BIN/$(basename "$bin")"
            echo "$name: $LOCAL_BIN/$(basename "$bin") -> $dir/$bin"
        else
            setup_warn "$name: expected binary $dir/$bin missing after build — '$(basename "$bin")' not installed."
        fi
    done
}

# loopctl: the loop supervisor. `make build` also produces loop-runner beside
# loops/ (not linked — loopctl execs it from its own directory). The publisher
# post-hook wires the optional macOS-widget publishing.
install_loopctl() {
    install_command loopctl noelruault/loopctl "make build" loopctl
    local dir="$GO_SRC_NOELRUAULT/loopctl"
    [ -x "$dir/loopctl" ] || return 0 # install_command already warned
    # Widget publishing (optional): loopctl expects a publisher/ symlink at its
    # repo root pointing into a loopmonitor checkout (legacy name macos-widgets).
    # Without it loops still run; only the macOS widget publishing is disabled.
    if [ -d "$dir/publisher" ] && [ ! -L "$dir/publisher" ]; then
        return 0 # real directory already in place; leave it alone
    fi
    local mon
    for mon in "$GO_SRC_NOELRUAULT/loopmonitor/publisher" "$GO_SRC_NOELRUAULT/macos-widgets/publisher"; do
        if [ -d "$mon" ]; then
            ln -sfn "$mon" "$dir/publisher"
            echo "loopctl: publisher -> $mon"
            return 0
        fi
    done
    setup_warn "loopctl: widget publishing disabled — clone github.com/noelruault/loopmonitor and run: ln -s <loopmonitor>/publisher $dir/publisher"
}

# router: foreground checklist/plan executor (routes each item to the cheapest
# capable model; see the repo's README).
install_router() {
    install_command router noelruault/router "GOTOOLCHAIN=auto go build -o router ./cmd/router" router
}

# Overwrite config with symlinks
overwrite_config() {
    local src="$1"
    local dest="$2"
    if [ -e "$src" ]; then
        rm -f "$dest" && ln -sF "$src" "$dest"
        echo "Symlink created from $src to $dest"
    else
        echo "Source $src not found. Skipping."
    fi
}

# Prompt user for confirmation
prompt_user() {
    local prompt_message="$1"
    local default_answer="y"
    read -rp "$prompt_message ([y]/n) " answer </dev/tty
    answer=${answer:-$default_answer}
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Main script execution starts here
backup_config "$HOME/.config"
overwrite_config "$HOME/config" "$HOME/.config"

install_homebrew
setup_bash
# Core CLI tools, in one list so a fresh machine gets everything in a single pass.
# bash is handled by setup_bash above (it also configures the login shell).
# neovim config lives in nvim/ (active via ~/.config -> ~/config); lazy.nvim
# bootstraps its plugins on first `nvim` launch.
BREW_PACKAGES=(
    git        # version control + private-repo clones
    gh         # GitHub CLI: auth, private clones, PR/workflow ops
    jq         # JSON processor: required by the .claude guards (claude-*-ro-guard)
    python     # python3: bin/resolve-secrets in the .claude dotfiles repo
    awscli     # aws CLI: the AWS read-only guard + day-to-day AWS
    coreutils  # GNU coreutils (readlink -f used by this script, etc.)
    fzf
    shfmt
    shellcheck
    neovim
)
for pkg in "${BREW_PACKAGES[@]}"; do
    install_brew_package "$pkg"
done

# Optional / heavier tooling (uncomment as needed):
# install_brew_package docker
# install_brew_package colima
# install_brew_package docker-compose
# install_brew_package docker-credential-helper
# install_brew_package kubectl

install_oh_my_zsh

# Install Zsh plugins and themes
ZSH_CUSTOM=${ZSH_CUSTOM:-~/.oh-my-zsh/custom}
install_zsh_plugins "https://github.com/zsh-users/zsh-syntax-highlighting" "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
install_zsh_plugins "https://github.com/zsh-users/zsh-autosuggestions" "$ZSH_CUSTOM/plugins/zsh-autosuggestions"

SPACESHIP="$ZSH_CUSTOM/themes/spaceship-prompt"
if [ ! -d "$SPACESHIP" ]; then
    git clone https://github.com/spaceship-prompt/spaceship-prompt.git "$SPACESHIP" --depth=1
    ln -s "$SPACESHIP/spaceship.zsh-theme" "$ZSH_CUSTOM/themes/spaceship.zsh-theme"
fi

# Overwrite ZSH configuration
if prompt_user "Do you want to overwrite current zsh configuration?"; then
    overwrite_config "$HOME/config/zshrc/zshrc" "$HOME/.zshrc"
    overwrite_config "$HOME/config/zshrc/zprofile" "$HOME/.zprofile"
fi

# Overwrite Git configuration
if prompt_user "Do you want to overwrite current git configuration?"; then
    git_config_script="$CURRENT_DIR/git/git-config.sh"
    if [ -f "$git_config_script" ]; then
        # shellcheck disable=SC1090  # runtime path, not resolvable statically
        source "$git_config_script" || echo "Error executing $git_config_script"
    else
        echo "$git_config_script not found, skipping."
    fi
fi

# Generate SSH keys if needed
if prompt_user "Do you want to generate SSH keys?"; then
    ssh_gen_script="$CURRENT_DIR/git/ssh-gen.sh"
    if [ -f "$ssh_gen_script" ]; then
        # shellcheck disable=SC1090  # runtime path, not resolvable statically
        source "$ssh_gen_script" || echo "Error executing $ssh_gen_script"
    else
        echo "$ssh_gen_script not found, skipping."
    fi
fi

# Configure SSH commit signing
if prompt_user "Do you want to configure SSH commit signing?"; then
    git_signing_script="$CURRENT_DIR/git/git-signing.sh"
    if [ -f "$git_signing_script" ]; then
        # shellcheck disable=SC1090  # runtime path, not resolvable statically
        source "$git_signing_script" || echo "Error executing $git_signing_script"
    else
        echo "$git_signing_script not found, skipping."
    fi
fi

# Fonts last: the private fonts repo is cloned over SSH, so this must run after
# SSH key generation / signing above, otherwise a fresh machine has no auth yet.
install_fonts

# aispeak: also a private SSH clone, so likewise after SSH setup. No-op without
# repo access; loaded by zshrc/aliases/utils/aispeak only when the clone exists.
install_aispeak

# loopctl + router: private clones too, so after gh/SSH auth is in place.
# Warn-and-continue without repo access, Go, or a build; never fail setup.
install_loopctl
install_router

# TODO:
# https://iterm2colorschemes.com
