-- Guide engine: step advance, catch-up, persistence and chaining (spec §3.2 and §5).
local Client = require("support.client")
local Fx = require("support.fixtures")

-- One step of each automatic type, then a goto 1% (10 yards per 1%) away, then a closing note.
local GOTO = { mapId = 1420, x = 50, y = 50 }
local QUEST_ROUTE_STEPS = {
	{ type = "accept", questId = 101 },
	{ type = "complete", questId = 101 },
	{ type = "turnin", questId = 101 },
	{ type = "goto", coords = GOTO },
	Fx.note("Closing note"),
}
local QUEST_ROUTE_TEXTS = {
	"Accept: First Quest",
	"Complete: First Quest",
	"Turn in: First Quest",
	"Go to 50.0, 50.0",
	"Closing note",
}

local function bootQuestRoute(opts)
	opts = opts or {}
	opts.guides = { Fx.route("fx-quests", Fx.copy(QUEST_ROUTE_STEPS)) }
	local client = Fx.boot(opts)
	client.login()
	return client
end

local function current(client)
	return Fx.current(client, QUEST_ROUTE_TEXTS)
end

-- accept 101, accept 102, complete 102, accept 103, turnin 101, turnin 102, turnin 103.
local CATCH_UP_STEPS = {
	{ type = "accept", questId = 101 },
	{ type = "accept", questId = 102 },
	{ type = "complete", questId = 102 },
	{ type = "accept", questId = 103 },
	{ type = "turnin", questId = 101 },
	{ type = "turnin", questId = 102 },
	{ type = "turnin", questId = 103 },
}
local CATCH_UP_TEXTS = {
	"Accept: First Quest",
	"Accept: Second Quest",
	"Complete: Second Quest",
	"Accept: Third Quest",
	"Turn in: First Quest",
	"Turn in: Second Quest",
	"Turn in: Third Quest",
}

local function bootCatchUp(quests)
	local client = Fx.boot({ guides = { Fx.route("fx-catch-up", Fx.copy(CATCH_UP_STEPS)) }, quests = quests })
	client.login()
	return client
end

local CHAIN_TEXTS = {
	"Accept: First Quest",
	"Complete: First Quest",
	"Turn in: First Quest",
	"Accept: Silver Quest",
	"Accept: Pine Quest",
	"Turn in: Silver Quest",
}

describe("Guide engine: progress (acceptance)", function()
	after_each(function()
		Client.shutdown()
	end)

	describe("advance", function()
		it("advances accept, complete and turnin steps through the quest actions", function()
			local client = bootQuestRoute()
			assert.are.equal("Accept: First Quest", current(client))
			client.acceptQuest(101)
			assert.are.equal("Complete: First Quest", current(client))
			assert.is_false(Fx.shows(client, "Accept: First Quest"))
			client.completeObjectives(101)
			assert.are.equal("Turn in: First Quest", current(client))
			client.turnInQuest(101)
			assert.are.equal("Go to 50.0, 50.0", current(client))
		end)

		it("ignores quest actions for other quests", function()
			local client = bootQuestRoute()
			client.acceptQuest(999)
			client.completeObjectives(999)
			client.turnInQuest(999)
			client.advance(0.5)
			assert.are.equal("Accept: First Quest", current(client))
		end)

		it("does not advance a goto step at 11 yards and advances it at 9 yards", function()
			local client = bootQuestRoute({ quests = { completed = { 101 } } })
			assert.are.equal("Go to 50.0, 50.0", current(client))
			client.moveTo(1420, 50, 51.1)
			client.advance(1)
			assert.are.equal("Go to 50.0, 50.0", current(client))
			client.moveTo(1420, 51.1, 50)
			client.advance(1)
			assert.are.equal("Go to 50.0, 50.0", current(client))
			client.moveTo(1420, 50, 50.9)
			client.advance(0.5)
			assert.are.equal("Closing note", current(client))
		end)

		it("does not advance a goto step from another map, nor inside an instance", function()
			local client = bootQuestRoute({ quests = { completed = { 101 } } })
			client.moveTo(1411, 50, 50)
			client.advance(1)
			assert.are.equal("Go to 50.0, 50.0", current(client))
			client.enterInstance(Client.INSTANCE_MAP)
			client.advance(1)
			assert.are.equal("Go to 50.0, 50.0", current(client))
			client.moveTo(1420, 50.5, 50.5)
			client.advance(0.5)
			assert.are.equal("Closing note", current(client))
		end)

		it("advances every manual step type on Done", function()
			local client = Fx.boot({
				guides = {
					Fx.route("fx-manual", {
						{ type = "hearth" },
						{ type = "fly" },
						{ type = "train" },
						Fx.note("Talk to the bat handler"),
						{ type = "accept", questId = 101 },
					}),
				},
			})
			client.login()
			local texts = {
				"Use your Hearthstone",
				"Take a flight",
				"Visit your class trainer",
				"Talk to the bat handler",
				"Accept: First Quest",
			}
			for i = 1, 4 do
				assert.are.equal(texts[i], Fx.current(client, texts))
				client.advance(1)
				assert.are.equal(texts[i], Fx.current(client, texts), "manual steps wait for Done")
				client.click("Done")
			end
			assert.are.equal("Accept: First Quest", Fx.current(client, texts))
		end)

		it("moves one step forward on Skip and one step back on Back", function()
			local client = Fx.boot({ guides = { Fx.notesRoute("fx-notes", 4) } })
			client.login()
			local texts = Fx.noteTexts(4)
			assert.are.equal("Note 1", Fx.current(client, texts))
			client.click("Skip")
			assert.are.equal("Note 2", Fx.current(client, texts))
			client.click("Skip")
			assert.are.equal("Note 3", Fx.current(client, texts))
			client.click("Back")
			assert.are.equal("Note 2", Fx.current(client, texts))
			client.click("Back")
			assert.are.equal("Note 1", Fx.current(client, texts))
		end)

		it("skips an automatic step without its quest action", function()
			local client = bootQuestRoute()
			client.click("Skip")
			assert.are.equal("Complete: First Quest", current(client))
		end)
	end)

	describe("catch-up", function()
		it("lands on the first step that is not satisfied at login", function()
			-- 101 turned in, 102 in the log: accept 101 and accept 102 are satisfied; complete 102 is not.
			local client = bootCatchUp({ completed = { 101 }, log = { 102 } })
			assert.are.equal("Complete: Second Quest", Fx.current(client, CATCH_UP_TEXTS))
			assert.is_false(Fx.shows(client, "Accept: First Quest"))
			assert.is_false(Fx.shows(client, "Accept: Second Quest"))
		end)

		it("skips complete steps that are ready or turned in, and turnin steps already turned in", function()
			-- 101 and 102 turned in, 103 ready: everything up to turnin 103 is satisfied.
			local client = bootCatchUp({ completed = { 101, 102 }, ready = { 103 } })
			assert.are.equal("Turn in: Third Quest", Fx.current(client, CATCH_UP_TEXTS))

			Client.shutdown()
			client = bootCatchUp({ log = { 101 }, ready = { 102 } })
			assert.are.equal("Accept: Third Quest", Fx.current(client, CATCH_UP_TEXTS))
		end)

		it("does not skip a turnin step whose quest is only ready", function()
			local client = Fx.boot({
				guides = {
					Fx.route("fx-ready", { { type = "turnin", questId = 101 } }, { carriedQuests = { 101 } }),
				},
				quests = { ready = { 101 } },
			})
			client.login()
			assert.is_true(Fx.shows(client, "Turn in: First Quest"))
		end)

		it("never skips goto or manual steps on catch-up", function()
			local client = Fx.boot({
				guides = {
					Fx.route("fx-no-skip", {
						{ type = "goto", coords = { mapId = 1420, x = 80, y = 80 } },
						Fx.note("Read this first"),
						{ type = "accept", questId = 101 },
					}),
				},
				quests = { log = { 101 } },
			})
			client.login()
			local texts = { "Go to 80.0, 80.0", "Read this first", "Accept: First Quest" }
			assert.are.equal("Go to 80.0, 80.0", Fx.current(client, texts))
			client.click("Skip")
			assert.are.equal("Read this first", Fx.current(client, texts))
		end)

		it("skips a quest done out of order when its step comes up", function()
			local client = bootCatchUp()
			client.acceptQuest(102)
			assert.are.equal("Accept: First Quest", Fx.current(client, CATCH_UP_TEXTS))
			client.acceptQuest(101)
			assert.are.equal("Complete: Second Quest", Fx.current(client, CATCH_UP_TEXTS))
		end)

		it("stays on a satisfied step reached with Back", function()
			local client = bootCatchUp({ log = { 101, 102 } })
			assert.are.equal("Complete: Second Quest", Fx.current(client, CATCH_UP_TEXTS))
			client.click("Back")
			assert.are.equal("Accept: Second Quest", Fx.current(client, CATCH_UP_TEXTS))
			client.advance(1)
			assert.are.equal("Accept: Second Quest", Fx.current(client, CATCH_UP_TEXTS))
			client.click("Back")
			assert.are.equal("Accept: First Quest", Fx.current(client, CATCH_UP_TEXTS))
		end)
	end)

	describe("persistence", function()
		it("shows the same step after a reload", function()
			local client = Fx.boot({ guides = { Fx.notesRoute("fx-notes", 4) } })
			client.login()
			client.click("Skip")
			client.click("Skip")
			assert.are.equal("Note 3", Fx.current(client, Fx.noteTexts(4)))
			client.reload()
			assert.are.equal("Note 3", Fx.current(client, Fx.noteTexts(4)))
			assert.is_true(Fx.shows(client, "Route fx-notes"))
		end)

		it("keeps automatic progress after a reload", function()
			-- The leading note is never skipped on catch-up, so only saved progress can land past it.
			local client = Fx.boot({
				guides = {
					Fx.route("fx-saved", {
						Fx.note("Intro"),
						{ type = "accept", questId = 101 },
						{ type = "complete", questId = 101 },
					}),
				},
			})
			client.login()
			local texts = { "Intro", "Accept: First Quest", "Complete: First Quest" }
			client.click("Done")
			client.acceptQuest(101)
			assert.are.equal("Complete: First Quest", Fx.current(client, texts))
			client.reload()
			assert.are.equal("Complete: First Quest", Fx.current(client, texts))
		end)

		it("keeps separate progress for two characters on the same account", function()
			local function session(name, savedVariables)
				local client = Fx.boot({
					player = { name = name },
					guides = { Fx.notesRoute("fx-notes", 4) },
					savedVariables = savedVariables,
				})
				client.login()
				return client
			end
			local texts = Fx.noteTexts(4)

			local alpha = session("Alpha")
			alpha.click("Skip")
			alpha.click("Skip")
			assert.are.equal("Note 3", Fx.current(alpha, texts))
			local db = Fx.copy(LaRutaDel60DB)
			Client.shutdown()

			local beta = session("Beta", db)
			assert.are.equal("Note 1", Fx.current(beta, texts))
			beta.click("Skip")
			db = Fx.copy(LaRutaDel60DB)
			Client.shutdown()

			alpha = session("Alpha", db)
			assert.are.equal("Note 3", Fx.current(alpha, texts))
			db = Fx.copy(LaRutaDel60DB)
			Client.shutdown()

			beta = session("Beta", db)
			assert.are.equal("Note 2", Fx.current(beta, texts))
		end)

		it("stores each character's route and step under chars[<Name>-<Realm>]", function()
			local client = Fx.boot({
				player = { name = "Alpha", realm = "Stormspire" },
				guides = { Fx.notesRoute("fx-notes", 4) },
			})
			client.login()
			client.click("Skip")
			client.click("Skip")
			assert.are.same({ route = "fx-notes", step = 3 }, {
				route = LaRutaDel60DB.chars["Alpha-Stormspire"].route,
				step = LaRutaDel60DB.chars["Alpha-Stormspire"].step,
			})
		end)

		it("does not mix characters with the same name on different realms", function()
			local client = Fx.boot({
				player = { name = "Alpha", realm = "One" },
				guides = { Fx.notesRoute("fx-notes", 4) },
			})
			client.login()
			client.click("Skip")
			local db = Fx.copy(LaRutaDel60DB)
			Client.shutdown()
			client = Fx.boot({
				player = { name = "Alpha", realm = "Two" },
				guides = { Fx.notesRoute("fx-notes", 4) },
				savedVariables = db,
			})
			client.login()
			assert.are.equal("Note 1", Fx.current(client, Fx.noteTexts(4)))
		end)
	end)

	describe("chaining", function()
		local function bootChain(quests, locale)
			local client = Fx.boot({ guides = { Fx.tirisfal(), Fx.silverpine() }, quests = quests, locale = locale })
			client.login()
			return client
		end

		it("switches to the next route at step 1 when the last step is completed", function()
			local client = bootChain()
			client.acceptQuest(101)
			client.completeObjectives(101)
			assert.is_true(Fx.shows(client, Fx.TIRISFAL_NAME.enUS))
			client.turnInQuest(101)
			assert.is_true(Fx.shows(client, Fx.SILVERPINE_NAME.enUS))
			assert.is_false(Fx.shows(client, Fx.TIRISFAL_NAME.enUS))
			assert.are.equal("Accept: Silver Quest", Fx.current(client, CHAIN_TEXTS))
		end)

		it("runs catch-up on the next route", function()
			local client = bootChain({ log = { 201 } })
			client.acceptQuest(101)
			client.completeObjectives(101)
			client.turnInQuest(101)
			assert.is_true(Fx.shows(client, Fx.SILVERPINE_NAME.enUS))
			assert.are.equal("Accept: Pine Quest", Fx.current(client, CHAIN_TEXTS))
		end)

		it("switches to the next route when the last step is a manual one", function()
			local first = Fx.route("fx-first", { Fx.note("Last note of the first route") }, { next = "fx-second" })
			local second = Fx.notesRoute("fx-second", 2, { minLevel = 12, maxLevel = 20 })
			local client = Fx.boot({ guides = { first, second } })
			client.login()
			client.click("Done")
			assert.is_true(Fx.shows(client, "Route fx-second"))
			assert.are.equal("Note 1", Fx.current(client, { "Last note of the first route", "Note 1", "Note 2" }))
		end)

		it("keeps the next route after a reload", function()
			local client = bootChain()
			client.acceptQuest(101)
			client.completeObjectives(101)
			client.turnInQuest(101)
			client.reload()
			assert.is_true(Fx.shows(client, Fx.SILVERPINE_NAME.enUS))
			assert.are.equal("Accept: Silver Quest", Fx.current(client, CHAIN_TEXTS))
		end)

		it("shows route complete after the last step of the last route", function()
			local client = Fx.boot({ guides = { Fx.silverpine() }, player = { level = 13 } })
			client.login()
			client.acceptQuest(201)
			client.acceptQuest(202)
			assert.is_false(Fx.shows(client, "Route complete!"))
			client.turnInQuest(201)
			assert.is_true(Fx.shows(client, "Route complete!"))
			for _, text in ipairs(CHAIN_TEXTS) do
				assert.is_false(Fx.shows(client, text), text)
			end
		end)

		it("shows route complete in Spanish on esES and esMX", function()
			for _, locale in ipairs({ "esES", "esMX" }) do
				local client = Fx.boot({ guides = { Fx.notesRoute("fx-last", 1) }, locale = locale })
				client.login()
				client.click("Hecho")
				assert.is_true(Fx.shows(client, "¡Ruta completada!"), locale)
				assert.is_false(Fx.shows(client, "Route complete!"), locale)
				Client.shutdown()
			end
		end)
	end)
end)
