#!/bin/bash
# UserPromptSubmit hook — approval persists until user explicitly accepts/rejects
# Approval is only cleared by:
#   1. User typing /accept or /reject (this hook)
#   2. EnterPlanMode (clear_plan_on_new_task.sh)
source "$(dirname "$0")/common.sh"
init_hook

# Extract the user's prompt text
USER_PROMPT=$(echo "$HOOK_INPUT" | jq -r '.prompt // empty' 2>/dev/null)

# Check for explicit acceptance/rejection commands
case "$USER_PROMPT" in
    /accept|/accept\ *)
        state_remove approved
        state_remove objective
        state_remove scope
        state_remove criteria
        state_remove context_injected
        echo "Work accepted. Plan approval cleared."
        exit 0
        ;;
    /reject|/reject\ *)
        state_remove approved
        state_remove objective
        state_remove scope
        state_remove criteria
        state_remove context_injected
        echo "Work rejected. Plan approval cleared. Use EnterPlanMode to start a new plan."
        exit 0
        ;;
esac

# All other user messages: approval persists
exit 0
