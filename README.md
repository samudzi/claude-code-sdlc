# Claude Code SDLC Enforcement

A hook-based system that mechanically enforces software development discipline in Claude Code sessions. Instead of relying on instructions that the model can ignore, this uses Claude Code's hook system to **block tool execution** when the model tries to skip steps.

## The Problem

Claude Code's helpfulness bias makes it skip exploration and write thin plans. Instruction files say "explore first, plan second" but the model routinely jumps straight to code. The result: changes that don't fit the codebase, duplicate functions, missed patterns.

## The Solution

Three enforcement layers, each backed by shell scripts that return exit code 2 (block) when the model cuts corners:

### Layer 1: Plan Gate (Edit/Write Blocking)
**No code changes without an approved plan.** Every `Edit`, `Write`, and `NotebookEdit` call is intercepted by `require_plan_approval.sh`. If no approval markers exist, the tool is blocked with instructions telling the model exactly what to do.

### Layer 2: Exploration Tracking
**The model must actually read before it plans.** When `EnterPlanMode` fires, `clear_plan_on_new_task.sh` creates a planning marker and resets an exploration counter to zero. Every subsequent `Read`, `Glob`, or `Grep` call increments the counter via `track_exploration.sh`. This runs in <5ms and does nothing outside plan mode.

### Layer 3: Plan Quality Gate
**The plan must be substantive.** When the model calls `ExitPlanMode`, `validate_before_exit_plan.sh` runs as a PreToolUse hook and checks:

| Check | Requirement | Why |
|-------|-------------|-----|
| Exploration depth | >= 3 reads/searches | Forces the model to actually look at docs and code |
| Plan freshness | < 30 minutes old | Prevents stale plans from prior sessions |
| Plan substance | >= 50 words | Blocks one-liner "plans" |
| File references | At least one file path | Plan must reference real files |
| Exploration evidence | Keywords like "existing", "found", "current" | Plan must describe what was discovered |

If any check fails, `ExitPlanMode` is blocked and the model gets a specific error message telling it what's missing.

### Layer 4: Per-Turn Approval Expiry
**Approval dies on every user message.** `check_clear_approval_command.sh` fires on `UserPromptSubmit` and unconditionally clears both approval markers. The model gets exactly one turn to implement after plan approval. Follow-up messages like "fix this" or "that's wrong" require a fresh plan cycle.

## State Machine

```
[No Approval] ──EnterPlanMode──► [Planning] ──ExitPlanMode──► [Approved]
      ^                               |                           |
      |                          (reads tracked,            (model implements
      |                           counter increments)        in same turn)
      |                                                           |
      └──── UserPromptSubmit (ANY user message) ──────────────────┘
```

## File Reference

### Scripts (`scripts/`)

| Script | Hook | Purpose |
|--------|------|---------|
| `require_plan_approval.sh` | PreToolUse: Edit\|Write\|NotebookEdit | Blocks code changes without approval markers |
| `validate_before_exit_plan.sh` | PreToolUse: ExitPlanMode | Quality gate — checks exploration + plan substance, creates markers on pass |
| `mark_plan_approved.sh` | PostToolUse: ExitPlanMode | Backup marker creation (redundant with validate script) |
| `clear_plan_on_new_task.sh` | PostToolUse: EnterPlanMode | Clears old approval, starts exploration tracking |
| `track_exploration.sh` | PostToolUse: Read\|Glob\|Grep | Increments exploration counter during planning |
| `check_clear_approval_command.sh` | UserPromptSubmit | Clears all approval markers on every user message |
| `restore_approval.sh` | Manual | Emergency escape hatch — user runs directly to bypass |
| `clear_approval.sh` | Manual | Force-clear approval markers |
| `strip-claude-coauthor.sh` | Git hook | Removes "Co-Authored-By: Claude" from commit messages |

### Git Hooks (`git-hooks/`)

Commit message hygiene and safety checks. Set globally via `git config --global core.hooksPath ~/.claude/git-hooks`.

### Configuration

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Instructions loaded into every session — rules, plan requirements, state machine docs |
| `settings.json` | Hook wiring — maps tool events to enforcement scripts |

## Installation

```bash
git clone https://github.com/samudzi/claude-code-sdlc.git ~/.claude-sdlc

# Copy into your ~/.claude directory (or symlink)
cp ~/.claude-sdlc/CLAUDE.md ~/.claude/CLAUDE.md
cp ~/.claude-sdlc/settings.json ~/.claude/settings.json
cp -r ~/.claude-sdlc/scripts/ ~/.claude/scripts/
cp -r ~/.claude-sdlc/git-hooks/ ~/.claude/git-hooks/

# Make scripts executable
chmod +x ~/.claude/scripts/*.sh ~/.claude/git-hooks/*

# Optional: set global git hooks
git config --global core.hooksPath ~/.claude/git-hooks
```

## Customization

**Adjust exploration minimum:** Change the `3` in `validate_before_exit_plan.sh` line 10.

**Adjust plan word minimum:** Change the `50` in `validate_before_exit_plan.sh` line 62.

**Disable per-turn expiry:** Replace the body of `check_clear_approval_command.sh` with the original `/clear-approval`-only version to let approval persist across turns.

**Add project-specific rules:** Create `<project>/CLAUDE.md` with project-specific instructions. These load alongside the global `~/.claude/CLAUDE.md`.

## Escape Hatches

If the enforcement is blocking legitimate work:

```bash
# Restore approval for this session (expires on next user message)
~/.claude/scripts/restore_approval.sh
```

The system is designed so that a competent model doing its job properly never hits the gates — they only fire when it tries to shortcut.
