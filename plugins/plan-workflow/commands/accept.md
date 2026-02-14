---
description: Accept completed implementation and clear plan approval
allowed-tools: Bash(~/.claude/scripts/*), Read
---

# Accept Implementation

The user is accepting the completed implementation. Run the acceptance workflow:

1. Run `~/.claude/scripts/accept_outcome.sh` via Bash to clear approval state
2. Summarize what was implemented (based on conversation context)
3. Confirm the acceptance to the user

Do NOT start any new work. Just confirm and stop.
