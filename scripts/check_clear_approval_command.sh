#!/bin/bash
# Hook for UserPromptSubmit — clears approval on EVERY user message
# Approval is per-turn only: model gets one turn to implement after plan approval

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

exit 0
