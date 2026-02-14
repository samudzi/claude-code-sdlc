#!/bin/bash
# Emergency approval restore — run manually when approval was lost
# Usage: ~/.claude/scripts/restore_approval.sh [session_id]
#   No args: lists active sessions
#   With session_id: creates approval for that session

HOOKS_DIR="/tmp/.claude_hooks"

if [[ -z "$1" ]]; then
    # List active sessions
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

    # Auto-select if only one session
    if [[ ${#SESSIONS[@]} -eq 1 ]]; then
        echo ""
        echo "Only one session found. Restoring approval..."
        mkdir -p "${HOOKS_DIR}/${SESSIONS[0]}"
        echo "1" > "${HOOKS_DIR}/${SESSIONS[0]}/approved"
        # No scope file = scope enforcement skipped for restored sessions
        echo "Approval restored for session ${SESSIONS[0]}."
    else
        echo ""
        echo "Multiple sessions found. Run with session_id argument:"
        echo "  ~/.claude/scripts/restore_approval.sh <session_id>"
    fi
    exit 0
fi

# Restore specific session
SESSION_ID="$1"
mkdir -p "${HOOKS_DIR}/${SESSION_ID}"
echo "1" > "${HOOKS_DIR}/${SESSION_ID}/approved"
# No scope file = scope enforcement skipped for restored sessions
echo "Approval restored for session $SESSION_ID."
echo "Approval will expire on the next user message."
