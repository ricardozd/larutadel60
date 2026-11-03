"""Black-box helpers for acceptance tests: run CLIs, build fixture routes, copy the repo."""

from __future__ import annotations

import copy
import json
import os
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
VALIDATE = ROOT / "tools" / "validate_routes.py"
COMPILE = ROOT / "tools" / "compile_guides.py"
DUMP_GUIDE = Path(__file__).resolve().parent / "dump_guide.lua"
LUAJIT = shutil.which("luajit") or "luajit"
SKIP_TOOLING = os.environ.get("LR60_SKIP_TOOLING_TESTS") == "1"

VALID_ROUTE = {
    "id": "test-route",
    "name": {"enUS": "Test route", "esES": "Ruta de prueba"},
    "faction": "Alliance",
    "races": ["Human"],
    "minLevel": 1,
    "maxLevel": 2,
    "steps": [
        {"type": "note", "text": {"enUS": "Start", "esES": "Empieza"}},
        {"type": "note", "text": {"enUS": 'Say "hi"\nback\\slash', "esES": "Habla con él: más"}},
        {
            "type": "accept",
            "questId": 783,
            "npcId": 823,
            "coords": {"mapId": 1429, "x": 48.2, "y": 42.9},
            "source": "https://www.wowhead.com/classic/quest=783",
        },
        {"type": "goto", "coords": {"mapId": 1429, "x": 48.9, "y": 41.6}},
        {"type": "turnin", "questId": 783, "npcId": 197},
    ],
}


def run(args: list, cwd: Path = ROOT, env: dict | None = None, stdin: str | None = None):
    full_env = dict(os.environ)
    full_env.update(env or {})
    return subprocess.run(
        [str(a) for a in args],
        cwd=cwd,
        env=full_env,
        input=stdin,
        capture_output=True,
        text=True,
        encoding="utf-8",
        timeout=900,
    )


def valid_route(**overrides) -> dict:
    route = copy.deepcopy(VALID_ROUTE)
    route.update(overrides)
    return route


def write_route(directory: Path, route: dict, filename: str | None = None) -> Path:
    directory.mkdir(parents=True, exist_ok=True)
    path = directory / (filename or f"{route['id']}.json")
    path.write_text(json.dumps(route, ensure_ascii=False, indent=2), encoding="utf-8")
    return path


def dump_guide(guide_path: Path, guide_id: str):
    """Loads a compiled guide with LuaJIT like the client would and returns ns.Guides[id] as Python data."""
    result = run([LUAJIT, DUMP_GUIDE, guide_path, guide_id])
    if result.returncode != 0:
        raise AssertionError(f"dump_guide failed: {result.stderr}")
    return json.loads(result.stdout)


def normalize(value):
    """Lua cannot tell empty arrays from empty objects; treat both as []."""
    if isinstance(value, dict):
        return {k: normalize(v) for k, v in value.items()} if value else []
    if isinstance(value, list):
        return [normalize(v) for v in value]
    return value


def copy_repo(destination: Path) -> Path:
    """Copies the working tree (without .git) to destination/repo, sharing .vendor through a symlink."""
    repo = destination / "repo"
    shutil.copytree(
        ROOT,
        repo,
        ignore=shutil.ignore_patterns(".git", ".vendor", "__pycache__", "dist", "check.json"),
        symlinks=True,
    )
    if (ROOT / ".vendor").exists():
        (repo / ".vendor").symlink_to(ROOT / ".vendor", target_is_directory=True)
    return repo
