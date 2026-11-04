local _, ns = ...

-- /ruta subcommands (spec §3.5). Plain /ruta (the version line) stays in Core/Init.lua.
local Commands = {}
ns.Commands = Commands

local L = ns.L

local function listRoutes()
	local locale = ns.Game.Locale()
	for _, route in ipairs(ns.Selector.ForCharacter(ns.Guides, ns.Game.Player())) do
		ns.Print(string.format(L.ROUTE_LIST_LINE, route.id, ns.StepText.RouteName(route, locale)))
	end
end

local function resetRoute()
	ns.Engine.Reset()
	ns.Print(L.ROUTE_RESTARTED)
end

local function showWindow()
	ns.StepFrame.Show()
end

local function hideWindow()
	ns.StepFrame.Hide()
end

-- Every alias works in every locale.
local SUBCOMMANDS = {
	list = listRoutes,
	lista = listRoutes,
	reset = resetRoute,
	reiniciar = resetRoute,
	show = showWindow,
	mostrar = showWindow,
	hide = hideWindow,
	ocultar = hideWindow,
}

local function switchRoute(id)
	local route = ns.Engine.SetRoute(id)
	if route then
		ns.Print(string.format(L.ROUTE_SWITCHED, ns.StepText.RouteName(route, ns.Game.Locale())))
	else
		ns.Print(string.format(L.ROUTE_UNKNOWN, id))
	end
end

-- input: the text after "/ruta", already trimmed and not empty.
function Commands.Run(input)
	local subcommand = SUBCOMMANDS[input:lower()]
	if subcommand then
		subcommand()
	else
		switchRoute(input)
	end
end
