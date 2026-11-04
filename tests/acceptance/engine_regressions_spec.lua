-- Guide engine: regressions found in review (spec §3.2 Back hold, §3.5 hide/show).
local Client = require("support.client")
local Fx = require("support.fixtures")

local GOTO_TEXT = "Go to 50.0, 50.0"

local function gotoRoute()
	return Fx.route("fx-goto-hold", {
		{ type = "goto", coords = { mapId = 1420, x = 50, y = 50 } },
		Fx.note("After goto"),
		Fx.note("Last"),
	})
end

local TEXTS = { GOTO_TEXT, "After goto", "Last" }

describe("Guide engine: regressions (acceptance)", function()
	after_each(function()
		Client.shutdown()
	end)

	describe("Back onto a reached goto step", function()
		it("stays on the goto step across QUEST_LOG_UPDATE while the player is in the radius", function()
			local client = Fx.boot({ guides = { gotoRoute() } })
			client.login()
			client.moveTo(1420, 50, 50)
			client.advance(0.5)
			assert.are.equal("After goto", Fx.current(client, TEXTS))
			client.click("Back")
			client.advance(0.5)
			assert.are.equal(GOTO_TEXT, Fx.current(client, TEXTS), "held after Back")
			client.fire("QUEST_LOG_UPDATE")
			client.advance(0.5)
			assert.are.equal(GOTO_TEXT, Fx.current(client, TEXTS), "still held after QUEST_LOG_UPDATE")
		end)

		it("advances again once the player leaves the radius and comes back", function()
			local client = Fx.boot({ guides = { gotoRoute() } })
			client.login()
			client.moveTo(1420, 50, 50)
			client.advance(0.5)
			client.click("Back")
			client.advance(0.5)
			assert.are.equal(GOTO_TEXT, Fx.current(client, TEXTS))
			client.moveTo(1420, 50, 60)
			client.fire("QUEST_LOG_UPDATE")
			client.advance(0.5)
			assert.are.equal(GOTO_TEXT, Fx.current(client, TEXTS))
			client.moveTo(1420, 50, 50)
			client.advance(0.5)
			assert.are.equal("After goto", Fx.current(client, TEXTS))
		end)
	end)

	describe("/ruta hide and /ruta show", function()
		local function bootWithArrow(locale)
			local client = Fx.boot({
				locale = locale,
				guides = { Fx.route("fx-arrow-hide", { { type = "goto", coords = { mapId = 1420, x = 50, y = 40 } } }) },
				position = { mapId = 1420, x = 50, y = 50, facing = 0 },
			})
			client.login()
			client.advance(0.5)
			return client
		end

		it("hide hides the arrow too and show restores it", function()
			local client = bootWithArrow("enUS")
			assert.is_true(client.arrow().shown)
			client.slash("/ruta hide")
			client.advance(0.5)
			assert.is_false(client.arrow().shown)
			client.moveTo(1420, 50, 45)
			client.advance(0.5)
			assert.is_false(client.arrow().shown, "stays hidden while the player moves")
			client.slash("/ruta show")
			client.advance(0.5)
			assert.is_true(client.arrow().shown)
			assert.are.equal("50 yd", client.arrow().label)
		end)

		it("ocultar and mostrar hide and restore the arrow on esES", function()
			local client = bootWithArrow("esES")
			client.slash("/ruta ocultar")
			client.advance(0.5)
			assert.is_false(client.arrow().shown)
			client.slash("/ruta mostrar")
			client.advance(0.5)
			assert.is_true(client.arrow().shown)
		end)
	end)

	describe("chaining", function()
		it("terminates on a cycle of satisfied routes", function()
			local a = Fx.route("fx-cycle-a", { { type = "accept", questId = 101 } }, { next = "fx-cycle-b" })
			local b = Fx.route("fx-cycle-b", { { type = "accept", questId = 101 } }, { next = "fx-cycle-a" })
			local client = Fx.boot({ guides = { a, b }, quests = { log = { 101 } } })
			client.login()
			assert.is_true(Fx.shows(client, "Route complete!"))
		end)
	end)
end)
