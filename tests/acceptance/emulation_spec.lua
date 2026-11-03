-- Self-tests of the WoW client emulation (tests/support), so engine tests can rely on it.
local Client = require("support.client")

local function routeCount()
	local pipe = assert(io.popen("find data/routes -name '*.json' | wc -l"))
	local count = tonumber(pipe:read("*a"):match("%d+"))
	pipe:close()
	return count
end

-- Records every event a test frame receives, with its arguments.
local function recordEvents(...)
	local log = {}
	local frame = CreateFrame("Frame")
	for i = 1, select("#", ...) do
		frame:RegisterEvent((select(i, ...)))
	end
	frame:SetScript("OnEvent", function(_, event, ...)
		log[#log + 1] = { event, ... }
	end)
	return log
end

local function fixtureRoute(id)
	return {
		id = id,
		faction = "Horde",
		minLevel = 1,
		maxLevel = 10,
		name = { enUS = "Fixture " .. id },
		steps = { { type = "note", text = { enUS = "Hello" } } },
	}
end

local function lastMessage(client)
	local messages = client.messages()
	return messages[#messages]
end

describe("Client emulation (acceptance)", function()
	after_each(function()
		Client.shutdown()
	end)

	describe("player", function()
		it("defaults to an Undead warrior level 1 on the Horde", function()
			Client.boot()
			assert.are.same({ "Tester" }, { UnitName("player") })
			assert.are.equal("Realm", GetRealmName())
			assert.are.equal("Horde", (UnitFactionGroup("player")))
			assert.are.same({ "Undead", "Scourge", 5 }, { UnitRace("player") })
			assert.are.same({ "Warrior", "WARRIOR", 1 }, { UnitClass("player") })
			assert.are.equal(1, UnitLevel("player"))
		end)

		it("uses the player options", function()
			Client.boot({
				player = {
					name = "Alt",
					realm = "Other",
					faction = "Alliance",
					race = "Human",
					class = "MAGE",
					level = 7,
				},
			})
			assert.are.equal("Alt", (UnitName("player")))
			assert.are.equal("Other", GetRealmName())
			assert.are.equal("Alliance", (UnitFactionGroup("player")))
			assert.are.equal("Human", select(2, UnitRace("player")))
			assert.are.equal("MAGE", select(2, UnitClass("player")))
			assert.are.equal(7, UnitLevel("player"))
		end)

		it("fires PLAYER_LEVEL_UP with the new level", function()
			local client = Client.boot()
			local log = recordEvents("PLAYER_LEVEL_UP")
			client.levelUp(2)
			assert.are.same({ { "PLAYER_LEVEL_UP", 2 } }, log)
			assert.are.equal(2, UnitLevel("player"))
		end)
	end)

	describe("quests", function()
		it("starts from the quest options; ready quests are in the log", function()
			Client.boot({ quests = { completed = { 1 }, log = { 2 }, ready = { 3 }, titles = { [2] = "Two" } } })
			assert.is_true(C_QuestLog.IsQuestFlaggedCompleted(1))
			assert.is_false(C_QuestLog.IsQuestFlaggedCompleted(2))
			assert.is_true(C_QuestLog.IsOnQuest(2))
			assert.is_false(C_QuestLog.ReadyForTurnIn(2))
			assert.is_true(C_QuestLog.IsOnQuest(3))
			assert.is_true(C_QuestLog.ReadyForTurnIn(3))
			assert.are.equal("Two", C_QuestLog.GetTitleForQuestID(2))
		end)

		it("acceptQuest adds the quest and fires QUEST_ACCEPTED(id), QUEST_LOG_UPDATE", function()
			local client = Client.boot()
			local log = recordEvents("QUEST_ACCEPTED", "QUEST_LOG_UPDATE")
			client.acceptQuest(10)
			assert.are.same({ { "QUEST_ACCEPTED", 10 }, { "QUEST_LOG_UPDATE" } }, log)
			assert.is_true(C_QuestLog.IsOnQuest(10))
			assert.is_false(C_QuestLog.ReadyForTurnIn(10))
		end)

		it("completeObjectives marks the quest ready and fires QUEST_LOG_UPDATE", function()
			local client = Client.boot({ quests = { log = { 10 } } })
			local log = recordEvents("QUEST_ACCEPTED", "QUEST_LOG_UPDATE")
			client.completeObjectives(10)
			assert.are.same({ { "QUEST_LOG_UPDATE" } }, log)
			assert.is_true(C_QuestLog.ReadyForTurnIn(10))
		end)

		it("turnInQuest fires QUEST_TURNED_IN, QUEST_REMOVED, QUEST_LOG_UPDATE", function()
			local client = Client.boot({ quests = { ready = { 10 } } })
			local log = recordEvents("QUEST_TURNED_IN", "QUEST_REMOVED", "QUEST_LOG_UPDATE")
			client.turnInQuest(10)
			assert.are.same({
				{ "QUEST_TURNED_IN", 10, 0, 0 },
				{ "QUEST_REMOVED", 10, false },
				{ "QUEST_LOG_UPDATE" },
			}, log)
			assert.is_false(C_QuestLog.IsOnQuest(10))
			assert.is_false(C_QuestLog.ReadyForTurnIn(10))
			assert.is_true(C_QuestLog.IsQuestFlaggedCompleted(10))
		end)

		it("rejects impossible quest actions", function()
			local client = Client.boot({ quests = { completed = { 1 }, log = { 2 } } })
			assert.has_error(function()
				client.acceptQuest(1)
			end)
			assert.has_error(function()
				client.acceptQuest(2)
			end)
			assert.has_error(function()
				client.completeObjectives(3)
			end)
			assert.has_error(function()
				client.turnInQuest(3)
			end)
		end)

		it("has no title until loadQuestData fires QUEST_DATA_LOAD_RESULT(id, true)", function()
			local client = Client.boot()
			local log = recordEvents("QUEST_DATA_LOAD_RESULT")
			assert.is_nil(C_QuestLog.GetTitleForQuestID(42))
			C_QuestLog.RequestLoadQuestByID(42)
			assert.is_nil(C_QuestLog.GetTitleForQuestID(42))
			client.loadQuestData(42)
			assert.are.same({ { "QUEST_DATA_LOAD_RESULT", 42, true } }, log)
			assert.are.equal("Quest Title 42", C_QuestLog.GetTitleForQuestID(42))
		end)
	end)

	describe("map and position", function()
		it("returns the player map position as a 0-1 vector2", function()
			Client.boot({ position = { mapId = 1420, x = 50, y = 25 } })
			assert.are.equal(1420, C_Map.GetBestMapForUnit("player"))
			local position = C_Map.GetPlayerMapPosition(1420, "player")
			local x, y = position:GetXY()
			assert.are.near(0.5, x, 1e-9)
			assert.are.near(0.25, y, 1e-9)
			assert.is_nil(C_Map.GetPlayerMapPosition(1421, "player"))
		end)

		it("has no position nor facing in an instance", function()
			local client = Client.boot({ position = { mapId = 1420, x = 50, y = 25, facing = 1 } })
			assert.are.equal(1, GetPlayerFacing())
			client.enterInstance()
			assert.is_nil(C_Map.GetBestMapForUnit("player"))
			assert.is_nil(C_Map.GetPlayerMapPosition(1420, "player"))
			assert.is_nil(GetPlayerFacing())
		end)

		it("starts in an instance when no position is given", function()
			Client.boot()
			assert.is_nil(C_Map.GetBestMapForUnit("player"))
			assert.is_nil(GetPlayerFacing())
		end)

		it("moves and faces the player", function()
			local client = Client.boot()
			client.moveTo(1421, 40, 60)
			assert.are.equal(1421, C_Map.GetBestMapForUnit("player"))
			assert.are.near(0.4, (C_Map.GetPlayerMapPosition(1421, "player"):GetXY()), 1e-9)
			assert.are.equal(0, GetPlayerFacing())
			client.face(math.pi / 2)
			assert.are.near(math.pi / 2, GetPlayerFacing(), 1e-9)
			client.moveTo(1421, 41, 60)
			assert.are.near(math.pi / 2, GetPlayerFacing(), 1e-9)
		end)

		it("puts both default maps on the same continent", function()
			Client.boot()
			local tirisfal = C_Map.GetWorldPosFromMapPos(1420, CreateVector2D(0.5, 0.5))
			local silverpine = C_Map.GetWorldPosFromMapPos(1421, CreateVector2D(0.5, 0.5))
			assert.are.equal(0, tirisfal)
			assert.are.equal(tirisfal, silverpine)
			assert.is_nil(C_Map.GetWorldPosFromMapPos(9999, CreateVector2D(0.5, 0.5)))
		end)

		it("converts map positions to world yards: X grows north, Y grows west", function()
			Client.boot({ maps = { [7] = { continent = 1, left = 1000, top = 2000, width = 400, height = 200 } } })
			local continent, origin = C_Map.GetWorldPosFromMapPos(7, CreateVector2D(0, 0))
			assert.are.equal(1, continent)
			assert.are.same({ 2000, 1000 }, { origin:GetXY() })
			local _, southEast = C_Map.GetWorldPosFromMapPos(7, CreateVector2D(1, 1))
			assert.are.same({ 1800, 600 }, { southEast:GetXY() })
			-- 10% of the map width east is 40 yards.
			local _, a = C_Map.GetWorldPosFromMapPos(7, CreateVector2D(0.5, 0.5))
			local _, b = C_Map.GetWorldPosFromMapPos(7, CreateVector2D(0.6, 0.5))
			local ax, ay = a:GetXY()
			local bx, by = b:GetXY()
			assert.are.near(40, math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2), 1e-9)
		end)

		it("lets bearings be derived counterclockwise from north, like GetPlayerFacing", function()
			Client.boot()
			local function bearing(fromX, fromY, toX, toY)
				local _, from = C_Map.GetWorldPosFromMapPos(1420, CreateVector2D(fromX, fromY))
				local _, to = C_Map.GetWorldPosFromMapPos(1420, CreateVector2D(toX, toY))
				local px, py = from:GetXY()
				local tx, ty = to:GetXY()
				return math.atan2(ty - py, tx - px)
			end
			assert.are.near(0, bearing(0.5, 0.5, 0.5, 0.4), 1e-9) -- north
			assert.are.near(math.pi / 2, bearing(0.5, 0.5, 0.4, 0.5), 1e-9) -- west
			assert.are.near(-math.pi / 2, bearing(0.5, 0.5, 0.6, 0.5), 1e-9) -- east
		end)
	end)

	describe("time", function()
		it("fires C_Timer.After once, when due", function()
			local client = Client.boot()
			local calls = 0
			C_Timer.After(0.5, function()
				calls = calls + 1
			end)
			client.advance(0.4)
			assert.are.equal(0, calls)
			client.advance(0.1)
			assert.are.equal(1, calls)
			client.advance(2)
			assert.are.equal(1, calls)
		end)

		it("repeats C_Timer.NewTicker until cancelled or out of iterations", function()
			local client = Client.boot()
			local ticks, limited = 0, 0
			local ticker = C_Timer.NewTicker(0.2, function()
				ticks = ticks + 1
			end)
			C_Timer.NewTicker(0.1, function()
				limited = limited + 1
			end, 3)
			client.advance(1)
			assert.are.equal(5, ticks)
			assert.are.equal(3, limited)
			ticker:Cancel()
			client.advance(1)
			assert.are.equal(5, ticks)
		end)

		it("runs OnUpdate with the elapsed time on visible frames only", function()
			local client = Client.boot()
			local total, hiddenCalls = 0, 0
			local frame = CreateFrame("Frame")
			frame:SetScript("OnUpdate", function(_, elapsed)
				total = total + elapsed
			end)
			local parent = CreateFrame("Frame")
			local child = CreateFrame("Frame", nil, parent)
			child:SetScript("OnUpdate", function()
				hiddenCalls = hiddenCalls + 1
			end)
			parent:Hide()
			client.advance(1)
			assert.are.near(1, total, 1e-9)
			assert.are.equal(0, hiddenCalls)
		end)
	end)

	describe("reload", function()
		it("keeps LaRutaDel60DB, the player and the quests, and logs in again", function()
			local client = Client.boot({ position = { mapId = 1420, x = 10, y = 20 } })
			client.login()
			LaRutaDel60DB.step = 3
			client.acceptQuest(5)
			client.levelUp(4)
			client.reload()
			assert.are.equal(3, LaRutaDel60DB.step)
			assert.is_true(C_QuestLog.IsOnQuest(5))
			assert.are.equal(4, UnitLevel("player"))
			assert.are.equal(1420, C_Map.GetBestMapForUnit("player"))
			assert.are.same({ "La Ruta del 60: Loaded. Type /ruta for info." }, client.messages())
		end)

		it("restores a copy of the saved variables, like the client does", function()
			local client = Client.boot()
			client.login()
			local before = LaRutaDel60DB
			LaRutaDel60DB.callback = function() end
			client.reload()
			assert.are_not.equal(before, LaRutaDel60DB)
			assert.is_nil(LaRutaDel60DB.callback)
		end)
	end)

	describe("fixture guides", function()
		it("registers them after the addon's own guides", function()
			local client = Client.boot({ guides = { fixtureRoute("fixture-a"), fixtureRoute("fixture-b") } })
			client.login()
			client.slash("/ruta")
			assert.matches(" %- " .. (routeCount() + 2) .. " guide%(s%) loaded%.$", lastMessage(client))
		end)

		it("replaces the addon's guides with replaceGuides", function()
			local client = Client.boot({ guides = { fixtureRoute("fixture-a") }, replaceGuides = true })
			client.login()
			client.slash("/ruta")
			assert.matches(" %- 1 guide%(s%) loaded%.$", lastMessage(client))
		end)
	end)

	describe("frames", function()
		it("lists visible font strings and button labels in creation order", function()
			local client = Client.boot()
			local window = CreateFrame("Frame", nil, UIParent)
			local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			title:SetText("Title")
			local button = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
			button:SetText("Skip")
			local hidden = window:CreateFontString()
			hidden:SetText("Hidden")
			hidden:Hide()
			local other = CreateFrame("Frame", nil, UIParent)
			other:CreateFontString():SetText("Inside hidden parent")
			other:Hide()
			assert.are.same({ "Title", "Skip" }, client.visibleTexts())
			window:Hide()
			assert.are.same({}, client.visibleTexts())
		end)

		it("keeps IsShown as the own flag and IsVisible through the parents", function()
			Client.boot()
			local parent = CreateFrame("Frame")
			local child = CreateFrame("Frame", nil, parent)
			parent:Hide()
			assert.is_true(child:IsShown())
			assert.is_false(child:IsVisible())
		end)

		it("clicks the visible button with that label", function()
			local client = Client.boot()
			local clicks = 0
			local button = CreateFrame("Button", nil, UIParent)
			button:SetText("Done")
			button:SetScript("OnClick", function()
				clicks = clicks + 1
			end)
			client.click("Done")
			assert.are.equal(1, clicks)
			assert.has_error(function()
				client.click("Nope")
			end)
			button:Hide()
			assert.has_error(function()
				client.click("Done")
			end)
		end)

		it("rejects OnClick on plain frames", function()
			Client.boot()
			assert.has_error(function()
				CreateFrame("Frame"):SetScript("OnClick", function() end)
			end)
		end)

		it("reports the rotated texture and its label as the arrow", function()
			local client = Client.boot()
			assert.are.same({ shown = false }, client.arrow())
			local arrowFrame = CreateFrame("Frame", nil, UIParent)
			local texture = arrowFrame:CreateTexture(nil, "ARTWORK")
			local label = arrowFrame:CreateFontString()
			texture:SetRotation(math.pi / 2)
			label:SetText("42 yd")
			assert.are.same({ shown = true, rotation = math.pi / 2, label = "42 yd" }, client.arrow())
			texture:SetRotation(5 * math.pi / 2)
			assert.are.near(math.pi / 2, client.arrow().rotation, 1e-9)
			arrowFrame:Hide()
			assert.are.same({ shown = false }, client.arrow())
		end)

		it("drags a movable frame to a new anchor", function()
			local client = Client.boot()
			local window = CreateFrame("Frame", nil, UIParent)
			window:SetPoint("CENTER")
			window:SetMovable(true)
			window:EnableMouse(true)
			window:RegisterForDrag("LeftButton")
			local saved
			window:SetScript("OnDragStart", window.StartMoving)
			window:SetScript("OnDragStop", function(self)
				self:StopMovingOrSizing()
				saved = { self:GetPoint() }
			end)
			assert.are.same({ "CENTER", UIParent, "CENTER", 0, 0 }, { window:GetPoint() })
			client.drag(1, "TOPLEFT", UIParent, "TOPLEFT", 100, -50)
			assert.are.same({ "TOPLEFT", UIParent, "TOPLEFT", 100, -50 }, saved)
		end)

		it("still makes named frames globals", function()
			Client.boot()
			local frame = CreateFrame("Frame", "EmulationNamedFrame")
			assert.are.equal(frame, _G.EmulationNamedFrame)
		end)
	end)
end)
