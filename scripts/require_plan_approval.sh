#!/bin/bash
# Block write tools until plan has been approved
# Exit code 2 = block the action
#
# Two-tier approval:
# 1. Session marker (/tmp/.claude_plan_approved_${PPID}) - current session
# 2. Active plan marker ($PROJECT/.claude_active_plan) - survives sessions
#
# Approval persists until EnterPlanMode starts a NEW task.
# Commits do NOT reset approval.
#
# When allowed, injects exploration context to ground the model's immediate attention.

# Helper: output exploration context and git status for the file being edited
inject_context() {
    local file="$1"
    local log="/tmp/.claude_exploration_log_${PPID}"

    # Exploration context (deduped, max 20 lines)
    if [[ -f "$log" ]]; then
        echo "───── Exploration context (from planning phase) ─────"
        sort -u "$log" | head -20
        echo "─────────────────────────────────────────────────────"
    fi

    # Git status for the specific file being edited
    if [[ -n "$file" ]]; then
        local status
        status=$(git status --porcelain -- "$file" 2>/dev/null)
        if [[ -n "$status" ]]; then
            echo "Git status for $file: $status"
        fi
    fi
}

# Read tool input
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')

# Always allow writes to plan files (plan mode needs this — no context injection needed)
if [[ "$FILE_PATH" == *"/.claude/plans/"* ]]; then
    exit 0
fi

# Check 1: Session marker (fast path for current session)
if [[ -f "/tmp/.claude_plan_approved_${PPID}" ]]; then
    inject_context "$FILE_PATH"
    exit 0
fi

# Check 2: Active plan marker (cross-session continuity)
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [[ -n "$PROJECT_ROOT" && -f "$PROJECT_ROOT/.claude_active_plan" ]]; then
    # Validate marker isn't ancient (optional: 24hr TTL)
    MARKER_AGE=$(( $(date +%s) - $(stat -f %m "$PROJECT_ROOT/.claude_active_plan" 2>/dev/null || echo 0) ))
    if [[ $MARKER_AGE -lt 86400 ]]; then
        # Restore session marker for faster future checks
        touch "/tmp/.claude_plan_approved_${PPID}"
        inject_context "$FILE_PATH"
        exit 0
    fi
fi

# Block with prescriptive instructions
cat << 'EOF'
═══════════════════════════════════════════════════════════════════
BLOCKED: No approved plan for this work.
═══════════════════════════════════════════════════════════════════

REQUIRED WORKFLOW:

  1. EnterPlanMode    → Enter planning mode
  2. [explore]        → Read code, understand patterns
  3. [write plan]     → Document your approach
  4. ExitPlanMode     → Present plan for user approval
  5. [user approves]  → You can now edit files
  6. [commit]         → Approval persists
  7. [continue work]  → Still approved
  8. EnterPlanMode    → Starting NEW task resets approval

───────────────────────────────────────────────────────────────────
IF YOU ALREADY HAD APPROVAL:

The approval marker may have expired (>24hrs) or been cleared.
Ask the user:

  "I need to verify: do you want me to proceed with the previously
   approved plan, or should I create a fresh plan for this work?"

If they say proceed, they can run:
  ~/.claude/scripts/restore_approval.sh

───────────────────────────────────────────────────────────────────
PURPOSE: This gate ensures human review before code changes.
DO NOT bypass. DO NOT create markers directly.
═══════════════════════════════════════════════════════════════════
EOF
exit 2
