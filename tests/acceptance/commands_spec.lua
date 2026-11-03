-- Guide engine: /ruta subcommands (spec §3.5 and §5 "Commands").
local Client = require("support.client")
local Fx = require("support.fixtures")

local PREFIX = Fx.PREFIX

-- Level 12 matches both Undead fixture routes (1-12 and 12-20); selection picks Tirisfal (lowest minLevel).
local function bootCommands(opts)
	opts = opts or {}
	opts.guides = { Fx.tirisfal(), Fx.silverpine(), Fx.alliance(), Fx.orc() }
	opts.player = opts.player or { level = 12 }
	local client = Fx.boot(opts)
	client.login()
	return client
end

local ALL_TEXTS = {
	"Accept: First Quest",
	"Complete: First Quest",
	"Turn in: First Quest",
	"Accept: Silver Quest",
	"Accept: Pine Quest",
	"Turn in: Silver Quest",
	"Acepta: First Quest",
	"Completa: First Quest",
	"Entrega: First Quest",
	"Acepta: Silver Quest",
	"Acepta: Pine Quest",
	"Entrega: Silver Quest",
}

local function current(client)
	return Fx.current(client, ALL_TEXTS)
end

local function contains(list, value)
	for _, item in ipairs(list) do
		if item == value then
			return true
		end
	end
	return false
end

local function versionLine(locale, count)
	if locale == "enUS" then
		return string.format("%sVersion %s - %d guide(s) loaded.", PREFIX, Client.tocField("Version"), count)
	end
	return string.format("%sVersión %s - %d guía(s) cargada(s).", PREFIX, Client.tocField("Version"), count)
end

describe("Guide engine: commands (acceptance)", function()
	after_each(function()
		Client.shutdown()
	end)

	describe("/ruta", function()
		it("still prints only the version line while the engine runs (enUS)", function()
			local client = bootCommands()
			assert.is_true(Fx.shows(client, Fx.TIRISFAL_NAME.enUS))
			assert.are.same({ versionLine("enUS", 4) }, Fx.slash(client, "/ruta"))
		end)

		it("still prints only the version line while the engine runs (esES)", function()
			local client = bootCommands({ locale = "esES" })
			assert.is_true(Fx.shows(client, Fx.TIRISFAL_NAME.esES))
			assert.are.same({ versionLine("esES", 4) }, Fx.slash(client, "/ruta"))
		end)

		it("does not change the step", function()
			local client = bootCommands()
			client.acceptQuest(101)
			Fx.slash(client, "/ruta")
			assert.are.equal("Complete: First Quest", current(client))
		end)
	end)

	describe("/ruta list", function()
		it("lists the routes that match the character, one line each (enUS)", function()
			local client = bootCommands()
			assert.is_true(Fx.shows(client, Fx.TIRISFAL_NAME.enUS))
			local lines = Fx.slash(client, "/ruta list")
			assert.is_true(contains(lines, PREFIX .. "fx-tirisfal - " .. Fx.TIRISFAL_NAME.enUS))
			assert.is_true(contains(lines, PREFIX .. "fx-silverpine - " .. Fx.SILVERPINE_NAME.enUS))
			for _, line in ipairs(lines) do
				assert.is_nil(line:find("fx-alliance", 1, true), line)
				assert.is_nil(line:find("fx-orc", 1, true), line)
			end
		end)

		it("lists the routes with /ruta lista and the esES names (esES)", function()
			local client = bootCommands({ locale = "esES" })
			assert.is_true(Fx.shows(client, Fx.TIRISFAL_NAME.esES))
			local lines = Fx.slash(client, "/ruta lista")
			assert.is_true(contains(lines, PREFIX .. "fx-tirisfal - " .. Fx.TIRISFAL_NAME.esES))
			assert.is_true(contains(lines, PREFIX .. "fx-silverpine - " .. Fx.SILVERPINE_NAME.esES))
			for _, line in ipairs(lines) do
				assert.is_nil(line:find("fx-alliance", 1, true), line)
				assert.is_nil(line:find("fx-orc", 1, true), line)
			end
		end)

		it("does not change the step", function()
			local client = bootCommands()
			client.acceptQuest(101)
			Fx.slash(client, "/ruta list")
			assert.are.equal("Complete: First Quest", current(client))
			assert.is_true(Fx.shows(client, Fx.TIRISFAL_NAME.enUS))
		end)
	end)

	describe("/ruta <id>", function()
		it("switches to that route at step 1 (enUS)", function()
			local client = bootCommands()
			client.acceptQuest(101)
			assert.are.equal("Complete: First Quest", current(client))
			assert.are.same({ PREFIX .. "Route: " .. Fx.SILVERPINE_NAME.enUS }, Fx.slash(client, "/ruta fx-silverpine"))
			assert.is_true(Fx.shows(client, Fx.SILVERPINE_NAME.enUS))
			assert.is_false(Fx.shows(client, Fx.TIRISFAL_NAME.enUS))
			assert.are.equal("Accept: Silver Quest", current(client))
		end)

		it("switches to that route at step 1 (esES)", function()
			local client = bootCommands({ locale = "esES" })
			assert.are.same({ PREFIX .. "Ruta: " .. Fx.SILVERPINE_NAME.esES }, Fx.slash(client, "/ruta fx-silverpine"))
			assert.is_true(Fx.shows(client, Fx.SILVERPINE_NAME.esES))
			assert.are.equal("Acepta: Silver Quest", current(client))
		end)

		it("keeps the chosen route after a reload, over automatic selection", function()
			local client = bootCommands()
			client.slash("/ruta fx-silverpine")
			client.reload()
			assert.is_true(Fx.shows(client, Fx.SILVERPINE_NAME.enUS))
			assert.are.equal("Accept: Silver Quest", current(client))
		end)
	end)

	describe("/ruta <unknown id>", function()
		it("changes nothing and says so (enUS)", function()
			local client = bootCommands()
			client.acceptQuest(101)
			assert.are.same({ PREFIX .. "Unknown route: fx-missing" }, Fx.slash(client, "/ruta fx-missing"))
			assert.is_true(Fx.shows(client, Fx.TIRISFAL_NAME.enUS))
			assert.are.equal("Complete: First Quest", current(client))
			client.reload()
			assert.is_true(Fx.shows(client, Fx.TIRISFAL_NAME.enUS))
			assert.are.equal("Complete: First Quest", current(client))
		end)

		it("changes nothing and says so (esES)", function()
			local client = bootCommands({ locale = "esES" })
			client.acceptQuest(101)
			assert.are.same({ PREFIX .. "Ruta desconocida: fx-missing" }, Fx.slash(client, "/ruta fx-missing"))
			assert.is_true(Fx.shows(client, Fx.TIRISFAL_NAME.esES))
			assert.are.equal("Completa: First Quest", current(client))
		end)
	end)

	describe("/ruta reset", function()
		local NOTES = {
			{ type = "accept", questId = 101 },
			Fx.note("Note A", "Nota A"),
			Fx.note("Note B", "Nota B"),
			Fx.note("Note C", "Nota C"),
		}
		local TEXTS =
			{ "Accept: First Quest", "Note A", "Note B", "Note C", "Acepta: First Quest", "Nota A", "Nota B", "Nota C" }

		local function bootReset(locale)
			local client = Fx.boot({
				locale = locale,
				guides = { Fx.route("fx-reset", Fx.copy(NOTES)) },
				quests = { log = { 101 } },
			})
			client.login()
			return client
		end

		it("goes back to step 1, then catches up (enUS)", function()
			local client = bootReset("enUS")
			assert.are.equal("Note A", Fx.current(client, TEXTS))
			client.click("Skip")
			client.click("Skip")
			assert.are.equal("Note C", Fx.current(client, TEXTS))
			assert.are.same({ PREFIX .. "Route restarted." }, Fx.slash(client, "/ruta reset"))
			assert.are.equal("Note A", Fx.current(client, TEXTS))
		end)

		it("goes back to step 1 with /ruta reiniciar (esES)", function()
			local client = bootReset("esES")
			client.click("Saltar")
			assert.are.equal("Nota B", Fx.current(client, TEXTS))
			assert.are.same({ PREFIX .. "Ruta reiniciada." }, Fx.slash(client, "/ruta reiniciar"))
			assert.are.equal("Nota A", Fx.current(client, TEXTS))
		end)

		it("restarts at step 1 when it is not satisfied", function()
			local client = bootCommands()
			client.click("Skip")
			client.click("Skip")
			assert.are.equal("Turn in: First Quest", current(client))
			Fx.slash(client, "/ruta reset")
			assert.are.equal("Accept: First Quest", current(client))
		end)
	end)

	describe("/ruta hide and /ruta show", function()
		it("hide and show toggle the window without printing anything (enUS)", function()
			local client = bootCommands()
			assert.is_true(Fx.shows(client, Fx.TIRISFAL_NAME.enUS))
			assert.are.same({}, Fx.slash(client, "/ruta hide"))
			assert.is_false(Fx.shows(client, Fx.TIRISFAL_NAME.enUS))
			assert.is_false(Fx.shows(client, "Accept: First Quest"))
			assert.is_false(Fx.shows(client, "Skip"))
			assert.are.same({}, Fx.slash(client, "/ruta show"))
			assert.is_true(Fx.shows(client, Fx.TIRISFAL_NAME.enUS))
			assert.is_true(Fx.shows(client, "Accept: First Quest"))
		end)

		it("ocultar and mostrar toggle the window without printing anything (esES)", function()
			local client = bootCommands({ locale = "esES" })
			assert.is_true(Fx.shows(client, Fx.TIRISFAL_NAME.esES))
			assert.are.same({}, Fx.slash(client, "/ruta ocultar"))
			assert.is_false(Fx.shows(client, Fx.TIRISFAL_NAME.esES))
			assert.are.same({}, Fx.slash(client, "/ruta mostrar"))
			assert.is_true(Fx.shows(client, Fx.TIRISFAL_NAME.esES))
		end)

		it("keeps the engine running while the window is hidden", function()
			local client = bootCommands()
			client.slash("/ruta hide")
			client.acceptQuest(101)
			client.slash("/ruta show")
			assert.are.equal("Complete: First Quest", current(client))
		end)
	end)
end)
