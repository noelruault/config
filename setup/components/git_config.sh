# shellcheck shell=bash
define_component git_config all optional "git remotes rewritten to SSH"

git_config_has_ssh_rewrite() {
    git config --global --get-regexp '^url\..*\.insteadof$'
}

component_git_config_install() {
    if git_config_has_ssh_rewrite > /dev/null 2>&1; then
        say_ok "git already rewrites a remote to SSH"
        return 0
    fi
    run_interactive_script "Configure git remotes?" "$SETUP_ROOT/git/git-config.sh"
}

component_git_config_check() {
    check --warn --hint "run: setup.sh init --only git_config" "git rewrites a remote to SSH" git_config_has_ssh_rewrite
}
