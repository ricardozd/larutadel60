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

## Emulated / used APIs
| API | Use | Verified |
|---|---|---|
| `C_AddOns.GetAddOnMetadata(addon, field)` | `## Field:` fields of the TOC | Ketho annotations |
| `CreateFrame("Frame")`, `:RegisterEvent`, `:UnregisterEvent`, `:SetScript("OnEvent")` | events | Ketho annotations |
| `DEFAULT_CHAT_FRAME:AddMessage(msg)`, `print(...)` | chat | Ketho annotations |
| `GetLocale()` | client locale | Ketho annotations |
| `WOW_PROJECT_ID`, `WOW_PROJECT_CAMELOT`, `WOW_PROJECT_MAINLINE` | detection | forevermeta.me |

## To be verified in game
- Forever install folder on Windows (`_forever_`, `_camelot_`...). `scripts/deploy.ps1` tries several.

## Tooling
- LSP: `wow-lua-lsp` plugin (lua-language-server 3.19 + Ketho mainline annotations in `.vendor/`).
- `.luarc.json` declares `SlashCmdList`, `DEFAULT_CHAT_FRAME` and `WOW_PROJECT_CAMELOT` as globals because Ketho's `Annotations/FrameXML` is a git submodule that `tools/fetch_annotations.sh` does not download, so LuaLS does not know them. `WOW_PROJECT_CAMELOT` is also Forever-exclusive (it does not exist in the Classic annotations).
