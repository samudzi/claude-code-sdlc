#!/bin/bash
# Clear plan approval — forces Claude back into plan mode
# Usage: ~/.claude/scripts/clear_approval.sh [session_id]
#   No args: lists active sessions and clears if only one
#   With session_id: clears approval for that session

HOOKS_DIR="/tmp/.claude_hooks"

if [[ -z "$1" ]]; then
    if [[ ! -d "$HOOKS_DIR" ]] || [[ -z "$(ls -A "$HOOKS_DIR" 2>/dev/null)" ]]; then
        echo "No active sessions found in $HOOKS_DIR"
        exit 1
    fi

    SESSIONS=()
    for D in "$HOOKS_DIR"/*/; do
        [[ -d "$D" ]] || continue
        SID=$(basename "$D")
        STATUS="no approval"
        [[ -f "$D/approved" ]] && STATUS="approved"
        [[ -f "$D/planning" ]] && STATUS="planning"
        echo "  $SID  ($STATUS)"
        SESSIONS+=("$SID")
    done

    if [[ ${#SESSIONS[@]} -eq 1 ]]; then
        echo ""
        echo "Only one session found. Clearing approval..."
        rm -f "${HOOKS_DIR}/${SESSIONS[0]}/approved"
        rm -f "${HOOKS_DIR}/${SESSIONS[0]}/context_injected"
        echo "Approval cleared for session ${SESSIONS[0]}."
    else
        echo ""
        echo "Multiple sessions found. Run with session_id argument:"
        echo "  ~/.claude/scripts/clear_approval.sh <session_id>"
    fi
    exit 0
fi

SESSION_ID="$1"
rm -f "${HOOKS_DIR}/${SESSION_ID}/approved"
rm -f "${HOOKS_DIR}/${SESSION_ID}/context_injected"
echo "Approval cleared for session $SESSION_ID. Claude must now plan before editing."
