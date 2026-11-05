"""Validate authored runtime JSON independently of the Godot registry.

Run from any directory: python scripts/validate_levels.py [--root PROJECT_ROOT].
This is a structural audit. tests/test_routes.gd owns actual physics solvability.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from collections import Counter
from pathlib import Path
from typing import Any

KINDS = {"ring", "slide", "pendulum", "pulse", "switch", "reverse", "chain"}


def require(condition: bool, message: str, errors: list[str]) -> None:
    if not condition:
        errors.append(message)


def number(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def integer_in(value: Any, low: int, high: int) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and low <= value <= high


def validate_stage(stage: Any, location: str, errors: list[str]) -> None:
    if not isinstance(stage, dict):
        errors.append(f"{location}: expected stage object")
        return
    kind = stage.get("kind")
    require(isinstance(kind, str) and kind in KINDS, f"{location}: unknown mechanic", errors)
    for key, low, high in [("gap", 135, 205), ("speed", 0.5, 2), ("phase", 0, 6.28)]:
        value = stage.get(key)
        require(number(value) and low <= value <= high, f"{location}: invalid {key}", errors)
    for key in ("offset", "color"):
        require(integer_in(stage.get(key), 0, 3), f"{location}: invalid {key}", errors)
    require(isinstance(stage.get("checkpoint"), bool), f"{location}: invalid checkpoint", errors)
    if "width" in stage:
        value = stage["width"]
        require(number(value) and 0.2 <= value <= 0.45, f"{location}: invalid pulse width", errors)
    if "drift" in stage:
        value = stage["drift"]
        require(number(value) and 10 <= value <= 60, f"{location}: invalid drift", errors)


def validate_level(level: Any, world_id: int, errors: list[str]) -> None:
    if not isinstance(level, dict):
        errors.append(f"World {world_id}: expected level object")
        return
    location = f"Level {level.get('id', '?')}"
    require(integer_in(level.get("id"), 1, 100), f"{location}: invalid ID", errors)
    require(integer_in(level.get("world"), 1, 10) and level["world"] == world_id,
            f"{location}: wrong world", errors)
    for key in ("name", "subtitle"):
        value = level.get(key)
        require(isinstance(value, str) and 0 < len(value.strip()) <= 160,
                f"{location}: invalid {key}", errors)
    value = level.get("par")
    require(number(value) and 1 <= value <= 600, f"{location}: invalid par seconds", errors)
    require(integer_in(level.get("start_color"), 0, 3), f"{location}: invalid start color", errors)
    stages = level.get("stages")
    if not isinstance(stages, list):
        errors.append(f"{location}: expected stage list")
        return
    require(3 <= len(stages) <= 7, f"{location}: expected 3–7 stages", errors)
    require(any(isinstance(s, dict) and s.get("checkpoint") for s in stages),
            f"{location}: missing checkpoint", errors)
    for index, stage in enumerate(stages, 1):
        validate_stage(stage, f"{location} stage {index}", errors)


def load_worlds(root: Path, errors: list[str]) -> tuple[list[dict[str, Any]], list[Path]]:
    paths = sorted((root / "data" / "worlds").glob("*.json"))
    require(len(paths) == 10, "Expected exactly ten world files", errors)
    worlds: list[dict[str, Any]] = []
    for path in paths:
        try:
            if path.stat().st_size > 1_000_000:
                errors.append(f"{path.name}: exceeds one megabyte limit")
                continue
            data = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, UnicodeError, json.JSONDecodeError) as exc:
            errors.append(f"{path.name}: {type(exc).__name__}")
            continue
        if not isinstance(data, dict):
            errors.append(f"{path.name}: expected world object")
            continue
        worlds.append(data)
    return worlds, paths


def validate(root: Path) -> dict[str, Any]:
    errors: list[str] = []
    worlds, paths = load_worlds(root, errors)
    levels: list[dict[str, Any]] = []
    for index, world in enumerate(worlds, 1):
        require(integer_in(world.get("id"), 1, 10) and world["id"] == index,
                f"World {index}: wrong ID", errors)
        require(isinstance(world.get("name"), str), f"World {index}: missing name", errors)
        require(isinstance(world.get("theme"), str), f"World {index}: missing theme", errors)
        color = world.get("accent")
        valid_color = isinstance(color, str) and len(color) == 7 and color.startswith("#")
        if valid_color:
            valid_color = all(c in "0123456789abcdefABCDEF" for c in color[1:])
        require(valid_color, f"World {index}: invalid accent", errors)
        items = world.get("levels")
        if not isinstance(items, list):
            errors.append(f"World {index}: missing levels")
            continue
        require(len(items) == 10, f"World {index}: expected ten levels", errors)
        for level in items:
            validate_level(level, index, errors)
            if isinstance(level, dict):
                levels.append(level)
    require([l.get("id") for l in levels] == list(range(1, 101)), "IDs must be exactly 1–100", errors)
    names = [l.get("name") for l in levels]
    require(len(set(str(n) for n in names)) == 100, "Expected one hundred unique level names", errors)
    signatures = [json.dumps(l.get("stages"), sort_keys=True) for l in levels]
    require(len(set(signatures)) == 100, "Expected one hundred distinct stage layouts", errors)
    stage_lists = [l["stages"] for l in levels if isinstance(l.get("stages"), list)]
    stages = [stage for items in stage_lists for stage in items if isinstance(stage, dict)]
    counts = Counter(str(s.get("kind")) for s in stages)
    require(set(counts) == KINDS, "Expected every specified mechanic", errors)
    return {
        "worlds": len(worlds), "levels": len(levels), "stages": len(stages),
        "unique_layouts": len(set(signatures)), "mechanics": dict(sorted(counts.items())),
        "registry_sha256": hashlib.sha256(b"".join(p.read_bytes() for p in paths)).hexdigest(),
        "errors": errors,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    report = validate(args.root)
    print(json.dumps(report, indent=2))
    return 1 if report["errors"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
