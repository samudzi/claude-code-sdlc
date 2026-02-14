#!/bin/bash
# PreToolUse hook on ExitPlanMode — quality gate + marker creation
# Exit 2 = block the tool. Exit 0 = allow (and markers are created).

# Read hook stdin for session_id
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)".*/\1/')
SESSION_ID="${SESSION_ID:-$PPID}"

COUNTER_FILE="/tmp/.claude_explore_count_${SESSION_ID}"
PLANNING_MARKER="/tmp/.claude_planning_${SESSION_ID}"

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

# ── Check 3: Architectural justification gate ──

# 3a: Justification section must exist
if ! echo "$PLAN_CONTENT" | grep -qiE '^##\s+Justification'; then
    cat << EOF
BLOCKED: Plan is missing a ## Justification section.

Every plan must include a ## Justification section that explains WHY the
chosen approach is consistent with existing project architecture.

Add a section like:

  ## Justification

  Per docs/BLEND_IMPORT_PROCESS.md, the established pipeline exports GLBs
  via Blender CLI. This approach follows that pattern because ...

Then try ExitPlanMode again.
EOF
    exit 2
fi

# Extract the Justification section (from header to next ## or EOF, max 50 lines)
JUSTIFICATION=$(echo "$PLAN_CONTENT" | sed -n '/^##[[:space:]]*[Jj]ustification/,/^##/p' | head -50 | tail -n +2 | grep -v '^## ')

# 3b: Must cite at least one project file path
if ! echo "$JUSTIFICATION" | grep -qE '(docs/|scripts/|tools/|assets/|scenes/|CLAUDE\.md|README|\.gd|\.md|\.tscn|\.tres)'; then
    cat << EOF
BLOCKED: Justification section has no project file citations.

The ## Justification section must reference at least one project file to
show which documentation or code informed the approach.

Example citations:
  - Per docs/design.md FR-26, settlements start as Level 1
  - Following the pattern in scripts/autoload/FactionBuildings.gd
  - Consistent with CLAUDE.md Plan Requirements section

Add file references to your Justification, then try ExitPlanMode again.
EOF
    exit 2
fi

# 3c: Must contain causal/reasoning language
if ! echo "$JUSTIFICATION" | grep -qiE '(because|consistent with|per |therefore|aligns with|following the|in line with|as documented|as specified|this follows|this matches)'; then
    cat << EOF
BLOCKED: Justification section lacks reasoning language.

The ## Justification must explain WHY the approach was chosen, not just
list what was read. Use causal language to connect documentation to decisions.

Good: "Per docs/design.md, factions emerge at Level 2, therefore we trigger
       faction creation in the population callback."
Bad:  "Read docs/design.md. Will add faction creation."

Add reasoning language (because, per, therefore, consistent with, following the,
aligns with, etc.) then try ExitPlanMode again.
EOF
    exit 2
fi

# ── Check 5: Objective section ──
if ! echo "$PLAN_CONTENT" | grep -qiE '^##\s+Objective'; then
    cat << EOF
BLOCKED: Plan is missing a ## Objective section.

Every plan must include a ## Objective section that states what you are
doing and why. This gets injected into context during implementation to
prevent objective drift.

Add a section like:

  ## Objective

  Add scope enforcement to the hook system so that edits outside
  the declared file list are blocked during implementation.

Then try ExitPlanMode again.
EOF
    exit 2
fi

# Extract Objective content (from header to next ## or EOF)
OBJECTIVE_CONTENT=$(echo "$PLAN_CONTENT" | sed -n '/^##[[:space:]]*[Oo]bjective/,/^##/p' | tail -n +2 | grep -v '^## ')
OBJECTIVE_WORDS=$(echo "$OBJECTIVE_CONTENT" | wc -w | tr -d ' ')
if [[ "$OBJECTIVE_WORDS" -lt 10 ]]; then
    cat << EOF
BLOCKED: ## Objective section is too short ($OBJECTIVE_WORDS words, minimum 10).

The objective must clearly state what you are doing and why, in enough
detail to keep you on track during implementation.

Then try ExitPlanMode again.
EOF
    exit 2
fi

# ── Check 6: Scope section ──
if ! echo "$PLAN_CONTENT" | grep -qiE '^##\s+Scope'; then
    cat << EOF
BLOCKED: Plan is missing a ## Scope section.

Every plan must include a ## Scope section listing every file that will
be modified, one per line as a markdown list item.

Add a section like:

  ## Scope

  - scripts/autoload/FactionBuildings.gd
  - scenes/ui/settlement_panel.tscn
  - docs/design.md

Then try ExitPlanMode again.
EOF
    exit 2
fi

# Extract Scope content and check for file paths
SCOPE_CONTENT=$(echo "$PLAN_CONTENT" | sed -n '/^##[[:space:]]*[Ss]cope/,/^##/p' | tail -n +2 | grep -v '^## ')
SCOPE_FILE_LINES=$(echo "$SCOPE_CONTENT" | grep -E '^\s*-\s+.*/' | grep -E '\.[a-zA-Z]{1,10}(\s|$|`|\))')
if [[ -z "$SCOPE_FILE_LINES" ]]; then
    cat << EOF
BLOCKED: ## Scope section has no file paths.

The ## Scope section must list every file that will be modified, one per
line starting with "- " and containing a path with / and file extension.

Example:
  - ~/.claude/scripts/validate_before_exit_plan.sh
  - ~/.claude/CLAUDE.md

List every file that will be modified, then try ExitPlanMode again.
EOF
    exit 2
fi

# ── Check 7: Success Criteria section ──
if ! echo "$PLAN_CONTENT" | grep -qiE '^##\s+Success\s+Criteria'; then
    cat << EOF
BLOCKED: Plan is missing a ## Success Criteria section.

Every plan must include a ## Success Criteria section describing how to
verify the task is done. This is checked after implementation.

Add a section like:

  ## Success Criteria

  1. Writing a plan without required sections is blocked at ExitPlanMode
  2. Editing a file not in scope is blocked with a clear error
  3. Manual test passes: edit file A (allowed), edit file B (blocked)

Then try ExitPlanMode again.
EOF
    exit 2
fi

# Extract Success Criteria content
CRITERIA_CONTENT=$(echo "$PLAN_CONTENT" | sed -n '/^##[[:space:]]*[Ss]uccess[[:space:]]*[Cc]riteria/,/^##/p' | tail -n +2 | grep -v '^## ')
CRITERIA_WORDS=$(echo "$CRITERIA_CONTENT" | wc -w | tr -d ' ')
if [[ "$CRITERIA_WORDS" -lt 10 ]]; then
    cat << EOF
BLOCKED: ## Success Criteria section is too short ($CRITERIA_WORDS words, minimum 10).

The success criteria must describe how to verify the task is complete,
in enough detail to validate the implementation.

Then try ExitPlanMode again.
EOF
    exit 2
fi

# ── Check 4: Cross-reference plan against exploration log ──
EXPLORATION_LOG="/tmp/.claude_exploration_log_${SESSION_ID}"
if [[ -f "$EXPLORATION_LOG" ]]; then
    # Extract unique basenames from READ entries in the exploration log
    EXPLORED_FILES=$(grep '^READ:' "$EXPLORATION_LOG" | sed 's/^READ:[[:space:]]*//' | xargs -I{} basename {} 2>/dev/null | sort -u)

    if [[ -n "$EXPLORED_FILES" ]]; then
        MATCH_COUNT=0
        MATCHED=""
        UNMATCHED=""

        while IFS= read -r BASENAME; do
            [[ -z "$BASENAME" ]] && continue
            # Strip extension for flexible matching (e.g. "foo.sh" matches "foo.sh" or "foo")
            NAME_NO_EXT="${BASENAME%.*}"
            if echo "$PLAN_CONTENT" | grep -qF "$BASENAME" || echo "$PLAN_CONTENT" | grep -qF "$NAME_NO_EXT"; then
                MATCH_COUNT=$(( MATCH_COUNT + 1 ))
                MATCHED="${MATCHED}  - ${BASENAME}\n"
            else
                UNMATCHED="${UNMATCHED}  - ${BASENAME}\n"
            fi
        done <<< "$EXPLORED_FILES"

        if [[ "$MATCH_COUNT" -lt 2 ]]; then
            cat << EOF
BLOCKED: Plan does not reference enough of the files you explored.

You read these files during exploration but the plan does not mention them:
$(echo -e "$UNMATCHED")
The plan only references $MATCH_COUNT explored file(s). Minimum required: 2.
$(if [[ -n "$MATCHED" ]]; then echo -e "Files referenced:\n$MATCHED"; fi)
Update your plan to reference the files you actually read, then try ExitPlanMode again.
EOF
            exit 2
        fi
    fi
fi

# ── All checks passed — create approval markers ──
touch "/tmp/.claude_plan_approved_${SESSION_ID}"

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [[ -n "$PROJECT_ROOT" ]]; then
    cat > "$PROJECT_ROOT/.claude_active_plan" << MARKER
plan_file: ${PLAN_FILE}
approved_at: $(date -Iseconds)
session_id: ${SESSION_ID}
MARKER
fi

# Clean up planning state
rm -f "$PLANNING_MARKER" "$COUNTER_FILE"

echo "Plan validated. Approval markers created. Edits permitted for this turn."
exit 0
