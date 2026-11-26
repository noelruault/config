# shellcheck shell=bash
define_component ssh_key all optional "an ed25519 SSH key"

# ssh_key_exists ignores id_ed25519_signing.pub: git-signing.sh creates that one, and it does not authenticate to anything.
ssh_key_exists() {
    local key
    for key in "$HOME"/.ssh/id_ed25519*.pub; do
        [ -f "$key" ] && [[ $key != *_signing.pub ]] && return 0
    done
    return 1
}

component_ssh_key_install() {
    if ssh_key_exists; then
        say_ok "an ed25519 key already exists"
        return 0
    fi
    run_interactive_script "Generate an SSH key?" "$SETUP_ROOT/git/ssh-gen.sh"
}

component_ssh_key_check() {
    check --warn --hint "run: setup.sh init --only ssh_key" "an ed25519 public key exists in $HOME/.ssh" ssh_key_exists
}
