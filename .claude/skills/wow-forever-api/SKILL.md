---
name: wow-forever-api
description: Use before writing or reviewing Lua code that calls the WoW API in this project (WoW Forever 1.60.1, Interface 16001). Explains how to verify an API, which architecture Forever uses and what to touch when adding a new API.
---

# WoW Forever API

Forever = modern retail 12.x API on Lua 5.1, with the Midnight restrictions. It is NOT the Classic Era 1.15 API nor the 1.12 one.

## Before using an API
1. Check `docs/api/forever-api.md`. If it is there, use it.
2. If it is not: `Grep` in `.vendor/vscode-wow-api/Annotations/Core` (signature and types). If it is not there either, do NOT use it.
3. If it concerns quests, map, gossip or items, or there are doubts about Forever: delegate to the `wow-api-expert` agent.

## When adding an API to the code
- Put it in `read_globals` of `.luacheckrc` (only the root name, e.g. `C_QuestLog`).
- Add its row in "Emulated / used APIs" of `docs/api/forever-api.md`, with the source.
- If the feature's acceptance tests need it, the emulation in `tests/support/wow_mock.lua` is extended **as part of writing those tests** (before the code), never to make an implementation pass. Only NEW test files (`*_spec.lua`) are added and `tests/support/` is only extended additively (new emulated functions or APIs) without changing existing behavior. Any change in `tests/support/` requires explicit user approval, because `lua-reviewer` treats it as critical. Never modify existing tests or emulations; if one looks wrong, STOP and ask the user.

## Key events for a leveling guide (verify each one before using it)
QUEST_ACCEPTED, QUEST_TURNED_IN, QUEST_REMOVED, QUEST_LOG_UPDATE, QUEST_DETAIL, QUEST_PROGRESS, QUEST_COMPLETE, GOSSIP_SHOW, QUEST_GREETING, PLAYER_LEVEL_UP, PLAYER_XP_UPDATE, ZONE_CHANGED_NEW_AREA, TAXIMAP_OPENED.

## Common pitfalls
- Protected functions and combat: check `InCombatLockdown()` before touching secure frames.
- Classic Era APIs (`GetQuestLogTitle`, `GetNumQuestLogEntries`) may not exist: use `C_QuestLog.*`.
- Coordinates: `C_Map.GetPlayerMapPosition(uiMapID, "player")` returns a `Vector2DMixin` (`pos:GetXY()`, values 0-1) or `nil` (e.g. in instances), not two numbers, whereas the guide format uses 0-100.
