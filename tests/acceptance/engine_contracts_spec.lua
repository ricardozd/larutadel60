-- Guide engine: remaining contracts (spec §3.1, §3.2 edge cases, §3.3 fallback, §3.5 and §5).
local Client = require("support.client")
local Fx = require("support.fixtures")

local PREFIX = Fx.PREFIX

local QUEST_TEXTS = {
	"Accept: First Quest",
	"Complete: First Quest",
	"Turn in: First Quest",
	"Accept: Silver Quest",
	"Accept: Pine Quest",
	"Turn in: Silver Quest",
}

local function allRoutes()
	return { Fx.tirisfal(), Fx.silverpine(), Fx.alliance(), Fx.orc() }
end

local function bootAll(opts)
	opts = opts or {}
	opts.guides = opts.guides or allRoutes()
	local client = Fx.boot(opts)
	client.login()
	return client
end

local function contains(list, value)
	for _, item in ipairs(list) do
		if item == value then
			return true
		end
	end
	return false
end

describe("Guide engine: remaining contracts (acceptance)", function()
	after_each(function()
		Client.shutdown()
	end)

	describe("commands", function()
		it("runs catch-up after /ruta <id> switches route", function()
			local client = bootAll({ player = { level = 12 }, quests = { log = { 201 } } })
			assert.is_true(Fx.shows(client, Fx.TIRISFAL_NAME.enUS))
			assert.are.same({ PREFIX .. "Route: " .. Fx.SILVERPINE_NAME.enUS }, Fx.slash(client, "/ruta fx-silverpine"))
			assert.is_true(Fx.shows(client, Fx.SILVERPINE_NAME.enUS))
			assert.are.equal("Accept: Pine Quest", Fx.current(client, QUEST_TEXTS))
		end)

		it("treats an existing route that does not match the character as unknown", function()
			local client = bootAll()
			client.acceptQuest(101)
			assert.are.equal("Complete: First Quest", Fx.current(client, QUEST_TEXTS))
			for _, id in ipairs({ "fx-alliance", "fx-orc" }) do
				assert.are.same({ PREFIX .. "Unknown route: " .. id }, Fx.slash(client, "/ruta " .. id))
				assert.is_true(Fx.shows(client, Fx.TIRISFAL_NAME.enUS), id)
				assert.is_false(Fx.shows(client, "Fixture Northshire"), id)
				assert.is_false(Fx.shows(client, "Fixture Valley of Trials"), id)
				assert.are.equal("Complete: First Quest", Fx.current(client, QUEST_TEXTS), id)
			end
			client.reload()
			assert.is_true(Fx.shows(client, Fx.TIRISFAL_NAME.enUS))
			assert.are.equal("Complete: First Quest", Fx.current(client, QUEST_TEXTS))
		end)

		it("treats a non-matching route as unknown in Spanish too", function()
			local client = bootAll({ locale = "esES" })
			assert.are.same({ PREFIX .. "Ruta desconocida: fx-alliance" }, Fx.slash(client, "/ruta fx-alliance"))
			assert.is_true(Fx.shows(client, Fx.TIRISFAL_NAME.esES))
		end)

		it("lists routes ignoring level, but not faction, race or class", function()
			local mage = Fx.notesRoute("fx-mage", 2, { classes = { "MAGE" } })
			local guides = allRoutes()
			guides[#guides + 1] = mage
			local client = bootAll({ player = { level = 1 }, guides = guides })
			assert.is_true(Fx.shows(client, Fx.TIRISFAL_NAME.enUS))
			local lines = Fx.slash(client, "/ruta list")
			assert.is_true(contains(lines, PREFIX .. "fx-tirisfal - " .. Fx.TIRISFAL_NAME.enUS))
			assert.is_true(contains(lines, PREFIX .. "fx-silverpine - " .. Fx.SILVERPINE_NAME.enUS))
			for _, line in ipairs(lines) do
				assert.are.equal(PREFIX, line:sub(1, #PREFIX))
				for _, excluded in ipairs({ "fx-alliance", "fx-orc", "fx-mage" }) do
					assert.is_nil(line:find(excluded, 1, true), line)
				end
			end
		end)

		it("switches to a matching route of another level range from level 1", function()
			local client = bootAll({ player = { level = 1 } })
			assert.are.same({ PREFIX .. "Route: " .. Fx.SILVERPINE_NAME.enUS }, Fx.slash(client, "/ruta fx-silverpine"))
			assert.are.equal("Accept: Silver Quest", Fx.current(client, QUEST_TEXTS))
		end)

		it("accepts both aliases of each subcommand in every locale", function()
			for _, locale in ipairs({ "enUS", "esES" }) do
				local client = bootAll({ locale = locale })
				local title = locale == "enUS" and Fx.TIRISFAL_NAME.enUS or Fx.TIRISFAL_NAME.esES
				for _, command in ipairs({ "/ruta list", "/ruta lista" }) do
					assert.is_true(contains(Fx.slash(client, command), PREFIX .. "fx-tirisfal - " .. title), command)
				end
				for _, pair in ipairs({ { "/ruta hide", "/ruta show" }, { "/ruta ocultar", "/ruta mostrar" } }) do
					client.slash(pair[1])
					assert.is_false(Fx.shows(client, title), locale .. " " .. pair[1])
					client.slash(pair[2])
					assert.is_true(Fx.shows(client, title), locale .. " " .. pair[2])
				end
				local restarted = locale == "enUS" and "Route restarted." or "Ruta reiniciada."
				for _, command in ipairs({ "/ruta reset", "/ruta reiniciar" }) do
					assert.are.same({ PREFIX .. restarted }, Fx.slash(client, command), locale .. " " .. command)
				end
				Client.shutdown()
			end
		end)
	end)

	describe("selection", function()
		it("selects again when the saved route no longer matches the race or faction", function()
			for _, saved in ipairs({ "fx-orc", "fx-alliance" }) do
				local client = bootAll({
					savedVariables = { chars = { ["Tester-Realm"] = { route = saved, step = 2 } } },
				})
				assert.is_true(Fx.shows(client, Fx.TIRISFAL_NAME.enUS), saved)
				assert.are.equal("Accept: First Quest", Fx.current(client, QUEST_TEXTS), saved)
				assert.are.equal("fx-tirisfal", LaRutaDel60DB.chars["Tester-Realm"].route, saved)
				Client.shutdown()
			end
		end)

		it("saves the selected route as progress as soon as it is chosen", function()
			bootAll({ player = { level = 13 } })
			assert.are.equal("fx-silverpine", LaRutaDel60DB.chars["Tester-Realm"].route)
			assert.are.equal(1, LaRutaDel60DB.chars["Tester-Realm"].step)
		end)
	end)

	describe("steps", function()
		it("uses Misión #<id> until the title loads on esES", function()
			local client = Fx.boot({
				locale = "esES",
				guides = { Fx.route("fx-fallback", { { type = "accept", questId = 150 }, Fx.note("End", "Fin") }) },
				quests = { titles = {} },
			})
			client.login()
			local texts = { "Acepta: Misión #150", "Acepta: Quest Title 150", "Fin" }
			assert.are.equal("Acepta: Misión #150", Fx.current(client, texts))
			client.loadQuestData(150)
			client.advance(0.5)
			assert.are.equal("Acepta: Quest Title 150", Fx.current(client, texts))
		end)

		it("advances an accept step on QUEST_ACCEPTED with the quest ID as the last of two arguments", function()
			local client = bootAll()
			assert.are.equal("Accept: First Quest", Fx.current(client, QUEST_TEXTS))
			client.fire("QUEST_ACCEPTED", 5, 101)
			assert.are.equal("Complete: First Quest", Fx.current(client, QUEST_TEXTS))
		end)

		it("does not advance on QUEST_ACCEPTED whose last argument is another quest", function()
			local client = bootAll()
			client.fire("QUEST_ACCEPTED", 101, 999)
			assert.are.equal("Accept: First Quest", Fx.current(client, QUEST_TEXTS))
			assert.is_true(Fx.shows(client, "Skip"))
		end)
	end)

	describe("edge cases", function()
		it("does nothing on Back at step 1", function()
			local client = Fx.boot({ guides = { Fx.notesRoute("fx-notes", 3) } })
			client.login()
			local texts = Fx.noteTexts(3)
			assert.are.equal("Note 1", Fx.current(client, texts))
			client.click("Back")
			assert.are.equal("Note 1", Fx.current(client, texts))
			assert.is_true(Fx.shows(client, "Route fx-notes"))
			client.click("Skip")
			assert.are.equal("Note 2", Fx.current(client, texts))
		end)

		it("auto-skips a satisfied step reached with Skip", function()
			local client = Fx.boot({
				guides = {
					Fx.route("fx-skip-catch-up", {
						Fx.note("Intro"),
						{ type = "accept", questId = 101 },
						Fx.note("After"),
					}),
				},
				quests = { log = { 101 } },
			})
			client.login()
			local texts = { "Intro", "Accept: First Quest", "After" }
			assert.are.equal("Intro", Fx.current(client, texts))
			client.click("Skip")
			assert.are.equal("After", Fx.current(client, texts))
		end)

		it("chains to next on Skip at the last step", function()
			local client = bootAll()
			client.click("Skip")
			client.click("Skip")
			assert.are.equal("Turn in: First Quest", Fx.current(client, QUEST_TEXTS))
			client.click("Skip")
			assert.is_true(Fx.shows(client, Fx.SILVERPINE_NAME.enUS))
			assert.are.equal("Accept: Silver Quest", Fx.current(client, QUEST_TEXTS))
		end)

		it("runs catch-up on the next route after Skip at the last step", function()
			local client = bootAll({ quests = { log = { 201 } } })
			client.click("Skip")
			client.click("Skip")
			client.click("Skip")
			assert.is_true(Fx.shows(client, Fx.SILVERPINE_NAME.enUS))
			assert.are.equal("Accept: Pine Quest", Fx.current(client, QUEST_TEXTS))
		end)

		it("shows route complete on Skip at the last step without next", function()
			local client = Fx.boot({ guides = { Fx.notesRoute("fx-notes", 2) } })
			client.login()
			client.click("Skip")
			assert.are.equal("Note 2", Fx.current(client, Fx.noteTexts(2)))
			client.click("Skip")
			assert.is_true(Fx.shows(client, "Route complete!"))
			assert.is_false(Fx.shows(client, "Note 2"))
		end)

		it("shows only Back on route complete, and Back returns to the last step", function()
			local client = Fx.boot({ guides = { Fx.notesRoute("fx-notes", 2) } })
			client.login()
			client.click("Skip")
			client.click("Done")
			assert.is_true(Fx.shows(client, "Route complete!"))
			assert.is_true(Fx.shows(client, "Back"))
			assert.is_false(Fx.shows(client, "Done"))
			assert.is_false(Fx.shows(client, "Skip"))
			client.click("Back")
			assert.is_false(Fx.shows(client, "Route complete!"))
			assert.are.equal("Note 2", Fx.current(client, Fx.noteTexts(2)))
			assert.is_true(Fx.shows(client, "Done"))
		end)

		it("shows only Atrás on route complete in Spanish", function()
			local client = Fx.boot({ locale = "esES", guides = { Fx.notesRoute("fx-notes", 1) } })
			client.login()
			client.click("Hecho")
			assert.is_true(Fx.shows(client, "¡Ruta completada!"))
			assert.is_true(Fx.shows(client, "Atrás"))
			assert.is_false(Fx.shows(client, "Hecho"))
			assert.is_false(Fx.shows(client, "Saltar"))
			client.click("Atrás")
			assert.are.equal("Nota 1", Fx.current(client, { "Nota 1" }))
		end)
	end)
end)
