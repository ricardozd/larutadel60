# Base técnica de La Ruta del 60 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dejar listo el repositorio para desarrollar 100% con IA un addon de leveo 1-60 para WoW Forever: toolchain Lua (LSP, lint, formato, tests), pipeline de rutas JSON→Lua, addon "hola mundo", agentes, skills, hooks, CI y despliegue a Windows.

**Architecture:** El addon vive en `addon/LaRutaDel60/` y no usa globals salvo SavedVariables y el slash command. Las rutas son datos (`data/routes/**/*.json`) que `tools/validate_routes.py` valida y `tools/compile_guides.py` compila a `addon/LaRutaDel60/Guides/*.lua` + `Guides.xml`. Los tests corren fuera del juego con busted sobre LuaJIT (compatible Lua 5.1) usando mocks de la API de WoW y un loader que lee el TOC real. Claude Code recibe diagnósticos vía plugin LSP local (lua-language-server + anotaciones Ketho) y hooks post-edición (stylua + luacheck).

**Tech Stack:** Lua 5.1 (WoW) / LuaJIT 2.1, busted 2.3, luacheck 1.2, stylua 2.6, lua-language-server 3.19, anotaciones Ketho `vscode-wow-api`, Python 3 (solo stdlib, unittest), GitHub Actions, PowerShell 5+.

## Global Constraints

- Cliente objetivo: WoW Forever 1.60.1, `## Interface: 16001`.
- Lua 5.1: nada de `goto`, `//`, operadores bit nativos, `table.unpack` sin fallback, `<const>`.
- API moderna (retail 12.x): usar `C_AddOns.GetAddOnMetadata`, `C_QuestLog.*`, `C_Map.*`; nunca APIs de Classic Era 1.15 sin verificar.
- Detección de Forever: `WOW_PROJECT_ID == WOW_PROJECT_CAMELOT` (valor 18).
- Globals permitidas en el addon: `LaRutaDel60DB`, `SLASH_LARUTADEL601`, y la entrada `SlashCmdList.LARUTADEL60`. Todo lo demás en `ns` (`local ADDON_NAME, ns = ...`).
- Comando de chat: `/ruta`.
- Idiomas: enUS (base) y esES (también para esMX).
- Rutas = datos. Los archivos de `addon/LaRutaDel60/Guides/` son generados: nunca se editan a mano.
- Código y identificadores en inglés; documentación, mensajes de herramientas y comentarios en español.
- Nada de código ni contenido de guías copiado de RestedXP u otros addons.
- Python solo stdlib (sin pip).
- Rutas de archivos en el repo con `/`; en el TOC con `\`.

## File Structure

```
.gitignore                         # ignora .vendor/, artefactos
.editorconfig
.luarc.json                        # config LuaLS
.luacheckrc
.stylua.toml
.styluaignore
.busted                            # config busted
CLAUDE.md                          # reglas del proyecto para la IA
.claude-plugin/marketplace.json    # marketplace local (plugin LSP)
claude-plugins/wow-lua-lsp/.claude-plugin/plugin.json
.claude/settings.json              # permisos + hooks
.claude/hooks/post-edit.sh         # stylua/luacheck/validador tras editar
.claude/agents/*.md                # 6 subagentes
.claude/skills/*/SKILL.md          # 6 skills
addon/LaRutaDel60/LaRutaDel60.toc
addon/LaRutaDel60/LaRutaDel60_Forever.toc
addon/LaRutaDel60/Locales/Locales.lua   # tabla L con fallback a la clave
addon/LaRutaDel60/Locales/enUS.lua
addon/LaRutaDel60/Locales/esES.lua
addon/LaRutaDel60/Core/Init.lua         # versión, detección, login, /ruta
addon/LaRutaDel60/Guides/              # GENERADO
data/raw/.gitkeep
data/routes/alliance/alliance-northshire-example.json
tools/__init__.py
tools/validate_routes.py
tools/compile_guides.py
tools/tests/__init__.py
tools/tests/test_validate_routes.py
tools/tests/test_compile_guides.py
tools/setup.sh                     # instala toolchain en macOS
tools/fetch_annotations.sh         # descarga anotaciones Ketho a .vendor/
tools/check.sh                     # verificación completa
tools/luals_check.sh
tests/mocks/wow.lua                # mocks API WoW
tests/helpers/loader.lua           # carga el addon siguiendo el TOC
tests/init_spec.lua
tests/toc_spec.lua
tests/guides_spec.lua
scripts/deploy.ps1
.github/workflows/ci.yml
docs/api/forever-api.md
```

---

### Task 1: Scaffold del repo y configuración del toolchain

**Files:**
- Create: `.gitignore`, `.editorconfig`, `.luarc.json`, `.luacheckrc`, `.stylua.toml`, `.styluaignore`, `.busted`, `tools/setup.sh`, `tools/fetch_annotations.sh`, `data/raw/.gitkeep`

**Interfaces:**
- Produces: `.vendor/vscode-wow-api/Annotations/Core` (anotaciones LuaLS); `~/.luarocks/bin/busted` (busted sobre LuaJIT); configuración que todas las tareas Lua siguientes respetan.

- [ ] **Step 1: Crear `.gitignore`**

```gitignore
.vendor/
dist/
check.json
__pycache__/
*.pyc
.DS_Store
luacov.*
```

- [ ] **Step 2: Crear `.editorconfig`**

```ini
root = true

[*]
end_of_line = lf
insert_final_newline = true
charset = utf-8
trim_trailing_whitespace = true

[*.{lua,xml,toc}]
indent_style = tab
indent_size = 4

[*.{py,json,yml,yaml,md}]
indent_style = space
indent_size = 4

[*.{json,yml,yaml}]
indent_size = 2

[*.ps1]
end_of_line = crlf
indent_style = space
indent_size = 4
```

- [ ] **Step 3: Crear `.stylua.toml` y `.styluaignore`**

`.stylua.toml`:
```toml
column_width = 120
line_endings = "Unix"
indent_type = "Tabs"
indent_width = 4
quote_style = "AutoPreferDouble"
call_parentheses = "Always"
```

`.styluaignore`:
```
.vendor/
addon/LaRutaDel60/Libs/
addon/LaRutaDel60/Guides/
```

- [ ] **Step 4: Crear `.luacheckrc`**

```lua
std = "lua51"
max_line_length = 120
exclude_files = { ".vendor/**", "addon/LaRutaDel60/Libs/**" }

-- Globals que el addon escribe.
globals = {
	"LaRutaDel60DB",
	"SLASH_LARUTADEL601",
	SlashCmdList = { fields = { "LARUTADEL60" } },
}

-- API de WoW que el addon lee. Añadir aquí cada API nueva que se use.
read_globals = {
	"C_AddOns",
	"CreateFrame",
	"DEFAULT_CHAT_FRAME",
	"GetLocale",
	"WOW_PROJECT_CAMELOT",
	"WOW_PROJECT_ID",
}

files["addon/LaRutaDel60/Guides/**"] = { max_line_length = false }

files["tests/**"] = {
	std = "max+busted",
	-- Los mocks instalan globals de WoW a propósito.
	ignore = { "111", "112", "113", "121", "122", "142", "143" },
}
```

- [ ] **Step 5: Crear `.luarc.json`**

```json
{
  "$schema": "https://raw.githubusercontent.com/LuaLS/vscode-lua/master/setting/schema.json",
  "runtime.version": "Lua 5.1",
  "workspace.library": [".vendor/vscode-wow-api/Annotations/Core"],
  "workspace.ignoreDir": [".vendor", "tests", "tools", "addon/LaRutaDel60/Libs"],
  "workspace.checkThirdParty": false,
  "diagnostics.globals": ["LaRutaDel60DB", "SLASH_LARUTADEL601"],
  "telemetry.enable": false
}
```

- [ ] **Step 6: Crear `.busted`**

```lua
return {
	_all = {
		lpath = "tests/?.lua",
		ROOT = { "tests" },
		pattern = "_spec",
	},
}
```

- [ ] **Step 7: Crear `tools/fetch_annotations.sh`**

```bash
#!/usr/bin/env bash
# Descarga (o actualiza) las anotaciones LuaLS de la API de WoW de Ketho en .vendor/.
set -euo pipefail
cd "$(dirname "$0")/.."
DEST=".vendor/vscode-wow-api"
if [ -d "$DEST/.git" ]; then
	git -C "$DEST" pull --ff-only --quiet
else
	mkdir -p .vendor
	git clone --quiet --depth 1 --filter=blob:none --sparse https://github.com/Ketho/vscode-wow-api.git "$DEST"
	git -C "$DEST" sparse-checkout set Annotations
fi
test -d "$DEST/Annotations/Core" || { echo "ERROR: no se encontró $DEST/Annotations/Core" >&2; exit 1; }
echo "OK: anotaciones en $DEST/Annotations/Core"
```

- [ ] **Step 8: Crear `tools/setup.sh`**

```bash
#!/usr/bin/env bash
# Instala el toolchain de desarrollo en macOS (Homebrew). Idempotente.
set -euo pipefail
cd "$(dirname "$0")/.."
brew install luajit luarocks lua-language-server luacheck stylua
luarocks --lua-version=5.1 --lua-dir="$(brew --prefix luajit)" --local install busted
tools/fetch_annotations.sh
case ":$PATH:" in
	*":$HOME/.luarocks/bin:"*) ;;
	*) echo "AVISO: añade \$HOME/.luarocks/bin a tu PATH (busted está ahí)." ;;
esac
echo "OK: toolchain instalado"
```

- [ ] **Step 9: Crear `data/raw/.gitkeep`, dar permisos y ejecutar setup**

Run:
```bash
mkdir -p data/raw && touch data/raw/.gitkeep
chmod +x tools/setup.sh tools/fetch_annotations.sh
tools/setup.sh
```
Expected: termina con `OK: toolchain instalado`; existe `.vendor/vscode-wow-api/Annotations/Core`.

- [ ] **Step 10: Verificar herramientas**

Run: `luajit -v && ~/.luarocks/bin/busted --version && luacheck --version && stylua --version && lua-language-server --version`
Expected: cinco versiones impresas sin error (LuaJIT 2.1, busted 2.3.x, Luacheck 1.2.x, stylua 2.6.x, 3.19.x).

- [ ] **Step 11: Commit**

```bash
git add .gitignore .editorconfig .luarc.json .luacheckrc .stylua.toml .styluaignore .busted tools/setup.sh tools/fetch_annotations.sh data/raw/.gitkeep
git commit -m "chore: configuración del toolchain Lua"
```

---

### Task 2: Pipeline de rutas (validador + compilador + ruta de ejemplo)

**Files:**
- Create: `tools/__init__.py`, `tools/validate_routes.py`, `tools/compile_guides.py`, `tools/tests/__init__.py`, `tools/tests/test_validate_routes.py`, `tools/tests/test_compile_guides.py`, `data/routes/alliance/alliance-northshire-example.json`
- Generated: `addon/LaRutaDel60/Guides/alliance-northshire-example.lua`, `addon/LaRutaDel60/Guides/Guides.xml`

**Interfaces:**
- Produces:
  - `tools.validate_routes.validate_route(route: object) -> list[str]`
  - `tools.validate_routes.validate_all(routes_dir: Path = ROUTES_DIR) -> list[str]`
  - `tools.validate_routes.ROUTES_DIR`, `ROOT` (`Path`)
  - `tools.compile_guides.to_lua(value, depth=0) -> str`
  - `tools.compile_guides.compile_route(route: dict, source: str) -> str`
  - `tools.compile_guides.build_xml(ids: list[str]) -> str`
  - `tools.compile_guides.main(argv: list[str] | None) -> int` (flags `--check`, `--routes DIR`, `--out DIR`)
  - En Lua: cada guía generada hace `ns.Guides["<id>"] = { ... }` con las mismas claves que el JSON.

**Formato de ruta (JSON)** — fuente de verdad, se documenta también en la skill `guide-format`:

| Campo | Tipo | Regla |
|---|---|---|
| `id` | string | kebab-case minúsculas; igual al nombre del archivo sin `.json`; único |
| `name` | `{enUS, esES?}` | `enUS` obligatorio |
| `faction` | string | `Alliance`, `Horde` o `Both` |
| `races`, `classes` | lista de strings | opcional |
| `minLevel`, `maxLevel` | int | 1..60, `minLevel <= maxLevel` |
| `next` | string | opcional; id de una ruta existente |
| `carriedQuests` | lista de int | opcional; quests aceptadas en rutas anteriores |
| `steps` | lista no vacía | ver abajo |

Paso: `type` ∈ `accept, complete, turnin, goto, hearth, fly, train, note`; `questId` (int > 0) obligatorio en `accept/complete/turnin`; `complete/turnin` exigen `accept` previo en la ruta o estar en `carriedQuests`; `coords {mapId:int>0, x:0..100, y:0..100}` obligatorio en `goto`, opcional en el resto; `text {enUS, esES?}` obligatorio en `note`; `npcId` int > 0 opcional; `source` URL `http(s)` opcional.

- [ ] **Step 1: Crear paquetes vacíos**

```bash
mkdir -p tools/tests data/routes/alliance
printf '' > tools/__init__.py
printf '' > tools/tests/__init__.py
```

- [ ] **Step 2: Escribir tests del validador (fallan)**

`tools/tests/test_validate_routes.py`:
```python
import json
import tempfile
import unittest
from pathlib import Path

from tools.validate_routes import ROUTES_DIR, validate_all, validate_route


def make_route(**overrides):
    route = {
        "id": "test-route",
        "name": {"enUS": "Test"},
        "faction": "Alliance",
        "minLevel": 1,
        "maxLevel": 2,
        "steps": [
            {"type": "accept", "questId": 783, "npcId": 823},
            {"type": "turnin", "questId": 783},
        ],
    }
    route.update(overrides)
    return route


class ValidateRouteTest(unittest.TestCase):
    def test_valid_route_has_no_errors(self):
        self.assertEqual(validate_route(make_route()), [])

    def test_rejects_non_object(self):
        self.assertEqual(validate_route([]), ["la ruta debe ser un objeto JSON"])

    def test_rejects_bad_id(self):
        errors = validate_route(make_route(id="Bad Id"))
        self.assertTrue(any("'id'" in e for e in errors), errors)

    def test_requires_english_name(self):
        errors = validate_route(make_route(name={"esES": "Prueba"}))
        self.assertTrue(any("name" in e for e in errors), errors)

    def test_rejects_unknown_faction(self):
        errors = validate_route(make_route(faction="Pirates"))
        self.assertTrue(any("faction" in e for e in errors), errors)

    def test_rejects_level_out_of_range(self):
        errors = validate_route(make_route(maxLevel=61))
        self.assertTrue(any("maxLevel" in e for e in errors), errors)

    def test_rejects_min_above_max(self):
        errors = validate_route(make_route(minLevel=10, maxLevel=5))
        self.assertTrue(any("minLevel" in e for e in errors), errors)

    def test_rejects_empty_steps(self):
        errors = validate_route(make_route(steps=[]))
        self.assertTrue(any("steps" in e for e in errors), errors)

    def test_rejects_unknown_step_type(self):
        errors = validate_route(make_route(steps=[{"type": "dance"}]))
        self.assertTrue(any("dance" in e for e in errors), errors)

    def test_quest_step_requires_quest_id(self):
        errors = validate_route(make_route(steps=[{"type": "accept"}]))
        self.assertTrue(any("questId" in e for e in errors), errors)

    def test_turnin_requires_previous_accept(self):
        errors = validate_route(make_route(steps=[{"type": "turnin", "questId": 5}]))
        self.assertTrue(any("questId 5" in e for e in errors), errors)

    def test_carried_quests_allow_turnin(self):
        route = make_route(carriedQuests=[5], steps=[{"type": "turnin", "questId": 5}])
        self.assertEqual(validate_route(route), [])

    def test_goto_requires_coords(self):
        errors = validate_route(make_route(steps=[{"type": "goto"}]))
        self.assertTrue(any("coords" in e for e in errors), errors)

    def test_coords_must_be_percentages(self):
        step = {"type": "goto", "coords": {"mapId": 1429, "x": 150, "y": 20}}
        errors = validate_route(make_route(steps=[step]))
        self.assertTrue(any("coords.x" in e for e in errors), errors)

    def test_note_requires_text(self):
        errors = validate_route(make_route(steps=[{"type": "note"}]))
        self.assertTrue(any("text" in e for e in errors), errors)

    def test_source_must_be_url(self):
        step = {"type": "accept", "questId": 1, "source": "wowhead"}
        errors = validate_route(make_route(steps=[step]))
        self.assertTrue(any("source" in e for e in errors), errors)


class ValidateAllTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self._tmp.name)

    def tearDown(self):
        self._tmp.cleanup()

    def write(self, name, data):
        (self.dir / name).write_text(json.dumps(data), encoding="utf-8")

    def test_filename_must_match_id(self):
        self.write("other.json", make_route())
        errors = validate_all(self.dir)
        self.assertTrue(any("nombre del archivo" in e for e in errors), errors)

    def test_rejects_duplicate_ids(self):
        sub = self.dir / "a"
        sub.mkdir()
        self.write("test-route.json", make_route())
        (sub / "test-route.json").write_text(json.dumps(make_route()), encoding="utf-8")
        errors = validate_all(self.dir)
        self.assertTrue(any("duplicado" in e for e in errors), errors)

    def test_next_must_exist(self):
        self.write("test-route.json", make_route(next="missing-route"))
        errors = validate_all(self.dir)
        self.assertTrue(any("missing-route" in e for e in errors), errors)

    def test_invalid_json_is_reported(self):
        (self.dir / "broken.json").write_text("{", encoding="utf-8")
        errors = validate_all(self.dir)
        self.assertTrue(any("JSON inválido" in e for e in errors), errors)

    def test_repository_routes_are_valid(self):
        self.assertEqual(validate_all(ROUTES_DIR), [])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 3: Ejecutar y ver que falla**

Run: `python3 -m unittest discover -s tools/tests -t . -q`
Expected: FAIL con `ModuleNotFoundError: No module named 'tools.validate_routes'`.

- [ ] **Step 4: Implementar `tools/validate_routes.py`**

```python
"""Valida las rutas de data/routes según el formato de guía de La Ruta del 60.

Uso: python3 tools/validate_routes.py [DIRECTORIO_RUTAS]
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ROUTES_DIR = ROOT / "data" / "routes"

FACTIONS = {"Alliance", "Horde", "Both"}
STEP_TYPES = {"accept", "complete", "turnin", "goto", "hearth", "fly", "train", "note"}
QUEST_STEPS = {"accept", "complete", "turnin"}
LOCALES = {"enUS", "esES"}
MIN_LEVEL, MAX_LEVEL = 1, 60
ID_RE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")


def _is_int(value) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


def _is_num(value) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def _check_localized(value, where: str, field: str, errors: list[str], required: bool) -> None:
    if value is None:
        if required:
            errors.append(f"{where}: falta '{field}'")
        return
    if not isinstance(value, dict) or "enUS" not in value:
        errors.append(f"{where}: '{field}' debe ser un objeto con al menos 'enUS'")
        return
    for locale, text in value.items():
        if locale not in LOCALES:
            errors.append(f"{where}: locale desconocido '{locale}' en '{field}'")
        elif not isinstance(text, str) or not text.strip():
            errors.append(f"{where}: '{field}.{locale}' vacío")


def _check_coords(coords, where: str, errors: list[str]) -> None:
    if not isinstance(coords, dict):
        errors.append(f"{where}: 'coords' debe ser un objeto")
        return
    map_id = coords.get("mapId")
    if not _is_int(map_id) or map_id <= 0:
        errors.append(f"{where}: 'coords.mapId' debe ser entero > 0")
    for axis in ("x", "y"):
        value = coords.get(axis)
        if not _is_num(value) or not 0 <= value <= 100:
            errors.append(f"{where}: 'coords.{axis}' debe estar entre 0 y 100")


def _check_level(route: dict, field: str, errors: list[str]) -> bool:
    value = route.get(field)
    if not _is_int(value) or not MIN_LEVEL <= value <= MAX_LEVEL:
        errors.append(f"'{field}' debe ser entero entre {MIN_LEVEL} y {MAX_LEVEL}")
        return False
    return True


def _check_step(step, index: int, accepted: set[int], errors: list[str]) -> None:
    where = f"steps[{index}]"
    if not isinstance(step, dict):
        errors.append(f"{where}: el paso debe ser un objeto")
        return
    step_type = step.get("type")
    if step_type not in STEP_TYPES:
        errors.append(f"{where}: tipo de paso desconocido '{step_type}'")
        return

    if step_type in QUEST_STEPS:
        quest_id = step.get("questId")
        if not _is_int(quest_id) or quest_id <= 0:
            errors.append(f"{where}: 'questId' debe ser entero > 0")
        elif step_type == "accept":
            accepted.add(quest_id)
        elif quest_id not in accepted:
            errors.append(
                f"{where}: questId {quest_id} no se aceptó antes en la ruta "
                "(añádela a 'carriedQuests' si viene de otra ruta)"
            )

    if step_type == "goto" and "coords" not in step:
        errors.append(f"{where}: un paso 'goto' necesita 'coords'")
    if "coords" in step:
        _check_coords(step["coords"], where, errors)

    _check_localized(step.get("text"), where, "text", errors, required=step_type == "note")

    if "npcId" in step and (not _is_int(step["npcId"]) or step["npcId"] <= 0):
        errors.append(f"{where}: 'npcId' debe ser entero > 0")
    source = step.get("source")
    if source is not None and (not isinstance(source, str) or not source.startswith(("http://", "https://"))):
        errors.append(f"{where}: 'source' debe ser una URL http(s)")


def validate_route(route) -> list[str]:
    """Devuelve la lista de errores de una ruta (vacía si es válida)."""
    if not isinstance(route, dict):
        return ["la ruta debe ser un objeto JSON"]
    errors: list[str] = []

    route_id = route.get("id")
    if not isinstance(route_id, str) or not ID_RE.match(route_id):
        errors.append("'id' debe ser kebab-case en minúsculas")
    _check_localized(route.get("name"), "ruta", "name", errors, required=True)
    if route.get("faction") not in FACTIONS:
        errors.append(f"'faction' debe ser uno de {sorted(FACTIONS)}")

    min_ok = _check_level(route, "minLevel", errors)
    max_ok = _check_level(route, "maxLevel", errors)
    if min_ok and max_ok and route["minLevel"] > route["maxLevel"]:
        errors.append("'minLevel' no puede ser mayor que 'maxLevel'")

    for field in ("races", "classes"):
        value = route.get(field)
        if value is not None and (not isinstance(value, list) or not all(isinstance(v, str) for v in value)):
            errors.append(f"'{field}' debe ser una lista de strings")

    next_id = route.get("next")
    if next_id is not None and not isinstance(next_id, str):
        errors.append("'next' debe ser el id (string) de otra ruta")

    carried = route.get("carriedQuests", [])
    if not isinstance(carried, list) or not all(_is_int(q) and q > 0 for q in carried):
        errors.append("'carriedQuests' debe ser una lista de enteros > 0")
        carried = []

    steps = route.get("steps")
    if not isinstance(steps, list) or not steps:
        errors.append("'steps' debe ser una lista no vacía")
        return errors
    accepted = set(carried)
    for index, step in enumerate(steps, start=1):
        _check_step(step, index, accepted, errors)
    return errors


def validate_all(routes_dir: Path = ROUTES_DIR) -> list[str]:
    """Valida todas las rutas *.json bajo routes_dir, incluidas reglas entre archivos."""
    errors: list[str] = []
    ids: dict[str, str] = {}
    routes: list[tuple[str, dict]] = []

    for path in sorted(Path(routes_dir).rglob("*.json")):
        label = path.relative_to(routes_dir).as_posix()
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            errors.append(f"{label}: JSON inválido: {exc}")
            continue
        errors.extend(f"{label}: {err}" for err in validate_route(data))
        if isinstance(data, dict) and isinstance(data.get("id"), str):
            route_id = data["id"]
            if path.stem != route_id:
                errors.append(f"{label}: el nombre del archivo debe ser '{route_id}.json'")
            if route_id in ids:
                errors.append(f"{label}: id duplicado '{route_id}' (también en {ids[route_id]})")
            ids[route_id] = label
            routes.append((label, data))

    for label, data in routes:
        next_id = data.get("next")
        if isinstance(next_id, str) and next_id not in ids:
            errors.append(f"{label}: 'next' apunta a una ruta inexistente '{next_id}'")
    return errors


def main(argv: list[str] | None = None) -> int:
    argv = sys.argv[1:] if argv is None else argv
    routes_dir = Path(argv[0]) if argv else ROUTES_DIR
    errors = validate_all(routes_dir)
    for err in errors:
        print(f"ERROR {err}", file=sys.stderr)
    if errors:
        return 1
    print(f"OK: rutas válidas en {routes_dir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 5: Crear la ruta de ejemplo**

`data/routes/alliance/alliance-northshire-example.json` (datos de Classic usados solo para probar el pipeline; **no verificados en Forever**):
```json
{
  "id": "alliance-northshire-example",
  "name": {
    "enUS": "Example: Northshire Valley (pipeline test)",
    "esES": "Ejemplo: Valle de Villanorte (prueba del pipeline)"
  },
  "faction": "Alliance",
  "races": ["Human"],
  "minLevel": 1,
  "maxLevel": 2,
  "steps": [
    {
      "type": "note",
      "text": {
        "enUS": "Example route: data not verified for WoW Forever.",
        "esES": "Ruta de ejemplo: datos no verificados para WoW Forever."
      }
    },
    {
      "type": "accept",
      "questId": 783,
      "npcId": 823,
      "coords": { "mapId": 1429, "x": 48.2, "y": 42.9 },
      "source": "https://www.wowhead.com/classic/quest=783"
    },
    {
      "type": "goto",
      "coords": { "mapId": 1429, "x": 48.9, "y": 41.6 }
    },
    {
      "type": "turnin",
      "questId": 783,
      "npcId": 197,
      "coords": { "mapId": 1429, "x": 48.9, "y": 41.6 },
      "source": "https://www.wowhead.com/classic/quest=783"
    }
  ]
}
```

- [ ] **Step 6: Ejecutar tests del validador**

Run: `python3 -m unittest tools.tests.test_validate_routes -q`
Expected: `OK` (21 tests).

- [ ] **Step 7: Escribir tests del compilador (fallan)**

`tools/tests/test_compile_guides.py`:
```python
import json
import tempfile
import unittest
from pathlib import Path

from tools.compile_guides import build_xml, compile_route, main, to_lua


class ToLuaTest(unittest.TestCase):
    def test_scalars(self):
        self.assertEqual(to_lua(True), "true")
        self.assertEqual(to_lua(False), "false")
        self.assertEqual(to_lua(42), "42")
        self.assertEqual(to_lua(48.2), "48.2")
        self.assertEqual(to_lua("hi"), '"hi"')

    def test_escapes_strings(self):
        self.assertEqual(to_lua('a "b"\\\n'), '"a \\"b\\"\\\\\\n"')

    def test_empty_containers(self):
        self.assertEqual(to_lua([]), "{}")
        self.assertEqual(to_lua({}), "{}")

    def test_list(self):
        self.assertEqual(to_lua([1, 2]), "{\n\t1,\n\t2,\n}")

    def test_dict_keys_sorted_and_none_skipped(self):
        self.assertEqual(to_lua({"b": 1, "a": 2, "c": None}), "{\n\ta = 2,\n\tb = 1,\n}")

    def test_non_identifier_keys_are_bracketed(self):
        self.assertEqual(to_lua({"my-key": 1, "end": 2}), '{\n\t["end"] = 2,\n\t["my-key"] = 1,\n}')

    def test_nested_indentation(self):
        self.assertEqual(to_lua({"a": [1]}), "{\n\ta = {\n\t\t1,\n\t},\n}")

    def test_rejects_unsupported_type(self):
        with self.assertRaises(TypeError):
            to_lua(object())


class CompileRouteTest(unittest.TestCase):
    def test_compiled_route_registers_guide(self):
        lua = compile_route({"id": "r1", "minLevel": 1}, "data/routes/r1.json")
        self.assertTrue(lua.startswith("-- GENERADO por tools/compile_guides.py desde data/routes/r1.json"))
        self.assertIn("local _, ns = ...\n", lua)
        self.assertIn("ns.Guides = ns.Guides or {}\n", lua)
        self.assertIn('ns.Guides["r1"] = {\n\tid = "r1",\n\tminLevel = 1,\n}\n', lua)

    def test_build_xml_lists_sorted_scripts(self):
        xml = build_xml(["b", "a"])
        self.assertIn('\t<Script file="a.lua"/>\n\t<Script file="b.lua"/>\n', xml)
        self.assertTrue(xml.startswith('<Ui xmlns="http://www.blizzard.com/wow/ui/">'))
        self.assertTrue(xml.endswith("</Ui>\n"))


class MainTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        base = Path(self._tmp.name)
        self.routes = base / "routes"
        self.out = base / "Guides"
        self.routes.mkdir()
        route = {
            "id": "r1",
            "name": {"enUS": "R1"},
            "faction": "Both",
            "minLevel": 1,
            "maxLevel": 2,
            "steps": [{"type": "accept", "questId": 1}],
        }
        (self.routes / "r1.json").write_text(json.dumps(route), encoding="utf-8")

    def tearDown(self):
        self._tmp.cleanup()

    def run_main(self, *extra):
        return main(["--routes", str(self.routes), "--out", str(self.out), *extra])

    def test_check_fails_when_outdated_then_passes_after_compile(self):
        self.assertEqual(self.run_main("--check"), 1)
        self.assertEqual(self.run_main(), 0)
        self.assertTrue((self.out / "r1.lua").exists())
        self.assertTrue((self.out / "Guides.xml").exists())
        self.assertEqual(self.run_main("--check"), 0)

    def test_removes_stale_guides(self):
        self.out.mkdir()
        (self.out / "old.lua").write_text("-- old", encoding="utf-8")
        self.assertEqual(self.run_main(), 0)
        self.assertFalse((self.out / "old.lua").exists())

    def test_refuses_invalid_routes(self):
        (self.routes / "bad.json").write_text("{}", encoding="utf-8")
        self.assertEqual(self.run_main(), 1)
        self.assertFalse(self.out.exists())


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 8: Ejecutar y ver que falla**

Run: `python3 -m unittest tools.tests.test_compile_guides -q`
Expected: FAIL con `ModuleNotFoundError: No module named 'tools.compile_guides'`.

- [ ] **Step 9: Implementar `tools/compile_guides.py`**

```python
"""Compila data/routes/**/*.json a addon/LaRutaDel60/Guides/*.lua + Guides.xml.

Uso:
  python3 tools/compile_guides.py            # valida y genera
  python3 tools/compile_guides.py --check    # falla si Guides/ no está al día
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from validate_routes import ROOT, ROUTES_DIR, validate_all  # noqa: E402

GUIDES_DIR = ROOT / "addon" / "LaRutaDel60" / "Guides"
HEADER = "-- GENERADO por tools/compile_guides.py desde {source}. NO EDITAR A MANO.\n"
IDENT_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
LUA_KEYWORDS = {
    "and", "break", "do", "else", "elseif", "end", "false", "for", "function", "if", "in",
    "local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while",
}


def lua_string(text: str) -> str:
    escaped = text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
    return f'"{escaped}"'


def _lua_key(key: str) -> str:
    if IDENT_RE.match(key) and key not in LUA_KEYWORDS:
        return key
    return f"[{lua_string(key)}]"


def to_lua(value, depth: int = 0) -> str:
    """Serializa un valor JSON a una expresión Lua determinista (claves ordenadas, tabs)."""
    pad = "\t" * (depth + 1)
    close = "\t" * depth
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, float):
        return repr(value)
    if isinstance(value, str):
        return lua_string(value)
    if isinstance(value, list):
        items = [f"{pad}{to_lua(item, depth + 1)}," for item in value]
    elif isinstance(value, dict):
        items = [
            f"{pad}{_lua_key(key)} = {to_lua(value[key], depth + 1)},"
            for key in sorted(value)
            if value[key] is not None
        ]
    else:
        raise TypeError(f"tipo no soportado: {type(value).__name__}")
    if not items:
        return "{}"
    return "{\n" + "\n".join(items) + f"\n{close}}}"


def compile_route(route: dict, source: str) -> str:
    return (
        HEADER.format(source=source)
        + "local _, ns = ...\n"
        + "ns.Guides = ns.Guides or {}\n"
        + f"ns.Guides[{lua_string(route['id'])}] = {to_lua(route)}\n"
    )


def build_xml(ids: list[str]) -> str:
    lines = ['<Ui xmlns="http://www.blizzard.com/wow/ui/">']
    lines.append("\t<!-- GENERADO por tools/compile_guides.py. NO EDITAR A MANO. -->")
    lines.extend(f'\t<Script file="{guide_id}.lua"/>' for guide_id in sorted(ids))
    lines.append("</Ui>")
    return "\n".join(lines) + "\n"


def build_outputs(routes_dir: Path) -> dict[str, str]:
    outputs: dict[str, str] = {}
    for path in sorted(routes_dir.rglob("*.json")):
        route = json.loads(path.read_text(encoding="utf-8"))
        resolved = path.resolve()
        source = resolved.relative_to(ROOT).as_posix() if resolved.is_relative_to(ROOT) else path.name
        outputs[f"{route['id']}.lua"] = compile_route(route, source)
    outputs["Guides.xml"] = build_xml([name[: -len(".lua")] for name in outputs])
    return outputs


def _existing(out_dir: Path) -> dict[str, str]:
    if not out_dir.exists():
        return {}
    return {
        p.name: p.read_text(encoding="utf-8")
        for p in out_dir.iterdir()
        if p.is_file() and p.suffix in (".lua", ".xml")
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true", help="no escribe; falla si Guides/ está desactualizado")
    parser.add_argument("--routes", type=Path, default=ROUTES_DIR)
    parser.add_argument("--out", type=Path, default=GUIDES_DIR)
    args = parser.parse_args(argv)

    errors = validate_all(args.routes)
    if errors:
        for err in errors:
            print(f"ERROR {err}", file=sys.stderr)
        return 1

    outputs = build_outputs(args.routes)
    existing = _existing(args.out)
    if args.check:
        if existing != outputs:
            print("ERROR: Guides/ desactualizado; ejecuta python3 tools/compile_guides.py", file=sys.stderr)
            return 1
        print("OK: Guides/ al día")
        return 0

    args.out.mkdir(parents=True, exist_ok=True)
    for stale in existing.keys() - outputs.keys():
        (args.out / stale).unlink()
    for name, content in outputs.items():
        (args.out / name).write_text(content, encoding="utf-8", newline="\n")
    print(f"OK: {len(outputs) - 1} guía(s) compilada(s) en {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 10: Ejecutar todos los tests de Python**

Run: `python3 -m unittest discover -s tools/tests -t . -q`
Expected: `OK` (34 tests).

- [ ] **Step 11: Generar las guías y comprobar**

Run: `python3 tools/validate_routes.py && python3 tools/compile_guides.py && python3 tools/compile_guides.py --check && luajit -bl addon/LaRutaDel60/Guides/alliance-northshire-example.lua > /dev/null && echo LUA_OK`
Expected: `OK: rutas válidas…`, `OK: 1 guía(s) compilada(s)…`, `OK: Guides/ al día`, `LUA_OK`.

- [ ] **Step 12: Commit**

```bash
git add tools/__init__.py tools/validate_routes.py tools/compile_guides.py tools/tests data/routes addon/LaRutaDel60/Guides
git commit -m "feat: pipeline de rutas JSON a Lua con validador"
```

---

### Task 3: Harness de tests Lua + addon "hola mundo"

**Files:**
- Create: `tests/mocks/wow.lua`, `tests/helpers/loader.lua`, `tests/toc_spec.lua`, `tests/init_spec.lua`, `tests/guides_spec.lua`, `addon/LaRutaDel60/LaRutaDel60.toc`, `addon/LaRutaDel60/LaRutaDel60_Forever.toc`, `addon/LaRutaDel60/Locales/Locales.lua`, `addon/LaRutaDel60/Locales/enUS.lua`, `addon/LaRutaDel60/Locales/esES.lua`, `addon/LaRutaDel60/Core/Init.lua`

**Interfaces:**
- Consumes: `addon/LaRutaDel60/Guides/Guides.xml` y `ns.Guides[id]` (Task 2).
- Produces:
  - `require("mocks.wow").install(opts) -> env` con `opts = { locale?, projectId?, version? }` y `env = { chat: string[], frames: table[], fire(event, ...) }`.
  - `require("helpers.loader").load(opts) -> ns, env`; `loader.tocFiles(tocPath) -> string[]`; `loader.ADDON_DIR`.
  - En `ns`: `ns.L`, `ns.VERSION`, `ns.Guides`, `ns.IsForever() -> boolean`, `ns.Print(msg)`, `ns.GuideCount() -> integer`, `ns.HandleSlash()`.
  - Claves de locale: `ADDON_TITLE`, `LOADED`, `NOT_FOREVER`, `VERSION_INFO` (formato `%s` versión, `%d` nº guías).

- [ ] **Step 1: Crear el mock de la API de WoW**

`tests/mocks/wow.lua`:
```lua
-- Mock mínimo de la API de WoW para tests fuera del juego.
-- Añade aquí solo lo que el addon use de verdad, con el mismo comportamiento que en Forever.
local M = {}

function M.install(opts)
	opts = opts or {}
	local env = { chat = {}, frames = {} }

	_G.DEFAULT_CHAT_FRAME = {
		AddMessage = function(_, msg)
			env.chat[#env.chat + 1] = msg
		end,
	}
	_G.GetLocale = function()
		return opts.locale or "enUS"
	end
	_G.WOW_PROJECT_CAMELOT = 18
	_G.WOW_PROJECT_ID = opts.projectId or 18
	_G.C_AddOns = {
		GetAddOnMetadata = function(_, field)
			if field == "Version" then
				return opts.version or "0.0.0-test"
			end
			return nil
		end,
	}
	_G.CreateFrame = function()
		local frame = { events = {}, scripts = {} }
		function frame:RegisterEvent(event)
			self.events[event] = true
		end
		function frame:SetScript(name, fn)
			self.scripts[name] = fn
		end
		env.frames[#env.frames + 1] = frame
		return frame
	end
	_G.SlashCmdList = {}
	_G.SLASH_LARUTADEL601 = nil
	_G.LaRutaDel60DB = nil

	function env.fire(event, ...)
		for _, frame in ipairs(env.frames) do
			if frame.events[event] and frame.scripts.OnEvent then
				frame.scripts.OnEvent(frame, event, ...)
			end
		end
	end

	return env
end

return M
```

- [ ] **Step 2: Crear el loader que sigue el TOC**

`tests/helpers/loader.lua`:
```lua
-- Carga el addon como lo haría el cliente: en el orden del TOC, pasando (ADDON_NAME, ns) a cada archivo.
local Mock = require("mocks.wow")

local Loader = {}
Loader.ADDON_NAME = "LaRutaDel60"
Loader.ADDON_DIR = "addon/LaRutaDel60/"

local function readFile(path)
	local handle = assert(io.open(path, "r"), "no existe " .. path)
	local content = handle:read("*a")
	handle:close()
	return content
end

function Loader.tocFiles(tocPath)
	local files = {}
	for line in readFile(tocPath):gmatch("[^\r\n]+") do
		local entry = line:match("^%s*(.-)%s*$")
		if entry ~= "" and entry:sub(1, 1) ~= "#" then
			files[#files + 1] = (entry:gsub("\\", "/"))
		end
	end
	return files
end

local function xmlScripts(xmlPath)
	local dir = xmlPath:match("^(.*/)") or ""
	local scripts = {}
	for file in readFile(xmlPath):gmatch('<Script%s+file="([^"]+)"') do
		scripts[#scripts + 1] = dir .. (file:gsub("\\", "/"))
	end
	return scripts
end

local function runFile(path, ns)
	local chunk = assert(loadfile(path))
	chunk(Loader.ADDON_NAME, ns)
end

function Loader.load(opts)
	local env = Mock.install(opts)
	local ns = {}
	for _, file in ipairs(Loader.tocFiles(Loader.ADDON_DIR .. Loader.ADDON_NAME .. ".toc")) do
		local path = Loader.ADDON_DIR .. file
		if file:match("%.xml$") then
			for _, script in ipairs(xmlScripts(path)) do
				runFile(script, ns)
			end
		else
			runFile(path, ns)
		end
	end
	return ns, env
end

return Loader
```

- [ ] **Step 3: Escribir los specs (fallan)**

`tests/toc_spec.lua`:
```lua
local Loader = require("helpers.loader")

local function read(path)
	local handle = assert(io.open(path, "r"))
	local content = handle:read("*a")
	handle:close()
	return content
end

describe("TOC", function()
	local base = Loader.ADDON_DIR .. "LaRutaDel60.toc"
	local forever = Loader.ADDON_DIR .. "LaRutaDel60_Forever.toc"

	it("targets the WoW Forever interface", function()
		assert.truthy(read(base):match("## Interface: 16001\n"))
	end)

	it("declares the SavedVariables", function()
		assert.truthy(read(base):match("## SavedVariables: LaRutaDel60DB\n"))
	end)

	it("keeps the _Forever TOC identical to the base TOC", function()
		assert.are.equal(read(base), read(forever))
	end)

	it("only lists files that exist", function()
		for _, file in ipairs(Loader.tocFiles(base)) do
			assert.truthy(io.open(Loader.ADDON_DIR .. file, "r"), "falta " .. file)
		end
	end)
end)
```

`tests/init_spec.lua`:
```lua
local Loader = require("helpers.loader")

describe("Core/Init", function()
	it("reads the version from the TOC metadata", function()
		local ns = Loader.load({ version = "1.2.3" })
		assert.are.equal("1.2.3", ns.VERSION)
	end)

	it("detects WoW Forever", function()
		local ns = Loader.load({ projectId = 18 })
		assert.is_true(ns.IsForever())
	end)

	it("detects a non-Forever client", function()
		local ns = Loader.load({ projectId = 1 })
		assert.is_false(ns.IsForever())
	end)

	it("registers the /ruta slash command", function()
		Loader.load()
		assert.are.equal("/ruta", SLASH_LARUTADEL601)
		assert.is_function(SlashCmdList.LARUTADEL60)
	end)

	it("initializes saved variables and greets on login", function()
		local _, env = Loader.load()
		env.fire("PLAYER_LOGIN")
		assert.is_table(LaRutaDel60DB)
		assert.are.equal(1, #env.chat)
		assert.truthy(env.chat[1]:find("Loaded. Type /ruta", 1, true))
	end)

	it("keeps existing saved variables on login", function()
		local _, env = Loader.load()
		LaRutaDel60DB = { keep = true }
		env.fire("PLAYER_LOGIN")
		assert.is_true(LaRutaDel60DB.keep)
	end)

	it("warns on login when the client is not Forever", function()
		local _, env = Loader.load({ projectId = 1 })
		env.fire("PLAYER_LOGIN")
		assert.are.equal(2, #env.chat)
		assert.truthy(env.chat[1]:find("not WoW Forever", 1, true))
	end)

	it("prints version and guide count on /ruta", function()
		local ns, env = Loader.load({ version = "9.9.9" })
		SlashCmdList.LARUTADEL60("")
		local expected = string.format("Version 9.9.9 - %d guide(s) loaded.", ns.GuideCount())
		assert.truthy(env.chat[1]:find(expected, 1, true))
	end)

	it("translates messages to Spanish", function()
		local _, env = Loader.load({ locale = "esES" })
		env.fire("PLAYER_LOGIN")
		assert.truthy(env.chat[1]:find("Cargado. Escribe /ruta", 1, true))
	end)

	it("uses Spanish for esMX too", function()
		local ns = Loader.load({ locale = "esMX" })
		assert.truthy(ns.L.LOADED:find("Cargado", 1, true))
	end)

	it("falls back to the key for missing translations", function()
		local ns = Loader.load()
		assert.are.equal("MISSING_KEY", ns.L.MISSING_KEY)
	end)
end)
```

`tests/guides_spec.lua`:
```lua
local Loader = require("helpers.loader")

describe("Guides", function()
	it("loads the compiled example guide through Guides.xml", function()
		local ns = Loader.load()
		local guide = ns.Guides["alliance-northshire-example"]
		assert.is_table(guide)
		assert.are.equal("Alliance", guide.faction)
		assert.are.equal("accept", guide.steps[2].type)
		assert.are.equal(783, guide.steps[2].questId)
	end)

	it("counts loaded guides", function()
		local ns = Loader.load()
		local count = 0
		for _ in pairs(ns.Guides) do
			count = count + 1
		end
		assert.are.equal(count, ns.GuideCount())
		assert.is_true(count >= 1)
	end)
end)
```

- [ ] **Step 4: Ejecutar y ver que falla**

Run: `~/.luarocks/bin/busted`
Expected: FAIL — errores `no existe addon/LaRutaDel60/LaRutaDel60.toc`.

- [ ] **Step 5: Crear los TOC**

`addon/LaRutaDel60/LaRutaDel60.toc` y una copia idéntica en `addon/LaRutaDel60/LaRutaDel60_Forever.toc`:
```
## Interface: 16001
## Title: La Ruta del 60
## Notes: Fastest 1-60 leveling guide for WoW Forever.
## Notes-esES: La guía de leveo 1-60 más rápida para WoW Forever.
## Author: Ricardo Olivera
## Version: 0.1.0
## SavedVariables: LaRutaDel60DB
## Category: Quests

Locales\Locales.lua
Locales\enUS.lua
Locales\esES.lua
Core\Init.lua
Guides\Guides.xml
```

Run: `cp addon/LaRutaDel60/LaRutaDel60.toc addon/LaRutaDel60/LaRutaDel60_Forever.toc`

- [ ] **Step 6: Crear los locales**

`addon/LaRutaDel60/Locales/Locales.lua`:
```lua
local _, ns = ...

-- Tabla de textos. Una clave sin traducción devuelve la propia clave, así nunca hay nil en pantalla.
ns.L = setmetatable({}, {
	__index = function(_, key)
		return key
	end,
})
```

`addon/LaRutaDel60/Locales/enUS.lua`:
```lua
local _, ns = ...
local L = ns.L

L.ADDON_TITLE = "La Ruta del 60"
L.LOADED = "Loaded. Type /ruta for info."
L.NOT_FOREVER = "Warning: this client is not WoW Forever; guides may be wrong."
L.VERSION_INFO = "Version %s - %d guide(s) loaded."
```

`addon/LaRutaDel60/Locales/esES.lua`:
```lua
local _, ns = ...

local locale = GetLocale()
if locale ~= "esES" and locale ~= "esMX" then
	return
end

local L = ns.L
L.LOADED = "Cargado. Escribe /ruta para más info."
L.NOT_FOREVER = "Aviso: este cliente no es WoW Forever; las guías pueden fallar."
L.VERSION_INFO = "Versión %s - %d guía(s) cargada(s)."
```

- [ ] **Step 7: Crear `Core/Init.lua`**

```lua
local ADDON_NAME, ns = ...
local L = ns.L

ns.VERSION = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "dev"
ns.Guides = ns.Guides or {}

function ns.IsForever()
	return WOW_PROJECT_CAMELOT ~= nil and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT
end

function ns.Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99" .. L.ADDON_TITLE .. "|r: " .. msg)
end

function ns.GuideCount()
	local count = 0
	for _ in pairs(ns.Guides) do
		count = count + 1
	end
	return count
end

function ns.HandleSlash()
	ns.Print(string.format(L.VERSION_INFO, ns.VERSION, ns.GuideCount()))
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGIN" then
		LaRutaDel60DB = LaRutaDel60DB or {}
		if not ns.IsForever() then
			ns.Print(L.NOT_FOREVER)
		end
		ns.Print(L.LOADED)
	end
end)
ns.frame = frame

SLASH_LARUTADEL601 = "/ruta"
SlashCmdList.LARUTADEL60 = ns.HandleSlash
```

- [ ] **Step 8: Ejecutar specs**

Run: `~/.luarocks/bin/busted`
Expected: `17 successes / 0 failures / 0 errors / 0 pending`.

- [ ] **Step 9: Lint y formato**

Run: `stylua addon tests && luacheck addon tests`
Expected: luacheck `Total: 0 warnings / 0 errors`. Si stylua cambia archivos, vuelve a ejecutar busted.

- [ ] **Step 10: Commit**

```bash
git add tests addon/LaRutaDel60
git commit -m "feat: addon hola mundo con /ruta, locales y harness de tests"
```

---

### Task 4: Script de verificación completa (`tools/check.sh`)

**Files:**
- Create: `tools/luals_check.sh`, `tools/check.sh`

**Interfaces:**
- Produces: `tools/check.sh` (exit 0 = todo verde) que usan los hooks, el CI, los agentes y las skills. Variable `BUSTED` opcional para la ruta del binario.

- [ ] **Step 1: Crear `tools/luals_check.sh`**

```bash
#!/usr/bin/env bash
# Diagnósticos de lua-language-server (con anotaciones de la API de WoW) sobre el addon.
set -euo pipefail
cd "$(dirname "$0")/.."
test -d .vendor/vscode-wow-api/Annotations/Core || tools/fetch_annotations.sh
LOGDIR="$(mktemp -d)"
trap 'rm -rf "$LOGDIR"' EXIT
# Se analiza la raíz para que las rutas relativas de .luarc.json resuelvan; ignoreDir excluye tests/tools/.vendor.
lua-language-server --check "$PWD" --configpath "$PWD/.luarc.json" \
	--checklevel=Warning --logpath "$LOGDIR"
```

- [ ] **Step 2: Comprobar que LuaLS detecta errores de verdad**

Run:
```bash
chmod +x tools/luals_check.sh
printf 'local _, ns = ...\nns.x = UnknownWowThing()\n' > addon/LaRutaDel60/Core/Broken.lua
tools/luals_check.sh; echo "exit=$?"
rm addon/LaRutaDel60/Core/Broken.lua
tools/luals_check.sh; echo "exit=$?"
```
Expected: primera ejecución reporta `undefined-global` para `UnknownWowThing` y `exit=1`; la segunda `no problems found` y `exit=0`. Si la segunda reporta avisos en `Core/Init.lua` o `Locales/*.lua`, corregir el código (no desactivar diagnósticos) y repetir.

- [ ] **Step 3: Crear `tools/check.sh`**

```bash
#!/usr/bin/env bash
# Verificación completa del proyecto. Debe pasar antes de cada commit.
set -euo pipefail
cd "$(dirname "$0")/.."

BUSTED="${BUSTED:-}"
if [ -z "$BUSTED" ]; then
	if command -v busted > /dev/null; then BUSTED="busted"; else BUSTED="$HOME/.luarocks/bin/busted"; fi
fi

step() { printf '\n== %s\n' "$1"; }

step "stylua"; stylua --check addon tests
step "luacheck"; luacheck --no-color addon tests
step "validar rutas"; python3 tools/validate_routes.py
step "guías compiladas al día"; python3 tools/compile_guides.py --check
step "tests Python"; python3 -m unittest discover -s tools/tests -t . -q
step "tests Lua (busted)"; "$BUSTED"
step "LuaLS"; tools/luals_check.sh

printf '\nOK: todo verde\n'
```

- [ ] **Step 4: Ejecutar**

Run: `chmod +x tools/check.sh && tools/check.sh`
Expected: última línea `OK: todo verde`.

- [ ] **Step 5: Commit**

```bash
git add tools/check.sh tools/luals_check.sh
git commit -m "chore: script de verificación completa"
```

---

### Task 5: Hooks y permisos de Claude Code

**Files:**
- Create: `.claude/hooks/post-edit.sh`, `.claude/settings.json`

**Interfaces:**
- Consumes: `tools/validate_routes.py` (Task 2), configs de Task 1.
- Produces: tras cada `Edit|Write|MultiEdit`, feedback automático a Claude (exit 2 + stderr) si luacheck o el validador de rutas fallan.

- [ ] **Step 1: Crear `.claude/hooks/post-edit.sh`**

```bash
#!/usr/bin/env bash
# PostToolUse: formatea y valida el archivo recién editado. Exit 2 = Claude ve el error y debe corregirlo.
set -uo pipefail
cd "${CLAUDE_PROJECT_DIR:-$(dirname "$0")/../..}"

file="$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input", {}).get("file_path", ""))')"
[ -n "$file" ] && [ -f "$file" ] || exit 0

case "$file" in
	*/.vendor/*|*/addon/LaRutaDel60/Guides/*) exit 0 ;;
	*.lua)
		stylua "$file" 2> /dev/null
		if ! out="$(luacheck --no-color "$file" 2>&1)"; then
			printf 'luacheck encontró problemas en %s:\n%s\n' "$file" "$out" >&2
			exit 2
		fi
		;;
	*/data/routes/*.json)
		if ! out="$(python3 tools/validate_routes.py 2>&1)"; then
			printf 'Rutas inválidas tras editar %s:\n%s\n' "$file" "$out" >&2
			exit 2
		fi
		;;
esac
exit 0
```

- [ ] **Step 2: Probar el hook a mano**

Run:
```bash
chmod +x .claude/hooks/post-edit.sh
printf 'local unused = 1\n' > /tmp/lr60_bad.lua
echo '{"tool_input":{"file_path":"/tmp/lr60_bad.lua"}}' | CLAUDE_PROJECT_DIR="$PWD" .claude/hooks/post-edit.sh; echo "exit=$?"
echo '{"tool_input":{"file_path":"'"$PWD"'/addon/LaRutaDel60/Core/Init.lua"}}' | CLAUDE_PROJECT_DIR="$PWD" .claude/hooks/post-edit.sh; echo "exit=$?"
rm /tmp/lr60_bad.lua
```
Expected: primer caso imprime aviso `unused variable 'unused'` y `exit=2`; segundo `exit=0`.

- [ ] **Step 3: Crear `.claude/settings.json`**

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "permissions": {
    "allow": [
      "Bash(tools/check.sh)",
      "Bash(tools/luals_check.sh)",
      "Bash(tools/fetch_annotations.sh)",
      "Bash(busted *)",
      "Bash(~/.luarocks/bin/busted *)",
      "Bash(luacheck *)",
      "Bash(stylua *)",
      "Bash(lua-language-server *)",
      "Bash(luajit *)",
      "Bash(python3 tools/validate_routes.py *)",
      "Bash(python3 tools/compile_guides.py *)",
      "Bash(python3 -m unittest *)",
      "WebFetch(domain:warcraft.wiki.gg)",
      "WebFetch(domain:www.wowhead.com)",
      "WebFetch(domain:github.com)",
      "WebFetch(domain:raw.githubusercontent.com)"
    ]
  },
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit",
        "hooks": [
          { "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/post-edit.sh" }
        ]
      }
    ]
  }
}
```

- [ ] **Step 4: Validar JSON**

Run: `python3 -m json.tool .claude/settings.json > /dev/null && echo JSON_OK`
Expected: `JSON_OK`.

- [ ] **Step 5: Commit**

```bash
git add .claude/settings.json .claude/hooks/post-edit.sh
git commit -m "chore: hooks post-edición y permisos de Claude Code"
```

---

### Task 6: Plugin LSP local para Claude Code

**Files:**
- Create: `.claude-plugin/marketplace.json`, `claude-plugins/wow-lua-lsp/.claude-plugin/plugin.json`
- Modify: `.claude/settings.json` (lo modifica el CLI al instalar con `--scope project`)

**Interfaces:**
- Consumes: `.luarc.json` y `.vendor/` (Task 1).
- Produces: plugin `wow-lua-lsp@larutadel60` que da a la herramienta LSP de Claude diagnósticos/definiciones en `.lua`.

- [ ] **Step 1: Crear `.claude-plugin/marketplace.json`**

```json
{
  "name": "larutadel60",
  "owner": { "name": "Ricardo Olivera" },
  "description": "Plugins locales del proyecto La Ruta del 60",
  "plugins": [
    {
      "name": "wow-lua-lsp",
      "source": "./claude-plugins/wow-lua-lsp",
      "description": "lua-language-server con anotaciones de la API de WoW"
    }
  ]
}
```

- [ ] **Step 2: Crear `claude-plugins/wow-lua-lsp/.claude-plugin/plugin.json`**

```json
{
  "name": "wow-lua-lsp",
  "version": "0.1.0",
  "description": "lua-language-server para el addon La Ruta del 60 (lee .luarc.json del proyecto)",
  "author": { "name": "Ricardo Olivera" },
  "lspServers": {
    "lua": {
      "command": "lua-language-server",
      "extensionToLanguage": { ".lua": "lua" },
      "workspaceFolder": "${CLAUDE_PROJECT_DIR}",
      "startupTimeout": 30000
    }
  }
}
```

- [ ] **Step 3: Validar**

Run: `claude plugin validate ./claude-plugins/wow-lua-lsp && claude plugin validate .`
Expected: `Validation passed` en ambos (warnings aceptables solo si no son de `lspServers`).

- [ ] **Step 4: Registrar e instalar a nivel de proyecto**

Run:
```bash
claude plugin marketplace add ./
claude plugin install wow-lua-lsp@larutadel60 --scope project
git diff .claude/settings.json
```
Expected: instalación correcta; `.claude/settings.json` gana `enabledPlugins` con `"wow-lua-lsp@larutadel60": true` (y posiblemente `extraKnownMarketplaces`). Si el CLI no añade `extraKnownMarketplaces`, añadirlo a mano:
```json
"extraKnownMarketplaces": {
  "larutadel60": { "source": { "source": "directory", "path": "./" } }
}
```
y comprobar con `claude plugin list` que el plugin aparece sin errores.

- [ ] **Step 5: Verificación manual del LSP (tras reiniciar Claude Code)**

En una sesión nueva de Claude Code en el repo, pedir: «usa la herramienta LSP para hacer hover sobre `C_AddOns` en `addon/LaRutaDel60/Core/Init.lua:4`». Expected: devuelve la documentación de la anotación de Ketho. Si no funciona, el fallback ya está cubierto por `tools/luals_check.sh` en `tools/check.sh`; anotar el problema en `docs/api/forever-api.md` sección "Tooling".

- [ ] **Step 6: Commit**

```bash
git add .claude-plugin claude-plugins .claude/settings.json
git commit -m "chore: plugin LSP local (lua-language-server) para Claude Code"
```

---

### Task 7: Subagentes

**Files:**
- Create: `.claude/agents/wow-api-expert.md`, `.claude/agents/addon-engineer.md`, `.claude/agents/route-researcher.md`, `.claude/agents/route-optimizer.md`, `.claude/agents/route-validator.md`, `.claude/agents/lua-reviewer.md`

**Interfaces:**
- Consumes: `tools/check.sh`, skills de Task 8 (por nombre), `docs/api/forever-api.md`.
- Produces: agentes invocables por nombre desde la sesión principal.

- [ ] **Step 1: `wow-api-expert.md`**

```markdown
---
name: wow-api-expert
description: Verifica si una función, evento, widget o constante de la API de WoW existe y cómo se comporta en WoW Forever 1.60.1 (Interface 16001). Úsalo ANTES de usar cualquier API de WoW que no esté ya en el código o en docs/api/forever-api.md. Solo lectura.
tools: Read, Grep, Glob, WebFetch, WebSearch
---

Eres el experto en la API de addons de WoW Forever (cliente 1.60.1, Interface 16001, Lua 5.1).

Contexto fijo:
- Forever usa la arquitectura de UI de retail 12.x (C_QuestLog, C_Map, C_Item, C_Spell...), NO la de Classic Era 1.15.
- Las restricciones de "secrets" de Midnight están activas. ~1.041 globales de FrameXML de retail fueron eliminados.
- Detección: WOW_PROJECT_ID == WOW_PROJECT_CAMELOT (18).

Proceso para cada API consultada:
1. Busca primero en `docs/api/forever-api.md` (conocimiento ya verificado del proyecto).
2. Busca en las anotaciones: `Grep` en `.vendor/vscode-wow-api/Annotations/Core` (firma, parámetros, retornos).
3. Consulta warcraft.wiki.gg (incluida la página "Patch 1.60.1/API changes") si hay dudas sobre Forever.
4. Responde con: existe sí/no/incierto, firma exacta, eventos relacionados, restricciones (protegida, combat lockdown, secret), alternativa si no existe, y las URLs consultadas.

Si confirmas algo nuevo, propón (no escribas) la línea exacta a añadir en `docs/api/forever-api.md` y, si la API es global, en `read_globals` de `.luacheckrc` y en `tests/mocks/wow.lua`.
Nunca inventes una API. "Incierto" es una respuesta válida.
```

- [ ] **Step 2: `addon-engineer.md`**

```markdown
---
name: addon-engineer
description: Implementa funcionalidad del addon (motor de guía, flecha, auto-quest, UI, módulos) en addon/LaRutaDel60 con TDD sobre los mocks de tests/. Úsalo para cualquier cambio de código Lua del addon.
tools: Read, Edit, Write, Grep, Glob, Bash
---

Implementas código del addon La Ruta del 60 para WoW Forever (Interface 16001, Lua 5.1).

Reglas no negociables (ver CLAUDE.md):
- TDD: primero el spec en `tests/*_spec.lua` (falla), luego el código mínimo, luego `tools/check.sh` verde.
- Sin globals nuevas: todo en `ns` (`local ADDON_NAME, ns = ...`). Globals permitidas: LaRutaDel60DB, SLASH_LARUTADEL601, SlashCmdList.LARUTADEL60.
- Cada API de WoW nueva: confirmarla (skill `wow-forever-api` o agente `wow-api-expert`), añadirla a `read_globals` en `.luacheckrc` y a `tests/mocks/wow.lua` imitando su comportamiento real.
- Un módulo por archivo, registrado en AMBOS TOC (`LaRutaDel60.toc` y `LaRutaDel60_Forever.toc`, idénticos). Usa la skill `new-module`.
- Textos visibles siempre vía `ns.L` con clave en `Locales/enUS.lua` y traducción en `Locales/esES.lua`.
- Nunca edites `addon/LaRutaDel60/Guides/` (generado).
- Rendimiento: nada de trabajo pesado en OnUpdate sin throttle; preferir eventos.
- No copies código de RestedXP ni de otros addons.

Termina siempre ejecutando `tools/check.sh` y reporta su salida final.
```

- [ ] **Step 3: `route-researcher.md`**

```markdown
---
name: route-researcher
description: Investiga en bases de datos web (Wowhead y similares con datos de WoW Forever) quests, NPCs, coordenadas, niveles y prerrequisitos de una zona o tramo, y los guarda como JSON crudo en data/raw/. Úsalo como primer paso de la skill add-route-segment.
tools: Read, Write, Grep, Glob, WebFetch, WebSearch
---

Recopilas datos crudos para rutas de leveo de WoW Forever. NO creas rutas: solo datos.

Salida: `data/raw/<zona-kebab>.json` con esta forma:
{
  "zone": "Elwynn Forest", "mapId": 1429, "faction": "Alliance",
  "retrievedAt": "YYYY-MM-DD",
  "quests": [
    { "questId": 783, "name": "A Threat Within", "level": 1, "minLevel": 1,
      "faction": "Alliance", "prereqs": [], "followUps": [7],
      "start": { "npcId": 823, "npc": "Sergeant Willem", "mapId": 1429, "x": 48.2, "y": 42.9 },
      "end":   { "npcId": 197, "npc": "Marshal McBride", "mapId": 1429, "x": 48.9, "y": 41.6 },
      "objectives": ["..."], "xp": 40,
      "source": "https://..." }
  ],
  "flightPaths": [], "innkeepers": [], "notes": []
}

Reglas:
- Prioriza fuentes con datos de WoW Forever (1.60.1). Forever tiene ~1.000 quests nuevas y la XP de mazmorras va por quests: datos de Classic Era pueden ser incorrectos. Marca `"forever": false` en cada quest cuyo dato solo encuentres para Classic Era.
- Cada quest DEBE tener `source` (URL). Nada inventado: si falta un dato, omítelo y anótalo en `notes`.
- Coordenadas en porcentaje 0-100 del mapa `mapId` (uiMapID).
- Si un archivo de la zona ya existe, fusiona sin borrar datos verificados.
```

- [ ] **Step 4: `route-optimizer.md`**

```markdown
---
name: route-optimizer
description: Construye u optimiza una ruta de leveo (data/routes/<faccion>/<id>.json) a partir de los datos crudos de data/raw/, minimizando tiempo hasta el nivel objetivo. Úsalo tras route-researcher.
tools: Read, Write, Edit, Grep, Glob, Bash
---

Diseñas rutas de leveo lo más rápidas posible para WoW Forever, en el formato de la skill `guide-format`.

Criterios (en orden):
1. XP por minuto: agrupa quests por área, acepta todo lo cercano antes de salir, entrega en lote.
2. Menos desplazamiento: evita volver sobre tus pasos; usa hearthstone (`hearth`) y vuelos (`fly`) cuando ahorren tiempo; fija la piedra (paso `note`) donde convenga para el siguiente regreso.
3. Nunca dejar al jugador sin nivel suficiente: estima XP acumulada con el `xp` de data/raw y respeta minLevel.
4. Entrena clase (`train`) en los niveles pares cuando pases cerca de un entrenador.
5. Variantes por raza/clase solo cuando cambia la zona de inicio o hay quests de clase.

Reglas:
- Solo usa quests presentes en data/raw (con `source`). Copia `source` al paso.
- Quests aceptadas en rutas anteriores van en `carriedQuests`.
- Enlaza tramos con `next`.
- Al terminar: `python3 tools/validate_routes.py && python3 tools/compile_guides.py` y corrige hasta que pase.
- Explica en tu respuesta final el razonamiento del orden y la XP estimada al final del tramo.
```

- [ ] **Step 5: `route-validator.md`**

```markdown
---
name: route-validator
description: Revisa la coherencia de rutas en data/routes contra los datos crudos de data/raw (prerrequisitos, niveles, coordenadas, facción, XP hasta el nivel objetivo). Solo lectura; reporta problemas. Úsalo tras route-optimizer y antes de commitear rutas.
tools: Read, Grep, Glob, Bash
---

Eres un revisor escéptico de rutas de leveo. Asume que hay errores hasta demostrar lo contrario.

1. Ejecuta `python3 tools/validate_routes.py` (reglas estructurales). Si falla, repórtalo y para.
2. Para cada ruta indicada, comprueba contra data/raw:
   - Cada questId existe en data/raw y la facción coincide.
   - Prerrequisitos (`prereqs`) aceptados y entregados antes, en esta ruta o en la cadena `next` previa.
   - Nivel del jugador estimado (XP acumulada) >= minLevel de cada quest al aceptarla.
   - Coordenadas del paso == coordenadas start/end del NPC (tolerancia 1.0).
   - Quests con `"forever": false` señaladas como riesgo.
   - El último tramo de la cadena llega a maxLevel 60.
3. Informe: lista numerada `ruta:steps[n] — problema — evidencia`, ordenada por gravedad. Sin problemas: dilo explícitamente.
No edites archivos.
```

- [ ] **Step 6: `lua-reviewer.md`**

```markdown
---
name: lua-reviewer
description: Revisa cambios de código Lua del addon antes de commitear (taint, rendimiento, globals, compatibilidad Forever 16001, Lua 5.1, tests). Solo lectura. Úsalo al terminar cada tarea de código.
tools: Read, Grep, Glob, Bash
---

Revisas el diff actual (`git diff` y `git diff --cached`) del addon La Ruta del 60.

Checklist:
- Lua 5.1: sin goto, //, operadores de bits nativos, table.unpack sin fallback, atributos <const>/<close>.
- Globals: ninguna nueva fuera de las permitidas en CLAUDE.md.
- APIs de WoW: cada una existe en Forever (pregunta al agente wow-api-expert si dudas), está en `.luacheckrc` y en `tests/mocks/wow.lua`.
- Taint/seguridad: no modificar frames protegidos ni llamar funciones protegidas en combate; respetar InCombatLockdown(); no hookear con reemplazo funciones de Blizzard (usar hooksecurefunc).
- Rendimiento: OnUpdate con throttle, sin crear tablas/closures por frame, desregistrar eventos que ya no hacen falta.
- Textos visibles vía ns.L con clave en enUS y esES.
- TOC: archivo nuevo en ambos TOC, idénticos.
- Tests: el comportamiento nuevo tiene spec; ejecuta `tools/check.sh`.

Salida: hallazgos `archivo:línea — problema — arreglo sugerido`, de más a menos grave; o "Sin hallazgos" con la salida de check.sh.
No edites archivos.
```

- [ ] **Step 7: Verificar frontmatter**

Run: `for f in .claude/agents/*.md; do head -2 "$f" | tail -1; done`
Expected: seis líneas `name: ...` con los nombres de archivo correspondientes.

- [ ] **Step 8: Commit**

```bash
git add .claude/agents
git commit -m "feat: subagentes especializados para addon y rutas"
```

---

### Task 8: Skills y documentación de la API de Forever

**Files:**
- Create: `docs/api/forever-api.md`, `.claude/skills/wow-forever-api/SKILL.md`, `.claude/skills/guide-format/SKILL.md`, `.claude/skills/add-route-segment/SKILL.md`, `.claude/skills/new-module/SKILL.md`, `.claude/skills/release/SKILL.md`, `.claude/skills/debug-in-game/SKILL.md`

**Interfaces:**
- Consumes: formato de ruta (Task 2), harness (Task 3), check.sh (Task 4), agentes (Task 7), CI release (Task 10, por nombre del workflow).
- Produces: skills invocables `/wow-forever-api`, `/guide-format`, `/add-route-segment`, `/new-module`, `/release`, `/debug-in-game`.

- [ ] **Step 1: `docs/api/forever-api.md`**

```markdown
# API de WoW Forever — conocimiento verificado

Fuente de verdad del proyecto sobre la API. Cada entrada lleva fecha y fuente. Actualízala cuando verifiques algo (agente `wow-api-expert`).

## Cliente
- Versión 1.60.1, `## Interface: 16001`. Lanzamiento 2026-11-04. (2026-11-03, github.com/everbuff/everbuff-wow-addon/issues/1)
- TOC con sufijo `_Forever` o `_Camelot` se cargan con prioridad; `[AllowLoadGameType camelot]` para archivos solo-Forever. (2026-11-03, forevermeta.me)
- `WOW_PROJECT_CAMELOT = 18`; Forever: `WOW_PROJECT_ID == WOW_PROJECT_CAMELOT` (desde build 70170). (2026-11-03, forevermeta.me)

## Arquitectura de API
- Comparte arquitectura de UI y la mayoría de APIs de retail 12.1.5 (C_QuestLog, C_Map, C_Item, C_Spell, C_Traits). Un addon de Classic Era no carga tal cual. (2026-11-03, Blizzard en Discord UI dev vía forevermeta.me)
- Restricciones de "secrets" de Midnight activas. (idem)
- ~1.041 globales de FrameXML de retail eliminados en 1.60.1. Lista completa: https://warcraft.wiki.gg (Patch 1.60.1/API changes).
- Títulos de quest: usar `C_QuestLog.GetTitleForQuestID`. (2026-11-03, changelogs de addons)

## Usado por el addon
| API | Uso | Verificado |
|---|---|---|
| `C_AddOns.GetAddOnMetadata(addon, field)` | versión desde el TOC | anotaciones Ketho |
| `CreateFrame("Frame")` / `:RegisterEvent` / `:SetScript("OnEvent")` | eventos | anotaciones Ketho |
| `DEFAULT_CHAT_FRAME:AddMessage(msg)` | chat | anotaciones Ketho |
| `GetLocale()` | locale | anotaciones Ketho |
| Evento `PLAYER_LOGIN` | inicialización | anotaciones Ketho |

## Pendiente de verificar en el juego
- Carpeta de instalación de Forever en Windows (`_forever_`, `_camelot_`...). `scripts/deploy.ps1` prueba varias.

## Tooling
- LSP: plugin `wow-lua-lsp` (lua-language-server 3.19 + anotaciones Ketho mainline en `.vendor/`).
```

- [ ] **Step 2: `.claude/skills/wow-forever-api/SKILL.md`**

```markdown
---
name: wow-forever-api
description: Usar antes de escribir o revisar código Lua que llame a la API de WoW en este proyecto (WoW Forever 1.60.1, Interface 16001). Explica cómo verificar una API, qué arquitectura usa Forever y qué tocar al añadir una API nueva (luacheck, mocks, docs).
---

# API de WoW Forever

Forever = API moderna de retail 12.x sobre Lua 5.1, con restricciones de Midnight. NO es la API de Classic Era 1.15 ni la de 1.12.

## Antes de usar una API
1. Mira `docs/api/forever-api.md`. Si está, úsala.
2. Si no: `Grep` en `.vendor/vscode-wow-api/Annotations/Core` por el nombre (firma y tipos). Si no existe ahí, NO la uses.
3. Si es de quests/mapa/gossip/items o hay duda sobre Forever: delega en el agente `wow-api-expert`.

## Al añadir una API al código
- Añádela a `read_globals` en `.luacheckrc` (solo el nombre raíz, p. ej. `C_QuestLog`).
- Añade a `tests/mocks/wow.lua` un mock con el mismo contrato (parámetros, retornos, nil cuando corresponda).
- Añade la fila en la tabla "Usado por el addon" de `docs/api/forever-api.md`.

## Eventos clave para una guía de leveo (verificar cada uno antes de usarlo)
QUEST_ACCEPTED, QUEST_TURNED_IN, QUEST_REMOVED, QUEST_LOG_UPDATE, QUEST_DETAIL, QUEST_PROGRESS, QUEST_COMPLETE, GOSSIP_SHOW, QUEST_GREETING, PLAYER_LEVEL_UP, PLAYER_XP_UPDATE, ZONE_CHANGED_NEW_AREA, TAXIMAP_OPENED.

## Trampas habituales
- Funciones protegidas y combate: comprobar `InCombatLockdown()` antes de tocar frames seguros.
- Patrones de Classic Era (`GetQuestLogTitle`, `GetNumQuestLogEntries`) pueden no existir: usar `C_QuestLog.*`.
- Coordenadas: `C_Map.GetPlayerMapPosition(uiMapID, "player")` devuelve 0-1; el formato de guía usa 0-100.
```

- [ ] **Step 3: `.claude/skills/guide-format/SKILL.md`**

```markdown
---
name: guide-format
description: Usar al crear, editar o leer rutas de leveo (data/routes/**/*.json) o al trabajar con las guías compiladas (addon/LaRutaDel60/Guides). Define el esquema JSON de una ruta, sus reglas de validación y cómo se compila a Lua.
---

# Formato de guía

Las rutas son DATOS. Fuente: `data/routes/<alliance|horde|both>/<id>.json`. Compiladas a `addon/LaRutaDel60/Guides/<id>.lua` + `Guides.xml` (no editar nunca a mano).

## Ruta
| Campo | Tipo | Regla |
|---|---|---|
| id | string | kebab-case; = nombre de archivo; único |
| name | {enUS, esES?} | enUS obligatorio |
| faction | string | Alliance, Horde, Both |
| races, classes | string[] | opcional (p. ej. "Human", "Warrior") |
| minLevel, maxLevel | int | 1..60, min <= max |
| next | string | opcional, id de ruta existente |
| carriedQuests | int[] | quests aceptadas en rutas anteriores |
| steps | Step[] | no vacía |

## Step
| type | Obligatorio | Significado |
|---|---|---|
| accept | questId | aceptar quest |
| complete | questId (aceptada antes o en carriedQuests) | completar objetivos |
| turnin | questId (aceptada antes o en carriedQuests) | entregar |
| goto | coords | ir a un punto |
| hearth | — | usar piedra de hogar |
| fly | — | volar (usar text/coords para destino) |
| train | — | entrenar clase/profesión |
| note | text | instrucción libre |

Campos opcionales en cualquier paso: `npcId` (int>0), `coords {mapId, x, y}` (x,y en 0-100, mapId = uiMapID), `text {enUS, esES?}`, `source` (URL).

## En Lua
`ns.Guides["<id>"]` = misma estructura que el JSON (claves ordenadas). Ej.: `ns.Guides[id].steps[1].questId`.

## Comandos
- Validar: `python3 tools/validate_routes.py`
- Compilar: `python3 tools/compile_guides.py` (y `--check` en CI)
El hook post-edición valida al guardar cualquier JSON de data/routes.

## Ejemplo
Ver `data/routes/alliance/alliance-northshire-example.json`.
```

- [ ] **Step 4: `.claude/skills/add-route-segment/SKILL.md`**

```markdown
---
name: add-route-segment
description: Usar cuando el usuario pida añadir o rehacer un tramo de ruta de leveo (p. ej. "ruta humano 1-10", "Horda 30-40 en Stranglethorn"). Orquesta investigar → JSON crudo → optimizar → validar → compilar → commit.
---

# Añadir un tramo de ruta

Entrada: facción, raza/clase (si aplica), rango de niveles, zonas.

1. **Plan**: decide id(s) de ruta (`<faccion>-<zona>-<min>-<max>`), la ruta anterior (`next` de la previa) y quests arrastradas.
2. **Investigar**: agente `route-researcher` por cada zona → `data/raw/<zona>.json`. Revisa que cada quest tenga `source`.
3. **Optimizar**: agente `route-optimizer` → `data/routes/<faccion>/<id>.json`. Actualiza `next` de la ruta previa.
4. **Validar**: agente `route-validator`. Si reporta problemas, vuelve al paso 3 con el informe (máx. 3 iteraciones; si persisten, informa al usuario).
5. **Compilar**: `python3 tools/compile_guides.py` y `tools/check.sh` verde.
6. **Commit**: `git add data/ addon/LaRutaDel60/Guides && git commit -m "feat(rutas): <id>"`.
7. Informa al usuario: niveles cubiertos, nº de pasos, quests con `"forever": false`, y pide prueba en el juego.

No inventes datos: si falta información, márcalo en el informe en lugar de rellenar.
```

- [ ] **Step 5: `.claude/skills/new-module/SKILL.md`**

````markdown
---
name: new-module
description: Usar al crear un archivo/módulo Lua nuevo en addon/LaRutaDel60 (Core, UI o Modules). Plantilla de módulo, registro en ambos TOC, locale y spec de test.
---

# Nuevo módulo

1. Spec primero: `tests/<modulo>_spec.lua` usando `require("helpers.loader").load(opts)` (devuelve `ns, env`; `env.fire(evento, ...)` dispara eventos; `env.chat` captura el chat).
2. Archivo `addon/LaRutaDel60/<Carpeta>/<Nombre>.lua`:

```lua
local _, ns = ...

local Module = {}
ns.<Nombre> = Module

function Module.Example()
	-- ...
end
```

3. Añádelo en `LaRutaDel60.toc` en su orden de carga (antes de quien lo use, después de `Core\Init.lua` si usa `ns.Print`), y copia el TOC: `cp addon/LaRutaDel60/LaRutaDel60.toc addon/LaRutaDel60/LaRutaDel60_Forever.toc`.
4. Textos: claves en `Locales/enUS.lua` y `Locales/esES.lua`.
5. APIs de WoW nuevas: skill `wow-forever-api`.
6. `tools/check.sh` verde → agente `lua-reviewer` → commit.
````

- [ ] **Step 6: `.claude/skills/release/SKILL.md`**

```markdown
---
name: release
description: Usar cuando el usuario pida publicar/sacar una versión del addon. Sube la versión en los TOC, actualiza CHANGELOG.md, crea tag vX.Y.Z y lo empuja para que el CI genere el zip del release.
---

# Release

1. `tools/check.sh` verde y working tree limpio (`git status`).
2. Decide versión semver (fix → patch, feature → minor). Pregunta al usuario si dudas.
3. Cambia `## Version:` en `addon/LaRutaDel60/LaRutaDel60.toc` y copia a `_Forever.toc`.
4. Añade al principio de `CHANGELOG.md` (créalo si no existe):
   `## vX.Y.Z - YYYY-MM-DD` + viñetas desde `git log --oneline <tag-anterior>..HEAD`.
5. `git commit -am "chore: release vX.Y.Z"` y `git tag vX.Y.Z`.
6. Pide confirmación al usuario antes de `git push origin main --tags` (es público).
7. El workflow `.github/workflows/ci.yml` verifica que el tag coincide con la versión del TOC y publica `LaRutaDel60-vX.Y.Z.zip` en GitHub Releases.
8. Recuerda al usuario: en Windows `scripts/deploy.ps1 -Source release -Repo <owner>/<repo>`.
```

- [ ] **Step 7: `.claude/skills/debug-in-game/SKILL.md`**

```markdown
---
name: debug-in-game
description: Usar cuando el usuario pegue un error del juego (BugSack/BugGrabber, mensaje de chat, Lua error) o el contenido de su SavedVariables, o diga que algo del addon no funciona en WoW. Convierte el fallo en un test que lo reproduce y luego lo arregla.
---

# Depurar un fallo del juego

Usa también `superpowers:systematic-debugging`.

1. Pide (si falta): texto completo del error con stack (BugSack: copiar), versión del addon (`/ruta`), qué hacía, y si es de datos, el archivo `WTF\Account\<CUENTA>\SavedVariables\LaRutaDel60.lua` de Windows.
2. Localiza `archivo:línea` del stack dentro de `addon/LaRutaDel60`. Si el error está en código de Blizzard, busca qué llamada nuestra lo provoca.
3. Si es "attempt to call a nil value" sobre una API de WoW: es una API inexistente en Forever → agente `wow-api-expert`.
4. Escribe un spec en `tests/` que reproduzca el fallo con los mocks (ajusta `tests/mocks/wow.lua` para imitar el comportamiento real observado). Debe fallar.
5. Arregla, `tools/check.sh` verde, commit `fix: ...`.
6. Pide al usuario verificar en el juego tras `scripts/deploy.ps1` + `/reload`.
```

- [ ] **Step 8: Verificar**

Run: `ls .claude/skills/*/SKILL.md | wc -l && grep -h '^name:' .claude/skills/*/SKILL.md`
Expected: `6` y los seis nombres.

- [ ] **Step 9: Commit**

```bash
git add docs/api .claude/skills
git commit -m "feat: skills del proyecto y documentación de la API de Forever"
```

---

### Task 9: CLAUDE.md

**Files:**
- Create: `CLAUDE.md`

**Interfaces:**
- Consumes: todo lo anterior por nombre.
- Produces: contexto que Claude Code carga en cada sesión.

- [ ] **Step 1: Escribir `CLAUDE.md`**

````markdown
# La Ruta del 60

Addon gratuito para **WoW Forever** (Classic+ oficial, cliente 1.60.1, `## Interface: 16001`) que guía a cualquier personaje de 1 a 60 por la ruta más rápida. Desarrollo 100% con IA. Se juega en Windows; se desarrolla en macOS.

## Reglas
- **API**: Forever usa la API moderna de retail 12.x sobre Lua 5.1, no la de Classic Era. Antes de usar cualquier API de WoW: skill `wow-forever-api` / agente `wow-api-expert`. Conocimiento verificado en `docs/api/forever-api.md`.
- **Lua 5.1**: sin `goto`, `//`, bitops nativos, `<const>`.
- **Sin globals**: todo en `ns` (`local ADDON_NAME, ns = ...`). Solo se permiten `LaRutaDel60DB`, `SLASH_LARUTADEL601`, `SlashCmdList.LARUTADEL60`.
- **TDD**: spec en `tests/` primero (busted + `tests/mocks/wow.lua` + `tests/helpers/loader.lua`).
- **Rutas = datos**: `data/routes/**/*.json` (skill `guide-format`). `addon/LaRutaDel60/Guides/` es GENERADO: nunca editar a mano.
- **TOC**: `LaRutaDel60.toc` y `LaRutaDel60_Forever.toc` siempre idénticos.
- **Textos**: siempre `ns.L` con clave en `Locales/enUS.lua` + `Locales/esES.lua`.
- **Original**: no copiar código ni guías de RestedXP u otros addons.
- Código/identificadores en inglés; docs, comentarios y mensajes de herramientas en español.
- Commits pequeños, Conventional Commits. No hacer push sin que el usuario lo pida.

## Comandos
| Qué | Comando |
|---|---|
| Verificación completa (obligatoria antes de commit) | `tools/check.sh` |
| Tests Lua | `~/.luarocks/bin/busted` (o `busted`) |
| Tests Python | `python3 -m unittest discover -s tools/tests -t . -q` |
| Validar / compilar rutas | `python3 tools/validate_routes.py` / `python3 tools/compile_guides.py` |
| LuaLS | `tools/luals_check.sh` |
| Instalar toolchain (macOS) | `tools/setup.sh` |
| Instalar en Windows | `scripts\deploy.ps1` (PowerShell) |

Los hooks de `.claude/settings.json` formatean y lintan cada `.lua` editado y validan cada JSON de rutas; si devuelven error, corrígelo antes de seguir.

## Agentes (`.claude/agents/`)
- `wow-api-expert` — verifica APIs de Forever (solo lectura).
- `addon-engineer` — implementa código del addon con TDD.
- `route-researcher` — datos crudos de quests desde la web → `data/raw/`.
- `route-optimizer` — construye rutas óptimas → `data/routes/`.
- `route-validator` — revisa coherencia de rutas (solo lectura).
- `lua-reviewer` — revisión de código antes de commit (solo lectura).

## Skills (`.claude/skills/`)
`wow-forever-api`, `guide-format`, `add-route-segment`, `new-module`, `release`, `debug-in-game`.

## Estructura
```
addon/LaRutaDel60/   addon (lo que se copia a Interface\AddOns)
  Core/ UI/ Modules/ Locales/ Libs/ Guides/(generado)
data/raw/            datos crudos web (con source)
data/routes/         rutas fuente (JSON)
tools/               scripts Python/bash (validador, compilador, check)
tests/               specs busted + mocks
scripts/deploy.ps1   despliegue en Windows
docs/                specs, planes, API
```
````

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: CLAUDE.md con reglas, comandos, agentes y skills"
```

---

### Task 10: CI (GitHub Actions) y despliegue Windows

**Files:**
- Create: `.github/workflows/ci.yml`, `scripts/deploy.ps1`

**Interfaces:**
- Consumes: `tools/check.sh`, `tools/fetch_annotations.sh`, TOC `## Version:`.
- Produces: job `check` en cada push/PR; job `release` en tags `v*` que publica `LaRutaDel60-<tag>.zip` (carpeta `LaRutaDel60/` en la raíz del zip). `deploy.ps1 -WowPath <ruta> -Source git|release -Repo owner/name`.

- [ ] **Step 1: Crear `.github/workflows/ci.yml`**

```yaml
name: CI

on:
  push:
    branches: [main]
    tags: ["v*"]
  pull_request:

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"

      - uses: leafo/gh-actions-lua@v10
        with:
          luaVersion: "luajit-2.1"

      - uses: leafo/gh-actions-luarocks@v4

      - name: Instalar busted y luacheck
        run: |
          luarocks install busted
          luarocks install luacheck

      - name: Instalar stylua
        uses: JohnnyMorganz/stylua-action@v4
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          version: v2.6.0
          args: --version

      - name: Instalar lua-language-server
        run: |
          mkdir -p "$HOME/luals"
          curl -sSL https://github.com/LuaLS/lua-language-server/releases/download/3.19.2/lua-language-server-3.19.2-linux-x64.tar.gz \
            | tar -xz -C "$HOME/luals"
          echo "$HOME/luals/bin" >> "$GITHUB_PATH"

      - name: Anotaciones API WoW
        run: tools/fetch_annotations.sh

      - name: Verificación completa
        run: tools/check.sh

  release:
    if: startsWith(github.ref, 'refs/tags/v')
    needs: check
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v4

      - name: Comprobar versión del TOC
        run: |
          toc_version="$(sed -n 's/^## Version: //p' addon/LaRutaDel60/LaRutaDel60.toc | tr -d '\r')"
          if [ "v$toc_version" != "$GITHUB_REF_NAME" ]; then
            echo "El tag $GITHUB_REF_NAME no coincide con la versión del TOC ($toc_version)" >&2
            exit 1
          fi

      - name: Empaquetar
        run: |
          mkdir -p dist
          (cd addon && zip -r "../dist/LaRutaDel60-$GITHUB_REF_NAME.zip" LaRutaDel60)

      - uses: softprops/action-gh-release@v2
        with:
          files: dist/*.zip
          generate_release_notes: true
```

- [ ] **Step 2: Validar YAML**

Run: `python3 -c "import sys; t=open('.github/workflows/ci.yml').read(); assert '\t' not in t; print('YAML_NO_TABS_OK')"`
Expected: `YAML_NO_TABS_OK`. (La validación real ocurre en el primer push.)

- [ ] **Step 3: Crear `scripts/deploy.ps1`**

```powershell
<#
.SYNOPSIS
    Instala La Ruta del 60 en WoW Forever (Windows).
.EXAMPLE
    .\scripts\deploy.ps1
    .\scripts\deploy.ps1 -WowPath "D:\Games\World of Warcraft\_forever_"
    .\scripts\deploy.ps1 -Source release -Repo usuario/larutadel60
#>
[CmdletBinding()]
param(
    [string]$WowPath = $env:WOW_FOREVER_PATH,
    [ValidateSet("git", "release")]
    [string]$Source = "git",
    [string]$Repo = "",
    [string]$RepoPath = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
$AddonName = "LaRutaDel60"

if (-not $WowPath) {
    $roots = @("C:\Program Files (x86)\World of Warcraft", "C:\Program Files\World of Warcraft", "D:\World of Warcraft")
    $flavors = @("_forever_", "_camelot_", "_classic_")
    $WowPath = foreach ($root in $roots) {
        foreach ($flavor in $flavors) {
            $candidate = Join-Path $root $flavor
            if (Test-Path $candidate) { $candidate }
        }
    } | Select-Object -First 1
}
if (-not $WowPath -or -not (Test-Path $WowPath)) {
    throw "No encuentro la carpeta de WoW Forever. Usa -WowPath 'C:\...\World of Warcraft\_forever_' o define la variable WOW_FOREVER_PATH."
}
Write-Host "Carpeta de WoW: $WowPath"

$AddOns = Join-Path $WowPath "Interface\AddOns"
New-Item -ItemType Directory -Force -Path $AddOns | Out-Null
$Target = Join-Path $AddOns $AddonName

if ($Source -eq "git") {
    git -C $RepoPath pull --ff-only
    if ($LASTEXITCODE -ne 0) { throw "git pull falló en $RepoPath" }
    $From = Join-Path $RepoPath "addon\$AddonName"
}
else {
    if (-not $Repo) { throw "Con -Source release indica -Repo usuario/repositorio" }
    $release = Invoke-RestMethod "https://api.github.com/repos/$Repo/releases/latest"
    $asset = $release.assets | Where-Object { $_.name -like "$AddonName-*.zip" } | Select-Object -First 1
    if (-not $asset) { throw "El release $($release.tag_name) no tiene zip del addon" }
    $tmp = Join-Path $env:TEMP "$AddonName-deploy"
    if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
    New-Item -ItemType Directory -Path $tmp | Out-Null
    $zip = Join-Path $tmp "addon.zip"
    Invoke-WebRequest $asset.browser_download_url -OutFile $zip
    Expand-Archive $zip -DestinationPath $tmp
    $From = Join-Path $tmp $AddonName
    Write-Host "Release: $($release.tag_name)"
}

if (-not (Test-Path (Join-Path $From "$AddonName.toc"))) { throw "No encuentro $AddonName.toc en $From" }
if (Test-Path $Target) { Remove-Item -Recurse -Force $Target }
Copy-Item -Recurse $From $Target
Write-Host "Instalado en $Target" -ForegroundColor Green
Write-Host "En el juego: /reload  (y /ruta para ver la versión)"
```

- [ ] **Step 4: Comprobar sintaxis de PowerShell si hay pwsh**

Run: `command -v pwsh >/dev/null && pwsh -NoProfile -Command "[System.Management.Automation.Language.Parser]::ParseFile('scripts/deploy.ps1',[ref]\$null,[ref]\$e) > \$null; if (\$e) { \$e; exit 1 } else { 'PS_OK' }" || echo "pwsh no instalado: validar en Windows"`
Expected: `PS_OK` o el aviso de pwsh no instalado.

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/ci.yml scripts/deploy.ps1
git commit -m "ci: verificación y release en GitHub Actions; deploy.ps1 para Windows"
```

---

### Task 11: Verificación final y publicación en GitHub

**Files:** ninguno nuevo.

- [ ] **Step 1: Verificación completa**

Run: `tools/check.sh && git status --short`
Expected: `OK: todo verde` y working tree limpio.

- [ ] **Step 2: Revisión de criterios de éxito de la spec**

Comprobar uno a uno (spec §9): check.sh pasa; LSP del Task 6 Step 5; 6 agentes + 6 skills referenciados en CLAUDE.md (`grep -c` de cada nombre en CLAUDE.md ≥ 1); deploy y CI pendientes de los pasos siguientes.

- [ ] **Step 3: Publicar en GitHub (requiere confirmación del usuario)**

Preguntar al usuario nombre y visibilidad del repo. Luego:
```bash
gh repo create <usuario>/larutadel60 --<public|private> --source . --remote origin --push
gh run watch --exit-status
```
Expected: CI verde en GitHub.

- [ ] **Step 4: Prueba en Windows (usuario)**

Instrucciones al usuario:
```powershell
git clone https://github.com/<usuario>/larutadel60.git
cd larutadel60
powershell -ExecutionPolicy Bypass -File .\scripts\deploy.ps1
```
En el juego: el chat muestra `La Ruta del 60: Cargado. Escribe /ruta para más info.`; `/ruta` muestra `Versión 0.1.0 - 1 guía(s) cargada(s).` Si aparece el aviso "no es WoW Forever" o la carpeta no se encuentra, actualizar `docs/api/forever-api.md` y `deploy.ps1` con la ruta/valor real.
