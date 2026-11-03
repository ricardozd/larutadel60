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
