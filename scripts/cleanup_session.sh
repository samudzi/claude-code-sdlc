#!/bin/bash
# SessionEnd hook — clean up session-scoped temp files
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)".*/\1/')
[[ -z "$SESSION_ID" ]] && exit 0
rm -f /tmp/.claude_plan_approved_"${SESSION_ID}" \
      /tmp/.claude_planning_"${SESSION_ID}" \
      /tmp/.claude_explore_count_"${SESSION_ID}" \
      /tmp/.claude_exploration_log_"${SESSION_ID}" \
      /tmp/.claude_objective_"${SESSION_ID}" \
      /tmp/.claude_scope_"${SESSION_ID}" \
      /tmp/.claude_success_criteria_"${SESSION_ID}"
exit 0
