---
description: Reject implementation and clear plan approval — forces re-planning
allowed-tools: Bash(~/.claude/scripts/*), Read
---

# Reject Implementation

The user is rejecting the current implementation. Run the rejection workflow:

1. Run `~/.claude/scripts/reject_outcome.sh` via Bash to clear approval state
2. Ask the user what went wrong or what they want changed
3. Do NOT start a new plan yet — wait for the user's feedback

Do NOT make any edits. Just clear state and ask for direction.
