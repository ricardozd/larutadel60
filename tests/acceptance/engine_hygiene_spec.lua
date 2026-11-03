-- Guide engine: no new globals and unchanged login chat (spec §2 and §5 "Hygiene").
local Client = require("support.client")
local Fx = require("support.fixtures")

local PREFIX = Fx.PREFIX
local ALLOWED_GLOBALS = { "LaRutaDel60DB", "SLASH_LARUTADEL601" }

local function bootEngine(opts)
	opts = opts or {}
	opts.guides = { Fx.tirisfal(), Fx.silverpine(), Fx.alliance() }
	local client = Fx.boot(opts)
	client.login()
	return client
end

local function assertOnlyAllowedGlobals(client)
	assert.are.same(ALLOWED_GLOBALS, client.newGlobals())
	assert.are.same({ "LARUTADEL60" }, client.newSlashCommands())
end

describe("Guide engine: hygiene (acceptance)", function()
	after_each(function()
		Client.shutdown()
	end)

	it("creates no new globals after login, actions, commands and reload", function()
		local client = bootEngine({ position = { mapId = 1420, x = 50, y = 60, facing = 0 } })
		assert.is_true(Fx.shows(client, Fx.TIRISFAL_NAME.enUS))
		client.advance(1)
		assertOnlyAllowedGlobals(client)

		-- Quest actions and the arrow.
		client.acceptQuest(101)
		client.completeObjectives(101)
		client.moveTo(1420, 50, 45)
		client.face(1)
		client.advance(1)
		client.enterInstance(Client.INSTANCE_MAP)
		client.advance(1)
		client.moveTo(1420, 50, 50)
		client.loadQuestData(500)
		client.levelUp(2)
		client.advance(1)
		assertOnlyAllowedGlobals(client)

		-- Buttons, chaining and route complete.
		client.click("Back")
		client.click("Skip")
		client.turnInQuest(101)
		assert.is_true(Fx.shows(client, Fx.SILVERPINE_NAME.enUS))
		client.click("Skip")
		client.click("Back")
		client.acceptQuest(201)
		client.acceptQuest(202)
		client.turnInQuest(201)
		assert.is_true(Fx.shows(client, "Route complete!"))
		client.advance(1)
		assertOnlyAllowedGlobals(client)

		-- Every subcommand.
		for _, line in ipairs({
			"/ruta",
			"/ruta list",
			"/ruta lista",
			"/ruta fx-tirisfal",
			"/ruta fx-missing",
			"/ruta reset",
			"/ruta reiniciar",
			"/ruta hide",
			"/ruta ocultar",
			"/ruta show",
			"/ruta mostrar",
		}) do
			client.slash(line)
		end
		client.advance(1)
		assertOnlyAllowedGlobals(client)

		client.reload()
		client.advance(1)
		assertOnlyAllowedGlobals(client)
	end)

	it("creates no new globals when there is no route", function()
		local client = bootEngine({ player = { race = "Orc" } })
		assert.is_true(Fx.shows(client, "No route available for your character yet."))
		client.advance(1)
		client.slash("/ruta list")
		client.slash("/ruta reset")
		client.slash("/ruta hide")
		client.slash("/ruta show")
		client.reload()
		assertOnlyAllowedGlobals(client)
	end)

	it("prints only the greeting on login while the engine runs (enUS)", function()
		-- Catch-up runs at login: 101 is already in the log.
		local client = bootEngine({ quests = { log = { 101 } } })
		client.advance(1)
		assert.is_true(Fx.shows(client, Fx.TIRISFAL_NAME.enUS))
		assert.is_true(Fx.shows(client, "Complete: First Quest"))
		assert.are.same({ PREFIX .. "Loaded. Type /ruta for info." }, client.messages())
	end)

	it("prints only the greeting on login while the engine runs (esES and esMX)", function()
		for _, locale in ipairs({ "esES", "esMX" }) do
			local client = bootEngine({ locale = locale })
			client.advance(1)
			assert.is_true(Fx.shows(client, Fx.TIRISFAL_NAME.esES), locale)
			assert.are.same({ PREFIX .. "Cargado. Escribe /ruta para más info." }, client.messages(), locale)
			Client.shutdown()
		end
	end)

	it("prints only the warning and the greeting outside WoW Forever", function()
		local client = bootEngine({ projectId = 1 })
		client.advance(1)
		assert.is_true(Fx.shows(client, Fx.TIRISFAL_NAME.enUS))
		assert.are.same({
			PREFIX .. "Warning: this client is not WoW Forever; guides may be wrong.",
			PREFIX .. "Loaded. Type /ruta for info.",
		}, client.messages())
	end)

	it("prints only the greeting on login with no route", function()
		local client = bootEngine({ player = { faction = "Alliance", race = "Dwarf" } })
		client.advance(1)
		assert.is_true(Fx.shows(client, "No route available for your character yet."))
		assert.are.same({ PREFIX .. "Loaded. Type /ruta for info." }, client.messages())
	end)

	it("prints only the greeting after a reload and after automatic advances", function()
		local client = bootEngine()
		client.acceptQuest(101)
		client.completeObjectives(101)
		client.turnInQuest(101)
		assert.is_true(Fx.shows(client, Fx.SILVERPINE_NAME.enUS))
		assert.are.same({ PREFIX .. "Loaded. Type /ruta for info." }, client.messages())
		client.reload()
		client.advance(1)
		assert.is_true(Fx.shows(client, Fx.SILVERPINE_NAME.enUS))
		assert.are.same({ PREFIX .. "Loaded. Type /ruta for info." }, client.messages())
	end)
end)
