#!/bin/bash
# SessionStart hook — remove stale session dirs and legacy flat files (>6hrs old)

# Clean new-style session directories
if [[ -d /tmp/.claude_hooks ]]; then
    find /tmp/.claude_hooks -mindepth 1 -maxdepth 1 -type d -mmin +360 -exec rm -rf {} + 2>/dev/null
fi

# Clean legacy flat files from old hook system
find /tmp -maxdepth 1 -name '.claude_*' -mmin +360 -delete 2>/dev/null

exit 0
