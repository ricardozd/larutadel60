# Classic Era compatibility (design)

Date: 2026-11-04
Status: approved by the user ("vamos a ello, classic era"), as the way to test the addon before WoW Forever launches.

## Goal
The addon loads and works in **WoW Classic Era / Hardcore 1.15.x**, so the engine (step window, arrow, advance, commands) can be tested in a live client before Forever is out. Quest steps that exist only in Forever are expected to stay as `Quest #<id>`, and the player skips them. Making the routes Classic-correct is out of scope.

## Facts (verified by `wow-api-expert` on warcraft.wiki.gg, 2026-11-04)
- **Interface and TOC:** Classic Era uses `## Interface: 11509` and loads `<Addon>_Vanilla.toc` with priority.
- **Project ID:** `WOW_PROJECT_ID` = `WOW_PROJECT_CLASSIC` = 2. `WOW_PROJECT_CAMELOT` is not guaranteed to exist.
- **Missing in 1.15:**
  - `C_QuestLog.ReadyForTurnIn`. Fallback: `GetQuestLogIndexByID(questID)`, which returns 0 when the quest is not in the log, then the 6th return of `GetQuestLogTitle(index)` (`isComplete == 1`).
  - `C_QuestLog.GetTitleForQuestID`. Fallback: `C_QuestLog.GetQuestInfo(questID)`, which returns the title, or nil or `""` when it is unknown.
  - `C_QuestLog.RequestLoadQuestByID` and `QUEST_DATA_LOAD_RESULT`: uncertain, so guard them.
- **`QUEST_ACCEPTED`:** Classic sends `(questLogIndex, questID)`. The engine already reads the last argument.
- **Present in 1.15:** everything else the addon uses, including `C_AddOns.GetAddOnMetadata` (since 1.14.4), `C_QuestLog.IsQuestFlaggedCompleted` and `IsOnQuest`, the C_Map position and world APIs, `GetPlayerFacing` and `C_Timer`. Some of these are marked uncertain or probable in docs/api; the in-game test confirms them.

## Changes
1. **`addon/LaRutaDel60/LaRutaDel60_Vanilla.toc`:** the same file list and fields as `LaRutaDel60.toc`, with `## Interface: 11509`. Rule: all TOCs share the same file list, and only the `## Interface:` line may differ. The base TOC and the `_Forever` TOC stay byte-identical, which the frozen test requires.
2. **`Core/Game.lua`** is the only place with flavor differences. It uses feature detection, never project-ID branching:
   - "ready for turn-in" uses `C_QuestLog.ReadyForTurnIn` when present, otherwise the `GetQuestLogIndexByID` + `GetQuestLogTitle` fallback;
   - the title uses `C_QuestLog.GetTitleForQuestID` when present, otherwise `C_QuestLog.GetQuestInfo`, where `""` counts as unknown;
   - `RequestLoadQuestByID` is called only when it exists;
   - Forever detection must not error when `WOW_PROJECT_CAMELOT` is nil (it already compares safely).
3. **Player-visible behavior on Classic Era:** the login shows the existing "not WoW Forever" warning before "Loaded". Everything else is as specified in the engine spec. Unknown titles keep the fallback `Quest #<id>` / `Misión #<id>`.
4. **Supporting files:**
   - `scripts/deploy.ps1` also looks for `_classic_era_` (after `_forever_`, before `_classic_`);
   - the `release` skill bumps the version in all three TOCs;
   - the CI release job's TOC/tag check keeps reading the base TOC;
   - the README gets a "Testing on Classic Era" note.

## Emulation extension (tests/support, additive)
`Client.boot({ flavor = "classic_era" })` emulates 1.15:
- **TOC:** loads `LaRutaDel60_Vanilla.toc` instead of the base TOC.
- **Project ID:** `WOW_PROJECT_ID = 2`, `WOW_PROJECT_CLASSIC = 2`, and no `WOW_PROJECT_CAMELOT` global.
- **Removed:** `C_QuestLog.ReadyForTurnIn`, `C_QuestLog.GetTitleForQuestID`, `C_QuestLog.RequestLoadQuestByID`. `client.loadQuestData` is not available, and `QUEST_DATA_LOAD_RESULT` never fires.
- **Added:**
  - `GetQuestLogIndexByID(id)`: 1-based position in the log, or 0;
  - `GetQuestLogTitle(i)`: returns `title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID`, with `isComplete = 1` when ready and nil otherwise;
  - `C_QuestLog.GetQuestInfo(id)`: the title from `opts.quests.titles`, or nil.
- **Events:** `QUEST_ACCEPTED` fires `(logIndex, questID)`.
- **Default flavor:** stays `"forever"`, so existing tests are unchanged.

## Acceptance criteria (new tests, written first)
- **TOC:** `LaRutaDel60_Vanilla.toc` exists, has `## Interface: 11509`, and has the same non-`Interface` lines as the base TOC.
- **Login:** on `classic_era`, login shows exactly the warning and then "Loaded" (enUS and esES).
- **Selection and display:** an Undead level 1 character gets the Undead route title, and the first step text uses the `GetQuestInfo` title.
- **Advance:** accept, complete and turn-in advance on `classic_era`. Complete goes through the `GetQuestLogTitle` path.
- **Unknown titles:** an unknown title shows `Quest #<id>` and nothing errors.
- **Arrow:** shown with a distance on `classic_era` when coords and a position exist.
- **Hygiene:** no Lua errors and no new globals on `classic_era`.
