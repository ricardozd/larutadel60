-- Fixture routes, world and black-box helpers shared by the guide engine acceptance tests.
-- Routes follow the guide format (.claude/skills/guide-format/SKILL.md); only fixture routes are loaded.
local Client = require("support.client")
local WowMock = require("support.wow_mock")

local Fixtures = {}

Fixtures.PREFIX = "La Ruta del 60: "

-- Map rectangles with round numbers: on every map 1% of x or y is exactly 10 yards.
-- 1420 and 1421 share continent 0, and 1421 lies right south of 1420. 1411 is on continent 1.
Fixtures.MAPS = {
	[1420] = { continent = 0, left = 5000, top = 5000, width = 1000, height = 1000 },
	[1421] = { continent = 0, left = 5000, top = 4000, width = 1000, height = 1000 },
	[1411] = { continent = 1, left = 5000, top = 5000, width = 1000, height = 1000 },
}

-- Quest titles cached by the client in every fixture boot (unless a test overrides `quests`).
Fixtures.TITLES = {
	[101] = "First Quest",
	[102] = "Second Quest",
	[103] = "Third Quest",
	[201] = "Silver Quest",
	[202] = "Pine Quest",
}

-- Default player position: far (more than 400 yards) from every fixture coordinate.
Fixtures.START = { mapId = 1420, x = 10, y = 10, facing = 0 }

local function copy(value)
	return WowMock.deepCopy(value)
end
Fixtures.copy = copy

-- A Horde Undead route for levels 1-12. `fields` overrides any route field.
function Fixtures.route(id, steps, fields)
	local route = {
		id = id,
		name = { enUS = "Route " .. id, esES = "Ruta " .. id },
		faction = "Horde",
		races = { "Scourge" },
		minLevel = 1,
		maxLevel = 12,
		steps = steps,
	}
	for key, value in pairs(fields or {}) do
		route[key] = value
	end
	return route
end

-- A note step with an enUS and esES text.
function Fixtures.note(enUS, esES)
	return { type = "note", text = { enUS = enUS, esES = esES } }
end

-- A route made of `count` note steps "Note 1".."Note <count>" (esES "Nota 1"..).
function Fixtures.notesRoute(id, count, fields)
	local steps = {}
	for i = 1, count do
		steps[i] = Fixtures.note("Note " .. i, "Nota " .. i)
	end
	return Fixtures.route(id, steps, fields)
end

function Fixtures.noteTexts(count)
	local texts = {}
	for i = 1, count do
		texts[i] = "Note " .. i
	end
	return texts
end

-- Tirisfal-like and Silverpine-like routes, chained by `next`.
Fixtures.TIRISFAL_NAME = { enUS = "Fixture Tirisfal Glades", esES = "Claros de Tirisfal (prueba)" }
Fixtures.SILVERPINE_NAME = { enUS = "Fixture Silverpine Forest", esES = "Bosque de Argénteos (prueba)" }

function Fixtures.tirisfal(steps)
	return Fixtures.route("fx-tirisfal", steps or {
		{ type = "accept", questId = 101, coords = { mapId = 1420, x = 50, y = 40 } },
		{ type = "complete", questId = 101 },
		{ type = "turnin", questId = 101, coords = { mapId = 1420, x = 50, y = 40 } },
	}, { name = copy(Fixtures.TIRISFAL_NAME), next = "fx-silverpine" })
end

function Fixtures.silverpine(steps)
	return Fixtures.route("fx-silverpine", steps or {
		{ type = "accept", questId = 201, coords = { mapId = 1421, x = 50, y = 50 } },
		{ type = "accept", questId = 202 },
		{ type = "turnin", questId = 201 },
	}, { name = copy(Fixtures.SILVERPINE_NAME), minLevel = 12, maxLevel = 20 })
end

-- Routes no Undead may get: an Alliance route and a Horde route for Orcs only.
function Fixtures.alliance()
	return Fixtures.notesRoute("fx-alliance", 2, {
		faction = "Alliance",
		races = { "Human" },
		name = { enUS = "Fixture Northshire", esES = "Villanorte (prueba)" },
	})
end

function Fixtures.orc()
	return Fixtures.notesRoute("fx-orc", 2, {
		races = { "Orc" },
		name = { enUS = "Fixture Valley of Trials", esES = "Valle de los Retos (prueba)" },
	})
end

-- Boots a client with only the given fixture guides, the fixture maps and titles, and a known position.
-- opts are passed to Client.boot; `position = false` boots inside an instance.
function Fixtures.boot(opts)
	opts = opts or {}
	local bootOpts = {}
	for key, value in pairs(opts) do
		bootOpts[key] = value
	end
	bootOpts.replaceGuides = true
	bootOpts.guides = opts.guides or {}
	bootOpts.maps = opts.maps or copy(Fixtures.MAPS)
	if opts.position == false then
		bootOpts.position = nil
	else
		bootOpts.position = opts.position or copy(Fixtures.START)
	end
	local quests = copy(opts.quests or {})
	quests.titles = quests.titles or copy(Fixtures.TITLES)
	bootOpts.quests = quests
	return Client.boot(bootOpts)
end

-- Every visible text line, in order. A font string holding several lines counts as several lines.
function Fixtures.lines(client)
	local lines = {}
	for _, text in ipairs(client.visibleTexts()) do
		for line in (text .. "\n"):gmatch("(.-)\r?\n") do
			line = line:match("^%s*(.-)%s*$")
			if line ~= "" then
				lines[#lines + 1] = line
			end
		end
	end
	return lines
end

-- Position of the first visible line equal to `text`, or nil.
function Fixtures.indexOf(client, text)
	for i, line in ipairs(Fixtures.lines(client)) do
		if line == text then
			return i
		end
	end
	return nil
end

function Fixtures.shows(client, text)
	return Fixtures.indexOf(client, text) ~= nil
end

-- The current step: the first visible line that is one of `candidates` (the step texts of the route).
-- The window shows the current step first, followed by up to two upcoming steps.
function Fixtures.current(client, candidates)
	local wanted = {}
	for _, text in ipairs(candidates) do
		wanted[text] = true
	end
	for _, line in ipairs(Fixtures.lines(client)) do
		if wanted[line] then
			return line
		end
	end
	return nil
end

-- Chat lines printed since `from` (the number of lines before the action).
function Fixtures.messagesSince(client, from)
	local lines = {}
	local messages = client.messages()
	for i = from + 1, #messages do
		lines[#lines + 1] = messages[i]
	end
	return lines
end

-- Runs a slash command and returns only the chat lines it printed.
function Fixtures.slash(client, line)
	local before = #client.messages()
	client.slash(line)
	return Fixtures.messagesSince(client, before)
end

return Fixtures
