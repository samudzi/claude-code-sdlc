#!/bin/bash
# PostToolUse hook on ExitPlanMode — SOLE approval marker creator
# Writes to both session state and persistent project state
source "$(dirname "$0")/common.sh"
init_hook

# ── Create approval markers (session + persistent) ──
state_write approved "1"
persist_write approved "1"

# ── Extract objective, scope, criteria from validated plan ──
PLAN_FILE=$(state_read plan_file)

if [[ -n "$PLAN_FILE" && -f "$PLAN_FILE" ]]; then
    PLAN_CONTENT=$(cat "$PLAN_FILE" 2>/dev/null)

    # Extract Objective
    OBJ=$(echo "$PLAN_CONTENT" \
        | sed -n '/^##[[:space:]]*[Oo]bjective/,/^##/p' \
        | tail -n +2 | grep -v '^## ' \
        | sed '/^[[:space:]]*$/d' \
        | head -3)
    echo "$OBJ" > "$(state_file objective)"
    echo "$OBJ" > "$(persist_file objective)"

    # Extract Scope
    SCOPE=$(echo "$PLAN_CONTENT" \
        | sed -n '/^##[[:space:]]*[Ss]cope/,/^##/p' \
        | tail -n +2 | grep -v '^## ' \
        | grep -E '^\s*-\s+' \
        | grep '/' \
        | sed 's/^[[:space:]]*-[[:space:]]*//' \
        | sed 's/[[:space:]]*$//' \
        | sed 's/`//g')
    echo "$SCOPE" > "$(state_file scope)"
    echo "$SCOPE" > "$(persist_file scope)"

    # Extract Success Criteria
    CRIT=$(echo "$PLAN_CONTENT" \
        | sed -n '/^##[[:space:]]*[Ss]uccess[[:space:]]*[Cc]riteria/,/^##/p' \
        | tail -n +2 | grep -v '^## ' \
        | sed '/^[[:space:]]*$/d' \
        | head -3)
    echo "$CRIT" > "$(state_file criteria)"
    echo "$CRIT" > "$(persist_file criteria)"
fi

# Clean up planning state
state_remove planning
state_remove explore_count

echo "Plan presented to user. Remind them to type /approve to confirm approval. Edits permitted after /approve, until /accept or /reject."
exit 0
