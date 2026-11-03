# La Ruta del 60

Free addon for **WoW Forever** (official Classic+, client 1.60.1, `## Interface: 16001`) that guides any character from level 1 to 60 along the fastest route. It is developed 100% with AI on macOS and played on Windows.

## Rules
- **Language:** Everything committed to the repo is in English: code, comments, strings, CLI messages, tests, commits, README, CLAUDE.md, agents, skills, specs, plans and docs. Player-facing texts are localized (enUS + esES). The assistant explains and talks to the user in Spanish in chat.
- **Acceptance tests first:** before writing code for a feature, there are black-box tests derived from its spec, committed in red. `tests/acceptance/`, `tests/support/` and `tools/tests/acceptance/` are **frozen**: they are turned green without modifying them. If a test looks wrong, STOP and ask the user.
  - The freeze is enforced with the `acceptance-frozen` tag: `tools/check.sh` (and CI) fails if anything modified, deleted or renamed relative to the tag changes under those paths, both in the working tree and in commits. Adding new tests is allowed.
  - A new feature adds NEW acceptance tests; after committing them in red, the tag is moved (`git tag -f acceptance-frozen`), only with user approval.
  - The push must include the tags (`git push --follow-tags` or `git push origin acceptance-frozen`; if it was moved, `--force` on that tag with user approval).
- **API:** Forever uses the modern retail 12.x API on Lua 5.1, not the Classic Era one. Before using any WoW API: skill `wow-forever-api` / agent `wow-api-expert`. What has been verified is in `docs/api/forever-api.md`.
- **Lua 5.1:** no `goto`, `//`, native bitwise operators, `<const>`.
- **No globals:** everything in `ns` (`local ADDON_NAME, ns = ...`). Only `LaRutaDel60DB`, `SLASH_LARUTADEL601` and `SlashCmdList.LARUTADEL60` are allowed.
- **Routes = data:** `data/routes/**/*.json` (skill `guide-format`). `addon/LaRutaDel60/Guides/` is GENERATED: never edit it by hand.
- **TOC:** `LaRutaDel60.toc` and `LaRutaDel60_Forever.toc` always identical.
- **Player-facing texts:** always via `ns.L`, with a key in `Locales/enUS.lua` and `Locales/esES.lua`.
- **Original:** no code or guides are copied from RestedXP or other addons.
- Small commits using Conventional Commits. No push unless the user asks.

## Setup (fresh clone, macOS)
1. `tools/setup.sh`: installs the toolchain and the API annotations. If `~/.luarocks/bin` is not in the PATH, it warns: add it yourself in your shell profile (`check.sh` works anyway).
2. LSP plugin for Claude Code (needs `lua-language-server` in the PATH): `claude plugin marketplace add ./` and then `claude plugin install wow-lua-lsp@larutadel60 --scope project`. Then restart Claude Code.
3. `tools/check.sh` must end with `OK: all green`.

## Commands
| What | Command |
|---|---|
| Full verification (mandatory before commit) | `tools/check.sh` |
| Lua tests | `~/.luarocks/bin/busted` (or `busted`) |
| Python tests | `python3 -m unittest discover -s tools/tests -t . -q` |
| Validate / compile routes | `python3 tools/validate_routes.py` / `python3 tools/compile_guides.py` |
| LuaLS | `tools/luals_check.sh` |
| Install the toolchain (macOS) | `tools/setup.sh` |
| Install on Windows | `scripts\deploy.ps1` (PowerShell) |

The hooks in `.claude/settings.json` format and lint every edited `.lua` and validate every route JSON. If they return an error, fix it before continuing.

## Agents (`.claude/agents/`)
- `wow-api-expert`: verifies Forever APIs (read-only).
- `addon-engineer`: implements addon code against acceptance tests.
- `route-researcher`: raw quest data from the web → `data/raw/`.
- `route-optimizer`: builds optimal routes → `data/routes/`.
- `route-validator`: reviews route consistency (read-only).
- `lua-reviewer`: code review before commit (read-only).

## Skills (`.claude/skills/`)
`wow-forever-api`, `guide-format`, `add-route-segment`, `new-module`, `release`, `debug-in-game`.

## Structure
```
addon/LaRutaDel60/   addon (what gets copied to Interface\AddOns)
  Core/ UI/ Modules/ Locales/ Libs/ Guides/(generated)
data/raw/            raw data from the web (with source)
data/routes/         source routes (JSON)
tools/               Python/bash scripts (validator, compiler, check)
tools/tests/         acceptance tests for the tools (frozen)
tests/support/       WoW client emulation (frozen)
tests/acceptance/    addon acceptance tests (frozen)
scripts/deploy.ps1   deployment on Windows
docs/                specs, plans, API
```
