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

3. Register it in `LaRutaDel60.toc` in its load order (after `Core\Init.lua` if it uses `ns.Print`) and copy the TOC: `cp addon/LaRutaDel60/LaRutaDel60.toc addon/LaRutaDel60/LaRutaDel60_Forever.toc`, then regenerate the Classic Era one: `sed 's/^## Interface: .*/## Interface: 11509/' addon/LaRutaDel60/LaRutaDel60.toc > addon/LaRutaDel60/LaRutaDel60_Vanilla.toc`.
   The guides (`Guides\Guides.xml`) are loaded AFTER Core in the TOC: a module must read `ns.Guides` in `PLAYER_LOGIN` (or later), never when the file loads.
4. Texts: keys in `Locales/enUS.lua` and `Locales/esES.lua`.
5. New WoW APIs: skill `wow-forever-api`.
6. `tools/check.sh` green → `lua-reviewer` agent → commit (with the `Co-Authored-By` trailer).
