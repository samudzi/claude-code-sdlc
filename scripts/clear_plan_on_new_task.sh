#!/bin/bash
# PostToolUse hook on EnterPlanMode — clears approval, starts planning
source "$(dirname "$0")/common.sh"
init_hook

# Clear session state
state_remove approved
state_remove objective
state_remove scope
state_remove criteria
state_remove exploration_log
state_remove context_injected
state_remove plan_file

# Clear persistent state — only if approval is stale (> 30 min)
# This prevents the destructive loop where EnterPlanMode (called as recovery
# from a BLOCKED edit) wipes a recent approval before it can be hydrated
if persist_exists approved; then
    APPROVAL_AGE=$(( $(date +%s) - $(file_mtime "$(persist_file approved)") ))
    if [[ "$APPROVAL_AGE" -gt 1800 ]]; then
        persist_remove approved
        persist_remove objective
        persist_remove scope
        persist_remove criteria
    fi
else
    persist_remove objective
    persist_remove scope
    persist_remove criteria
fi

# Enter planning mode (session + persistent)
state_write planning "1"
state_write explore_count "0"
persist_write planning "1"
persist_write explore_count "0"
persist_remove exploration_log

echo "Previous plan cleared. Exploration tracking started. Read docs and code before writing a plan."
exit 0
