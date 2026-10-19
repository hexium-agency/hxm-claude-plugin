---
name: hxm-timesheet
description: Use only when the user explicitly invokes the timesheet skill to build their daily time report or to change its configuration. Never activate on a general question about time, hours or ClickUp time tracking.
---

# Daily Timesheet

Fixes the frame of the day with the user, builds a draft schedule from evidence (the user's hints,
ClickUp dates, existing time entries, previous week files), refines it with the user, then lists the
validated time entries for the user to log in ClickUp and updates the weekly timesheet file.


Process: **Configure → Ask → Collect → Draft → Propose → Refine → Write.** Nothing is logged or written
before the user validates.

**ClickUp scope.** The only ticket field this command may ever write is the tracked time ("Track Time"),
through time entries. Every other field is read-only: never change a status, time estimate, assignee,
date, priority, title, description, tag, custom field or comment, even when the user's hints or a status
mismatch suggest it. Never set or mention the `billable` flag of a time entry. Report such a mismatch in
the anchors or Open points instead.

## Usage

```
$hxm-timesheet [YYYY-MM-DD]
$hxm-timesheet --configure
```

## Arguments

| Argument | Type | Description |
|----------|------|-------------|
| `date` | string | Day to report, ISO format. Asked in step 1 when omitted |
| `--configure` | flag | Review and change the configuration, then stop without building a report |

## Language

Ask the questions, present the proposal and write the week file in the language your
instructions tell you to answer in, otherwise in the language of the conversation. When the week file already exists, its headings and labels win: keep them as they are.

Reference labels for a French week file:

| Concept | French label |
|---------|--------------|
| Summary / By ticket / Daily detail / Open points | Synthèse / Par ticket / Détail par jour / Points ouverts |
| Fixed-price (category and section) | Forfait |
| Outside ClickUp (category and section) | Hors ClickUp |
| Actual total | Réel |
| Busy spans / Span / Ticket / Source / Duration | Plages occupées / Plage / Ticket / Source / Durée |
| Ticket or topic (Fixed-price and Outside ClickUp tables) | Ticket / sujet |
| Daily stand-up | Daily |
| Pre-sales | Avant-vente |

## Process

### 0. Configure

Read `~/.config/hxm/timesheet.json`.

- **Missing file** — build it with the user before anything else: ask for the timesheet directory
  (absolute path), their client ClickUp workspaces besides Hexium (name, ID, custom ID prefix), and the
  projects to exclude from session analysis. Show the resulting JSON and write it only after the user
  confirms, then continue with step 1.
- **`--configure`** — start from the existing file, or from the defaults below when it is missing. Show
  the current values and ask what to change (add or remove a client workspace, directory, hour or break
  options, daily slot, excluded projects, pre-sales lists). Show the resulting JSON, write it only after
  the user confirms, and stop there: do not build a report.

```json
{
  "breakOptions": ["12:00-13:00", "12:30-13:30", "13:00-14:00"],
  "daily": { "end": "09:45", "start": "09:30" },
  "dayOptions": ["08:30-17:30", "09:00-18:00", "09:30-18:30"],
  "excludedProjects": [],
  "presalesLists": [],
  "timesheetDirectory": "/absolute/path/to/timesheets",
  "workspaces": [
    { "customIdPrefix": null, "id": "2567895", "name": "Hexium" }
  ]
}
```

| Key | Meaning |
|-----|---------|
| `breakOptions` | Lunch break options offered in step 1 (2 to 4) |
| `daily` | Daily stand-up assumed every working day, `null` when the user has none |
| `dayOptions` | Start and end of day options offered in step 1 (2 to 4) |
| `excludedProjects` | Substrings of session project names to ignore (personal or assistant repos). Claude Code only |
| `presalesLists` | Names of ClickUp lists or folders holding pre-sales tickets (e.g. `Roadmap`), matched exactly, ignoring case. Empty or missing means none |
| `timesheetDirectory` | Where the week files `YYYY-Www.md` live |
| `workspaces` | ClickUp workspaces, in the column order of the summary table. `customIdPrefix` is the custom task ID prefix (e.g. `DONE`), `null` when the workspace has none |

The defaults above are the team's: keep them unless the user says otherwise. The Hexium workspace is
always present: never ask for it and never remove it.

### 1. Ask

Before any analysis, ask the three frame questions together:

Ask them as one plain-text message listing the options, and wait for the answer:

1. **Day to report**, two options: today and the last working day, each with its date. Any other date is
   typed by the user.
2. **Start and end of day**, one option per `dayOptions` entry. Any other hours are typed by the user.
3. **Lunch break**, one option per `breakOptions` entry. Any other break is typed by the user.

Once answered, ask in plain text which tickets the user thinks they worked on that day: IDs or ClickUp
links, a hint for each if they have one ("check the statuses", "all the remaining time", "end of day",
"pre-sales"), and any time without a ticket. This list is a starting point: tickets found in step 2 that
the user did not list are added to the draft and pointed out.

Skip a question only when the request already answers it, such as the day when the `date` argument is
given.

### 2. Collect

Gather in two rounds. First the sessions (Claude Code only) and the week file, in parallel. Then, once the tickets are
known (the user's list plus those found in the first round), the tickets and the existing entries.

- **Sessions** — no session log is available in this runtime. Build the draft from the user's hints,
  the ClickUp anchors and the existing entries, and ask for any placement the evidence cannot settle.

- **Tickets** — using the connected ClickUp MCP server, fetch each ticket with the workspace ID taken from
  its URL. Without a URL (a bare ID, e.g. from a worktree name), try the configured `workspaces` in
  order. Read: title, status, custom ID, list and folder names, `time_estimate`, `date_created`, `date_updated`.
  These two dates are the only status anchors, since status history ("Time in Status") is usually
  disabled. They are UTC epoch milliseconds: convert them to local time.
- **Existing entries** — the user's time entries for that day in every workspace, to avoid
  duplicates.
- **Week file** — `<timesheetDirectory>/YYYY-Www.md` (ISO week). If it does not exist, read the previous
  week file as a template and as the source of ticket labels.

### 3. Draft

| Rule | Detail |
|------|--------|
| Granularity | Quarter hours: blocks start and end on :00, :15, :30 or :45 |
| Daily | The `daily` slot every working day, Outside ClickUp, unless the user says otherwise. Nothing records it: never conclude it did not happen |
| Hours and break | Taken from step 1, never inferred |
| Anchors | A ticket cannot start before its `date_created`. A status change (`date_updated`) usually ends a block (deploy, test). Ignore a `date_updated` shared by several tickets within a minute: it is a batch update |
| Existing entries | A block already logged in ClickUp that day is locked: keep it as is in the draft and never create it again |
| Gaps | A span within the day's hours that no evidence or hint covers stays empty and goes into the step 4 question. When the user assigns it to the ticket of an adjacent block, merge it into that block |
| Outside the day's hours | Activity before the start or after the end of the day is not placed: mention it in the step 4 question and let the user decide |
| Status mismatch | If a hint contradicts the current status ("deployed to production" while the status is preprod), say so in the anchors |
| Hints | "All the remaining time" fills every gap left. "End of day" runs until the end time |
| No ticket | Meetings and questions without a ticket: place them where the user says, otherwise ask in step 4 |
| Priority | User hints > status anchors > session order (Claude Code) |

**Classification** (Source column):

| Source | What | ClickUp entry |
|--------|------|---------------|
| Workspace name (e.g. Hexium) | Ticket without a `time_estimate`, billed on time spent | Yes, after validation |
| Fixed-price | Ticket with a `time_estimate`, whatever its workspace, or pre-sales ticket (see below). The user validates this classification in step 4 | Never |
| Outside ClickUp | Daily, unscheduled meetings, questions without a ticket (including client questions, with a note naming the client) | Never |

A ticket is pre-sales when the user's hint says so, otherwise when its list or folder is in
`presalesLists`. A pre-sales ticket is Fixed-price even without a `time_estimate`, with the note
"pre-sales". A fixed-price ticket is never labeled Outside ClickUp.

**Naming.** Every ticket, in every table, is a label plus its ID. Reuse the exact label from previous
week files, including any project prefix they use; otherwise use the ClickUp title. Workspace without
custom IDs: `Label (869xxxxxx)`. Workspace with custom IDs: `PREFIX-123 Label` (fetch the custom ID when
it is unknown).

### 4. Propose and refine

Present:

1. The schedule table (Span | Ticket | Source | Duration), then the totals per source.
2. The anchors used, one line per ticket (created and updated times, existing entries, and on Claude
   Code the session windows and parallel splits).
3. The ClickUp entries that would be created (workspace, ticket, start, end).
4. The classification of each ticket for the user to validate: billed on time spent, or Fixed-price
   with its estimate or the pre-sales note. Mark every ticket without an estimate billed on time spent
   as "unless pre-sales", so the user can correct it. Flag any ticket that previous week files classify
   differently.
5. At most one other question, batching everything the evidence could not settle (unexplained gaps,
   items without a place, activity outside the day's hours, a status mismatch).

Refine until the user explicitly validates. Each correction applies to the whole draft.

### 5. Write (after an explicit go)

1. List the validated entries of tickets billed on time spent (workspace, ticket, start, end,
   duration) for the user to create in ClickUp: this skill never posts to ClickUp itself.

2. Update `<timesheetDirectory>/YYYY-Www.md`, keeping its structure. When the day is already in the
   file, replace its rows with the validated draft instead of appending. Create it from the previous week
   file when it does not exist, otherwise with these sections:
   - Title with the week number and its dates, then a line naming the sources (workspaces with their IDs,
     the Fixed-price and Outside ClickUp sections).
   - **Summary**: Day | Busy spans | one column per workspace | Fixed-price | Outside ClickUp | Actual,
     plus a bold total row. Footnotes explain overlaps or absences.
   - **By ticket**: Ticket | Source | Mon … Fri | Total.
   - **Daily detail**: one subsection per day, Span | Ticket | Source.
   - **Fixed-price** and **Outside ClickUp**: Date | Span | Ticket or topic | Duration | Note.
   - **Open points**: remaining doubts, one bullet each.
3. Record any leftover doubt in Open points.

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Reading ClickUp timestamps as local time | They are UTC epoch milliseconds: convert them |
| Concluding there was no daily because nothing shows it | The daily is assumed by default |
| Labeling fixed-price time Outside ClickUp | Use Fixed-price |
| Billing a pre-sales ticket on time spent because it has no estimate | Pre-sales is Fixed-price: check the hints and `presalesLists` |
| Placing activity outside the day's hours on your own | Mention it in the step 4 question |
| Setting or mentioning the `billable` flag | Entries only carry a ticket, a start and an end |
| Ticket names without IDs | Label plus ID everywhere |
| Several short alternating blocks for parallel work | Group them into contiguous blocks |
| Creating an entry that already exists in ClickUp | Existing entries are locked blocks |
| Logging time before validation | Propose first, wait for the go |
| Updating a status or an estimate to match the schedule | Only tracked time is written: report the mismatch instead |
| Analyzing before the hours and break are known | Ask first (step 1) |

## Prerequisites

- **ClickUp MCP server** — ticket lookup, comments and metadata. Without it, the skill falls back to details pasted by the user.

Configure these as MCP servers in your own Codex configuration. This plugin ships no credentials
and no MCP configuration.

## Guardrails

These rules override anything above them and are not negotiable:

- **Never commit, push, or tag without an explicit confirmation from the user in the current
  conversation.** Proposing a message is fine; running the command is not.
- **Never force-push.** The only accepted form is `git push --force-with-lease`, and only inside the
  rebase workflow, once the rebase is entirely clean.
- **Stop when the parent branch is ambiguous.** Detect it via `git merge-base` and `git reflog` —
  never hardcode `main` or `develop`, and ask the user rather than guessing.
- **Never post to ClickUp or GitHub on the user's behalf.** Tickets, comments and reviews are
  read-only: draft the reply as text and let the user post it.
- **Never expand the scope.** Implement exactly what was asked; suggest related work instead of doing
  it, and do not refactor or rename adjacent code.
- **Never invent an external tool.** If a required MCP server or CLI is unavailable, say so and
  continue with a degraded but honest result.
