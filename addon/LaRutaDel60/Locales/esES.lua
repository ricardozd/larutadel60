local _, ns = ...

local locale = GetLocale()
if locale ~= "esES" and locale ~= "esMX" then
	return
end

local L = ns.L
L.LOADED = "Cargado. Escribe /ruta para más info."
L.NOT_FOREVER = "Aviso: este cliente no es WoW Forever; las guías pueden fallar."
L.VERSION_INFO = "Versión %s - %d guía(s) cargada(s)."
