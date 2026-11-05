"""Validate exported payloads, SHA sidecars and the final source archive without dependencies."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parent.parent
BUILDS = ROOT / "builds"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def artifact(name: str) -> dict:
    path = BUILDS / name
    assert path.is_file() and path.stat().st_size > 0, f"Missing artifact: {name}"
    sha = digest(path)
    expected = path.with_name(path.name + ".sha256").read_text(encoding="utf-8").split()[0]
    assert sha == expected, f"SHA sidecar mismatch: {name}"
    return {"file": name, "bytes": path.stat().st_size, "sha256": sha}


def apk_payload(name: str = "chromatic-rush-1.0.0-release.apk") -> dict:
    with zipfile.ZipFile(BUILDS / name) as archive:
        assert archive.testzip() is None, "APK ZIP CRC failure"
        names = archive.namelist()
        assert not any(name.startswith(("assets/tests/", "assets/docs/", "assets/scripts/")) for name in names)
        assert not any(name.endswith((".keystore", ".jks", ".p12", ".pfx", "/.env")) for name in names)
        assert not any("release-password" in name for name in names)
        worlds = sorted(name for name in names if name.startswith("assets/data/worlds/") and name.endswith(".json"))
        assert len(worlds) == 10, "APK must include all ten authored worlds"
        levels = 0
        for name in worlds:
            content = archive.read(name)
            assert content == (ROOT / name.removeprefix("assets/")).read_bytes(), f"Stale APK content: {name}"
            levels += len(json.loads(content)["levels"])
        assert levels == 100, "APK must contain all one hundred levels"
        abis = sorted({name.split("/")[1] for name in names if name.startswith("lib/") and name.endswith(".so")})
        assert abis == ["arm64-v8a", "x86_64"], "Unexpected native architecture payload"
        return {"worlds": len(worlds), "levels": levels, "abis": abis, "crc": "pass"}


def source_payload() -> dict:
    with zipfile.ZipFile(BUILDS / "ChromaticRush-1.0.0-source.zip") as archive:
        assert archive.testzip() is None, "Source ZIP CRC failure"
        for entry in archive.infolist():
            path = Path(entry.filename)
            assert path.parts[0] == "ChromaticRush" and ".." not in path.parts
            assert not any(part in {".git", ".godot", ".tools", "builds", "__pycache__"} for part in path.parts)
            assert path.suffix not in {".jks", ".keystore", ".p12", ".pfx", ".apk", ".exe"}
            assert path.name != ".env" and "release-password" not in path.name
            assert not path.name.startswith("tmp_"), "Temporary visual probes should not ship"
            local = ROOT.joinpath(*path.parts[1:])
            assert local.is_file() and archive.read(entry) == local.read_bytes(), f"Source archive differs: {path}"
        expected = set()
        for folder in ("src", "data", "assets", "tests", "scripts", "docs", ".github"):
            for file in (ROOT / folder).rglob("*"):
                if file.is_file() and "__pycache__" not in file.parts and not file.name.startswith("tmp_"):
                    if file.suffix not in {".pyc", ".tmp", ".log"}:
                        expected.add("ChromaticRush/" + file.relative_to(ROOT).as_posix())
        assert expected.issubset(set(archive.namelist())), "Source package omits working files"
        return {"files": len(archive.infolist()), "matches_working_files": True, "crc": "pass"}


def main() -> None:
    report = {
        "artifacts": [artifact(name) for name in (
            "chromatic-rush-1.0.0-release.apk", "chromatic-rush-1.0.0-debug.apk",
            "ChromaticRush-1.0.0.exe", "ChromaticRush-1.0.0-source.zip")],
        "apk_payload": apk_payload(),
        "debug_payload": apk_payload("chromatic-rush-1.0.0-debug.apk"),
        "source_payload": source_payload(),
    }
    output = BUILDS / "logs" / "release-audit.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
