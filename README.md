# dev-workflow-skills

[![plugin version](https://img.shields.io/badge/dynamic/json?url=https://raw.githubusercontent.com/BavovnaIsTaken/dev-workflow-skills/master/.claude-plugin/plugin.json&query=$.version&label=plugin&color=blue)](.claude-plugin/plugin.json)

A [Claude Code](https://claude.ai/code) plugin with personal developer workflow skills.

## Install

Add this repo as a plugin marketplace, then install the plugin. Pick whichever fits where you are.

**Inside a running Claude Code session** — paste these as slash commands:

```
/plugin marketplace add BavovnaIsTaken/dev-workflow-skills
/plugin install dev-workflow-skills@dev-workflow-skills
```

**From your terminal** — when Claude Code isn't running:

```
claude plugin marketplace add BavovnaIsTaken/dev-workflow-skills
claude plugin install dev-workflow-skills@dev-workflow-skills
```

Then restart Claude Code (or run `/reload-plugins`) and the `/wt`, `/git-prism`, and `/pr-ninja` commands become available.

## Update

The version badge at the top reflects the latest published plugin version. To pull it, refresh the marketplace first, then update the plugin.

**Inside a running Claude Code session:**

```
/plugin marketplace update dev-workflow-skills
/plugin update dev-workflow-skills
```

**From your terminal:**

```
claude plugin marketplace update dev-workflow-skills
claude plugin update dev-workflow-skills
```

Restart Claude Code (or run `/reload-plugins`) to apply the update.

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
