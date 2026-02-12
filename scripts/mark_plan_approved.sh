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

echo "Plan approved. Edits permitted until you start a new task with EnterPlanMode."
