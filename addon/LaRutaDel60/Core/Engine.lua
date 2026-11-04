local _, ns = ...

-- Guide orchestration (spec §3.2): selection at login, event-driven advance, goto polling,
-- manual actions and route chaining. Views subscribe with OnChange and OnTick.
local Engine = {}
ns.Engine = Engine

-- Yards within which a goto step is reached.
local GOTO_RADIUS = 10
-- Seconds between time-based checks (goto distance, arrow).
local TICK_SECONDS = 0.1

local MANUAL_TYPES = { hearth = true, fly = true, train = true, note = true }
-- Steps shown in the window: the current one plus 2 upcoming (spec §3.3).
local VISIBLE_STEPS = 3
-- Upper bound on `next` hops in one catch-up, so a cycle of satisfied routes terminates.
local MAX_CHAIN_HOPS = 100

local started = false
local routeId -- current route id, or nil when no route matches
local index = 1 -- current step; #steps + 1 means "route complete"
-- Set by Back when it lands on an already satisfied step: that step is not auto-completed by the
-- quest state (or by standing in a goto radius) until the step changes or stops being satisfied.
local held = false
local ticker
local player -- faction, race and class do not change during a session
-- Last progress written to the saved variables, so unchanged state is not written again.
local savedRouteId, savedIndex

local changeListeners = {}
local tickListeners = {}

-- Navigation to the current step's coords, refreshed on every step change and tick.
local targetStep, targetContinent, targetX, targetY
local navDistance, navBearing

local function currentRoute()
	return routeId and ns.Guides[routeId] or nil
end

local function currentStep()
	local route = currentRoute()
	return route and route.steps[index] or nil
end

local function updateNavigation()
	local step = currentStep()
	if step ~= targetStep then
		targetStep = step
		targetContinent, targetX, targetY = nil, nil, nil
		local coords = step and step.coords
		if type(coords) == "table" then
			targetContinent, targetX, targetY = ns.Game.MapToWorld(coords.mapId, coords.x, coords.y)
		end
	end
	navDistance, navBearing = nil, nil
	if targetContinent == nil then
		return
	end
	local continent, playerX, playerY = ns.Game.PlayerWorld()
	if continent == nil or continent ~= targetContinent then
		return
	end
	-- World X grows north and world Y grows west, so atan2(dWest, dNorth) is counterclockwise from north.
	local dNorth, dWest = targetX - playerX, targetY - playerY
	navDistance = math.sqrt(dNorth * dNorth + dWest * dWest)
	navBearing = math.atan2(dWest, dNorth)
end

local function currentPlayer()
	player = player or ns.Game.Player()
	return player
end

-- Whether a step is already done by the game state: the catch-up rule for quest steps, and
-- being inside the radius for goto. Back holds a step while this stays true.
local function isDone(step)
	if step == nil then
		return false
	end
	if step.type == "goto" then
		return navDistance ~= nil and navDistance <= GOTO_RADIUS
	end
	return ns.Progress.IsSatisfied(step)
end

local function save()
	if routeId and (routeId ~= savedRouteId or index ~= savedIndex) then
		savedRouteId, savedIndex = routeId, index
		ns.Progress.Save(routeId, index)
	end
end

local function refreshViews()
	for i = 1, #changeListeners do
		changeListeners[i]()
	end
end

-- After a step or route change: persist, recompute navigation and refresh the views.
local function notify()
	save()
	updateNavigation()
	refreshViews()
end

-- Catch-up: keep advancing while the current step is satisfied, chaining to `next` at the end.
local function settle()
	held = false
	local hops = 0
	while true do
		local route = currentRoute()
		if route == nil then
			return
		end
		local steps = route.steps
		if index > #steps then
			local nextId = route.next
			local nextRoute = nextId ~= routeId and ns.Selector.Find(ns.Guides, nextId, currentPlayer())
			if nextRoute and hops < MAX_CHAIN_HOPS then
				hops = hops + 1
				routeId, index = nextId, 1
			else
				index = #steps + 1
				return
			end
		elseif ns.Progress.IsSatisfied(steps[index]) then
			index = index + 1
		else
			return
		end
	end
end

-- Completes the current step and catches up.
local function advance()
	if currentStep() == nil then
		return
	end
	index = index + 1
	settle()
	notify()
end

------------------------------------------------------------------------------------------------
-- Events and polling
------------------------------------------------------------------------------------------------

local function onQuestAccepted(...)
	-- The quest ID is the last argument in every client version.
	local questId = select(select("#", ...), ...)
	local step = currentStep()
	if step and step.type == "accept" and step.questId == questId then
		advance()
	end
end

local function onQuestTurnedIn(questId)
	local step = currentStep()
	if step and step.type == "turnin" and step.questId == questId then
		advance()
	end
end

local function onQuestLogUpdate()
	local step = currentStep()
	if step == nil then
		return
	end
	if held then
		held = isDone(step)
		return
	end
	if ns.Progress.IsSatisfied(step) then
		settle()
		notify()
	end
end

local function isVisibleQuest(questId)
	local route = currentRoute()
	if route == nil then
		return false
	end
	for i = index, index + VISIBLE_STEPS - 1 do
		local step = route.steps[i]
		if step and step.questId == questId then
			return true
		end
	end
	return false
end

local function onQuestDataLoaded(questId, success)
	if not success then
		ns.Game.ForgetQuestRequest(questId)
		return
	end
	if isVisibleQuest(questId) then
		refreshViews()
	end
end

local function onTick()
	updateNavigation()
	local step = currentStep()
	if held then
		held = isDone(step)
	elseif step and step.type == "goto" and isDone(step) then
		advance()
	end
	for i = 1, #tickListeners do
		tickListeners[i]()
	end
end

------------------------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------------------------

-- Selects the route (saved progress first) and starts listening. Called once at PLAYER_LOGIN.
function Engine.Start()
	if started then
		return
	end
	started = true
	local savedRoute, savedStep = ns.Progress.Load()
	savedRouteId, savedIndex = savedRoute, savedStep
	local saved = savedRoute and ns.Selector.Find(ns.Guides, savedRoute, currentPlayer())
	if saved then
		routeId = savedRoute
		index = math.max(1, math.min(savedStep, #saved.steps + 1))
	else
		routeId = ns.Selector.Choose(ns.Guides, currentPlayer())
		index = 1
	end
	if routeId then
		settle()
	end
	notify()

	ns.Game.On("QUEST_ACCEPTED", onQuestAccepted)
	ns.Game.On("QUEST_TURNED_IN", onQuestTurnedIn)
	ns.Game.On("QUEST_LOG_UPDATE", onQuestLogUpdate)
	ns.Game.On("QUEST_DATA_LOAD_RESULT", onQuestDataLoaded)
	ticker = ticker or ns.Game.NewTicker(TICK_SECONDS, onTick)
end

-- Completes a manual step.
function Engine.Done()
	advance()
end

function Engine.Skip()
	advance()
end

-- One step back, without catch-up. Does nothing on step 1.
function Engine.Back()
	if routeId == nil or index <= 1 then
		return
	end
	index = index - 1
	notify()
	held = isDone(currentStep())
end

-- Switches to a route that matches the character (level ignored), at step 1 with catch-up.
-- Returns the route, or nil when the id is unknown or does not match.
function Engine.SetRoute(id)
	local route = ns.Selector.Find(ns.Guides, id, currentPlayer())
	if not route then
		return nil
	end
	routeId, index = id, 1
	settle()
	notify()
	return route
end

-- Back to step 1 of the current route, with catch-up. Does nothing when there is no route.
function Engine.Reset()
	if routeId == nil then
		return
	end
	index = 1
	settle()
	notify()
end

-- route, index, step. step is nil on "route complete"; route is nil when no route matches.
function Engine.Current()
	return currentRoute(), index, currentStep()
end

function Engine.IsManual(step)
	return step ~= nil and MANUAL_TYPES[step.type] == true
end

-- Distance in yards and bearing (radians counterclockwise from north) to the current step's
-- coords, or nil when they are unknown (no coords, no position, or another continent).
function Engine.Navigation()
	return navDistance, navBearing
end

-- callback() runs after every step or route change, and when a visible quest title loads.
function Engine.OnChange(callback)
	changeListeners[#changeListeners + 1] = callback
end

-- callback() runs on every time-based check (every TICK_SECONDS).
function Engine.OnTick(callback)
	tickListeners[#tickListeners + 1] = callback
end
