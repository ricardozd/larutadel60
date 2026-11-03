-- Guide engine: waypoint arrow (spec §3.4 and §5 "Arrow").
--
-- Geometry (Fx.MAPS): on every map 1% of x or y is 10 yards; map x grows east and map y grows south.
-- 1421 lies right south of 1420 on the same continent; 1411 is on another continent.
-- Facing and bearings are radians counterclockwise from north, so west is +pi/2 and east is -pi/2.
local Client = require("support.client")
local WowMock = require("support.wow_mock")
local Fx = require("support.fixtures")

local TOLERANCE = 1e-3
local PLAYER = { mapId = 1420, x = 50, y = 50, facing = 0 }

local function assertRotation(expected, arrow)
	assert.is_true(arrow.shown, "arrow must be shown")
	assert.is_number(arrow.rotation)
	local difference = WowMock.normalizeAngle(arrow.rotation - expected)
	assert.is_true(
		math.abs(difference) < TOLERANCE,
		string.format("rotation %.4f, expected %.4f", arrow.rotation, expected)
	)
end

local function gotoStep(mapId, x, y)
	return { type = "goto", coords = { mapId = mapId, x = x, y = y } }
end

-- Boots a route made of `steps` with the player at `position` (default PLAYER), logs in and lets the arrow update.
local function bootArrow(steps, opts)
	opts = opts or {}
	opts.guides = { Fx.route("fx-arrow", steps) }
	opts.position = opts.position == nil and Fx.copy(PLAYER) or opts.position
	local client = Fx.boot(opts)
	client.login()
	client.advance(0.5)
	return client
end

describe("Guide engine: arrow (acceptance)", function()
	after_each(function()
		Client.shutdown()
	end)

	it("is shown with the distance label when the target is on the same continent", function()
		-- Target 10% north: 100 yards straight ahead.
		local client = bootArrow({ gotoStep(1420, 50, 40), Fx.note("After") })
		local arrow = client.arrow()
		assert.is_true(arrow.shown)
		assert.are.equal("100 yd", arrow.label)
	end)

	it("points up (rotation 0) when facing the target", function()
		local client = bootArrow({ gotoStep(1420, 50, 40) })
		assertRotation(0, client.arrow())
	end)

	it("has rotation pi/2 when the target is 90 degrees to the left", function()
		-- Facing north, the target is 100 yards west.
		local client = bootArrow({ gotoStep(1420, 40, 50) })
		assertRotation(math.pi / 2, client.arrow())
		assert.are.equal("100 yd", client.arrow().label)
	end)

	it("uses bearing minus facing", function()
		-- Facing west: a target to the north is 90 degrees to the right, a target to the west is ahead.
		local client = bootArrow({ gotoStep(1420, 50, 40), gotoStep(1420, 40, 50) }, {
			position = { mapId = 1420, x = 50, y = 50, facing = math.pi / 2 },
		})
		assertRotation(-math.pi / 2, client.arrow())
		client.click("Skip")
		client.advance(0.5)
		assertRotation(0, client.arrow())
	end)

	it("follows the player as they move and turn", function()
		local client = bootArrow({ gotoStep(1420, 50, 40) })
		assert.are.equal("100 yd", client.arrow().label)
		client.moveTo(1420, 50, 45)
		client.advance(0.5)
		assert.are.equal("50 yd", client.arrow().label)
		-- Target east of the player, player facing north: 90 degrees to the right.
		client.moveTo(1420, 45, 40)
		client.advance(0.5)
		assertRotation(-math.pi / 2, client.arrow())
		client.face(-math.pi / 2)
		client.advance(0.5)
		assertRotation(0, client.arrow())
		client.face(math.pi / 2)
		client.advance(0.5)
		assertRotation(math.pi, client.arrow())
	end)

	it("rounds the distance label to an integer", function()
		-- 7.66% north: 76.6 yards.
		local client = bootArrow({ gotoStep(1420, 50, 42.34) })
		assert.are.equal("77 yd", client.arrow().label)
	end)

	it("measures world distance across maps of the same continent", function()
		-- 1421 (50, 10) is 600 yards south of 1420 (50, 50). Facing west, south is 90 degrees to the left.
		local client = bootArrow({ gotoStep(1421, 50, 10) }, {
			position = { mapId = 1420, x = 50, y = 50, facing = math.pi / 2 },
		})
		assert.are.equal("600 yd", client.arrow().label)
		assertRotation(math.pi / 2, client.arrow())
	end)

	it("points at the coords of quest steps too", function()
		local client = bootArrow({ { type = "accept", questId = 101, coords = { mapId = 1420, x = 60, y = 50 } } })
		assert.are.equal("100 yd", client.arrow().label)
		assertRotation(-math.pi / 2, client.arrow())
	end)

	it("is hidden for steps without coordinates", function()
		local client = bootArrow({
			gotoStep(1420, 50, 40),
			Fx.note("No coords here"),
			{ type = "accept", questId = 101 },
		})
		assert.is_true(client.arrow().shown)
		client.click("Skip")
		client.advance(0.5)
		assert.is_false(client.arrow().shown)
		client.click("Done")
		client.advance(0.5)
		assert.is_true(Fx.shows(client, "Accept: First Quest"))
		assert.is_false(client.arrow().shown)
	end)

	it("is hidden inside an instance and comes back outside", function()
		local client = bootArrow({ gotoStep(1420, 50, 40) })
		assert.is_true(client.arrow().shown)
		client.enterInstance(Client.INSTANCE_MAP)
		client.advance(0.5)
		assert.is_false(client.arrow().shown)
		client.moveTo(1420, 50, 50)
		client.advance(1)
		assert.is_true(client.arrow().shown)
		assert.are.equal("100 yd", client.arrow().label)
	end)

	it("is hidden when logging in inside an instance", function()
		local client = bootArrow({ gotoStep(1420, 50, 40) }, { position = false })
		assert.is_true(Fx.shows(client, "Go to 50.0, 40.0"))
		assert.is_false(client.arrow().shown)
	end)

	it("is hidden when the target is on another continent", function()
		local client = bootArrow({ gotoStep(1420, 50, 40), gotoStep(1411, 50, 40) })
		assert.is_true(client.arrow().shown)
		client.click("Skip")
		client.advance(0.5)
		assert.is_true(Fx.shows(client, "Go to 50.0, 40.0"))
		assert.is_false(client.arrow().shown)
	end)

	it("is hidden when the player goes to another continent", function()
		local client = bootArrow({ gotoStep(1420, 50, 40) })
		assert.is_true(client.arrow().shown)
		client.moveTo(1411, 50, 50)
		client.advance(1)
		assert.is_false(client.arrow().shown)
	end)
end)
