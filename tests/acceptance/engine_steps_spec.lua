-- Guide engine: step window texts, lines and buttons (spec §3.3 and §5 "Steps", "Advance: Done").
local Client = require("support.client")
local Fx = require("support.fixtures")

-- Boots with a single route whose first step is `step`, followed by a closing note.
local function bootFirstStep(step, opts)
	opts = opts or {}
	opts.guides = {
		Fx.route("fx-steps", { step, Fx.note("Closing note", "Nota final") }, { carriedQuests = { 101 } }),
	}
	local client = Fx.boot(opts)
	client.login()
	return client
end

local QUEST_IN_LOG = { log = { 101 } }

-- { step, quest state, enUS text, esES text }
local STEP_TEXTS = {
	{ { type = "accept", questId = 101 }, nil, "Accept: First Quest", "Acepta: First Quest" },
	{ { type = "complete", questId = 101 }, QUEST_IN_LOG, "Complete: First Quest", "Completa: First Quest" },
	{ { type = "turnin", questId = 101 }, QUEST_IN_LOG, "Turn in: First Quest", "Entrega: First Quest" },
	{ { type = "goto", coords = { mapId = 1420, x = 45.3, y = 67 } }, nil, "Go to 45.3, 67.0", "Ve a 45.3, 67.0" },
	{ { type = "hearth" }, nil, "Use your Hearthstone", "Usa tu Piedra de hogar" },
	{ { type = "fly" }, nil, "Take a flight", "Toma un vuelo" },
	{ { type = "train" }, nil, "Visit your class trainer", "Visita a tu instructor de clase" },
	{
		Fx.note("Talk to the bat handler", "Habla con el maestro de murciélagos"),
		nil,
		"Talk to the bat handler",
		"Habla con el maestro de murciélagos",
	},
}

local AUTOMATIC = { "accept", "complete", "turnin", "goto" }
local MANUAL = { "hearth", "fly", "train", "note" }

local function stepOfType(stepType)
	for _, row in ipairs(STEP_TEXTS) do
		if row[1].type == stepType then
			return row
		end
	end
end

describe("Guide engine: step window (acceptance)", function()
	after_each(function()
		Client.shutdown()
	end)

	describe("step texts", function()
		it("generates the enUS text of every step type", function()
			for _, row in ipairs(STEP_TEXTS) do
				local client = bootFirstStep(Fx.copy(row[1]), { quests = Fx.copy(row[2]) })
				assert.are.equal(row[3], Fx.current(client, { row[3], "Closing note" }), row[1].type)
				Client.shutdown()
			end
		end)

		it("generates the esES text of every step type on esES and esMX", function()
			for _, locale in ipairs({ "esES", "esMX" }) do
				for _, row in ipairs(STEP_TEXTS) do
					local client = bootFirstStep(Fx.copy(row[1]), { locale = locale, quests = Fx.copy(row[2]) })
					assert.are.equal(row[4], Fx.current(client, { row[4], "Nota final" }), locale .. " " .. row[1].type)
					Client.shutdown()
				end
			end
		end)

		it("uses Quest #<id> until the title loads, then refreshes on QUEST_DATA_LOAD_RESULT", function()
			local client = bootFirstStep({ type = "accept", questId = 150 }, { quests = { titles = {} } })
			assert.are.equal("Accept: Quest #150", Fx.current(client, { "Accept: Quest #150", "Closing note" }))
			client.loadQuestData(150)
			client.advance(0.5)
			assert.are.equal(
				"Accept: Quest Title 150",
				Fx.current(client, { "Accept: Quest #150", "Accept: Quest Title 150", "Closing note" })
			)
			assert.is_false(Fx.shows(client, "Accept: Quest #150"))
		end)

		it("lets a step's own text replace the generated text, in both locales", function()
			local step = {
				type = "accept",
				questId = 101,
				text = { enUS = "Grab the quest from the gravedigger", esES = "Coge la misión del sepulturero" },
			}
			local client = bootFirstStep(Fx.copy(step))
			assert.is_true(Fx.shows(client, "Grab the quest from the gravedigger"))
			assert.is_false(Fx.shows(client, "Accept: First Quest"))
			Client.shutdown()

			client = bootFirstStep(Fx.copy(step), { locale = "esES" })
			assert.is_true(Fx.shows(client, "Coge la misión del sepulturero"))
			assert.is_false(Fx.shows(client, "Acepta: First Quest"))
		end)
	end)

	describe("lines", function()
		it("shows the current step first, followed by up to two upcoming steps", function()
			local client = Fx.boot({ guides = { Fx.notesRoute("fx-notes", 5) } })
			client.login()
			local first, second, third =
				Fx.indexOf(client, "Note 1"), Fx.indexOf(client, "Note 2"), Fx.indexOf(client, "Note 3")
			assert.is_number(first)
			assert.is_number(second)
			assert.is_number(third)
			assert.is_true(first < second and second < third)
			assert.is_false(Fx.shows(client, "Note 4"))
			assert.is_false(Fx.shows(client, "Note 5"))
		end)

		it("drops passed steps and shows fewer lines near the end of the route", function()
			local client = Fx.boot({ guides = { Fx.notesRoute("fx-notes", 5) } })
			client.login()
			client.click("Skip")
			client.click("Skip")
			client.click("Skip")
			assert.are.equal("Note 4", Fx.current(client, Fx.noteTexts(5)))
			assert.is_true(Fx.indexOf(client, "Note 4") < Fx.indexOf(client, "Note 5"))
			for i = 1, 3 do
				assert.is_false(Fx.shows(client, "Note " .. i))
			end
		end)

		it("generates the texts of upcoming steps too", function()
			local client = Fx.boot({
				guides = {
					Fx.route("fx-upcoming", {
						Fx.note("Start here"),
						{ type = "accept", questId = 102 },
						{ type = "goto", coords = { mapId = 1420, x = 20.27, y = 5 } },
					}),
				},
			})
			client.login()
			assert.is_true(Fx.indexOf(client, "Start here") < Fx.indexOf(client, "Accept: Second Quest"))
			assert.is_true(Fx.indexOf(client, "Accept: Second Quest") < Fx.indexOf(client, "Go to 20.3, 5.0"))
		end)
	end)

	describe("buttons", function()
		it("shows Back and Skip, but not Done, for automatic step types", function()
			for _, stepType in ipairs(AUTOMATIC) do
				local row = stepOfType(stepType)
				local client = bootFirstStep(Fx.copy(row[1]), { quests = Fx.copy(row[2]) })
				assert.is_true(Fx.shows(client, row[3]), stepType)
				assert.is_true(Fx.shows(client, "Back"), stepType)
				assert.is_true(Fx.shows(client, "Skip"), stepType)
				assert.is_false(Fx.shows(client, "Done"), stepType)
				Client.shutdown()
			end
		end)

		it("shows Back, Done and Skip for manual step types", function()
			for _, stepType in ipairs(MANUAL) do
				local row = stepOfType(stepType)
				local client = bootFirstStep(Fx.copy(row[1]))
				assert.is_true(Fx.shows(client, row[3]), stepType)
				assert.is_true(Fx.shows(client, "Back"), stepType)
				assert.is_true(Fx.shows(client, "Done"), stepType)
				assert.is_true(Fx.shows(client, "Skip"), stepType)
				Client.shutdown()
			end
		end)

		it("hides Done again when an automatic step follows a manual one", function()
			local client = Fx.boot({
				guides = { Fx.route("fx-mixed", { { type = "hearth" }, { type = "accept", questId = 101 } }) },
			})
			client.login()
			assert.is_true(Fx.shows(client, "Done"))
			client.click("Done")
			assert.are.equal(
				"Accept: First Quest",
				Fx.current(client, { "Use your Hearthstone", "Accept: First Quest" })
			)
			assert.is_false(Fx.shows(client, "Done"))
		end)

		it("labels the buttons in Spanish on esES and esMX", function()
			for _, locale in ipairs({ "esES", "esMX" }) do
				local client = bootFirstStep({ type = "train" }, { locale = locale })
				for _, label in ipairs({ "Atrás", "Hecho", "Saltar" }) do
					assert.is_true(Fx.shows(client, label), locale .. " " .. label)
				end
				for _, label in ipairs({ "Back", "Done", "Skip" }) do
					assert.is_false(Fx.shows(client, label), locale .. " " .. label)
				end
				client.click("Hecho")
				assert.are.equal("Nota final", Fx.current(client, { "Visita a tu instructor de clase", "Nota final" }))
				Client.shutdown()
			end
		end)
	end)

	describe("window", function()
		-- Anchor of a frame without its relative frame (UIParent is a new object after a reload).
		local function anchorOf(frame)
			local point, _, relativePoint, x, y = frame:GetPoint()
			return { point, relativePoint, x, y }
		end

		it("is draggable and keeps its position after a reload", function()
			local client = Fx.boot({ guides = { Fx.notesRoute("fx-notes", 3) } })
			client.login()
			assert.is_true(Fx.shows(client, "Route fx-notes"))
			local movable = client.movableFrames()
			assert.is_true(#movable >= 1, "the step window must be draggable")
			-- Drag every visible draggable frame to its own spot; the step window is one of them.
			local targets = {}
			for i, frame in ipairs(movable) do
				if frame:IsVisible() then
					targets[i] = { "TOPLEFT", "TOPLEFT", 100 + i, -(200 + i) }
					client.drag(i, "TOPLEFT", UIParent, "TOPLEFT", 100 + i, -(200 + i))
				end
			end
			client.reload()
			assert.is_true(Fx.shows(client, "Route fx-notes"))
			local kept = 0
			for i, frame in ipairs(client.movableFrames()) do
				if targets[i] and frame:GetNumPoints() > 0 then
					local anchor = anchorOf(frame)
					if anchor[1] == targets[i][1] and anchor[3] == targets[i][3] and anchor[4] == targets[i][4] then
						kept = kept + 1
					end
				end
			end
			assert.is_true(kept >= 1, "the dragged step window must be restored where it was left")
		end)
	end)
end)
