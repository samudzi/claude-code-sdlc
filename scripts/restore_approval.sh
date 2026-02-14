#!/bin/bash
# Restore approval when user confirms prior approval was valid
# Use when: approval state was lost but user confirms they approved earlier
#
# Usage: ~/.claude/scripts/restore_approval.sh
#
# Note: Only creates the project-scoped .claude_active_plan marker.
# The session-scoped /tmp marker is lazily created by require_plan_approval.sh
# when it detects .claude_active_plan on the next edit check.

# Create active plan marker
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [[ -n "$PROJECT_ROOT" ]]; then
    cat > "$PROJECT_ROOT/.claude_active_plan" << MARKER
plan_file: restored_by_user
approved_at: $(date -Iseconds)
restored: true
MARKER
fi

echo "Approval restored. Claude can now edit files."
echo "To require fresh planning, run: rm $PROJECT_ROOT/.claude_active_plan"
echo ""
echo "CLAUDE: Re-read project instructions before proceeding:"
echo "  Read ~/.claude/CLAUDE.md"
if [[ -f "$PROJECT_ROOT/CLAUDE.md" ]]; then
    echo "  Read $PROJECT_ROOT/CLAUDE.md"
fi
