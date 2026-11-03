#!/usr/bin/env bash
# Full project verification. Must pass before every commit.
set -euo pipefail
cd "$(dirname "$0")/.."

BUSTED="${BUSTED:-}"
if [ -z "$BUSTED" ]; then
	if command -v busted > /dev/null; then BUSTED="busted"; else BUSTED="$HOME/.luarocks/bin/busted"; fi
fi

step() { printf '\n== %s\n' "$1"; }

step "frozen acceptance tests"
if git rev-parse -q --verify refs/tags/acceptance-frozen > /dev/null 2>&1; then
	if ! git diff --quiet --diff-filter=MDR acceptance-frozen -- tests/acceptance tests/support tools/tests/acceptance; then
		echo "Frozen acceptance tests were modified or deleted since tag acceptance-frozen (see CLAUDE.md)" >&2
		exit 1
	fi
else
	echo "WARNING: tag acceptance-frozen not found; freeze check skipped"
fi

step "stylua"; stylua --check addon tests tools/tests
step "luacheck"; luacheck --no-color addon tests tools/tests/acceptance/dump_guide.lua
step "validate routes"; python3 tools/validate_routes.py
step "compiled guides up to date"; python3 tools/compile_guides.py --check
step "python tests"; python3 -m unittest discover -s tools/tests -t . -q
step "lua tests (busted)"; "$BUSTED"
step "LuaLS"; tools/luals_check.sh

printf '\nOK: all green\n'
