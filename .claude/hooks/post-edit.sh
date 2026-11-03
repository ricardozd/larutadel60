#!/usr/bin/env bash
# PostToolUse hook: formats and checks the edited file. Exit 2 sends stderr back to Claude as a blocking error.
set -uo pipefail
cd "${CLAUDE_PROJECT_DIR:-$(dirname "$0")/../..}"

file="$(python3 -c 'import json, sys; print(json.load(sys.stdin).get("tool_input", {}).get("file_path", ""))')"
[ -n "$file" ] && [ -f "$file" ] || exit 0

case "$file" in
	*/.vendor/*|*/addon/LaRutaDel60/Guides/*) exit 0 ;;
	*.lua)
		stylua "$file" 2> /dev/null
		if ! out="$(luacheck --no-color "$file" 2>&1)"; then
			printf 'luacheck found problems in %s:\n%s\n' "$file" "$out" >&2
			exit 2
		fi
		;;
	*/data/routes/*.json)
		if ! out="$(python3 tools/validate_routes.py 2>&1)"; then
			printf 'Routes are invalid after editing %s:\n%s\n' "$file" "$out" >&2
			exit 2
		fi
		;;
esac
exit 0
