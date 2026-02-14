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

# Clear persistent state
persist_remove approved
persist_remove objective
persist_remove scope
persist_remove criteria

# Enter planning mode
state_write planning "1"
state_write explore_count "0"

echo "Previous plan cleared. Exploration tracking started. Read docs and code before writing a plan."
exit 0
