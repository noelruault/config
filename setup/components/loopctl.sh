# shellcheck shell=bash
# `make build` also produces loop-runner, which is not linked: loopctl runs it from its own directory.
define_component loopctl all optional "loopctl, the loop supervisor"

LOOPCTL_DIR="$GO_SRC_NOELRUAULT/loopctl"

# link_loopctl_publisher points loopctl's publisher/ at a loopmonitor checkout. Without it loops still run; only publishing to the macOS widget is off.
link_loopctl_publisher() {
    if [ -d "$LOOPCTL_DIR/publisher" ] && [ ! -L "$LOOPCTL_DIR/publisher" ]; then
        return 0
    fi
    local publisher
    # macos-widgets is the old name of the loopmonitor repo.
    for publisher in "$GO_SRC_NOELRUAULT/loopmonitor/publisher" "$GO_SRC_NOELRUAULT/macos-widgets/publisher"; do
        if [ -d "$publisher" ]; then
            ln -sfn "$publisher" "$LOOPCTL_DIR/publisher"
            say_ok "loopctl: publisher -> $publisher"
            return 0
        fi
    done
    say_warn "loopctl: widget publishing is off; clone github.com/noelruault/loopmonitor and run: ln -s <loopmonitor>/publisher $LOOPCTL_DIR/publisher"
}

install_loopctl() {
    install_private_command "$1" loopctl noelruault/loopctl "make build" loopctl
    [ -x "$LOOPCTL_DIR/loopctl" ] || return 0
    link_loopctl_publisher
}

component_loopctl_install() { install_loopctl install; }
component_loopctl_update() { install_loopctl update; }

component_loopctl_check() {
    check --warn --hint "run: setup.sh init --only loopctl" "loopctl is linked into $LOCAL_BIN" test -x "$LOCAL_BIN/loopctl"
}
