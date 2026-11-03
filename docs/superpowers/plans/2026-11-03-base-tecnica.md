# La Ruta del 60 Technical Base — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** leave the repository ready to develop a 1-60 leveling addon for WoW Forever 100% with AI: Lua toolchain (LSP, lint, formatting, tests), JSON→Lua route pipeline, "hello world" addon, agents, skills, hooks, CI and deployment to Windows.

**Architecture:** first the **black-box acceptance tests** derived from the spec (§11) are written, and they are frozen. Then each task implements just enough to turn them green. The addon lives in `addon/LaRutaDel60/`. Routes are data (`data/routes/**/*.json`) that are validated and compiled to `addon/LaRutaDel60/Guides/`. Lua tests run with busted on LuaJIT (Lua 5.1 compatible), with a client emulator in `tests/support/`. The Python and tool tests use unittest and run the CLIs as subprocesses.

**Tech Stack:** Lua 5.1 / LuaJIT 2.1, busted 2.3, luacheck 1.2, stylua 2.6, lua-language-server 3.19, anotaciones Ketho `vscode-wow-api`, Python 3 (solo stdlib), GitHub Actions, PowerShell 5+.

## Restricciones globales

- **Language:** everything committed to the repo is in English (code, comments, strings, CLI messages, test names, commits, docs, CLAUDE.md, agents, skills). Player-facing texts are localized (enUS + esES). The assistant talks to the user in Spanish in chat.
- **Frozen acceptance tests:** `tests/acceptance/`, `tests/support/` and `tools/tests/acceptance/` are not modified from Task 3 onwards. If a task cannot turn them green without changing them: STOP and ask the user.
- Cliente objetivo: WoW Forever 1.60.1, `## Interface: 16001`.
- Lua 5.1: sin `goto`, `//`, operadores bit nativos, `<const>`/`<close>`.
- Modern API (retail 12.x). Forever detection: `WOW_PROJECT_ID == WOW_PROJECT_CAMELOT` (18).
- Allowed globals: `LaRutaDel60DB`, `SLASH_LARUTADEL601`, `SlashCmdList.LARUTADEL60`. Everything else in `ns` (`local ADDON_NAME, ns = ...`).
- Chat command: `/ruta`. Player-facing texts in enUS + esES (esMX uses esES), exactly those in spec §11.2.
- `addon/LaRutaDel60/Guides/` is generated: never edited by hand.
- Do not copy code or guides from RestedXP or other addons.
- Python solo stdlib.
- Commits with trailer `Co-Authored-By: Claude <model that made the commit> <noreply@anthropic.com>` (e.g. Opus 5.5, Sonnet 5.5 or Haiku 5.5).

## File structure

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

### Task 1: Toolchain setup (no product code)

**Archivos:**
- Crear: `.gitignore`, `.editorconfig`, `.luarc.json`, `.luacheckrc`, `.stylua.toml`, `.styluaignore`, `.busted`, `tools/setup.sh`, `tools/fetch_annotations.sh`, `data/raw/.gitkeep`

**Interfaces:**
- Produce: `.vendor/vscode-wow-api/Annotations/Core`, `~/.luarocks/bin/busted` (LuaJIT), and the config that all tasks respect.

- [ ] **Step 1: `.gitignore`**

```gitignore
.vendor/
dist/
check.json
__pycache__/
*.pyc
.DS_Store
luacov.*
```

- [ ] **Step 2: `.editorconfig`**

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

- [ ] **Step 3: `.stylua.toml` y `.styluaignore`**

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

- [ ] **Step 4: `.luacheckrc`**

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

- [ ] **Step 5: `.luarc.json`**

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

- [ ] **Step 6: `.busted`**

```lua
return {
	_all = {
		lpath = "tests/?.lua",
		ROOT = { "tests" },
		pattern = "_spec",
	},
}
```

- [ ] **Step 7: `tools/fetch_annotations.sh`**

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

- [ ] **Step 8: `tools/setup.sh`**

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

- [ ] **Step 9: ejecutar setup**

```bash
mkdir -p data/raw && touch data/raw/.gitkeep
chmod +x tools/setup.sh tools/fetch_annotations.sh
tools/setup.sh
luajit -v && ~/.luarocks/bin/busted --version && luacheck --version && stylua --version && lua-language-server --version
```
Expected: `OK: toolchain installed` y cinco versiones (LuaJIT 2.1, busted 2.3.x, Luacheck 1.2.x, stylua 2.6.x, 3.19.x).

- [ ] **Step 10: commit**

```bash
git add .gitignore .editorconfig .luarc.json .luacheckrc .stylua.toml .styluaignore .busted tools/setup.sh tools/fetch_annotations.sh data/raw/.gitkeep
git commit -m "chore: Lua toolchain configuration"
```

---

### Task 2: Acceptance tests (red, then frozen)

They are written **only from spec §11**, with no product code. When this task finishes they must all FAIL or error, because there is nothing to test yet.

**Archivos:**
- Crear: `docs/api/forever-api.md`, `tests/support/wow_mock.lua`, `tests/support/client.lua`, `tests/acceptance/toc_spec.lua`, `tests/acceptance/addon_spec.lua`, `tools/__init__.py`, `tools/tests/__init__.py`, `tools/tests/acceptance/__init__.py`, `tools/tests/acceptance/support.py`, `tools/tests/acceptance/dump_guide.lua`, `tools/tests/acceptance/test_route_pipeline.py`, `tools/tests/acceptance/test_tooling.py`

**Interfaces:**
- Produce (contracts that the following tasks must fulfill, copied from spec §11):
  - CLI `python3 tools/validate_routes.py [DIR]`: exit 0/1; errors on stderr with the file's relative path.
  - CLI `python3 tools/compile_guides.py [--routes DIR] [--out DIR] [--check]`.
  - Generated file `<id>.lua` that, loaded with `(addonName, ns)`, leaves `ns.Guides[id]` equal to the JSON; and `Guides.xml` with `<Script file="<id>.lua"/>`.
  - Chat messages from §11.2. Allowed globals.
  - `tools/check.sh` y `.claude/hooks/post-edit.sh` (§11.3); variable `LR60_SKIP_TOOLING_TESTS=1`.

- [ ] **Step 1: `docs/api/forever-api.md`** (base that the mocks must cite)

```markdown
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
```

- [ ] **Step 2: `tests/support/wow_mock.lua`**

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

- [ ] **Step 3: `tests/support/client.lua`**

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

- [ ] **Step 4: `tests/acceptance/toc_spec.lua`**

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

- [ ] **Step 5: `tests/acceptance/addon_spec.lua`**

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

- [ ] **Step 6: Python packages**

```bash
mkdir -p tools/tests/acceptance
: > tools/__init__.py
: > tools/tests/__init__.py
: > tools/tests/acceptance/__init__.py
```

- [ ] **Step 7: `tools/tests/acceptance/support.py`**

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

- [ ] **Step 8: `tools/tests/acceptance/dump_guide.lua`**

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

- [ ] **Step 9: `tools/tests/acceptance/test_route_pipeline.py`**

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

- [ ] **Step 10: `tools/tests/acceptance/test_tooling.py`**

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

- [ ] **Step 11: lint the tests**

Run: `stylua tests tools/tests && luacheck tests tools/tests/acceptance/dump_guide.lua`
Expected: `Total: 0 warnings / 0 errors`.

- [ ] **Step 12: confirm that EVERYTHING is red**

```bash
~/.luarocks/bin/busted; echo "busted exit=$?"
python3 -m unittest discover -s tools/tests -t . 2>&1 | tail -3
```
Expected: busted ends with errors (`missing file addon/LaRutaDel60/LaRutaDel60.toc`) and exit ≠ 0. unittest ends with `FAILED (failures=…, errors=…)` and **no test green**: the CLIs do not exist (python returns exit 2, not the 1 the tests expect) and `check.sh`/the hook do not exist (error when running them). If any test passes, the test is badly written: fix it now, before freezing it.

- [ ] **Step 13: commit (in red)**

```bash
git add docs/api tests tools/__init__.py tools/tests
git commit -m "test: black-box acceptance tests for the technical base (red)"
```

---

### Task 3: Route pipeline (validator + compiler + example route)

**Task goal:** turn `tools/tests/acceptance/test_route_pipeline.py` green without modifying it.

**Archivos:**
- Crear: `tools/validate_routes.py`, `tools/compile_guides.py`, `data/routes/alliance/alliance-northshire-example.json`
- Generados: `addon/LaRutaDel60/Guides/alliance-northshire-example.lua`, `addon/LaRutaDel60/Guides/Guides.xml`

**Interfaces:**
- Consumes: the contracts of Task 2.
- Produce: `validate_routes.validate_all(routes_dir) -> list[str]`, `validate_routes.ROOT`, `ROUTES_DIR`; the generated guides that the addon loads (Task 4).

- [ ] **Step 1: see it red**

Run: `python3 -m unittest tools.tests.acceptance.test_route_pipeline 2>&1 | tail -1`
Expected: `FAILED (...)`.

- [ ] **Step 2: `tools/validate_routes.py`**

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

- [ ] **Step 3: `tools/compile_guides.py`**

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

- [ ] **Step 4: example route**

`data/routes/alliance/alliance-northshire-example.json` (Classic data, only to test the pipeline; **not verified in Forever**):
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

- [ ] **Step 5: generate guides and turn green**

```bash
python3 tools/compile_guides.py
python3 -m unittest tools.tests.acceptance.test_route_pipeline -v 2>&1 | tail -3
```
Expected: `OK: compiled 1 guide(s)…` and `OK` in the pipeline tests. If any fails, fix the `tools/` code (never the test).

- [ ] **Step 6: commit**

```bash
git add tools/validate_routes.py tools/compile_guides.py data/routes addon/LaRutaDel60/Guides
git commit -m "feat: route validator and JSON-to-Lua guide compiler"
```

---

### Task 4: "Hello world" addon

**Task goal:** turn `tests/acceptance/*_spec.lua` green without modifying them.

**Archivos:**
- Crear: `addon/LaRutaDel60/LaRutaDel60.toc`, `addon/LaRutaDel60/LaRutaDel60_Forever.toc`, `addon/LaRutaDel60/Locales/Locales.lua`, `addon/LaRutaDel60/Locales/enUS.lua`, `addon/LaRutaDel60/Locales/esES.lua`, `addon/LaRutaDel60/Core/Init.lua`

**Interfaces:**
- Consume: `Guides/Guides.xml` y `ns.Guides[id]` (Task 3).
- Produce: `ns.L` (text table with fallback to the key), `ns.Print(msg)`, `ns.Guides`. Locale keys: `ADDON_TITLE`, `LOADED`, `NOT_FOREVER`, `VERSION_INFO`.

- [ ] **Step 1: see it red**

Run: `~/.luarocks/bin/busted 2>&1 | tail -2`
Expected: errors because the TOC does not exist.

- [ ] **Step 2: TOC**

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

- [ ] **Step 3: locales**

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

- [ ] **Step 4: `addon/LaRutaDel60/Core/Init.lua`**

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

- [ ] **Step 5: turn green**

Run: `stylua addon && luacheck addon && ~/.luarocks/bin/busted`
Expected: luacheck `0 warnings / 0 errors`; busted `12 successes / 0 failures / 0 errors`. If a spec fails, fix the addon (never the spec).

- [ ] **Step 6: commit**

```bash
git add addon/LaRutaDel60
git commit -m "feat: hello-world addon with /ruta, enUS/esES and Forever detection"
```

---

### Task 5: Full verification (`tools/check.sh`)

**Task goal:** turn `CheckScriptTest` in `test_tooling.py` green.

**Archivos:**
- Crear: `tools/luals_check.sh`, `tools/check.sh`

- [ ] **Step 1: `tools/luals_check.sh`**

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

- [ ] **Step 2: check that LuaLS detects real errors**

```bash
chmod +x tools/luals_check.sh
printf 'local _, ns = ...\nns.x = UnknownWowThing()\n' > addon/LaRutaDel60/Core/Broken.lua
tools/luals_check.sh; echo "exit=$?"
rm addon/LaRutaDel60/Core/Broken.lua
tools/luals_check.sh; echo "exit=$?"
```
Expected: the first time `undefined-global` and `exit=1`; the second, `no problems found` and `exit=0`. If the second flags warnings in the addon, fix the code (do not disable diagnostics).

- [ ] **Step 3: `tools/check.sh`**

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

- [ ] **Step 4: turn green**

```bash
chmod +x tools/check.sh
python3 -m unittest tools.tests.acceptance.test_tooling.CheckScriptTest -v 2>&1 | tail -3
```
Expected: `OK` (4 tests).

- [ ] **Step 5: commit**

```bash
git add tools/check.sh tools/luals_check.sh
git commit -m "chore: full verification script"
```

---

### Task 6: Post-edit hook and Claude Code permissions

**Task goal:** turn `PostEditHookTest` green and, with it, the full `tools/check.sh`.

**Archivos:**
- Crear: `.claude/hooks/post-edit.sh`, `.claude/settings.json`

- [ ] **Step 1: `.claude/hooks/post-edit.sh`**

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

- [ ] **Step 2: `.claude/settings.json`**

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

- [ ] **Step 3: turn everything green**

```bash
chmod +x .claude/hooks/post-edit.sh
python3 -m json.tool .claude/settings.json > /dev/null && echo JSON_OK
python3 -m unittest tools.tests.acceptance.test_tooling -v 2>&1 | tail -3
tools/check.sh
```
Expected: `JSON_OK`, `OK` (9 tests) y `OK: all green`.

- [ ] **Step 4: commit**

```bash
git add .claude/settings.json .claude/hooks/post-edit.sh
git commit -m "chore: Claude Code post-edit hook and permissions"
```

---

### Task 7: Local LSP plugin for Claude Code

**Archivos:**
- Crear: `.claude-plugin/marketplace.json`, `claude-plugins/wow-lua-lsp/.claude-plugin/plugin.json`
- Modificar: `.claude/settings.json` (modified by the CLI when installing with `--scope project`)

- [ ] **Step 1: `.claude-plugin/marketplace.json`**

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

- [ ] **Step 2: `claude-plugins/wow-lua-lsp/.claude-plugin/plugin.json`**

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

- [ ] **Step 3: validar**

Run: `claude plugin validate ./claude-plugins/wow-lua-lsp && claude plugin validate .`
Expected: `Validation passed` in both (if there are warnings, they must not be about `lspServers`).

- [ ] **Step 4: install at project level**

```bash
claude plugin marketplace add ./
claude plugin install wow-lua-lsp@larutadel60 --scope project
git diff .claude/settings.json
claude plugin list
```
Expected: `.claude/settings.json` gains `enabledPlugins` with `"wow-lua-lsp@larutadel60": true`, and `claude plugin list` shows it without errors. If the CLI does not add `extraKnownMarketplaces`, add it by hand:
```json
"extraKnownMarketplaces": {
  "larutadel60": { "source": { "source": "directory", "path": "./" } }
}
```

- [ ] **Step 5: manual verification (noted for the final checklist)**

In a new Claude Code session: "use the LSP tool to hover over `C_AddOns` in `addon/LaRutaDel60/Core/Init.lua`". Expected: it returns the documentation from the Ketho annotation. If it fails, the fallback is `tools/luals_check.sh` inside `check.sh`; note it in `docs/api/forever-api.md`, section "Tooling".

- [ ] **Step 6: `tools/check.sh` green and commit**

```bash
tools/check.sh
git add .claude-plugin claude-plugins .claude/settings.json
git commit -m "chore: local LSP plugin (lua-language-server) for Claude Code"
```

---

### Task 8: Subagents

**Files:** create `.claude/agents/{wow-api-expert,addon-engineer,route-researcher,route-optimizer,route-validator,lua-reviewer}.md`

- [ ] **Step 1: `wow-api-expert.md`**

```markdown
---
name: wow-api-expert
description: Verifies whether a WoW API function, event, widget or constant exists and how it behaves in WoW Forever 1.60.1 (Interface 16001). Use it BEFORE using any WoW API that is not already in the code or in docs/api/forever-api.md. Read-only.
tools: Read, Grep, Glob, WebFetch, WebSearch
---

You are the expert on the WoW Forever addon API (client 1.60.1, Interface 16001, Lua 5.1).

Fixed context:
- Forever uses the retail 12.x UI architecture (C_QuestLog, C_Map, C_Item, C_Spell...), NOT the Classic Era 1.15 one.
- Midnight "secrets" restrictions are active. About 1,041 retail FrameXML globals were removed.
- Detection: WOW_PROJECT_ID == WOW_PROJECT_CAMELOT (18).

Process for each API:
1. Search `docs/api/forever-api.md` (already verified knowledge).
2. `Grep` in `.vendor/vscode-wow-api/Annotations/Core` to get the signature, parameters and returns.
3. If in doubt about Forever, consult warcraft.wiki.gg (including "Patch 1.60.1/API changes").
4. Answer with: exists yes/no/uncertain, exact signature, related events, restrictions (protected, combat lockdown, secret), alternative if it does not exist and URLs consulted. Reply to the user in Spanish; everything written to the repo is in English.

If you confirm something new, propose (without writing it) the line for `docs/api/forever-api.md` and, if it is a global, for `read_globals` in `.luacheckrc` and for `tests/support/wow_mock.lua` (frozen file: the proposal goes to the user for approval and only additively).
Never invent an API: "uncertain" is a valid answer.
```

- [ ] **Step 2: `addon-engineer.md`**

```markdown
---
name: addon-engineer
description: Implements addon functionality (guide engine, arrow, auto-quest, UI, modules) in addon/LaRutaDel60 by making already-written acceptance tests pass. Use it for any Lua code change in the addon.
tools: Read, Edit, Write, Grep, Glob, Bash
---

You implement code for the La Ruta del 60 addon for WoW Forever (Interface 16001, Lua 5.1).

Non-negotiable rules (see CLAUDE.md):
- Code 100% in English (identifiers, comments, strings). Reply to the user in Spanish; everything written to the repo is in English.
- The acceptance tests (`tests/acceptance/`, `tests/support/`, `tools/tests/acceptance/`) are frozen. Your job is to turn them green without touching them. If a test looks incorrect, STOP and explain it; do not change it.
- If the feature has no acceptance tests, ask for them before writing code (they must be derived from the spec, not from your implementation).
- No new globals: everything in `ns` (`local ADDON_NAME, ns = ...`). Allowed: LaRutaDel60DB, SLASH_LARUTADEL601, SlashCmdList.LARUTADEL60.
- Every new WoW API: verify it by reading `.claude/skills/wow-forever-api/SKILL.md` and `docs/api/forever-api.md` (you cannot invoke skills or agents); if you still have doubts about the API, STOP and report it to the main agent so it consults `wow-api-expert`. Once verified, add it to `.luacheckrc` and to `docs/api/forever-api.md`.
- One module per file, in BOTH TOCs (identical). Follow `.claude/skills/new-module/SKILL.md` (read it directly).
- Visible texts always via `ns.L`, with a key in `Locales/enUS.lua` and in `Locales/esES.lua`.
- Never edit `addon/LaRutaDel60/Guides/` (it is generated).
- Performance: nothing heavy in OnUpdate without a throttle; use events.
- Do not copy code from RestedXP or other addons.

Always finish by running `tools/check.sh` and report its final output.
```

- [ ] **Step 3: `route-researcher.md`**

```markdown
---
name: route-researcher
description: Researches quests, NPCs, coordinates, levels and prerequisites of a zone or segment in web databases (Wowhead and similar, with WoW Forever data) and saves them as raw JSON in data/raw/. First step of the add-route-segment skill.
tools: Read, Write, Grep, Glob, WebFetch, WebSearch
---

You collect raw data for WoW Forever leveling routes. You do NOT create routes, only data.

Output: `data/raw/<zone-kebab>.json` (keys in English):
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

Rules:
- Never copy data or routes from RestedXP or other commercial or paid guides. Use only public quest databases, citing `source`.
- Prioritize sources with WoW Forever 1.60.1 data. Forever has about 1,000 new quests and dungeon XP comes from quests, so Classic Era data may be wrong. Set `"forever": false` on every quest whose data you only find for Classic Era.
- Every quest MUST have `source` (URL). Do not invent anything: if a datum is missing, omit it and note it in `notes`.
- Coordinates as a 0-100 percentage of map `mapId` (uiMapID).
- If the zone file already exists, merge without deleting verified data.
- Reply to the user in Spanish; everything written to the repo is in English.
```

- [ ] **Step 4: `route-optimizer.md`**

```markdown
---
name: route-optimizer
description: Builds or optimizes a leveling route (data/routes/<faction>/<id>.json) from the raw data in data/raw/, minimizing the time to the target level. Use it after route-researcher.
tools: Read, Write, Edit, Grep, Glob, Bash
---

You design the fastest possible leveling routes for WoW Forever, in the format of the `guide-format` skill.

Criteria, in order:
1. XP per minute: group quests by area, accept everything nearby before leaving and turn in in batches.
2. Less travel: do not backtrack; use `hearth` and `fly` when they save time; use a `note` to indicate where to set the hearthstone.
3. The player must never be under-leveled: estimate the accumulated XP with the `xp` from data/raw and respect minLevel.
4. Class training (`train`) on even levels when you pass near a trainer.
5. Race or class variants only when the starting zone changes or there are class quests.

Rules:
- Never copy data or routes from RestedXP or other commercial or paid guides. Use only public quest databases, citing `source`.
- Only use quests from data/raw that have `source`, and copy `source` into the step.
- Quests accepted in earlier routes go in `carriedQuests`. Link segments with `next`.
- Step texts (`text`) carry enUS and esES.
- When done: `python3 tools/validate_routes.py && python3 tools/compile_guides.py`, and fix until it passes.
- Reply to the user in Spanish; everything written to the repo is in English. In your final answer, explain why you chose that order and the estimated XP at the end of the segment.
```

- [ ] **Step 5: `route-validator.md`**

```markdown
---
name: route-validator
description: Reviews the consistency of the routes in data/routes against the raw data in data/raw (prerequisites, levels, coordinates, faction, XP up to the target level). Read-only; reports problems. Use it after route-optimizer and before committing routes.
tools: Read, Grep, Glob, Bash
---

You are a skeptical reviewer of leveling routes: assume there are errors until proven otherwise.

1. Run `python3 tools/validate_routes.py` (structural rules). If it fails, report it and stop.
2. For each given route, check against data/raw that:
   - every questId exists in data/raw and the faction matches;
   - prerequisites are accepted and turned in earlier, in this route or in the previous `next` chain;
   - the player's estimated level (from accumulated XP) is >= each quest's minLevel when accepting it;
   - each step's coordinates match the NPC's start/end ones (tolerance 1.0);
   - the last segment of the chain reaches maxLevel 60.
   Also flag quests with `"forever": false` as a risk.
3. Reply to the user in Spanish; everything written to the repo is in English. Report: numbered list `route:steps[n] — problem — evidence`, from most to least severe. If there are no problems, say so explicitly.
Do not edit files.
```

- [ ] **Step 6: `lua-reviewer.md`**

```markdown
---
name: lua-reviewer
description: Reviews the addon's Lua code changes before committing (taint, performance, globals, Forever 16001 compatibility, Lua 5.1, language, frozen tests). Read-only. Use it when finishing each code task.
tools: Read, Grep, Glob, Bash
---

You review the current diff (`git diff` and `git diff --cached`) and also the untracked files (`git status --porcelain`) of the La Ruta del 60 addon.

Checklist:
- Frozen tests: no change in `tests/acceptance/`, `tests/support/` or `tools/tests/acceptance/` without explicit user approval. If there are any, it is a critical finding.
- Language: code, comments and strings in English (except the translations in `Locales/esES.lua`).
- Lua 5.1: no goto, //, native bitwise operators, table.unpack without fallback, <const>/<close>.
- Globals: none outside those allowed in CLAUDE.md.
- WoW APIs: they exist in Forever (if in doubt, STOP and report it to the main agent so it consults `wow-api-expert`; you cannot invoke agents or skills; read `.claude/skills/wow-forever-api/SKILL.md`) and they are in `.luacheckrc` and in `docs/api/forever-api.md`.
- Taint: do not touch protected frames or call protected functions in combat (InCombatLockdown()); use hooksecurefunc instead of replacing Blizzard functions.
- Performance: OnUpdate with a throttle, no creating tables or closures per frame, unregister events that are no longer needed.
- Visible texts via ns.L, with a key in enUS and esES. New files in both TOCs.
- Run `tools/check.sh`.

Reply to the user in Spanish; everything written to the repo is in English. Output: findings `file:line — problem — suggested fix`, from most to least severe; or "No findings" together with the output of check.sh.
Do not edit files.
```

- [ ] **Step 7: verificar y commit**

```bash
for f in .claude/agents/*.md; do sed -n 2p "$f"; done
git add .claude/agents
git commit -m "feat: specialized subagents for addon and route work"
```
Expected: six `name: …` lines matching the file names.

---

### Task 9: Skills

**Files:** create `.claude/skills/{wow-forever-api,guide-format,add-route-segment,new-module,release,debug-in-game}/SKILL.md`

- [ ] **Step 1: `wow-forever-api/SKILL.md`**

```markdown
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
```

- [ ] **Step 2: `guide-format/SKILL.md`**

```markdown
---
name: guide-format
description: Use when creating, editing or reading leveling routes (data/routes/**/*.json) or working with the compiled guides (addon/LaRutaDel60/Guides). Defines a route's JSON schema, its validation rules and how it compiles to Lua.
---

# Guide format

Routes are DATA. Source: `data/routes/<alliance|horde|both>/<id>.json`. They are compiled to `addon/LaRutaDel60/Guides/<id>.lua` + `Guides.xml`, which are never edited by hand.

## Route
| Field | Type | Rule |
|---|---|---|
| id | string | kebab-case; equal to the file name; unique |
| name | {enUS, esES?} | enUS required |
| faction | string | Alliance, Horde or Both |
| races, classes | string[] | optional (e.g. "Human", "Warrior") |
| minLevel, maxLevel | int | 1..60, min <= max |
| next | string | optional, id of an existing route |
| carriedQuests | int[] | quests accepted in earlier routes |
| steps | Step[] | non-empty |

## Step
| type | Required | Meaning |
|---|---|---|
| accept | questId | accept the quest |
| complete | questId (accepted earlier or in carriedQuests) | complete objectives |
| turnin | questId (accepted earlier or in carriedQuests) | turn in |
| goto | coords | go to a point |
| hearth | — | use the hearthstone |
| fly | — | fly (destination in text/coords) |
| train | — | train class or profession |
| note | text | free-form instruction |

Optional on any step: `npcId` (int > 0), `coords {mapId, x, y}` (x and y in 0-100; mapId = uiMapID), `text {enUS, esES?}`, `source` (URL).

Unknown keys or `null` → error.

## In Lua
`ns.Guides["<id>"]` contains exactly the same data as the JSON (guaranteed by a round-trip acceptance test).

## Commands
- Validate: `python3 tools/validate_routes.py`
- Compile: `python3 tools/compile_guides.py` (`--check` in CI)
The post-edit hook validates any data/routes JSON on save.

## Example
`data/routes/alliance/alliance-northshire-example.json`.
```

- [ ] **Step 3: `add-route-segment/SKILL.md`**

```markdown
---
name: add-route-segment
description: Use when the user asks to add or redo a leveling route segment (e.g. "human route 1-10", "Horde 30-40 in Stranglethorn"). Orchestrates research → raw JSON → optimize → validate → compile → commit.
---

# Add a route segment

Input: faction, race or class (if applicable), level range and zones.

1. **Plan:** decide the id (`<faction>-<zone>-<min>-<max>`), the previous route (for its `next`) and the carried quests.
2. **Research:** `route-researcher` agent per zone → `data/raw/<zone>.json`. Check that every quest has `source`.
3. **Optimize:** `route-optimizer` agent → `data/routes/<faction>/<id>.json`. Update the `next` of the previous route.
4. **Validate:** `route-validator` agent. If there are problems, go back to step 3 with the report (max. 3 rounds; if they persist, inform the user).
5. **Compile:** `python3 tools/compile_guides.py` and `tools/check.sh` green.
6. **Commit:** `git add data/ addon/LaRutaDel60/Guides && git commit -m "feat(routes): <id>"` (with the `Co-Authored-By` trailer).
7. Reply to the user in Spanish; everything written to the repo is in English. Report: levels covered, number of steps, quests with `"forever": false`, and ask them to test it in the game.

Do not invent data: whatever is missing is flagged in the report, never filled in.
```

- [ ] **Step 4: `new-module/SKILL.md`**

````markdown
---
name: new-module
description: Use when creating a new Lua file or module in addon/LaRutaDel60 (Core, UI or Modules). Acceptance-tests-first flow, module template, registration in both TOCs and localized texts.
---

# New module

1. **Acceptance tests first**, derived from the feature's spec and not from the implementation: `tests/acceptance/<feature>_spec.lua` using only `require("support.client")` (`Client.boot(opts)`, `client.login()`, `client.slash("/ruta ...")`, `client.fire(event, ...)`, `client.messages()`). If more client API needs emulating, `tests/support/` is extended in this same step. Only NEW test files (`*_spec.lua`) are added and `tests/support/` is only extended additively (new emulated functions or APIs) without changing existing behavior. Any change in `tests/support/` requires explicit user approval, because `lua-reviewer` treats it as critical. Never modify existing tests or emulations; if one looks wrong, STOP and ask the user. Commit in red: `test: acceptance tests for <feature> (red)` (with the `Co-Authored-By` trailer); it is the only allowed exception to "`tools/check.sh` green before every commit". From here on they are frozen.
2. File `addon/LaRutaDel60/<Folder>/<Name>.lua` (code in English):

```lua
local _, ns = ...

local Module = {}
ns.<Name> = Module

function Module.Example()
	-- ...
end
```

3. Register it in `LaRutaDel60.toc` in its load order (after `Core\Init.lua` if it uses `ns.Print`) and copy the TOC: `cp addon/LaRutaDel60/LaRutaDel60.toc addon/LaRutaDel60/LaRutaDel60_Forever.toc`.
   The guides (`Guides\Guides.xml`) are loaded AFTER Core in the TOC: a module must read `ns.Guides` in `PLAYER_LOGIN` (or later), never when the file loads.
4. Texts: keys in `Locales/enUS.lua` and `Locales/esES.lua`.
5. New WoW APIs: skill `wow-forever-api`.
6. `tools/check.sh` green → `lua-reviewer` agent → commit (with the `Co-Authored-By` trailer).
````
- [ ] **Step 5: `release/SKILL.md`**

```markdown
---
name: release
description: Use when the user asks to publish or cut an addon release. Bumps the version in the TOCs, updates CHANGELOG.md, creates the vX.Y.Z tag and, with confirmation, pushes it so CI publishes the zip.
---

# Release

1. `tools/check.sh` green and clean working tree (`git status`). You must be on `main` with the work already integrated (`git branch --show-current` = main) and with a remote configured (`git remote -v`); otherwise stop and tell the user.
2. Semver version (fix → patch, feature → minor). If in doubt, ask.
3. Change `## Version:` in `addon/LaRutaDel60/LaRutaDel60.toc` and copy it to `_Forever.toc`.
4. Add at the top of `CHANGELOG.md` (create it if it does not exist; in English): `## vX.Y.Z - YYYY-MM-DD` with bullets from `git log --oneline <previous-tag>..HEAD` (if it is the first release and there is no previous tag, `git log --oneline` with the whole history).
5. `git add CHANGELOG.md addon/LaRutaDel60/LaRutaDel60.toc addon/LaRutaDel60/LaRutaDel60_Forever.toc && git commit -m "chore: release vX.Y.Z"` (with the `Co-Authored-By` trailer) and `git tag vX.Y.Z`.
6. Ask the user for confirmation before `git push origin main vX.Y.Z` (it is public).
7. `.github/workflows/ci.yml` checks that the tag matches the TOC version and publishes `LaRutaDel60-vX.Y.Z.zip` to GitHub Releases.
8. Remind the user: on Windows, `scripts\deploy.ps1 -Source release -Repo <owner>/<repo>`.
9. Reply to the user in Spanish; everything written to the repo is in English.
```

- [ ] **Step 6: `debug-in-game/SKILL.md`**

```markdown
---
name: debug-in-game
description: Use when the user pastes an in-game error (BugSack/BugGrabber, chat message, Lua error) or their SavedVariables, or says something in the addon does not work in WoW. Turns the failure into an acceptance test that reproduces it and then fixes it.
---

# Debug an in-game failure

Also use `superpowers:systematic-debugging`.

1. Ask for whatever is missing: the full error with stack (in BugSack, copy it), addon version (`/ruta`), what they were doing and, if it is a data problem, `WTF\Account\<ACCOUNT>\SavedVariables\LaRutaDel60.lua`.
2. Locate the `file:line` of the stack inside `addon/LaRutaDel60`. If the error is in Blizzard code, find which call of ours triggers it.
3. "attempt to call a nil value" on a WoW API = API does not exist in Forever → `wow-api-expert` agent.
4. Write an acceptance test in `tests/acceptance/` that reproduces what the player saw. If needed, extend the emulation in `tests/support/` with the real observed behavior and document it in `docs/api/forever-api.md`. Only NEW test files (`*_spec.lua`) are added and `tests/support/` is only extended additively (new emulated functions or APIs) without changing existing behavior. Any change in `tests/support/` requires explicit user approval, because `lua-reviewer` treats it as critical. Never modify existing tests or emulations; if one looks wrong, STOP and ask the user. It must fail. Commit in red and tell the user that test is now frozen.
5. If the failure shows that an existing frozen test encodes incorrect behavior, STOP, explain it to the user and wait for their approval before touching that test.
6. Fix it, leave `tools/check.sh` green and commit `fix: ...`.
7. Ask the user to verify it in the game (`scripts\deploy.ps1` + `/reload`).
8. Reply to the user in Spanish; everything written to the repo is in English.
```

- [ ] **Step 7: verificar y commit**

```bash
ls .claude/skills/*/SKILL.md | wc -l && grep -h '^name:' .claude/skills/*/SKILL.md
git add .claude/skills
git commit -m "feat: project skills"
```
Expected: `6` and the six names.

---

### Task 10: CLAUDE.md

**Files:** create `CLAUDE.md`

- [ ] **Step 1: escribir `CLAUDE.md`**

````markdown
# La Ruta del 60

Free addon for **WoW Forever** (official Classic+, client 1.60.1, `## Interface: 16001`) that guides any character from level 1 to 60 along the fastest route. It is developed 100% with AI on macOS and played on Windows.

## Rules
- **Language:** Everything committed to the repo is in English: code, comments, strings, CLI messages, tests, commits, README, CLAUDE.md, agents, skills, specs, plans and docs. Player-facing texts are localized (enUS + esES). The assistant explains and talks to the user in Spanish in chat.
- **Acceptance tests first:** before writing code for a feature, there are black-box tests derived from its spec, committed in red. `tests/acceptance/`, `tests/support/` and `tools/tests/acceptance/` are **frozen**: they are turned green without modifying them. If a test looks wrong, STOP and ask the user.
  - The freeze is enforced with the `acceptance-frozen` tag: `tools/check.sh` (and CI) fails if anything modified, deleted or renamed relative to the tag changes under those paths, both in the working tree and in commits. Adding new tests is allowed.
  - A new feature adds NEW acceptance tests; after committing them in red, the tag is moved (`git tag -f acceptance-frozen`), only with user approval.
  - The push must include the tags (`git push --follow-tags` or `git push origin acceptance-frozen`; if it was moved, `--force` on that tag with user approval).
- **API:** Forever uses the modern retail 12.x API on Lua 5.1, not the Classic Era one. Before using any WoW API: skill `wow-forever-api` / agent `wow-api-expert`. What has been verified is in `docs/api/forever-api.md`.
- **Lua 5.1:** no `goto`, `//`, native bitwise operators, `<const>`.
- **No globals:** everything in `ns` (`local ADDON_NAME, ns = ...`). Only `LaRutaDel60DB`, `SLASH_LARUTADEL601` and `SlashCmdList.LARUTADEL60` are allowed.
- **Routes = data:** `data/routes/**/*.json` (skill `guide-format`). `addon/LaRutaDel60/Guides/` is GENERATED: never edit it by hand.
- **TOC:** `LaRutaDel60.toc` and `LaRutaDel60_Forever.toc` always identical.
- **Player-facing texts:** always via `ns.L`, with a key in `Locales/enUS.lua` and `Locales/esES.lua`.
- **Original:** no code or guides are copied from RestedXP or other addons.
- Small commits using Conventional Commits. No push unless the user asks.

## Setup (fresh clone, macOS)
1. `tools/setup.sh`: installs the toolchain and the API annotations. If `~/.luarocks/bin` is not in the PATH, it warns: add it yourself in your shell profile (`check.sh` works anyway).
2. LSP plugin for Claude Code (needs `lua-language-server` in the PATH): `claude plugin marketplace add ./` and then `claude plugin install wow-lua-lsp@larutadel60 --scope project`. Then restart Claude Code.
3. `tools/check.sh` must end with `OK: all green`.

## Commands
| What | Command |
|---|---|
| Full verification (mandatory before commit) | `tools/check.sh` |
| Lua tests | `~/.luarocks/bin/busted` (or `busted`) |
| Python tests | `python3 -m unittest discover -s tools/tests -t . -q` |
| Validate / compile routes | `python3 tools/validate_routes.py` / `python3 tools/compile_guides.py` |
| LuaLS | `tools/luals_check.sh` |
| Install the toolchain (macOS) | `tools/setup.sh` |
| Install on Windows | `scripts\deploy.ps1` (PowerShell) |

The hooks in `.claude/settings.json` format and lint every edited `.lua` and validate every route JSON. If they return an error, fix it before continuing.

## Agents (`.claude/agents/`)
- `wow-api-expert`: verifies Forever APIs (read-only).
- `addon-engineer`: implements addon code against acceptance tests.
- `route-researcher`: raw quest data from the web → `data/raw/`.
- `route-optimizer`: builds optimal routes → `data/routes/`.
- `route-validator`: reviews route consistency (read-only).
- `lua-reviewer`: code review before commit (read-only).

## Skills (`.claude/skills/`)
`wow-forever-api`, `guide-format`, `add-route-segment`, `new-module`, `release`, `debug-in-game`.

## Structure
```
addon/LaRutaDel60/   addon (what gets copied to Interface\AddOns)
  Core/ UI/ Modules/ Locales/ Libs/ Guides/(generated)
data/raw/            raw data from the web (with source)
data/routes/         source routes (JSON)
tools/               Python/bash scripts (validator, compiler, check)
tools/tests/         acceptance tests for the tools (frozen)
tests/support/       WoW client emulation (frozen)
tests/acceptance/    addon acceptance tests (frozen)
scripts/deploy.ps1   deployment on Windows
docs/                specs, plans, API
```
````

- [ ] **Step 2: commit**

```bash
git add CLAUDE.md
git commit -m "docs: CLAUDE.md with rules, commands, agents and skills"
```

---

### Task 11: CI (GitHub Actions) and deployment to Windows

**Files:** create `.github/workflows/ci.yml`, `scripts/deploy.ps1`

- [ ] **Step 1: `.github/workflows/ci.yml`**

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

- [ ] **Step 2: `scripts/deploy.ps1`**

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

- [ ] **Step 3: comprobaciones locales**

```bash
python3 -c "t=open('.github/workflows/ci.yml').read(); assert '\t' not in t; print('YAML_NO_TABS_OK')"
command -v pwsh >/dev/null && pwsh -NoProfile -Command "\$e=\$null; [System.Management.Automation.Language.Parser]::ParseFile('scripts/deploy.ps1',[ref]\$null,[ref]\$e) > \$null; if (\$e) { \$e; exit 1 } else { 'PS_OK' }" || echo "pwsh not installed: validate on Windows"
tools/check.sh
```
Expected: `YAML_NO_TABS_OK`, `PS_OK` or the warning that pwsh is not available, and `OK: all green`.

- [ ] **Step 4: commit**

```bash
git add .github/workflows/ci.yml scripts/deploy.ps1
git commit -m "ci: verification and release workflow; deploy.ps1 for Windows"
```

---

### Task 12: Final verification, publishing and manual checklist

- [ ] **Step 1: full verification**

Run: `tools/check.sh && git status --short`
Expected: `OK: all green` y working tree limpio.

- [ ] **Step 2: tests congelados intactos**

Run: `git diff --stat acceptance-frozen HEAD -- tests/acceptance tests/support tools/tests/acceptance`
Expected: no output (no changes since the red commit).

- [ ] **Step 3: publish on GitHub (requires user confirmation)**

Ask the user for the repo name and visibility. Then:
```bash
gh repo create <usuario>/larutadel60 --<public|private> --source . --remote origin --push
gh run watch --exit-status
```
Expected: CI green.

- [ ] **Step 4: manual checklist for the user (spec §11.5)**

1. En Windows:
   ```powershell
   git clone https://github.com/<usuario>/larutadel60.git
   cd larutadel60
   powershell -ExecutionPolicy Bypass -File .\scripts\deploy.ps1
   ```
2. In the game (Spanish client): it shows `La Ruta del 60: Cargado. Escribe /ruta para más info.` and `/ruta` shows `Versión 0.1.0 - 1 guía(s) cargada(s).`
3. If the "not WoW Forever" warning appears or the folder is not found, record the real value or path in `docs/api/forever-api.md` and in `deploy.ps1`.
4. In Claude Code, the LSP must respond to hover (Task 7, Step 5).
