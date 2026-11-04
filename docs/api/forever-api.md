# WoW Forever API — verified knowledge

The project's source of truth about the API. Every entry carries a date and a source. The mocks in `tests/support/wow_mock.lua` may only imitate APIs from this document.

## Client
- Version 1.60.1, `## Interface: 16001`. Release 2026-11-04. (2026-11-03, github.com/everbuff/everbuff-wow-addon/issues/1)
- TOCs with a `_Forever` or `_Camelot` suffix take priority; `[AllowLoadGameType camelot]` marks Forever-only files. (2026-11-03, forevermeta.me)
- `WOW_PROJECT_CAMELOT = 18`; in Forever `WOW_PROJECT_ID == WOW_PROJECT_CAMELOT` (since build 70170). (2026-11-03, forevermeta.me)

## API architecture
- Shares the UI architecture and most APIs of retail 12.1.5 (C_QuestLog, C_Map, C_Item, C_Spell, C_Traits). A Classic Era addon does not load as is. (2026-11-03, Blizzard in the UI dev Discord, via forevermeta.me)
- Midnight "secrets" restrictions active. (idem)
- About 1,041 retail FrameXML globals removed in 1.60.1. List: warcraft.wiki.gg, page "Patch 1.60.1/API changes".
- Quest titles: `C_QuestLog.GetTitleForQuestID`. (2026-11-03, addon changelogs)

## Client behavior emulated by the tests
| Behavior | Emulation in `tests/support/` | Source |
|---|---|---|
| Loads files in TOC order; `.xml` files load their `<Script file>`; each file receives `(addonName, ns)` | `client.lua` | warcraft.wiki.gg/wiki/TOC_format |
| SavedVariables: restored after running the addon files and before `ADDON_LOADED` | `client.lua` | warcraft.wiki.gg/wiki/Saving_variables_between_game_sessions |
| Event order on login: `ADDON_LOADED` → `PLAYER_LOGIN` | `client.lua` | warcraft.wiki.gg/wiki/AddOn_loading_process |
| `CreateFrame(type, name)` with `name` registers the frame as global `_G[name]` | `wow_mock.lua` | warcraft.wiki.gg/wiki/API_CreateFrame |
| Slash: for each `KEY` in `SlashCmdList`, the aliases are `SLASH_<KEY>1`, `SLASH_<KEY>2`... | `client.lua` | warcraft.wiki.gg/wiki/Creating_a_slash_command |
| `/reload`: new Lua state; SavedVariables are serialized (a copy; functions dropped) and restored before `ADDON_LOADED`; `PLAYER_LOGIN` fires again. Player, quest and position state are kept | `client.reload()` | warcraft.wiki.gg/wiki/AddOn_loading_process |
| Extra guide files appended to the TOC (`opts.guides`); `opts.replaceGuides` skips `Guides/Guides.xml` | `client.lua` | test-only (spec §4) |
| `QUEST_ACCEPTED(questID)`: one argument, as in retail | `client.acceptQuest(id)`: log += id, then `QUEST_ACCEPTED(id)`, `QUEST_LOG_UPDATE` | Ketho annotations (Data/Event.lua). Not verified on Forever |
| Quest objectives done: `ReadyForTurnIn` becomes true; `QUEST_LOG_UPDATE` | `client.completeObjectives(id)` | Ketho annotations. Not verified on Forever |
| Turn-in: `QUEST_TURNED_IN(questID, xpReward, moneyReward)`, `QUEST_REMOVED(questID, wasReplayQuest)`, `QUEST_LOG_UPDATE` | `client.turnInQuest(id)` fires `(id, 0, 0)`, `(id, false)`, then `QUEST_LOG_UPDATE` | Ketho annotations. Not verified on Forever |
| Uncached quest title: `GetTitleForQuestID` returns nil until `QUEST_DATA_LOAD_RESULT(questID, success)` | `client.loadQuestData(id)`: title `"Quest Title <id>"`, fires `(id, true)` | Ketho annotations, warcraft.wiki.gg/wiki/API_C_QuestLog.RequestLoadQuestByID. Not verified on Forever |
| `PLAYER_LEVEL_UP(level)`; `UnitLevel("player")` may still return the old level inside the handler | `client.levelUp(level)` updates the level after the event | warcraft.wiki.gg/wiki/PLAYER_LEVEL_UP. Not verified on Forever |
| Position and instances: inside an instance `C_Map.GetBestMapForUnit("player")` still returns the instance's own uiMapID, while `GetPlayerMapPosition` and `GetPlayerFacing` return nil. `GetPlayerMapPosition` also returns nil for any map other than the current one. A nil uiMapID passed to `GetPlayerMapPosition` / `GetWorldPosFromMapPos` is a Lua error ("bad argument #1 ..."), like real C_ functions | `opts.position` (no position = instance 9999), `client.moveTo(mapId, x%, y%)`, `client.face(radians)` (facing normalized to [0, 2π)), `client.enterInstance(mapId?)` (default 9999, exposed as `Client.INSTANCE_MAP`) | warcraft.wiki.gg/wiki/API_C_Map.GetBestMapForUnit, API_C_Map.GetPlayerMapPosition, API_GetPlayerFacing. Not verified on Forever |
| World coordinates: world X grows to the **north**, world Y grows to the **west**; map x grows east and map y grows south. So `worldX = top - mapY * height`, `worldY = left - mapX * width`, and the bearing to a target, counterclockwise from north like `GetPlayerFacing`, is `atan2(targetY - playerY, targetX - playerX)` | `opts.maps` rectangles `{ continent, left, top, width, height }` in yards; defaults 1420 and 1421 (continent 0) are approximations, not real data | warcraft.wiki.gg/wiki/API_C_Map.GetWorldPosFromMapPos (Elwynn example: map (0,0) → (-7939.6, 1535.4), (1,1) → (-10254.2, -1935.4)); HereBeDragons. Not verified on Forever |
| `OnUpdate(self, elapsed)` runs every rendered frame on visible frames only; `C_Timer` callbacks fire when due (the ticker receives itself) | `client.advance(seconds)` in 50 ms frames; due timers run before OnUpdate in each frame; `After(0)` fires on the next frame; `advance(0)` does nothing. `elapsed` is 0.05 (a float), so accumulator patterns like `acc >= 0.2` can fire one frame late: tests should advance with some slack | warcraft.wiki.gg/wiki/UIHANDLER_OnUpdate, API_C_Timer.NewTicker |
| `IsShown` is the frame's own flag; `IsVisible` also requires every parent to be shown; frames and regions start shown | `wow_mock.lua` | warcraft.wiki.gg/wiki/API_ScriptRegion_IsShown, API_ScriptRegion_IsVisible |
| Event coverage: the emulation fires `ADDON_LOADED`, `PLAYER_LOGIN`, quest events, `PLAYER_LEVEL_UP`. It does **not** fire `PLAYER_ENTERING_WORLD` nor `PLAYER_LOGOUT`, so the engine must not depend on them | `client.lua`, `wow_mock.lua` | test-only |
| Quest state timing: the emulation updates quest state before firing the events. The real client may lag (e.g. `IsOnQuest` inside `QUEST_ACCEPTED`), so the engine should also re-check state on `QUEST_LOG_UPDATE` | `wow_mock.lua` | warcraft.wiki.gg/wiki/QUEST_ACCEPTED. Not verified on Forever |
| Backdrops: since 9.0 `SetBackdrop`, `SetBackdropColor`, `SetBackdropBorderColor` exist only on frames inheriting `BackdropTemplate` | `wow_mock.lua` | warcraft.wiki.gg/wiki/BackdropTemplate. Availability on Forever not verified |
| `OnClick` only exists on buttons (`SetScript` errors on a plain Frame) | `wow_mock.lua` | warcraft.wiki.gg/wiki/UIHANDLER_OnClick |
| Inspection: `client.visibleTexts()` and `client.click(label)` compare text with only these escapes stripped: `|cAARRGGBB`, `|cn<NAME>:` (named colors), `|r`, `|T...|t` (textures), `|A...|a` (atlases), and `||` shown as `|`, and ignore empty texts; `client.arrow()` = the first visible texture whose rotation was set (rotation normalized to [-π, π)), its `label` is the visible font string with the same parent frame (the first created after the texture); `client.drag(i, point...)` (i = i-th frame with `SetMovable(true)` and `EnableMouse(true)`), `client.movableFrames()`. All helpers use `IsVisible` | `wow_mock.lua` | test-only (spec §4) |

## Emulated / used APIs
| API | Use | Verified |
|---|---|---|
| `C_AddOns.GetAddOnMetadata(addon, field)` | `## Field:` fields of the TOC | Ketho annotations |
| `CreateFrame("Frame")`, `:RegisterEvent`, `:UnregisterEvent`, `:SetScript("OnEvent")` | events | Ketho annotations |
| `DEFAULT_CHAT_FRAME:AddMessage(msg)`, `print(...)` | chat | Ketho annotations |
| `GetLocale()` | client locale | Ketho annotations |
| `WOW_PROJECT_ID`, `WOW_PROJECT_CAMELOT`, `WOW_PROJECT_MAINLINE` | detection | forevermeta.me |
| `C_QuestLog.IsQuestFlaggedCompleted(id)`, `.IsOnQuest(id)`, `.ReadyForTurnIn(id)`, `.GetTitleForQuestID(id)`, `.RequestLoadQuestByID(id)` | quest state and titles | Ketho annotations. Not verified on Forever |
| `C_Map.GetBestMapForUnit("player")` → uiMapID or nil | current map | Ketho annotations. Not verified on Forever |
| `C_Map.GetPlayerMapPosition(uiMapID, "player")` → vector2 (`:GetXY()`, 0-1) or nil | map position | Ketho annotations. Not verified on Forever |
| `C_Map.GetWorldPosFromMapPos(uiMapID, vector2)` → `continentID, vector2(worldX, worldY)` in yards | distances, bearing | Ketho annotations, warcraft.wiki.gg. Not verified on Forever |
| `CreateVector2D(x, y)` → vector2 with `.x`, `.y`, `:GetXY()` | map positions | Ketho annotations (FrameXML Vector2D) |
| `GetPlayerFacing()` → radians, 0 = north, counterclockwise; nil in instances | arrow | Ketho annotations, warcraft.wiki.gg/wiki/API_GetPlayerFacing. Not verified on Forever |
| `UnitName("player")`, `GetRealmName()` | character key | Ketho annotations |
| `UnitFactionGroup("player")` → `"Horde"`/`"Alliance"`, localized | selection | Ketho annotations |
| `UnitRace("player")` → localized, English token (Undead = `"Scourge"`), raceID (the emulation returns enUS localized names on every locale) | selection | Ketho annotations, warcraft.wiki.gg/wiki/API_UnitRace |
| `UnitClass("player")` → localized, class file (`"WARRIOR"`...), classID (the emulation returns enUS localized names on every locale) | selection | Ketho annotations |
| `UnitLevel("player")` | selection | Ketho annotations |
| `C_Timer.After(seconds, cb)`, `C_Timer.NewTicker(seconds, cb, iterations?)` → ticker with `:Cancel()` | polling | Ketho annotations |
| `UIParent` | parent of the addon's frames | Ketho annotations (FrameXML) |
| Frames: `CreateFrame(type, name, parent, template)`; layout methods (`SetPoint`, `GetPoint`, `ClearAllPoints`, `SetSize`, `SetMovable`, `EnableMouse`, `RegisterForDrag`, `StartMoving`, `StopMovingOrSizing`, `SetClampedToScreen`, `SetFrameStrata`; `SetBackdrop*` only with a template containing `BackdropTemplate`); `GetName`; `Button:GetFontString` (nil until `SetText`, unless a `*ButtonTemplate` template provides the label); `Show`/`Hide`/`IsShown`/`IsVisible`; `CreateTexture` (`SetTexture`, `SetRotation`/`GetRotation`), `CreateFontString` (`SetText`/`GetText`); `Button` (`SetText`/`GetText`, `OnClick`, `Enable`/`Disable`) | step window, arrow | Ketho annotations. `BackdropTemplate` availability not verified on Forever |
| Widget methods used by the step window and arrow, beyond the row above: `Region:SetAllPoints`, `Region:SetShown`, `Texture:SetColorTexture(r, g, b, a)` (window background, no backdrop), `FontString:SetJustifyH` | step window, arrow | Ketho annotations (`Annotations/Core/Widget`). Not verified on Forever |
| FrameXML templates and art: `GameFontNormal` / `GameFontHighlight` (font string templates), `UIPanelButtonTemplate` (button with label), texture `Interface\\Minimap\\MinimapArrow` (arrow pointing up) | step window, arrow | FrameXML (retail). Not verified on Forever |

## To be verified in game
- Forever install folder on Windows (`_forever_`, `_camelot_`...). `scripts/deploy.ps1` tries several.

## Tooling
- LSP: `wow-lua-lsp` plugin (lua-language-server 3.19 + Ketho mainline annotations in `.vendor/`).
- `.luarc.json` declares `SlashCmdList`, `DEFAULT_CHAT_FRAME` and `WOW_PROJECT_CAMELOT` as globals because Ketho's `Annotations/FrameXML` is a git submodule that `tools/fetch_annotations.sh` does not download, so LuaLS does not know them. `WOW_PROJECT_CAMELOT` is also Forever-exclusive (it does not exist in the Classic annotations).
