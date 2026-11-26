# shellcheck shell=bash
define_component router all optional "router, the checklist and plan executor"

install_router() {
    install_private_command "$1" router noelruault/router "GOTOOLCHAIN=auto go build -o router ./cmd/router" router
}

component_router_install() { install_router install; }
component_router_update() { install_router update; }

component_router_check() {
    check --warn --hint "run: setup.sh init --only router" "router is linked into $LOCAL_BIN" test -x "$LOCAL_BIN/router"
}
