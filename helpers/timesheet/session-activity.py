#!/usr/bin/env python3
"""List Claude Code activity windows for one day, per session, in local time.

Usage: python3 session-activity.py YYYY-MM-DD [--exclude PROJECT ...] [--exclude-session ID] [--gap MINUTES] [--prompts]
"""
import argparse
import datetime as dt
import json
import re
from pathlib import Path

PROJECTS = Path.home() / ".claude" / "projects"
PROJECT_PREFIX = re.sub(r"[^A-Za-z0-9]", "-", str(Path.home())) + "-"
TICKET = re.compile(r"cu-([0-9a-z]{9})")
TICKET_URL = re.compile(r"app\.clickup\.com/t/(?:\d+/)?([0-9a-zA-Z-]+)")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("date")
    parser.add_argument("--exclude", action="append", default=[])
    parser.add_argument("--exclude-session")
    parser.add_argument("--gap", type=int, default=15)
    parser.add_argument("--prompts", action="store_true")
    args = parser.parse_args()

    day = dt.date.fromisoformat(args.date)
    rows = []
    for path in PROJECTS.glob("*/*.jsonl"):
        project = path.parent.name
        if any(e in project for e in args.exclude):
            continue
        if args.exclude_session and path.stem == args.exclude_session:
            continue
        events, prompts, name, linked = read_session(path, day)
        if not events:
            continue
        ticket = ticket_id(project, name) or ",".join(sorted(linked)) or None
        rows.append((events[0], project, path.stem[:8], name, ticket, bursts(events, prompts, args.gap), prompts))

    for first, project, sid, name, ticket, windows, prompts in sorted(rows):
        label = project.removeprefix(PROJECT_PREFIX)
        print(f"{label} [{sid}]" + (f" name={name}" if name else "") + (f" ticket={ticket}" if ticket else ""))
        print("  windows: " + ", ".join(f"{a:%H:%M}-{b:%H:%M} ({n} events, {p} prompts)" for a, b, n, p in windows))
        print(f"  user prompts: {len(prompts)}")
        if args.prompts:
            for at, text in prompts:
                print(f"    {at:%H:%M} {text}")


def bursts(events, prompts, gap_minutes):
    windows = [[events[0], events[0], 1, 0]]
    for at in events[1:]:
        if (at - windows[-1][1]).total_seconds() > gap_minutes * 60:
            windows.append([at, at, 1, 0])
        else:
            windows[-1][1] = at
            windows[-1][2] += 1
    for at, _ in prompts:
        for window in windows:
            if window[0] <= at <= window[1]:
                window[3] += 1
    return windows


def prompt_text(content):
    if not isinstance(content, str):
        return None
    if content.startswith(("<local-command", "<bash-", "<task-notification", "<system-reminder", "[Cross-session")):
        return None
    if content.startswith(("Another Claude session", "<artifact-content-authored-by-others")):
        return None
    command = re.search(r"<command-name>(/[^<]+)</command-name>", content)
    if command:
        return command.group(1)
    return " ".join(content.split())[:100]


def read_session(path, day):
    events, prompts, name, linked = [], [], None, set()
    with path.open() as handle:
        for line in handle:
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue
            content = (entry.get("message") or {}).get("content")
            if entry.get("type") == "user" and isinstance(content, str):
                linked.update(TICKET_URL.findall(content))
            if isinstance(content, str) and "The user named this session" in content:
                found = re.search(r'named this session "([^"]+)"', content)
                name = found.group(1) if found else name
            stamp = entry.get("timestamp")
            if not stamp:
                continue
            at = dt.datetime.fromisoformat(stamp.replace("Z", "+00:00")).astimezone()
            if at.date() != day:
                continue
            events.append(at)
            if entry.get("type") == "user":
                text = prompt_text(content)
                if text:
                    prompts.append((at, text))
    events.sort()
    return events, prompts, name, linked


def ticket_id(project, name):
    found = TICKET.search(project) or (TICKET.search(f"cu-{name}") if name else None)
    return found.group(1) if found else None


if __name__ == "__main__":
    main()
