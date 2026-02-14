#!/bin/bash
# Emergency approval restore — creates persistent project approval
# Usage: ~/.claude/scripts/restore_approval.sh
# No args needed — uses current working directory to find project state

PROJECT_HASH=$(pwd | shasum | cut -c1-12)
PERSIST_DIR="${CLAUDE_TEST_PERSIST_DIR:-${HOME}/.claude/state/${PROJECT_HASH}}"
mkdir -p "$PERSIST_DIR"

echo "1" > "${PERSIST_DIR}/approved"

# Also restore into any active session dirs
HOOKS_DIR="${CLAUDE_TEST_HOOKS_DIR:-/tmp/.claude_hooks}"
if [[ -d "$HOOKS_DIR" ]]; then
    for D in "$HOOKS_DIR"/*/; do
        [[ -d "$D" ]] || continue
        echo "1" > "${D}/approved"
        # Copy scope/objective/criteria from persistent if they exist
        for f in scope objective criteria; do
            [[ -f "${PERSIST_DIR}/$f" ]] && cp "${PERSIST_DIR}/$f" "${D}/$f"
        done
    done
fi

echo "Approval restored for project (hash: ${PROJECT_HASH})."
echo "Will persist across sessions until /accept, /reject, or new plan cycle."
