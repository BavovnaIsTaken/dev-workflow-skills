---
name: wt
version: 0.0.1
description: Manage git worktrees — list, enter, create, exit, and remove. Run /wt for interactive mode.
argument-hint: [list|enter <name>|new <name> [branch]|exit [keep|remove]|remove <name>|status]
allowed-tools: Bash, EnterWorktree, ExitWorktree, AskUserQuestion
---

# Worktree Manager

Parse the first word of `$ARGUMENTS` as the subcommand. If empty, run interactive mode.

---

## No arguments — interactive mode

1. Run `git worktree list --porcelain` and display a formatted table (see `list` mode below)
2. Use AskUserQuestion to ask what the user wants to do next, with options based on the available worktrees

---

## `list`

Run `git worktree list --porcelain` and parse the output. Each worktree block looks like:
```
worktree /path/to/worktree
HEAD <hash>
branch refs/heads/<branch-name>
```
(bare worktrees have `bare` instead of `branch`)

Display each worktree as a **card** (box drawing characters). Separate cards with a blank line:
```
┌─ Worktree: [main] ──────────────────────────── [current] ─┐
│ branch  feature/videochat-e2e-tests                        │
│ path    ~/AndroidStudioProjects/minichat-android           │
│ commit  e1ff8b89   status  dirty (2D 2M 1?)                │
└────────────────────────────────────────────────────────────┘

┌─ Worktree: [may-fixes] ────────────────────────────────────┐
│ branch  fix/may-rc-polish                                   │
│ path    .claude/worktrees/may-fixes                         │
│ commit  db97fb5c   status  clean                            │
└────────────────────────────────────────────────────────────┘

┌─ Worktree: [timber-log-viewer] ────────────────────────────┐
│ branch  feature/timber-log-viewer                           │
│ path    .claude/worktrees/timber-log-viewer                 │
│ commit  d0cd79b0   status  dirty (2M 2?)                    │
└────────────────────────────────────────────────────────────┘
```

Card rules:
- **Title**: format as `┌─ Worktree: [<name>] ──…─┐` where name is the last path segment; for the main repo use `main`
- **[current]**: shown right-aligned in the top border for the worktree matching the current working directory
- **branch**: strip `refs/heads/` prefix; show `(detached)` for detached HEAD
- **path**: Replace `$HOME` with `~`. For worktrees inside the repo root, show path relative to repo root (e.g., `.claude/worktrees/may-fixes`). For external, show `~`-shortened absolute path.
- **commit** + **status** on the same line: run `git -C <path> status --porcelain` — count `M` (modified), `A` (added), `D` (deleted), `?` (untracked); show "clean" if empty
- All cards have the same fixed width (match the widest content, minimum 56 chars inside)

---

## `enter <name>`

1. Run `git worktree list --porcelain` to get all worktrees
2. Find a worktree whose path ends with `/<name>` (match is case-insensitive)
3. If not found: tell the user and list available names, then stop
4. Call `EnterWorktree { path: "<resolved-absolute-path>" }`
5. Confirm: "Switched to `<name>` (branch: `<branch>`)"

---

## `new <name> [<branch>]`

**With `<branch>` provided:**
1. Check if branch exists locally or remotely: `git branch -a | grep -F "<branch>"`
2. If not found: tell the user and stop
3. Run `git worktree add .claude/worktrees/<name> <branch>`
4. Call `EnterWorktree { path: "<repo-root>/.claude/worktrees/<name>" }`
5. Confirm: "Created and entered worktree `<name>` on branch `<branch>`"

**Without `<branch>`:**
1. Call `EnterWorktree { name: "<name>" }` — Claude Code creates a new branch from current HEAD
2. Confirm: "Created and entered new worktree `<name>`"

To find `<repo-root>`: run `git rev-parse --show-toplevel`.

---

## `exit [keep|remove]`

**With `keep`:** call `ExitWorktree { action: "keep" }`

**With `remove`:**
1. Check for uncommitted changes: `git status --porcelain`
2. If clean: `ExitWorktree { action: "remove" }`
3. If dirty: warn the user with a summary of changes, then use AskUserQuestion asking whether to discard them
   - If yes: `ExitWorktree { action: "remove", discard_changes: true }`
   - If no: stop, do nothing

**Without argument:**
- Use AskUserQuestion with two options:
  - "Keep worktree on disk" → `ExitWorktree { action: "keep" }`
  - "Remove worktree from disk" → follow `remove` flow above

---

## `remove <name>`

1. Run `git worktree list --porcelain`, find the path for `<name>`
2. If not found: tell the user and list available names, then stop
3. Check for uncommitted changes in that worktree: `git -C <path> status --porcelain`
4. If dirty: warn the user and use AskUserQuestion to confirm removal
5. Run `git worktree remove <path>` (add `--force` flag only after user confirms discarding changes)
6. Confirm: "Removed worktree `<name>`"

Note: if the session is currently inside that worktree, use `ExitWorktree { action: "remove" }` instead of the git command.

---

## `status`

For each worktree from `git worktree list --porcelain`:
1. Run `git -C <path> status --short` (count M/A/D/? per worktree)
2. Run `git -C <path> log --oneline -1` (last commit message + hash)

Display each worktree as a **card** using the same format as the `list` command, but add a **last commit** line:
```
┌─ Worktree: [main] ──────────────────────────── [current] ─┐
│ branch  feature/videochat-e2e-tests                        │
│ path    ~/AndroidStudioProjects/minichat-android           │
│ commit  e1ff8b89   status  dirty (2D 2M 1?)                │
│ last    Fix E2E tests                                       │
└────────────────────────────────────────────────────────────┘

┌─ Worktree: [may-fixes] ────────────────────────────────────┐
│ branch  fix/may-rc-polish                                   │
│ path    .claude/worktrees/may-fixes                         │
│ commit  db97fb5c   status  clean                            │
│ last    Fix alignment                                       │
└────────────────────────────────────────────────────────────┘
```

---

## Error handling

- **Unknown subcommand**: show the argument-hint and a one-line description of each command
- **Worktree not found by name**: list available names from `git worktree list`
- **Branch not found**: print the `git branch -a` output filtered to similar names
- **Already in a worktree when calling `new`**: that is fine — proceed normally
