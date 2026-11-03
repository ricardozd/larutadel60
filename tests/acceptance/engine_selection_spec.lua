-- Guide engine: automatic route selection (spec §3.1, §3.3 and §5 "Selection").
local Client = require("support.client")
local Fx = require("support.fixtures")

local NO_ROUTE = {
	enUS = "No route available for your character yet.",
	esES = "Todavía no hay ruta para tu personaje.",
}

local function allRoutes()
	return { Fx.tirisfal(), Fx.silverpine(), Fx.alliance(), Fx.orc() }
end

local function bootAs(player, opts)
	opts = opts or {}
	opts.player = player
	opts.guides = opts.guides or allRoutes()
	local client = Fx.boot(opts)
	client.login()
	return client
end

local function assertNoRoute(client, locale)
	assert.is_true(Fx.shows(client, NO_ROUTE[locale]), "no route text missing")
	for _, label in ipairs({ "Back", "Done", "Skip", "Atrás", "Hecho", "Saltar" }) do
		assert.is_false(Fx.shows(client, label), label .. " must not be shown without a route")
	end
	for _, name in ipairs({ Fx.TIRISFAL_NAME, Fx.SILVERPINE_NAME }) do
		assert.is_false(Fx.shows(client, name.enUS))
		assert.is_false(Fx.shows(client, name.esES))
	end
end

describe("Guide engine: route selection (acceptance)", function()
	after_each(function()
		Client.shutdown()
	end)

	it("shows the Tirisfal route name as the title for an Undead level 1", function()
		local client = bootAs({ race = "Scourge", level = 1 })
		assert.is_true(Fx.shows(client, Fx.TIRISFAL_NAME.enUS))
		assert.is_false(Fx.shows(client, Fx.SILVERPINE_NAME.enUS))
		assert.are.equal("Accept: First Quest", Fx.current(client, { "Accept: First Quest", "Accept: Silver Quest" }))
	end)

	it("gives the Silverpine route to an Undead level 13 with no saved progress", function()
		local client = bootAs({ race = "Scourge", level = 13 })
		assert.is_true(Fx.shows(client, Fx.SILVERPINE_NAME.enUS))
		assert.is_false(Fx.shows(client, Fx.TIRISFAL_NAME.enUS))
		assert.are.equal("Accept: Silver Quest", Fx.current(client, { "Accept: First Quest", "Accept: Silver Quest" }))
	end)

	it("shows the no route text, without buttons, to an Undead with no Undead route", function()
		local client = bootAs({ race = "Scourge", level = 1 }, { guides = { Fx.alliance(), Fx.orc() } })
		-- Fx.orc is Horde but Orc-only, so it must not match an Undead.
		assertNoRoute(client, "enUS")
	end)

	it("shows the no route text to an Orc", function()
		local client = bootAs({ race = "Orc", level = 1 }, { guides = { Fx.tirisfal(), Fx.silverpine() } })
		assertNoRoute(client, "enUS")
	end)

	it("shows the no route text to an Alliance character", function()
		local client = bootAs(
			{ faction = "Alliance", race = "Human", level = 1 },
			{ guides = { Fx.tirisfal(), Fx.silverpine(), Fx.orc() } }
		)
		assertNoRoute(client, "enUS")
	end)

	it("shows the no route text in Spanish on esES and esMX", function()
		for _, locale in ipairs({ "esES", "esMX" }) do
			local client = bootAs({ race = "Orc" }, { locale = locale, guides = { Fx.tirisfal(), Fx.silverpine() } })
			assertNoRoute(client, "esES")
			Client.shutdown()
		end
	end)

	it("gives the Orc-only route to an Orc", function()
		local client = bootAs({ race = "Orc", level = 1 })
		assert.is_true(Fx.shows(client, "Fixture Valley of Trials"))
		assert.is_false(Fx.shows(client, NO_ROUTE.enUS))
	end)

	it("matches a route with faction Both", function()
		local both = Fx.notesRoute("fx-both", 2, { faction = "Both", races = { "Human", "Scourge" } })
		local client = bootAs(
			{ faction = "Alliance", race = "Human" },
			{ guides = { both, Fx.tirisfal(), Fx.silverpine() } }
		)
		assert.is_true(Fx.shows(client, "Route fx-both"))
	end)

	it("prefers a route that lists races over one that does not", function()
		-- Alphabetically first and with the same minLevel, so only the races rule can rank it below.
		local generic = Fx.notesRoute("fx-aaa-generic", 2)
		generic.races = nil
		local client = bootAs({ race = "Scourge", level = 1 }, { guides = { generic, Fx.tirisfal(), Fx.silverpine() } })
		assert.is_true(Fx.shows(client, Fx.TIRISFAL_NAME.enUS))
		assert.is_false(Fx.shows(client, "Route fx-aaa-generic"))
	end)

	it("gives a route without races to any race of its faction", function()
		local generic = Fx.notesRoute("fx-generic", 2)
		generic.races = nil
		local client = bootAs({ race = "Troll", level = 1 }, { guides = { generic, Fx.tirisfal(), Fx.silverpine() } })
		assert.is_true(Fx.shows(client, "Route fx-generic"))
	end)

	it("skips routes for other classes and routes outside the level range", function()
		local mage = Fx.notesRoute("fx-aaa-mage", 2, { classes = { "MAGE" } })
		local high = Fx.notesRoute("fx-aaa-high", 2, { minLevel = 30, maxLevel = 40 })
		local client = bootAs(
			{ race = "Scourge", class = "WARRIOR", level = 5 },
			{ guides = { mage, high, Fx.tirisfal(), Fx.silverpine() } }
		)
		assert.is_true(Fx.shows(client, Fx.TIRISFAL_NAME.enUS))
		assert.is_false(Fx.shows(client, "Route fx-aaa-mage"))
		assert.is_false(Fx.shows(client, "Route fx-aaa-high"))
	end)

	it("gives a class route to that class", function()
		local mage = Fx.notesRoute("fx-zzz-mage", 2, { classes = { "MAGE" } })
		local client = bootAs({ race = "Scourge", class = "MAGE", level = 5 }, { guides = { mage } })
		assert.is_true(Fx.shows(client, "Route fx-zzz-mage"))
	end)

	it("breaks ties by the lowest minLevel, then by id", function()
		local late = Fx.notesRoute("fx-aaa-late", 2, { minLevel = 5, maxLevel = 12 })
		local early = Fx.notesRoute("fx-zzz-early", 2, { minLevel = 1, maxLevel = 12 })
		local client = bootAs({ race = "Scourge", level = 6 }, { guides = { late, early } })
		assert.is_true(Fx.shows(client, "Route fx-zzz-early"))
		assert.is_false(Fx.shows(client, "Route fx-aaa-late"))
		Client.shutdown()

		local b = Fx.notesRoute("fx-bbb", 2)
		local a = Fx.notesRoute("fx-aaa", 2)
		client = bootAs({ race = "Scourge", level = 6 }, { guides = { b, a } })
		assert.is_true(Fx.shows(client, "Route fx-aaa"))
		assert.is_false(Fx.shows(client, "Route fx-bbb"))
	end)

	it("keeps the saved route after outleveling it", function()
		local client = bootAs({ race = "Scourge", level = 1 })
		assert.is_true(Fx.shows(client, Fx.TIRISFAL_NAME.enUS))
		client.levelUp(13)
		client.reload()
		assert.is_true(Fx.shows(client, Fx.TIRISFAL_NAME.enUS))
		assert.is_false(Fx.shows(client, Fx.SILVERPINE_NAME.enUS))
	end)

	it("selects again when the saved route no longer exists", function()
		local saved = { chars = { ["Tester-Realm"] = { route = "fx-removed-route", step = 2 } } }
		local client = bootAs({ race = "Scourge", level = 1 }, { savedVariables = saved })
		assert.is_true(Fx.shows(client, Fx.TIRISFAL_NAME.enUS))
		assert.are.equal("Accept: First Quest", Fx.current(client, { "Accept: First Quest", "Complete: First Quest" }))
	end)

	it("uses the esES route name on esES and esMX clients", function()
		for _, locale in ipairs({ "esES", "esMX" }) do
			local client = bootAs({ race = "Scourge", level = 1 }, { locale = locale })
			assert.is_true(Fx.shows(client, Fx.TIRISFAL_NAME.esES), locale)
			assert.is_false(Fx.shows(client, Fx.TIRISFAL_NAME.enUS), locale)
			Client.shutdown()
		end
	end)

	it("falls back to the enUS route name when there is no esES name", function()
		local route = Fx.notesRoute("fx-english-only", 2, { name = { enUS = "English Only Route" } })
		local client = bootAs({ race = "Scourge", level = 1 }, { locale = "esES", guides = { route } })
		assert.is_true(Fx.shows(client, "English Only Route"))
	end)
end)
