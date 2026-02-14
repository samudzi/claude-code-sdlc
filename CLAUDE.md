# Rules

## First Action Protocol
When you receive ANY request that will involve code changes, your FIRST actions — before
thinking about solutions — MUST be:
1. Find project documentation: Glob for README*, CLAUDE.md, docs/**/*.md, CONTRIBUTING*
2. Read the most relevant docs found
3. Search for existing code related to the request (Grep/Glob)

You MUST complete these reads BEFORE entering plan mode.

## Five Absolute Rules
1. NEVER write/edit code without an approved plan (enforced by hooks)
2. NEVER propose a plan without first reading project docs and related code
3. NEVER create a function without searching for existing ones first
4. NEVER make changes beyond what was explicitly approved
5. NEVER skip validation after implementation

## Plan Requirements
Every plan MUST include:
- Which documentation you read and what it says about this change
- Existing code/patterns you found that relate to this change
- Specific files that will be modified
- The minimal change needed

Every plan MUST include these enforced sections:
- `## Objective` — What are we doing and why (≥ 10 words)
- `## Scope` — Every file that will be modified, one per line as `- path/to/file.ext`
- `## Success Criteria` — How to verify the task is done (≥ 10 words)
- `## Justification` — Why this approach, citing project docs (existing requirement)

The Scope section is enforced: edits to files not listed will be BLOCKED.

## UI Changes Require ASCII Mockups
When a plan involves ANY visual/UI change, the plan MUST include an ASCII mockup
showing the proposed layout BEFORE and AFTER. No UI code without a visual preview.

## Git Commits
Never add "Co-Authored-By: Claude" or any self-attribution to commit messages.

## Debugging Workflow
When something doesn't work, DO NOT immediately jump to code changes:
1. List at least 3 possible causes with evidence for/against each
2. Form a theory based on evidence
3. Write an implementation plan for the fix
4. Get approval before writing code

---

## Hook System - ENFORCED WORKFLOW

Hooks **BLOCK Edit/Write/NotebookEdit** until plan approval.
Hooks **BLOCK ExitPlanMode** if exploration or plan quality is insufficient.
Approval **persists until the user explicitly accepts or rejects** the implementation outcome.

### State Machine

```
[No Approval] ──EnterPlanMode──► [Planning] ──ExitPlanMode──► [Approved/Implementing]
      ^                                                           │
      │                                          (approval persists across ALL
      │                                           user messages — no auto-expiry)
      │                                                           │
      │                                          user types /accept or /reject
      │                                                           │
      └───────────────────────────────────────────────────────────┘
```

Approval is cleared ONLY by:
- `/accept` — user accepts the implementation outcome
- `/reject` — user rejects; must re-plan
- `EnterPlanMode` — starting a new plan cycle clears the previous one

### The Workflow

1. `EnterPlanMode` → clears approval, enters planning, starts exploration tracking
2. Explore codebase: Read docs, Grep/Glob for related code (minimum 3 reads/searches)
3. Write substantive plan to plan file (50+ words, reference files found)
4. `ExitPlanMode` → validates exploration + plan quality → creates approval markers → user approves
5. Edit/Write/NotebookEdit now allowed — implement across as many turns as needed
6. When implementation is complete, tell the user to review and type `/accept` or `/reject`

### When You See "BLOCKED: No approved plan"

**Always:** Follow steps 1-6 above.

**Emergency escape hatch (user runs manually):**
```
~/.claude/scripts/restore_approval.sh
```

### What NOT To Do

- DO NOT bypass or work around the block
- DO NOT create marker files directly
- DO NOT assume approval has expired — it persists until /accept, /reject, or new plan cycle
