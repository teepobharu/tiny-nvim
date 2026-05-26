#!/usr/bin/env python3
"""Watch an agent-flow session folder and update its receiver end.

This is a dependency-free polling watcher. It is intentionally simple so it can
run in local project folders without fswatch/watchman.
"""

from __future__ import annotations

import argparse
import fnmatch
import hashlib
import json
import sys
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, Iterable, List, Optional

DEFAULT_EXCLUDES = [
    ".git/**",
    "**/.DS_Store",
    "receiver/status.md",
    "receiver/events.jsonl",
    "receiver/.agent-flow-watch-state.json",
]

TEXT_STATUS_EXTS = {".md", ".txt", ".json", ".yaml", ".yml"}


@dataclass
class FileState:
    size: int
    mtime_ns: int
    sha256: str

    def to_json(self) -> dict:
        return {"size": self.size, "mtime_ns": self.mtime_ns, "sha256": self.sha256}

    @classmethod
    def from_json(cls, raw: dict) -> "FileState":
        return cls(size=int(raw["size"]), mtime_ns=int(raw["mtime_ns"]), sha256=str(raw["sha256"]))


def now_iso() -> str:
    return datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")


def rel(path: Path, root: Path) -> str:
    return path.relative_to(root).as_posix()


def matches_any(value: str, patterns: Iterable[str]) -> bool:
    return any(fnmatch.fnmatch(value, pattern) for pattern in patterns)


def iter_watch_files(root: Path, includes: List[str], excludes: List[str]) -> Iterable[Path]:
    for path in sorted(root.rglob("*")):
        if not path.is_file():
            continue
        relative = rel(path, root)
        if matches_any(relative, excludes):
            continue
        if includes and not matches_any(relative, includes):
            continue
        yield path


def hash_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def snapshot(root: Path, includes: List[str], excludes: List[str]) -> Dict[str, FileState]:
    result: Dict[str, FileState] = {}
    for path in iter_watch_files(root, includes, excludes):
        stat = path.stat()
        result[rel(path, root)] = FileState(size=stat.st_size, mtime_ns=stat.st_mtime_ns, sha256=hash_file(path))
    return result


def load_state(path: Path) -> Dict[str, FileState]:
    if not path.exists():
        return {}
    try:
        raw = json.loads(path.read_text())
        return {name: FileState.from_json(value) for name, value in raw.items()}
    except Exception:
        return {}


def save_state(path: Path, state: Dict[str, FileState]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps({name: item.to_json() for name, item in state.items()}, indent=2, sort_keys=True) + "\n")


def detect_events(old: Dict[str, FileState], new: Dict[str, FileState]) -> List[dict]:
    events: List[dict] = []
    old_names = set(old)
    new_names = set(new)

    for name in sorted(new_names - old_names):
        events.append({"type": "created", "path": name})
    for name in sorted(old_names - new_names):
        events.append({"type": "deleted", "path": name})
    for name in sorted(old_names & new_names):
        if old[name].sha256 != new[name].sha256:
            events.append({"type": "modified", "path": name})
    return events


def append_events(events_path: Path, events: List[dict]) -> None:
    events_path.parent.mkdir(parents=True, exist_ok=True)
    with events_path.open("a", encoding="utf-8") as handle:
        for event in events:
            enriched = {"time": now_iso(), **event}
            handle.write(json.dumps(enriched, sort_keys=True) + "\n")


def read_recent_events(events_path: Path, limit: int = 12) -> List[dict]:
    if not events_path.exists():
        return []
    lines = events_path.read_text(encoding="utf-8", errors="replace").splitlines()
    events = []
    for line in lines[-limit:]:
        try:
            events.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return events


def parse_frontmatter_status(path: Path) -> Optional[dict]:
    if path.suffix.lower() not in TEXT_STATUS_EXTS:
        return None
    try:
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    except Exception:
        return None
    if not lines or lines[0].strip() != "---":
        return None

    data = {}
    for line in lines[1:]:
        if line.strip() == "---":
            break
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if key in {"status", "role", "from", "to", "updated", "box"}:
            data[key] = value
    return data or None


def collect_statuses(root: Path, state: Dict[str, FileState]) -> List[tuple[str, dict]]:
    statuses: List[tuple[str, dict]] = []
    interesting_prefixes = ("source-note.md", "tasks.md", "agents/", "handoffs/", "iterations/", "jobs/", "README.md")
    for name in sorted(state):
        if not name.startswith(interesting_prefixes):
            continue
        parsed = parse_frontmatter_status(root / name)
        if parsed:
            statuses.append((name, parsed))
    return statuses


def render_receiver_status(root: Path, receiver_status: Path, events_path: Path, state: Dict[str, FileState]) -> None:
    recent_events = read_recent_events(events_path)
    statuses = collect_statuses(root, state)
    latest_event = recent_events[-1] if recent_events else None

    lines = [
        "---",
        "role: receiver",
        f"status: {'changed' if latest_event else 'watching'}",
        f"updated: {now_iso()}",
        "---",
        "",
        "# Receiver Status",
        "",
        f"Session: `{root.as_posix()}`",
        f"Watched files: {len(state)}",
        "",
        "## Latest event",
        "",
    ]

    if latest_event:
        lines.append(f"- `{latest_event.get('time')}` — **{latest_event.get('type')}** `{latest_event.get('path')}`")
    else:
        lines.append("- No events recorded yet.")

    lines.extend(["", "## Recent events", ""])
    if recent_events:
        for event in reversed(recent_events):
            lines.append(f"- `{event.get('time')}` — **{event.get('type')}** `{event.get('path')}`")
    else:
        lines.append("- No events recorded yet.")

    lines.extend(["", "## File statuses", ""])
    if statuses:
        lines.append("| File | Role | Box | From → To | Status | Updated |")
        lines.append("| --- | --- | --- | --- | --- | --- |")
        for name, data in statuses:
            role = data.get("role", "")
            box = data.get("box", "")
            route = ""
            if data.get("from") or data.get("to"):
                route = f"{data.get('from', '')} → {data.get('to', '')}"
            status = data.get("status", "")
            updated = data.get("updated", "")
            lines.append(f"| `{name}` | {role} | {box} | {route} | {status} | {updated} |")
    else:
        lines.append("No frontmatter statuses found yet.")

    lines.extend([
        "",
        "## Next action",
        "",
        "Check the latest role/handoff with a non-final status (`draft`, `ready`, `accepted`, `blocked`, `needs-changes`).",
        "",
        "_Generated by `scripts/agent-flow-watch.py`._",
        "",
    ])

    receiver_status.parent.mkdir(parents=True, exist_ok=True)
    receiver_status.write_text("\n".join(lines), encoding="utf-8")


def run_once(root: Path, includes: List[str], excludes: List[str], quiet: bool) -> int:
    receiver = root / "receiver"
    state_path = receiver / ".agent-flow-watch-state.json"
    events_path = receiver / "events.jsonl"
    status_path = receiver / "status.md"

    old = load_state(state_path)
    new = snapshot(root, includes, excludes)
    events = detect_events(old, new)

    if not old and not events_path.exists():
        events = [{"type": "watch-started", "path": "."}, *events]

    if events:
        append_events(events_path, events)
        if not quiet:
            for event in events:
                print(f"{now_iso()} {event['type']:>13} {event['path']}")

    render_receiver_status(root, status_path, events_path, new)
    save_state(state_path, new)
    return len(events)


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Watch an agent-flow session and update receiver/status.md")
    parser.add_argument("session_dir", help="Path to an agent-flow session folder")
    parser.add_argument("--interval", type=float, default=2.0, help="Polling interval in seconds (default: 2)")
    parser.add_argument("--once", action="store_true", help="Scan once, update receiver, and exit")
    parser.add_argument("--include", action="append", default=[], help="fnmatch pattern to include; defaults to all files")
    parser.add_argument("--exclude", action="append", default=[], help="fnmatch pattern to exclude")
    parser.add_argument("--quiet", action="store_true", help="Do not print change events to stdout")
    args = parser.parse_args(argv)

    root = Path(args.session_dir).expanduser().resolve()
    if not root.exists() or not root.is_dir():
        print(f"Session directory does not exist: {root}", file=sys.stderr)
        return 2

    excludes = [*DEFAULT_EXCLUDES, *args.exclude]
    includes = args.include

    try:
        while True:
            run_once(root, includes, excludes, args.quiet)
            if args.once:
                return 0
            time.sleep(args.interval)
    except KeyboardInterrupt:
        if not args.quiet:
            print("Stopped watcher.")
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
