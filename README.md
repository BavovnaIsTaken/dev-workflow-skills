# dev-workflow-skills

A [Claude Code](https://claude.ai/code) plugin with personal developer workflow skills.

## Install

```
/plugins add https://github.com/BavovnaIsTaken/dev-workflow-skills
```

## Skills

| Skill | Command | Description |
|-------|---------|-------------|
| **wt** | `/wt [list\|new\|enter\|exit\|remove\|status]` | Manage git worktrees interactively or via subcommands |
| **git-prism** | `/git-prism` | Split uncommitted changes into logical commits on proper branches, push and open PRs |
| **pr-ninja** | `/pr-ninja` | PR workflow agent — review, respond to comments, or audit merge-readiness |

## Usage example

```
/wt new my-feature        # create a worktree for a new branch
/wt list                  # see all active worktrees
/git-prism                # auto-split staged mess into clean commits
/pr-ninja                 # review or respond to a PR
```
