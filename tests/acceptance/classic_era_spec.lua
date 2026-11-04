-- Classic Era compatibility (docs/superpowers/specs/2026-11-04-classic-era-compat-design.md,
-- "Acceptance criteria"). The client boots with flavor = "classic_era": it loads LaRutaDel60_Vanilla.toc
-- and emulates the 1.15 API (see tests/support/wow_mock.lua and emulation_classic_spec.lua).
local Client = require("support.client")
local WowMock = require("support.wow_mock")
local Fx = require("support.fixtures")

local CLASSIC_ERA = "classic_era"
local PREFIX = Fx.PREFIX
local ALLOWED_GLOBALS = { "LaRutaDel60DB", "SLASH_LARUTADEL601" }

local LOGIN = {
	enUS = {
		PREFIX .. "Warning: this client is not WoW Forever; guides may be wrong.",
		PREFIX .. "Loaded. Type /ruta for info.",
	},
	esES = {
		PREFIX .. "Aviso: este cliente no es WoW Forever; las guías pueden fallar.",
		PREFIX .. "Cargado. Escribe /ruta para más info.",
	},
}

-- Boots a Classic Era client with only the given fixture guides (Fx.boot) and logs in.
local function bootClassic(opts)
	opts = opts or {}
	opts.flavor = CLASSIC_ERA
	local client = Fx.boot(opts)
	client.login()
	return client
end

-- accept, complete and turnin of quest 101, then a closing note.
local QUEST_ROUTE_TEXTS = {
	"Accept: First Quest",
	"Complete: First Quest",
	"Turn in: First Quest",
	"Closing note",
}

local function bootQuestRoute(opts)
	opts = opts or {}
	opts.guides = {
		Fx.route("fx-classic-quests", {
			{ type = "accept", questId = 101 },
			{ type = "complete", questId = 101 },
			{ type = "turnin", questId = 101 },
			Fx.note("Closing note", "Nota final"),
		}),
	}
	return bootClassic(opts)
end

local function current(client)
	return Fx.current(client, QUEST_ROUTE_TEXTS)
end

local function readLines(path)
	local handle = io.open(path, "r")
	assert.is_not_nil(handle, "missing " .. path)
	local lines = {}
	for line in handle:read("*a"):gmatch("[^\r\n]+") do
		lines[#lines + 1] = line
	end
	handle:close()
	return lines
end

local function isInterfaceLine(line)
	return line:match("^##%s*Interface%s*:") ~= nil
end

local function withoutInterface(lines)
	local kept = {}
	for _, line in ipairs(lines) do
		if not isInterfaceLine(line) then
			kept[#kept + 1] = line
		end
	end
	return kept
end

local function assertOnlyAllowedGlobals(client)
	assert.are.same(ALLOWED_GLOBALS, client.newGlobals())
	assert.are.same({ "LARUTADEL60" }, client.newSlashCommands())
end

describe("Classic Era compatibility (acceptance)", function()
	after_each(function()
		Client.shutdown()
	end)

	describe("TOC", function()
		it("has LaRutaDel60_Vanilla.toc with ## Interface: 11509", function()
			local interfaces = {}
			for _, line in ipairs(readLines(Client.VANILLA_TOC)) do
				if isInterfaceLine(line) then
					interfaces[#interfaces + 1] = line:match(":%s*(.-)%s*$")
				end
			end
			assert.are.same({ "11509" }, interfaces)
		end)

		it("has the same non-Interface lines as the base TOC, in the same order", function()
			local vanilla = withoutInterface(readLines(Client.VANILLA_TOC))
			local base = withoutInterface(readLines(Client.TOC))
			assert.are.same(base, vanilla)
		end)

		it("loads the same addon files as the base TOC", function()
			assert.are.same(Client.addonFiles(Client.TOC), Client.addonFiles(Client.VANILLA_TOC))
		end)
	end)

	describe("login", function()
		it("shows exactly the warning and then Loaded (enUS)", function()
			local client = Client.boot({ flavor = CLASSIC_ERA })
			client.login()
			client.advance(1)
			assert.are.same(LOGIN.enUS, client.messages())
		end)

		it("shows exactly the warning and then Loaded (esES and esMX)", function()
			for _, locale in ipairs({ "esES", "esMX" }) do
				local client = Client.boot({ flavor = CLASSIC_ERA, locale = locale })
				client.login()
				client.advance(1)
				assert.are.same(LOGIN.esES, client.messages(), locale)
				Client.shutdown()
			end
		end)

		it("shows exactly the warning and then Loaded with fixture routes", function()
			local client = bootClassic({ guides = { Fx.tirisfal(), Fx.silverpine() } })
			client.advance(1)
			assert.are.same(LOGIN.enUS, client.messages())
		end)
	end)

	describe("selection and display", function()
		it("gives an Undead level 1 the Undead route, with the GetQuestInfo title in the first step", function()
			local client = bootClassic({
				player = { race = "Scourge", level = 1 },
				guides = { Fx.tirisfal(), Fx.silverpine(), Fx.alliance(), Fx.orc() },
			})
			assert.is_true(Fx.shows(client, Fx.TIRISFAL_NAME.enUS))
			assert.is_false(Fx.shows(client, Fx.SILVERPINE_NAME.enUS))
			assert.are.equal("Accept: First Quest", Fx.current(client, { "Accept: First Quest", "Accept: Quest #101" }))
		end)

		it("shows the esES route name and step text on esES", function()
			local client = bootClassic({ locale = "esES", guides = { Fx.tirisfal(), Fx.silverpine() } })
			assert.is_true(Fx.shows(client, Fx.TIRISFAL_NAME.esES))
			assert.are.equal(
				"Acepta: First Quest",
				Fx.current(client, { "Acepta: First Quest", "Acepta: Misión #101" })
			)
		end)

		it("shows the GetQuestInfo titles of the upcoming steps", function()
			local client = bootQuestRoute()
			assert.is_true(Fx.shows(client, "Accept: First Quest"))
			assert.is_true(Fx.shows(client, "Complete: First Quest"))
			assert.is_true(Fx.shows(client, "Turn in: First Quest"))
		end)
	end)

	describe("advance", function()
		it("advances accept, complete and turnin through the classic quest events", function()
			local client = bootQuestRoute()
			assert.are.equal("Accept: First Quest", current(client))
			client.acceptQuest(101)
			assert.are.equal("Complete: First Quest", current(client))
			client.completeObjectives(101)
			assert.are.equal("Turn in: First Quest", current(client))
			client.turnInQuest(101)
			assert.are.equal("Closing note", current(client))
		end)

		it("reads the quest ID from the last argument of QUEST_ACCEPTED(logIndex, questID)", function()
			-- 102 and 103 are already in the log, so 101 lands at log index 3. QUEST_ACCEPTED is fired
			-- alone (no QUEST_LOG_UPDATE after it), so only the questID argument can advance the step.
			local client = bootQuestRoute({ quests = { log = { 102, 103 } } })
			assert.are.equal("Accept: First Quest", current(client))
			local quests = client.world.quests
			quests.log[101] = true
			quests.order[#quests.order + 1] = 101
			assert.are.equal(3, GetQuestLogIndexByID(101))
			client.fire("QUEST_ACCEPTED", 3, 101)
			assert.are.equal("Complete: First Quest", current(client))
		end)

		it("ignores QUEST_ACCEPTED whose questID (last argument) is another quest", function()
			-- logIndex 1 matches nothing; the questID 102 is not on the route.
			local client = bootQuestRoute({ quests = { log = { 102 } } })
			client.fire("QUEST_ACCEPTED", 1, 102)
			assert.are.equal("Accept: First Quest", current(client))
		end)

		it("completes through GetQuestLogIndexByID and GetQuestLogTitle, not another log entry", function()
			-- 101 sits at log index 3, after 102 and 103.
			local client = bootQuestRoute({ quests = { log = { 102, 103 } } })
			client.acceptQuest(101)
			assert.are.equal("Complete: First Quest", current(client))
			-- Another quest becoming ready must not complete 101.
			client.completeObjectives(102)
			assert.are.equal("Complete: First Quest", current(client))
			client.completeObjectives(101)
			assert.are.equal("Turn in: First Quest", current(client))
		end)

		it("stays on complete while the quest is in the log but not ready", function()
			local client = bootQuestRoute({ quests = { log = { 101 } } })
			assert.are.equal("Complete: First Quest", current(client))
			client.advance(1)
			assert.are.equal("Complete: First Quest", current(client))
		end)

		it("does not advance a complete step when the quest fails", function()
			local client = bootQuestRoute()
			client.acceptQuest(101)
			assert.are.equal("Complete: First Quest", current(client))
			client.failQuest(101)
			client.advance(1)
			assert.are.equal("Complete: First Quest", current(client))
		end)

		it("does not catch up past a quest that is failed at login", function()
			local client = bootQuestRoute({ quests = { failed = { 101 } } })
			client.advance(1)
			assert.are.equal("Complete: First Quest", current(client))
		end)

		it("catches up at login past a quest that is already ready", function()
			local client = bootQuestRoute({ quests = { log = { 102 }, ready = { 101 } } })
			assert.are.equal("Turn in: First Quest", current(client))
		end)

		it("catches up at login past a quest that is already turned in", function()
			local client = bootQuestRoute({ quests = { completed = { 101 } } })
			assert.are.equal("Closing note", current(client))
		end)

		it("chains to the next route after the last turn-in", function()
			local client = bootClassic({ guides = { Fx.tirisfal(), Fx.silverpine() } })
			client.acceptQuest(101)
			client.completeObjectives(101)
			client.turnInQuest(101)
			assert.is_true(Fx.shows(client, Fx.SILVERPINE_NAME.enUS))
			assert.are.equal(
				"Accept: Silver Quest",
				Fx.current(client, { "Accept: Silver Quest", "Accept: Pine Quest" })
			)
		end)

		it("keeps the step after a reload", function()
			local client = bootQuestRoute()
			client.acceptQuest(101)
			client.reload()
			assert.are.equal("Complete: First Quest", current(client))
			client.completeObjectives(101)
			assert.are.equal("Turn in: First Quest", current(client))
		end)
	end)

	describe("unknown titles", function()
		local UNKNOWN_STEPS = {
			{ type = "accept", questId = 555 },
			{ type = "complete", questId = 555 },
			Fx.note("Closing note", "Nota final"),
		}

		local function bootUnknown(opts)
			opts = opts or {}
			opts.guides = { Fx.route("fx-classic-unknown", Fx.copy(UNKNOWN_STEPS)) }
			return bootClassic(opts)
		end

		it("shows Quest #<id> when GetQuestInfo has no title, and nothing errors", function()
			local client = bootUnknown()
			client.advance(1)
			assert.are.equal("Accept: Quest #555", Fx.current(client, { "Accept: Quest #555", "Closing note" }))
			assert.is_true(Fx.shows(client, "Complete: Quest #555"))
			client.click("Skip")
			client.advance(1)
			assert.are.equal("Complete: Quest #555", Fx.current(client, { "Complete: Quest #555", "Closing note" }))
			client.click("Skip")
			client.advance(1)
			assert.are.equal("Closing note", Fx.current(client, { "Complete: Quest #555", "Closing note" }))
			assert.are.same(LOGIN.enUS, client.messages())
		end)

		it("treats an empty GetQuestInfo title as unknown", function()
			local client = bootUnknown({ quests = { titles = { [555] = "" } } })
			assert.are.equal(
				"Accept: Quest #555",
				Fx.current(client, { "Accept: Quest #555", "Accept:", "Closing note" })
			)
		end)

		it("shows Misión #<id> on esES", function()
			local client = bootUnknown({ locale = "esES" })
			assert.are.equal("Acepta: Misión #555", Fx.current(client, { "Acepta: Misión #555", "Nota final" }))
		end)

		it("takes the displayed title from GetQuestInfo, not the quest log, while the quest is in the log", function()
			-- GetQuestInfo has no title for 555; the quest log entry does ("Quest Title 555").
			local client = bootUnknown()
			client.acceptQuest(555)
			client.advance(1)
			local texts = { "Complete: Quest #555", "Complete: Quest Title 555", "Closing note" }
			assert.are.equal("Complete: Quest #555", Fx.current(client, texts))
			assert.is_false(Fx.shows(client, "Complete: Quest Title 555"))
			client.completeObjectives(555)
			assert.are.equal("Closing note", Fx.current(client, texts))
		end)
	end)

	describe("arrow", function()
		local function bootArrow(steps, position)
			local client = bootClassic({
				guides = { Fx.route("fx-classic-arrow", steps) },
				position = position or { mapId = 1420, x = 50, y = 50, facing = 0 },
			})
			client.advance(0.5)
			return client
		end

		it("is shown with the distance when the step has coords and the position is known", function()
			-- Target 10% north: 100 yards straight ahead.
			local client = bootArrow({ { type = "goto", coords = { mapId = 1420, x = 50, y = 40 } }, Fx.note("After") })
			local arrow = client.arrow()
			assert.is_true(arrow.shown)
			assert.are.equal("100 yd", arrow.label)
			assert.is_true(math.abs(WowMock.normalizeAngle(arrow.rotation)) < 1e-3)
		end)

		it("is shown for a quest step with coords and follows the player", function()
			local client = bootArrow({
				{ type = "accept", questId = 101, coords = { mapId = 1420, x = 40, y = 50 } },
				Fx.note("After"),
			})
			assert.is_true(client.arrow().shown)
			assert.are.equal("100 yd", client.arrow().label)
			client.moveTo(1420, 45, 50)
			client.advance(0.5)
			assert.are.equal("50 yd", client.arrow().label)
		end)
	end)

	describe("hygiene", function()
		it("creates no new globals and raises no errors after login, actions, commands and reload", function()
			local client = bootClassic({
				guides = { Fx.tirisfal(), Fx.silverpine(), Fx.alliance() },
				position = { mapId = 1420, x = 50, y = 60, facing = 0 },
			})
			assert.is_true(Fx.shows(client, Fx.TIRISFAL_NAME.enUS))
			client.advance(1)
			assertOnlyAllowedGlobals(client)

			client.acceptQuest(101)
			client.completeObjectives(101)
			client.moveTo(1420, 50, 45)
			client.face(1)
			client.advance(1)
			client.enterInstance(Client.INSTANCE_MAP)
			client.advance(1)
			client.moveTo(1420, 50, 50)
			client.levelUp(2)
			client.advance(1)
			assertOnlyAllowedGlobals(client)

			client.click("Back")
			client.click("Skip")
			client.turnInQuest(101)
			assert.is_true(Fx.shows(client, Fx.SILVERPINE_NAME.enUS))
			client.acceptQuest(201)
			client.acceptQuest(202)
			client.turnInQuest(201)
			assert.is_true(Fx.shows(client, "Route complete!"))
			client.advance(1)
			assertOnlyAllowedGlobals(client)

			for _, line in ipairs({
				"/ruta",
				"/ruta list",
				"/ruta fx-tirisfal",
				"/ruta fx-missing",
				"/ruta reset",
				"/ruta hide",
				"/ruta show",
			}) do
				client.slash(line)
			end
			client.advance(1)
			assertOnlyAllowedGlobals(client)

			client.reload()
			client.advance(1)
			assertOnlyAllowedGlobals(client)
		end)

		it("creates no new globals with the addon's own guides", function()
			local client = Client.boot({ flavor = CLASSIC_ERA })
			client.login()
			client.advance(1)
			client.slash("/ruta")
			client.reload()
			client.advance(1)
			assertOnlyAllowedGlobals(client)
		end)
	end)
end)
