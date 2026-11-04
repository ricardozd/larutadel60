"""Acceptance tests for the Undead 1-20 routes (guide engine spec §5, "Routes"). Frozen once tagged."""

import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path
from urllib.parse import urlparse

from tools.tests.acceptance.support import ROOT, VALIDATE, run

ROUTES = ROOT / "data" / "routes"
GUIDES = ROOT / "addon" / "LaRutaDel60" / "Guides"
TIRISFAL = "horde-tirisfal-1-12"
SILVERPINE = "horde-silverpine-12-20"
EXAMPLE = "alliance-northshire-example"
QUEST_STEPS = {"accept", "complete", "turnin"}


def route_path(route_id: str) -> Path:
    return ROUTES / "horde" / f"{route_id}.json"


def load(route_id: str) -> dict:
    path = route_path(route_id)
    if not path.is_file():
        raise AssertionError(f"missing route file {path.relative_to(ROOT)}")
    return json.loads(path.read_text(encoding="utf-8"))


def is_wowhead_forever(url) -> bool:
    if not isinstance(url, str):
        return False
    parsed = urlparse(url)
    host = parsed.netloc.lower()
    return (
        parsed.scheme in ("http", "https")
        and host in ("wowhead.com", "www.wowhead.com")
        and (parsed.path == "/forever" or parsed.path.startswith("/forever/"))
    )


class UndeadRoutesTest(unittest.TestCase):
    def test_both_routes_exist(self):
        for route_id in (TIRISFAL, SILVERPINE):
            with self.subTest(route_id):
                self.assertTrue(route_path(route_id).is_file(), f"missing {route_path(route_id)}")
                self.assertEqual(route_id, load(route_id)["id"])

    def test_both_routes_are_valid(self):
        with tempfile.TemporaryDirectory() as tmp:
            routes = Path(tmp) / "horde"
            routes.mkdir()
            # Validate the whole chain reachable from Tirisfal through `next`, so later
            # segments may be chained without breaking this test.
            route_id, seen = TIRISFAL, set()
            while route_id and route_id not in seen:
                seen.add(route_id)
                self.assertTrue(route_path(route_id).is_file(), f"missing {route_path(route_id)}")
                shutil.copy(route_path(route_id), routes / f"{route_id}.json")
                route_id = load(route_id).get("next")
            self.assertIn(SILVERPINE, seen)
            result = run([sys.executable, VALIDATE, Path(tmp)])
            self.assertEqual(0, result.returncode, result.stderr)
        result = run([sys.executable, VALIDATE])
        self.assertEqual(0, result.returncode, result.stderr)

    def test_both_routes_are_for_horde_undead(self):
        for route_id in (TIRISFAL, SILVERPINE):
            with self.subTest(route_id):
                route = load(route_id)
                self.assertEqual("Horde", route["faction"])
                self.assertEqual(["Scourge"], route["races"])

    def test_tirisfal_starts_at_level_1_and_chains_to_silverpine(self):
        route = load(TIRISFAL)
        self.assertEqual(1, route["minLevel"])
        self.assertEqual(SILVERPINE, route.get("next"))

    def test_silverpine_ends_at_level_20(self):
        self.assertEqual(20, load(SILVERPINE)["maxLevel"])

    def test_every_quest_step_has_a_wowhead_forever_source(self):
        for route_id in (TIRISFAL, SILVERPINE):
            route = load(route_id)
            quest_steps = [step for step in route["steps"] if step["type"] in QUEST_STEPS]
            self.assertTrue(quest_steps, f"{route_id} has no quest steps")
            for index, step in enumerate(route["steps"], start=1):
                if step["type"] not in QUEST_STEPS:
                    continue
                with self.subTest(route=route_id, step=index):
                    self.assertTrue(
                        is_wowhead_forever(step.get("source")),
                        f"{route_id} step {index} ({step['type']} {step.get('questId')}): "
                        f"source {step.get('source')!r} is not on wowhead.com/forever",
                    )

    def test_example_route_is_gone(self):
        self.assertEqual([], sorted(str(p) for p in ROUTES.rglob(f"{EXAMPLE}.json")))
        self.assertFalse((GUIDES / f"{EXAMPLE}.lua").exists())
        guides_xml = GUIDES / "Guides.xml"
        if guides_xml.exists():
            self.assertNotIn(EXAMPLE, guides_xml.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
