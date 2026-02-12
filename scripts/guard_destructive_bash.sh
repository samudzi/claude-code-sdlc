#!/bin/bash
# PreToolUse hook on Bash — blocks destructive commands that would destroy uncommitted work
# Exit 2 = block the action. Exit 0 = allow.

trap 'exit 0' ERR

INPUT=$(cat)

# Extract the command string from tool input
COMMAND=$(echo "$INPUT" | grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"command"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')

[[ -z "$COMMAND" ]] && exit 0

# Check for destructive git commands
if echo "$COMMAND" | grep -qE 'git\s+(checkout\s+--\s|reset\s+--hard|clean\s+-[a-zA-Z]*f)'; then
    # Extract paths affected (rough: everything after the flag)
    AFFECTED_PATHS=$(echo "$COMMAND" | sed -E 's/.*git\s+(checkout\s+--\s+|reset\s+--hard\s*|clean\s+-[a-zA-Z]*f\s*)//')

    # Get uncommitted status
    if [[ -n "$AFFECTED_PATHS" && "$AFFECTED_PATHS" != "$COMMAND" ]]; then
        STATUS=$(git status --porcelain -- $AFFECTED_PATHS 2>/dev/null)
    else
        STATUS=$(git status --porcelain 2>/dev/null)
    fi

    if [[ -n "$STATUS" ]]; then
        cat << EOF
═══════════════════════════════════════════════════════════════════
BLOCKED: Destructive command would discard uncommitted changes.
═══════════════════════════════════════════════════════════════════

Command: $COMMAND

Uncommitted changes that would be lost:
$STATUS

If you intend to discard these changes, ask the user to confirm first.
═══════════════════════════════════════════════════════════════════
EOF
        exit 2
    fi
fi

# Check for rm -rf on git-tracked files
if echo "$COMMAND" | grep -qE 'rm\s+-[a-zA-Z]*r[a-zA-Z]*f|rm\s+-[a-zA-Z]*f[a-zA-Z]*r'; then
    # Extract the paths after rm flags
    RM_PATHS=$(echo "$COMMAND" | sed -E 's/.*rm\s+-[a-zA-Z]+\s+//')

    if [[ -n "$RM_PATHS" ]]; then
        # Check if any of the paths are git-tracked
        TRACKED=""
        for P in $RM_PATHS; do
            if git ls-files --error-unmatch "$P" &>/dev/null; then
                TRACKED="${TRACKED}  $P\n"
            fi
        done

        if [[ -n "$TRACKED" ]]; then
            STATUS=$(git status --porcelain -- $RM_PATHS 2>/dev/null)
            cat << EOF
═══════════════════════════════════════════════════════════════════
BLOCKED: rm -rf targets git-tracked files.
═══════════════════════════════════════════════════════════════════

Command: $COMMAND

Git-tracked files that would be deleted:
$(echo -e "$TRACKED")
${STATUS:+Uncommitted changes in these paths:
$STATUS
}
If you intend to remove these files, ask the user to confirm first.
═══════════════════════════════════════════════════════════════════
EOF
            exit 2
        fi
    fi
fi

# Non-destructive command — allow
exit 0
