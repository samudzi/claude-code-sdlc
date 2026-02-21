#!/bin/bash
# Clear plan approval — forces Claude back into plan mode
# Usage: ~/.claude/scripts/clear_approval.sh
# No args needed — uses current working directory

PROJECT_HASH=$(pwd | shasum | cut -c1-12)
PERSIST_DIR="${CLAUDE_TEST_PERSIST_DIR:-${HOME}/.claude/state/${PROJECT_HASH}}"

# Clear persistent state
rm -f "${PERSIST_DIR}/approved" "${PERSIST_DIR}/objective" "${PERSIST_DIR}/scope" "${PERSIST_DIR}/criteria" "${PERSIST_DIR}/context_injected" "${PERSIST_DIR}/planning" "${PERSIST_DIR}/explore_count" "${PERSIST_DIR}/exploration_log"

# Clear all active session states
HOOKS_DIR="${CLAUDE_TEST_HOOKS_DIR:-/tmp/.claude_hooks}"
if [[ -d "$HOOKS_DIR" ]]; then
    for D in "$HOOKS_DIR"/*/; do
        [[ -d "$D" ]] || continue
        rm -f "${D}/approved" "${D}/objective" "${D}/scope" "${D}/criteria" "${D}/context_injected" "${D}/planning" "${D}/explore_count" "${D}/exploration_log"
    done
fi

echo "Approval cleared for project (hash: ${PROJECT_HASH}). Claude must now plan before editing."
