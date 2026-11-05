"""Offline source safety and exact-token duplication checks; not a SonarQube substitute."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent.parent
TOKENS = re.compile(r'"""[\s\S]*?"""|\'\'\'[\s\S]*?\'\'\'|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|#[^\n]*|\w+|[^\s]', re.UNICODE)
SECRET_PATTERNS = {
    "private_key": re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
    "aws_access_key": re.compile(r"\bAKIA[0-9A-Z]{16}\b"),
    "github_token": re.compile(r"\b(?:ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{36,}\b"),
}
RUNTIME_BOUNDARIES = re.compile(r"\b(?:OS\.(?:execute|create_process|shell_open)|HTTPRequest|HTTPClient|TCPServer|UDPServer|eval)\b")


def lexical_tokens(source: str) -> list[tuple[str, int]]:
    return [(match.group(), source.count("\n", 0, match.start()) + 1) for match in TOKENS.finditer(source)
            if not match.group().startswith("#")]


def duplication(files: dict[str, str], size: int = 100) -> dict:
    fingerprints: dict[bytes, list[tuple[str, int, int]]] = {}
    cloned: dict[str, set[int]] = {name: set() for name in files}
    total: dict[str, set[int]] = {}
    for name, source in files.items():
        tokens = lexical_tokens(source)
        total[name] = {line for _, line in tokens}
        for index in range(len(tokens) - size + 1):
            window = tokens[index:index + size]
            start, end = window[0][1], window[-1][1]
            if end - start + 1 < 10:
                continue
            fingerprint = hashlib.sha256("\x00".join(token for token, _ in window).encode()).digest()
            matches = fingerprints.setdefault(fingerprint, [])
            for other, left, right in matches:
                if other == name and not (end < left or start > right):
                    continue
                cloned[other].update(line for line in total[other] if left <= line <= right)
                cloned[name].update(line for _, line in window)
            matches.append((name, start, end))
    count = sum(len(lines) for lines in cloned.values())
    denominator = sum(len(lines) for lines in total.values())
    return {"method": "Exact lexical 100-token clones spanning at least ten lines; comments/whitespace ignored",
            "duplicated_lines": count, "code_lines": denominator,
            "percent": count / denominator * 100 if denominator else 0.0,
            "files": {name: sorted(lines) for name, lines in cloned.items() if lines}}


def inspect_sources() -> dict:
    runtime = {path.relative_to(ROOT).as_posix(): path.read_text(encoding="utf-8")
               for path in sorted((ROOT / "src").rglob("*.gd"))}
    findings = []
    for name, source in runtime.items():
        for label, pattern in SECRET_PATTERNS.items():
            for match in pattern.finditer(source):
                findings.append({"file": name, "line": source.count("\n", 0, match.start()) + 1, "kind": label})
        for match in RUNTIME_BOUNDARIES.finditer(source):
            findings.append({"file": name, "line": source.count("\n", 0, match.start()) + 1,
                             "kind": "external_execution_or_network_requires_review"})
    clones = duplication(runtime)
    return {"source_files": len(runtime), "source_sha256": {
        name: hashlib.sha256(source.encode()).hexdigest() for name, source in runtime.items()},
        "high_confidence_findings": findings, "duplication": clones,
        "sonarqube": "Not applicable to GDScript: no supported SonarSource analyzer; this is an independent check",
        "limitations": ["Pattern checks are not a complete vulnerability assessment",
                        "Exact-token duplication does not normalize identifiers or literal values",
                        "No security hotspot status is inferred from unsupported Sonar rules"]}


def main() -> None:
    fixture = "\n".join(f"var repeated_{index} = {index} + 1" for index in range(40))
    assert duplication({"a.gd": fixture, "b.gd": fixture})["percent"] == 100.0
    assert duplication({"a.gd": "# same\n" * 100, "b.gd": "# same\n" * 100})["percent"] == 0.0
    assert SECRET_PATTERNS["private_key"].search("-----BEGIN PRIVATE KEY-----")
    assert RUNTIME_BOUNDARIES.search('OS.execute("test")')
    report = inspect_sources()
    report["negative_control_checks"] = 4
    output = ROOT / "builds/logs/quality-static.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({key: value for key, value in report.items() if key != "source_sha256"}, indent=2))
    assert not report["high_confidence_findings"], "Review static findings before release"
    assert report["duplication"]["percent"] <= 3.0, "Exact-token duplication exceeds the three-percent gate"


if __name__ == "__main__":
    main()
