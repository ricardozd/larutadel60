---
name: debug-in-game
description: Usar cuando el usuario pegue un error del juego (BugSack/BugGrabber, mensaje de chat, Lua error) o su SavedVariables, o diga que algo del addon no funciona en WoW. Convierte el fallo en un test de aceptación que lo reproduce y luego lo arregla.
---

# Depurar un fallo del juego

Usa también `superpowers:systematic-debugging`.

1. Pide lo que falte: error completo con stack (en BugSack, copiar), versión del addon (`/ruta`), qué estaba haciendo y, si es de datos, `WTF\Account\<CUENTA>\SavedVariables\LaRutaDel60.lua`.
2. Localiza el `archivo:línea` del stack dentro de `addon/LaRutaDel60`. Si el error está en código de Blizzard, busca qué llamada nuestra lo provoca.
3. "attempt to call a nil value" sobre una API de WoW = API inexistente en Forever → agente `wow-api-expert`.
4. Escribe un test de aceptación en `tests/acceptance/` que reproduzca lo que vio el jugador. Si hace falta, amplía la emulación de `tests/support/` con el comportamiento real observado y documéntalo en `docs/api/forever-api.md`. Debe fallar. Commit en rojo y avisa al usuario de que ese test queda congelado.
5. Arregla, deja `tools/check.sh` en verde y haz commit `fix: ...`.
6. Pide al usuario que lo verifique en el juego (`scripts\deploy.ps1` + `/reload`).
