"""Acceptance tests for tools/check.sh and the Claude Code post-edit hook (spec §11.3).
Frozen: do not edit without user approval."""

import json
import tempfile
import unittest
from pathlib import Path

from tools.tests.acceptance.support import SKIP_TOOLING, copy_repo, run, valid_route, write_route

BAD_LUA = "local unused_variable = 1\n"


@unittest.skipIf(SKIP_TOOLING, "running inside tools/check.sh of a repository copy")
class CheckScriptTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.repo = copy_repo(Path(self._tmp.name))

    def tearDown(self):
        self._tmp.cleanup()

    def check(self):
        return run([self.repo / "tools" / "check.sh"], cwd=self.repo, env={"LR60_SKIP_TOOLING_TESTS": "1"})

    def test_passes_on_a_clean_repository(self):
        result = self.check()
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)

    def test_fails_on_a_lint_error_in_the_addon(self):
        with open(self.repo / "addon" / "LaRutaDel60" / "Core" / "Init.lua", "a", encoding="utf-8") as f:
            f.write(BAD_LUA)
        self.assertNotEqual(0, self.check().returncode)

    def test_fails_on_an_invalid_route(self):
        write_route(self.repo / "data" / "routes" / "alliance", {"id": "broken-route"})
        self.assertNotEqual(0, self.check().returncode)

    def test_fails_on_outdated_guides(self):
        example = next((self.repo / "data" / "routes").rglob("*.json"))
        route = json.loads(example.read_text(encoding="utf-8"))
        route["maxLevel"] = route["maxLevel"] + 1 if route["maxLevel"] < 60 else route["maxLevel"] - 1
        example.write_text(json.dumps(route), encoding="utf-8")
        self.assertNotEqual(0, self.check().returncode)


@unittest.skipIf(SKIP_TOOLING, "running inside tools/check.sh of a repository copy")
class PostEditHookTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.repo = copy_repo(Path(self._tmp.name))
        self.hook = self.repo / ".claude" / "hooks" / "post-edit.sh"

    def tearDown(self):
        self._tmp.cleanup()

    def run_hook(self, path: Path):
        payload = json.dumps({"tool_name": "Edit", "tool_input": {"file_path": str(path)}})
        return run([self.hook], cwd=self.repo, env={"CLAUDE_PROJECT_DIR": str(self.repo)}, stdin=payload)

    def test_blocks_a_lua_file_with_lint_errors(self):
        bad = self.repo / "addon" / "LaRutaDel60" / "Core" / "Bad.lua"
        bad.write_text(BAD_LUA, encoding="utf-8")
        result = self.run_hook(bad)
        self.assertEqual(2, result.returncode)
        self.assertTrue(result.stderr.strip())

    def test_accepts_a_clean_lua_file(self):
        result = self.run_hook(self.repo / "addon" / "LaRutaDel60" / "Core" / "Init.lua")
        self.assertEqual(0, result.returncode, result.stderr)

    def test_blocks_an_edit_that_leaves_invalid_routes(self):
        broken = write_route(self.repo / "data" / "routes" / "alliance", {"id": "broken-route"})
        result = self.run_hook(broken)
        self.assertEqual(2, result.returncode)
        self.assertTrue(result.stderr.strip())

    def test_accepts_a_valid_route_edit(self):
        path = write_route(self.repo / "data" / "routes" / "alliance", valid_route(id="extra-route"))
        result = self.run_hook(path)
        self.assertEqual(0, result.returncode, result.stderr)

    def test_ignores_other_files(self):
        result = self.run_hook(self.repo / "docs" / "api" / "forever-api.md")
        self.assertEqual(0, result.returncode, result.stderr)


if __name__ == "__main__":
    unittest.main()
