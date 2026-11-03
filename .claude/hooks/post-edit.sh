#!/usr/bin/env bash
# PostToolUse hook: formats and checks the edited file. Exit 2 sends stderr back to Claude as a blocking error.
set -uo pipefail
cd "${CLAUDE_PROJECT_DIR:-$(dirname "$0")/../..}"

file="$(python3 -c 'import json, sys; print(json.load(sys.stdin).get("tool_input", {}).get("file_path", ""))')"
[ -n "$file" ] && [ -f "$file" ] || exit 0
# Claude Code sends absolute paths; luacheck only applies .luacheckrc per-path rules to relative ones.
file="${file#"$PWD"/}"

case "$file" in
	.vendor/*|*/.vendor/*) exit 0 ;;
	addon/LaRutaDel60/Guides/*)
		echo "Guides/ is generated: edit data/routes/*.json and run python3 tools/compile_guides.py" >&2
		exit 2
		;;
	*.lua)
		command -v luacheck > /dev/null || { echo "luacheck not installed (run tools/setup.sh)" >&2; exit 2; }
		stylua "$file" 2> /dev/null
		if ! out="$(luacheck --no-color "$file" 2>&1)"; then
			printf 'luacheck found problems in %s:\n%s\n' "$file" "$out" >&2
			exit 2
		fi
		;;
	data/routes/*.json|*/data/routes/*.json)
		if ! out="$(python3 tools/validate_routes.py 2>&1)"; then
			printf 'Routes are invalid after editing %s:\n%s\n' "$file" "$out" >&2
			exit 2
		fi
		;;
esac
exit 0
