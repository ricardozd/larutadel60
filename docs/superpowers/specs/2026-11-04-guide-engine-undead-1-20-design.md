# Guide engine MVP + Undead 1-20 routes (design)

Date: 2026-11-04
Status: approved by the user ("implement 1 to 20"); implementation pending.

## 1. Goal

First playable version of La Ruta del 60: an Undead character goes from level 1 to 20 following the addon's steps, through Tirisfal Glades (1-12) and Silverpine Forest (12-20).

In scope:
- Guide engine:
  - step window;
  - waypoint arrow;
  - automatic route selection with manual switching;
  - automatic step advance;
  - per-character progress.
- Two routes: `horde-tirisfal-1-12` and `horde-silverpine-12-20`.
- Additive extension of the client emulation in `tests/support/` (the user approved it as part of this spec).

Out of scope (later):
- auto accept/turn-in;
- world map and minimap pins;
- other races and classes;
- routes above 20;
- dungeons.

## 2. Constraints carried over from the frozen tests

- On login the chat shows only `Loaded. Type /ruta for info.` (and the "not Forever" warning when applicable). The engine prints nothing else on login.
- Plain `/ruta` still prints only `Version <v> - <N> guide(s) loaded.`. Every new command is a subcommand.
- No new globals. Frames are created **without names**. Per-character data lives inside `LaRutaDel60DB`.
- A compiled guide must hold exactly the JSON data, so the compiler cannot add derived fields. The step identity is `(routeId, stepIndex)`.
- `<N>` in `/ruta` = number of route JSON files. The example route `alliance-northshire-example` is removed once the real routes exist.

## 3. Architecture

Pure logic is separated from the WoW API and from the UI.

| File | Responsibility | WoW API |
|---|---|---|
| `Core/Game.lua` | The only adapter over the WoW API. Covers: player info; quest state; map position, world position, facing and distance; title lookup with async load. | yes |
| `Core/Selector.lua` | `ns.Selector.Choose(guides, player) -> routeId or nil` | no |
| `Core/Progress.lua` | Per-character state: `LaRutaDel60DB.chars["<Name>-<Realm>"] = { route = id, step = n }`. Also holds the catch-up rule. | no |
| `Core/StepText.lua` | Localized text for a step. | via `Game` |
| `Core/Engine.lua` | Orchestration: selection on login, event-driven advance, `goto` distance polling, manual actions, route chaining. | via `Game` |
| `Core/Commands.lua` | `/ruta` subcommands. | chat |
| `UI/StepFrame.lua` | Movable step window, unnamed. Its position is saved in `LaRutaDel60DB.ui`. | frames |
| `UI/Arrow.lua` | Arrow texture rotation and distance label. | frames |

Load order in the TOC: Locales → Core/Init → Core/Game, Selector, Progress, StepText, Engine, Commands → UI → Guides. Modules read `ns.Guides` at `PLAYER_LOGIN` or later.

### 3.1 Route selection

A route matches when all of these hold:
- `faction` equals the player's faction, or is `Both`;
- `races` is absent or contains the player's English race token (`UnitRace` 2nd return; Undead = `Scourge`);
- `classes` is absent or contains the class file token;
- `minLevel <= level <= maxLevel`.

Among the matches, a route that lists `races` beats one that doesn't. Ties are broken by the lowest `minLevel`, then by the `id` sorted alphabetically. Saved progress wins over selection as long as its route still exists and still matches faction, race and class. Level is not checked here, so a player who outlevels a route keeps it until they switch.

The selected route is saved as progress as soon as it is chosen.

### 3.2 Step completion

| Type | Completes when | Auto-skipped on catch-up when |
|---|---|---|
| `accept` | `QUEST_ACCEPTED` for its `questId` | the quest is in the log or already turned in |
| `complete` | `ReadyForTurnIn(questId) == true`, re-checked on `QUEST_LOG_UPDATE` | ready, or already turned in |
| `turnin` | `QUEST_TURNED_IN` for its `questId` | already turned in |
| `goto` | the player is within 10 yards of `coords` (checked every 0.2 s) | never |
| `hearth`, `fly`, `train`, `note` | the player clicks **Done** | never |

On every step change, and at login, the engine keeps advancing while the current step is auto-skippable. That way a quest done out of order is skipped, and the player never stays stuck on a step that is already satisfied. **Skip** advances one step. **Back** goes back one step and is never auto-skipped right after. When the last step of a route is completed, the engine switches to `next` (step 1). With no `next`, the window shows the "route complete" text.

`QUEST_ACCEPTED` carries the quest ID in its last argument in every client version, so the engine reads the last argument.

Edge cases:
- Back on step 1 does nothing.
- Skip on the last step behaves like completing it: it chains to `next`, or shows route complete.
- On the route-complete screen only Back is shown, and it returns to the last step.
- Skip, like every step change, is followed by catch-up.

Timing: engine reactions are synchronous. By the end of the `PLAYER_LOGIN` handler the window shows the selected route and step. `QUEST_ACCEPTED`, `QUEST_TURNED_IN` and `QUEST_LOG_UPDATE` update the window within the same event handler. Time-based checks (goto distance, arrow) run at least every 0.2 s.

### 3.3 Step window

- **Title:** the route name in the player's locale (`name.esES` when present and the client is esES/esMX, otherwise `name.enUS`).
- **Lines:** the current step, highlighted, followed by up to 2 upcoming steps.
- **Buttons:** `Back`, `Done` (only shown for manual steps) and `Skip`.
- **No matching route:** the window shows the "no route" text, with no buttons.
- **Behavior:** the window is draggable, keeps its position between sessions, and can be hidden or shown.

Step texts. `<title>` = `C_QuestLog.GetTitleForQuestID(questId)`. If the title is not cached yet, the fallback is `Quest #<id>`, and the text refreshes on `QUEST_DATA_LOAD_RESULT`. A step's own `text` field always replaces the generated text.

| Type | enUS | esES |
|---|---|---|
| accept | `Accept: <title>` | `Acepta: <title>` |
| complete | `Complete: <title>` | `Completa: <title>` |
| turnin | `Turn in: <title>` | `Entrega: <title>` |
| goto | `Go to <x>, <y>` | `Ve a <x>, <y>` |
| hearth | `Use your Hearthstone` | `Usa tu Piedra de hogar` |
| fly | `Take a flight` | `Toma un vuelo` |
| train | `Visit your class trainer` | `Visita a tu instructor de clase` |
| note | (the step `text`) | (the step `text`) |
| no route | `No route available for your character yet.` | `Todavía no hay ruta para tu personaje.` |
| route complete | `Route complete!` | `¡Ruta completada!` |

Buttons: `Back` / `Atrás`, `Done` / `Hecho`, `Skip` / `Saltar`. The x and y in `goto` use one decimal place.

Line contract:
- Each step line shows exactly the table text, with no prefix or numbering. Highlighting may only use color or texture escapes.
- Lines are font strings created top to bottom (current first), or a single multi-line font string.
- The current step is followed by the next 2 steps, or fewer near the end of the route.
- The title shows exactly the route name.
- Coordinates use `.` as the decimal separator in every locale.
- The fallback title is `Quest #<id>` (enUS) and `Misión #<id>` (esES).
- Timing: see §3.2 (synchronous reactions; time-based checks at least every 0.2 s).

### 3.4 Arrow

- **When shown:** the current step has `coords`, and the player's world position and facing are known. They are unknown (nil) in instances.
- **Distance:** computed in yards with `C_Map.GetWorldPosFromMapPos`. When the continents differ, the arrow is hidden.
- **Rotation:** `SetRotation(bearing - facing)` (radians, counterclockwise, 0 = north), so it points straight up when the target is in front of the player.
- **Label:** `<n> yd`, rounded to an integer.
- **Updates:** every 0.1 s while shown.
- **Visibility:** re-evaluated at least every 0.2 s, also while hidden, independent of zone events. The label is `<n> yd` in every locale.

### 3.5 Commands (chat prefix `La Ruta del 60: `)

| Command | Effect | enUS message | esES message |
|---|---|---|---|
| `/ruta` | unchanged | (version line) | (version line) |
| `/ruta list` / `/ruta lista` | lists the routes that match the character, one line each | `<id> - <name>` | same |
| `/ruta <id>` | switches to that route, step 1 | `Route: <name>` | `Ruta: <name>` |
| `/ruta <unknown id>` | nothing changes | `Unknown route: <id>` | `Ruta desconocida: <id>` |
| `/ruta reset` / `/ruta reiniciar` | back to step 1 of the current route, then catch-up; with no route it only prints the message | `Route restarted.` | `Ruta reiniciada.` |
| `/ruta show` / `/ruta mostrar` | shows the window | none | none |
| `/ruta hide` / `/ruta ocultar` | hides the window | none | none |

- Every chat line starts with `La Ruta del 60: `. `/ruta list` prints one such line per route, in any order.
- `/ruta list` shows routes matching faction, race and class; level is ignored.
- `/ruta <id>` accepts only ids that `/ruta list` would show. It switches to step 1 and then runs catch-up. Any other id prints `Unknown route: <id>` and changes nothing.
- Both aliases of each subcommand work in every locale.

## 4. Client emulation extension (`tests/support/`, additive)

The extension is additive. Existing functions keep their behavior, so the frozen tests still pass. `Client.boot(opts)` accepts these new optional fields:
- `player = { name, realm, faction, race, class, level }`. Defaults: `"Tester"`, `"Realm"`, `"Horde"`, `"Scourge"`, `"WARRIOR"`, `1`.
- `quests = { completed = {ids}, log = {ids}, ready = {ids}, titles = { [id] = "Title" } }`. A quest missing from `titles` returns nil until `client.loadQuestData(id)` fires `QUEST_DATA_LOAD_RESULT(id, true)` and sets the title to `"Quest Title <id>"`.
- `position = { mapId, x, y, facing }`, with x and y as percentages from 0 to 100. Nil position means an instance.
- `maps = { [mapId] = { continent = c, left = yards, top = yards, width = yards, height = yards } }`. These are the world rectangles used by `GetWorldPosFromMapPos`. Defaults cover the two maps used here: Tirisfal Glades 1420 and Silverpine Forest 1421 (the Classic uiMapIDs, still to verify on Forever), with continent 0. The routes must use whatever uiMapIDs `route-researcher` confirms. If those differ, the defaults are updated in the same change, before the code.

- `guides = { <route table>, ... }` plus `replaceGuides = true|false`. These emulate extra guide files appended to the TOC: each table is registered as `ns.Guides[route.id] = route` after the addon's own files. With `replaceGuides = true`, the addon's `Guides/Guides.xml` is skipped, so only the fixture routes exist. Engine acceptance tests use fixture routes defined in the tests, so route data changes never break them. The real routes are covered by the tools acceptance test (§5, "Routes").

New client actions, each firing the real event sequence:
- `client.acceptQuest(id)`: adds the quest to the log and fires `QUEST_ACCEPTED(id)` and `QUEST_LOG_UPDATE`.
- `client.completeObjectives(id)`: marks the quest ready and fires `QUEST_LOG_UPDATE`.
- `client.turnInQuest(id)`: removes the quest from the log, marks it completed, and fires `QUEST_TURNED_IN(id, 0, 0)`, `QUEST_REMOVED(id)` and `QUEST_LOG_UPDATE`.
- `client.moveTo(mapId, x, y)`, `client.face(radians)`, `client.enterInstance(mapId?)`: the last one keeps a non-nil current map (`GetBestMapForUnit` returns `mapId`, default 9999) while the map position and facing are nil.
- `client.levelUp(level)`: fires `PLAYER_LEVEL_UP(level)`.
- `client.advance(seconds)`: runs `OnUpdate` handlers with elapsed time, and fires due `C_Timer.After` and `C_Timer.NewTicker` callbacks.
- `client.reload()`: boots again, keeping `LaRutaDel60DB` and the player and quest state. This is the equivalent of `/reload`.

Emulated API surface:
- `C_QuestLog`: `IsQuestFlaggedCompleted`, `IsOnQuest`, `ReadyForTurnIn`, `GetTitleForQuestID`, `RequestLoadQuestByID`.
- `C_Map`: `GetBestMapForUnit`, `GetPlayerMapPosition` (returns a vector2 with `GetXY`, values 0-1), `GetWorldPosFromMapPos`.
- `CreateVector2D`, `GetPlayerFacing`.
- `UnitFactionGroup`, `UnitRace`, `UnitClass`, `UnitLevel`, `UnitName`, `GetRealmName`.
- `C_Timer.After`, `C_Timer.NewTicker` (with `:Cancel()`).
- Frames, black-box but inspectable:
  - `CreateFrame(type, name, parent, template)` returns objects with no-op layout methods: `SetPoint`, `SetSize`, `SetMovable`, `EnableMouse`, `RegisterForDrag`, `StartMoving`, `StopMovingOrSizing`, `SetClampedToScreen`, `SetFrameStrata`, `ClearAllPoints`. Backdrop methods (`SetBackdrop`, `SetBackdropColor`, `SetBackdropBorderColor`) exist only on frames created with a template containing `BackdropTemplate`.
  - `GetPoint` returns the last `SetPoint`.
  - `IsShown` is the frame's own flag; `IsVisible` includes the parents' visibility. The inspection helpers use `IsVisible`.
  - `CreateTexture` and `CreateFontString` return regions with `SetTexture`, `SetRotation`/`GetRotation`, `SetText`/`GetText` and `SetAllPoints`.
  - `"Button"` frames support `SetText`/`GetText` and an `OnClick` script.
- Inspection helpers:
  - `client.visibleTexts()`: the texts of all visible font strings and buttons, in creation order, with color and texture escape codes stripped; empty texts are excluded.
  - `client.click(label)`: runs `OnClick` of the visible button with that text (escape codes stripped), and errors if there is none.
  - `client.arrow()`: `{ shown, rotation, label }` of the visible texture whose rotation was set, or `{ shown = false }`. The arrow texture and its distance label live in their own frame: `label` is the visible font string with the same parent as the texture (the first created after it).
  - `client.drag(frameIndex, point...)`: simulates a drag that ends with a `SetPoint`. `frameIndex` indexes the movable (`SetMovable(true)`), mouse-enabled (`EnableMouse(true)`) frames in creation order.

Workflow for this extension:
1. Edit `tests/support/` and write the new acceptance tests.
2. Commit them in red. `check.sh`'s freeze step fails at this point; that is the allowed red-commit exception.
3. Move the tag with `git tag -f acceptance-frozen`. The user approved this move as part of this spec.

`docs/api/forever-api.md` gains a row for each emulated behavior, citing the source used by `wow-api-expert` (the Ketho annotations and warcraft.wiki.gg) and marking anything not yet verified on Forever.

## 5. Acceptance criteria (black box, written before the code)

**Selection:**
- An Undead level 1 character sees the Tirisfal route name as the window title.
- An Undead level 13 character with no saved progress gets the Silverpine route.
- An Orc character sees the "no route" text.
- An Alliance character sees the "no route" text.
- Saved progress on a route that exists but no longer matches the race or faction is replaced by a new selection.

**Steps:**
- The first step text matches the table, including the fallback title and its refresh after `QUEST_DATA_LOAD_RESULT`.
- The fallback title is `Misión #<id>` on esES.

**Advance:**
- accept, complete, turnin and goto each advance through the client actions.
- `goto` does not advance at 11 yards and does advance at 9 yards.
- The manual types advance on **Done**.
- **Done** is not shown for automatic types.
- **Skip** and **Back** work.
- `QUEST_ACCEPTED` with two arguments (quest ID last) advances the accept step.
- **Back** on step 1 does nothing.

**Catch-up:**
- With quests already in the log or completed, login lands on the first step that is not satisfied.
- **Back** onto a satisfied step stays there.
- **Skip** onto a satisfied step auto-skips it.

**Persistence:**
- After `client.reload()` the same step is shown.
- Two characters on the same account keep separate progress.

**Chaining:**
- Finishing Tirisfal shows the Silverpine route at step 1, after catch-up.
- Finishing the last route shows "route complete".
- **Skip** on the last step chains to `next`, or shows "route complete" when there is no `next`.
- On "route complete" only **Back** is shown among the buttons, and it returns to the last step.

**Arrow:**
- Shown, with the distance label, when the target is on the same continent.
- Rotation ≈ 0 when facing the target, and ≈ π/2 when the target is 90° to the left.
- Hidden for steps without coordinates, inside instances, and when the continent differs.

**Commands:**
- Each row of §3.5 in both locales, and plain `/ruta` unchanged.
- `/ruta hide` / `/ruta show` toggle the window's visibility.
- `/ruta list` ignores level: at level 1 it lists both Undead routes.
- `/ruta <id>` runs catch-up after switching.
- `/ruta <id>` with an existing id that does not match the character prints `Unknown route: <id>` and changes nothing.

**Hygiene:**
- No new globals after login, routes, actions and reload.
- Login chat output unchanged.

**Routes (tools acceptance test):**
- `horde-tirisfal-1-12` and `horde-silverpine-12-20` exist and are valid.
- Both are `faction: Horde` with `races: ["Scourge"]`.
- Tirisfal has `minLevel` 1 and `next` = Silverpine; Silverpine has `maxLevel` 20.
- Every quest step has a `source` URL on wowhead.com/forever.
- The example route is gone.

## 6. Route data

The routes are built with the `add-route-segment` skill: `route-researcher` → `route-optimizer` → `route-validator`.
- **Source:** Wowhead Forever (client 1.60.1). Use only public quest databases; RestedXP or paid guides are never copied.
- **Coordinates:** uiMap percentages.
- **Quest coverage:** new Forever quests (for example the Tirisfal IDs listed by AllTheThings PR #2667) are included where they give good XP per minute.
- **Pending verification:** data the researcher could only find for Classic Era is flagged `forever: false` in `data/raw`, and the user checks it in game.

## 7. Risks

- No emulated API has been verified inside the Forever client yet. The user's first in-game test is the verification, and the `debug-in-game` skill turns any mismatch into a test.
- `BackdropTemplate` availability is uncertain. The window uses plain textures for its background, not backdrops.
- Quest data quality depends on Wowhead Forever right after launch. Mistakes are fixed as data, without engine changes.
