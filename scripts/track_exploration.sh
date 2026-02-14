#!/bin/bash
# PreToolUse hook on Read|Glob|Grep — tracks exploration during planning
source "$(dirname "$0")/common.sh"
init_hook

# Not in plan mode? Silent no-op.
state_exists planning || exit 0

TOOL=$(tool_name)

case "$TOOL" in
    Read)
        FILE_PATH=$(tool_input file_path)
        [[ -n "$FILE_PATH" ]] && echo "READ: $FILE_PATH" >> "$(state_file exploration_log)"
        ;;
    Grep)
        PATTERN=$(tool_input pattern)
        SEARCH_PATH=$(tool_input path)
        [[ -n "$PATTERN" ]] && echo "SEARCH: $PATTERN | ${SEARCH_PATH:-.}" >> "$(state_file exploration_log)"
        ;;
    Glob)
        GLOB_PATTERN=$(tool_input pattern)
        SEARCH_PATH=$(tool_input path)
        [[ -n "$GLOB_PATTERN" ]] && echo "SEARCH: $GLOB_PATTERN | ${SEARCH_PATH:-.}" >> "$(state_file exploration_log)"
        ;;
esac

counter_increment explore_count > /dev/null
exit 0
