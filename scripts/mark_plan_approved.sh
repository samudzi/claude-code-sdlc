#!/bin/bash
# Called after ExitPlanMode - user has approved the plan
#
# Creates two markers:
# 1. Session marker - for fast checks this session
# 2. Active plan marker - survives session changes

# Get the plan file from tool output if available
INPUT=$(cat)
PLAN_FILE=$(echo "$INPUT" | grep -o '"plan_file"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)".*/\1/' || echo "unknown")

# Create session marker
touch "/tmp/.claude_plan_approved_${PPID}"

# Create active plan marker with metadata
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [[ -n "$PROJECT_ROOT" ]]; then
    cat > "$PROJECT_ROOT/.claude_active_plan" << MARKER
plan_file: ${PLAN_FILE}
approved_at: $(date -Iseconds)
session_ppid: ${PPID}
MARKER

    # Ensure it's gitignored
    if [[ -f "$PROJECT_ROOT/.gitignore" ]]; then
        if ! grep -q "^\.claude_active_plan$" "$PROJECT_ROOT/.gitignore" 2>/dev/null; then
            echo ".claude_active_plan" >> "$PROJECT_ROOT/.gitignore"
        fi
    fi
fi

# ── Extract objective, scope, and success criteria for injection during edits ──

# Find the most recent plan file (same logic as validate_before_exit_plan.sh)
RESOLVED_PLAN=""
NEWEST_TIME=0
for DIR in ~/.claude/plans .claude/plans; do
    [[ ! -d "$DIR" ]] && continue
    while IFS= read -r -d '' F; do
        FTIME=$(stat -f %m "$F" 2>/dev/null || echo 0)
        if [[ "$FTIME" -gt "$NEWEST_TIME" ]]; then
            NEWEST_TIME=$FTIME
            RESOLVED_PLAN=$F
        fi
    done < <(find "$DIR" -maxdepth 1 -name '*.md' -print0 2>/dev/null)
done

if [[ -n "$RESOLVED_PLAN" ]]; then
    PLAN_CONTENT=$(cat "$RESOLVED_PLAN" 2>/dev/null)

    # Extract Objective (between ## Objective and next ##, first 3 lines)
    echo "$PLAN_CONTENT" \
        | sed -n '/^##[[:space:]]*[Oo]bjective/,/^##/p' \
        | tail -n +2 | grep -v '^## ' \
        | sed '/^[[:space:]]*$/d' \
        | head -3 \
        > "/tmp/.claude_objective_${PPID}"

    # Extract Scope — only lines starting with "- " that contain "/" (file paths)
    echo "$PLAN_CONTENT" \
        | sed -n '/^##[[:space:]]*[Ss]cope/,/^##/p' \
        | tail -n +2 | grep -v '^## ' \
        | grep -E '^\s*-\s+' \
        | grep '/' \
        | sed 's/^[[:space:]]*-[[:space:]]*//' \
        | sed 's/[[:space:]]*$//' \
        | sed 's/`//g' \
        > "/tmp/.claude_scope_${PPID}"

    # Extract Success Criteria (between ## Success Criteria and next ##, first 3 lines)
    echo "$PLAN_CONTENT" \
        | sed -n '/^##[[:space:]]*[Ss]uccess[[:space:]]*[Cc]riteria/,/^##/p' \
        | tail -n +2 | grep -v '^## ' \
        | sed '/^[[:space:]]*$/d' \
        | head -3 \
        > "/tmp/.claude_success_criteria_${PPID}"
fi

echo "Plan approved. Edits permitted until you start a new task with EnterPlanMode."
