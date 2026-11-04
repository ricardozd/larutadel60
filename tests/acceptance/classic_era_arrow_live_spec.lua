-- Regression (debug-in-game, 2026-11-04): on Classic Era the arrow was drawn once at login and then
-- froze (distance and rotation never changed), because the engine stopped starting when an event
-- unknown to Classic Era could not be registered. The arrow must keep following the player.
local WowMock = require("support.wow_mock")
local Fx = require("support.fixtures")

local function boot()
	local client = Fx.boot({
		flavor = "classic_era",
		guides = {
			Fx.route("fx-classic-live", {
				{ type = "goto", coords = { mapId = 1420, x = 50, y = 40 } },
				Fx.note("After", "Después"),
			}),
		},
		position = { mapId = 1420, x = 50, y = 50, facing = 0 },
	})
	client.login()
	client.advance(0.5)
	return client
end

describe("Classic Era: the arrow follows the player (acceptance)", function()
	it("updates the distance as the player walks", function()
		local client = boot()
		assert.are.equal("100 yd", client.arrow().label)
		client.moveTo(1420, 50, 45)
		client.advance(0.5)
		assert.are.equal("50 yd", client.arrow().label)
	end)

	it("rotates as the player turns", function()
		local client = boot()
		assert.is_true(math.abs(WowMock.normalizeAngle(client.arrow().rotation)) < 1e-3)
		client.face(math.pi / 2)
		client.advance(0.5)
		assert.is_true(math.abs(WowMock.normalizeAngle(client.arrow().rotation) + math.pi / 2) < 1e-3)
	end)

	it("advances the goto step on arrival", function()
		local client = boot()
		client.moveTo(1420, 50, 40)
		client.advance(0.5)
		assert.is_truthy(table.concat(client.visibleTexts(), "\n"):find("After", 1, true))
	end)
end)
