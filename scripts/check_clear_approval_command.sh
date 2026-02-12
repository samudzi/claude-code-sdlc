#!/bin/bash
# Hook for UserPromptSubmit — clears approval on EVERY user message
# Approval is per-turn only: model gets one turn to implement after plan approval

# Clear session marker
rm -f "/tmp/.claude_plan_approved_${PPID}"

# Clear active plan marker
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [[ -n "$PROJECT_ROOT" && -f "$PROJECT_ROOT/.claude_active_plan" ]]; then
    rm -f "$PROJECT_ROOT/.claude_active_plan"
fi

exit 0
