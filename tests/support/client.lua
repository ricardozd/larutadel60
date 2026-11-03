-- Emulates how the WoW client loads and drives the addon (see docs/api/forever-api.md).
local WowMock = require("support.wow_mock")

local Client = {}
Client.ADDON_NAME = "LaRutaDel60"
Client.ADDON_DIR = "addon/LaRutaDel60/"
Client.TOC = Client.ADDON_DIR .. "LaRutaDel60.toc"
Client.FOREVER_TOC = Client.ADDON_DIR .. "LaRutaDel60_Forever.toc"
-- uiMapID that C_Map.GetBestMapForUnit("player") reports inside an instance by default.
Client.INSTANCE_MAP = WowMock.DEFAULT_INSTANCE_MAP

local originalPrint = print

local function keysOf(t)
	local keys = {}
	for key in pairs(t) do
		keys[key] = true
	end
	return keys
end

-- Globals present before any test ran; everything else is test pollution to be removed.
local baselineGlobals = keysOf(_G)

local function resetGlobals()
	for key in pairs(keysOf(_G)) do
		if not baselineGlobals[key] then
			_G[key] = nil
		end
	end
	_G.print = originalPrint
end

function Client.readFile(path)
	local handle = assert(io.open(path, "r"), "missing file " .. path)
	local content = handle:read("*a")
	handle:close()
	return content
end

function Client.tocField(field)
	return (Client.readFile(Client.TOC) .. "\n"):match("##%s*" .. field .. "%s*:%s*([^\r\n]-)%s*[\r\n]")
end

local function tocEntries(tocPath)
	local entries = {}
	for line in Client.readFile(tocPath):gmatch("[^\r\n]+") do
		local entry = line:match("^%s*(.-)%s*$")
		if entry ~= "" and entry:sub(1, 1) ~= "#" then
			entries[#entries + 1] = (entry:gsub("\\", "/"))
		end
	end
	return entries
end

-- Lua files in client load order, with .xml files expanded into their <Script file="..."/> entries.
function Client.addonFiles()
	local files = {}
	for _, entry in ipairs(tocEntries(Client.TOC)) do
		local path = Client.ADDON_DIR .. entry
		if entry:match("%.xml$") then
			local dir = path:match("^(.*/)")
			for script in Client.readFile(path):gmatch('<Script%s+file="([^"]+)"') do
				files[#files + 1] = dir .. (script:gsub("\\", "/"))
			end
		else
			files[#files + 1] = path
		end
	end
	return files
end

local function newKeys(before, after)
	local added = {}
	for key in pairs(after) do
		if not before[key] then
			added[#added + 1] = tostring(key)
		end
	end
	table.sort(added)
	return added
end

local GUIDES_DIR = Client.ADDON_DIR .. "Guides/"

-- Boots one client session. `world` (player, quests, position, maps) outlives a /reload.
local function bootSession(opts, world, savedVariables)
	resetGlobals()
	local client = WowMock.install({
		locale = opts.locale,
		projectId = opts.projectId,
		addonName = Client.ADDON_NAME,
		tocPath = Client.TOC,
		world = world,
	})
	local globalsBefore = keysOf(_G)
	local slashBefore = keysOf(SlashCmdList)

	local ns = {}
	for _, path in ipairs(Client.addonFiles()) do
		-- replaceGuides skips the addon's own compiled guides (Guides/Guides.xml and its scripts).
		if not (opts.replaceGuides and path:sub(1, #GUIDES_DIR) == GUIDES_DIR) then
			local chunk = assert(loadfile(path))
			chunk(Client.ADDON_NAME, ns)
		end
	end
	-- Fixture guides behave like extra guide files appended to the TOC.
	for _, route in ipairs(opts.guides or {}) do
		ns.Guides = ns.Guides or {}
		ns.Guides[route.id] = WowMock.deepCopy(route)
	end

	-- Other addons may finish loading first, before our saved variables exist.
	client.fire("ADDON_LOADED", "Blizzard_Foo")
	-- The client restores saved variables after the addon files ran, before our ADDON_LOADED.
	if savedVariables ~= nil then
		_G.LaRutaDel60DB = savedVariables
	end
	client.fire("ADDON_LOADED", Client.ADDON_NAME)

	function client.login()
		client.loggedIn = true
		client.fire("PLAYER_LOGIN")
	end

	function client.slash(line)
		local command, rest = line:match("^(/%S+)%s*(.*)$")
		for key, handler in pairs(SlashCmdList) do
			local index = 1
			while _G["SLASH_" .. key .. index] do
				if _G["SLASH_" .. key .. index] == command then
					handler(rest)
					return
				end
				index = index + 1
			end
		end
		error("unknown slash command " .. tostring(command))
	end

	-- Chat lines as the player reads them (color codes removed).
	function client.messages()
		local lines = {}
		for i, message in ipairs(client.chat) do
			lines[i] = message:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
		end
		return lines
	end

	function client.newGlobals()
		return newKeys(globalsBefore, _G)
	end

	function client.newSlashCommands()
		return newKeys(slashBefore, SlashCmdList)
	end

	return client
end

-- opts: {
--   locale = "enUS", projectId = 18, savedVariables = <table|nil>,
--   player = { name, realm, faction, race, class, level },
--   quests = { completed = {ids}, log = {ids}, ready = {ids}, titles = { [id] = "Title" } },
--   position = { mapId, x, y, facing } (x, y in percent; nil = inside an instance),
--   maps = { [uiMapID] = { continent, left, top, width, height } } (yards, see wow_mock.lua),
--   guides = { <route table>, ... }, replaceGuides = true|false,
-- }
function Client.boot(opts)
	opts = opts or {}
	local world = WowMock.newWorld(opts)
	-- The returned client is a handle onto the current session, so it keeps working across reloads.
	local client = {}
	local function start(savedVariables)
		local session = bootSession(opts, world, savedVariables)
		setmetatable(client, { __index = session, __newindex = session })
		return session
	end
	start(opts.savedVariables)

	-- Equivalent of /reload: a fresh Lua state that keeps LaRutaDel60DB (serialized, so it is a copy)
	-- and the player, quest and position state. Frames, timers and chat start over, and the boot
	-- sequence runs again (ADDON_LOADED, then PLAYER_LOGIN if the session had logged in).
	-- rawset keeps reload on the handle itself instead of the current session.
	rawset(client, "reload", function()
		local wasLoggedIn = client.loggedIn
		local session = start(WowMock.deepCopy(_G.LaRutaDel60DB))
		if wasLoggedIn then
			session.login()
		end
		return client
	end)

	return client
end

function Client.shutdown()
	resetGlobals()
end

return Client
