#!/bin/bash
# PreToolUse hook on ExitPlanMode — quality gate (validation only, NO marker creation)
source "$(dirname "$0")/common.sh"
init_hook

ERRORS=""

# ── Check 1: Exploration depth ──
EXPLORE_COUNT=$(state_read explore_count)
EXPLORE_COUNT="${EXPLORE_COUNT:-0}"
if [[ "$EXPLORE_COUNT" -lt 3 ]]; then
    ERRORS+="INSUFFICIENT EXPLORATION: $EXPLORE_COUNT reads/searches (minimum 3).
  - Read project documentation (CLAUDE.md, docs/*.md, README)
  - Search for existing code related to the change (Grep/Glob)
  - Read the specific files you plan to modify

"
fi

# ── Check 2: Find plan file ──
PLAN_FILE=""
NEWEST_TIME=0

for DIR in ~/.claude/plans .claude/plans; do
    [[ ! -d "$DIR" ]] && continue
    while IFS= read -r -d '' F; do
        FTIME=$(file_mtime "$F")
        if [[ "$FTIME" -gt "$NEWEST_TIME" ]]; then
            NEWEST_TIME=$FTIME
            PLAN_FILE=$F
        fi
    done < <(find "$DIR" -maxdepth 1 -name '*.md' -print0 2>/dev/null)
done

if [[ -z "$PLAN_FILE" ]]; then
    deny_tool "BLOCKED: No plan file found in ~/.claude/plans/ or .claude/plans/
Write your plan to a .md file in the plans directory before calling ExitPlanMode."
fi

# Check staleness (30 min)
AGE=$(( $(date +%s) - NEWEST_TIME ))
if [[ "$AGE" -gt 1800 ]]; then
    ERRORS+="STALE PLAN: $(( AGE / 60 )) minutes old (max 30).
  File: $PLAN_FILE — update it, then try ExitPlanMode again.

"
fi

# Read plan content
PLAN_CONTENT=$(cat "$PLAN_FILE" 2>/dev/null)

# ── Check 3: Word count ──
WORD_COUNT=$(echo "$PLAN_CONTENT" | wc -w | tr -d ' ')
if [[ "$WORD_COUNT" -lt 50 ]]; then
    ERRORS+="PLAN TOO THIN: $WORD_COUNT words (minimum 50).
  Add detail: what docs you read, what code you found, what files change.

"
fi

# ── Check 4: File path references ──
if ! echo "$PLAN_CONTENT" | grep -qE '\.[a-zA-Z]{2,5}\b'; then
    ERRORS+="NO FILE REFERENCES: Plan must reference specific files (e.g., scripts/foo.sh).

"
fi

# ── Check 5: Exploration evidence ──
if ! echo "$PLAN_CONTENT" | grep -qiE '(existing|found|pattern|readme|documentation|current|already|currently)'; then
    ERRORS+="NO EXPLORATION EVIDENCE: Reference what you found in the codebase.

"
fi

# ── Check 6: Required sections ──

# Objective
if ! echo "$PLAN_CONTENT" | grep -qiE '^##\s+Objective'; then
    ERRORS+="MISSING ## Objective section (what you are doing and why).

"
else
    OBJ_CONTENT=$(echo "$PLAN_CONTENT" | sed -n '/^##[[:space:]]*[Oo]bjective/,/^##/p' | tail -n +2 | grep -v '^## ')
    OBJ_WORDS=$(echo "$OBJ_CONTENT" | wc -w | tr -d ' ')
    if [[ "$OBJ_WORDS" -lt 10 ]]; then
        ERRORS+="## Objective too short ($OBJ_WORDS words, minimum 10).

"
    fi
fi

# Scope
if ! echo "$PLAN_CONTENT" | grep -qiE '^##\s+Scope'; then
    ERRORS+="MISSING ## Scope section (list every file to be modified).

"
else
    SCOPE_CONTENT=$(echo "$PLAN_CONTENT" | sed -n '/^##[[:space:]]*[Ss]cope/,/^##/p' | tail -n +2 | grep -v '^## ')
    SCOPE_LINES=$(echo "$SCOPE_CONTENT" | grep -E '^\s*-\s+.*/' | grep -E '\.[a-zA-Z]{1,10}(\s|$|`|\))')
    if [[ -z "$SCOPE_LINES" ]]; then
        ERRORS+="## Scope has no file paths (need '- path/to/file.ext' lines).

"
    fi
fi

# Success Criteria
if ! echo "$PLAN_CONTENT" | grep -qiE '^##\s+Success\s+Criteria'; then
    ERRORS+="MISSING ## Success Criteria section (how to verify the task is done).

"
else
    CRIT_CONTENT=$(echo "$PLAN_CONTENT" | sed -n '/^##[[:space:]]*[Ss]uccess[[:space:]]*[Cc]riteria/,/^##/p' | tail -n +2 | grep -v '^## ')
    CRIT_WORDS=$(echo "$CRIT_CONTENT" | wc -w | tr -d ' ')
    if [[ "$CRIT_WORDS" -lt 10 ]]; then
        ERRORS+="## Success Criteria too short ($CRIT_WORDS words, minimum 10).

"
    fi
fi

# Justification
if ! echo "$PLAN_CONTENT" | grep -qiE '^##\s+Justification'; then
    ERRORS+="MISSING ## Justification section (why this approach, citing project docs).

"
else
    JUST_CONTENT=$(echo "$PLAN_CONTENT" | sed -n '/^##[[:space:]]*[Jj]ustification/,/^##/p' | head -50 | tail -n +2 | grep -v '^## ')

    if ! echo "$JUST_CONTENT" | grep -qE '(docs/|scripts/|tools/|assets/|scenes/|CLAUDE\.md|README|\.gd|\.md|\.tscn|\.tres|\.sh|\.json)'; then
        ERRORS+="## Justification has no project file citations.

"
    fi

    if ! echo "$JUST_CONTENT" | grep -qiE '(because|consistent with|per |therefore|aligns with|following the|in line with|as documented|as specified|this follows|this matches)'; then
        ERRORS+="## Justification lacks reasoning language (because, per, therefore, etc.).

"
    fi
fi

# ── Check 7: Cross-reference exploration log ──
if state_exists exploration_log; then
    EXPLORED_FILES=$(grep '^READ:' "$(state_file exploration_log)" | sed 's/^READ:[[:space:]]*//' | xargs -I{} basename {} 2>/dev/null | sort -u)
    if [[ -n "$EXPLORED_FILES" ]]; then
        MATCH_COUNT=0
        while IFS= read -r BASENAME; do
            [[ -z "$BASENAME" ]] && continue
            NAME_NO_EXT="${BASENAME%.*}"
            if echo "$PLAN_CONTENT" | grep -qF "$BASENAME" || echo "$PLAN_CONTENT" | grep -qF "$NAME_NO_EXT"; then
                MATCH_COUNT=$(( MATCH_COUNT + 1 ))
            fi
        done <<< "$EXPLORED_FILES"

        if [[ "$MATCH_COUNT" -lt 2 ]]; then
            ERRORS+="Plan references only $MATCH_COUNT explored file(s) (minimum 2).
  Update your plan to reference files you actually read.

"
        fi
    fi
fi

# ── Emit all errors at once, or pass ──
if [[ -n "$ERRORS" ]]; then
    deny_tool "BLOCKED: Plan quality checks failed.

${ERRORS}Fix all issues above, then try ExitPlanMode again."
fi

# ── All checks passed — record plan file path for approve_plan.sh ──
state_write plan_file "$PLAN_FILE"

echo "Plan validated. Awaiting user approval via ExitPlanMode."
exit 0
