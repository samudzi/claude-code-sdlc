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
        if [[ -n "$FILE_PATH" ]]; then
            echo "READ: $FILE_PATH" >> "$(state_file exploration_log)"
            echo "READ: $FILE_PATH" >> "$(persist_file exploration_log)"
        fi
        ;;
    Grep)
        PATTERN=$(tool_input pattern)
        SEARCH_PATH=$(tool_input path)
        if [[ -n "$PATTERN" ]]; then
            echo "SEARCH: $PATTERN | ${SEARCH_PATH:-.}" >> "$(state_file exploration_log)"
            echo "SEARCH: $PATTERN | ${SEARCH_PATH:-.}" >> "$(persist_file exploration_log)"
        fi
        ;;
    Glob)
        GLOB_PATTERN=$(tool_input pattern)
        SEARCH_PATH=$(tool_input path)
        if [[ -n "$GLOB_PATTERN" ]]; then
            echo "SEARCH: $GLOB_PATTERN | ${SEARCH_PATH:-.}" >> "$(state_file exploration_log)"
            echo "SEARCH: $GLOB_PATTERN | ${SEARCH_PATH:-.}" >> "$(persist_file exploration_log)"
        fi
        ;;
esac

counter_increment explore_count > /dev/null
cp "$(state_file explore_count)" "$(persist_file explore_count)" 2>/dev/null
exit 0
