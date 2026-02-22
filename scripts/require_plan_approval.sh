#!/bin/bash
# PreToolUse hook on Edit|Write|NotebookEdit — blocks until plan approved
source "$(dirname "$0")/common.sh"
init_hook

FILE_PATH=$(tool_input file_path)

# Always allow writes to plan files (plan mode needs this)
if [[ "$FILE_PATH" == *"/.claude/plans/"* ]]; then
    exit 0
fi

# ── Check approval ──
if ! state_exists approved; then
    # Check if a plan file already exists — guide model to re-approve it
    # instead of starting a fresh EnterPlanMode cycle (which clears persist)
    EXISTING_PLAN=""
    for pf in "${HOME}/.claude/plans/"*.md; do
        [[ -f "$pf" ]] && EXISTING_PLAN="$pf" && break
    done

    if [[ -n "$EXISTING_PLAN" ]]; then
        deny_tool "BLOCKED: No approved plan for this work.

A plan file exists at: ${EXISTING_PLAN}
If this plan is current, call ExitPlanMode to get it approved.
If you need a different plan, call EnterPlanMode first.

DO NOT bypass. DO NOT create markers directly."
    else
        deny_tool "BLOCKED: No approved plan for this work.

REQUIRED WORKFLOW:
  1. EnterPlanMode    → Enter planning mode
  2. [explore]        → Read code, understand patterns
  3. [write plan]     → Document your approach
  4. ExitPlanMode     → Present plan for user approval
  5. [user approves]  → You can now edit files

Approval persists until you type /accept or /reject.
If you already had approval,
ask the user to run: ~/.claude/scripts/restore_approval.sh

DO NOT bypass. DO NOT create markers directly."
    fi
fi

# ── Scope enforcement (fail-closed) ──
if state_exists scope; then
    SCOPE_CONTENT=$(state_read scope)

    # Empty scope file = fail closed (block everything)
    if [[ -z "$SCOPE_CONTENT" ]]; then
        deny_tool "BLOCKED: Scope file exists but is empty — cannot verify file is in scope.
Re-run your plan with a valid ## Scope section listing files to modify."
    fi

    IN_SCOPE=false
    while IFS= read -r SCOPE_PATH; do
        [[ -z "$SCOPE_PATH" ]] && continue
        local_expanded="${SCOPE_PATH/#\~/$HOME}"
        # Exact match
        [[ "$FILE_PATH" == "$local_expanded" ]] && IN_SCOPE=true && break
        # File ends with scope path
        [[ "$FILE_PATH" == *"$SCOPE_PATH" ]] && IN_SCOPE=true && break
        # Scope is directory prefix
        [[ "$FILE_PATH" == "${local_expanded}"* ]] && IN_SCOPE=true && break
    done <<< "$SCOPE_CONTENT"

    if [[ "$IN_SCOPE" == "false" ]]; then
        deny_tool "BLOCKED: File not in approved scope.

File: $FILE_PATH

Approved scope:
$(echo "$SCOPE_CONTENT" | sed 's/^/  - /')

To modify this file, update your plan's ## Scope section and get re-approval."
    fi
fi

# ── Context injection (every edit) ──
EDIT_COUNT=$(counter_increment edit_count)

CONTEXT=""
if state_exists objective; then
    CONTEXT+="── OBJECTIVE ──
$(state_read objective)
"
fi
if state_exists scope; then
    CONTEXT+="── SCOPE (only these files may be edited) ──
$(state_read scope)
"
fi
if state_exists criteria; then
    CONTEXT+="── SUCCESS CRITERIA ──
$(state_read criteria)
"
fi
CONTEXT+="── CONSTRAINT ──
Edit #${EDIT_COUNT}. ONLY make changes described in the approved plan. When implementation is complete, run: ~/.claude/scripts/clear_approval.sh — then tell the user to /accept or /reject. Do NOT make additional edits after signaling completion.
"

if [[ -n "$CONTEXT" ]]; then
    allow_with_context "$CONTEXT"
fi
