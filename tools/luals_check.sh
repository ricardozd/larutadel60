#!/usr/bin/env bash
# lua-language-server diagnostics (with WoW API annotations) for the addon.
set -euo pipefail
cd "$(dirname "$0")/.."
test -d .vendor/vscode-wow-api/Annotations/Core || tools/fetch_annotations.sh
LOGDIR="$(mktemp -d)"
trap 'rm -rf "$LOGDIR"' EXIT
# Check the repo root so relative paths in .luarc.json resolve; ignoreDir skips tests/, tools/ and .vendor/.
lua-language-server --check "$PWD" --configpath "$PWD/.luarc.json" --checklevel=Warning --logpath "$LOGDIR"
