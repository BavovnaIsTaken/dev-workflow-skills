---
name: git-prism
description: Analyze uncommitted changes and split them into logical commits on appropriate git-flow topic branches, then push and surface PRs.
---

Analyze uncommitted changes and the branch tree, split changes into logical commits on appropriate topic branches per git-flow, then push topic branches (never `develop`/`master`/`main`) and surface PRs.

## Git-flow model

- `master` (or `main`) — releases only. Never commit or push to it directly.
- `develop` — integration branch for the next release. Merges in **only via reviewed PR**. A PR into `develop` must have at least one approval, and every review comment must be resolved (addressed in code, or explicitly declined with a strong argument) before merge.
- `feature/<scope>`, `fix/<scope>`, `refactor/<scope>`, `perf/<scope>`, `chore/<scope>`, `docs/<scope>`, `test/<scope>` — topic branches. Always cut from `develop` (or its closest equivalent if the repo uses a different name).

## WIP limit on topic branches

An **active topic branch** = a topic branch with commits ahead of `develop` that has not yet been merged (local or remote).

- **≤2 active** → normal flow, no extra noise.
- **≥3 active** → at the start AND end of the run, list every open PR with status (approvals, unresolved comments, CI). Remind the user to move them toward merge.
- **≥5 active** → **hard cap**. Do not create a new topic branch. Stop, surface every active branch with the specific next action required (respond to comments / request review / rebase / merge), and ask the user to land or abandon work before opening more. Repeat this reminder loudly in both the opening status and the final summary.

When the cap blocks new work, if the uncommitted changes legitimately belong to an existing active topic branch — route them there instead of refusing outright.

## Steps

1. **Capture state.** In parallel:
   - `git status` and `git diff HEAD` (+ `git ls-files --others --exclude-standard` for untracked) — what changed
   - `git branch --show-current` — where we are
   - `git branch -a` and `git log --oneline --graph --decorate --all -20` — branch landscape and recent commit style
   - Detect long-lived branches: confirm `master`/`main` and `develop` exist. If `develop` is missing, stop and ask the user how they want to proceed — do not silently invent it.
   - **Count active topic branches** (commits ahead of `develop`, not merged). Apply the WIP-limit policy from above. If the count is already ≥3, fetch open-PR status now (`gh pr list --state open --json number,title,headRefName,reviewDecision,isDraft,mergeStateStatus`) so the opening status message can include it.

2. **Group uncommitted changes into logical units** using these criteria:
   - Feature vs. bugfix vs. refactor vs. perf vs. test vs. docs vs. chore — keep separate
   - Same domain/module + tightly coupled → same group
   - Tests for a feature go in the same commit as the feature code (or immediately after, clearly labeled)
   - Infrastructure/config changes go in their own group

3. **Map each group to a topic branch.** Branch name: `<type>/<short-kebab-scope>`.
   - If the current branch is already a topic branch and **all** groups belong there — reuse it.
   - If the current branch is `develop` / `master` / `main` — do not commit there. For each group, create a topic branch from `develop` (`git checkout -b <type>/<scope> develop`) before staging. Uncommitted changes follow automatically; for groups that need to move separately, use `git stash push -- <paths>` and pop on the target branch.
   - If groups belong to different topic branches — create one branch per group, route each group there.
   - Before creating a new branch, check `git branch -a` for an existing branch that already fits (open feature work in progress) and prefer reusing it.
   - **Enforce the WIP cap.** Before creating any new topic branch, compute `active_after = current_active_count + new_branches_to_create`. If `active_after > 5`, stop creating new branches. Try to route the remaining groups onto existing active branches if a reasonable fit exists; otherwise report the conflict and ask the user to land/abandon work first.

4. **Commit each group on its target branch.**
   - `git add` only the specific files / hunks for that group — never `git add .` / `git add -A`
   - Conventional commit subject: `<type>(<scope>): <description>` matching the repo's existing style (`git log --oneline -10`)
   - Append `Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>` to every commit message
   - On pre-commit hook failure: fix the underlying cause and create a **new** commit. Do not `--amend`. Do not `--no-verify`.

5. **Push topic branches.** For each topic branch touched:
   - `git push -u origin <topic-branch>`
   - **Never** push to `develop` / `master` / `main`.
   - After push, check whether a PR exists (`gh pr list --head <branch>`):
     - If yes — print the URL (`gh pr view <branch> --json url -q .url`)
     - If no — propose title and body to the user (do not create silently). On confirmation: `gh pr create --base develop --head <branch>` (omit `--draft` unless the user asks).
   - Remind the user: PR into `develop` requires ≥1 approval and all comments resolved before merge.

6. **Audit the branch tree** and surface drift (report only — do not rewrite shared history):
   - Topic branches already merged into `develop` → suggest local deletion (`git branch -d`)
   - Topic branches significantly behind `develop` → suggest rebase
   - Direct commits on `develop` / `master` / `main` that did not arrive via a merge commit from a PR → flag as policy violations, list them, ask the user how to handle
   - Topic branches with no activity for a long stretch → list them as candidates for cleanup, do not delete
   - Branches not matching the `<type>/<scope>` naming → list, suggest rename

7. **Final summary.** Print:
   - `git log --oneline --graph --decorate --all -20`
   - A table: branch → commits added → push status → PR status (URL or "to create")
   - **WIP status line**: `Active topic branches: N/5`. If `N ≥ 3`, append a list of open PRs with required next action per PR (e.g. "needs review", "respond to N unresolved comments", "rebase on develop", "ready to merge"). If `N ≥ 5`, prefix with a loud warning that no new topic branches will be opened until the count drops.
   - Any tree-audit findings from step 6

## Rules

- Never `git add .` or `git add -A` — always specific paths to avoid committing secrets or unrelated files.
- Never `--no-verify`. On hook failure, fix the cause and re-commit.
- Never push directly to `develop`, `master`, or `main`. Integration happens only via PR.
- Never force-push a shared branch (`develop`/`master`/`main`). Do not force-push a topic branch without warning the user first and getting explicit confirmation.
- Never merge a PR yourself — humans approve and merge.
- Do not silently rewrite history that violates the model. Surface findings and let the user decide.
- Respect the WIP cap: never grow active topic branches beyond 5. At ≥3, always surface PR statuses; at ≥5, refuse new branches and ask the user to land work first.
- Keep commit messages in the same language/style as recent commits (`git log --oneline -10`).
- If there is nothing to commit **and** the tree audit is clean, say so and stop.
