"""Acceptance tests for strict route keys: unknown keys and null values are rejected."""

import sys
import tempfile
import unittest
from pathlib import Path

from tools.tests.acceptance.support import VALIDATE, run, valid_route, write_route


def _with_step_key(key, value):
    route = valid_route()
    route["steps"][2][key] = value
    return route


def _with_coords_key(key, value):
    route = valid_route()
    route["steps"][3]["coords"][key] = value
    return route


def _with_step_replaced(index, key, value):
    route = valid_route()
    route["steps"][index][key] = value
    return route


REJECTED = [
    ("unknown top-level key", {**valid_route(), "questID": 1}),
    ("unknown step key", _with_step_key("cords", {"mapId": 1429, "x": 1, "y": 2})),
    ("unknown coords key", _with_coords_key("z", 1)),
    ("null next", {**valid_route(), "next": None}),
    ("null races", {**valid_route(), "races": None}),
    ("null step text", _with_step_replaced(0, "text", None)),
    ("null step npcId", _with_step_key("npcId", None)),
    ("null step source", _with_step_key("source", None)),
]


class StrictKeysTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.routes = Path(self._tmp.name) / "routes"

    def tearDown(self):
        self._tmp.cleanup()

    def test_valid_route_is_still_accepted(self):
        write_route(self.routes, valid_route())
        result = run([sys.executable, VALIDATE, self.routes])
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_unknown_keys_and_nulls_are_rejected_naming_the_file(self):
        for label, route in REJECTED:
            with self.subTest(label):
                directory = self.routes / label.replace(" ", "_")
                write_route(directory, route)
                result = run([sys.executable, VALIDATE, directory])
                self.assertEqual(result.returncode, 1, f"{label} was accepted")
                self.assertIn("test-route.json", result.stderr)


if __name__ == "__main__":
    unittest.main()
