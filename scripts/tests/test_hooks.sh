#!/bin/bash
# test_hooks.sh — end-to-end tests for Claude hook scripts
# Runs each hook against isolated temp directories using env-var overrides.
# Usage: bash ~/.claude/scripts/tests/test_hooks.sh

set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PASSED=0
FAILED=0
TOTAL=0
FAILURES=""

# ── Colors ──
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ── Test harness ──

setup() {
    TEST_TMPDIR=$(mktemp -d)
    export CLAUDE_TEST_STATE_DIR="${TEST_TMPDIR}/state"
    export CLAUDE_TEST_PERSIST_DIR="${TEST_TMPDIR}/persist"
    export CLAUDE_TEST_HOOKS_DIR="${TEST_TMPDIR}/hooks"
    mkdir -p "$CLAUDE_TEST_STATE_DIR" "$CLAUDE_TEST_PERSIST_DIR" "$CLAUDE_TEST_HOOKS_DIR"
}

teardown() {
    rm -rf "$TEST_TMPDIR"
    unset CLAUDE_TEST_STATE_DIR CLAUDE_TEST_PERSIST_DIR CLAUDE_TEST_HOOKS_DIR
}

# Run a hook script, piping JSON on stdin. Sets HOOK_OUTPUT and HOOK_EXIT.
run_hook() {
    local script="$1"
    local json="$2"
    HOOK_OUTPUT=""
    HOOK_EXIT=0
    HOOK_OUTPUT=$(echo "$json" | bash "$script" 2>/dev/null) || HOOK_EXIT=$?
}

# ── Assertions ──

assert_file_exists() {
    local path="$1"
    local label="${2:-$path}"
    if [[ ! -f "$path" ]]; then
        fail "Expected file to exist: $label"
        return 1
    fi
    return 0
}

assert_file_missing() {
    local path="$1"
    local label="${2:-$path}"
    if [[ -f "$path" ]]; then
        fail "Expected file NOT to exist: $label"
        return 1
    fi
    return 0
}

assert_file_contains() {
    local path="$1"
    local pattern="$2"
    local label="${3:-$path contains '$pattern'}"
    if ! grep -q "$pattern" "$path" 2>/dev/null; then
        fail "File $path does not contain pattern: $pattern"
        return 1
    fi
    return 0
}

assert_output_contains() {
    local pattern="$1"
    local label="${2:-output contains '$pattern'}"
    if ! echo "$HOOK_OUTPUT" | grep -q "$pattern" 2>/dev/null; then
        fail "Output does not contain: $pattern (got: ${HOOK_OUTPUT:0:200})"
        return 1
    fi
    return 0
}

assert_output_not_contains() {
    local pattern="$1"
    if echo "$HOOK_OUTPUT" | grep -q "$pattern" 2>/dev/null; then
        fail "Output should NOT contain: $pattern"
        return 1
    fi
    return 0
}

assert_exit_code() {
    local expected="$1"
    if [[ "$HOOK_EXIT" -ne "$expected" ]]; then
        fail "Expected exit code $expected, got $HOOK_EXIT"
        return 1
    fi
    return 0
}

assert_json_field() {
    local field="$1"
    local expected="$2"
    local actual
    actual=$(echo "$HOOK_OUTPUT" | jq -r "$field" 2>/dev/null)
    if [[ "$actual" != "$expected" ]]; then
        fail "JSON field $field: expected '$expected', got '$actual'"
        return 1
    fi
    return 0
}

# ── Test result tracking ──

current_test=""

begin_test() {
    current_test="$1"
    TOTAL=$(( TOTAL + 1 ))
}

pass() {
    PASSED=$(( PASSED + 1 ))
    printf "${GREEN}  PASS${NC} %s\n" "$current_test"
}

fail() {
    FAILED=$(( FAILED + 1 ))
    local reason="${1:-}"
    printf "${RED}  FAIL${NC} %s: %s\n" "$current_test" "$reason"
    FAILURES+="  - $current_test: $reason\n"
}

# ── Minimal JSON templates ──

json_pretooluse() {
    local tool="$1"
    local file_path="${2:-}"
    local pattern="${3:-}"
    local search_path="${4:-}"
    local input="{}"
    if [[ -n "$file_path" ]]; then
        input=$(jq -n --arg fp "$file_path" '{"file_path":$fp}')
    elif [[ -n "$pattern" ]]; then
        input=$(jq -n --arg p "$pattern" --arg sp "$search_path" '{"pattern":$p,"path":$sp}')
    fi
    jq -n --arg tool "$tool" --argjson input "$input" \
        '{"session_id":"test-session-001","tool_name":$tool,"tool_input":$input}'
}

json_posttooluse() {
    local tool="$1"
    jq -n --arg tool "$tool" \
        '{"session_id":"test-session-001","tool_name":$tool,"tool_input":{}}'
}

# ══════════════════════════════════════════════════════════════════
# GROUP 1: init_hook / env-var overrides
# ══════════════════════════════════════════════════════════════════
printf "\n${YELLOW}── Group 1: init_hook / env-var overrides ──${NC}\n"

# 1.1 STATE_DIR uses CLAUDE_TEST_STATE_DIR
begin_test "1.1 STATE_DIR uses CLAUDE_TEST_STATE_DIR"
setup
run_hook "${SCRIPTS_DIR}/track_exploration.sh" "$(json_pretooluse Read /tmp/foo.sh)"
# track_exploration is a no-op without planning mode, but init_hook still runs.
# Set planning mode and re-run to prove state dir is used.
echo "1" > "${CLAUDE_TEST_STATE_DIR}/planning"
run_hook "${SCRIPTS_DIR}/track_exploration.sh" "$(json_pretooluse Read /tmp/foo.sh)"
if assert_file_exists "${CLAUDE_TEST_STATE_DIR}/explore_count"; then
    pass
fi
teardown

# 1.2 PERSIST_DIR uses CLAUDE_TEST_PERSIST_DIR
begin_test "1.2 PERSIST_DIR uses CLAUDE_TEST_PERSIST_DIR"
setup
echo "1" > "${CLAUDE_TEST_PERSIST_DIR}/approved"
run_hook "${SCRIPTS_DIR}/require_plan_approval.sh" "$(json_pretooluse Edit /some/file.sh)"
# If PERSIST_DIR is used, hydration will copy approved to STATE_DIR,
# and the script won't deny
assert_output_not_contains "permissionDecision" && pass
teardown

# 1.3 Missing session_id with CLAUDE_TEST_STATE_DIR set → script still runs
begin_test "1.3 Missing session_id + STATE_DIR set → runs"
setup
local_json='{"tool_name":"Read","tool_input":{"file_path":"/tmp/x.sh"}}'
echo "1" > "${CLAUDE_TEST_STATE_DIR}/planning"
run_hook "${SCRIPTS_DIR}/track_exploration.sh" "$local_json"
if assert_file_exists "${CLAUDE_TEST_STATE_DIR}/explore_count"; then
    pass
fi
teardown

# 1.4 Missing session_id + no env var → exits silently (exit 0)
begin_test "1.4 Missing session_id + no env var → exit 0"
setup
unset CLAUDE_TEST_STATE_DIR
local_json='{"tool_name":"Read","tool_input":{"file_path":"/tmp/x.sh"}}'
run_hook "${SCRIPTS_DIR}/track_exploration.sh" "$local_json"
if assert_exit_code 0; then
    pass
fi
teardown

# ══════════════════════════════════════════════════════════════════
# GROUP 2: require_plan_approval.sh
# ══════════════════════════════════════════════════════════════════
printf "\n${YELLOW}── Group 2: require_plan_approval.sh ──${NC}\n"

REQUIRE="${SCRIPTS_DIR}/require_plan_approval.sh"

# 2.1 No approved file → deny
begin_test "2.1 No approved file → deny"
setup
run_hook "$REQUIRE" "$(json_pretooluse Edit /some/file.sh)"
if assert_json_field '.hookSpecificOutput.permissionDecision' 'deny'; then
    pass
fi
teardown

# 2.2 Approved file present → no deny (exit 0)
begin_test "2.2 Approved file present → allow"
setup
echo "1" > "${CLAUDE_TEST_STATE_DIR}/approved"
run_hook "$REQUIRE" "$(json_pretooluse Edit /some/file.sh)"
assert_exit_code 0 && assert_output_not_contains '"deny"' && pass
teardown

# 2.3 Plan file paths always allowed (no approval needed)
begin_test "2.3 Plan file paths always allowed"
setup
run_hook "$REQUIRE" "$(json_pretooluse Write /home/user/.claude/plans/plan.md)"
if assert_exit_code 0; then
    assert_output_not_contains '"deny"' && pass
fi
teardown

# 2.4 Scope enforcement: in-scope file allowed, out-of-scope blocked
begin_test "2.4 Scope enforcement: in-scope → allow"
setup
echo "1" > "${CLAUDE_TEST_STATE_DIR}/approved"
printf "src/main.sh\nlib/utils.sh\n" > "${CLAUDE_TEST_STATE_DIR}/scope"
run_hook "$REQUIRE" "$(json_pretooluse Edit /project/src/main.sh)"
assert_exit_code 0 && assert_output_not_contains '"deny"' && pass
teardown

begin_test "2.5 Scope enforcement: out-of-scope → deny"
TOTAL=$(( TOTAL ))  # already incremented by begin_test
setup
echo "1" > "${CLAUDE_TEST_STATE_DIR}/approved"
printf "src/main.sh\nlib/utils.sh\n" > "${CLAUDE_TEST_STATE_DIR}/scope"
run_hook "$REQUIRE" "$(json_pretooluse Edit /project/tests/bad.sh)"
if assert_json_field '.hookSpecificOutput.permissionDecision' 'deny'; then
    pass
fi
teardown

# 2.6 Context injection on first edit
begin_test "2.6 Context injection on first edit"
setup
echo "1" > "${CLAUDE_TEST_STATE_DIR}/approved"
echo "Build the widget" > "${CLAUDE_TEST_STATE_DIR}/objective"
echo "src/widget.sh" > "${CLAUDE_TEST_STATE_DIR}/scope"
echo "Widget works" > "${CLAUDE_TEST_STATE_DIR}/criteria"
run_hook "$REQUIRE" "$(json_pretooluse Edit /project/src/widget.sh)"
if assert_json_field '.hookSpecificOutput.permissionDecision' 'allow'; then
    assert_output_contains "OBJECTIVE" && pass
fi
teardown

# ══════════════════════════════════════════════════════════════════
# GROUP 3: approve_plan.sh (PostToolUse on ExitPlanMode)
# ══════════════════════════════════════════════════════════════════
printf "\n${YELLOW}── Group 3: approve_plan.sh ──${NC}\n"

APPROVE="${SCRIPTS_DIR}/approve_plan.sh"

# 3.1 Creates approved in both dirs
begin_test "3.1 Creates approved in STATE_DIR and PERSIST_DIR"
setup
run_hook "$APPROVE" "$(json_posttooluse ExitPlanMode)"
assert_file_exists "${CLAUDE_TEST_STATE_DIR}/approved" "state/approved" \
    && assert_file_exists "${CLAUDE_TEST_PERSIST_DIR}/approved" "persist/approved" \
    && pass
teardown

# 3.2 Extracts objective/scope/criteria from plan file
begin_test "3.2 Extracts plan sections into state files"
setup
# Create a plan file and record its path in state
PLAN_DIR="${TEST_TMPDIR}/plans"
mkdir -p "$PLAN_DIR"
PLAN_FILE="${PLAN_DIR}/test-plan.md"
cat > "$PLAN_FILE" <<'PLAN'
## Objective
Build a test harness for validating hook behavior end-to-end.

## Scope
- ~/.claude/scripts/tests/test_hooks.sh

## Success Criteria
All 21 tests pass with zero failures when run via bash.

## Justification
Per CLAUDE.md rule 5, we must validate. This follows existing patterns in scripts/.
PLAN
echo "$PLAN_FILE" > "${CLAUDE_TEST_STATE_DIR}/plan_file"
run_hook "$APPROVE" "$(json_posttooluse ExitPlanMode)"
assert_file_exists "${CLAUDE_TEST_STATE_DIR}/objective" \
    && assert_file_contains "${CLAUDE_TEST_STATE_DIR}/objective" "test harness" \
    && assert_file_exists "${CLAUDE_TEST_STATE_DIR}/scope" \
    && assert_file_contains "${CLAUDE_TEST_STATE_DIR}/scope" "test_hooks.sh" \
    && assert_file_exists "${CLAUDE_TEST_PERSIST_DIR}/objective" \
    && assert_file_exists "${CLAUDE_TEST_PERSIST_DIR}/scope" \
    && pass
teardown

# 3.3 Cleans up planning and explore_count
begin_test "3.3 Cleans up planning and explore_count"
setup
echo "1" > "${CLAUDE_TEST_STATE_DIR}/planning"
echo "5" > "${CLAUDE_TEST_STATE_DIR}/explore_count"
run_hook "$APPROVE" "$(json_posttooluse ExitPlanMode)"
assert_file_missing "${CLAUDE_TEST_STATE_DIR}/planning" \
    && assert_file_missing "${CLAUDE_TEST_STATE_DIR}/explore_count" \
    && pass
teardown

# ══════════════════════════════════════════════════════════════════
# GROUP 4: clear_plan_on_new_task.sh (PostToolUse on EnterPlanMode)
# ══════════════════════════════════════════════════════════════════
printf "\n${YELLOW}── Group 4: clear_plan_on_new_task.sh ──${NC}\n"

CLEAR_TASK="${SCRIPTS_DIR}/clear_plan_on_new_task.sh"

# 4.1 Clears approval markers from both dirs
begin_test "4.1 Clears approval from STATE_DIR and PERSIST_DIR"
setup
echo "1" > "${CLAUDE_TEST_STATE_DIR}/approved"
echo "obj" > "${CLAUDE_TEST_STATE_DIR}/objective"
echo "sc" > "${CLAUDE_TEST_STATE_DIR}/scope"
echo "cr" > "${CLAUDE_TEST_STATE_DIR}/criteria"
echo "1" > "${CLAUDE_TEST_PERSIST_DIR}/approved"
echo "obj" > "${CLAUDE_TEST_PERSIST_DIR}/objective"
echo "sc" > "${CLAUDE_TEST_PERSIST_DIR}/scope"
echo "cr" > "${CLAUDE_TEST_PERSIST_DIR}/criteria"
run_hook "$CLEAR_TASK" "$(json_posttooluse EnterPlanMode)"
assert_file_missing "${CLAUDE_TEST_STATE_DIR}/approved" \
    && assert_file_missing "${CLAUDE_TEST_STATE_DIR}/objective" \
    && assert_file_missing "${CLAUDE_TEST_PERSIST_DIR}/approved" \
    && assert_file_missing "${CLAUDE_TEST_PERSIST_DIR}/objective" \
    && pass
teardown

# 4.2 Creates planning and explore_count markers
begin_test "4.2 Creates planning + explore_count markers"
setup
run_hook "$CLEAR_TASK" "$(json_posttooluse EnterPlanMode)"
assert_file_exists "${CLAUDE_TEST_STATE_DIR}/planning" \
    && assert_file_contains "${CLAUDE_TEST_STATE_DIR}/explore_count" "0" \
    && pass
teardown

# ══════════════════════════════════════════════════════════════════
# GROUP 5: track_exploration.sh
# ══════════════════════════════════════════════════════════════════
printf "\n${YELLOW}── Group 5: track_exploration.sh ──${NC}\n"

TRACK="${SCRIPTS_DIR}/track_exploration.sh"

# 5.1 Increments explore_count
begin_test "5.1 Increments explore_count on Read"
setup
echo "1" > "${CLAUDE_TEST_STATE_DIR}/planning"
echo "0" > "${CLAUDE_TEST_STATE_DIR}/explore_count"
run_hook "$TRACK" "$(json_pretooluse Read /some/file.sh)"
run_hook "$TRACK" "$(json_pretooluse Grep "" "*.sh" /some/dir)"
run_hook "$TRACK" "$(json_pretooluse Read /another/file.sh)"
COUNT=$(cat "${CLAUDE_TEST_STATE_DIR}/explore_count")
if [[ "$COUNT" -eq 3 ]]; then
    pass
else
    fail "Expected explore_count=3, got $COUNT"
fi
teardown

# 5.2 Appends to exploration_log with correct format
begin_test "5.2 Appends to exploration_log"
setup
echo "1" > "${CLAUDE_TEST_STATE_DIR}/planning"
echo "0" > "${CLAUDE_TEST_STATE_DIR}/explore_count"
run_hook "$TRACK" "$(json_pretooluse Read /path/to/main.sh)"
run_hook "$TRACK" "$(json_pretooluse Grep "" "TODO" /src)"
assert_file_exists "${CLAUDE_TEST_STATE_DIR}/exploration_log" \
    && assert_file_contains "${CLAUDE_TEST_STATE_DIR}/exploration_log" "READ: /path/to/main.sh" \
    && assert_file_contains "${CLAUDE_TEST_STATE_DIR}/exploration_log" "SEARCH: TODO" \
    && pass
teardown

# 5.3 No-op when not in planning mode
begin_test "5.3 No-op when not in planning mode"
setup
# No planning marker
run_hook "$TRACK" "$(json_pretooluse Read /tmp/whatever.sh)"
assert_file_missing "${CLAUDE_TEST_STATE_DIR}/explore_count" "explore_count absent" \
    && assert_file_missing "${CLAUDE_TEST_STATE_DIR}/exploration_log" "exploration_log absent" \
    && pass
teardown

# ══════════════════════════════════════════════════════════════════
# GROUP 6: Standalone scripts
# ══════════════════════════════════════════════════════════════════
printf "\n${YELLOW}── Group 6: Standalone scripts ──${NC}\n"

# 6.1 restore_approval.sh
begin_test "6.1 restore_approval.sh creates approved"
setup
# Create a fake session subdir under HOOKS_DIR
mkdir -p "${CLAUDE_TEST_HOOKS_DIR}/session-abc"
run_hook "${SCRIPTS_DIR}/restore_approval.sh" ""
assert_file_exists "${CLAUDE_TEST_PERSIST_DIR}/approved" "persist/approved" \
    && assert_file_exists "${CLAUDE_TEST_HOOKS_DIR}/session-abc/approved" "session/approved" \
    && pass
teardown

# 6.2 accept_outcome.sh
begin_test "6.2 accept_outcome.sh clears approval"
setup
mkdir -p "${CLAUDE_TEST_HOOKS_DIR}/session-xyz"
echo "1" > "${CLAUDE_TEST_PERSIST_DIR}/approved"
echo "obj" > "${CLAUDE_TEST_PERSIST_DIR}/objective"
echo "1" > "${CLAUDE_TEST_HOOKS_DIR}/session-xyz/approved"
echo "obj" > "${CLAUDE_TEST_HOOKS_DIR}/session-xyz/objective"
run_hook "${SCRIPTS_DIR}/accept_outcome.sh" ""
assert_file_missing "${CLAUDE_TEST_PERSIST_DIR}/approved" \
    && assert_file_missing "${CLAUDE_TEST_PERSIST_DIR}/objective" \
    && assert_file_missing "${CLAUDE_TEST_HOOKS_DIR}/session-xyz/approved" \
    && assert_file_missing "${CLAUDE_TEST_HOOKS_DIR}/session-xyz/objective" \
    && pass
teardown

# 6.3 reject_outcome.sh
begin_test "6.3 reject_outcome.sh clears approval"
setup
mkdir -p "${CLAUDE_TEST_HOOKS_DIR}/session-rej"
echo "1" > "${CLAUDE_TEST_PERSIST_DIR}/approved"
echo "sc" > "${CLAUDE_TEST_PERSIST_DIR}/scope"
echo "1" > "${CLAUDE_TEST_HOOKS_DIR}/session-rej/approved"
echo "sc" > "${CLAUDE_TEST_HOOKS_DIR}/session-rej/scope"
run_hook "${SCRIPTS_DIR}/reject_outcome.sh" ""
assert_file_missing "${CLAUDE_TEST_PERSIST_DIR}/approved" \
    && assert_file_missing "${CLAUDE_TEST_PERSIST_DIR}/scope" \
    && assert_file_missing "${CLAUDE_TEST_HOOKS_DIR}/session-rej/approved" \
    && pass
teardown

# 6.4 clear_approval.sh
begin_test "6.4 clear_approval.sh clears all state"
setup
mkdir -p "${CLAUDE_TEST_HOOKS_DIR}/session-clr"
echo "1" > "${CLAUDE_TEST_PERSIST_DIR}/approved"
echo "crit" > "${CLAUDE_TEST_PERSIST_DIR}/criteria"
echo "1" > "${CLAUDE_TEST_HOOKS_DIR}/session-clr/approved"
echo "crit" > "${CLAUDE_TEST_HOOKS_DIR}/session-clr/criteria"
run_hook "${SCRIPTS_DIR}/clear_approval.sh" ""
assert_file_missing "${CLAUDE_TEST_PERSIST_DIR}/approved" \
    && assert_file_missing "${CLAUDE_TEST_PERSIST_DIR}/criteria" \
    && assert_file_missing "${CLAUDE_TEST_HOOKS_DIR}/session-clr/approved" \
    && assert_file_missing "${CLAUDE_TEST_HOOKS_DIR}/session-clr/criteria" \
    && pass
teardown

# ══════════════════════════════════════════════════════════════════
# Final report
# ══════════════════════════════════════════════════════════════════
printf "\n${YELLOW}══════════════════════════════════════════${NC}\n"
if [[ "$FAILED" -eq 0 ]]; then
    printf "${GREEN}ALL TESTS PASSED: %d / %d${NC}\n" "$PASSED" "$TOTAL"
else
    printf "${RED}FAILURES: %d / %d${NC}\n" "$FAILED" "$TOTAL"
    printf "\nFailed tests:\n"
    printf "$FAILURES"
fi
printf "${YELLOW}══════════════════════════════════════════${NC}\n"

exit "$FAILED"
