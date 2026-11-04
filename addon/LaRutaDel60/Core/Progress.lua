local _, ns = ...

-- Per-character progress and the catch-up rule (spec §2, §3.2).
-- Stored as LaRutaDel60DB.chars["<Name>-<Realm>"] = { route = id, step = n }.
local Progress = {}
ns.Progress = Progress

local function chars()
	local db = ns.Game.DB()
	if type(db.chars) ~= "table" then
		db.chars = {}
	end
	return db.chars
end

-- Saved route id and step for this character, or nil.
function Progress.Load()
	local entry = chars()[ns.Game.CharacterKey()]
	if type(entry) ~= "table" or type(entry.route) ~= "string" then
		return nil
	end
	local step = tonumber(entry.step) or 1
	return entry.route, math.floor(step)
end

function Progress.Save(routeId, step)
	local key = ns.Game.CharacterKey()
	local entry = chars()[key]
	if type(entry) ~= "table" then
		entry = {}
		chars()[key] = entry
	end
	entry.route = routeId
	entry.step = step
end

-- Catch-up rule: whether a step is already satisfied by the quest state, so it can be skipped.
-- goto and the manual types are never skipped this way.
function Progress.IsSatisfied(step)
	local questId = step and step.questId
	if type(questId) ~= "number" then
		return false
	end
	local Game = ns.Game
	if step.type == "accept" then
		return Game.IsOnQuest(questId) or Game.IsQuestCompleted(questId)
	elseif step.type == "complete" then
		return Game.IsReadyForTurnIn(questId) or Game.IsQuestCompleted(questId)
	elseif step.type == "turnin" then
		return Game.IsQuestCompleted(questId)
	end
	return false
end
