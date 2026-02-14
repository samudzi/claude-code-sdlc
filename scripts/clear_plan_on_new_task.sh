#!/bin/bash
# Called after EnterPlanMode - user is starting a NEW task
# Clears approval markers, creates planning marker, resets exploration counter

# Read hook stdin for session_id
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)".*/\1/')
SESSION_ID="${SESSION_ID:-$PPID}"

# Clear session marker
rm -f "/tmp/.claude_plan_approved_${SESSION_ID}"

# Clear active plan marker
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [[ -n "$PROJECT_ROOT" && -f "$PROJECT_ROOT/.claude_active_plan" ]]; then
    rm -f "$PROJECT_ROOT/.claude_active_plan"
fi

# Create planning marker (signals exploration tracking is active)
touch "/tmp/.claude_planning_${SESSION_ID}"

# Reset exploration counter and log
echo 0 > "/tmp/.claude_explore_count_${SESSION_ID}"
rm -f "/tmp/.claude_exploration_log_${SESSION_ID}"

echo "Previous plan cleared. Exploration tracking started. Read docs and code before writing a plan."
exit 0
