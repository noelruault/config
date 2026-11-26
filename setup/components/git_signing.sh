# shellcheck shell=bash
define_component git_signing all optional "SSH commit signing"

git_signing_is_configured() {
    [ "$(git config --global commit.gpgsign)" = true ] && [ -n "$(git config --global user.signingkey)" ]
}

component_git_signing_install() {
    if git_signing_is_configured; then
        say_ok "commit signing is already configured"
        return 0
    fi
    run_interactive_script "Configure SSH commit signing?" "$SETUP_ROOT/git/git-signing.sh"
}

component_git_signing_check() {
    check --warn --hint "run: setup.sh init --only git_signing" "commits are signed with an SSH key" git_signing_is_configured
}
