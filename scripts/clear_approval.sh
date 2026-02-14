#!/bin/bash
# Clear plan approval - forces Claude back into plan mode for any further edits
#
# Use when:
# - Implementation went wrong and Claude keeps hacking instead of re-planning
# - You want to force a fresh planning cycle
#
# Note: Only clears the project-scoped .claude_active_plan marker.
# Session-scoped /tmp markers are cleared by check_clear_approval_command.sh
# on the next user message.

# Clear active plan marker
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [[ -n "$PROJECT_ROOT" && -f "$PROJECT_ROOT/.claude_active_plan" ]]; then
    rm -f "$PROJECT_ROOT/.claude_active_plan"
fi

echo "Approval cleared. Claude must now EnterPlanMode and get approval before any edits."
echo ""
echo "CLAUDE: Re-read project instructions before proceeding:"
echo "  Read ~/.claude/CLAUDE.md"
if [[ -f "$PROJECT_ROOT/CLAUDE.md" ]]; then
    echo "  Read $PROJECT_ROOT/CLAUDE.md"
fi
