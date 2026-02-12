#!/bin/bash
# PreToolUse hook on ExitPlanMode — quality gate + marker creation
# Exit 2 = block the tool. Exit 0 = allow (and markers are created).

COUNTER_FILE="/tmp/.claude_explore_count_${PPID}"
PLANNING_MARKER="/tmp/.claude_planning_${PPID}"

# ── Check 1: Exploration depth ──
EXPLORE_COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)
if [[ "$EXPLORE_COUNT" -lt 3 ]]; then
    cat << EOF
BLOCKED: Insufficient exploration before ExitPlanMode.

You performed $EXPLORE_COUNT reads/searches. Minimum required: 3.

Before presenting a plan, you MUST:
  - Read project documentation (CLAUDE.md, docs/*.md, README)
  - Search for existing code related to the change (Grep/Glob)
  - Read the specific files you plan to modify

Go back and explore, then try ExitPlanMode again.
EOF
    exit 2
fi

# ── Check 2: Plan quality ──
# Find the most recent .md in any plans directory
PLAN_FILE=""
NEWEST_TIME=0

for DIR in ~/.claude/plans .claude/plans; do
    [[ ! -d "$DIR" ]] && continue
    while IFS= read -r -d '' F; do
        FTIME=$(stat -f %m "$F" 2>/dev/null || echo 0)
        if [[ "$FTIME" -gt "$NEWEST_TIME" ]]; then
            NEWEST_TIME=$FTIME
            PLAN_FILE=$F
        fi
    done < <(find "$DIR" -maxdepth 1 -name '*.md' -print0 2>/dev/null)
done

if [[ -z "$PLAN_FILE" ]]; then
    echo "BLOCKED: No plan file found in ~/.claude/plans/ or .claude/plans/"
    echo "Write your plan to a .md file in the plans directory before calling ExitPlanMode."
    exit 2
fi

# Check staleness (30 min = 1800 seconds)
AGE=$(( $(date +%s) - NEWEST_TIME ))
if [[ "$AGE" -gt 1800 ]]; then
    echo "BLOCKED: Plan file is stale ($(( AGE / 60 )) minutes old, max 30 minutes)."
    echo "File: $PLAN_FILE"
    echo "Update the plan file, then try ExitPlanMode again."
    exit 2
fi

# Read plan content
PLAN_CONTENT=$(cat "$PLAN_FILE" 2>/dev/null)

# Check word count (50+ words)
WORD_COUNT=$(echo "$PLAN_CONTENT" | wc -w | tr -d ' ')
if [[ "$WORD_COUNT" -lt 50 ]]; then
    echo "BLOCKED: Plan is too thin ($WORD_COUNT words, minimum 50)."
    echo "File: $PLAN_FILE"
    echo "Add more detail: what docs you read, what code you found, what files change."
    exit 2
fi

# Check for file path references (at least one common file extension)
if ! echo "$PLAN_CONTENT" | grep -qE '\.[a-zA-Z]{2,5}\b'; then
    echo "BLOCKED: Plan has no file path references."
    echo "File: $PLAN_FILE"
    echo "Reference specific files (e.g., scripts/foo.gd, docs/design.md) in your plan."
    exit 2
fi

# Check for exploration evidence
if ! echo "$PLAN_CONTENT" | grep -qiE '(existing|found|pattern|readme|documentation|current|already|currently)'; then
    echo "BLOCKED: Plan shows no evidence of exploration."
    echo "File: $PLAN_FILE"
    echo "Reference what you found in the codebase (existing patterns, current behavior, documentation)."
    exit 2
fi

# ── All checks passed — create approval markers ──
touch "/tmp/.claude_plan_approved_${PPID}"

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [[ -n "$PROJECT_ROOT" ]]; then
    cat > "$PROJECT_ROOT/.claude_active_plan" << MARKER
plan_file: ${PLAN_FILE}
approved_at: $(date -Iseconds)
session_ppid: ${PPID}
MARKER
fi

# Clean up planning state
rm -f "$PLANNING_MARKER" "$COUNTER_FILE"

echo "Plan validated. Approval markers created. Edits permitted for this turn."
exit 0
