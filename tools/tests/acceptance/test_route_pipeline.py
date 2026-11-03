"""Acceptance tests for the route pipeline CLIs (spec §11.1). Frozen: do not edit without user approval."""

import json
import sys
import tempfile
import unittest
from pathlib import Path

from tools.tests.acceptance.support import (
    COMPILE,
    ROOT,
    VALIDATE,
    dump_guide,
    normalize,
    run,
    valid_route,
    write_route,
)

INVALID_ROUTES = [
    ("unknown faction", {"faction": "Pirates"}),
    ("faction that is not a string", {"faction": 1}),
    ("level above 60", {"maxLevel": 61}),
    ("level below 1", {"minLevel": 0}),
    ("min level above max level", {"minLevel": 10, "maxLevel": 5}),
    ("name without enUS", {"name": {"esES": "Ruta"}}),
    ("missing name", {"name": None}),
    ("empty steps", {"steps": []}),
    ("unknown step type", {"steps": [{"type": "dance"}]}),
    ("quest step without questId", {"steps": [{"type": "accept"}]}),
    ("non positive questId", {"steps": [{"type": "accept", "questId": 0}]}),
    ("turnin without previous accept", {"steps": [{"type": "turnin", "questId": 5}]}),
    ("complete without previous accept", {"steps": [{"type": "complete", "questId": 5}]}),
    ("goto without coords", {"steps": [{"type": "goto"}]}),
    ("coords out of range", {"steps": [{"type": "goto", "coords": {"mapId": 1429, "x": 150, "y": 20}}]}),
    ("coords without mapId", {"steps": [{"type": "goto", "coords": {"x": 10, "y": 20}}]}),
    ("note without text", {"steps": [{"type": "note"}]}),
    ("text without enUS", {"steps": [{"type": "note", "text": {"esES": "Hola"}}]}),
    ("source that is not a URL", {"steps": [{"type": "accept", "questId": 1, "source": "wowhead"}]}),
    ("non positive npcId", {"steps": [{"type": "accept", "questId": 1, "npcId": 0}]}),
    ("races that is not a list", {"races": "Human"}),
    ("classes that is not a list of strings", {"classes": [1]}),
    ("carriedQuests that is not a list of ints", {"carriedQuests": ["x"]}),
    ("fractional minLevel", {"minLevel": 1.5}),
    ("string maxLevel", {"maxLevel": "2"}),
    ("next that is not a string", {"next": 5}),
]


class ValidateCliTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.routes = Path(self._tmp.name) / "routes"

    def tearDown(self):
        self._tmp.cleanup()

    def validate(self, routes_dir=None):
        return run([sys.executable, VALIDATE, routes_dir or self.routes])

    def test_accepts_a_valid_route(self):
        write_route(self.routes, valid_route())
        result = self.validate()
        self.assertEqual(0, result.returncode, result.stderr)

    def test_accepts_turnin_of_a_quest_carried_from_a_previous_route(self):
        write_route(self.routes, valid_route(carriedQuests=[5], steps=[{"type": "turnin", "questId": 5}]))
        result = self.validate()
        self.assertEqual(0, result.returncode, result.stderr)

    def test_accepts_the_repository_routes(self):
        result = run([sys.executable, VALIDATE])
        self.assertEqual(0, result.returncode, result.stderr)

    def test_rejects_every_rule_violation_naming_the_file(self):
        for label, overrides in INVALID_ROUTES:
            with self.subTest(label), tempfile.TemporaryDirectory() as tmp:
                routes = Path(tmp)
                route = valid_route(**overrides)
                if route.get("name") is None:
                    del route["name"]
                write_route(routes, route, filename="test-route.json")
                result = self.validate(routes)
                self.assertEqual(1, result.returncode, f"{label}: {result.stdout}{result.stderr}")
                self.assertIn("test-route.json", result.stderr, label)

    def test_rejects_an_id_that_is_not_kebab_case(self):
        write_route(self.routes, valid_route(id="Bad_Id"), filename="Bad_Id.json")
        result = self.validate()
        self.assertEqual(1, result.returncode)
        self.assertIn("Bad_Id.json", result.stderr)

    def test_accepts_hearth_fly_and_train_steps(self):
        steps = [{"type": "hearth"}, {"type": "fly"}, {"type": "train"}]
        write_route(self.routes, valid_route(steps=steps))
        result = self.validate()
        self.assertEqual(0, result.returncode, result.stderr)

    def test_rejects_a_file_name_that_does_not_match_the_id(self):
        write_route(self.routes, valid_route(), filename="other-name.json")
        result = self.validate()
        self.assertEqual(1, result.returncode)
        self.assertIn("other-name.json", result.stderr)

    def test_rejects_duplicate_ids_across_folders(self):
        write_route(self.routes / "alliance", valid_route())
        write_route(self.routes / "horde", valid_route())
        result = self.validate()
        self.assertEqual(1, result.returncode)
        self.assertIn("test-route.json", result.stderr)

    def test_rejects_next_pointing_to_a_missing_route(self):
        write_route(self.routes, valid_route(next="missing-route"))
        result = self.validate()
        self.assertEqual(1, result.returncode)
        self.assertIn("test-route.json", result.stderr)

    def test_accepts_next_pointing_to_an_existing_route(self):
        write_route(self.routes, valid_route(next="second-route"))
        write_route(self.routes, valid_route(id="second-route"))
        result = self.validate()
        self.assertEqual(0, result.returncode, result.stderr)

    def test_rejects_broken_json_naming_the_file(self):
        self.routes.mkdir(parents=True)
        (self.routes / "broken.json").write_text("{", encoding="utf-8")
        result = self.validate()
        self.assertEqual(1, result.returncode)
        self.assertIn("broken.json", result.stderr)


class CompileCliTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        base = Path(self._tmp.name)
        self.routes = base / "routes"
        self.out = base / "Guides"
        self.route = valid_route()
        write_route(self.routes / "alliance", self.route)

    def tearDown(self):
        self._tmp.cleanup()

    def compile(self, *extra, routes=None, out=None):
        return run([sys.executable, COMPILE, "--routes", routes or self.routes, "--out", out or self.out, *extra])

    def test_writes_one_guide_per_route_and_an_index(self):
        result = self.compile()
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual({"test-route.lua", "Guides.xml"}, {p.name for p in self.out.iterdir()})
        self.assertIn('<Script file="test-route.lua"/>', (self.out / "Guides.xml").read_text(encoding="utf-8"))

    def test_compiled_guide_holds_exactly_the_route_data(self):
        self.assertEqual(0, self.compile().returncode)
        loaded = dump_guide(self.out / "test-route.lua", "test-route")
        self.assertEqual(normalize(self.route), normalize(loaded))

    def test_repository_routes_survive_the_round_trip(self):
        result = self.compile(routes=ROOT / "data" / "routes")
        self.assertEqual(0, result.returncode, result.stderr)
        sources = sorted((ROOT / "data" / "routes").rglob("*.json"))
        self.assertTrue(sources, "the repository must contain at least one route")
        for source in sources:
            route = json.loads(source.read_text(encoding="utf-8"))
            with self.subTest(route["id"]):
                loaded = dump_guide(self.out / f"{route['id']}.lua", route["id"])
                self.assertEqual(normalize(route), normalize(loaded))

    def test_writes_nothing_when_a_route_is_invalid(self):
        write_route(self.routes / "alliance", {"id": "broken-route"})
        result = self.compile()
        self.assertEqual(1, result.returncode)
        self.assertFalse(self.out.exists() and any(self.out.iterdir()))

    def test_check_detects_outdated_guides(self):
        self.assertEqual(1, self.compile("--check").returncode)
        self.assertEqual(0, self.compile().returncode)
        self.assertEqual(0, self.compile("--check").returncode)
        write_route(self.routes / "alliance", valid_route(maxLevel=3))
        self.assertEqual(1, self.compile("--check").returncode)

    def test_check_does_not_write(self):
        result = self.compile("--check")
        self.assertEqual(1, result.returncode, result.stderr)
        self.assertFalse(self.out.exists() and any(self.out.iterdir()))

    def test_removes_guides_of_deleted_routes(self):
        second = write_route(self.routes / "alliance", valid_route(id="second-route"))
        self.assertEqual(0, self.compile().returncode)
        second.unlink()
        self.assertEqual(0, self.compile().returncode)
        self.assertFalse((self.out / "second-route.lua").exists())
        self.assertNotIn("second-route", (self.out / "Guides.xml").read_text(encoding="utf-8"))

    def test_check_detects_stale_guide_files(self):
        self.assertEqual(0, self.compile().returncode)
        self.assertEqual(0, self.compile("--check").returncode)
        (self.out / "stale-route.lua").write_text("-- stale\n", encoding="utf-8")
        self.assertEqual(1, self.compile("--check").returncode)

    def test_failed_compile_leaves_existing_output_untouched(self):
        self.assertEqual(0, self.compile().returncode)
        before = {p.name: p.read_bytes() for p in self.out.iterdir()}
        write_route(self.routes / "alliance", {"id": "broken-route"})
        self.assertEqual(1, self.compile().returncode)
        after = {p.name: p.read_bytes() for p in self.out.iterdir()}
        self.assertEqual(before, after)

    def test_repository_guides_are_up_to_date(self):
        result = run([sys.executable, COMPILE, "--check"])
        self.assertEqual(0, result.returncode, result.stderr)


if __name__ == "__main__":
    unittest.main()
