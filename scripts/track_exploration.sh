#!/bin/bash
# PreToolUse hook on Read|Glob|Grep — tracks exploration depth AND content during planning
# Receives tool INPUT (file paths, patterns) since this runs before the tool executes.
# Fast exit if not in plan mode (zero friction outside planning).

trap 'exit 0' ERR

PLANNING_MARKER="/tmp/.claude_planning_${PPID}"
COUNTER_FILE="/tmp/.claude_explore_count_${PPID}"
EXPLORATION_LOG="/tmp/.claude_exploration_log_${PPID}"

# Not in plan mode? Do nothing.
[[ ! -f "$PLANNING_MARKER" ]] && exit 0

# Read tool input (JSON with tool_name and tool_input)
INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | grep -o '"tool_name"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)".*/\1/')

case "$TOOL_NAME" in
    Read)
        FILE_PATH=$(echo "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
        [[ -n "$FILE_PATH" ]] && echo "READ: $FILE_PATH" >> "$EXPLORATION_LOG"
        ;;
    Grep)
        PATTERN=$(echo "$INPUT" | grep -o '"pattern"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"pattern"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
        SEARCH_PATH=$(echo "$INPUT" | grep -o '"path"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
        [[ -n "$PATTERN" ]] && echo "SEARCH: $PATTERN | ${SEARCH_PATH:-.}" >> "$EXPLORATION_LOG"
        ;;
    Glob)
        GLOB_PATTERN=$(echo "$INPUT" | grep -o '"pattern"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"pattern"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
        SEARCH_PATH=$(echo "$INPUT" | grep -o '"path"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
        [[ -n "$GLOB_PATTERN" ]] && echo "SEARCH: $GLOB_PATTERN | ${SEARCH_PATH:-.}" >> "$EXPLORATION_LOG"
        ;;
esac

# Increment exploration counter
COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)
echo $(( COUNT + 1 )) > "$COUNTER_FILE"

exit 0
