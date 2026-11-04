-- Self-tests of the Classic Era flavor of the client emulation (tests/support), so the Classic Era
-- acceptance tests can rely on it (docs/superpowers/specs/2026-11-04-classic-era-compat-design.md,
-- "Emulation extension").
--
-- These tests install the emulated API directly with WowMock.install({ flavor = "classic_era" }) and
-- do not load the addon, so they do not depend on LaRutaDel60_Vanilla.toc existing. The base TOC is
-- only read for the C_AddOns metadata.
local Client = require("support.client")
local WowMock = require("support.wow_mock")

local function install(flavor, worldOpts, opts)
	Client.shutdown()
	opts = opts or {}
	return WowMock.install({
		locale = "enUS",
		projectId = opts.projectId,
		flavor = flavor,
		addonName = Client.ADDON_NAME,
		tocPath = Client.TOC,
		world = WowMock.newWorld(worldOpts),
	})
end

local function installClassic(worldOpts, opts)
	return install(WowMock.CLASSIC_ERA, worldOpts, opts)
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

-- All returns of GetQuestLogTitle, with nils kept in place.
local function logTitle(index)
	return { n = 8, GetQuestLogTitle(index) }
end

describe("Client emulation: Classic Era flavor (acceptance)", function()
	after_each(function()
		Client.shutdown()
	end)

	describe("boot", function()
		it("loads LaRutaDel60_Vanilla.toc on classic_era and the base TOC otherwise", function()
			assert.are.equal("addon/LaRutaDel60/LaRutaDel60_Vanilla.toc", Client.VANILLA_TOC)
			assert.are.equal(Client.VANILLA_TOC, Client.tocFor("classic_era"))
			assert.are.equal(Client.TOC, Client.tocFor("forever"))
			assert.are.equal(Client.TOC, Client.tocFor(nil))
		end)

		it("rejects an unknown flavor", function()
			assert.has_error(function()
				install("wrath")
			end)
		end)
	end)

	describe("project ID", function()
		it("is WOW_PROJECT_CLASSIC = 2, with no WOW_PROJECT_CAMELOT", function()
			installClassic()
			assert.are.equal(2, WOW_PROJECT_ID)
			assert.are.equal(2, WOW_PROJECT_CLASSIC)
			assert.is_nil(rawget(_G, "WOW_PROJECT_CAMELOT"))
		end)

		it("still honours an explicit projectId", function()
			installClassic(nil, { projectId = 5 })
			assert.are.equal(5, WOW_PROJECT_ID)
			assert.is_nil(rawget(_G, "WOW_PROJECT_CAMELOT"))
		end)
	end)

	describe("removed APIs", function()
		it("has no ReadyForTurnIn, GetTitleForQuestID nor RequestLoadQuestByID", function()
			installClassic()
			assert.is_nil(C_QuestLog.ReadyForTurnIn)
			assert.is_nil(C_QuestLog.GetTitleForQuestID)
			assert.is_nil(C_QuestLog.RequestLoadQuestByID)
		end)

		it("keeps the rest of C_QuestLog", function()
			installClassic({ quests = { completed = { 1 }, log = { 2 } } })
			assert.is_true(C_QuestLog.IsQuestFlaggedCompleted(1))
			assert.is_false(C_QuestLog.IsQuestFlaggedCompleted(2))
			assert.is_true(C_QuestLog.IsOnQuest(2))
			assert.is_false(C_QuestLog.IsOnQuest(1))
		end)

		it("has no client.loadQuestData, so QUEST_DATA_LOAD_RESULT never fires", function()
			local client = installClassic()
			assert.is_nil(client.loadQuestData)
		end)
	end)

	describe("quest log", function()
		it("GetQuestLogIndexByID is the 1-based position in the log, or 0", function()
			installClassic({ quests = { log = { 30, 10 }, ready = { 20 }, completed = { 40 } } })
			assert.are.equal(1, GetQuestLogIndexByID(30))
			assert.are.equal(2, GetQuestLogIndexByID(10))
			assert.are.equal(3, GetQuestLogIndexByID(20))
			assert.are.equal(0, GetQuestLogIndexByID(40))
			assert.are.equal(0, GetQuestLogIndexByID(99))
		end)

		it("GetQuestLogTitle returns title, level, group, header, collapsed, isComplete, frequency, questID", function()
			installClassic({
				player = { level = 4 },
				quests = { log = { 10 }, ready = { 20 }, titles = { [10] = "Ten", [20] = "Twenty" } },
			})
			assert.are.same({ n = 8, "Ten", 4, 0, false, false, nil, 0, 10 }, logTitle(1))
			assert.are.same({ n = 8, "Twenty", 4, 0, false, false, 1, 0, 20 }, logTitle(2))
		end)

		it("GetQuestLogTitle returns nothing past the end of the log", function()
			installClassic({ quests = { log = { 10 } } })
			assert.is_nil((GetQuestLogTitle(2)))
			assert.is_nil((GetQuestLogTitle(0)))
		end)

		it("sets isComplete to 1 only once the quest is ready", function()
			local client = installClassic({ quests = { log = { 10 } } })
			local index = GetQuestLogIndexByID(10)
			assert.is_nil(select(6, GetQuestLogTitle(index)))
			client.completeObjectives(10)
			assert.are.equal(1, select(6, GetQuestLogTitle(index)))
		end)

		it("appends accepted quests and removes turned-in ones", function()
			local client = installClassic({ quests = { log = { 10 } } })
			client.acceptQuest(20)
			client.acceptQuest(30)
			assert.are.equal(2, GetQuestLogIndexByID(20))
			assert.are.equal(3, GetQuestLogIndexByID(30))
			assert.are.equal(30, select(8, GetQuestLogTitle(3)))
			client.completeObjectives(20)
			client.turnInQuest(20)
			assert.are.equal(0, GetQuestLogIndexByID(20))
			assert.are.equal(2, GetQuestLogIndexByID(30))
			assert.are.equal(30, select(8, GetQuestLogTitle(2)))
			assert.is_nil((GetQuestLogTitle(3)))
		end)

		it("keeps the quest log order across a reload", function()
			local world = WowMock.newWorld({ quests = { log = { 10 } } })
			Client.shutdown()
			local client = WowMock.install({
				flavor = WowMock.CLASSIC_ERA,
				addonName = Client.ADDON_NAME,
				tocPath = Client.TOC,
				world = world,
			})
			client.acceptQuest(20)
			Client.shutdown()
			WowMock.install({
				flavor = WowMock.CLASSIC_ERA,
				addonName = Client.ADDON_NAME,
				tocPath = Client.TOC,
				world = world,
			})
			assert.are.equal(1, GetQuestLogIndexByID(10))
			assert.are.equal(2, GetQuestLogIndexByID(20))
		end)
	end)

	describe("titles", function()
		it("C_QuestLog.GetQuestInfo returns the cached title, or nil", function()
			installClassic({ quests = { titles = { [10] = "Ten", [11] = "" } } })
			assert.are.equal("Ten", C_QuestLog.GetQuestInfo(10))
			assert.are.equal("", C_QuestLog.GetQuestInfo(11))
			assert.is_nil(C_QuestLog.GetQuestInfo(12))
		end)
	end)

	describe("events", function()
		it("acceptQuest fires QUEST_ACCEPTED(logIndex, questID), then QUEST_LOG_UPDATE", function()
			local client = installClassic({ quests = { log = { 10 } } })
			local log = recordEvents("QUEST_ACCEPTED", "QUEST_LOG_UPDATE")
			client.acceptQuest(20)
			assert.are.same({ { "QUEST_ACCEPTED", 2, 20 }, { "QUEST_LOG_UPDATE" } }, log)
			assert.is_true(C_QuestLog.IsOnQuest(20))
		end)

		it("completeObjectives and turnInQuest fire the same events as on Forever", function()
			local client = installClassic({ quests = { log = { 10 } } })
			local log = recordEvents("QUEST_TURNED_IN", "QUEST_REMOVED", "QUEST_LOG_UPDATE")
			client.completeObjectives(10)
			client.turnInQuest(10)
			assert.are.same({
				{ "QUEST_LOG_UPDATE" },
				{ "QUEST_TURNED_IN", 10, 0, 0 },
				{ "QUEST_REMOVED", 10, false },
				{ "QUEST_LOG_UPDATE" },
			}, log)
			assert.is_true(C_QuestLog.IsQuestFlaggedCompleted(10))
		end)
	end)

	describe("default flavor", function()
		it("stays forever: the retail-style API, CAMELOT = 18 and QUEST_ACCEPTED(questID)", function()
			local client = install(nil)
			assert.are.equal("forever", client.flavor)
			assert.are.equal(18, WOW_PROJECT_ID)
			assert.are.equal(18, WOW_PROJECT_CAMELOT)
			assert.is_nil(rawget(_G, "WOW_PROJECT_CLASSIC"))
			assert.is_function(C_QuestLog.ReadyForTurnIn)
			assert.is_function(C_QuestLog.GetTitleForQuestID)
			assert.is_function(C_QuestLog.RequestLoadQuestByID)
			assert.is_function(client.loadQuestData)
			assert.is_nil(C_QuestLog.GetQuestInfo)
			assert.is_nil(rawget(_G, "GetQuestLogIndexByID"))
			assert.is_nil(rawget(_G, "GetQuestLogTitle"))
			local log = recordEvents("QUEST_ACCEPTED")
			client.acceptQuest(10)
			assert.are.same({ { "QUEST_ACCEPTED", 10 } }, log)
		end)

		it("Client.boot() without a flavor loads the base TOC with the forever API", function()
			local client = Client.boot()
			assert.are.equal("forever", client.flavor)
			assert.are.equal(18, WOW_PROJECT_CAMELOT)
			assert.is_function(C_QuestLog.ReadyForTurnIn)
		end)
	end)
end)
