# Base técnica de La Ruta del 60 — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Objetivo:** dejar el repositorio listo para desarrollar 100% con IA un addon de leveo 1-60 para WoW Forever: toolchain Lua (LSP, lint, formato, tests), pipeline de rutas JSON→Lua, addon "hola mundo", agentes, skills, hooks, CI y despliegue a Windows.

**Arquitectura:** primero se escriben los **tests de aceptación de caja negra** derivados de la spec (§11), que quedan congelados. Después cada tarea implementa lo justo para ponerlos en verde. El addon vive en `addon/LaRutaDel60/`. Las rutas son datos (`data/routes/**/*.json`) que se validan y se compilan a `addon/LaRutaDel60/Guides/`. Los tests Lua corren con busted sobre LuaJIT (compatible con Lua 5.1), con un emulador del cliente en `tests/support/`. Los de Python y herramientas usan unittest y ejecutan las CLIs como subprocesos.

**Tech Stack:** Lua 5.1 / LuaJIT 2.1, busted 2.3, luacheck 1.2, stylua 2.6, lua-language-server 3.19, anotaciones Ketho `vscode-wow-api`, Python 3 (solo stdlib), GitHub Actions, PowerShell 5+.

## Restricciones globales

- **Idioma:** código en inglés (identificadores, comentarios, strings, mensajes de CLI, nombres de tests, commits). Explicaciones en castellano (docs, CLAUDE.md, agentes, skills).
- **Tests de aceptación congelados:** `tests/acceptance/`, `tests/support/` y `tools/tests/acceptance/` no se modifican desde la Tarea 3 en adelante. Si una tarea no puede ponerlos en verde sin cambiarlos: PARAR y preguntar al usuario.
- Cliente objetivo: WoW Forever 1.60.1, `## Interface: 16001`.
- Lua 5.1: sin `goto`, `//`, operadores bit nativos, `<const>`/`<close>`.
- API moderna (retail 12.x). Detección de Forever: `WOW_PROJECT_ID == WOW_PROJECT_CAMELOT` (18).
- Globals permitidas: `LaRutaDel60DB`, `SLASH_LARUTADEL601`, `SlashCmdList.LARUTADEL60`. Todo lo demás en `ns` (`local ADDON_NAME, ns = ...`).
- Comando de chat: `/ruta`. Textos al jugador en enUS + esES (esMX usa esES), exactamente los de la spec §11.2.
- `addon/LaRutaDel60/Guides/` es generado: nunca se edita a mano.
- No copiar código ni guías de RestedXP u otros addons.
- Python solo stdlib.
- Commits con trailer `Co-Authored-By: Claude <modelo que hizo el commit> <noreply@anthropic.com>` (p. ej. Opus 5.5, Sonnet 5.5 o Haiku 5.5).

## Estructura de archivos

```
.gitignore .editorconfig .luarc.json .luacheckrc .stylua.toml .styluaignore .busted
CLAUDE.md
.claude-plugin/marketplace.json
claude-plugins/wow-lua-lsp/.claude-plugin/plugin.json
.claude/settings.json
.claude/hooks/post-edit.sh
.claude/agents/{wow-api-expert,addon-engineer,route-researcher,route-optimizer,route-validator,lua-reviewer}.md
.claude/skills/{wow-forever-api,guide-format,add-route-segment,new-module,release,debug-in-game}/SKILL.md
addon/LaRutaDel60/LaRutaDel60.toc
addon/LaRutaDel60/LaRutaDel60_Forever.toc
addon/LaRutaDel60/Locales/{Locales,enUS,esES}.lua
addon/LaRutaDel60/Core/Init.lua
addon/LaRutaDel60/Guides/                    (GENERATED)
data/raw/.gitkeep
data/routes/alliance/alliance-northshire-example.json
tools/__init__.py
tools/validate_routes.py
tools/compile_guides.py
tools/setup.sh tools/fetch_annotations.sh tools/check.sh tools/luals_check.sh
tools/tests/__init__.py
tools/tests/acceptance/{__init__,support}.py
tools/tests/acceptance/dump_guide.lua
tools/tests/acceptance/test_route_pipeline.py
tools/tests/acceptance/test_tooling.py
tests/support/wow_mock.lua                   (client API emulation)
tests/support/client.lua                     (TOC loader, slash, chat, globals)
tests/acceptance/toc_spec.lua
tests/acceptance/addon_spec.lua
scripts/deploy.ps1
.github/workflows/ci.yml
docs/api/forever-api.md
```

---

### Tarea 1: Configuración del toolchain (sin código de producto)

**Archivos:**
- Crear: `.gitignore`, `.editorconfig`, `.luarc.json`, `.luacheckrc`, `.stylua.toml`, `.styluaignore`, `.busted`, `tools/setup.sh`, `tools/fetch_annotations.sh`, `data/raw/.gitkeep`

**Interfaces:**
- Produce: `.vendor/vscode-wow-api/Annotations/Core`, `~/.luarocks/bin/busted` (LuaJIT), y la config que respetan todas las tareas.

- [ ] **Paso 1: `.gitignore`**

```gitignore
.vendor/
dist/
check.json
__pycache__/
*.pyc
.DS_Store
luacov.*
```

- [ ] **Paso 2: `.editorconfig`**

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

[*.{py,md}]
indent_style = space
indent_size = 4

[*.{json,yml,yaml}]
indent_style = space
indent_size = 2

[*.ps1]
end_of_line = crlf
indent_style = space
indent_size = 4
```

- [ ] **Paso 3: `.stylua.toml` y `.styluaignore`**

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

- [ ] **Paso 4: `.luacheckrc`**

```lua
std = "lua51"
max_line_length = 120
exclude_files = { ".vendor/**", "addon/LaRutaDel60/Libs/**" }

-- Globals the addon is allowed to write.
globals = {
	"LaRutaDel60DB",
	"SLASH_LARUTADEL601",
	SlashCmdList = { fields = { "LARUTADEL60" } },
}

-- WoW API the addon reads. Add every new API here (see docs/api/forever-api.md).
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
	-- The client emulation installs WoW globals on purpose.
	ignore = { "111", "112", "113", "121", "122", "142", "143" },
}

files["tools/tests/**/*.lua"] = { std = "max" }
```

- [ ] **Paso 5: `.luarc.json`**

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

- [ ] **Paso 6: `.busted`**

```lua
return {
	_all = {
		lpath = "tests/?.lua",
		ROOT = { "tests" },
		pattern = "_spec",
	},
}
```

- [ ] **Paso 7: `tools/fetch_annotations.sh`**

```bash
#!/usr/bin/env bash
# Downloads (or updates) Ketho's WoW API LuaLS annotations into .vendor/.
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
test -d "$DEST/Annotations/Core" || { echo "ERROR: $DEST/Annotations/Core not found" >&2; exit 1; }
echo "OK: annotations in $DEST/Annotations/Core"
```

- [ ] **Paso 8: `tools/setup.sh`**

```bash
#!/usr/bin/env bash
# Installs the development toolchain on macOS (Homebrew). Idempotent.
set -euo pipefail
cd "$(dirname "$0")/.."
brew install luajit luarocks lua-language-server luacheck stylua
luarocks --lua-version=5.1 --lua-dir="$(brew --prefix luajit)" --local install busted
tools/fetch_annotations.sh
case ":$PATH:" in
	*":$HOME/.luarocks/bin:"*) ;;
	*) echo "WARNING: add \$HOME/.luarocks/bin to your PATH (busted lives there)." ;;
esac
echo "OK: toolchain installed"
```

- [ ] **Paso 9: ejecutar setup**

```bash
mkdir -p data/raw && touch data/raw/.gitkeep
chmod +x tools/setup.sh tools/fetch_annotations.sh
tools/setup.sh
luajit -v && ~/.luarocks/bin/busted --version && luacheck --version && stylua --version && lua-language-server --version
```
Esperado: `OK: toolchain installed` y cinco versiones (LuaJIT 2.1, busted 2.3.x, Luacheck 1.2.x, stylua 2.6.x, 3.19.x).

- [ ] **Paso 10: commit**

```bash
git add .gitignore .editorconfig .luarc.json .luacheckrc .stylua.toml .styluaignore .busted tools/setup.sh tools/fetch_annotations.sh data/raw/.gitkeep
git commit -m "chore: Lua toolchain configuration"
```

---

### Tarea 2: Tests de aceptación (en rojo, y se congelan)

Se escriben **solo a partir de la spec §11**, sin ningún código de producto. Al terminar esta tarea todos deben FALLAR o dar error, porque todavía no existe nada que probar.

**Archivos:**
- Crear: `docs/api/forever-api.md`, `tests/support/wow_mock.lua`, `tests/support/client.lua`, `tests/acceptance/toc_spec.lua`, `tests/acceptance/addon_spec.lua`, `tools/__init__.py`, `tools/tests/__init__.py`, `tools/tests/acceptance/__init__.py`, `tools/tests/acceptance/support.py`, `tools/tests/acceptance/dump_guide.lua`, `tools/tests/acceptance/test_route_pipeline.py`, `tools/tests/acceptance/test_tooling.py`

**Interfaces:**
- Produce (contratos que las tareas siguientes deben cumplir, copiados de la spec §11):
  - CLI `python3 tools/validate_routes.py [DIR]`: exit 0/1; errores en stderr con el path relativo del archivo.
  - CLI `python3 tools/compile_guides.py [--routes DIR] [--out DIR] [--check]`.
  - Archivo generado `<id>.lua` que, cargado con `(addonName, ns)`, deja `ns.Guides[id]` igual al JSON; y `Guides.xml` con `<Script file="<id>.lua"/>`.
  - Mensajes de chat de la §11.2. Globals permitidas.
  - `tools/check.sh` y `.claude/hooks/post-edit.sh` (§11.3); variable `LR60_SKIP_TOOLING_TESTS=1`.

- [ ] **Paso 1: `docs/api/forever-api.md`** (base que deben citar los mocks)

```markdown
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
```

- [ ] **Paso 2: `tests/support/wow_mock.lua`**

```lua
-- Minimal WoW Forever API emulation for out-of-game tests.
-- Only APIs documented in docs/api/forever-api.md may be emulated here.
local WowMock = {}

local function readTocFields(tocPath)
	local fields = {}
	local handle = assert(io.open(tocPath, "r"), "missing TOC " .. tocPath)
	for line in handle:lines() do
		local key, value = line:match("^##%s*([%w%-_]+)%s*:%s*(.-)%s*$")
		if key then
			fields[key] = value
		end
	end
	handle:close()
	return fields
end

-- opts: { locale = "enUS", projectId = 18, addonName = "...", tocPath = "..." }
function WowMock.install(opts)
	local client = { chat = {}, frames = {} }

	local function capture(message)
		client.chat[#client.chat + 1] = message
	end

	_G.DEFAULT_CHAT_FRAME = {
		AddMessage = function(_, message)
			capture(message)
		end,
	}
	_G.print = function(...)
		local parts = {}
		for i = 1, select("#", ...) do
			parts[i] = tostring((select(i, ...)))
		end
		capture(table.concat(parts, " "))
	end

	_G.GetLocale = function()
		return opts.locale or "enUS"
	end

	_G.WOW_PROJECT_MAINLINE = 1
	_G.WOW_PROJECT_CAMELOT = 18
	_G.WOW_PROJECT_ID = opts.projectId or 18

	local tocFields = readTocFields(opts.tocPath)
	_G.C_AddOns = {
		GetAddOnMetadata = function(addonName, field)
			if addonName ~= opts.addonName then
				return nil
			end
			return tocFields[field]
		end,
	}

	_G.CreateFrame = function()
		local frame = { events = {}, scripts = {} }
		function frame:RegisterEvent(event)
			self.events[event] = true
		end
		function frame:UnregisterEvent(event)
			self.events[event] = nil
		end
		function frame:SetScript(name, handler)
			self.scripts[name] = handler
		end
		client.frames[#client.frames + 1] = frame
		return frame
	end

	_G.SlashCmdList = {}
	_G.SLASH_LARUTADEL601 = nil
	_G.LaRutaDel60DB = nil

	function client.fire(event, ...)
		for _, frame in ipairs(client.frames) do
			local handler = frame.scripts.OnEvent
			if frame.events[event] and handler then
				handler(frame, event, ...)
			end
		end
	end

	return client
end

return WowMock
```

- [ ] **Paso 3: `tests/support/client.lua`**

```lua
-- Emulates how the WoW client loads and drives the addon (see docs/api/forever-api.md).
local WowMock = require("support.wow_mock")

local Client = {}
Client.ADDON_NAME = "LaRutaDel60"
Client.ADDON_DIR = "addon/LaRutaDel60/"
Client.TOC = Client.ADDON_DIR .. "LaRutaDel60.toc"
Client.FOREVER_TOC = Client.ADDON_DIR .. "LaRutaDel60_Forever.toc"

local originalPrint = print

function Client.readFile(path)
	local handle = assert(io.open(path, "r"), "missing file " .. path)
	local content = handle:read("*a")
	handle:close()
	return content
end

function Client.tocField(field)
	return Client.readFile(Client.TOC):match("##%s*" .. field .. "%s*:%s*([^\r\n]-)%s*[\r\n]")
end

local function tocEntries(tocPath)
	local entries = {}
	for line in Client.readFile(tocPath):gmatch("[^\r\n]+") do
		local entry = line:match("^%s*(.-)%s*$")
		if entry ~= "" and entry:sub(1, 1) ~= "#" then
			entries[#entries + 1] = (entry:gsub("\\", "/"))
		end
	end
	return entries
end

-- Lua files in client load order, with .xml files expanded into their <Script file="..."/> entries.
function Client.addonFiles()
	local files = {}
	for _, entry in ipairs(tocEntries(Client.TOC)) do
		local path = Client.ADDON_DIR .. entry
		if entry:match("%.xml$") then
			local dir = path:match("^(.*/)")
			for script in Client.readFile(path):gmatch('<Script%s+file="([^"]+)"') do
				files[#files + 1] = dir .. (script:gsub("\\", "/"))
			end
		else
			files[#files + 1] = path
		end
	end
	return files
end

local function keysOf(t)
	local keys = {}
	for key in pairs(t) do
		keys[key] = true
	end
	return keys
end

local function newKeys(before, after)
	local added = {}
	for key in pairs(after) do
		if not before[key] then
			added[#added + 1] = tostring(key)
		end
	end
	table.sort(added)
	return added
end

-- opts: { locale = "enUS", projectId = 18, savedVariables = <table|nil> }
function Client.boot(opts)
	opts = opts or {}
	local client = WowMock.install({
		locale = opts.locale,
		projectId = opts.projectId,
		addonName = Client.ADDON_NAME,
		tocPath = Client.TOC,
	})
	local globalsBefore = keysOf(_G)
	local slashBefore = keysOf(SlashCmdList)

	local ns = {}
	for _, path in ipairs(Client.addonFiles()) do
		local chunk = assert(loadfile(path))
		chunk(Client.ADDON_NAME, ns)
	end

	-- The client restores saved variables after the addon files ran, before ADDON_LOADED.
	if opts.savedVariables ~= nil then
		_G.LaRutaDel60DB = opts.savedVariables
	end
	client.fire("ADDON_LOADED", Client.ADDON_NAME)

	function client.login()
		client.fire("PLAYER_LOGIN")
	end

	function client.slash(line)
		local command, rest = line:match("^(/%S+)%s*(.*)$")
		for key, handler in pairs(SlashCmdList) do
			local index = 1
			while _G["SLASH_" .. key .. index] do
				if _G["SLASH_" .. key .. index] == command then
					handler(rest)
					return
				end
				index = index + 1
			end
		end
		error("unknown slash command " .. tostring(command))
	end

	-- Chat lines as the player reads them (color codes removed).
	function client.messages()
		local lines = {}
		for i, message in ipairs(client.chat) do
			lines[i] = message:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
		end
		return lines
	end

	function client.newGlobals()
		return newKeys(globalsBefore, _G)
	end

	function client.newSlashCommands()
		return newKeys(slashBefore, SlashCmdList)
	end

	return client
end

function Client.shutdown()
	_G.print = originalPrint
end

return Client
```

- [ ] **Paso 4: `tests/acceptance/toc_spec.lua`**

```lua
local Client = require("support.client")

describe("TOC (acceptance)", function()
	it("targets the WoW Forever interface 16001", function()
		assert.are.equal("16001", Client.tocField("Interface"))
	end)

	it("declares LaRutaDel60DB as SavedVariables", function()
		assert.are.equal("LaRutaDel60DB", Client.tocField("SavedVariables"))
	end)

	it("keeps the _Forever TOC identical to the base TOC", function()
		assert.are.equal(Client.readFile(Client.TOC), Client.readFile(Client.FOREVER_TOC))
	end)

	it("only references files that exist", function()
		for _, path in ipairs(Client.addonFiles()) do
			local handle = io.open(path, "r")
			assert.is_not_nil(handle, "missing " .. path)
			handle:close()
		end
	end)
end)
```

- [ ] **Paso 5: `tests/acceptance/addon_spec.lua`**

```lua
local Client = require("support.client")

local PREFIX = "La Ruta del 60: "

local function routeCount()
	local pipe = assert(io.popen("find data/routes -name '*.json' | wc -l"))
	local count = tonumber(pipe:read("*a"):match("%d+"))
	pipe:close()
	return count
end

describe("Addon (acceptance)", function()
	after_each(function()
		Client.shutdown()
	end)

	it("greets once on login in WoW Forever (enUS)", function()
		local client = Client.boot()
		client.login()
		assert.are.same({ PREFIX .. "Loaded. Type /ruta for info." }, client.messages())
	end)

	it("warns first when the client is not WoW Forever", function()
		local client = Client.boot({ projectId = 1 })
		client.login()
		assert.are.same({
			PREFIX .. "Warning: this client is not WoW Forever; guides may be wrong.",
			PREFIX .. "Loaded. Type /ruta for info.",
		}, client.messages())
	end)

	it("reports the TOC version and the number of guides on /ruta", function()
		local client = Client.boot()
		client.login()
		client.slash("/ruta")
		local messages = client.messages()
		local expected =
			string.format("%sVersion %s - %d guide(s) loaded.", PREFIX, Client.tocField("Version"), routeCount())
		assert.are.equal(expected, messages[#messages])
	end)

	it("speaks Spanish on an esES client", function()
		local client = Client.boot({ locale = "esES" })
		client.login()
		client.slash("/ruta")
		assert.are.same({
			PREFIX .. "Cargado. Escribe /ruta para más info.",
			string.format("%sVersión %s - %d guía(s) cargada(s).", PREFIX, Client.tocField("Version"), routeCount()),
		}, client.messages())
	end)

	it("speaks Spanish on an esMX client", function()
		local client = Client.boot({ locale = "esMX", projectId = 1 })
		client.login()
		assert.are.same({
			PREFIX .. "Aviso: este cliente no es WoW Forever; las guías pueden fallar.",
			PREFIX .. "Cargado. Escribe /ruta para más info.",
		}, client.messages())
	end)

	it("creates saved variables on the first login", function()
		local client = Client.boot()
		client.login()
		assert.is_table(LaRutaDel60DB)
	end)

	it("keeps saved variables from a previous session", function()
		local client = Client.boot({ savedVariables = { keep = true } })
		client.login()
		assert.is_true(LaRutaDel60DB.keep)
	end)

	it("creates no globals besides the allowed ones", function()
		local client = Client.boot()
		client.login()
		client.slash("/ruta")
		assert.are.same({ "LaRutaDel60DB", "SLASH_LARUTADEL601" }, client.newGlobals())
		assert.are.same({ "LARUTADEL60" }, client.newSlashCommands())
	end)
end)
```

- [ ] **Paso 6: paquetes de Python**

```bash
mkdir -p tools/tests/acceptance
: > tools/__init__.py
: > tools/tests/__init__.py
: > tools/tests/acceptance/__init__.py
```

- [ ] **Paso 7: `tools/tests/acceptance/support.py`**

```python
"""Black-box helpers for acceptance tests: run CLIs, build fixture routes, copy the repo."""

from __future__ import annotations

import copy
import json
import os
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
VALIDATE = ROOT / "tools" / "validate_routes.py"
COMPILE = ROOT / "tools" / "compile_guides.py"
DUMP_GUIDE = Path(__file__).resolve().parent / "dump_guide.lua"
LUAJIT = shutil.which("luajit") or "luajit"
SKIP_TOOLING = os.environ.get("LR60_SKIP_TOOLING_TESTS") == "1"

VALID_ROUTE = {
    "id": "test-route",
    "name": {"enUS": "Test route", "esES": "Ruta de prueba"},
    "faction": "Alliance",
    "races": ["Human"],
    "minLevel": 1,
    "maxLevel": 2,
    "steps": [
        {"type": "note", "text": {"enUS": "Start", "esES": "Empieza"}},
        {
            "type": "accept",
            "questId": 783,
            "npcId": 823,
            "coords": {"mapId": 1429, "x": 48.2, "y": 42.9},
            "source": "https://www.wowhead.com/classic/quest=783",
        },
        {"type": "goto", "coords": {"mapId": 1429, "x": 48.9, "y": 41.6}},
        {"type": "turnin", "questId": 783, "npcId": 197},
    ],
}


def run(args: list, cwd: Path = ROOT, env: dict | None = None, stdin: str | None = None):
    full_env = dict(os.environ)
    full_env.update(env or {})
    return subprocess.run(
        [str(a) for a in args],
        cwd=cwd,
        env=full_env,
        input=stdin,
        capture_output=True,
        text=True,
        timeout=900,
    )


def valid_route(**overrides) -> dict:
    route = copy.deepcopy(VALID_ROUTE)
    route.update(overrides)
    return route


def write_route(directory: Path, route: dict, filename: str | None = None) -> Path:
    directory.mkdir(parents=True, exist_ok=True)
    path = directory / (filename or f"{route['id']}.json")
    path.write_text(json.dumps(route, ensure_ascii=False, indent=2), encoding="utf-8")
    return path


def dump_guide(guide_path: Path, guide_id: str):
    """Loads a compiled guide with LuaJIT like the client would and returns ns.Guides[id] as Python data."""
    result = run([LUAJIT, DUMP_GUIDE, guide_path, guide_id])
    if result.returncode != 0:
        raise AssertionError(f"dump_guide failed: {result.stderr}")
    return json.loads(result.stdout)


def normalize(value):
    """Lua cannot tell empty arrays from empty objects; treat both as []."""
    if isinstance(value, dict):
        return {k: normalize(v) for k, v in value.items()} if value else []
    if isinstance(value, list):
        return [normalize(v) for v in value]
    return value


def copy_repo(destination: Path) -> Path:
    """Copies the working tree (without .git) to destination/repo, sharing .vendor through a symlink."""
    repo = destination / "repo"
    shutil.copytree(
        ROOT,
        repo,
        ignore=shutil.ignore_patterns(".git", ".vendor", "__pycache__", "dist", "check.json"),
        symlinks=True,
    )
    if (ROOT / ".vendor").exists():
        (repo / ".vendor").symlink_to(ROOT / ".vendor", target_is_directory=True)
    return repo
```

- [ ] **Paso 8: `tools/tests/acceptance/dump_guide.lua`**

```lua
-- Usage: luajit dump_guide.lua <compiled-guide.lua> <guide-id>
-- Loads a compiled guide the way the WoW client would and prints ns.Guides[id] as JSON.
local path, id = arg[1], arg[2]
local ns = {}
assert(loadfile(path))("LaRutaDel60", ns)
local guide = assert(ns.Guides and ns.Guides[id], "guide not registered: " .. tostring(id))

local ESCAPES = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }

local function encodeString(s)
	local escaped = s:gsub('[%c"\\]', function(c)
		return ESCAPES[c] or string.format("\\u%04x", c:byte())
	end)
	return '"' .. escaped .. '"'
end

local function arrayLength(t)
	local count = 0
	for _ in pairs(t) do
		count = count + 1
	end
	for i = 1, count do
		if t[i] == nil then
			return nil
		end
	end
	return count
end

local encode
encode = function(value)
	local kind = type(value)
	if kind == "table" then
		local length = arrayLength(value)
		local parts = {}
		if length then
			for i = 1, length do
				parts[i] = encode(value[i])
			end
			return "[" .. table.concat(parts, ",") .. "]"
		end
		local keys = {}
		for key in pairs(value) do
			assert(type(key) == "string", "non-string key in guide table")
			keys[#keys + 1] = key
		end
		table.sort(keys)
		for i, key in ipairs(keys) do
			parts[i] = encodeString(key) .. ":" .. encode(value[key])
		end
		return "{" .. table.concat(parts, ",") .. "}"
	elseif kind == "string" then
		return encodeString(value)
	elseif kind == "number" then
		return string.format("%.17g", value)
	elseif kind == "boolean" then
		return tostring(value)
	end
	error("unsupported type in guide: " .. kind)
end

io.write(encode(guide))
```

- [ ] **Paso 9: `tools/tests/acceptance/test_route_pipeline.py`**

```python
"""Acceptance tests for the route pipeline CLIs (spec §11.1). Frozen: do not edit without user approval."""

import json
import tempfile
import unittest
from pathlib import Path

from tools.tests.acceptance.support import (
    COMPILE,
    ROOT,
    VALIDATE,
    dump_guide,
    normalize,
    run,
    valid_route,
    write_route,
)

INVALID_ROUTES = [
    ("unknown faction", {"faction": "Pirates"}),
    ("faction that is not a string", {"faction": 1}),
    ("level above 60", {"maxLevel": 61}),
    ("level below 1", {"minLevel": 0}),
    ("min level above max level", {"minLevel": 10, "maxLevel": 5}),
    ("name without enUS", {"name": {"esES": "Ruta"}}),
    ("missing name", {"name": None}),
    ("non kebab-case id", {"id": "Bad Id"}),
    ("empty steps", {"steps": []}),
    ("unknown step type", {"steps": [{"type": "dance"}]}),
    ("quest step without questId", {"steps": [{"type": "accept"}]}),
    ("non positive questId", {"steps": [{"type": "accept", "questId": 0}]}),
    ("turnin without previous accept", {"steps": [{"type": "turnin", "questId": 5}]}),
    ("complete without previous accept", {"steps": [{"type": "complete", "questId": 5}]}),
    ("goto without coords", {"steps": [{"type": "goto"}]}),
    ("coords out of range", {"steps": [{"type": "goto", "coords": {"mapId": 1429, "x": 150, "y": 20}}]}),
    ("coords without mapId", {"steps": [{"type": "goto", "coords": {"x": 10, "y": 20}}]}),
    ("note without text", {"steps": [{"type": "note"}]}),
    ("text without enUS", {"steps": [{"type": "note", "text": {"esES": "Hola"}}]}),
    ("source that is not a URL", {"steps": [{"type": "accept", "questId": 1, "source": "wowhead"}]}),
    ("non positive npcId", {"steps": [{"type": "accept", "questId": 1, "npcId": 0}]}),
]


class ValidateCliTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.routes = Path(self._tmp.name) / "routes"

    def tearDown(self):
        self._tmp.cleanup()

    def validate(self, routes_dir=None):
        return run(["python3", VALIDATE, routes_dir or self.routes])

    def test_accepts_a_valid_route(self):
        write_route(self.routes, valid_route())
        result = self.validate()
        self.assertEqual(0, result.returncode, result.stderr)

    def test_accepts_turnin_of_a_quest_carried_from_a_previous_route(self):
        write_route(self.routes, valid_route(carriedQuests=[5], steps=[{"type": "turnin", "questId": 5}]))
        result = self.validate()
        self.assertEqual(0, result.returncode, result.stderr)

    def test_accepts_the_repository_routes(self):
        result = run(["python3", VALIDATE])
        self.assertEqual(0, result.returncode, result.stderr)

    def test_rejects_every_rule_violation_naming_the_file(self):
        for label, overrides in INVALID_ROUTES:
            with self.subTest(label), tempfile.TemporaryDirectory() as tmp:
                routes = Path(tmp)
                route = valid_route(**overrides)
                if route.get("name") is None:
                    del route["name"]
                write_route(routes, route, filename="test-route.json")
                result = self.validate(routes)
                self.assertEqual(1, result.returncode, f"{label}: {result.stdout}{result.stderr}")
                self.assertIn("test-route.json", result.stderr, label)

    def test_rejects_a_file_name_that_does_not_match_the_id(self):
        write_route(self.routes, valid_route(), filename="other-name.json")
        result = self.validate()
        self.assertEqual(1, result.returncode)
        self.assertIn("other-name.json", result.stderr)

    def test_rejects_duplicate_ids_across_folders(self):
        write_route(self.routes / "alliance", valid_route())
        write_route(self.routes / "horde", valid_route())
        result = self.validate()
        self.assertEqual(1, result.returncode)
        self.assertIn("test-route.json", result.stderr)

    def test_rejects_next_pointing_to_a_missing_route(self):
        write_route(self.routes, valid_route(next="missing-route"))
        result = self.validate()
        self.assertEqual(1, result.returncode)
        self.assertIn("test-route.json", result.stderr)

    def test_accepts_next_pointing_to_an_existing_route(self):
        write_route(self.routes, valid_route(next="second-route"))
        write_route(self.routes, valid_route(id="second-route"))
        result = self.validate()
        self.assertEqual(0, result.returncode, result.stderr)

    def test_rejects_broken_json_naming_the_file(self):
        self.routes.mkdir(parents=True)
        (self.routes / "broken.json").write_text("{", encoding="utf-8")
        result = self.validate()
        self.assertEqual(1, result.returncode)
        self.assertIn("broken.json", result.stderr)


class CompileCliTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        base = Path(self._tmp.name)
        self.routes = base / "routes"
        self.out = base / "Guides"
        self.route = valid_route()
        write_route(self.routes / "alliance", self.route)

    def tearDown(self):
        self._tmp.cleanup()

    def compile(self, *extra, routes=None, out=None):
        return run(["python3", COMPILE, "--routes", routes or self.routes, "--out", out or self.out, *extra])

    def test_writes_one_guide_per_route_and_an_index(self):
        result = self.compile()
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertEqual({"test-route.lua", "Guides.xml"}, {p.name for p in self.out.iterdir()})
        self.assertIn('<Script file="test-route.lua"/>', (self.out / "Guides.xml").read_text(encoding="utf-8"))

    def test_compiled_guide_holds_exactly_the_route_data(self):
        self.assertEqual(0, self.compile().returncode)
        loaded = dump_guide(self.out / "test-route.lua", "test-route")
        self.assertEqual(normalize(self.route), normalize(loaded))

    def test_repository_routes_survive_the_round_trip(self):
        result = self.compile(routes=ROOT / "data" / "routes")
        self.assertEqual(0, result.returncode, result.stderr)
        sources = sorted((ROOT / "data" / "routes").rglob("*.json"))
        self.assertTrue(sources, "the repository must contain at least one route")
        for source in sources:
            route = json.loads(source.read_text(encoding="utf-8"))
            with self.subTest(route["id"]):
                loaded = dump_guide(self.out / f"{route['id']}.lua", route["id"])
                self.assertEqual(normalize(route), normalize(loaded))

    def test_writes_nothing_when_a_route_is_invalid(self):
        write_route(self.routes / "alliance", {"id": "broken-route"})
        result = self.compile()
        self.assertEqual(1, result.returncode)
        self.assertFalse(self.out.exists() and any(self.out.iterdir()))

    def test_check_detects_outdated_guides(self):
        self.assertEqual(1, self.compile("--check").returncode)
        self.assertEqual(0, self.compile().returncode)
        self.assertEqual(0, self.compile("--check").returncode)
        write_route(self.routes / "alliance", valid_route(maxLevel=3))
        self.assertEqual(1, self.compile("--check").returncode)

    def test_check_does_not_write(self):
        result = self.compile("--check")
        self.assertEqual(1, result.returncode, result.stderr)
        self.assertFalse(self.out.exists() and any(self.out.iterdir()))

    def test_removes_guides_of_deleted_routes(self):
        second = write_route(self.routes / "alliance", valid_route(id="second-route"))
        self.assertEqual(0, self.compile().returncode)
        second.unlink()
        self.assertEqual(0, self.compile().returncode)
        self.assertFalse((self.out / "second-route.lua").exists())
        self.assertNotIn("second-route", (self.out / "Guides.xml").read_text(encoding="utf-8"))

    def test_repository_guides_are_up_to_date(self):
        result = run(["python3", COMPILE, "--check"])
        self.assertEqual(0, result.returncode, result.stderr)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Paso 10: `tools/tests/acceptance/test_tooling.py`**

```python
"""Acceptance tests for tools/check.sh and the Claude Code post-edit hook (spec §11.3).
Frozen: do not edit without user approval."""

import json
import tempfile
import unittest
from pathlib import Path

from tools.tests.acceptance.support import SKIP_TOOLING, copy_repo, run, valid_route, write_route

BAD_LUA = "local unused_variable = 1\n"


@unittest.skipIf(SKIP_TOOLING, "running inside tools/check.sh of a repository copy")
class CheckScriptTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.repo = copy_repo(Path(self._tmp.name))

    def tearDown(self):
        self._tmp.cleanup()

    def check(self):
        return run([self.repo / "tools" / "check.sh"], cwd=self.repo, env={"LR60_SKIP_TOOLING_TESTS": "1"})

    def test_passes_on_a_clean_repository(self):
        result = self.check()
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)

    def test_fails_on_a_lint_error_in_the_addon(self):
        with open(self.repo / "addon" / "LaRutaDel60" / "Core" / "Init.lua", "a", encoding="utf-8") as f:
            f.write(BAD_LUA)
        self.assertNotEqual(0, self.check().returncode)

    def test_fails_on_an_invalid_route(self):
        write_route(self.repo / "data" / "routes" / "alliance", {"id": "broken-route"})
        self.assertNotEqual(0, self.check().returncode)

    def test_fails_on_outdated_guides(self):
        example = next((self.repo / "data" / "routes").rglob("*.json"))
        route = json.loads(example.read_text(encoding="utf-8"))
        route["maxLevel"] = route["maxLevel"] + 1 if route["maxLevel"] < 60 else route["maxLevel"] - 1
        example.write_text(json.dumps(route), encoding="utf-8")
        self.assertNotEqual(0, self.check().returncode)


@unittest.skipIf(SKIP_TOOLING, "running inside tools/check.sh of a repository copy")
class PostEditHookTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.repo = copy_repo(Path(self._tmp.name))
        self.hook = self.repo / ".claude" / "hooks" / "post-edit.sh"

    def tearDown(self):
        self._tmp.cleanup()

    def run_hook(self, path: Path):
        payload = json.dumps({"tool_name": "Edit", "tool_input": {"file_path": str(path)}})
        return run([self.hook], cwd=self.repo, env={"CLAUDE_PROJECT_DIR": str(self.repo)}, stdin=payload)

    def test_blocks_a_lua_file_with_lint_errors(self):
        bad = self.repo / "addon" / "LaRutaDel60" / "Core" / "Bad.lua"
        bad.write_text(BAD_LUA, encoding="utf-8")
        result = self.run_hook(bad)
        self.assertEqual(2, result.returncode)
        self.assertTrue(result.stderr.strip())

    def test_accepts_a_clean_lua_file(self):
        result = self.run_hook(self.repo / "addon" / "LaRutaDel60" / "Core" / "Init.lua")
        self.assertEqual(0, result.returncode, result.stderr)

    def test_blocks_an_edit_that_leaves_invalid_routes(self):
        broken = write_route(self.repo / "data" / "routes" / "alliance", {"id": "broken-route"})
        result = self.run_hook(broken)
        self.assertEqual(2, result.returncode)
        self.assertTrue(result.stderr.strip())

    def test_accepts_a_valid_route_edit(self):
        path = write_route(self.repo / "data" / "routes" / "alliance", valid_route(id="extra-route"))
        result = self.run_hook(path)
        self.assertEqual(0, result.returncode, result.stderr)

    def test_ignores_other_files(self):
        result = self.run_hook(self.repo / "docs" / "api" / "forever-api.md")
        self.assertEqual(0, result.returncode, result.stderr)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Paso 11: lint de los tests**

Run: `stylua tests tools/tests && luacheck tests tools/tests/acceptance/dump_guide.lua`
Esperado: `Total: 0 warnings / 0 errors`.

- [ ] **Paso 12: confirmar que TODO está en rojo**

```bash
~/.luarocks/bin/busted; echo "busted exit=$?"
python3 -m unittest discover -s tools/tests -t . 2>&1 | tail -3
```
Esperado: busted termina con errores (`missing file addon/LaRutaDel60/LaRutaDel60.toc`) y exit ≠ 0. unittest termina con `FAILED (failures=…, errors=…)` y **ningún test en verde**: las CLIs no existen (python devuelve exit 2, no el 1 que esperan los tests) y `check.sh`/el hook no existen (error al ejecutarlos). Si algún test pasa, el test está mal escrito: corregirlo ahora, antes de congelarlo.

- [ ] **Paso 13: commit (en rojo)**

```bash
git add docs/api tests tools/__init__.py tools/tests
git commit -m "test: black-box acceptance tests for the technical base (red)"
```

---

### Tarea 3: Pipeline de rutas (validador + compilador + ruta de ejemplo)

**Objetivo de la tarea:** poner en verde `tools/tests/acceptance/test_route_pipeline.py` sin modificarlo.

**Archivos:**
- Crear: `tools/validate_routes.py`, `tools/compile_guides.py`, `data/routes/alliance/alliance-northshire-example.json`
- Generados: `addon/LaRutaDel60/Guides/alliance-northshire-example.lua`, `addon/LaRutaDel60/Guides/Guides.xml`

**Interfaces:**
- Consume: los contratos de la Tarea 2.
- Produce: `validate_routes.validate_all(routes_dir) -> list[str]`, `validate_routes.ROOT`, `ROUTES_DIR`; las guías generadas que carga el addon (Tarea 4).

- [ ] **Paso 1: ver en rojo**

Run: `python3 -m unittest tools.tests.acceptance.test_route_pipeline 2>&1 | tail -1`
Esperado: `FAILED (...)`.

- [ ] **Paso 2: `tools/validate_routes.py`**

```python
"""Validates leveling routes under data/routes against the La Ruta del 60 guide format.

Usage: python3 tools/validate_routes.py [ROUTES_DIR]
Exit code 0 when every route is valid, 1 otherwise (one error per line on stderr).
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


def _is_number(value) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def _check_localized(value, where: str, field: str, errors: list[str], required: bool) -> None:
    if value is None:
        if required:
            errors.append(f"{where}: missing '{field}'")
        return
    if not isinstance(value, dict) or "enUS" not in value:
        errors.append(f"{where}: '{field}' must be an object with at least 'enUS'")
        return
    for locale, text in value.items():
        if locale not in LOCALES:
            errors.append(f"{where}: unknown locale '{locale}' in '{field}'")
        elif not isinstance(text, str) or not text.strip():
            errors.append(f"{where}: '{field}.{locale}' is empty")


def _check_coords(coords, where: str, errors: list[str]) -> None:
    if not isinstance(coords, dict):
        errors.append(f"{where}: 'coords' must be an object")
        return
    map_id = coords.get("mapId")
    if not _is_int(map_id) or map_id <= 0:
        errors.append(f"{where}: 'coords.mapId' must be an integer > 0")
    for axis in ("x", "y"):
        value = coords.get(axis)
        if not _is_number(value) or not 0 <= value <= 100:
            errors.append(f"{where}: 'coords.{axis}' must be between 0 and 100")


def _check_level(route: dict, field: str, errors: list[str]) -> bool:
    value = route.get(field)
    if not _is_int(value) or not MIN_LEVEL <= value <= MAX_LEVEL:
        errors.append(f"'{field}' must be an integer between {MIN_LEVEL} and {MAX_LEVEL}")
        return False
    return True


def _check_step(step, index: int, accepted: set[int], errors: list[str]) -> None:
    where = f"steps[{index}]"
    if not isinstance(step, dict):
        errors.append(f"{where}: a step must be an object")
        return
    step_type = step.get("type")
    if step_type not in STEP_TYPES:
        errors.append(f"{where}: unknown step type '{step_type}'")
        return

    if step_type in QUEST_STEPS:
        quest_id = step.get("questId")
        if not _is_int(quest_id) or quest_id <= 0:
            errors.append(f"{where}: 'questId' must be an integer > 0")
        elif step_type == "accept":
            accepted.add(quest_id)
        elif quest_id not in accepted:
            errors.append(
                f"{where}: questId {quest_id} was not accepted earlier in the route "
                "(add it to 'carriedQuests' if it comes from a previous route)"
            )

    if step_type == "goto" and "coords" not in step:
        errors.append(f"{where}: a 'goto' step needs 'coords'")
    if "coords" in step:
        _check_coords(step["coords"], where, errors)

    _check_localized(step.get("text"), where, "text", errors, required=step_type == "note")

    if "npcId" in step and (not _is_int(step["npcId"]) or step["npcId"] <= 0):
        errors.append(f"{where}: 'npcId' must be an integer > 0")
    source = step.get("source")
    if source is not None and (not isinstance(source, str) or not source.startswith(("http://", "https://"))):
        errors.append(f"{where}: 'source' must be an http(s) URL")


def validate_route(route) -> list[str]:
    """Returns the errors of a single route (empty when valid)."""
    if not isinstance(route, dict):
        return ["a route must be a JSON object"]
    errors: list[str] = []

    route_id = route.get("id")
    if not isinstance(route_id, str) or not ID_RE.match(route_id):
        errors.append("'id' must be lowercase kebab-case")
    _check_localized(route.get("name"), "route", "name", errors, required=True)
    if not isinstance(route.get("faction"), str) or route["faction"] not in FACTIONS:
        errors.append(f"'faction' must be one of {sorted(FACTIONS)}")

    min_ok = _check_level(route, "minLevel", errors)
    max_ok = _check_level(route, "maxLevel", errors)
    if min_ok and max_ok and route["minLevel"] > route["maxLevel"]:
        errors.append("'minLevel' cannot be greater than 'maxLevel'")

    for field in ("races", "classes"):
        value = route.get(field)
        if value is not None and (not isinstance(value, list) or not all(isinstance(v, str) for v in value)):
            errors.append(f"'{field}' must be a list of strings")

    next_id = route.get("next")
    if next_id is not None and not isinstance(next_id, str):
        errors.append("'next' must be the id (string) of another route")

    carried = route.get("carriedQuests", [])
    if not isinstance(carried, list) or not all(_is_int(q) and q > 0 for q in carried):
        errors.append("'carriedQuests' must be a list of integers > 0")
        carried = []

    steps = route.get("steps")
    if not isinstance(steps, list) or not steps:
        errors.append("'steps' must be a non-empty list")
        return errors
    accepted = set(carried)
    for index, step in enumerate(steps, start=1):
        _check_step(step, index, accepted, errors)
    return errors


def validate_all(routes_dir: Path = ROUTES_DIR) -> list[str]:
    """Validates every *.json under routes_dir, including cross-file rules. Errors are prefixed by the file."""
    routes_dir = Path(routes_dir)
    errors: list[str] = []
    ids: dict[str, str] = {}
    routes: list[tuple[str, dict]] = []

    for path in sorted(routes_dir.rglob("*.json")):
        label = path.relative_to(routes_dir).as_posix()
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            errors.append(f"{label}: invalid JSON: {exc}")
            continue
        errors.extend(f"{label}: {err}" for err in validate_route(data))
        if isinstance(data, dict) and isinstance(data.get("id"), str):
            route_id = data["id"]
            if path.stem != route_id:
                errors.append(f"{label}: file name must be '{route_id}.json'")
            if route_id in ids:
                errors.append(f"{label}: duplicated id '{route_id}' (also in {ids[route_id]})")
            ids[route_id] = label
            routes.append((label, data))

    for label, data in routes:
        next_id = data.get("next")
        if isinstance(next_id, str) and next_id not in ids:
            errors.append(f"{label}: 'next' points to a missing route '{next_id}'")
    return errors


def main(argv: list[str] | None = None) -> int:
    argv = sys.argv[1:] if argv is None else argv
    routes_dir = Path(argv[0]) if argv else ROUTES_DIR
    errors = validate_all(routes_dir)
    for err in errors:
        print(f"ERROR {err}", file=sys.stderr)
    if errors:
        return 1
    print(f"OK: routes are valid in {routes_dir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Paso 3: `tools/compile_guides.py`**

```python
"""Compiles data/routes/**/*.json into addon/LaRutaDel60/Guides/*.lua plus Guides.xml.

Usage:
  python3 tools/compile_guides.py [--routes DIR] [--out DIR]           validate and generate
  python3 tools/compile_guides.py [--routes DIR] [--out DIR] --check   fail if the output is outdated
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
HEADER = "-- GENERATED by tools/compile_guides.py from {source}. DO NOT EDIT.\n"
IDENT_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
LUA_KEYWORDS = {
    "and", "break", "do", "else", "elseif", "end", "false", "for", "function", "if", "in",
    "local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while",
}


def lua_string(text: str) -> str:
    escaped = text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\r", "\\r")
    return f'"{escaped}"'


def _lua_key(key: str) -> str:
    if IDENT_RE.match(key) and key not in LUA_KEYWORDS:
        return key
    return f"[{lua_string(key)}]"


def to_lua(value, depth: int = 0) -> str:
    """Serializes JSON data into a deterministic Lua expression (sorted keys, tab indentation)."""
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
        raise TypeError(f"unsupported type: {type(value).__name__}")
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
    lines.append("\t<!-- GENERATED by tools/compile_guides.py. DO NOT EDIT. -->")
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
    parser.add_argument("--check", action="store_true", help="do not write; fail when the output is outdated")
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
            print("ERROR: Guides/ is outdated; run python3 tools/compile_guides.py", file=sys.stderr)
            return 1
        print("OK: Guides/ is up to date")
        return 0

    args.out.mkdir(parents=True, exist_ok=True)
    for stale in existing.keys() - outputs.keys():
        (args.out / stale).unlink()
    for name, content in outputs.items():
        (args.out / name).write_text(content, encoding="utf-8", newline="\n")
    print(f"OK: compiled {len(outputs) - 1} guide(s) into {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Paso 4: ruta de ejemplo**

`data/routes/alliance/alliance-northshire-example.json` (datos de Classic, solo para probar el pipeline; **no verificados en Forever**):
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

- [ ] **Paso 5: generar guías y poner en verde**

```bash
python3 tools/compile_guides.py
python3 -m unittest tools.tests.acceptance.test_route_pipeline -v 2>&1 | tail -3
```
Esperado: `OK: compiled 1 guide(s)…` y `OK` en los tests del pipeline. Si alguno falla, arreglar el código de `tools/` (nunca el test).

- [ ] **Paso 6: commit**

```bash
git add tools/validate_routes.py tools/compile_guides.py data/routes addon/LaRutaDel60/Guides
git commit -m "feat: route validator and JSON-to-Lua guide compiler"
```

---

### Tarea 4: Addon "hola mundo"

**Objetivo de la tarea:** poner en verde `tests/acceptance/*_spec.lua` sin modificarlos.

**Archivos:**
- Crear: `addon/LaRutaDel60/LaRutaDel60.toc`, `addon/LaRutaDel60/LaRutaDel60_Forever.toc`, `addon/LaRutaDel60/Locales/Locales.lua`, `addon/LaRutaDel60/Locales/enUS.lua`, `addon/LaRutaDel60/Locales/esES.lua`, `addon/LaRutaDel60/Core/Init.lua`

**Interfaces:**
- Consume: `Guides/Guides.xml` y `ns.Guides[id]` (Tarea 3).
- Produce: `ns.L` (tabla de textos con fallback a la clave), `ns.Print(msg)`, `ns.Guides`. Claves de locale: `ADDON_TITLE`, `LOADED`, `NOT_FOREVER`, `VERSION_INFO`.

- [ ] **Paso 1: ver en rojo**

Run: `~/.luarocks/bin/busted 2>&1 | tail -2`
Esperado: errores por el TOC inexistente.

- [ ] **Paso 2: TOC**

`addon/LaRutaDel60/LaRutaDel60.toc`:
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

- [ ] **Paso 3: locales**

`addon/LaRutaDel60/Locales/Locales.lua`:
```lua
local _, ns = ...

-- Localized strings. A missing translation returns its own key, so the UI never shows nil.
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

- [ ] **Paso 4: `addon/LaRutaDel60/Core/Init.lua`**

```lua
local ADDON_NAME, ns = ...
local L = ns.L

ns.VERSION = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "dev"
ns.Guides = ns.Guides or {}

local function isForever()
	return WOW_PROJECT_CAMELOT ~= nil and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT
end

local function guideCount()
	local count = 0
	for _ in pairs(ns.Guides) do
		count = count + 1
	end
	return count
end

function ns.Print(message)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99" .. L.ADDON_TITLE .. "|r: " .. message)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGIN" then
		LaRutaDel60DB = LaRutaDel60DB or {}
		if not isForever() then
			ns.Print(L.NOT_FOREVER)
		end
		ns.Print(L.LOADED)
	end
end)

SLASH_LARUTADEL601 = "/ruta"
SlashCmdList.LARUTADEL60 = function()
	ns.Print(string.format(L.VERSION_INFO, ns.VERSION, guideCount()))
end
```

- [ ] **Paso 5: poner en verde**

Run: `stylua addon && luacheck addon && ~/.luarocks/bin/busted`
Esperado: luacheck `0 warnings / 0 errors`; busted `12 successes / 0 failures / 0 errors`. Si falla un spec, arreglar el addon (nunca el spec).

- [ ] **Paso 6: commit**

```bash
git add addon/LaRutaDel60
git commit -m "feat: hello-world addon with /ruta, enUS/esES and Forever detection"
```

---

### Tarea 5: Verificación completa (`tools/check.sh`)

**Objetivo de la tarea:** poner en verde `CheckScriptTest` de `test_tooling.py`.

**Archivos:**
- Crear: `tools/luals_check.sh`, `tools/check.sh`

- [ ] **Paso 1: `tools/luals_check.sh`**

```bash
#!/usr/bin/env bash
# lua-language-server diagnostics (with WoW API annotations) for the addon.
set -euo pipefail
cd "$(dirname "$0")/.."
test -d .vendor/vscode-wow-api/Annotations/Core || tools/fetch_annotations.sh
LOGDIR="$(mktemp -d)"
trap 'rm -rf "$LOGDIR"' EXIT
# Check the repo root so relative paths in .luarc.json resolve; ignoreDir skips tests/, tools/ and .vendor/.
lua-language-server --check "$PWD" --configpath "$PWD/.luarc.json" --checklevel=Warning --logpath "$LOGDIR"
```

- [ ] **Paso 2: comprobar que LuaLS detecta errores reales**

```bash
chmod +x tools/luals_check.sh
printf 'local _, ns = ...\nns.x = UnknownWowThing()\n' > addon/LaRutaDel60/Core/Broken.lua
tools/luals_check.sh; echo "exit=$?"
rm addon/LaRutaDel60/Core/Broken.lua
tools/luals_check.sh; echo "exit=$?"
```
Esperado: la primera vez `undefined-global` y `exit=1`; la segunda, `no problems found` y `exit=0`. Si la segunda marca avisos en el addon, corregir el código (no desactivar diagnósticos).

- [ ] **Paso 3: `tools/check.sh`**

```bash
#!/usr/bin/env bash
# Full project verification. Must pass before every commit.
set -euo pipefail
cd "$(dirname "$0")/.."

BUSTED="${BUSTED:-}"
if [ -z "$BUSTED" ]; then
	if command -v busted > /dev/null; then BUSTED="busted"; else BUSTED="$HOME/.luarocks/bin/busted"; fi
fi

step() { printf '\n== %s\n' "$1"; }

step "stylua"; stylua --check addon tests tools/tests
step "luacheck"; luacheck --no-color addon tests tools/tests/acceptance/dump_guide.lua
step "validate routes"; python3 tools/validate_routes.py
step "compiled guides up to date"; python3 tools/compile_guides.py --check
step "python tests"; python3 -m unittest discover -s tools/tests -t . -q
step "lua tests (busted)"; "$BUSTED"
step "LuaLS"; tools/luals_check.sh

printf '\nOK: all green\n'
```

- [ ] **Paso 4: poner en verde**

```bash
chmod +x tools/check.sh
python3 -m unittest tools.tests.acceptance.test_tooling.CheckScriptTest -v 2>&1 | tail -3
```
Esperado: `OK` (4 tests).

- [ ] **Paso 5: commit**

```bash
git add tools/check.sh tools/luals_check.sh
git commit -m "chore: full verification script"
```

---

### Tarea 6: Hook post-edición y permisos de Claude Code

**Objetivo de la tarea:** poner en verde `PostEditHookTest` y, con ello, el `tools/check.sh` completo.

**Archivos:**
- Crear: `.claude/hooks/post-edit.sh`, `.claude/settings.json`

- [ ] **Paso 1: `.claude/hooks/post-edit.sh`**

```bash
#!/usr/bin/env bash
# PostToolUse hook: formats and checks the edited file. Exit 2 sends stderr back to Claude as a blocking error.
set -uo pipefail
cd "${CLAUDE_PROJECT_DIR:-$(dirname "$0")/../..}"

file="$(python3 -c 'import json, sys; print(json.load(sys.stdin).get("tool_input", {}).get("file_path", ""))')"
[ -n "$file" ] && [ -f "$file" ] || exit 0

case "$file" in
	*/.vendor/*|*/addon/LaRutaDel60/Guides/*) exit 0 ;;
	*.lua)
		stylua "$file" 2> /dev/null
		if ! out="$(luacheck --no-color "$file" 2>&1)"; then
			printf 'luacheck found problems in %s:\n%s\n' "$file" "$out" >&2
			exit 2
		fi
		;;
	*/data/routes/*.json)
		if ! out="$(python3 tools/validate_routes.py 2>&1)"; then
			printf 'Routes are invalid after editing %s:\n%s\n' "$file" "$out" >&2
			exit 2
		fi
		;;
esac
exit 0
```

- [ ] **Paso 2: `.claude/settings.json`**

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

- [ ] **Paso 3: poner en verde todo**

```bash
chmod +x .claude/hooks/post-edit.sh
python3 -m json.tool .claude/settings.json > /dev/null && echo JSON_OK
python3 -m unittest tools.tests.acceptance.test_tooling -v 2>&1 | tail -3
tools/check.sh
```
Esperado: `JSON_OK`, `OK` (9 tests) y `OK: all green`.

- [ ] **Paso 4: commit**

```bash
git add .claude/settings.json .claude/hooks/post-edit.sh
git commit -m "chore: Claude Code post-edit hook and permissions"
```

---

### Tarea 7: Plugin LSP local para Claude Code

**Archivos:**
- Crear: `.claude-plugin/marketplace.json`, `claude-plugins/wow-lua-lsp/.claude-plugin/plugin.json`
- Modificar: `.claude/settings.json` (lo modifica el CLI al instalar con `--scope project`)

- [ ] **Paso 1: `.claude-plugin/marketplace.json`**

```json
{
  "name": "larutadel60",
  "owner": { "name": "Ricardo Olivera" },
  "description": "Local plugins for the La Ruta del 60 project",
  "plugins": [
    {
      "name": "wow-lua-lsp",
      "source": "./claude-plugins/wow-lua-lsp",
      "description": "lua-language-server with WoW API annotations"
    }
  ]
}
```

- [ ] **Paso 2: `claude-plugins/wow-lua-lsp/.claude-plugin/plugin.json`**

```json
{
  "name": "wow-lua-lsp",
  "version": "0.1.0",
  "description": "lua-language-server for the La Ruta del 60 addon (reads the project's .luarc.json)",
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

- [ ] **Paso 3: validar**

Run: `claude plugin validate ./claude-plugins/wow-lua-lsp && claude plugin validate .`
Esperado: `Validation passed` en ambos (si hay warnings, que no sean de `lspServers`).

- [ ] **Paso 4: instalar a nivel de proyecto**

```bash
claude plugin marketplace add ./
claude plugin install wow-lua-lsp@larutadel60 --scope project
git diff .claude/settings.json
claude plugin list
```
Esperado: `.claude/settings.json` gana `enabledPlugins` con `"wow-lua-lsp@larutadel60": true`, y `claude plugin list` lo muestra sin errores. Si el CLI no añade `extraKnownMarketplaces`, añadirlo a mano:
```json
"extraKnownMarketplaces": {
  "larutadel60": { "source": { "source": "directory", "path": "./" } }
}
```

- [ ] **Paso 5: verificación manual (se apunta para el checklist final)**

En una sesión nueva de Claude Code: «usa la herramienta LSP para hacer hover sobre `C_AddOns` en `addon/LaRutaDel60/Core/Init.lua`». Esperado: devuelve la documentación de la anotación de Ketho. Si falla, el respaldo es `tools/luals_check.sh` dentro de `check.sh`; anotarlo en `docs/api/forever-api.md`, sección "Tooling".

- [ ] **Paso 6: `tools/check.sh` en verde y commit**

```bash
tools/check.sh
git add .claude-plugin claude-plugins .claude/settings.json
git commit -m "chore: local LSP plugin (lua-language-server) for Claude Code"
```

---

### Tarea 8: Subagentes

**Archivos:** crear `.claude/agents/{wow-api-expert,addon-engineer,route-researcher,route-optimizer,route-validator,lua-reviewer}.md`

- [ ] **Paso 1: `wow-api-expert.md`**

```markdown
---
name: wow-api-expert
description: Verifica si una función, evento, widget o constante de la API de WoW existe y cómo se comporta en WoW Forever 1.60.1 (Interface 16001). Úsalo ANTES de usar cualquier API de WoW que no esté ya en el código o en docs/api/forever-api.md. Solo lectura.
tools: Read, Grep, Glob, WebFetch, WebSearch
---

Eres el experto en la API de addons de WoW Forever (cliente 1.60.1, Interface 16001, Lua 5.1).

Contexto fijo:
- Forever usa la arquitectura de UI de retail 12.x (C_QuestLog, C_Map, C_Item, C_Spell...), NO la de Classic Era 1.15.
- Las restricciones de "secrets" de Midnight están activas. Se eliminaron unos 1.041 globales de FrameXML de retail.
- Detección: WOW_PROJECT_ID == WOW_PROJECT_CAMELOT (18).

Proceso para cada API:
1. Busca en `docs/api/forever-api.md` (conocimiento ya verificado).
2. `Grep` en `.vendor/vscode-wow-api/Annotations/Core` para sacar firma, parámetros y retornos.
3. Si hay dudas sobre Forever, consulta warcraft.wiki.gg (incluida "Patch 1.60.1/API changes").
4. Responde con: existe sí/no/incierto, firma exacta, eventos relacionados, restricciones (protegida, combat lockdown, secret), alternativa si no existe y URLs consultadas.

Si confirmas algo nuevo, propón (sin escribirlo) la línea para `docs/api/forever-api.md` y, si es una global, para `read_globals` de `.luacheckrc` y para `tests/support/wow_mock.lua`.
Nunca inventes una API: "incierto" es una respuesta válida.
```

- [ ] **Paso 2: `addon-engineer.md`**

```markdown
---
name: addon-engineer
description: Implementa funcionalidad del addon (motor de guía, flecha, auto-quest, UI, módulos) en addon/LaRutaDel60 haciendo pasar tests de aceptación ya escritos. Úsalo para cualquier cambio de código Lua del addon.
tools: Read, Edit, Write, Grep, Glob, Bash
---

Implementas código del addon La Ruta del 60 para WoW Forever (Interface 16001, Lua 5.1).

Reglas no negociables (ver CLAUDE.md):
- Código 100% en inglés (identificadores, comentarios, strings). Tus explicaciones al usuario, en castellano.
- Los tests de aceptación (`tests/acceptance/`, `tests/support/`, `tools/tests/acceptance/`) están congelados. Tu trabajo es ponerlos en verde sin tocarlos. Si un test parece incorrecto, PARA y explícalo; no lo cambies.
- Si la funcionalidad no tiene tests de aceptación, pídelos antes de escribir código (deben derivarse de la spec, no de tu implementación).
- Sin globals nuevas: todo en `ns` (`local ADDON_NAME, ns = ...`). Permitidas: LaRutaDel60DB, SLASH_LARUTADEL601, SlashCmdList.LARUTADEL60.
- Cada API de WoW nueva: verifícala (skill `wow-forever-api` o agente `wow-api-expert`) y añádela a `.luacheckrc` y a `docs/api/forever-api.md`.
- Un módulo por archivo, en AMBOS TOC (idénticos). Skill `new-module`.
- Textos visibles siempre vía `ns.L`, con clave en `Locales/enUS.lua` y en `Locales/esES.lua`.
- Nunca edites `addon/LaRutaDel60/Guides/` (es generado).
- Rendimiento: nada pesado en OnUpdate sin throttle; usa eventos.
- No copies código de RestedXP ni de otros addons.

Termina siempre ejecutando `tools/check.sh` y reporta su salida final.
```

- [ ] **Paso 3: `route-researcher.md`**

```markdown
---
name: route-researcher
description: Investiga en bases de datos web (Wowhead y similares con datos de WoW Forever) quests, NPCs, coordenadas, niveles y prerrequisitos de una zona o tramo, y los guarda como JSON crudo en data/raw/. Primer paso de la skill add-route-segment.
tools: Read, Write, Grep, Glob, WebFetch, WebSearch
---

Recopilas datos crudos para rutas de leveo de WoW Forever. NO creas rutas, solo datos.

Salida: `data/raw/<zona-kebab>.json` (claves en inglés):
{
  "zone": "Elwynn Forest", "mapId": 1429, "faction": "Alliance",
  "retrievedAt": "YYYY-MM-DD",
  "quests": [
    { "questId": 783, "name": "A Threat Within", "level": 1, "minLevel": 1,
      "faction": "Alliance", "prereqs": [], "followUps": [7], "forever": true,
      "start": { "npcId": 823, "npc": "Sergeant Willem", "mapId": 1429, "x": 48.2, "y": 42.9 },
      "end":   { "npcId": 197, "npc": "Marshal McBride", "mapId": 1429, "x": 48.9, "y": 41.6 },
      "objectives": ["..."], "xp": 40,
      "source": "https://..." }
  ],
  "flightPaths": [], "innkeepers": [], "notes": []
}

Reglas:
- Prioriza fuentes con datos de WoW Forever 1.60.1. Forever tiene unas 1.000 quests nuevas y la XP de mazmorras va por quests, así que los datos de Classic Era pueden estar mal. Pon `"forever": false` en cada quest cuyo dato solo encuentres para Classic Era.
- Cada quest DEBE tener `source` (URL). No inventes nada: si falta un dato, omítelo y anótalo en `notes`.
- Coordenadas en porcentaje 0-100 del mapa `mapId` (uiMapID).
- Si el archivo de la zona ya existe, fusiona sin borrar datos verificados.
```

- [ ] **Paso 4: `route-optimizer.md`**

```markdown
---
name: route-optimizer
description: Construye u optimiza una ruta de leveo (data/routes/<faccion>/<id>.json) a partir de los datos crudos de data/raw/, minimizando el tiempo hasta el nivel objetivo. Úsalo tras route-researcher.
tools: Read, Write, Edit, Grep, Glob, Bash
---

Diseñas las rutas de leveo más rápidas posibles para WoW Forever, en el formato de la skill `guide-format`.

Criterios, en orden:
1. XP por minuto: agrupa quests por área, acepta todo lo cercano antes de salir y entrega en lote.
2. Menos desplazamiento: no vuelvas sobre tus pasos; usa `hearth` y `fly` cuando ahorren tiempo; indica con un `note` dónde fijar la piedra de hogar.
3. El jugador nunca debe quedarse sin nivel: estima la XP acumulada con el `xp` de data/raw y respeta minLevel.
4. Entrenamiento de clase (`train`) en los niveles pares cuando pases cerca de un entrenador.
5. Variantes por raza o clase solo cuando cambia la zona de inicio o hay quests de clase.

Reglas:
- Solo usa quests de data/raw que tengan `source`, y copia `source` al paso.
- Las quests aceptadas en rutas anteriores van en `carriedQuests`. Enlaza tramos con `next`.
- Los textos de los pasos (`text`) llevan enUS y esES.
- Al terminar: `python3 tools/validate_routes.py && python3 tools/compile_guides.py`, y corrige hasta que pase.
- En tu respuesta final, explica en castellano por qué elegiste ese orden y la XP estimada al final del tramo.
```

- [ ] **Paso 5: `route-validator.md`**

```markdown
---
name: route-validator
description: Revisa la coherencia de las rutas de data/routes contra los datos crudos de data/raw (prerrequisitos, niveles, coordenadas, facción, XP hasta el nivel objetivo). Solo lectura; reporta problemas. Úsalo tras route-optimizer y antes de commitear rutas.
tools: Read, Grep, Glob, Bash
---

Eres un revisor escéptico de rutas de leveo: asume que hay errores hasta demostrar lo contrario.

1. Ejecuta `python3 tools/validate_routes.py` (reglas estructurales). Si falla, repórtalo y para.
2. Para cada ruta indicada, comprueba contra data/raw que:
   - cada questId existe en data/raw y la facción coincide;
   - los prerrequisitos se aceptan y entregan antes, en esta ruta o en la cadena `next` anterior;
   - el nivel estimado del jugador (por XP acumulada) es >= minLevel de cada quest al aceptarla;
   - las coordenadas de cada paso coinciden con las de start/end del NPC (tolerancia 1.0);
   - el último tramo de la cadena llega a maxLevel 60.
   Además, señala como riesgo las quests con `"forever": false`.
3. Informe en castellano: lista numerada `ruta:steps[n] — problema — evidencia`, de más a menos grave. Si no hay problemas, dilo explícitamente.
No edites archivos.
```

- [ ] **Paso 6: `lua-reviewer.md`**

```markdown
---
name: lua-reviewer
description: Revisa los cambios de código Lua del addon antes de commitear (taint, rendimiento, globals, compatibilidad con Forever 16001, Lua 5.1, idioma, tests congelados). Solo lectura. Úsalo al terminar cada tarea de código.
tools: Read, Grep, Glob, Bash
---

Revisas el diff actual (`git diff` y `git diff --cached`) del addon La Ruta del 60.

Checklist:
- Tests congelados: ningún cambio en `tests/acceptance/`, `tests/support/` ni `tools/tests/acceptance/` sin aprobación explícita del usuario. Si los hay, es un hallazgo crítico.
- Idioma: código, comentarios y strings en inglés (salvo las traducciones de `Locales/esES.lua`).
- Lua 5.1: sin goto, //, operadores de bits nativos, table.unpack sin fallback, <const>/<close>.
- Globals: ninguna fuera de las permitidas en CLAUDE.md.
- APIs de WoW: existen en Forever (si dudas, pregunta a wow-api-expert) y están en `.luacheckrc` y en `docs/api/forever-api.md`.
- Taint: no tocar frames protegidos ni llamar funciones protegidas en combate (InCombatLockdown()); usar hooksecurefunc en vez de reemplazar funciones de Blizzard.
- Rendimiento: OnUpdate con throttle, nada de crear tablas o closures por frame, desregistrar eventos que ya no hacen falta.
- Textos visibles vía ns.L, con clave en enUS y esES. Archivos nuevos en ambos TOC.
- Ejecuta `tools/check.sh`.

Salida en castellano: hallazgos `archivo:línea — problema — arreglo sugerido`, de más a menos grave; o "Sin hallazgos" junto con la salida de check.sh.
No edites archivos.
```

- [ ] **Paso 7: verificar y commit**

```bash
for f in .claude/agents/*.md; do sed -n 2p "$f"; done
git add .claude/agents
git commit -m "feat: specialized subagents for addon and route work"
```
Esperado: seis líneas `name: …` que coinciden con los nombres de archivo.

---

### Tarea 9: Skills

**Archivos:** crear `.claude/skills/{wow-forever-api,guide-format,add-route-segment,new-module,release,debug-in-game}/SKILL.md`

- [ ] **Paso 1: `wow-forever-api/SKILL.md`**

```markdown
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
```

- [ ] **Paso 2: `guide-format/SKILL.md`**

```markdown
---
name: guide-format
description: Usar al crear, editar o leer rutas de leveo (data/routes/**/*.json) o al trabajar con las guías compiladas (addon/LaRutaDel60/Guides). Define el esquema JSON de una ruta, sus reglas de validación y cómo se compila a Lua.
---

# Formato de guía

Las rutas son DATOS. Fuente: `data/routes/<alliance|horde|both>/<id>.json`. Se compilan a `addon/LaRutaDel60/Guides/<id>.lua` + `Guides.xml`, que nunca se editan a mano.

## Ruta
| Campo | Tipo | Regla |
|---|---|---|
| id | string | kebab-case; igual al nombre del archivo; único |
| name | {enUS, esES?} | enUS obligatorio |
| faction | string | Alliance, Horde o Both |
| races, classes | string[] | opcional (p. ej. "Human", "Warrior") |
| minLevel, maxLevel | int | 1..60, min <= max |
| next | string | opcional, id de una ruta existente |
| carriedQuests | int[] | quests aceptadas en rutas anteriores |
| steps | Step[] | no vacía |

## Step
| type | Obligatorio | Significado |
|---|---|---|
| accept | questId | aceptar la quest |
| complete | questId (aceptada antes o en carriedQuests) | completar objetivos |
| turnin | questId (aceptada antes o en carriedQuests) | entregar |
| goto | coords | ir a un punto |
| hearth | — | usar la piedra de hogar |
| fly | — | volar (destino en text/coords) |
| train | — | entrenar clase o profesión |
| note | text | instrucción libre |

Opcionales en cualquier paso: `npcId` (int > 0), `coords {mapId, x, y}` (x e y en 0-100; mapId = uiMapID), `text {enUS, esES?}`, `source` (URL).

## En Lua
`ns.Guides["<id>"]` contiene exactamente los mismos datos que el JSON (lo garantiza un test de aceptación de ida y vuelta).

## Comandos
- Validar: `python3 tools/validate_routes.py`
- Compilar: `python3 tools/compile_guides.py` (`--check` en CI)
El hook post-edición valida al guardar cualquier JSON de data/routes.

## Ejemplo
`data/routes/alliance/alliance-northshire-example.json`.
```

- [ ] **Paso 3: `add-route-segment/SKILL.md`**

```markdown
---
name: add-route-segment
description: Usar cuando el usuario pida añadir o rehacer un tramo de ruta de leveo (p. ej. "ruta humano 1-10", "Horda 30-40 en Stranglethorn"). Orquesta investigar → JSON crudo → optimizar → validar → compilar → commit.
---

# Añadir un tramo de ruta

Entrada: facción, raza o clase (si aplica), rango de niveles y zonas.

1. **Plan:** decide el id (`<faccion>-<zona>-<min>-<max>`), la ruta anterior (para su `next`) y las quests arrastradas.
2. **Investigar:** agente `route-researcher` por zona → `data/raw/<zona>.json`. Comprueba que cada quest tenga `source`.
3. **Optimizar:** agente `route-optimizer` → `data/routes/<faccion>/<id>.json`. Actualiza el `next` de la ruta anterior.
4. **Validar:** agente `route-validator`. Si hay problemas, vuelve al paso 3 con el informe (máx. 3 vueltas; si siguen, informa al usuario).
5. **Compilar:** `python3 tools/compile_guides.py` y `tools/check.sh` en verde.
6. **Commit:** `git add data/ addon/LaRutaDel60/Guides && git commit -m "feat(routes): <id>"`.
7. Informa al usuario en castellano: niveles cubiertos, nº de pasos, quests con `"forever": false`, y pide que lo pruebe en el juego.

No inventes datos: lo que falte se marca en el informe, nunca se rellena.
```

- [ ] **Paso 4: `new-module/SKILL.md`**

````markdown
---
name: new-module
description: Usar al crear un archivo o módulo Lua nuevo en addon/LaRutaDel60 (Core, UI o Modules). Flujo de tests de aceptación primero, plantilla del módulo, registro en ambos TOC y textos localizados.
---

# Nuevo módulo

1. **Tests de aceptación primero**, derivados de la spec de la funcionalidad y no de la implementación: `tests/acceptance/<feature>_spec.lua` usando solo `require("support.client")` (`Client.boot(opts)`, `client.login()`, `client.slash("/ruta ...")`, `client.fire(event, ...)`, `client.messages()`). Si hace falta emular más API del cliente, se amplía `tests/support/` en este mismo paso. Commit en rojo: `test: acceptance tests for <feature> (red)`. A partir de aquí quedan congelados.
2. Archivo `addon/LaRutaDel60/<Folder>/<Name>.lua` (código en inglés):

```lua
local _, ns = ...

local Module = {}
ns.<Name> = Module

function Module.Example()
	-- ...
end
```

3. Regístralo en `LaRutaDel60.toc` en su orden de carga (después de `Core\Init.lua` si usa `ns.Print`) y copia el TOC: `cp addon/LaRutaDel60/LaRutaDel60.toc addon/LaRutaDel60/LaRutaDel60_Forever.toc`.
4. Textos: claves en `Locales/enUS.lua` y `Locales/esES.lua`.
5. APIs de WoW nuevas: skill `wow-forever-api`.
6. `tools/check.sh` en verde → agente `lua-reviewer` → commit.
````

- [ ] **Paso 5: `release/SKILL.md`**

```markdown
---
name: release
description: Usar cuando el usuario pida publicar o sacar una versión del addon. Sube la versión en los TOC, actualiza CHANGELOG.md, crea el tag vX.Y.Z y, con confirmación, lo empuja para que el CI publique el zip.
---

# Release

1. `tools/check.sh` en verde y working tree limpio (`git status`).
2. Versión semver (fix → patch, funcionalidad → minor). Si dudas, pregunta.
3. Cambia `## Version:` en `addon/LaRutaDel60/LaRutaDel60.toc` y cópialo a `_Forever.toc`.
4. Añade al principio de `CHANGELOG.md` (créalo si no existe; en inglés): `## vX.Y.Z - YYYY-MM-DD` con viñetas a partir de `git log --oneline <tag-anterior>..HEAD`.
5. `git commit -am "chore: release vX.Y.Z"` y `git tag vX.Y.Z`.
6. Pide confirmación al usuario antes de `git push origin main --tags` (es público).
7. `.github/workflows/ci.yml` comprueba que el tag coincide con la versión del TOC y publica `LaRutaDel60-vX.Y.Z.zip` en GitHub Releases.
8. Recuerda al usuario: en Windows, `scripts\deploy.ps1 -Source release -Repo <owner>/<repo>`.
```

- [ ] **Paso 6: `debug-in-game/SKILL.md`**

```markdown
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
```

- [ ] **Paso 7: verificar y commit**

```bash
ls .claude/skills/*/SKILL.md | wc -l && grep -h '^name:' .claude/skills/*/SKILL.md
git add .claude/skills
git commit -m "feat: project skills"
```
Esperado: `6` y los seis nombres.

---

### Tarea 10: CLAUDE.md

**Archivos:** crear `CLAUDE.md`

- [ ] **Paso 1: escribir `CLAUDE.md`**

````markdown
# La Ruta del 60

Addon gratuito para **WoW Forever** (Classic+ oficial, cliente 1.60.1, `## Interface: 16001`) que guía a cualquier personaje de 1 a 60 por la ruta más rápida. Se desarrolla 100% con IA en macOS y se juega en Windows.

## Reglas
- **Idioma:** el código va SIEMPRE en inglés (identificadores, comentarios, strings, mensajes de CLI, nombres de tests y commits). Las explicaciones van SIEMPRE en castellano (chat, specs, planes, este archivo, agentes y skills). Los textos al jugador se localizan en enUS y esES.
- **Tests de aceptación primero:** antes de escribir código de una funcionalidad hay tests de caja negra derivados de su spec, commiteados en rojo. `tests/acceptance/`, `tests/support/` y `tools/tests/acceptance/` están **congelados**: se ponen en verde sin modificarlos. Si un test parece mal, PARA y pregunta al usuario.
- **API:** Forever usa la API moderna de retail 12.x sobre Lua 5.1, no la de Classic Era. Antes de usar cualquier API de WoW: skill `wow-forever-api` / agente `wow-api-expert`. Lo verificado está en `docs/api/forever-api.md`.
- **Lua 5.1:** sin `goto`, `//`, operadores de bits nativos, `<const>`.
- **Sin globals:** todo en `ns` (`local ADDON_NAME, ns = ...`). Solo se permiten `LaRutaDel60DB`, `SLASH_LARUTADEL601` y `SlashCmdList.LARUTADEL60`.
- **Rutas = datos:** `data/routes/**/*.json` (skill `guide-format`). `addon/LaRutaDel60/Guides/` es GENERADO: nunca se edita a mano.
- **TOC:** `LaRutaDel60.toc` y `LaRutaDel60_Forever.toc` siempre idénticos.
- **Textos al jugador:** siempre vía `ns.L`, con clave en `Locales/enUS.lua` y `Locales/esES.lua`.
- **Original:** no se copia código ni guías de RestedXP u otros addons.
- Commits pequeños con Conventional Commits. No se hace push sin que el usuario lo pida.

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
````

- [ ] **Paso 2: commit**

```bash
git add CLAUDE.md
git commit -m "docs: CLAUDE.md with rules, commands, agents and skills"
```

---

### Tarea 11: CI (GitHub Actions) y despliegue a Windows

**Archivos:** crear `.github/workflows/ci.yml`, `scripts/deploy.ps1`

- [ ] **Paso 1: `.github/workflows/ci.yml`**

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

      - name: Install busted and luacheck
        run: |
          luarocks install busted
          luarocks install luacheck

      - name: Install stylua
        uses: JohnnyMorganz/stylua-action@v4
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          version: v2.6.0
          args: --version

      - name: Install lua-language-server
        run: |
          mkdir -p "$HOME/luals"
          curl -sSL https://github.com/LuaLS/lua-language-server/releases/download/3.19.2/lua-language-server-3.19.2-linux-x64.tar.gz \
            | tar -xz -C "$HOME/luals"
          echo "$HOME/luals/bin" >> "$GITHUB_PATH"

      - name: Fetch WoW API annotations
        run: tools/fetch_annotations.sh

      - name: Full verification
        run: tools/check.sh

  release:
    if: startsWith(github.ref, 'refs/tags/v')
    needs: check
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v4

      - name: Check TOC version matches tag
        run: |
          toc_version="$(sed -n 's/^## Version: //p' addon/LaRutaDel60/LaRutaDel60.toc | tr -d '\r')"
          if [ "v$toc_version" != "$GITHUB_REF_NAME" ]; then
            echo "Tag $GITHUB_REF_NAME does not match TOC version $toc_version" >&2
            exit 1
          fi

      - name: Package
        run: |
          mkdir -p dist
          (cd addon && zip -r "../dist/LaRutaDel60-$GITHUB_REF_NAME.zip" LaRutaDel60)

      - uses: softprops/action-gh-release@v2
        with:
          files: dist/*.zip
          generate_release_notes: true
```

- [ ] **Paso 2: `scripts/deploy.ps1`**

```powershell
<#
.SYNOPSIS
    Installs La Ruta del 60 into WoW Forever (Windows).
.EXAMPLE
    .\scripts\deploy.ps1
    .\scripts\deploy.ps1 -WowPath "D:\Games\World of Warcraft\_forever_"
    .\scripts\deploy.ps1 -Source release -Repo user/larutadel60
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
    throw "WoW Forever folder not found. Pass -WowPath 'C:\...\World of Warcraft\_forever_' or set WOW_FOREVER_PATH."
}
Write-Host "WoW folder: $WowPath"

$AddOns = Join-Path $WowPath "Interface\AddOns"
New-Item -ItemType Directory -Force -Path $AddOns | Out-Null
$Target = Join-Path $AddOns $AddonName

if ($Source -eq "git") {
    git -C $RepoPath pull --ff-only
    if ($LASTEXITCODE -ne 0) { throw "git pull failed in $RepoPath" }
    $From = Join-Path $RepoPath "addon\$AddonName"
}
else {
    if (-not $Repo) { throw "-Source release requires -Repo owner/repository" }
    $release = Invoke-RestMethod "https://api.github.com/repos/$Repo/releases/latest"
    $asset = $release.assets | Where-Object { $_.name -like "$AddonName-*.zip" } | Select-Object -First 1
    if (-not $asset) { throw "Release $($release.tag_name) has no addon zip" }
    $tmp = Join-Path $env:TEMP "$AddonName-deploy"
    if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
    New-Item -ItemType Directory -Path $tmp | Out-Null
    $zip = Join-Path $tmp "addon.zip"
    Invoke-WebRequest $asset.browser_download_url -OutFile $zip
    Expand-Archive $zip -DestinationPath $tmp
    $From = Join-Path $tmp $AddonName
    Write-Host "Release: $($release.tag_name)"
}

if (-not (Test-Path (Join-Path $From "$AddonName.toc"))) { throw "$AddonName.toc not found in $From" }
if (Test-Path $Target) { Remove-Item -Recurse -Force $Target }
Copy-Item -Recurse $From $Target
Write-Host "Installed into $Target" -ForegroundColor Green
Write-Host "In game: /reload  (then /ruta to see the version)"
```

- [ ] **Paso 3: comprobaciones locales**

```bash
python3 -c "t=open('.github/workflows/ci.yml').read(); assert '\t' not in t; print('YAML_NO_TABS_OK')"
command -v pwsh >/dev/null && pwsh -NoProfile -Command "\$e=\$null; [System.Management.Automation.Language.Parser]::ParseFile('scripts/deploy.ps1',[ref]\$null,[ref]\$e) > \$null; if (\$e) { \$e; exit 1 } else { 'PS_OK' }" || echo "pwsh not installed: validate on Windows"
tools/check.sh
```
Esperado: `YAML_NO_TABS_OK`, `PS_OK` o el aviso de que no hay pwsh, y `OK: all green`.

- [ ] **Paso 4: commit**

```bash
git add .github/workflows/ci.yml scripts/deploy.ps1
git commit -m "ci: verification and release workflow; deploy.ps1 for Windows"
```

---

### Tarea 12: Verificación final, publicación y checklist manual

- [ ] **Paso 1: verificación completa**

Run: `tools/check.sh && git status --short`
Esperado: `OK: all green` y working tree limpio.

- [ ] **Paso 2: tests congelados intactos**

Run: `git diff --stat acceptance-frozen HEAD -- tests/acceptance tests/support tools/tests/acceptance`
Esperado: sin salida (ningún cambio desde el commit en rojo).

- [ ] **Paso 3: publicar en GitHub (requiere confirmación del usuario)**

Preguntar al usuario el nombre y la visibilidad del repo. Después:
```bash
gh repo create <usuario>/larutadel60 --<public|private> --source . --remote origin --push
gh run watch --exit-status
```
Esperado: CI en verde.

- [ ] **Paso 4: checklist manual para el usuario (spec §11.5)**

1. En Windows:
   ```powershell
   git clone https://github.com/<usuario>/larutadel60.git
   cd larutadel60
   powershell -ExecutionPolicy Bypass -File .\scripts\deploy.ps1
   ```
2. En el juego (cliente en español): aparece `La Ruta del 60: Cargado. Escribe /ruta para más info.` y `/ruta` muestra `Versión 0.1.0 - 1 guía(s) cargada(s).`
3. Si aparece el aviso de "no es WoW Forever" o no se encuentra la carpeta, anotar el valor o la ruta reales en `docs/api/forever-api.md` y en `deploy.ps1`.
4. En Claude Code, que el LSP responda al hover (Tarea 7, Paso 5).
