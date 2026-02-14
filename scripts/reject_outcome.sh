#!/bin/bash
# Called by /reject command — clears approval after user rejects implementation
# Works with both session and persistent state

PROJECT_HASH=$(pwd | shasum | cut -c1-12)
PERSIST_DIR="${CLAUDE_TEST_PERSIST_DIR:-${HOME}/.claude/state/${PROJECT_HASH}}"
HOOKS_DIR="${CLAUDE_TEST_HOOKS_DIR:-/tmp/.claude_hooks}"

# Clear persistent state
rm -f "${PERSIST_DIR}/approved" "${PERSIST_DIR}/objective" "${PERSIST_DIR}/scope" "${PERSIST_DIR}/criteria" "${PERSIST_DIR}/context_injected"

# Clear all active session states
for D in "${HOOKS_DIR}"/*/; do
    [ -d "$D" ] || continue
    rm -f "${D}/approved" "${D}/objective" "${D}/scope" "${D}/criteria" "${D}/context_injected"
done

echo "Implementation rejected. Plan approval cleared. Provide feedback for re-planning."
