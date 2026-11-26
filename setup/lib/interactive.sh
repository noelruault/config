# shellcheck shell=bash
# The git/*.sh scripts ask their own questions on the terminal, so they only run when a person is there to answer.

# run_interactive_script asks QUESTION, then sources SCRIPT.
# The subshell keeps a script's `exit` from ending the whole setup run.
# Its stdin is the terminal because some of these scripts `read` from stdin, which is not a terminal when setup itself was started with input redirected.
run_interactive_script() {
    local question="$1" script="$2"
    if ! has_terminal; then
        say_warn "$(basename "$script") asks questions and there is no terminal, skipping"
        return 1
    fi
    if ! confirm "$question"; then
        say_info "left as it is"
        return 0
    fi
    # shellcheck disable=SC1090  # path is built at runtime
    (source "$script") < /dev/tty
}
