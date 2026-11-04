local ADDON_NAME, ns = ...
local L = ns.L

ns.VERSION = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "dev"
ns.Guides = ns.Guides or {}

local function isForever()
	return WOW_PROJECT_CAMELOT ~= nil and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT
end

local function guideCount()
	local count = 0
	for _ in pairs(ns.Guides) do
		count = count + 1
	end
	return count
end

function ns.Print(message)
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99" .. L.ADDON_TITLE .. "|r: " .. message)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGIN" then
		LaRutaDel60DB = LaRutaDel60DB or {}
		if not isForever() then
			ns.Print(L.NOT_FOREVER)
		end
		ns.Print(L.LOADED)
		ns.Engine.Start()
	end
end)

SLASH_LARUTADEL601 = "/ruta"
SlashCmdList.LARUTADEL60 = function(input)
	input = (input or ""):match("^%s*(.-)%s*$")
	if input == "" then
		ns.Print(string.format(L.VERSION_INFO, ns.VERSION, guideCount()))
	else
		ns.Commands.Run(input)
	end
end
