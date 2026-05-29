# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

A Claude Code **plugin** that packages reusable developer workflow skills. The plugin is declared in `.claude-plugin/plugin.json` and each skill lives under `skills/<name>/SKILL.md`.

Skills are markdown instruction files — they tell a Claude Code instance how to behave when the user invokes `/skill-name`. There is no build step, no test runner, and no compilation.

## Plugin Registration

`.claude-plugin/plugin.json` is the manifest. To add a new skill, register it here:

```json
{ "name": "my-skill", "path": "skills/my-skill" }
```

Then create `skills/my-skill/SKILL.md`.

## SKILL.md Format

Every skill file starts with YAML frontmatter followed by the instruction body:

```markdown
---
name: wt
version: 0.0.1
description: One-line description shown in /help and skill pickers.
argument-hint: [subcommand] [options]   # shown as usage hint
allowed-tools: Bash, EnterWorktree, ExitWorktree, AskUserQuestion
---

# Skill Title

Instruction body — plain prose and markdown that Claude Code follows when the skill runs.
```

Key frontmatter fields:
- `allowed-tools` — restricts which tools the skill can invoke (security boundary)
- `argument-hint` — displayed as usage hint; parsed by the skill body as `$ARGUMENTS`

## How Skills Execute

When a user runs `/wt enter main`, Claude Code:
1. Loads `skills/wt/SKILL.md`
2. Substitutes `$ARGUMENTS` → `"enter main"`
3. Follows the instruction body using only the tools in `allowed-tools`

The instruction body should be deterministic and command-driven. Use subcommand dispatch patterns (parse first word of `$ARGUMENTS`, branch on it) for multi-mode skills.

## Testing a Skill

Install the plugin locally (one-time):

```
/plugins add /path/to/dev-workflow-skills
```

Then invoke the skill directly:

```
/wt list
/wt new my-feature
```

Restart Claude Code (or reload the plugin) after editing a `SKILL.md` to pick up changes.

## Architecture Notes

- `skills/wt/SKILL.md` — the only skill currently. It manages git worktrees via the `EnterWorktree`/`ExitWorktree` Claude Code built-ins plus `Bash` for git commands.
- Interactive mode (no arguments) uses `AskUserQuestion` to present options; named subcommands are non-interactive.
- All git worktrees created by the skill are placed under `.claude/worktrees/<name>` relative to the repo root.
