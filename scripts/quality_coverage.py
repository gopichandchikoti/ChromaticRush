"""Run genuine gd-tools coverage in a disposable project, leaving delivered scripts untouched."""

from __future__ import annotations

import argparse
from dataclasses import asdict
from datetime import datetime, timezone
import importlib.resources
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

from gd_tools.coverage import plan_generator, reporter

ROOT = Path(__file__).resolve().parent.parent
ENGINE = Path(os.environ.get("GODOT_BIN", str(
    Path(os.environ["LOCALAPPDATA"]) / "Programs/CodexDevTools/godot/Godot_v4.7.2-stable_win64_console.exe")))


def prepare() -> tuple[Path, object]:
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%f")
    project = ROOT / ".tools" / "quality" / ("coverage-" + stamp)
    project.mkdir(parents=True)
    for folder in ("src", "data", "assets", "tests"):
        shutil.copytree(ROOT / folder, project / folder)
    for filename in ("project.godot", "main.tscn"):
        shutil.copy2(ROOT / filename, project / filename)
    evidence = project / "docs" / "evidence"
    evidence.mkdir(parents=True)
    shutil.copy2(ROOT / "docs/evidence/route_audit.json", evidence / "route_audit.json")
    target = project / ".quality"
    target.mkdir()
    addon = importlib.resources.files("gd_tools").joinpath("addons/gd-tools-coverage/coverage.gd")
    (target / "coverage.gd").write_text(addon.read_text(encoding="utf-8"), encoding="utf-8")
    config = project / "project.godot"
    config.write_text(config.read_text(encoding="utf-8") +
                      '\n[autoload]\n_GDTCoverage="*res://.quality/coverage.gd"\n', encoding="utf-8")
    plan = plan_generator.generate_plan(str(project), exclude_dirs=["tests", ".quality", "docs"], test_dirs=["tests"])
    expected = {"res://" + p.relative_to(project).as_posix() for p in (project / "src").rglob("*.gd")}
    assert {entry.path for entry in plan.files} == expected, "Every production script must be instrumented"
    assert all(not entry.excluded_lines for entry in plan.files), "Production coverage exclusions are not permitted"
    plan_generator.write_plan_json(plan, str(target / "plan.json"))
    for script in (project / "tests").glob("test_*.gd"):
        source = script.read_text(encoding="utf-8")
        entry = "_initialize" if re.search(r"^func _initialize\(", source, re.M) else "_init"
        source, count = re.subn(r"^func " + entry + r"\(", "func _quality_body(", source, count=1, flags=re.M)
        assert count == 1, f"No SceneTree entry point in {script}"
        source += ('\n\nfunc _initialize() -> void:\n\tcall_deferred("_quality_start")\n'
                   '\n\nfunc _quality_start() -> void:\n\tawait process_frame\n\t_quality_body()\n')
        script.write_text(source, encoding="utf-8")
    return project, plan


def execute(project: Path, suite: Path, render: bool) -> Path:
    output = project / ".quality" / (suite.stem + ("-render" if render else "") + ".json")
    env = dict(os.environ, GD_TOOLS_COVERAGE_PLAN=str(project / ".quality/plan.json"),
               GD_TOOLS_COVERAGE_OUTPUT=str(output), GD_TOOLS_COVERAGE_PLAYTEST="1")
    args = [str(ENGINE), "--path", str(project), "--script", "res://tests/" + suite.name]
    if not render:
        args.insert(1, "--headless")
    elif suite.stem in {"test_ui", "test_worlds"}:
        args.extend(["--", "--capture"])
    process = subprocess.run(args, capture_output=True, text=True, encoding="utf-8", errors="replace", env=env,
                             timeout=300, check=False)
    log = process.stdout + process.stderr
    output.with_suffix(".log").write_text(log, encoding="utf-8")
    assert process.returncode == 0 and "SCRIPT ERROR:" not in log and "ERROR:" not in log, str(output.with_suffix(".log"))
    assert output.is_file(), f"Collector produced no coverage data: {suite.name}"
    data = json.loads(output.read_text(encoding="utf-8"))
    assert not data.get("omitted"), f"Instrumentation omissions: {data['omitted']}"
    return output


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--suite", action="append", help="Limit diagnostic runs; omitted in the release gate")
    parser.add_argument("--render", action="store_true", help="Include actual drawing callbacks")
    parser.add_argument("--include-search", action="store_true", help="Also trace the costly launch search; replay is default")
    parser.add_argument("--minimum", type=float, default=90.0)
    args = parser.parse_args()
    project, plan = prepare()
    print("Coverage workspace:", project, flush=True)
    init = subprocess.run([str(ENGINE), "--headless", "--editor", "--path", str(project), "--import", "--quit"],
                          capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=120, check=False)
    (project / ".quality/import.log").write_text(init.stdout + init.stderr, encoding="utf-8")
    assert init.returncode == 0 and "SCRIPT ERROR:" not in init.stdout + init.stderr, "Coverage-copy import failed"
    paths = []
    for suite in sorted((project / "tests").glob("test_*.gd")):
        if suite.stem == "test_routes" and not args.include_search:
            continue
        if args.suite and suite.stem not in args.suite:
            continue
        print("Measuring", suite.name, flush=True)
        paths.append(execute(project, suite, args.render and suite.stem in {"test_ui", "test_worlds"}))
    combined = reporter.merge_coverage_data([str(path) for path in paths])
    summary = reporter.compute_summary(plan, combined)
    reporter.generate_report(plan, combined, ROOT / "builds/coverage", format="lcov")
    by_id = {entry.file_id: entry for entry in combined.files}
    lines_found = lines_hit = 0
    for entry in plan.files:
        found = {point.line for point in entry.lines}
        hit = {point.line for point in entry.lines if by_id[entry.file_id].hits.get(str(point.id), 0) > 0}
        lines_found += len(found)
        lines_hit += len(hit)
        original = ROOT / entry.path.removeprefix("res://")
        actual = "sha256:" + hashlib.sha256(original.read_text(encoding="utf-8").encode()).hexdigest()
        assert actual == entry.source_hash, f"Source changed during measurement: {entry.path}"
    unique_lines = {"covered": lines_hit, "total": lines_found, "rate": lines_hit / lines_found}
    report = {"tool": "gd-tools-cli==0.10.0", "source_scope": "Every src/**/*.gd file; no production exclusions",
              "workspace": str(project), "summary": asdict(summary),
              "source_sha256": {entry.path: entry.source_hash for entry in plan.files},
              "unique_planned_source_lines": unique_lines,
              "measurement_notes": "gd-tools line_rate counts statement/branch tracking points; unique source lines are also gated",
              "suite_policy": "Normal test.ps1 runs the launch search; coverage replays every successful input schedule",
              "files": [asdict(reporter.compute_file_summary(entry, by_id[entry.file_id])) for entry in plan.files],
              "metrics_not_provided": ["functions", "statements"], "threshold": args.minimum}
    destination = ROOT / "builds/logs/quality-coverage.json"
    destination.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    public = dict(report)
    public["workspace"] = str(project.relative_to(ROOT)).replace("\\", "/")
    (ROOT / "docs/evidence/quality-coverage.json").write_text(json.dumps(public, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report["summary"], indent=2), flush=True)
    assert summary.line_rate * 100 >= args.minimum, "Line coverage below required gate"
    assert unique_lines["rate"] * 100 >= args.minimum, "Unique planned source-line coverage below required gate"
    assert summary.branch_rate * 100 >= args.minimum, "Branch coverage below required gate"


if __name__ == "__main__":
    main()
