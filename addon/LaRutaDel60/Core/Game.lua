local _, ns = ...

-- The only adapter over the WoW API. Every other Core module reads the game through ns.Game,
-- so the guide logic stays testable and the API surface stays in one place.
local Game = {}
ns.Game = Game

local requestedQuests = {}

-- Saved variables, created on first use.
function Game.DB()
	LaRutaDel60DB = LaRutaDel60DB or {}
	return LaRutaDel60DB
end

-- "esES" on Spanish clients (esES and esMX), "enUS" otherwise. Guide data only carries these two.
function Game.Locale()
	local locale = GetLocale()
	if locale == "esES" or locale == "esMX" then
		return "esES"
	end
	return "enUS"
end

-- Player data used by route selection. Race and class are the English tokens.
function Game.Player()
	local _, race = UnitRace("player")
	local _, class = UnitClass("player")
	return {
		faction = UnitFactionGroup("player"),
		race = race,
		class = class,
		level = UnitLevel("player"),
	}
end

-- "<Name>-<Realm>", the per-character key inside LaRutaDel60DB.chars.
function Game.CharacterKey()
	local name = UnitName("player") or "?"
	local realm = GetRealmName() or "?"
	return name .. "-" .. realm
end

------------------------------------------------------------------------------------------------
-- Quests
------------------------------------------------------------------------------------------------

function Game.IsOnQuest(questId)
	return C_QuestLog.IsOnQuest(questId) == true
end

function Game.IsQuestCompleted(questId)
	return C_QuestLog.IsQuestFlaggedCompleted(questId) == true
end

function Game.IsReadyForTurnIn(questId)
	return C_QuestLog.ReadyForTurnIn(questId) == true
end

-- The quest title, or nil while it is not cached. A nil title asks the client to load it once;
-- QUEST_DATA_LOAD_RESULT fires when it is ready.
function Game.QuestTitle(questId)
	local title = C_QuestLog.GetTitleForQuestID(questId)
	if title == nil or title == "" then
		if not requestedQuests[questId] then
			requestedQuests[questId] = true
			C_QuestLog.RequestLoadQuestByID(questId)
		end
		return nil
	end
	return title
end

------------------------------------------------------------------------------------------------
-- Position
------------------------------------------------------------------------------------------------

-- World position of a map point (x and y in percent): continentId, worldX, worldY, or nil.
-- World X grows to the north and world Y to the west (see docs/api/forever-api.md).
function Game.MapToWorld(mapId, x, y)
	if type(mapId) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then
		return nil
	end
	local continent, world = C_Map.GetWorldPosFromMapPos(mapId, CreateVector2D(x / 100, y / 100))
	if continent == nil or world == nil then
		return nil
	end
	local worldX, worldY = world:GetXY()
	return continent, worldX, worldY
end

-- Player world position: continentId, worldX, worldY, or nil (e.g. inside an instance).
function Game.PlayerWorld()
	local mapId = C_Map.GetBestMapForUnit("player")
	if type(mapId) ~= "number" then
		return nil
	end
	local position = C_Map.GetPlayerMapPosition(mapId, "player")
	if position == nil then
		return nil
	end
	local continent, world = C_Map.GetWorldPosFromMapPos(mapId, position)
	if continent == nil or world == nil then
		return nil
	end
	local worldX, worldY = world:GetXY()
	return continent, worldX, worldY
end

-- Radians counterclockwise from north, or nil when unknown (e.g. inside an instance).
function Game.Facing()
	return GetPlayerFacing()
end

------------------------------------------------------------------------------------------------
-- Events and time
------------------------------------------------------------------------------------------------

local handlers = {}
local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(_, event, ...)
	local handler = handlers[event]
	if handler then
		handler(...)
	end
end)

-- One handler per event; handler(...) receives the event arguments.
function Game.On(event, handler)
	handlers[event] = handler
	eventFrame:RegisterEvent(event)
end

function Game.NewTicker(seconds, callback)
	return C_Timer.NewTicker(seconds, callback)
end
