#!/bin/bash
# Git commit-msg hook: strips Claude self-attribution from commit messages

COMMIT_MSG_FILE="$1"

# Remove Co-Authored-By lines mentioning Claude/Anthropic
sed -i.bak '/Co-Authored-By:.*[Cc]laude/d' "$COMMIT_MSG_FILE"
sed -i.bak '/Co-Authored-By:.*[Aa]nthropic/d' "$COMMIT_MSG_FILE"
sed -i.bak '/Co-authored-by:.*[Cc]laude/d' "$COMMIT_MSG_FILE"
sed -i.bak '/Co-authored-by:.*[Aa]nthropic/d' "$COMMIT_MSG_FILE"

# Clean up trailing blank lines
sed -i.bak -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$COMMIT_MSG_FILE"

rm -f "${COMMIT_MSG_FILE}.bak"
