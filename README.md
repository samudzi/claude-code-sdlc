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

## Prerequisites

**Required:**
- **Bash** 3.0+ (ships with macOS; check with `bash --version`)
- **Git** (for hooks and `git rev-parse` in scripts)
- **Claude Code CLI** installed and working ([install guide](https://docs.anthropic.com/en/docs/claude-code))

**Optional linting tools** (all degrade gracefully if missing):

| Tool | Used for | Install |
|------|----------|---------|
| `shellcheck` | Shell script analysis | `brew install shellcheck` / `apt install shellcheck` |
| `ruff` | Python linting | `pip install ruff` |
| `flake8` | Python linting (ruff fallback) | `pip install flake8` |
| `eslint` | JS/TS linting | `npm install -g eslint` |
| `gofmt` | Go formatting | Included with Go |
| `rustfmt` | Rust formatting | `rustup component add rustfmt` |
| `git-lfs` | Large file storage | `brew install git-lfs` / `apt install git-lfs` |

**Platform notes:**
- **macOS**: Works out of the box.
- **Linux**: Three scripts use macOS-specific `stat -f %m` for file timestamps. Replace with `stat -c %Y` in these files:
  - `scripts/validate_before_exit_plan.sh` (line 34)
  - `scripts/mark_plan_approved.sh` (line 40)
  - `scripts/require_plan_approval.sh` (line 127)

## Installation

### Step 1: Back up existing configuration

If you already have a `~/.claude` directory with your own settings:

```bash
# Back up your existing config
cp ~/.claude/CLAUDE.md ~/.claude/CLAUDE.md.bak 2>/dev/null
cp ~/.claude/settings.json ~/.claude/settings.json.bak 2>/dev/null
```

### Step 2: Clone the template

```bash
git clone https://github.com/samudzi/claude-code-sdlc.git ~/.claude-sdlc
```

### Step 3: Copy files into `~/.claude`

```bash
# Core configuration
cp ~/.claude-sdlc/CLAUDE.md ~/.claude/CLAUDE.md
cp ~/.claude-sdlc/settings.json ~/.claude/settings.json

# Enforcement scripts
cp -r ~/.claude-sdlc/scripts/ ~/.claude/scripts/

# Git hooks (pre-commit linting, commit-msg hygiene)
cp -r ~/.claude-sdlc/git-hooks/ ~/.claude/git-hooks/
```

If you had existing `CLAUDE.md` content, merge your backed-up rules into the new file — the SDLC rules must remain intact for the hooks to work correctly.

### Step 4: Make scripts executable

```bash
chmod +x ~/.claude/scripts/*.sh ~/.claude/git-hooks/*
```

### Step 5: Set global git hooks path

```bash
git config --global core.hooksPath ~/.claude/git-hooks
```

This makes the pre-commit (linting + safety checks) and commit-msg (attribution stripping) hooks run in every repo. Repos with their own linting frameworks (`.pre-commit-config.yaml`, `.husky`, `lefthook.yml`, `lint-staged`) are automatically bypassed.

### Step 6: Verify the installation

```bash
# 1. Check all scripts are executable
ls -la ~/.claude/scripts/*.sh ~/.claude/git-hooks/*

# 2. Syntax-check every script
for f in ~/.claude/scripts/*.sh; do bash -n "$f" && echo "OK: $f"; done

# 3. Verify hooks are wired
cat ~/.claude/settings.json | grep -c '"command"'  # Should show 7 hooks

# 4. Verify git hooks path
git config --global core.hooksPath  # Should show ~/.claude/git-hooks

# 5. Test in any git repo — make a trivial change and commit
cd /tmp && git init test-sdlc && cd test-sdlc
echo "test" > test.txt && git add test.txt && git commit -m "test"
cd / && rm -rf /tmp/test-sdlc
```

### Step 7: Create the plans directory

```bash
mkdir -p ~/.claude/plans
```

This is where the model writes its plans during the planning phase. The directory is local-only (not tracked by git).

## Per-Project vs Global Setup

### Global (default)

The files you installed apply to **every Claude Code session**:

- `~/.claude/CLAUDE.md` — loaded as instructions in every session
- `~/.claude/settings.json` — hooks fire on every tool call
- `~/.claude/git-hooks/` — run on every git commit (via `core.hooksPath`)

### Per-project overrides

Create a `CLAUDE.md` in any project root to add project-specific rules. Claude Code loads **both** the global `~/.claude/CLAUDE.md` and the project's `CLAUDE.md`:

```bash
# Example: add project-specific instructions
cat > ~/my-project/CLAUDE.md << 'EOF'
# Project Instructions

- Before modifying code, review `docs/architecture.md`
- Run `npm test` after any changes to `src/`
- Never modify files in `vendor/`
EOF
```

### Per-project git hooks

If a specific repo needs its own pre-commit hook **instead of** the global one, create `.git/hooks/pre-commit` in that repo. The global hook detects legitimate local hooks and chains to them automatically. Repos using framework-managed hooks (`.pre-commit-config.yaml`, `.husky`, `lefthook.yml`, `lint-staged`) are bypassed entirely.

## Customization

**Adjust exploration minimum:** Change the `3` in `validate_before_exit_plan.sh` line 10.

**Adjust plan word minimum:** Change the `50` in `validate_before_exit_plan.sh` line 62.

**Adjust plan staleness window:** Change `1800` (30 minutes) in `validate_before_exit_plan.sh` line 50.

**Disable per-turn expiry:** Replace the body of `check_clear_approval_command.sh` with the original `/clear-approval`-only version to let approval persist across turns.

**Add project-specific rules:** Create `<project>/CLAUDE.md` with project-specific instructions. These load alongside the global `~/.claude/CLAUDE.md`.

**Disable specific git hooks:** Remove or rename individual files in `~/.claude/git-hooks/`. The pre-commit hook handles linting; the commit-msg hook strips Claude self-attribution; the others are git-lfs pass-throughs.

## Escape Hatches

If the enforcement is blocking legitimate work:

```bash
# Restore approval for this session (expires on next user message)
~/.claude/scripts/restore_approval.sh
```

The system is designed so that a competent model doing its job properly never hits the gates — they only fire when it tries to shortcut.
