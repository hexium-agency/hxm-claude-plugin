---
description: Build the daily time report from sessions and ClickUp, log the validated time entries, and update the weekly timesheet file
argument-hint: [YYYY-MM-DD]
allowed-tools: [Read, Write, Edit, Glob, AskUserQuestion, Bash(python3 ${CLAUDE_PLUGIN_ROOT}/helpers/timesheet/session-activity.py:*), mcp__clickup]
model: opus
disable-model-invocation: true
---

# Daily Timesheet

Fixes the frame of the day with the user, builds a draft schedule from evidence (agent sessions, ClickUp
dates, existing time entries, previous week files), refines it with the user, then logs the validated
time entries and updates the weekly timesheet file.

Process: **Configure → Ask → Collect → Draft → Propose → Refine → Write.** Nothing is logged or written
before the user validates.

## Usage

```
/hxm:timesheet [YYYY-MM-DD]
```

## Arguments

| Argument | Type | Description |
|----------|------|-------------|
| `date` | string | Day to report, ISO format. Defaults to today |

## Language

Ask the questions, present the proposal and write the week file in the language the session is
configured to answer in (e.g. Claude Code's `language` setting), otherwise in the language of the
conversation. When the week file already exists, its headings and labels win: keep them as they are.

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

## Process

### 0. Configure

Read `~/.config/hxm/timesheet.json`. If it does not exist, build it with the user before anything else:
ask for the timesheet directory (absolute path), their client ClickUp workspaces (name, ID, billing,
custom ID prefix), and the projects to exclude from session analysis. Show the resulting JSON and write
it only after the user confirms.

```json
{
  "breakOptions": ["12:00-13:00", "12:30-13:30", "13:00-14:00"],
  "daily": { "end": "09:45", "start": "09:30" },
  "dayOptions": ["08:30-17:30", "09:00-18:00", "09:30-18:30"],
  "excludedProjects": [],
  "timesheetDirectory": "/absolute/path/to/timesheets",
  "workspaces": [
    { "billing": "time", "customIdPrefix": null, "id": "2567895", "name": "Hexium" }
  ]
}
```

| Key | Meaning |
|-----|---------|
| `breakOptions` | Lunch break options offered in step 1 (2 to 4) |
| `daily` | Daily stand-up assumed every working day, `null` when the user has none |
| `dayOptions` | Start and end of day options offered in step 1 (2 to 4) |
| `excludedProjects` | Substrings of session project names to ignore (personal or assistant repos) |
| `timesheetDirectory` | Where the week files `YYYY-Www.md` live |
| `workspaces` | ClickUp workspaces, in the column order of the summary table. `billing` is `time` (entries are logged) or `fixed` (always Fixed-price). `customIdPrefix` is the custom task ID prefix (e.g. `DONE`), `null` when the workspace has none |

The defaults above are the team's: keep them unless the user says otherwise. The Hexium workspace is
always present.

### 1. Ask

Before any analysis, ask the two frame questions together:

Use one `AskUserQuestion` call with two questions:

1. **Start and end of day**, one option per `dayOptions` entry. Any other hours are typed by the user.
2. **Lunch break**, one option per `breakOptions` entry. Any other break is typed by the user.

Once answered, ask in plain text which tickets the user thinks they worked on that day: IDs or ClickUp
links, a hint for each if they have one ("check the statuses", "all the remaining time", "end of day"),
and any time without a ticket. This list is a starting point: sessions found in step 2 for other tickets
are added to the draft and pointed out.

Skip a question only when the request already answers it. The day is today unless the user names
another one.

### 2. Collect

Gather these in parallel:

- **Sessions** — run the bundled helper, adding one `--exclude <project>` per `excludedProjects` entry:

  ```bash
  python3 ${CLAUDE_PLUGIN_ROOT}/helpers/timesheet/session-activity.py YYYY-MM-DD --exclude-session ${CLAUDE_SESSION_ID}
  ```

  It prints, per Claude Code session, the activity windows in local time (session logs are UTC, the
  helper converts them), with event and prompt counts and the ticket ID when it can be detected
  (worktree `cu-<id>`, session name, ClickUp URL in a prompt). Add `--prompts` to see what was asked and
  when. A window with 0 prompts and few events (compaction, background task) is not activity.

- **Tickets** — using the connected ClickUp MCP server, fetch each ticket with the workspace ID taken from
  its URL or from `workspaces`: title, status, custom ID, `time_estimate`, `date_created`, `date_updated`.
  These two dates are the only status anchors, since status history ("Time in Status") is usually
  disabled. They are UTC epoch milliseconds: convert them to local time.
- **Existing entries** — the user's time entries for that day in every `time` workspace, to avoid
  duplicates.
- **Week file** — `<timesheetDirectory>/YYYY-Www.md` (ISO week). If it does not exist, read the previous
  week file as a template and as the source of ticket labels.

### 3. Draft

| Rule | Detail |
|------|--------|
| Granularity | Quarter hours: blocks start and end on :00, :15, :30 or :45 |
| Daily | The `daily` slot every working day, Outside ClickUp, unless the user says otherwise. It never appears in sessions: never conclude it did not happen |
| Hours and break | Taken from step 1, never inferred |
| Anchors | A ticket cannot start before its `date_created`. A status change (`date_updated`) usually ends a block (deploy, test). Ignore a `date_updated` later than the ticket's last session, or shared by several tickets within a minute: it is a batch update |
| Background windows | A window with 0 prompts and few events is not activity |
| Status mismatch | If a hint contradicts the current status ("deployed to production" while the status is preprod), say so in the anchors |
| Hints | "All the remaining time" fills every gap left. "End of day" runs until the end time |
| No session | Meetings and questions without a ticket: place them where the user says, otherwise ask |
| Priority | User hints > status anchors > session order |

**Parallel work.** When sessions of two or more tickets interleave within one span, do not reproduce the
interleaving. Take the whole span and give each ticket `span × ticket events / all events in the span`,
rounded to the quarter hour (15 min minimum). Shift a quarter hour between tickets only when one is
clearly harder (more prompts, debugging, deploy). Emit one contiguous block per ticket, ordered by first
activity unless a user hint places a ticket. State the split and the counts in the anchors.

**Classification** (Source column):

| Source | What | ClickUp entry |
|--------|------|---------------|
| Workspace name (e.g. Hexium) | Ticket in a `time` workspace, billed on time spent | Yes, after validation |
| Fixed-price | Ticket with a `time_estimate`, or any ticket of a `fixed` workspace. Confirm with previous week files and ask if they disagree | Never |
| Outside ClickUp | Daily, unscheduled meetings, questions without a ticket (including client questions, with a note naming the client) | Never |

A fixed-price ticket is never labeled Outside ClickUp.

**Naming.** Every ticket, in every table, is a label plus its ID. Reuse the exact label from previous
week files, including any project prefix they use; otherwise use the ClickUp title. Workspace without
custom IDs: `Label (869xxxxxx)`. Workspace with custom IDs: `PREFIX-123 Label` (fetch the custom ID when
it is unknown).

### 4. Propose and refine

Present:

1. The schedule table (Span | Ticket | Source | Duration), then the totals per source.
2. The anchors used, one line per ticket (session windows, created and updated times, parallel splits).
3. The ClickUp entries that would be created (workspace, ticket, start, end).
4. At most one question, for what the evidence could not settle (a ticket without a session, a status
   mismatch).

Refine until the user explicitly validates. Each correction applies to the whole draft.

### 5. Write (after an explicit go)

1. Using the ClickUp MCP server, create one time entry per validated block of a `time` workspace, with
   its start and end times. Never for Fixed-price or Outside ClickUp blocks.

2. Update `<timesheetDirectory>/YYYY-Www.md`, keeping its structure. Create it from the previous week
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
| Reading session or ClickUp timestamps as local time | Both are UTC: the helper converts sessions, convert ClickUp dates yourself |
| Concluding there was no daily because no session shows it | The daily is assumed by default |
| Labeling fixed-price time Outside ClickUp | Use Fixed-price |
| Ticket names without IDs | Label plus ID everywhere |
| Several short alternating blocks for parallel work | Group them into contiguous blocks |
| Logging time before validation | Propose first, wait for the go |
| Analyzing before the hours and break are known | Ask first (step 1) |
