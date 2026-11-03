# La Ruta del 60

Addon gratuito para **WoW Forever** (Classic+ oficial, cliente 1.60.1, `## Interface: 16001`) que guía a cualquier personaje de 1 a 60 por la ruta más rápida. Se desarrolla 100% con IA en macOS y se juega en Windows.

## Reglas
- **Idioma:** el código va SIEMPRE en inglés (identificadores, comentarios, strings, mensajes de CLI, nombres de tests y commits). Las explicaciones van SIEMPRE en castellano (chat, specs, planes, este archivo, agentes y skills). Los textos al jugador se localizan en enUS y esES.
- **Tests de aceptación primero:** antes de escribir código de una funcionalidad hay tests de caja negra derivados de su spec, commiteados en rojo. `tests/acceptance/`, `tests/support/` y `tools/tests/acceptance/` están **congelados**: se ponen en verde sin modificarlos. Si un test parece mal, PARA y pregunta al usuario.
  - El congelado se hace cumplir con el tag `acceptance-frozen`: `tools/check.sh` (y el CI) falla si algo modificado, borrado o renombrado respecto al tag cambia bajo esas rutas, tanto en el working tree como en commits. Añadir tests nuevos está permitido.
  - Una funcionalidad nueva añade tests de aceptación NUEVOS; tras commitearlos en rojo se mueve el tag (`git tag -f acceptance-frozen`), solo con aprobación del usuario.
  - El push debe incluir los tags (`git push --follow-tags` o `git push origin acceptance-frozen`; si se movió, `--force` sobre ese tag con aprobación del usuario).
- **API:** Forever usa la API moderna de retail 12.x sobre Lua 5.1, no la de Classic Era. Antes de usar cualquier API de WoW: skill `wow-forever-api` / agente `wow-api-expert`. Lo verificado está en `docs/api/forever-api.md`.
- **Lua 5.1:** sin `goto`, `//`, operadores de bits nativos, `<const>`.
- **Sin globals:** todo en `ns` (`local ADDON_NAME, ns = ...`). Solo se permiten `LaRutaDel60DB`, `SLASH_LARUTADEL601` y `SlashCmdList.LARUTADEL60`.
- **Rutas = datos:** `data/routes/**/*.json` (skill `guide-format`). `addon/LaRutaDel60/Guides/` es GENERADO: nunca se edita a mano.
- **TOC:** `LaRutaDel60.toc` y `LaRutaDel60_Forever.toc` siempre idénticos.
- **Textos al jugador:** siempre vía `ns.L`, con clave en `Locales/enUS.lua` y `Locales/esES.lua`.
- **Original:** no se copia código ni guías de RestedXP u otros addons.
- Commits pequeños con Conventional Commits. No se hace push sin que el usuario lo pida.

## Puesta en marcha (clon nuevo, macOS)
1. `tools/setup.sh`: instala el toolchain y las anotaciones de la API. Si `~/.luarocks/bin` no está en el PATH, avisa: añádelo tú en tu perfil de shell (`check.sh` funciona igual).
2. Plugin LSP para Claude Code (necesita `lua-language-server` en el PATH): `claude plugin marketplace add ./` y luego `claude plugin install wow-lua-lsp@larutadel60 --scope project`. Después, reinicia Claude Code.
3. `tools/check.sh` tiene que terminar en `OK: all green`.

## Comandos
| Qué | Comando |
|---|---|
| Verificación completa (obligatoria antes de commit) | `tools/check.sh` |
| Tests Lua | `~/.luarocks/bin/busted` (o `busted`) |
| Tests Python | `python3 -m unittest discover -s tools/tests -t . -q` |
| Validar / compilar rutas | `python3 tools/validate_routes.py` / `python3 tools/compile_guides.py` |
| LuaLS | `tools/luals_check.sh` |
| Instalar el toolchain (macOS) | `tools/setup.sh` |
| Instalar en Windows | `scripts\deploy.ps1` (PowerShell) |

Los hooks de `.claude/settings.json` formatean y lintan cada `.lua` editado y validan cada JSON de rutas. Si devuelven error, corrígelo antes de seguir.

## Agentes (`.claude/agents/`)
- `wow-api-expert`: verifica APIs de Forever (solo lectura).
- `addon-engineer`: implementa código del addon contra tests de aceptación.
- `route-researcher`: datos crudos de quests desde la web → `data/raw/`.
- `route-optimizer`: construye rutas óptimas → `data/routes/`.
- `route-validator`: revisa la coherencia de las rutas (solo lectura).
- `lua-reviewer`: revisión de código antes de commit (solo lectura).

## Skills (`.claude/skills/`)
`wow-forever-api`, `guide-format`, `add-route-segment`, `new-module`, `release`, `debug-in-game`.

## Estructura
```
addon/LaRutaDel60/   addon (lo que se copia a Interface\AddOns)
  Core/ UI/ Modules/ Locales/ Libs/ Guides/(generado)
data/raw/            datos crudos de la web (con source)
data/routes/         rutas fuente (JSON)
tools/               scripts Python/bash (validador, compilador, check)
tools/tests/         tests de aceptación de las herramientas (congelados)
tests/support/       emulación del cliente WoW (congelada)
tests/acceptance/    tests de aceptación del addon (congelados)
scripts/deploy.ps1   despliegue en Windows
docs/                specs, planes, API
```
