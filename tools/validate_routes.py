"""Validates leveling routes under data/routes against the La Ruta del 60 guide format.

Usage: python3 tools/validate_routes.py [ROUTES_DIR]
Exit code 0 when every route is valid, 1 otherwise (one error per line on stderr).
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ROUTES_DIR = ROOT / "data" / "routes"

FACTIONS = {"Alliance", "Horde", "Both"}
STEP_TYPES = {"accept", "complete", "turnin", "goto", "hearth", "fly", "train", "note"}
QUEST_STEPS = {"accept", "complete", "turnin"}
LOCALES = {"enUS", "esES"}
ROUTE_KEYS = {"id", "name", "faction", "races", "classes", "minLevel", "maxLevel", "next", "carriedQuests", "steps"}
STEP_KEYS = {"type", "questId", "npcId", "coords", "text", "source"}
COORDS_KEYS = {"mapId", "x", "y"}
MIN_LEVEL, MAX_LEVEL = 1, 60
ID_RE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")


def _reject_constant(name: str):
    raise ValueError(f"{name} is not allowed in JSON")


def load_route_json(path: Path):
    """Reads a route file as strict JSON (rejects NaN/Infinity). Raises ValueError, OSError or UnicodeDecodeError."""
    return json.loads(path.read_text(encoding="utf-8"), parse_constant=_reject_constant)


def _is_int(value) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


def _is_number(value) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def _check_keys(obj: dict, allowed: set[str], where: str, errors: list[str]) -> None:
    for key in sorted(obj, key=str):
        if key not in allowed:
            errors.append(f"{where}: unknown key '{key}'")
        elif obj[key] is None:
            errors.append(f"{where}: '{key}' cannot be null (omit the key instead)")


def _check_localized(value, where: str, field: str, errors: list[str], required: bool) -> None:
    if value is None:
        if required:
            errors.append(f"{where}: missing '{field}'")
        return
    if not isinstance(value, dict) or "enUS" not in value:
        errors.append(f"{where}: '{field}' must be an object with at least 'enUS'")
        return
    for locale, text in value.items():
        if locale not in LOCALES:
            errors.append(f"{where}: unknown locale '{locale}' in '{field}'")
        elif not isinstance(text, str) or not text.strip():
            errors.append(f"{where}: '{field}.{locale}' is empty")


def _check_coords(coords, where: str, errors: list[str]) -> None:
    if not isinstance(coords, dict):
        errors.append(f"{where}: 'coords' must be an object")
        return
    _check_keys(coords, COORDS_KEYS, f"{where}: coords", errors)
    map_id = coords.get("mapId")
    if not _is_int(map_id) or map_id <= 0:
        errors.append(f"{where}: 'coords.mapId' must be an integer > 0")
    for axis in ("x", "y"):
        value = coords.get(axis)
        if not _is_number(value) or not 0 <= value <= 100:
            errors.append(f"{where}: 'coords.{axis}' must be between 0 and 100")


def _check_level(route: dict, field: str, errors: list[str]) -> bool:
    value = route.get(field)
    if not _is_int(value) or not MIN_LEVEL <= value <= MAX_LEVEL:
        errors.append(f"'{field}' must be an integer between {MIN_LEVEL} and {MAX_LEVEL}")
        return False
    return True


def _check_step(step, index: int, accepted: set[int], errors: list[str]) -> None:
    where = f"steps[{index}]"
    if not isinstance(step, dict):
        errors.append(f"{where}: a step must be an object")
        return
    _check_keys(step, STEP_KEYS, where, errors)
    step_type = step.get("type")
    if step_type not in STEP_TYPES:
        errors.append(f"{where}: unknown step type '{step_type}'")
        return

    if step_type in QUEST_STEPS:
        quest_id = step.get("questId")
        if not _is_int(quest_id) or quest_id <= 0:
            errors.append(f"{where}: 'questId' must be an integer > 0")
        elif step_type == "accept":
            accepted.add(quest_id)
        elif quest_id not in accepted:
            errors.append(
                f"{where}: questId {quest_id} was not accepted earlier in the route "
                "(add it to 'carriedQuests' if it comes from a previous route)"
            )

    if step_type == "goto" and "coords" not in step:
        errors.append(f"{where}: a 'goto' step needs 'coords'")
    if "coords" in step:
        _check_coords(step["coords"], where, errors)

    _check_localized(step.get("text"), where, "text", errors, required=step_type == "note")

    if "npcId" in step and (not _is_int(step["npcId"]) or step["npcId"] <= 0):
        errors.append(f"{where}: 'npcId' must be an integer > 0")
    source = step.get("source")
    if source is not None and (not isinstance(source, str) or not source.startswith(("http://", "https://"))):
        errors.append(f"{where}: 'source' must be an http(s) URL")


def validate_route(route) -> list[str]:
    """Returns the errors of a single route (empty when valid)."""
    if not isinstance(route, dict):
        return ["a route must be a JSON object"]
    errors: list[str] = []
    _check_keys(route, ROUTE_KEYS, "route", errors)

    route_id = route.get("id")
    if not isinstance(route_id, str) or not ID_RE.match(route_id):
        errors.append("'id' must be lowercase kebab-case")
    _check_localized(route.get("name"), "route", "name", errors, required=True)
    if not isinstance(route.get("faction"), str) or route["faction"] not in FACTIONS:
        errors.append(f"'faction' must be one of {sorted(FACTIONS)}")

    min_ok = _check_level(route, "minLevel", errors)
    max_ok = _check_level(route, "maxLevel", errors)
    if min_ok and max_ok and route["minLevel"] > route["maxLevel"]:
        errors.append("'minLevel' cannot be greater than 'maxLevel'")

    for field in ("races", "classes"):
        value = route.get(field)
        if value is not None and (not isinstance(value, list) or not all(isinstance(v, str) for v in value)):
            errors.append(f"'{field}' must be a list of strings")

    next_id = route.get("next")
    if next_id is not None and not isinstance(next_id, str):
        errors.append("'next' must be the id (string) of another route")

    carried = route.get("carriedQuests", [])
    if not isinstance(carried, list) or not all(_is_int(q) and q > 0 for q in carried):
        errors.append("'carriedQuests' must be a list of integers > 0")
        carried = []

    steps = route.get("steps")
    if not isinstance(steps, list) or not steps:
        errors.append("'steps' must be a non-empty list")
        return errors
    accepted = set(carried)
    for index, step in enumerate(steps, start=1):
        _check_step(step, index, accepted, errors)
    return errors


def validate_all(routes_dir: Path = ROUTES_DIR) -> list[str]:
    """Validates every *.json under routes_dir, including cross-file rules. Errors are prefixed by the file."""
    routes_dir = Path(routes_dir)
    errors: list[str] = []
    ids: dict[str, str] = {}
    routes: list[tuple[str, dict]] = []

    if not routes_dir.is_dir():
        return [f"routes directory '{routes_dir}' does not exist or is not a directory"]

    for path in sorted(routes_dir.rglob("*.json")):
        label = path.relative_to(routes_dir).as_posix()
        try:
            data = load_route_json(path)
        except (ValueError, UnicodeDecodeError) as exc:  # JSONDecodeError is a ValueError
            errors.append(f"{label}: invalid JSON: {exc}")
            continue
        except OSError as exc:
            errors.append(f"{label}: cannot read file: {exc}")
            continue
        errors.extend(f"{label}: {err}" for err in validate_route(data))
        if isinstance(data, dict) and isinstance(data.get("id"), str):
            route_id = data["id"]
            if path.stem != route_id:
                errors.append(f"{label}: file name must be '{route_id}.json'")
            if route_id in ids:
                errors.append(f"{label}: duplicated id '{route_id}' (also in {ids[route_id]})")
            ids[route_id] = label
            routes.append((label, data))

    for label, data in routes:
        next_id = data.get("next")
        if isinstance(next_id, str) and next_id not in ids:
            errors.append(f"{label}: 'next' points to a missing route '{next_id}'")
    return errors


def main(argv: list[str] | None = None) -> int:
    argv = sys.argv[1:] if argv is None else argv
    routes_dir = Path(argv[0]) if argv else ROUTES_DIR
    errors = validate_all(routes_dir)
    for err in errors:
        print(f"ERROR {err}", file=sys.stderr)
    if errors:
        return 1
    print(f"OK: routes are valid in {routes_dir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
