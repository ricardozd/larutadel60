-- Minimal WoW Forever API emulation for out-of-game tests.
-- Only APIs documented in docs/api/forever-api.md may be emulated here.
local WowMock = {}

local function readTocFields(tocPath)
	local fields = {}
	local handle = assert(io.open(tocPath, "r"), "missing TOC " .. tocPath)
	for line in handle:lines() do
		local key, value = line:match("^##%s*([%w%-_]+)%s*:%s*(.-)%s*$")
		if key then
			fields[key] = value
		end
	end
	handle:close()
	return fields
end

-- opts: { locale = "enUS", projectId = 18, addonName = "...", tocPath = "..." }
function WowMock.install(opts)
	local client = { chat = {}, frames = {} }

	local function capture(message)
		client.chat[#client.chat + 1] = message
	end

	_G.DEFAULT_CHAT_FRAME = {
		AddMessage = function(_, message)
			capture(message)
		end,
	}
	_G.print = function(...)
		local parts = {}
		for i = 1, select("#", ...) do
			parts[i] = tostring((select(i, ...)))
		end
		capture(table.concat(parts, " "))
	end

	_G.GetLocale = function()
		return opts.locale or "enUS"
	end

	_G.WOW_PROJECT_MAINLINE = 1
	_G.WOW_PROJECT_CAMELOT = 18
	_G.WOW_PROJECT_ID = opts.projectId or 18

	local tocFields = readTocFields(opts.tocPath)
	_G.C_AddOns = {
		GetAddOnMetadata = function(addonName, field)
			if addonName ~= opts.addonName then
				return nil
			end
			return tocFields[field]
		end,
	}

	_G.CreateFrame = function()
		local frame = { events = {}, scripts = {} }
		function frame:RegisterEvent(event)
			self.events[event] = true
		end
		function frame:UnregisterEvent(event)
			self.events[event] = nil
		end
		function frame:SetScript(name, handler)
			self.scripts[name] = handler
		end
		client.frames[#client.frames + 1] = frame
		return frame
	end

	_G.SlashCmdList = {}
	_G.SLASH_LARUTADEL601 = nil
	_G.LaRutaDel60DB = nil

	function client.fire(event, ...)
		for _, frame in ipairs(client.frames) do
			local handler = frame.scripts.OnEvent
			if frame.events[event] and handler then
				handler(frame, event, ...)
			end
		end
	end

	return client
end

return WowMock
