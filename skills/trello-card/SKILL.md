---
name: trello-card
description: Turn a Trello card into ready-to-work context — fetch the card by short number, URL, or name; pull description, checklists/acceptance criteria, comments, and attachments (with the large-attachment curl fallback); then map the task onto the current codebase and propose an approach. Use when the user references a Trello card ("Trello 254", a trello.com URL, "картка 255") or invokes /trello-card <number|url|search-term>.
---

# /trello-card — card → working context

Turn one Trello card into a compact task brief: what is asked, what "done"
means, what the designers/PM said in comments, the attached references saved
locally, and where in this codebase the work lands.

## 1. Resolve the card

The argument is a short number (`254`), a trello.com URL, or a search phrase.

Prefer the Trello MCP tools (`mcp__trello__*`) when available:
- URL → extract the card id/shortLink from it, `get_card`.
- Number → the board's card `idShort`. Find the active board
  (`get_active_board_info`; if wrong board, `list_boards` + `set_active_board`),
  then walk `get_lists` → `get_cards_by_list_id` and match `idShort`.
- Phrase → same walk, match on card name.

**REST fallback** (no MCP, or MCP lacks the call): credentials live in
`~/.claude.json` under `mcpServers.trello.env` (`TRELLO_API_KEY`,
`TRELLO_TOKEN`). Extract with python/jq — never print them. Then:

```
https://api.trello.com/1/boards/{boardId}/cards/{idShort}?key=…&token=…
https://api.trello.com/1/cards/{id}?fields=all&attachments=true&checklists=all&actions=commentCard&key=…&token=…
```

## 2. Pull the full card

Collect, tolerating partial failures (report what's missing, keep going):

- **Description** — the task text.
- **Checklists** — acceptance criteria (`get_acceptance_criteria` /
  `get_checklist_items`, or `checklists=all` via REST).
- **Comments** — `get_card_comments`; comments often carry the REAL spec
  (designer corrections, PM decisions) that supersedes the description.
  Read newest-last and note contradictions with the description.
- **Attachments** — list them; download images and small files to the session
  scratchpad dir (or `/tmp/trello-<idShort>/`) and READ the images.

**Large-attachment gotcha (videos, big exports):** downloading through MCP
returns base64 through the model (~200k tokens for a video) — never do that.
Use curl with the OAuth header instead (Trello ignores key/token query params
on `trello.com/1/cards/...` attachment download URLs):

```bash
curl -sL -H 'Authorization: OAuth oauth_consumer_key="'$KEY'", oauth_token="'$TOKEN'"' \
  -o /tmp/trello-<idShort>/<name> '<attachment url>'
```

For videos: download, then sample frames (`ffmpeg -i in.mp4 -vf fps=1 f%03d.png`)
and read the frames — do not try to attach the video itself to context.

## 3. Map onto the codebase

From the card's nouns (screen names, component names, feature words — in any
language), locate the relevant code: grep for view/layout/class names, check
recent git history for the same area. If the project keeps Claude memory
(`~/.claude/projects/$(pwd | tr '/' '-')/memory/MEMORY.md`), scan its index for
entries about the same feature — earlier cards often touched the same spot and
the traps are documented there.

## 4. Deliver the brief

One compact report, no raw JSON dumps:

- **Card**: number, title, list/column, link, assignees, due date if any.
- **Task**: 2–4 sentences, description reconciled with the comment thread
  (call out where comments overrode the description).
- **Acceptance criteria**: the checklist, verbatim, with done/undone state.
- **References**: local paths of downloaded attachments, one line each on what
  the image/video shows.
- **Code landing zone**: files/classes this touches, relevant memory entries,
  and a 3–6 step proposed approach.

Stop after the brief — implementing is a separate decision for the user, unless
they asked for implementation in the same message.
