---
name: wow-forever-api
description: Usar antes de escribir o revisar código Lua que llame a la API de WoW en este proyecto (WoW Forever 1.60.1, Interface 16001). Explica cómo verificar una API, qué arquitectura usa Forever y qué tocar al añadir una API nueva.
---

# API de WoW Forever

Forever = API moderna de retail 12.x sobre Lua 5.1, con las restricciones de Midnight. NO es la API de Classic Era 1.15 ni la de 1.12.

## Antes de usar una API
1. Mira `docs/api/forever-api.md`. Si está, úsala.
2. Si no está: `Grep` en `.vendor/vscode-wow-api/Annotations/Core` (firma y tipos). Si tampoco está ahí, NO la uses.
3. Si es de quests, mapa, gossip o items, o hay dudas sobre Forever: delega en el agente `wow-api-expert`.

## Al añadir una API al código
- Ponla en `read_globals` de `.luacheckrc` (solo el nombre raíz, p. ej. `C_QuestLog`).
- Añade su fila en "APIs emuladas / usadas por el addon" de `docs/api/forever-api.md`, con la fuente.
- Si los tests de aceptación de la funcionalidad la necesitan, la emulación de `tests/support/wow_mock.lua` se amplía **como parte de escribir esos tests** (antes del código), nunca para que pase una implementación.

## Eventos clave para una guía de leveo (verificar cada uno antes de usarlo)
QUEST_ACCEPTED, QUEST_TURNED_IN, QUEST_REMOVED, QUEST_LOG_UPDATE, QUEST_DETAIL, QUEST_PROGRESS, QUEST_COMPLETE, GOSSIP_SHOW, QUEST_GREETING, PLAYER_LEVEL_UP, PLAYER_XP_UPDATE, ZONE_CHANGED_NEW_AREA, TAXIMAP_OPENED.

## Trampas habituales
- Funciones protegidas y combate: comprueba `InCombatLockdown()` antes de tocar frames seguros.
- APIs de Classic Era (`GetQuestLogTitle`, `GetNumQuestLogEntries`) pueden no existir: usa `C_QuestLog.*`.
- Coordenadas: `C_Map.GetPlayerMapPosition(uiMapID, "player")` devuelve 0-1, mientras que el formato de guía usa 0-100.
