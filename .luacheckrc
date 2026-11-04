std = "lua51"
max_line_length = 120
exclude_files = { ".vendor/**", "addon/LaRutaDel60/Libs/**" }

-- Globals the addon is allowed to write.
globals = {
	"LaRutaDel60DB",
	"SLASH_LARUTADEL601",
	SlashCmdList = { fields = { "LARUTADEL60" } },
}

-- WoW API the addon reads. Add every new API here (see docs/api/forever-api.md).
read_globals = {
	"C_AddOns",
	"C_Map",
	"C_QuestLog",
	"C_Timer",
	"CreateFrame",
	"CreateVector2D",
	"DEFAULT_CHAT_FRAME",
	"GetLocale",
	"GetPlayerFacing",
	"GetQuestLogIndexByID",
	"GetQuestLogTitle",
	"GetRealmName",
	"UIParent",
	"UnitClass",
	"UnitFactionGroup",
	"UnitLevel",
	"UnitName",
	"UnitRace",
	"WOW_PROJECT_CAMELOT",
	"WOW_PROJECT_ID",
}

files["addon/LaRutaDel60/Guides/**"] = { max_line_length = false }

files["tests/**"] = {
	std = "max+busted",
	-- The client emulation installs WoW globals on purpose.
	ignore = { "111", "112", "113", "121", "122", "142", "143" },
}

files["tools/tests/**/*.lua"] = { std = "max" }
