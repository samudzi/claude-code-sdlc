#!/bin/bash
# UserPromptSubmit hook — no-op
# Approval persists across all user messages.
# Cleared only by: /accept, /reject (commands), or EnterPlanMode (new plan cycle).
source "$(dirname "$0")/common.sh"
init_hook
exit 0
