#!/usr/bin/env bash
# Downloads (or updates) Ketho's WoW API LuaLS annotations into .vendor/.
set -euo pipefail
cd "$(dirname "$0")/.."
DEST=".vendor/vscode-wow-api"
if [ -d "$DEST/.git" ]; then
	git -C "$DEST" pull --ff-only --quiet
else
	mkdir -p .vendor
	git clone --quiet --depth 1 --filter=blob:none --sparse https://github.com/Ketho/vscode-wow-api.git "$DEST"
	git -C "$DEST" sparse-checkout set Annotations
fi
test -d "$DEST/Annotations/Core" || { echo "ERROR: $DEST/Annotations/Core not found" >&2; exit 1; }
echo "OK: annotations in $DEST/Annotations/Core"
