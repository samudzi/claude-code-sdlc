---
description: Approve the current plan and enable editing — use after reviewing a plan
allowed-tools: Bash(~/.claude/scripts/*), Read
---

# Approve Plan

The user has reviewed the plan and is approving it. Run the approval workflow:

1. Run `~/.claude/scripts/restore_approval.sh` via Bash to set approval markers
2. Read the current plan file to extract scope (look in `~/.claude/plans/` for the most recent `.md` file)
3. Confirm approval to the user and list the files in scope

Do NOT start implementing yet — wait for the user to give the go-ahead.
