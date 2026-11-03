# La Ruta del 60 — Base técnica (diseño)

Fecha: 2026-11-03
Estado: aprobado e implementado (rama feat/base-tecnica)

## 1. Contexto

**Objetivo del producto:** addon gratuito para *World of Warcraft: Forever* (Classic+ oficial de Blizzard) que guía a cualquier personaje (cualquier raza/clase/facción) de 1 a 60 por la ruta más rápida. Funcionalmente similar a RestedXP (pasos, flecha, auto-aceptar/entregar), pero con **código y rutas 100% propios**: no se copia código ni contenido de guías de RestedXP ni de otros addons.

**Objetivo de esta fase:** crear la base técnica para que el addon se desarrolle íntegramente con IA (Claude Code): agentes, skills, LSP, lint, tests, pipeline de datos, CI y despliegue. El motor del addon es una spec posterior.

**Plataforma objetivo:**
- Cliente WoW Forever 1.60.1, `## Interface: 16001`, lanzamiento 2026-11-04.
- Lua 5.1 (entorno WoW). API moderna (retail 12.x): `C_QuestLog`, `C_Map`, `C_Item`, `C_Spell`, etc. Restricciones de "secrets" de Midnight activas. ~1.041 globales FrameXML eliminados respecto a retail.
- Detección: `WOW_PROJECT_ID == WOW_PROJECT_CAMELOT` (18). TOC con sufijo `_Forever` / `_Camelot` soportado.
- Juego en PC Windows; desarrollo en macOS.

**Decisiones tomadas con el usuario:**
- Enfoque A: Claude Code nativo + toolchain Lua estándar (sin MCP propio).
- Datos de rutas: bases de datos web (Wowhead y similares con datos de Forever), con fuente citada por registro.
- Despliegue: GitHub + script PowerShell en el PC.
- Idiomas del addon (textos al jugador): enUS y esES desde el inicio.
- **Idioma del proyecto:** el código va siempre en inglés: identificadores, comentarios, strings, mensajes de herramientas/CLI, nombres de tests y commits. Las explicaciones van siempre en castellano: specs, planes, CLAUDE.md, agentes, skills y chat.
- **Tests de aceptación primero:** antes de cualquier código se escriben tests de caja negra derivados solo de esta spec (§11). Se commitean en rojo y quedan congelados: la implementación los pone en verde sin modificarlos.

## 2. Estructura del repositorio

```
larutadel60/
├── CLAUDE.md
├── .claude/
│   ├── settings.json
│   ├── agents/
│   └── skills/
├── .luarc.json
├── .luacheckrc
├── .stylua.toml
├── addon/LaRutaDel60/
│   ├── LaRutaDel60.toc
│   ├── LaRutaDel60_Forever.toc
│   ├── Core/
│   ├── UI/
│   ├── Modules/
│   ├── Locales/
│   ├── Libs/
│   └── Guides/
├── data/
│   ├── raw/
│   └── routes/
├── tools/
├── tests/
│   └── support/
├── scripts/deploy.ps1
├── .github/workflows/ci.yml
└── docs/
    ├── api/
    └── superpowers/specs/
```

Principios:
- **Rutas = datos, no código.** `data/routes/*.json` → validado → compilado a `addon/LaRutaDel60/Guides/*.lua`. Los agentes de rutas nunca tocan `Core/`.
- **Sin globals.** Todo bajo la tabla privada del addon (`local ADDON, ns = ...`); única global permitida: `LaRutaDel60DB` (SavedVariables) y el comando `/ruta`.
- **Archivos pequeños y con una responsabilidad.** Un módulo por archivo.

## 3. Toolchain

| Herramienta | Uso | Config |
|---|---|---|
| lua-language-server | LSP: diagnósticos, tipos API WoW | `.luarc.json` (runtime Lua 5.1, library = anotaciones Ketho `vscode-wow-api` mainline, globals del addon) |
| luacheck | Lint (globals, variables sin usar) | `.luacheckrc` con `std = "lua51"` + globals WoW leídos |
| stylua | Formato | `.stylua.toml` (tabs, 120 col) |
| busted | Tests unitarios fuera del juego | `tests/`, mocks en `tests/support/` |
| python3 | Herramientas de datos | `tools/` (scraper, validador, compilador) |

Instalación en macOS vía `brew` (lua-language-server, luacheck, stylua, luarocks) y `luarocks install busted`. Las anotaciones de Ketho se descargan a `.vendor/` (en `.gitignore`) mediante `tools/setup.sh`.

**LSP en Claude Code:** plugin local del proyecto que registra `lua-language-server` para `.lua`, de modo que la herramienta LSP dé diagnósticos y navegación. Si la integración por plugin no está disponible, fallback: hook que ejecuta `lua-language-server --check` sobre el archivo editado.

**Hooks (`.claude/settings.json`):** tras cada `Edit`/`Write` de un `.lua`: `stylua <archivo>` y `luacheck <archivo>`; la salida vuelve a Claude. Permisos preaprobados para lint, test y `tools/`.

## 4. Agentes (`.claude/agents/`)

| Agente | Responsabilidad | Escribe en |
|---|---|---|
| `wow-api-expert` | Verifica si una API/evento existe en Forever 1.60.1 (docs/api, anotaciones, wiki) y propone alternativa. | — (solo lectura) |
| `addon-engineer` | Implementa motor/UI con TDD sobre mocks. | `addon/`, `tests/` |
| `route-researcher` | Extrae quests/NPCs/coords/niveles de bases web, con URL fuente por registro. | `data/raw/` |
| `route-optimizer` | Construye y optimiza rutas por facción/raza/clase (orden, viajes, hearthstone, vuelos). | `data/routes/` |
| `route-validator` | Valida coherencia: prerrequisitos, niveles, coords, IDs, XP acumulada hasta 60. | — (solo lectura) |
| `lua-reviewer` | Revisión antes de commit: taint, rendimiento, globals, compatibilidad 16001. | — (solo lectura) |

## 5. Skills (`.claude/skills/`)

- `wow-forever-api` — chuleta de API moderna, eliminados, secrets, eventos clave de quests/gossip/mapa.
- `guide-format` — esquema JSON de rutas y su compilación a Lua.
- `add-route-segment` — pipeline investigar → JSON → optimizar → validar → compilar para un tramo.
- `new-module` — plantilla de módulo (archivo, TOC, test, locale).
- `release` — versión, changelog, tag; CI empaqueta zip.
- `debug-in-game` — leer errores de BugSack / SavedVariables pegados por el usuario y reproducirlos como test.

## 6. Pipeline de datos de rutas

1. `route-researcher` guarda registros en `data/raw/<zona>.json` (quest id, nombre, nivel, prerrequisitos, NPC inicio/fin con coords, objetivos, facción, URL fuente).
2. `route-optimizer` genera `data/routes/<faccion>/<tramo>.json` (lista ordenada de pasos).
3. `tools/validate_routes.py` comprueba esquema y reglas; falla en CI si hay errores.
4. `tools/compile_guides.py` genera `addon/LaRutaDel60/Guides/*.lua` (archivos generados, cabecera "no editar").

En esta fase solo se crean el esquema, el validador, el compilador y una ruta de ejemplo mínima (2–3 pasos) para probar el pipeline extremo a extremo.

## 7. Addon "hola mundo"

- TOC con `Interface: 16001`, `SavedVariables: LaRutaDel60DB`, carga de Locales/Core/Guides.
- `Core/Init.lua`: namespace, evento `PLAYER_LOGIN`, detección de Forever, mensaje en chat, comando `/ruta` que muestra versión y guía cargada.
- Locales enUS/esES.
- Test busted que carga el addon con mocks y verifica init + comando.

## 8. CI y despliegue

- **CI (GitHub Actions):** luacheck, stylua `--check`, busted, validate_routes, compile_guides con diff limpio; en tag `v*`, zip de `addon/LaRutaDel60` adjunto al release.
- **`scripts/deploy.ps1` (Windows):** parámetros `-WowPath` (por defecto `C:\Program Files (x86)\World of Warcraft\_classic_`, configurable porque la carpeta de Forever puede diferir) y `-Source` (`git` = pull del repo local; `release` = descarga último zip de GitHub). Copia `LaRutaDel60` a `Interface\AddOns`. Indica luego `/reload`.

## 9. Criterios de éxito de esta fase

- `tools/check.sh` pasa: lint, formato, tests, validación y compilación.
- Claude Code muestra diagnósticos LSP en archivos `.lua` con tipos de API WoW.
- Los 6 agentes y 6 skills existen y están referenciados en `CLAUDE.md`.
- El addon "hola mundo" se instala en Windows con `deploy.ps1` y muestra su mensaje en Forever (verificación manual del usuario).
- CI verde en GitHub.

## 10. Fuera de alcance

Motor de guía (flecha, lista de pasos, auto-quest), UI final, rutas reales, publicación en CurseForge.

## 11. Contratos verificables y tests de aceptación

Los tests de aceptación solo usan estas interfaces externas. Cualquier otra cosa (funciones internas, formato exacto del Lua generado, texto de los mensajes de error) es detalle de implementación y no se testea a este nivel.

### 11.1 CLI del pipeline de rutas
- `python3 tools/validate_routes.py [ROUTES_DIR]` (por defecto `data/routes`): exit 0 si todas las rutas son válidas; exit 1 si no, con un error por línea en stderr, y cada línea contiene la ruta relativa del archivo culpable.
- `python3 tools/compile_guides.py [--routes DIR] [--out DIR] [--check]`:
  - Sin `--check`: valida; si hay errores, exit 1 y **no escribe nada**. Si todo es válido, escribe `<id>.lua` por ruta y `Guides.xml` (que lista todas con `<Script file="<id>.lua"/>`), borra los `.lua` de rutas que ya no existen y termina con exit 0.
  - Con `--check`: no escribe; exit 1 si la salida difiere de lo que hay en `--out`, exit 0 si está al día.
- Ida y vuelta: cargar `<id>.lua` en Lua 5.1 con `(addonName, ns)` deja en `ns.Guides[id]` una tabla con **exactamente los mismos datos** que el JSON de origen.
- Reglas de validación: las de la tabla de formato (§6 y la skill `guide-format`). Cada regla tiene al menos un caso de aceptación.

### 11.2 Addon (lo que ve el jugador)
Mensajes en el chat (sin códigos de color), con el prefijo `La Ruta del 60: `:

| Situación | enUS | esES / esMX |
|---|---|---|
| Login | `Loaded. Type /ruta for info.` | `Cargado. Escribe /ruta para más info.` |
| Login en un cliente que no es Forever (antes del anterior) | `Warning: this client is not WoW Forever; guides may be wrong.` | `Aviso: este cliente no es WoW Forever; las guías pueden fallar.` |
| `/ruta` | `Version <TOC Version> - <N> guide(s) loaded.` | `Versión <TOC Version> - <N> guía(s) cargada(s).` |

- `<N>` = número de rutas en `data/routes`.
- `LaRutaDel60DB` existe tras el login y conserva los datos previos.
- Globals nuevas tras cargar el addon y hacer login: solo `LaRutaDel60DB`, `SLASH_LARUTADEL601` y la clave `LARUTADEL60` en `SlashCmdList`.
- TOC: `LaRutaDel60.toc` y `LaRutaDel60_Forever.toc` idénticos, `## Interface: 16001`, `## SavedVariables: LaRutaDel60DB`, y cada archivo listado (y cada script incluido en un `.xml`) existe.

### 11.3 Herramientas
- `tools/check.sh`: exit 0 en el repo limpio; exit distinto de 0 si hay un `.lua` del addon con error de lint, una ruta inválida o guías desactualizadas.
- Hook `.claude/hooks/post-edit.sh` (recibe por stdin el JSON de PostToolUse): exit 2 con mensaje en stderr si el `.lua` editado tiene errores de lint o si la edición deja rutas inválidas; exit 0 en el resto de casos.
- Los tests de herramientas que ejecutan `tools/check.sh` lo hacen sobre una copia temporal del repo y con `LR60_SKIP_TOOLING_TESTS=1`, para no ejecutarse a sí mismos en bucle.

### 11.4 Emulación del cliente en tests
- `tests/support/` emula el cliente: carga los archivos en el orden del TOC (expandiendo los `.xml`), pasa `(addonName, ns)`, resuelve los slash commands como el cliente (`SLASH_<KEY><n>` → `SlashCmdList[KEY]`) y captura el chat (`DEFAULT_CHAT_FRAME:AddMessage` y `print`).
- Los mocks solo imitan APIs que están en `docs/api/forever-api.md`, con la fuente citada.

### 11.5 Verificación manual (no automatizable en macOS)
`deploy.ps1` en Windows, el LSP dentro de Claude Code y el addon en el cliente real: checklist para el usuario en la última tarea del plan.
