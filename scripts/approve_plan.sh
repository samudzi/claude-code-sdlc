#!/bin/bash
# PostToolUse hook on ExitPlanMode — SOLE approval marker creator
# Only runs after user approves (ExitPlanMode succeeded)
source "$(dirname "$0")/common.sh"
init_hook

# ── Create approval marker ──
state_write approved "1"

# ── Extract objective, scope, criteria from validated plan ──
PLAN_FILE=$(state_read plan_file)

if [[ -n "$PLAN_FILE" && -f "$PLAN_FILE" ]]; then
    PLAN_CONTENT=$(cat "$PLAN_FILE" 2>/dev/null)

    # Extract Objective
    echo "$PLAN_CONTENT" \
        | sed -n '/^##[[:space:]]*[Oo]bjective/,/^##/p' \
        | tail -n +2 | grep -v '^## ' \
        | sed '/^[[:space:]]*$/d' \
        | head -3 \
        > "$(state_file objective)"

    # Extract Scope — file paths from "- path/file" lines
    echo "$PLAN_CONTENT" \
        | sed -n '/^##[[:space:]]*[Ss]cope/,/^##/p' \
        | tail -n +2 | grep -v '^## ' \
        | grep -E '^\s*-\s+' \
        | grep '/' \
        | sed 's/^[[:space:]]*-[[:space:]]*//' \
        | sed 's/[[:space:]]*$//' \
        | sed 's/`//g' \
        > "$(state_file scope)"

    # Extract Success Criteria
    echo "$PLAN_CONTENT" \
        | sed -n '/^##[[:space:]]*[Ss]uccess[[:space:]]*[Cc]riteria/,/^##/p' \
        | tail -n +2 | grep -v '^## ' \
        | sed '/^[[:space:]]*$/d' \
        | head -3 \
        > "$(state_file criteria)"
fi

# Clean up planning state
state_remove planning
state_remove explore_count
state_remove context_injected

echo "Plan approved. Edits permitted for this turn."
exit 0
