# Global Claude Code Configuration

This directory (`~/.claude`) contains global configuration that applies to Claude Code across **all projects** on this computer.

## Configuration Hierarchy

Claude Code loads instructions in this order (later overrides earlier):

1. **Global instructions** (this directory): `~/.claude/instructions.md`
2. **Project instructions**: `<project>/.claude/instructions.md`
3. **Project guidelines**: `<project>/AI_CODING_GUIDELINES.md`
4. **User reminders**: Direct instructions in conversation

## Files in This Directory

- **instructions.md** - Universal workflow rules for all projects
- **GLOBAL_RULES.md** - Quick reference for core principles
- **README.md** - This file, explaining how it all works

## How It Works

1. When you start Claude Code in ANY project, it automatically loads `~/.claude/instructions.md`
2. If the project has `.claude/instructions.md`, that gets loaded too (and takes priority)
3. This ensures consistent behavior across all your projects

## Usage Tips

### For Universal Rules
Edit `~/.claude/instructions.md` to add rules that should apply to ALL your projects:
- Code review standards
- Security practices
- Documentation requirements
- General workflow preferences

### For Project-Specific Rules
Create `<project>/.claude/instructions.md` for project-specific requirements:
- Framework-specific patterns
- Team conventions
- Deployment procedures
- Project architecture rules

### Reinforcement in Long Conversations
Claude's adherence can drift in long conversations. Periodically remind:
```
"Check GLOBAL_RULES.md and follow the workflow strictly"
```

## Best Practices

1. **Keep global rules general** - They apply everywhere, so keep them universally applicable
2. **Keep them short** - Under 50 lines for better adherence
3. **Use strong language** - ALWAYS, NEVER, MUST, MANDATORY for critical rules
4. **Add STOP POINTS** - Where Claude must wait for approval
5. **Periodic reminders** - Every 5-10 exchanges in long chats

## Testing

To verify Claude is loading your instructions:
1. Start a new conversation
2. Ask: "What workflow should you follow before writing code?"
3. Claude should mention the EXPLORE → PLAN → CONFIRM → CODE workflow

## Updating

After editing instructions.md:
- Changes apply immediately to NEW conversations
- For existing conversations, remind Claude: "Reload instructions from ~/.claude/instructions.md"
