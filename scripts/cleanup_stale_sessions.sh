#!/bin/bash
# SessionStart hook — remove stale temp files from crashed sessions (>24hrs old)
find /tmp -maxdepth 1 -name '.claude_*' -mtime +1 -delete 2>/dev/null
exit 0
