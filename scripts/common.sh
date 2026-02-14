#!/bin/bash
# common.sh — shared library for all Claude hook scripts
# Source this at the top of every hook: source "$(dirname "$0")/common.sh"

# ── Require jq ──
if ! command -v jq &>/dev/null; then
    echo "FATAL: jq is required but not found. Install with: brew install jq" >&2
    exit 1
fi

# ── init_hook: read stdin, extract session_id, set up state dir ──
# Call this once after sourcing. Sets: HOOK_INPUT, SESSION_ID, STATE_DIR
init_hook() {
    HOOK_INPUT=$(cat)

    SESSION_ID=$(echo "$HOOK_INPUT" | jq -r '.session_id // empty' 2>/dev/null)

    # No session_id = silent no-op (cannot isolate state)
    if [[ -z "$SESSION_ID" ]]; then
        exit 0
    fi

    STATE_DIR="/tmp/.claude_hooks/${SESSION_ID}"
    mkdir -p "$STATE_DIR"
}

# ── State helpers ──
state_file() { echo "${STATE_DIR}/$1"; }
state_exists() { [[ -f "${STATE_DIR}/$1" ]]; }
state_write() { echo "$2" > "${STATE_DIR}/$1"; }
state_read() { cat "${STATE_DIR}/$1" 2>/dev/null; }
state_remove() { rm -f "${STATE_DIR}/$1"; }

# ── JSON field extraction ──
tool_name() { echo "$HOOK_INPUT" | jq -r '.tool_name // empty'; }
tool_input() { echo "$HOOK_INPUT" | jq -r ".tool_input.$1 // empty"; }

# ── Cross-platform file mtime (epoch seconds) ──
file_mtime() {
    local path="$1"
    if [[ "$(uname)" == "Darwin" ]]; then
        stat -f %m "$path" 2>/dev/null || echo 0
    else
        stat -c %Y "$path" 2>/dev/null || echo 0
    fi
}

# ── Atomic counter increment ──
# Uses mktemp + mv on same filesystem for atomic rename
counter_increment() {
    local name="$1"
    local file="${STATE_DIR}/${name}"
    local current
    current=$(cat "$file" 2>/dev/null || echo 0)
    local next=$(( current + 1 ))
    local tmp
    tmp=$(mktemp "${STATE_DIR}/.tmp_${name}.XXXXXX")
    echo "$next" > "$tmp"
    mv -f "$tmp" "$file"
    echo "$next"
}

# ── Hook output: deny tool ──
# Outputs structured JSON that Claude Code reads as a deny decision
deny_tool() {
    local reason="$1"
    local hook_event="${2:-PreToolUse}"
    jq -n \
        --arg event "$hook_event" \
        --arg reason "$reason" \
        '{"hookSpecificOutput":{"hookEventName":$event,"permissionDecision":"deny","permissionDecisionReason":$reason}}'
    exit 0
}

# ── Hook output: allow with context ──
# Injects additionalContext into Claude's attention on allow
allow_with_context() {
    local context="$1"
    local hook_event="${2:-PreToolUse}"
    jq -n \
        --arg event "$hook_event" \
        --arg ctx "$context" \
        '{"hookSpecificOutput":{"hookEventName":$event,"permissionDecision":"allow","additionalContext":$ctx}}'
    exit 0
}
