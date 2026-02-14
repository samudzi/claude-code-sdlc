#!/bin/bash
# UserPromptSubmit hook — clears approval on EVERY user message
# Approval is per-turn only: model gets one turn to implement after plan approval
source "$(dirname "$0")/common.sh"
init_hook

# Clear session-scoped approval only
state_remove approved
state_remove context_injected

exit 0
