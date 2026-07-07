#!/usr/bin/env python3
"""Validate song folders and chart data for the Godot project."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


VALID_NOTE_TYPES = {"normal", "moving", "hold"}
VALID_EVENT_TYPES = {
    "window",
    "window_moving_linear",
    "window_moving_smooth",
    "image",
    "image_moving_linear",
    "image_moving_smooth",
}


class Reporter:
    def __init__(self) -> None:
        self.errors: list[str] = []
        self.warnings: list[str] = []

    def error(self, message: str) -> None:
        self.errors.append(message)

    def warning(self, message: str) -> None:
        self.warnings.append(message)

    def print(self) -> None:
        for warning in self.warnings:
            print(f"WARNING: {warning}")
        for error in self.errors:
            print(f"ERROR: {error}")


def is_number(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def check_number(
    reporter: Reporter,
    where: str,
    data: dict[str, Any],
    key: str,
    *,
    required: bool = False,
    minimum: float | None = None,
) -> None:
    if key not in data:
        if required:
            reporter.error(f"{where}: missing required field '{key}'")
        return
    value = data[key]
    if not is_number(value):
        reporter.error(f"{where}: field '{key}' must be a number")
        return
    if minimum is not None and float(value) < minimum:
        reporter.error(f"{where}: field '{key}' must be >= {minimum}")


def validate_note(reporter: Reporter, song_name: str, index: int, note: Any) -> None:
    where = f"{song_name} chart note[{index}]"
    if not isinstance(note, dict):
        reporter.error(f"{where}: note must be an object")
        return

    note_type = str(note.get("type", "normal"))
    if note_type not in VALID_NOTE_TYPES:
        reporter.error(f"{where}: unknown type '{note_type}'")

    check_number(reporter, where, note, "time", required=True, minimum=0.0)

    if note_type in {"normal", "moving"}:
        check_number(reporter, where, note, "x", required=True)
        check_number(reporter, where, note, "y", required=True)

    if note_type == "moving":
        check_number(reporter, where, note, "move_duration", minimum=0.01)
        if "start_x" in note or "start_y" in note:
            check_number(reporter, where, note, "start_x", required=True)
            check_number(reporter, where, note, "start_y", required=True)
        if "curve_control_x" in note or "curve_control_y" in note:
            check_number(reporter, where, note, "curve_control_x", required=True)
            check_number(reporter, where, note, "curve_control_y", required=True)

    if note_type == "hold":
        check_number(reporter, where, note, "duration", minimum=0.01)
        if "beat_division" in note:
            check_number(reporter, where, note, "beat_division", minimum=1.0)


def validate_event(reporter: Reporter, song_name: str, index: int, event: Any) -> None:
    where = f"{song_name} chart event[{index}]"
    if not isinstance(event, dict):
        reporter.error(f"{where}: event must be an object")
        return

    event_type = str(event.get("type", ""))
    if event_type not in VALID_EVENT_TYPES:
        reporter.error(f"{where}: unknown type '{event_type}'")

    for key in ("time", "x", "y"):
        check_number(reporter, where, event, key, required=True, minimum=0.0 if key == "time" else None)
    for key in ("width", "height", "duration"):
        check_number(reporter, where, event, key, minimum=0.01)
    if "opacity" in event:
        check_number(reporter, where, event, "opacity", minimum=0.0)


def validate_song_folder(reporter: Reporter, song_dir: Path) -> None:
    song_name = song_dir.name
    required_files = [
        song_dir / "chart.json",
        song_dir / "Res.tres",
        song_dir / "img.png",
        song_dir / f"{song_name}.mp3",
    ]

    for path in required_files:
        if not path.exists():
            reporter.error(f"{song_name}: missing {path.name}")

    chart_path = song_dir / "chart.json"
    if not chart_path.exists():
        return

    try:
        chart = json.loads(chart_path.read_text(encoding="utf-8-sig"))
    except UnicodeDecodeError as exc:
        reporter.error(f"{song_name}: chart.json is not valid UTF-8 ({exc})")
        return
    except json.JSONDecodeError as exc:
        reporter.error(f"{song_name}: chart.json parse failed at line {exc.lineno}, column {exc.colno}: {exc.msg}")
        return

    if not isinstance(chart, dict):
        reporter.error(f"{song_name}: chart root must be an object")
        return

    notes = chart.get("notes", [])
    events = chart.get("events", [])
    if not isinstance(notes, list):
        reporter.error(f"{song_name}: 'notes' must be an array")
        notes = []
    if not isinstance(events, list):
        reporter.error(f"{song_name}: 'events' must be an array")
        events = []

    for index, note in enumerate(notes):
        validate_note(reporter, song_name, index, note)
    for index, event in enumerate(events):
        validate_event(reporter, song_name, index, event)


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate Godot song resources and chart JSON files.")
    parser.add_argument(
        "--project",
        type=Path,
        default=Path("window") / "window-gun",
        help="Path to the Godot project directory.",
    )
    args = parser.parse_args()

    project_dir = args.project
    music_dir = project_dir / "assets" / "musics"
    reporter = Reporter()

    if not project_dir.exists():
        reporter.error(f"Project directory not found: {project_dir}")
    elif not music_dir.exists():
        reporter.error(f"Music directory not found: {music_dir}")
    else:
        song_dirs = sorted(path for path in music_dir.iterdir() if path.is_dir())
        if not song_dirs:
            reporter.warning(f"No song folders found in {music_dir}")
        for song_dir in song_dirs:
            validate_song_folder(reporter, song_dir)

    reporter.print()
    if reporter.errors:
        print(f"Validation failed: {len(reporter.errors)} error(s), {len(reporter.warnings)} warning(s).")
        return 1

    print(f"Validation passed: {len(reporter.warnings)} warning(s).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
