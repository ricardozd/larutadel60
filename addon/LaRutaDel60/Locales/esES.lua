local _, ns = ...

local locale = GetLocale()
if locale ~= "esES" and locale ~= "esMX" then
	return
end

local L = ns.L
L.LOADED = "Cargado. Escribe /ruta para más info."
L.NOT_FOREVER = "Aviso: este cliente no es WoW Forever; las guías pueden fallar."
L.VERSION_INFO = "Versión %s - %d guía(s) cargada(s)."

-- Step window (spec §3.3).
L.STEP_ACCEPT = "Acepta: %s"
L.STEP_COMPLETE = "Completa: %s"
L.STEP_TURNIN = "Entrega: %s"
L.STEP_GOTO = "Ve a %s, %s"
L.STEP_HEARTH = "Usa tu Piedra de hogar"
L.STEP_FLY = "Toma un vuelo"
L.STEP_TRAIN = "Visita a tu instructor de clase"
L.QUEST_FALLBACK = "Misión #%s"
L.NO_ROUTE = "Todavía no hay ruta para tu personaje."
L.ROUTE_COMPLETE = "¡Ruta completada!"
L.BUTTON_BACK = "Atrás"
L.BUTTON_DONE = "Hecho"
L.BUTTON_SKIP = "Saltar"

-- Waypoint arrow (spec §3.4).
L.ARROW_DISTANCE = "%d yd"

-- Commands (spec §3.5).
L.ROUTE_LIST_LINE = "%s - %s"
L.ROUTE_SWITCHED = "Ruta: %s"
L.ROUTE_UNKNOWN = "Ruta desconocida: %s"
L.ROUTE_RESTARTED = "Ruta reiniciada."
