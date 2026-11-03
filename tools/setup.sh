#!/usr/bin/env bash
# Installs the development toolchain on macOS (Homebrew). Idempotent.
set -euo pipefail
cd "$(dirname "$0")/.."
brew install luajit luarocks lua-language-server luacheck stylua
luarocks --lua-version=5.1 --lua-dir="$(brew --prefix luajit)" --local install busted
tools/fetch_annotations.sh
case ":$PATH:" in
	*":$HOME/.luarocks/bin:"*) ;;
	*) echo "WARNING: add \$HOME/.luarocks/bin to your PATH (busted lives there)." ;;
esac
echo "OK: toolchain installed"
