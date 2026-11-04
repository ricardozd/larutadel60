-- Minimal WoW Forever API emulation for out-of-game tests.
-- Only APIs documented in docs/api/forever-api.md may be emulated here.
--
-- Flavors (opts.flavor in WowMock.install):
--   * "forever" (default): WoW Forever 1.60.1, the retail-style API.
--   * "classic_era": WoW Classic Era 1.15.x (docs/superpowers/specs/2026-11-04-classic-era-compat-design.md):
--     WOW_PROJECT_ID = WOW_PROJECT_CLASSIC = 2 and no WOW_PROJECT_CAMELOT; no C_QuestLog.ReadyForTurnIn,
--     GetTitleForQuestID nor RequestLoadQuestByID (and no client.loadQuestData); GetQuestLogIndexByID,
--     GetQuestLogTitle and C_QuestLog.GetQuestInfo instead; QUEST_ACCEPTED fires (logIndex, questID).
local WowMock = {}

WowMock.FOREVER = "forever"
WowMock.CLASSIC_ERA = "classic_era"

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

-- Copies plain data the way SavedVariables serialization does: functions and other non-data values are dropped.
function WowMock.deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, item in pairs(value) do
		local keyType, itemType = type(key), type(item)
		local keyOk = keyType == "string" or keyType == "number" or keyType == "boolean"
		local itemOk = itemType == "table" or itemType == "string" or itemType == "number" or itemType == "boolean"
		if keyOk and itemOk then
			copy[key] = WowMock.deepCopy(item)
		end
	end
	return copy
end

local function toSet(ids)
	local set = {}
	for _, id in ipairs(ids or {}) do
		set[id] = true
	end
	return set
end

WowMock.DEFAULT_PLAYER = {
	name = "Tester",
	realm = "Realm",
	faction = "Horde",
	race = "Scourge",
	class = "WARRIOR",
	level = 1,
}

-- English race token -> localized (enUS) name and raceID, as returned by UnitRace.
local RACES = {
	Human = { "Human", 1 },
	Orc = { "Orc", 2 },
	Dwarf = { "Dwarf", 3 },
	NightElf = { "Night Elf", 4 },
	Scourge = { "Undead", 5 },
	Tauren = { "Tauren", 6 },
	Gnome = { "Gnome", 7 },
	Troll = { "Troll", 8 },
}

-- Class file token -> localized (enUS) name and classID, as returned by UnitClass.
local CLASSES = {
	WARRIOR = { "Warrior", 1 },
	PALADIN = { "Paladin", 2 },
	HUNTER = { "Hunter", 3 },
	ROGUE = { "Rogue", 4 },
	PRIEST = { "Priest", 5 },
	SHAMAN = { "Shaman", 7 },
	MAGE = { "Mage", 8 },
	WARLOCK = { "Warlock", 9 },
	DRUID = { "Druid", 11 },
}

-- World rectangles of each uiMap, in yards, used by C_Map.GetWorldPosFromMapPos.
--
-- Axis convention (mirrors the real client, see the Elwynn Forest example on
-- warcraft.wiki.gg/wiki/API_C_Map.GetWorldPosFromMapPos and HereBeDragons):
--   * world X grows to the NORTH, world Y grows to the WEST;
--   * map x (0-1) grows to the east and map y (0-1) grows to the south;
--   * `top` is the world X of the map's north edge, `left` is the world Y of its west edge;
--   * worldX = top - mapY * height, worldY = left - mapX * width.
-- So with dNorth = targetX - playerX and dWest = targetY - playerY, the bearing measured
-- counterclockwise from north (the same convention as GetPlayerFacing) is atan2(dWest, dNorth).
--
-- The defaults are approximations of Tirisfal Glades (1420) and Silverpine Forest (1421), both on
-- Eastern Kingdoms (continent 0). They are emulation data only, not verified map rectangles.
WowMock.DEFAULT_MAPS = {
	[1420] = { continent = 0, left = 3033.3, top = 3837.5, width = 4518.7, height = 3012.5 },
	[1421] = { continent = 0, left = 3450.0, top = 1666.7, width = 4200.0, height = 2800.0 },
}

-- uiMapID reported by C_Map.GetBestMapForUnit inside an instance when no other ID is given.
WowMock.DEFAULT_INSTANCE_MAP = 9999

-- Player, quest and position state. It outlives a /reload (see client.reload).
-- opts: { player = {...}, quests = {...}, position = {...}, maps = {...} } (see docs/api/forever-api.md)
function WowMock.newWorld(opts)
	opts = opts or {}
	local player = {}
	for key, value in pairs(WowMock.DEFAULT_PLAYER) do
		player[key] = value
	end
	for key, value in pairs(opts.player or {}) do
		player[key] = value
	end

	local questOpts = opts.quests or {}
	local quests = {
		completed = toSet(questOpts.completed),
		log = toSet(questOpts.log),
		ready = toSet(questOpts.ready),
		titles = {},
		-- Quest log order (ids), used by the classic_era quest log API: opts.quests.log in order,
		-- then the ready quests that were not listed in it, then accepted quests at the end.
		order = {},
	}
	for _, id in ipairs(questOpts.log or {}) do
		if not toSet(quests.order)[id] then
			quests.order[#quests.order + 1] = id
		end
	end
	-- A quest ready for turn-in is necessarily in the quest log.
	for _, id in ipairs(questOpts.ready or {}) do
		if not quests.log[id] then
			quests.log[id] = true
			quests.order[#quests.order + 1] = id
		end
	end
	for id, title in pairs(questOpts.titles or {}) do
		quests.titles[id] = title
	end

	local position, instanceMapId
	if opts.position then
		position = {
			mapId = opts.position.mapId,
			x = opts.position.x,
			y = opts.position.y,
			facing = (opts.position.facing or 0) % (2 * math.pi),
		}
	else
		instanceMapId = WowMock.DEFAULT_INSTANCE_MAP
	end

	-- opts.maps is merged over the defaults; both are copied so tests never share or mutate them.
	local maps = WowMock.deepCopy(WowMock.DEFAULT_MAPS)
	for id, rect in pairs(opts.maps or {}) do
		maps[id] = WowMock.deepCopy(rect)
	end

	return {
		player = player,
		quests = quests,
		position = position,
		instanceMapId = instanceMapId,
		maps = maps,
	}
end

-- Text as the player reads it: color (|cAARRGGBB, |cn<NAME>:, |r), texture (|T...|t) and atlas
-- (|A...|a) escapes removed, and the escaped pipe || shown as a single |.
local function stripEscapes(text)
	local PIPE = "\0"
	text = text:gsub("||", PIPE)
	text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn[%w_]+:", ""):gsub("|r", "")
	text = text:gsub("|T.-|t", ""):gsub("|A.-|a", "")
	return (text:gsub("%z", "|"))
end
WowMock.stripEscapes = stripEscapes

local function normalizeAngle(radians)
	local twoPi = 2 * math.pi
	local angle = radians % twoPi
	if angle >= math.pi then
		angle = angle - twoPi
	end
	return angle
end
WowMock.normalizeAngle = normalizeAngle

-- opts: { locale = "enUS", projectId = 18, addonName = "...", tocPath = "...", world = <newWorld()>,
--         flavor = "forever"|"classic_era" (default "forever") }
function WowMock.install(opts)
	local client = { chat = {}, frames = {}, objects = {} }
	local world = opts.world or WowMock.newWorld()
	local classicEra = opts.flavor == WowMock.CLASSIC_ERA
	assert(
		opts.flavor == nil or opts.flavor == WowMock.FOREVER or classicEra,
		"unknown flavor " .. tostring(opts.flavor)
	)
	client.world = world
	client.flavor = opts.flavor or WowMock.FOREVER

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
	if classicEra then
		-- Classic Era: WOW_PROJECT_CLASSIC = 2, and WOW_PROJECT_CAMELOT does not exist.
		_G.WOW_PROJECT_CLASSIC = 2
		_G.WOW_PROJECT_ID = opts.projectId or 2
	else
		_G.WOW_PROJECT_CAMELOT = 18
		_G.WOW_PROJECT_ID = opts.projectId or 18
	end

	local tocFields = readTocFields(opts.tocPath)
	_G.C_AddOns = {
		GetAddOnMetadata = function(addonName, field)
			if addonName ~= opts.addonName then
				return nil
			end
			return tocFields[field]
		end,
	}

	------------------------------------------------------------------------------------------------
	-- Frames and regions
	------------------------------------------------------------------------------------------------

	local function register(object)
		client.objects[#client.objects + 1] = object
		object.serial = #client.objects
	end

	local function noop() end

	-- Methods shared by frames and regions (ScriptRegion / Region in the real client).
	local function addRegionMethods(object)
		object.shown = true
		object.points = {}
		object.width, object.height = 0, 0
		for _, method in ipairs({
			"SetAllPoints",
			"SetAlpha",
			"SetScale",
			"SetDrawLayer",
			"SetVertexColor",
		}) do
			object[method] = noop
		end
		function object:SetPoint(point, ...)
			local relativeTo, relativePoint, x, y
			local argCount = select("#", ...)
			local args = { ... }
			local first = args[1]
			if type(first) == "number" then
				x, y = args[1], args[2]
			elseif argCount == 0 then
				x, y = 0, 0
			else
				relativeTo = first
				if type(relativeTo) == "string" then
					relativeTo = _G[relativeTo]
				end
				if type(args[2]) == "number" then
					x, y = args[2], args[3]
				else
					relativePoint, x, y = args[2], args[3], args[4]
				end
			end
			local anchor = {
				point,
				relativeTo or self.parent or _G.UIParent,
				relativePoint or point,
				x or 0,
				y or 0,
			}
			for i, existing in ipairs(self.points) do
				if existing[1] == point then
					self.points[i] = anchor
					return
				end
			end
			self.points[#self.points + 1] = anchor
		end
		function object:ClearAllPoints()
			self.points = {}
		end
		function object:GetPoint(index)
			local anchor = self.points[index or 1]
			if anchor then
				return anchor[1], anchor[2], anchor[3], anchor[4], anchor[5]
			end
		end
		function object:GetNumPoints()
			return #self.points
		end
		function object:SetSize(width, height)
			self.width, self.height = width, height
		end
		function object:SetWidth(width)
			self.width = width
		end
		function object:SetHeight(height)
			self.height = height
		end
		function object:GetWidth()
			return self.width
		end
		function object:GetHeight()
			return self.height
		end
		function object:GetSize()
			return self.width, self.height
		end
		function object:GetParent()
			return self.parent
		end
		function object:GetName()
			return self.name
		end
		function object:Show()
			if not self.shown then
				self.shown = true
				local handler = self.scripts and self.scripts.OnShow
				if handler then
					handler(self)
				end
			end
		end
		function object:Hide()
			if self.shown then
				self.shown = false
				local handler = self.scripts and self.scripts.OnHide
				if handler then
					handler(self)
				end
			end
		end
		function object:SetShown(shown)
			if shown then
				self:Show()
			else
				self:Hide()
			end
		end
		-- Real client semantics: IsShown is the object's own flag; IsVisible also requires every parent to be shown.
		function object:IsShown()
			return self.shown
		end
		function object:IsVisible()
			if not self.shown then
				return false
			end
			if self.parent then
				return self.parent:IsVisible()
			end
			return true
		end
	end

	local function newRegion(kind, parent, name)
		local region = { kind = kind, parent = parent, name = name }
		addRegionMethods(region)
		if kind == "Texture" then
			for _, method in ipairs({ "SetTexture", "SetColorTexture", "SetTexCoord", "SetAtlas", "SetBlendMode" }) do
				region[method] = noop
			end
			function region:SetRotation(radians)
				self.rotation = radians
			end
			function region:GetRotation()
				return self.rotation or 0
			end
		else
			for _, method in ipairs({
				"SetFont",
				"SetFontObject",
				"SetTextColor",
				"SetJustifyH",
				"SetJustifyV",
				"SetWordWrap",
				"SetNonSpaceWrap",
				"SetMaxLines",
			}) do
				region[method] = noop
			end
			function region:SetText(text)
				self.text = text ~= nil and tostring(text) or nil
			end
			function region:GetText()
				return self.text
			end
			function region:SetFormattedText(format, ...)
				self.text = string.format(format, ...)
			end
		end
		if name then
			_G[name] = region
		end
		register(region)
		return region
	end

	local function newFrame(frameType, frameName, parent, template)
		local frame = {
			events = {},
			scripts = {},
			frameType = frameType or "Frame",
			parent = parent,
			name = frameName,
		}
		addRegionMethods(frame)
		function frame:RegisterEvent(event)
			self.events[event] = true
		end
		function frame:UnregisterEvent(event)
			self.events[event] = nil
		end
		function frame:UnregisterAllEvents()
			self.events = {}
		end
		function frame:IsEventRegistered(event)
			return self.events[event] == true
		end
		function frame:SetScript(name, handler)
			if name == "OnClick" and not self.isButton then
				error(self.frameType .. ' doesn\'t have a "OnClick" script', 2)
			end
			self.scripts[name] = handler
		end
		function frame:GetScript(name)
			return self.scripts[name]
		end
		function frame:HookScript(name, hook)
			local previous = self.scripts[name]
			self:SetScript(name, function(...)
				if previous then
					previous(...)
				end
				hook(...)
			end)
		end
		for _, method in ipairs({
			"SetClampedToScreen",
			"SetFrameStrata",
			"SetFrameLevel",
			"SetUserPlaced",
			"SetToplevel",
		}) do
			frame[method] = noop
		end
		-- Since 9.0 the backdrop API only exists on frames that inherit BackdropTemplate.
		if type(template) == "string" and template:find("BackdropTemplate", 1, true) then
			frame.SetBackdrop = noop
			frame.SetBackdropColor = noop
			frame.SetBackdropBorderColor = noop
		end
		function frame:EnableMouse(enabled)
			self.mouseEnabled = enabled and true or false
		end
		function frame:IsMouseEnabled()
			return self.mouseEnabled == true
		end
		function frame:SetMovable(movable)
			self.movable = movable and true or false
		end
		function frame:IsMovable()
			return self.movable == true
		end
		function frame:RegisterForDrag(...)
			self.dragButtons = { ... }
		end
		function frame:StartMoving()
			if not self.movable then
				error("Frame is not movable", 2)
			end
			self.moving = true
		end
		function frame:StopMovingOrSizing()
			self.moving = false
		end
		function frame:SetParent(newParent)
			self.parent = newParent
		end
		function frame:CreateTexture(name, _, _, _)
			return newRegion("Texture", self, name)
		end
		function frame:CreateFontString(name, _, _)
			return newRegion("FontString", self, name)
		end

		if type(frameType) == "string" and frameType:lower() == "button" then
			frame.isButton = true
			frame.enabled = true
			for _, method in ipairs({
				"RegisterForClicks",
				"SetNormalFontObject",
				"SetHighlightFontObject",
				"SetDisabledFontObject",
				"SetNormalTexture",
				"SetHighlightTexture",
				"SetPushedTexture",
			}) do
				frame[method] = noop
			end
			function frame:SetText(text)
				self.text = text ~= nil and tostring(text) or nil
			end
			function frame:GetText()
				return self.text
			end
			-- The button's own label region; its text is the button text. As in retail it does not exist
			-- until SetText was called, unless a button template (e.g. UIPanelButtonTemplate) provides it.
			function frame:GetFontString()
				local templateLabel = type(template) == "string" and template:find("ButtonTemplate", 1, true)
				if self.text == nil and not self.fontString and not templateLabel then
					return nil
				end
				if not self.fontString then
					local fontString = newRegion("FontString", self, nil)
					fontString.buttonLabel = true
					local button = self
					fontString.SetText = function(_, text)
						button:SetText(text)
					end
					fontString.GetText = function()
						return button.text
					end
					self.fontString = fontString
				end
				return self.fontString
			end
			function frame:Enable()
				self.enabled = true
			end
			function frame:Disable()
				self.enabled = false
			end
			function frame:SetEnabled(enabled)
				self.enabled = enabled and true or false
			end
			function frame:IsEnabled()
				return self.enabled
			end
			function frame:Click(button)
				local handler = self.scripts.OnClick
				if handler and self.enabled then
					handler(self, button or "LeftButton", false)
				end
			end
		end

		if frameName then
			_G[frameName] = frame
		end
		return frame
	end

	-- UIParent is the root of the UI; it is always shown and is not tracked in client.frames.
	_G.UIParent = newFrame("Frame", nil, nil)

	_G.CreateFrame = function(frameType, frameName, parent, template)
		local frame = newFrame(frameType, frameName, parent, template)
		client.frames[#client.frames + 1] = frame
		register(frame)
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

	------------------------------------------------------------------------------------------------
	-- Units
	------------------------------------------------------------------------------------------------

	local player = world.player
	local function isPlayer(unit)
		return unit == "player"
	end

	_G.UnitName = function(unit)
		if isPlayer(unit) then
			return player.name, nil
		end
	end
	_G.GetRealmName = function()
		return player.realm
	end
	_G.UnitFactionGroup = function(unit)
		if isPlayer(unit) then
			return player.faction, player.faction
		end
	end
	_G.UnitRace = function(unit)
		if isPlayer(unit) then
			local info = RACES[player.race] or { player.race, 0 }
			return info[1], player.race, info[2]
		end
	end
	_G.UnitClass = function(unit)
		if isPlayer(unit) then
			local info = CLASSES[player.class] or { player.class, 0 }
			return info[1], player.class, info[2]
		end
	end
	_G.UnitLevel = function(unit)
		if isPlayer(unit) then
			return player.level
		end
		return 0
	end

	------------------------------------------------------------------------------------------------
	-- Quests
	------------------------------------------------------------------------------------------------

	local quests = world.quests
	_G.C_QuestLog = {
		IsQuestFlaggedCompleted = function(questID)
			return quests.completed[questID] == true
		end,
		IsOnQuest = function(questID)
			return quests.log[questID] == true
		end,
		ReadyForTurnIn = function(questID)
			return quests.log[questID] == true and quests.ready[questID] == true
		end,
		GetTitleForQuestID = function(questID)
			return quests.titles[questID]
		end,
		RequestLoadQuestByID = function(questID)
			client.questLoadRequests[#client.questLoadRequests + 1] = questID
		end,
	}
	client.questLoadRequests = {}

	-- 1-based position of the quest in the log, or 0 when it is not in the log.
	local function logIndexOf(questID)
		for index, id in ipairs(quests.order) do
			if id == questID then
				return index
			end
		end
		return 0
	end

	if classicEra then
		-- 1.15 has neither ReadyForTurnIn, GetTitleForQuestID nor RequestLoadQuestByID.
		_G.C_QuestLog.ReadyForTurnIn = nil
		_G.C_QuestLog.GetTitleForQuestID = nil
		_G.C_QuestLog.RequestLoadQuestByID = nil
		-- The cached title, or nil when it is unknown.
		_G.C_QuestLog.GetQuestInfo = function(questID)
			return quests.titles[questID]
		end
		_G.GetQuestLogIndexByID = function(questID)
			return logIndexOf(questID)
		end
		-- title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID.
		-- isComplete is 1 when the quest is ready for turn-in and nil otherwise. The log has no headers.
		_G.GetQuestLogTitle = function(questLogIndex)
			local id = quests.order[questLogIndex]
			if not id then
				return nil
			end
			local isComplete = quests.ready[id] and 1 or nil
			return quests.titles[id], player.level, 0, false, false, isComplete, 0, id
		end
	end

	function client.acceptQuest(id)
		assert(not quests.log[id], "quest " .. tostring(id) .. " is already in the log")
		assert(not quests.completed[id], "quest " .. tostring(id) .. " is already completed")
		quests.log[id] = true
		quests.order[#quests.order + 1] = id
		if classicEra then
			client.fire("QUEST_ACCEPTED", logIndexOf(id), id)
		else
			client.fire("QUEST_ACCEPTED", id)
		end
		client.fire("QUEST_LOG_UPDATE")
	end

	function client.completeObjectives(id)
		assert(quests.log[id], "quest " .. tostring(id) .. " is not in the log")
		quests.ready[id] = true
		client.fire("QUEST_LOG_UPDATE")
	end

	function client.turnInQuest(id)
		assert(quests.log[id], "quest " .. tostring(id) .. " is not in the log")
		quests.log[id] = nil
		quests.ready[id] = nil
		quests.completed[id] = true
		local index = logIndexOf(id)
		if index > 0 then
			table.remove(quests.order, index)
		end
		client.fire("QUEST_TURNED_IN", id, 0, 0)
		client.fire("QUEST_REMOVED", id, false)
		client.fire("QUEST_LOG_UPDATE")
	end

	-- Classic Era has no async quest data load, so QUEST_DATA_LOAD_RESULT never fires there.
	if not classicEra then
		function client.loadQuestData(id)
			quests.titles[id] = quests.titles[id] or ("Quest Title " .. tostring(id))
			client.fire("QUEST_DATA_LOAD_RESULT", id, true)
		end
	end

	function client.levelUp(level)
		client.fire("PLAYER_LEVEL_UP", level)
		-- In the real client UnitLevel may still return the old level while PLAYER_LEVEL_UP runs.
		player.level = level
	end

	------------------------------------------------------------------------------------------------
	-- Map, position and facing
	------------------------------------------------------------------------------------------------

	local function vector2(x, y)
		local vector = { x = x, y = y }
		function vector:GetXY()
			return self.x, self.y
		end
		function vector:SetXY(newX, newY)
			self.x, self.y = newX, newY
		end
		return vector
	end
	_G.CreateVector2D = vector2

	-- Like real C_ functions, a nil or non-number uiMapID is a Lua error, not a nil return.
	local function checkMapId(apiName, uiMapID)
		if type(uiMapID) ~= "number" then
			error(
				"bad argument #1 to '"
					.. apiName
					.. "' (outgoing value type: number expected, got "
					.. type(uiMapID)
					.. ")",
				3
			)
		end
	end

	_G.C_Map = {
		-- Inside an instance the player has the instance's own uiMapID but no map position.
		GetBestMapForUnit = function(unit)
			if not isPlayer(unit) then
				return nil
			end
			if world.position then
				return world.position.mapId
			end
			return world.instanceMapId
		end,
		-- Only the player's current map has a position; any other map returns nil.
		GetPlayerMapPosition = function(uiMapID, unit)
			checkMapId("GetPlayerMapPosition", uiMapID)
			local position = world.position
			if isPlayer(unit) and position and position.mapId == uiMapID then
				return vector2(position.x / 100, position.y / 100)
			end
		end,
		GetWorldPosFromMapPos = function(uiMapID, mapPosition)
			checkMapId("GetWorldPosFromMapPos", uiMapID)
			local rect = world.maps[uiMapID]
			if not rect or not mapPosition then
				return nil
			end
			local worldX = rect.top - mapPosition.y * rect.height
			local worldY = rect.left - mapPosition.x * rect.width
			return rect.continent, vector2(worldX, worldY)
		end,
	}

	_G.GetPlayerFacing = function()
		return world.position and world.position.facing or nil
	end

	-- x and y are map percentages (0-100). The facing is kept, or 0 when coming out of an instance.
	function client.moveTo(mapId, x, y)
		local facing = world.position and world.position.facing or 0
		world.position = { mapId = mapId, x = x, y = y, facing = facing }
		world.instanceMapId = nil
	end

	function client.face(radians)
		assert(world.position, "cannot face inside an instance")
		world.position.facing = radians % (2 * math.pi)
	end

	-- Inside an instance GetBestMapForUnit keeps a uiMapID; map position and facing are nil.
	function client.enterInstance(mapId)
		world.position = nil
		world.instanceMapId = mapId or WowMock.DEFAULT_INSTANCE_MAP
	end

	------------------------------------------------------------------------------------------------
	-- Time: OnUpdate and C_Timer
	------------------------------------------------------------------------------------------------

	-- The clock runs in integer milliseconds to avoid float drift; one rendered frame lasts FRAME_MS.
	local FRAME_MS = 50
	local clockMs = 0
	local timers = {}
	local timerSerial = 0

	local function toMs(seconds)
		return math.floor((seconds or 0) * 1000 + 0.5)
	end

	local function addTimer(seconds, callback, iterations, ticker)
		timerSerial = timerSerial + 1
		local timer = {
			serial = timerSerial,
			interval = math.max(toMs(seconds), 0),
			callback = callback,
			remaining = iterations,
			handle = ticker,
		}
		timer.due = clockMs + timer.interval
		timers[#timers + 1] = timer
		return timer
	end

	local function newTickerHandle()
		local handle = { cancelled = false }
		function handle:Cancel()
			self.cancelled = true
		end
		function handle:IsCancelled()
			return self.cancelled
		end
		return handle
	end

	_G.C_Timer = {
		After = function(seconds, callback)
			addTimer(seconds, callback, 1, nil)
		end,
		NewTicker = function(seconds, callback, iterations)
			local handle = newTickerHandle()
			addTimer(seconds, callback, iterations, handle)
			return handle
		end,
	}

	local function runTimers()
		local due = {}
		for _, timer in ipairs(timers) do
			if timer.due <= clockMs then
				due[#due + 1] = timer
			end
		end
		table.sort(due, function(a, b)
			if a.due ~= b.due then
				return a.due < b.due
			end
			return a.serial < b.serial
		end)
		for _, timer in ipairs(due) do
			local cancelled = timer.handle and timer.handle.cancelled
			if not cancelled then
				if timer.handle then
					timer.callback(timer.handle)
				else
					timer.callback()
				end
			end
			if timer.remaining then
				timer.remaining = timer.remaining - 1
			end
			local finished = (timer.handle and timer.handle.cancelled) or (timer.remaining and timer.remaining <= 0)
			if finished then
				timer.done = true
			else
				timer.due = timer.due + math.max(timer.interval, 1)
				if timer.due <= clockMs then
					timer.due = clockMs + math.max(timer.interval, 1)
				end
			end
		end
		local pending = {}
		for _, timer in ipairs(timers) do
			if not timer.done then
				pending[#pending + 1] = timer
			end
		end
		timers = pending
	end

	-- Advances the game clock frame by frame: due timers fire, then OnUpdate runs on every visible frame.
	function client.advance(seconds)
		local remaining = toMs(seconds)
		while remaining > 0 do
			local step = math.min(FRAME_MS, remaining)
			remaining = remaining - step
			clockMs = clockMs + step
			runTimers()
			for _, frame in ipairs(client.frames) do
				local handler = frame.scripts.OnUpdate
				if handler and frame:IsVisible() then
					handler(frame, step / 1000)
				end
			end
		end
	end

	------------------------------------------------------------------------------------------------
	-- Inspection helpers (what the player sees and does)
	------------------------------------------------------------------------------------------------

	local function isFontString(object)
		return object.kind == "FontString"
	end

	-- Text as the player reads it, or nil when nothing would be displayed.
	local function displayedText(object)
		if object.text == nil then
			return nil
		end
		local text = stripEscapes(object.text)
		if text == "" then
			return nil
		end
		return text
	end

	-- Texts of every visible font string and button, in creation order, with escape codes removed.
	-- Empty texts are not shown. A button's own label (GetFontString) is reported once, as the button.
	function client.visibleTexts()
		local texts = {}
		for _, object in ipairs(client.objects) do
			if (isFontString(object) and not object.buttonLabel) or object.isButton then
				local text = displayedText(object)
				if text and object:IsVisible() then
					texts[#texts + 1] = text
				end
			end
		end
		return texts
	end

	-- Clicks the visible, enabled button whose displayed text (escapes removed) is `label`.
	-- Errors when there is none.
	function client.click(label)
		for _, object in ipairs(client.objects) do
			if object.isButton and displayedText(object) == label and object:IsVisible() and object.enabled then
				local handler = object.scripts.OnClick
				if handler then
					handler(object, "LeftButton", false)
				end
				return
			end
		end
		error("no visible button labelled " .. tostring(label), 2)
	end

	-- The arrow is the first visible texture whose rotation was set. `rotation` is normalized to
	-- [-pi, pi). `label` is the visible, non-empty font string with the SAME parent frame as the
	-- texture; with several, the first created after the texture (else the first one).
	function client.arrow()
		for _, object in ipairs(client.objects) do
			if object.kind == "Texture" and object.rotation ~= nil and object:IsVisible() then
				local label, before
				for _, other in ipairs(client.objects) do
					local text = isFontString(other) and other.parent == object.parent and displayedText(other)
					if text and other:IsVisible() then
						if other.serial > object.serial then
							label = text
							break
						end
						before = before or text
					end
				end
				return { shown = true, rotation = normalizeAngle(object.rotation), label = label or before }
			end
		end
		return { shown = false }
	end

	-- Frames the player can drag: SetMovable(true) and EnableMouse(true), in creation order.
	function client.movableFrames()
		local movable = {}
		for _, frame in ipairs(client.frames) do
			if frame.movable and frame.mouseEnabled then
				movable[#movable + 1] = frame
			end
		end
		return movable
	end

	-- Drags the frameIndex-th draggable frame: OnDragStart, the frame lands at the given SetPoint
	-- anchor if it is moving, then OnDragStop. Returns the frame so tests can read GetPoint().
	function client.drag(frameIndex, ...)
		local frame = client.movableFrames()[frameIndex]
		assert(frame, "no movable, mouse-enabled frame #" .. tostring(frameIndex))
		assert(frame:IsVisible(), "movable frame #" .. tostring(frameIndex) .. " is not visible")
		if frame.dragButtons and frame.scripts.OnDragStart then
			frame.scripts.OnDragStart(frame, "LeftButton")
		end
		if frame.moving then
			frame:ClearAllPoints()
			frame:SetPoint(...)
		end
		if frame.scripts.OnDragStop then
			frame.scripts.OnDragStop(frame)
		end
		return frame
	end

	return client
end

return WowMock
