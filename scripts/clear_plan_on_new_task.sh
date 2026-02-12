#!/bin/bash
# Called after EnterPlanMode - user is starting a NEW task
# Clears approval markers, creates planning marker, resets exploration counter

# Clear session marker
rm -f "/tmp/.claude_plan_approved_${PPID}"

# Clear active plan marker
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [[ -n "$PROJECT_ROOT" && -f "$PROJECT_ROOT/.claude_active_plan" ]]; then
    rm -f "$PROJECT_ROOT/.claude_active_plan"
fi

# Create planning marker (signals exploration tracking is active)
touch "/tmp/.claude_planning_${PPID}"

# Reset exploration counter and log
echo 0 > "/tmp/.claude_explore_count_${PPID}"
rm -f "/tmp/.claude_exploration_log_${PPID}"

echo "Previous plan cleared. Exploration tracking started. Read docs and code before writing a plan."
exit 0
