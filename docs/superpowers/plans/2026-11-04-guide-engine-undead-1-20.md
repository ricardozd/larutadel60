# Guide engine MVP + Undead 1-20 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An Undead character can follow the addon from level 1 to 20 (Tirisfal Glades → Silverpine Forest) with a step window and a waypoint arrow.

**Architecture:** The spec is `docs/superpowers/specs/2026-11-04-guide-engine-undead-1-20-design.md`, and every task reads it.
- Acceptance tests come first and are written by an author who has not seen any implementation. They are then frozen.
- Implementation tasks turn them green without editing them.
- The engine is pure Lua (Selector, Progress, StepText, Engine) behind a single WoW adapter (`Core/Game.lua`), with thin UI views (`UI/StepFrame.lua`, `UI/Arrow.lua`).
- Routes are JSON data produced by the route agents from Wowhead Forever.

**Tech Stack:** Lua 5.1 (WoW Forever 1.60.1, Interface 16001), busted on LuaJIT, Python 3 stdlib, the existing `tools/check.sh` pipeline.

**Note on code in this plan:** this plan deliberately does not dictate implementation code. The contract is the frozen acceptance tests written in Task 2 from spec §5, so the tests are independent of any implementation. That is the project's acceptance-tests-first rule. Each implementation task lists the exact files, interfaces and spec sections it must satisfy, and the test files that must turn green.

## Global Constraints

- Everything committed is in English. Only player-facing esES strings are Spanish, exactly as in spec §3.3 and §3.5.
- Frozen: `tests/acceptance/`, `tests/support/`, `tools/tests/acceptance/`. After Task 2's tag move, implementation tasks never edit them. If a test looks wrong: STOP and report.
- No new globals. Frames are unnamed. Per-character data goes in `LaRutaDel60DB.chars["<Name>-<Realm>"]` and UI data in `LaRutaDel60DB.ui`.
- Login chat output and plain `/ruta` output stay exactly as they are today.
- Lua 5.1 only. Every WoW API used must appear in `.luacheckrc` `read_globals` and in `docs/api/forever-api.md`.
- Both TOCs stay identical. Load order: Locales → Core/Init → Core/Game, Selector, Progress, StepText, Engine, Commands → UI/StepFrame, UI/Arrow → Guides.
- Routes: original data from public databases (Wowhead Forever), each quest step with a `source` URL. Never copy RestedXP or paid guides.
- `tools/check.sh` is green before every commit, except the red acceptance-test commit.
- Commit trailer: blank line + `Co-Authored-By: Claude <model> <noreply@anthropic.com>`.

---

### Task 1: Client emulation extension (additive)

**Files:**
- Modify: `tests/support/wow_mock.lua`, `tests/support/client.lua`. Additive only: existing behavior must be unchanged.
- Modify: `docs/api/forever-api.md`, adding a row for each emulated behavior with its source.
- Modify: `.luacheckrc`, adding to `read_globals`: `C_QuestLog`, `C_Map`, `C_Timer`, `CreateVector2D`, `GetPlayerFacing`, `UnitFactionGroup`, `UnitRace`, `UnitClass`, `UnitLevel`, `UnitName`, `GetRealmName`.
- Create: `tests/acceptance/emulation_spec.lua`. These are self-tests of the emulation, so the new behavior is pinned before the engine tests rely on it.

**Interfaces:** Produces exactly the `Client.boot(opts)` options, `client.*` actions, emulated APIs and inspection helpers of spec §4, with the names used there:
- `opts`: `player`, `quests`, `position`, `maps`, `guides`, `replaceGuides`.
- Actions: `acceptQuest`, `completeObjectives`, `turnInQuest`, `loadQuestData`, `moveTo`, `face`, `enterInstance`, `levelUp`, `advance`, `reload`.
- Inspection helpers: `visibleTexts`, `click`, `arrow`, `drag`.

- [ ] Step 1: Implement the extension in `tests/support/`. Keep every existing function's behavior.
- [ ] Step 2: Write `tests/acceptance/emulation_spec.lua`. It covers:
  - every quest action fires the documented event sequence;
  - `GetPlayerMapPosition` returns 0-1 values via `GetXY` and nil after `enterInstance`;
  - `GetWorldPosFromMapPos` returns the same continent for both default maps, with distances in yards;
  - `C_Timer` and `OnUpdate` fire through `advance`;
  - `reload` keeps `LaRutaDel60DB`;
  - `guides` and `replaceGuides` register fixture routes;
  - `visibleTexts`, `click` and `arrow` behave as specified.
- [ ] Step 3: Run `~/.luarocks/bin/busted`. All the old specs and `emulation_spec.lua` pass.
- [ ] Step 4: Commit: `test: extend WoW client emulation for the guide engine`. `check.sh`'s freeze step is expected to fail until Task 2 moves the tag; everything else must be green.

### Task 2: Acceptance tests (red) and freeze

**Author:** a fresh agent that reads only the spec, `tests/support/` and the existing acceptance tests. It must not read any addon code written for this feature, because none exists yet.

**Files:**
- Create in `tests/acceptance/`: `engine_selection_spec.lua`, `engine_steps_spec.lua`, `engine_progress_spec.lua`, `arrow_spec.lua`, `commands_spec.lua`, `engine_hygiene_spec.lua`. They use fixture routes through `opts.guides` and `replaceGuides = true`, and cover every engine bullet of spec §5.
- Create: `tools/tests/acceptance/test_undead_routes.py`, covering the "Routes" bullet of spec §5 through the files and the validate CLI.

- [ ] Step 1: Write the specs. Expected strings are copied verbatim from spec §3.3 and §3.5 (enUS and esES).
- [ ] Step 2: Run them and confirm the new ones FAIL or ERROR and the old ones still pass:
  - `~/.luarocks/bin/busted`
  - `python3 -m unittest discover -s tools/tests -t . -q`

  If any new test passes, it is vacuous and must be fixed now.
- [ ] Step 3: Commit: `test: acceptance tests for guide engine and Undead routes (red)`.
- [ ] Step 4: Controller: send the tests to an independent review (spec coverage, vacuity, determinism) and fix the findings before freezing. Then run `git tag -f acceptance-frozen` (approved in the spec).

### Task 3: Engine core and step window

**Files:**
- Create: `addon/LaRutaDel60/Core/Game.lua`, `Core/Selector.lua`, `Core/Progress.lua`, `Core/StepText.lua`, `Core/Engine.lua`, `UI/StepFrame.lua`.
- Modify: both TOCs, `Locales/enUS.lua`, `Locales/esES.lua`.

**Interfaces:**
- `ns.Game`: the only module that touches WoW globals.
- `ns.Selector.Choose(guides, player) -> routeId|nil` (spec §3.1).
- `ns.Progress`: get and set per character (spec §2, §3).
- `ns.StepText.For(step, locale) -> string` (spec §3.3).
- `ns.Engine`: `Start()`, `Done()`, `Skip()`, `Back()`, `SetRoute(id)`, `Reset()`, `Current() -> route, index, step`, plus an `OnChange(callback)` subscription for the views.
- `ns.StepFrame`: `Refresh()`, `Show()`, `Hide()`.

- [ ] Make these green, without editing them: `engine_selection_spec.lua`, `engine_steps_spec.lua`, `engine_progress_spec.lua`, plus every pre-existing spec.
- [ ] `tools/check.sh` green, except for specs owned by Tasks 4-7. Run `lua-reviewer` before committing.
- [ ] Commit: `feat: guide engine core and step window`.

### Task 4: Waypoint arrow

**Files:**
- Create: `addon/LaRutaDel60/UI/Arrow.lua`.
- Modify: both TOCs.

**Interfaces:**
- Consumes `ns.Engine.Current()` and `ns.Engine.OnChange(cb)`.
- Uses `ns.Game` position, facing and world-position helpers. Add any new helpers to `Core/Game.lua`.

- [ ] Make `arrow_spec.lua` green (spec §3.4).
- [ ] `check.sh` green apart from Task 5-7 specs, then `lua-reviewer`, then commit: `feat: waypoint arrow`.

### Task 5: Chat subcommands

**Files:**
- Create: `addon/LaRutaDel60/Core/Commands.lua`.
- Modify: `Core/Init.lua`, so that the `/ruta` handler delegates subcommands while plain `/ruta` keeps the exact current output. Also modify the locales and both TOCs.

- [ ] Make `commands_spec.lua` and `engine_hygiene_spec.lua` green (spec §3.5).
- [ ] `check.sh` green apart from the route test, then `lua-reviewer`, then commit: `feat: /ruta subcommands`.

### Task 6: Tirisfal Glades route (1-12)

Follow the `add-route-segment` skill.
- Run `route-researcher` for Tirisfal Glades. Output goes to `data/raw/tirisfal-glades.json` and includes the confirmed uiMapID. If the uiMapID differs from the emulation default of 1420, update `tests/support` defaults in Task 1 style, with user approval, before going on.
- Run `route-optimizer` to produce `data/routes/horde/horde-tirisfal-1-12.json`: Horde, races `["Scourge"]`, levels 1-12, `next: "horde-silverpine-12-20"`. The optimizer cannot finish until the Silverpine route exists, so commit both routes in Task 7. Here, stage the Tirisfal route with `next` set.
- Run `route-validator` on the Tirisfal route and fix every finding.

- [ ] Commit `data/raw/tirisfal-glades.json` only: `feat(routes): raw data for Tirisfal Glades`. The route file is committed with Task 7.

### Task 7: Silverpine Forest route (12-20) and removal of the example

- Run `route-researcher` for Silverpine Forest, writing `data/raw/silverpine-forest.json`.
- Run `route-optimizer` to produce `data/routes/horde/horde-silverpine-12-20.json`: Horde, races `["Scourge"]`, 12-20, with `carriedQuests` for quests carried over from Tirisfal.
- Run `route-validator` on both routes as a chain.
- Delete `data/routes/alliance/alliance-northshire-example.json`.
- Recompile with `python3 tools/compile_guides.py`.

- [ ] Make `test_undead_routes.py` green and the whole `tools/check.sh` green.
- [ ] Commit: `feat(routes): Undead 1-20 (Tirisfal Glades, Silverpine Forest)`.

### Task 8: Final review and release

- [ ] Run a final whole-branch review on the most capable model, then one fix wave.
- [ ] Bump the TOC version to `0.2.0` and push the commit with the tags. Then follow the `release` skill: create the tag and the GitHub release, after asking the user.
- [ ] Manual check for the user in game. On a new Undead character, verify:
  - the window, the first step and the arrow;
  - accepting the first quest advances the step;
  - `/reload` keeps the step;
  - API mismatches go through the `debug-in-game` skill.
