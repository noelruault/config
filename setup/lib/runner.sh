# shellcheck shell=bash
# Walks the selected components for one phase and reports what happened.

# run_phase runs PHASE (install, update or check) for every selected component that matches this platform.
# A component without an update step is updated by running its install step again, which is why install must be safe to repeat.
# Returns 1 when a required component failed.
run_phase() {
    local phase="$1" name step requirement
    local succeeded=() warned=() failed=() silent=()

    for name in "${SELECTED_COMPONENTS[@]}"; do
        platform_matches "${COMPONENT_PLATFORM[$name]}" || continue
        requirement="${COMPONENT_REQUIREMENT[$name]}"
        step="component_${name}_${phase}"
        if [ "$phase" = update ] && ! declare -F "$step" > /dev/null; then
            step="component_${name}_install"
        fi

        if [ "$SETUP_DRY_RUN" = true ] && [ "$phase" != check ]; then
            say_info "would $phase $name ($requirement): ${COMPONENT_DESCRIPTION[$name]}"
            continue
        fi

        say_header "$name"
        if "$step"; then
            succeeded+=("$name")
            if [ "$SETUP_LINES_SAID" -eq 0 ]; then
                silent+=("$name")
                say_ok "${COMPONENT_DESCRIPTION[$name]}"
            fi
        elif [ "$requirement" = required ]; then
            failed+=("$name")
            if [ "$SETUP_LINES_SAID" -eq 0 ]; then
                silent+=("$name")
                say_fail "${COMPONENT_DESCRIPTION[$name]}: failed"
            fi
            if [ "$phase" != check ]; then
                say_fail "$name is required and failed, stopping here"
                break
            fi
        else
            warned+=("$name")
            if [ "$SETUP_LINES_SAID" -eq 0 ]; then
                silent+=("$name")
                say_warn "${COMPONENT_DESCRIPTION[$name]}: not done"
            fi
        fi
    done

    if [ "$SETUP_DRY_RUN" = true ] && [ "$phase" != check ]; then
        return 0
    fi

    say_header summary
    say_info "ok ${#succeeded[@]} · warnings ${#warned[@]} · failed ${#failed[@]}"
    if [ ${#warned[@]} -gt 0 ]; then
        say_warn "optional, with problems: ${warned[*]}"
    fi
    if [ ${#failed[@]} -gt 0 ]; then
        say_fail "required, failed: ${failed[*]}"
        say_info "once fixed, run: setup.sh init --only $(join_with_commas "${failed[@]}")"
        return 1
    fi
    # A person gets the closing line the runner wrote for a silent step. The tests and CI set this so the same silence is a failure there, on every path they run.
    if [ "${SETUP_STRICT_REPORT:-}" = 1 ] && [ ${#silent[@]} -gt 0 ]; then
        say_fail "printed nothing about what they did (GUIDELINES.md, \"no empty section\"): ${silent[*]}"
        return 1
    fi
}

join_with_commas() {
    local IFS=,
    echo "$*"
}
