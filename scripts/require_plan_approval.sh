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

# Helper: check if file is within the declared scope
check_scope() {
    local file="$1"
    local scope_file="/tmp/.claude_scope_${PPID}"

    # If no scope file exists (older plan format), allow all edits
    [[ ! -f "$scope_file" ]] && return 0
    # Empty scope file means no enforcement
    [[ ! -s "$scope_file" ]] && return 0

    # Check each scope entry — allow if the file path ends with the scope path,
    # or the scope path is a prefix of the file path
    while IFS= read -r SCOPE_PATH; do
        [[ -z "$SCOPE_PATH" ]] && continue
        # Expand ~ to $HOME for comparison
        local expanded_scope="${SCOPE_PATH/#\~/$HOME}"
        # Exact match
        if [[ "$file" == "$expanded_scope" ]]; then
            return 0
        fi
        # File ends with scope path (e.g. scope says "scripts/foo.sh", file is "/full/path/scripts/foo.sh")
        if [[ "$file" == *"$SCOPE_PATH" ]]; then
            return 0
        fi
        # Scope is a directory prefix (e.g. scope says "src/", file is "src/foo.js")
        if [[ "$file" == "${expanded_scope}"* ]]; then
            return 0
        fi
    done < "$scope_file"

    # No match — block
    cat << EOF
═══════════════════════════════════════════════════════════════════
BLOCKED: File not in approved scope.
═══════════════════════════════════════════════════════════════════

File: $file

Approved scope:
$(sed 's/^/  - /' "$scope_file")

To modify this file, update your plan's ## Scope section and get re-approval.
═══════════════════════════════════════════════════════════════════
EOF
    return 1
}

# Helper: output objective grounding + exploration context + git status
inject_context() {
    local file="$1"
    local log="/tmp/.claude_exploration_log_${PPID}"
    local obj_file="/tmp/.claude_objective_${PPID}"
    local scope_file="/tmp/.claude_scope_${PPID}"
    local criteria_file="/tmp/.claude_success_criteria_${PPID}"

    # Objective grounding (injected FIRST to anchor attention)
    if [[ -f "$obj_file" && -s "$obj_file" ]]; then
        echo "───── OBJECTIVE ─────"
        head -3 "$obj_file"
        echo ""
    fi
    if [[ -f "$scope_file" && -s "$scope_file" ]]; then
        echo "───── SCOPE (only these files may be edited) ─────"
        cat "$scope_file"
        echo ""
    fi
    if [[ -f "$criteria_file" && -s "$criteria_file" ]]; then
        echo "───── SUCCESS CRITERIA ─────"
        head -3 "$criteria_file"
        echo ""
    fi
    echo "─────────────────────────────────────────────────────"

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
    # Enforce scope before allowing the edit
    if ! check_scope "$FILE_PATH"; then
        exit 2
    fi
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
        # Enforce scope before allowing the edit
        if ! check_scope "$FILE_PATH"; then
            exit 2
        fi
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
