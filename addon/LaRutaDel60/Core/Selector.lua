local _, ns = ...

-- Route selection (spec §3.1). Pure logic: guides and player are plain tables.
-- player = { faction, race, class, level } with the English race and class tokens.
local Selector = {}
ns.Selector = Selector

local function contains(list, value)
	for _, item in ipairs(list) do
		if item == value then
			return true
		end
	end
	return false
end

-- Faction, race and class rules only; the level is not checked.
function Selector.MatchesCharacter(route, player)
	if type(route) ~= "table" or type(route.steps) ~= "table" then
		return false
	end
	if route.faction ~= "Both" and route.faction ~= player.faction then
		return false
	end
	if route.races and not contains(route.races, player.race) then
		return false
	end
	if route.classes and not contains(route.classes, player.class) then
		return false
	end
	return true
end

function Selector.Matches(route, player)
	if not Selector.MatchesCharacter(route, player) then
		return false
	end
	local level = player.level or 0
	return (route.minLevel or 1) <= level and level <= (route.maxLevel or 60)
end

-- Ranking: a route that lists races first, then the lowest minLevel, then the id.
local function ranksBefore(a, b)
	local aRaces, bRaces = a.races ~= nil, b.races ~= nil
	if aRaces ~= bRaces then
		return aRaces
	end
	local aMin, bMin = a.minLevel or 1, b.minLevel or 1
	if aMin ~= bMin then
		return aMin < bMin
	end
	return a.id < b.id
end

-- Routes that match the character, ignoring level, ranked like Choose.
function Selector.ForCharacter(guides, player)
	local routes = {}
	for id, route in pairs(guides or {}) do
		if type(route) == "table" and route.id == id and Selector.MatchesCharacter(route, player) then
			routes[#routes + 1] = route
		end
	end
	table.sort(routes, ranksBefore)
	return routes
end

-- The id of the best route for the player at their level, or nil.
function Selector.Choose(guides, player)
	local best
	for id, route in pairs(guides or {}) do
		if type(route) == "table" and route.id == id and Selector.Matches(route, player) then
			if best == nil or ranksBefore(route, best) then
				best = route
			end
		end
	end
	return best and best.id or nil
end
