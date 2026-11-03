# API de WoW Forever — conocimiento verificado

Fuente de verdad del proyecto sobre la API. Cada entrada lleva fecha y fuente. Los mocks de `tests/support/wow_mock.lua` solo pueden imitar APIs de este documento.

## Cliente
- Versión 1.60.1, `## Interface: 16001`. Lanzamiento 2026-11-04. (2026-11-03, github.com/everbuff/everbuff-wow-addon/issues/1)
- Los TOC con sufijo `_Forever` o `_Camelot` tienen prioridad; `[AllowLoadGameType camelot]` marca archivos solo-Forever. (2026-11-03, forevermeta.me)
- `WOW_PROJECT_CAMELOT = 18`; en Forever `WOW_PROJECT_ID == WOW_PROJECT_CAMELOT` (desde la build 70170). (2026-11-03, forevermeta.me)

## Arquitectura de la API
- Comparte la arquitectura de UI y la mayoría de APIs de retail 12.1.5 (C_QuestLog, C_Map, C_Item, C_Spell, C_Traits). Un addon de Classic Era no carga tal cual. (2026-11-03, Blizzard en el Discord de UI dev, vía forevermeta.me)
- Restricciones de "secrets" de Midnight activas. (ídem)
- Unos 1.041 globales de FrameXML de retail eliminados en la 1.60.1. Lista: warcraft.wiki.gg, página "Patch 1.60.1/API changes".
- Títulos de quest: `C_QuestLog.GetTitleForQuestID`. (2026-11-03, changelogs de addons)

## Comportamiento del cliente que emulan los tests
| Comportamiento | Emulación en `tests/support/` | Fuente |
|---|---|---|
| Carga los archivos en el orden del TOC; los `.xml` cargan sus `<Script file>`; cada archivo recibe `(addonName, ns)` | `client.lua` | warcraft.wiki.gg/wiki/TOC_format |
| SavedVariables: se restauran tras ejecutar los archivos del addon y antes de `ADDON_LOADED` | `client.lua` | warcraft.wiki.gg/wiki/Saving_variables_between_game_sessions |
| Orden de eventos al entrar: `ADDON_LOADED` → `PLAYER_LOGIN` | `client.lua` | warcraft.wiki.gg/wiki/AddOn_loading_process |
| Slash: para cada `KEY` de `SlashCmdList`, los alias son `SLASH_<KEY>1`, `SLASH_<KEY>2`... | `client.lua` | warcraft.wiki.gg/wiki/Creating_a_slash_command |

## APIs emuladas / usadas por el addon
| API | Uso | Verificado |
|---|---|---|
| `C_AddOns.GetAddOnMetadata(addon, field)` | campos `## Field:` del TOC | anotaciones Ketho |
| `CreateFrame("Frame")`, `:RegisterEvent`, `:UnregisterEvent`, `:SetScript("OnEvent")` | eventos | anotaciones Ketho |
| `DEFAULT_CHAT_FRAME:AddMessage(msg)`, `print(...)` | chat | anotaciones Ketho |
| `GetLocale()` | locale del cliente | anotaciones Ketho |
| `WOW_PROJECT_ID`, `WOW_PROJECT_CAMELOT`, `WOW_PROJECT_MAINLINE` | detección | forevermeta.me |

## Pendiente de verificar en el juego
- Carpeta de instalación de Forever en Windows (`_forever_`, `_camelot_`...). `scripts/deploy.ps1` prueba varias.

## Tooling
- LSP: plugin `wow-lua-lsp` (lua-language-server 3.19 + anotaciones Ketho mainline en `.vendor/`).
