#!/bin/bash
# common.sh — shared library for all Claude hook scripts
# Source this at the top of every hook: source "$(dirname "$0")/common.sh"

# ── Require jq ──
if ! command -v jq &>/dev/null; then
    echo "FATAL: jq is required but not found. Install with: brew install jq" >&2
    exit 1
fi

# ── init_hook: read stdin, extract session_id, set up state dirs ──
# Sets: HOOK_INPUT, SESSION_ID, STATE_DIR (session), PERSIST_DIR (project)
init_hook() {
    HOOK_INPUT=$(cat)

    SESSION_ID=$(echo "$HOOK_INPUT" | jq -r '.session_id // empty' 2>/dev/null)

    if [[ -z "$SESSION_ID" && -z "$CLAUDE_TEST_STATE_DIR" ]]; then
        exit 0
    fi

    # Session-scoped ephemeral state (planning, explore_count)
    STATE_DIR="${CLAUDE_TEST_STATE_DIR:-/tmp/.claude_hooks/${SESSION_ID}}"
    mkdir -p "$STATE_DIR"

    # Project-scoped persistent state (approval, scope, objective, criteria)
    PROJECT_HASH=$(pwd | shasum | cut -c1-12)
    PERSIST_DIR="${CLAUDE_TEST_PERSIST_DIR:-${HOME}/.claude/state/${PROJECT_HASH}}"
    mkdir -p "$PERSIST_DIR"

    # Hydrate: if session lacks approval but project has it, restore into session
    if [[ ! -f "${STATE_DIR}/approved" && -f "${PERSIST_DIR}/approved" ]]; then
        for f in approved scope objective criteria; do
            [[ -f "${PERSIST_DIR}/$f" ]] && cp "${PERSIST_DIR}/$f" "${STATE_DIR}/$f"
        done
    fi
}

# ── Session state helpers ──
state_file() { echo "${STATE_DIR}/$1"; }
state_exists() { [[ -f "${STATE_DIR}/$1" ]]; }
state_write() { echo "$2" > "${STATE_DIR}/$1"; }
state_read() { cat "${STATE_DIR}/$1" 2>/dev/null; }
state_remove() { rm -f "${STATE_DIR}/$1"; }

# ── Persistent state helpers ──
persist_file() { echo "${PERSIST_DIR}/$1"; }
persist_exists() { [[ -f "${PERSIST_DIR}/$1" ]]; }
persist_write() { echo "$2" > "${PERSIST_DIR}/$1"; }
persist_read() { cat "${PERSIST_DIR}/$1" 2>/dev/null; }
persist_remove() { rm -f "${PERSIST_DIR}/$1"; }

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
allow_with_context() {
    local context="$1"
    local hook_event="${2:-PreToolUse}"
    jq -n \
        --arg event "$hook_event" \
        --arg ctx "$context" \
        '{"hookSpecificOutput":{"hookEventName":$event,"permissionDecision":"allow","additionalContext":$ctx}}'
    exit 0
}
