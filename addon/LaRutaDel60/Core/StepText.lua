local _, ns = ...

-- Localized texts of steps and route names (spec §3.3).
local StepText = {}
ns.StepText = StepText

local L = ns.L

local QUEST_FORMATS = {
	accept = "STEP_ACCEPT",
	complete = "STEP_COMPLETE",
	turnin = "STEP_TURNIN",
}

local FIXED_TEXTS = {
	hearth = "STEP_HEARTH",
	fly = "STEP_FLY",
	train = "STEP_TRAIN",
}

-- A { enUS = ..., esES = ... } field in the given locale, falling back to enUS.
local function localized(field, locale)
	if type(field) ~= "table" then
		return nil
	end
	return field[locale] or field.enUS
end

-- One decimal place with "." as the separator in every locale (string.format follows the C locale).
local function oneDecimal(value)
	local tenths = math.floor(value * 10 + 0.5)
	local sign = ""
	if tenths < 0 then
		sign, tenths = "-", -tenths
	end
	return sign .. math.floor(tenths / 10) .. "." .. tenths % 10
end

local function questTitle(questId)
	local title = type(questId) == "number" and ns.Game.QuestTitle(questId)
	return title or string.format(L.QUEST_FALLBACK, tostring(questId))
end

function StepText.RouteName(route, locale)
	return localized(route.name, locale) or route.id
end

function StepText.For(step, locale)
	local own = localized(step.text, locale)
	if own then
		return own
	end
	local questFormat = QUEST_FORMATS[step.type]
	if questFormat then
		return string.format(L[questFormat], questTitle(step.questId))
	end
	if step.type == "goto" then
		local coords = step.coords or {}
		return string.format(L.STEP_GOTO, oneDecimal(coords.x or 0), oneDecimal(coords.y or 0))
	end
	local fixed = FIXED_TEXTS[step.type]
	if fixed then
		return L[fixed]
	end
	return ""
end
