-- Self-test of the Classic Era emulation for unknown events (debug-in-game, 2026-11-04): on Classic Era
-- 1.15, Frame:RegisterEvent("QUEST_DATA_LOAD_RESULT") is a Lua error, as observed in game.
local Client = require("support.client")
local WowMock = require("support.wow_mock")

local function install(flavor)
	Client.shutdown()
	return WowMock.install({
		locale = "enUS",
		flavor = flavor,
		addonName = Client.ADDON_NAME,
		tocPath = Client.TOC,
		world = WowMock.newWorld(),
	})
end

describe("Classic Era emulation: unknown events (acceptance)", function()
	after_each(function()
		Client.shutdown()
	end)

	it("errors like the real client when registering QUEST_DATA_LOAD_RESULT on classic_era", function()
		install(WowMock.CLASSIC_ERA)
		local frame = CreateFrame("Frame")
		local ok, err = pcall(frame.RegisterEvent, frame, "QUEST_DATA_LOAD_RESULT")
		assert.is_false(ok)
		assert.matches('Attempt to register unknown event "QUEST_DATA_LOAD_RESULT"', err, 1, true)
		assert.is_false(frame:IsEventRegistered("QUEST_DATA_LOAD_RESULT"))
	end)

	it("still registers events Classic Era has", function()
		install(WowMock.CLASSIC_ERA)
		local frame = CreateFrame("Frame")
		frame:RegisterEvent("QUEST_ACCEPTED")
		assert.is_true(frame:IsEventRegistered("QUEST_ACCEPTED"))
	end)

	it("registers QUEST_DATA_LOAD_RESULT on forever", function()
		install(WowMock.FOREVER)
		local frame = CreateFrame("Frame")
		frame:RegisterEvent("QUEST_DATA_LOAD_RESULT")
		assert.is_true(frame:IsEventRegistered("QUEST_DATA_LOAD_RESULT"))
	end)
end)
