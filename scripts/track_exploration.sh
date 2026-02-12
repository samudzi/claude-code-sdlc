#!/bin/bash
# PostToolUse hook on Read|Glob|Grep — tracks exploration depth during planning
# Fast exit if not in plan mode (zero friction outside planning)

PLANNING_MARKER="/tmp/.claude_planning_${PPID}"
COUNTER_FILE="/tmp/.claude_explore_count_${PPID}"

# Not in plan mode? Do nothing.
[[ ! -f "$PLANNING_MARKER" ]] && exit 0

# Increment exploration counter
COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)
echo $(( COUNT + 1 )) > "$COUNTER_FILE"

exit 0
