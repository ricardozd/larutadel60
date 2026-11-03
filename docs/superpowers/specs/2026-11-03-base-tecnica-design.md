# La Ruta del 60 — Technical base (design)

Date: 2026-11-03
Status: approved and implemented (branch feat/base-tecnica)

## 1. Context

**Product goal:** free addon for *World of Warcraft: Forever* (Blizzard's official Classic+) that guides any character (any race/class/faction) from level 1 to 60 along the fastest route. Functionally similar to RestedXP (steps, arrow, auto-accept/turn-in), but with **100% original code and routes**: no code or content is copied from RestedXP guides or other addons.

**Goal of this phase:** create the technical base so the addon is developed entirely with AI (Claude Code): agents, skills, LSP, lint, tests, data pipeline, CI and deployment. The addon engine is a later spec.

**Target platform:**
- WoW Forever client 1.60.1, `## Interface: 16001`, release 2026-11-04.
- Lua 5.1 (WoW environment). Modern API (retail 12.x): `C_QuestLog`, `C_Map`, `C_Item`, `C_Spell`, etc. Midnight "secrets" restrictions active. ~1,041 FrameXML globals removed compared to retail.
- Detection: `WOW_PROJECT_ID == WOW_PROJECT_CAMELOT` (18). TOC with `_Forever` / `_Camelot` suffix supported.
- Played on a Windows PC; developed on macOS.

**Decisions made with the user:**
- Approach A: native Claude Code + standard Lua toolchain (no custom MCP).
- Route data: web databases (Wowhead and similar with Forever data), with the source cited per record.
- Deployment: GitHub + PowerShell script on the PC.
- Addon languages (player-facing texts): enUS and esES from the start.
- **Project language:** everything committed to the repo is in English: code, comments, strings, tool/CLI messages, test names, commits, specs, plans, CLAUDE.md, agents, skills and docs. Player-facing texts are localized (enUS + esES). The assistant explains and talks to the user in Spanish in chat. (Originally the explanations were in Spanish; translated to English when the rule changed.)
- **Acceptance tests first:** before any code, black-box tests derived only from this spec (§11) are written. They are committed in red and frozen: the implementation turns them green without modifying them.

## 2. Repository structure

```
larutadel60/
├── CLAUDE.md
├── .claude/
│   ├── settings.json
│   ├── agents/
│   └── skills/
├── .luarc.json
├── .luacheckrc
├── .stylua.toml
├── addon/LaRutaDel60/
│   ├── LaRutaDel60.toc
│   ├── LaRutaDel60_Forever.toc
│   ├── Core/
│   ├── UI/
│   ├── Modules/
│   ├── Locales/
│   ├── Libs/
│   └── Guides/
├── data/
│   ├── raw/
│   └── routes/
├── tools/
├── tests/
│   └── support/
├── scripts/deploy.ps1
├── .github/workflows/ci.yml
└── docs/
    ├── api/
    └── superpowers/specs/
```

Principles:
- **Routes = data, not code.** `data/routes/*.json` → validated → compiled to `addon/LaRutaDel60/Guides/*.lua`. The route agents never touch `Core/`.
- **No globals.** Everything under the addon's private table (`local ADDON, ns = ...`); the only allowed globals are `LaRutaDel60DB` (SavedVariables) and the `/ruta` command.
- **Small files with a single responsibility.** One module per file.

## 3. Toolchain

| Tool | Use | Config |
|---|---|---|
| lua-language-server | LSP: diagnostics, WoW API types | `.luarc.json` (Lua 5.1 runtime, library = Ketho `vscode-wow-api` mainline annotations, addon globals) |
| luacheck | Lint (globals, unused variables) | `.luacheckrc` with `std = "lua51"` + WoW globals read |
| stylua | Formatting | `.stylua.toml` (tabs, 120 cols) |
| busted | Unit tests outside the game | `tests/`, mocks in `tests/support/` |
| python3 | Data tools | `tools/` (scraper, validator, compiler) |

Installation on macOS via `brew` (lua-language-server, luacheck, stylua, luarocks) and `luarocks install busted`. The Ketho annotations are downloaded to `.vendor/` (in `.gitignore`) by `tools/setup.sh`.

**LSP in Claude Code:** project-local plugin that registers `lua-language-server` for `.lua`, so the LSP tool provides diagnostics and navigation. If the plugin integration is not available, fallback: a hook that runs `lua-language-server --check` on the edited file.

**Hooks (`.claude/settings.json`):** after each `Edit`/`Write` of a `.lua`: `stylua <file>` and `luacheck <file>`; the output goes back to Claude. Pre-approved permissions for lint, test and `tools/`.

## 4. Agents (`.claude/agents/`)

| Agent | Responsibility | Writes to |
|---|---|---|
| `wow-api-expert` | Verifies whether an API/event exists in Forever 1.60.1 (docs/api, annotations, wiki) and proposes an alternative. | — (read-only) |
| `addon-engineer` | Implements engine/UI with TDD over mocks. | `addon/`, `tests/` |
| `route-researcher` | Extracts quests/NPCs/coords/levels from web databases, with a source URL per record. | `data/raw/` |
| `route-optimizer` | Builds and optimizes routes by faction/race/class (order, travel, hearthstone, flights). | `data/routes/` |
| `route-validator` | Validates consistency: prerequisites, levels, coords, IDs, accumulated XP up to 60. | — (read-only) |
| `lua-reviewer` | Pre-commit review: taint, performance, globals, 16001 compatibility. | — (read-only) |

## 5. Skills (`.claude/skills/`)

- `wow-forever-api` — cheat sheet of the modern API, removed items, secrets, key quest/gossip/map events.
- `guide-format` — route JSON schema and its compilation to Lua.
- `add-route-segment` — research → JSON → optimize → validate → compile pipeline for a segment.
- `new-module` — module template (file, TOC, test, locale).
- `release` — version, changelog, tag; CI packages the zip.
- `debug-in-game` — read BugSack errors / SavedVariables pasted by the user and reproduce them as a test.

## 6. Route data pipeline

1. `route-researcher` saves records in `data/raw/<zone>.json` (quest id, name, level, prerequisites, start/end NPC with coords, objectives, faction, source URL).
2. `route-optimizer` generates `data/routes/<faction>/<segment>.json` (ordered list of steps).
3. `tools/validate_routes.py` checks schema and rules; fails in CI if there are errors.
4. `tools/compile_guides.py` generates `addon/LaRutaDel60/Guides/*.lua` (generated files, "do not edit" header).

In this phase only the schema, the validator, the compiler and a minimal example route (2–3 steps) are created, to test the pipeline end to end.

## 7. "Hello world" addon

- TOC with `Interface: 16001`, `SavedVariables: LaRutaDel60DB`, loading of Locales/Core/Guides.
- `Core/Init.lua`: namespace, `PLAYER_LOGIN` event, Forever detection, chat message, `/ruta` command showing the version and loaded guide.
- enUS/esES locales.
- busted test that loads the addon with mocks and verifies init + command.

## 8. CI and deployment

- **CI (GitHub Actions):** luacheck, stylua `--check`, busted, validate_routes, compile_guides with a clean diff; on a `v*` tag, zip of `addon/LaRutaDel60` attached to the release.
- **`scripts/deploy.ps1` (Windows):** parameters `-WowPath` (default `C:\Program Files (x86)\World of Warcraft\_classic_`, configurable because Forever's folder may differ) and `-Source` (`git` = pull of the local repo; `release` = downloads the latest zip from GitHub). Copies `LaRutaDel60` to `Interface\AddOns`. Then tells the user to `/reload`.

## 9. Success criteria for this phase

- `tools/check.sh` passes: lint, formatting, tests, validation and compilation.
- Claude Code shows LSP diagnostics on `.lua` files with WoW API types.
- The 6 agents and 6 skills exist and are referenced in `CLAUDE.md`.
- The "hello world" addon installs on Windows with `deploy.ps1` and shows its message in Forever (manual verification by the user).
- CI green on GitHub.

## 10. Out of scope

Guide engine (arrow, step list, auto-quest), final UI, real routes, CurseForge publishing.

## 11. Verifiable contracts and acceptance tests

The acceptance tests only use these external interfaces. Anything else (internal functions, exact format of the generated Lua, text of error messages) is an implementation detail and is not tested at this level.

### 11.1 Route pipeline CLI
- `python3 tools/validate_routes.py [ROUTES_DIR]` (default `data/routes`): exit 0 if all routes are valid; exit 1 otherwise, with one error per line on stderr, and each line contains the relative path of the offending file.
- `python3 tools/compile_guides.py [--routes DIR] [--out DIR] [--check]`:
  - Without `--check`: validates; if there are errors, exit 1 and **writes nothing**. If everything is valid, writes one `<id>.lua` per route and `Guides.xml` (which lists them all with `<Script file="<id>.lua"/>`), deletes the `.lua` files of routes that no longer exist and ends with exit 0.
  - With `--check`: writes nothing; exit 1 if the output differs from what is in `--out`, exit 0 if up to date.
- Round trip: loading `<id>.lua` in Lua 5.1 with `(addonName, ns)` leaves in `ns.Guides[id]` a table with **exactly the same data** as the source JSON.
- Validation rules: those in the format table (§6 and the `guide-format` skill). Each rule has at least one acceptance case.

### 11.2 Addon (what the player sees)
Chat messages (no color codes), with the prefix `La Ruta del 60: `:

| Situation | enUS | esES / esMX |
|---|---|---|
| Login | `Loaded. Type /ruta for info.` | `Cargado. Escribe /ruta para más info.` |
| Login on a non-Forever client (before the previous one) | `Warning: this client is not WoW Forever; guides may be wrong.` | `Aviso: este cliente no es WoW Forever; las guías pueden fallar.` |
| `/ruta` | `Version <TOC Version> - <N> guide(s) loaded.` | `Versión <TOC Version> - <N> guía(s) cargada(s).` |

- `<N>` = number of routes in `data/routes`.
- `LaRutaDel60DB` exists after login and keeps the previous data.
- New globals after loading the addon and logging in: only `LaRutaDel60DB`, `SLASH_LARUTADEL601` and the `LARUTADEL60` key in `SlashCmdList`.
- TOC: `LaRutaDel60.toc` and `LaRutaDel60_Forever.toc` identical, `## Interface: 16001`, `## SavedVariables: LaRutaDel60DB`, and every listed file (and every script included in an `.xml`) exists.

### 11.3 Tools
- `tools/check.sh`: exit 0 on the clean repo; non-zero exit if there is an addon `.lua` with a lint error, an invalid route or outdated guides.
- Hook `.claude/hooks/post-edit.sh` (receives the PostToolUse JSON on stdin): exit 2 with a message on stderr if the edited `.lua` has lint errors or if the edit leaves invalid routes; exit 0 in all other cases.
- The tool tests that run `tools/check.sh` do so on a temporary copy of the repo and with `LR60_SKIP_TOOLING_TESTS=1`, so they do not run themselves in a loop.

### 11.4 Client emulation in tests
- `tests/support/` emulates the client: loads files in TOC order (expanding `.xml`), passes `(addonName, ns)`, resolves slash commands like the client (`SLASH_<KEY><n>` → `SlashCmdList[KEY]`) and captures the chat (`DEFAULT_CHAT_FRAME:AddMessage` and `print`).
- The mocks only imitate APIs that are in `docs/api/forever-api.md`, with the source cited.

### 11.5 Manual verification (not automatable on macOS)
`deploy.ps1` on Windows, the LSP inside Claude Code and the addon in the real client: checklist for the user in the last task of the plan.
