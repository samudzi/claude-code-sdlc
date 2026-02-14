#!/bin/bash
# UserPromptSubmit hook — clears approval unless implementation has started
# Once the model makes its first edit (context_injected exists), approval persists.
# A new plan cycle (EnterPlanMode) resets everything.
source "$(dirname "$0")/common.sh"
init_hook

# If implementation has started (first edit made), preserve approval
if state_exists context_injected; then
    exit 0
fi

# No edits started yet — clear approval
state_remove approved

exit 0
