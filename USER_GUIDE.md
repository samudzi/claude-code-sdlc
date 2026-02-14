# User Guide: Claude Code SDLC Enforcement

## The Problem This Solves

Claude is technically brilliant but epistemically ungrounded in *your* codebase.

It can write a textbook-perfect React hook — but not *your* React hook. It doesn't know your abstractions, your naming conventions, your state management approach, or that you already have a `useAuth` hook that does exactly what it's about to reinvent. The result of this gap:

- Functions that duplicate existing utilities
- Patterns that contradict your established architecture
- "Improvements" nobody asked for (extra error handling, unsolicited refactors, docstrings everywhere)
- Code that technically works but doesn't *fit*

**High technical competence + low codebase orientation = overengineered slop.**

This system forces Claude to orient itself before it writes a single line. Not through instructions it can ignore, but through mechanical enforcement — hooks that block code changes until Claude has actually read your code and produced a plan you've approved.

## Is This For You?

### Use this when:

- **Issue-driven development** — You work from GitHub issues, Jira tickets, or structured specs, not stream-of-consciousness prompting
- **Existing codebases** — There are established patterns, conventions, and abstractions that must be respected
- **Regressions matter** — Breaking existing functionality is unacceptable
- **Team conventions exist** — Naming, architecture, file structure, testing patterns are established
- **CI/CD is critical** — Changes must pass pipelines, not just "look right"
- **You've been burned before** — Claude rewrote half your module when you asked for a one-line fix

### Skip this when:

- **Vibe coding a prototype** — You're exploring ideas and don't care about structure yet
- **Greenfield toy project** — There are no existing patterns to respect
- **One-off scripts** — A throwaway script doesn't need architectural review
- **Learning or experimenting** — The overhead isn't worth it when you're just trying things
- **Tiny codebases** — Under ~500 lines, Claude can hold the whole thing in context anyway

## How It Works (The User Experience)

When you give Claude a task, three things happen that wouldn't normally:

1. **Claude must explore before planning.** It's blocked from entering plan mode until it has read at least 3 files — your docs, your existing code, the area it's about to change. No more plans based on assumptions.

2. **Claude must plan before coding.** Every `Edit`, `Write`, and `NotebookEdit` call is blocked until a plan exists and you've approved it. The plan must be substantive (50+ words), reference real files, and describe what it found during exploration.

3. **Scope is enforced.** The plan declares which files will be modified. Edits to unlisted files are blocked. No more "while I was in there, I also refactored..."

The net effect: Claude behaves like a senior engineer on their first day — technically strong, but checking in with you before making changes because they know they lack context.

## Working With the System

### A typical task flow

```
You:     "Fix the race condition in the payment processor — see issue #247"
Claude:  [reads README, payment module, related tests — at least 3 files]
Claude:  [enters plan mode, writes plan describing what it found and how it'll fix it]
Claude:  "Here's my plan: [plan]. Ready to implement?"
You:     [review plan, approve or request changes]
Claude:  [implements the fix, scoped to approved files only]
Claude:  "Implementation complete. Review and type /accept or /reject."
You:     /accept   (or /reject to start over)
```

### Follow-up messages during implementation

Approval persists across your messages until you explicitly type `/accept` or `/reject`. You can send follow-up messages like "also update the test" or "that's not quite right" and Claude continues working under the same approved plan. No need to re-plan for minor adjustments within scope.

### When does approval clear?

Approval clears only when:
- You type `/accept` — you're satisfied with the implementation
- You type `/reject` — Claude must re-plan from scratch
- Claude enters a new plan cycle — starting a new task clears the old approval

### Emergency escape hatch

If the enforcement is blocking legitimate work (edge cases happen):

```bash
~/.claude/scripts/restore_approval.sh
```

This manually restores approval for the current session. Use sparingly — the system is designed so a model doing its job properly never hits the gates.

## Usage Examples

### Bug fix from a GitHub issue

```
You: "Fix #247 — payment webhook times out when Stripe sends duplicate events.
     See the error logs in the issue."

What happens:
- Claude reads your payment webhook handler, the Stripe integration module, and related tests
- Plans a fix: adds idempotency check using existing `cache.get()` utility (which it found by reading your code, not by inventing a new caching layer)
- You approve, it implements, you verify
```

**Why the system helps:** Without enforcement, Claude might create a new `IdempotencyManager` class, add a Redis dependency, and refactor your webhook handler — when all you needed was a three-line check using your existing cache.

### Feature implementation from a spec

```
You: "Add rate limiting to the /api/generate endpoint. Max 10 requests per minute
     per API key. We already have rate limiting on /api/chat — follow that pattern."

What happens:
- Claude reads your existing rate limiting implementation on /api/chat
- Reads your middleware registration pattern
- Plans an implementation that follows your existing approach exactly
- You approve, it implements using your patterns
```

**Why the system helps:** Claude discovers your existing `RateLimiter` middleware and your `@rate_limit` decorator instead of installing `express-rate-limit` or building something from scratch.

### Refactoring with regression safety

```
You: "Refactor the user service to separate authentication from profile management.
     Nothing should break — we have 94% coverage on this module."

What happens:
- Claude reads the entire user service, all its tests, and all callers
- Maps every dependency before proposing a split
- Plans which functions move where, which imports change
- Scope is explicit — you see exactly which files will be touched
- You approve only after reviewing the dependency map
```

**Why the system helps:** Scope enforcement prevents Claude from "helpfully" updating 15 files you didn't ask about. The exploration requirement means it actually finds all callers before moving code.

### CI/CD pipeline changes

```
You: "Add a staging deployment step to our GitHub Actions workflow.
     It should run after tests pass on the main branch."

What happens:
- Claude reads your existing CI/CD config, deployment scripts, and environment setup
- Identifies your deployment patterns (Docker? Serverless? K8s?)
- Plans the addition as a minimal diff to your existing workflow
- You review the exact YAML changes before they touch your pipeline
```

**Why the system helps:** CI/CD changes are high-stakes — a bad workflow change can block your entire team. Forced exploration means Claude understands your existing pipeline before modifying it.

### Code review follow-ups

```
You: "Address the PR feedback on #312 — reviewer wants us to use the existing
     validation middleware instead of inline validation."

What happens:
- Claude reads the PR diff, the reviewer's comments, and the existing validation middleware
- Plans a targeted change: swap inline validation for middleware usage
- Implements only what the reviewer asked for — no bonus refactoring
```

**Why the system helps:** PR follow-ups should be surgical. Scope enforcement prevents Claude from treating review feedback as an invitation to rewrite the feature.

## Tips for AI/Startup Engineering

**Treat Claude like a senior engineer on day one.** It's technically strong but needs context about *your* codebase. The enforcement system provides that context-gathering step that a real engineer would do naturally but Claude skips.

**Write good issue descriptions.** Claude grounds on what you give it. A vague "fix the bug" gets a vague exploration. A specific "the `/api/users` endpoint returns 500 when `email` contains unicode — see error log below" gets targeted investigation.

**Use project-level CLAUDE.md for team conventions.** Put a `CLAUDE.md` in your project root with project-specific rules. Both the global `~/.claude/CLAUDE.md` and the project's `CLAUDE.md` load together:

```markdown
# Project Instructions
- Run `npm test` after any changes to `src/`
- Never modify files in `vendor/`
- Follow the repository pattern in `src/repos/` for new data access
- Use `zod` for validation, not inline checks
```

**The overhead pays for itself on the second change.** The first time feels slower — Claude is reading files and writing plans instead of immediately producing code. But compare that to the alternative: Claude produces 200 lines instantly, you spend 20 minutes realizing half of it duplicates existing utilities, you undo everything and explain what it should have done, and then it does it again slightly wrong. The plan-first approach is faster in practice.

**Don't fight the system for small things.** If you genuinely need a quick one-off change and the enforcement feels heavy, use the escape hatch. The system is for protecting your codebase during real engineering work, not for gatekeeping trivial edits.

## Further Reading

- **[README.md](README.md)** — Installation, technical architecture, script reference, and customization options
- **[CLAUDE.md](CLAUDE.md)** — The instruction set loaded into Claude's context (the rules it follows)
