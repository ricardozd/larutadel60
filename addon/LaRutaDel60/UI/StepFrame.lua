local _, ns = ...

-- Movable step window (spec §3.3): route name, current step plus up to 2 upcoming steps, and the
-- Back / Done / Skip buttons. Unnamed frames; position and visibility saved in LaRutaDel60DB.ui.
local StepFrame = {}
ns.StepFrame = StepFrame

local L = ns.L

local WIDTH, LINE_HEIGHT, PADDING = 300, 16, 10
local BUTTON_WIDTH, BUTTON_HEIGHT = 80, 22
local LINE_COUNT = 3
local CURRENT_COLOR = "|cffffd100"
local UPCOMING_COLOR = "|cffb0b0b0"

local frame, title
local lines = {}
local backButton, doneButton, skipButton

local function uiDB()
	return ns.Game.DB().ui
end

local function savePosition()
	local point, _, relativePoint, x, y = frame:GetPoint()
	if point then
		uiDB().stepFrame = { point = point, relativePoint = relativePoint, x = x, y = y }
	end
end

local function restorePosition()
	local saved = uiDB().stepFrame
	frame:ClearAllPoints()
	if type(saved) == "table" and type(saved.point) == "string" then
		frame:SetPoint(saved.point, UIParent, saved.relativePoint or saved.point, saved.x or 0, saved.y or 0)
	else
		frame:SetPoint("RIGHT", UIParent, "RIGHT", -80, 120)
	end
end

local function newButton(label, x, onClick)
	local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	button:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
	button:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", x, PADDING)
	button:SetText(label)
	button:SetScript("OnClick", onClick)
	return button
end

local function build()
	frame = CreateFrame("Frame", nil, UIParent)
	frame:SetSize(WIDTH, PADDING * 3 + LINE_HEIGHT * (LINE_COUNT + 1) + BUTTON_HEIGHT)
	frame:SetFrameStrata("MEDIUM")
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function(self)
		self:StartMoving()
	end)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		savePosition()
	end)
	restorePosition()

	local background = frame:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints()
	background:SetColorTexture(0, 0, 0, 0.6)

	title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, -PADDING)
	title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PADDING, -PADDING)
	title:SetJustifyH("LEFT")
	title:SetWordWrap(false)

	for i = 1, LINE_COUNT do
		local line = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		local y = -PADDING - LINE_HEIGHT * i - 4
		line:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, y)
		line:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PADDING, y)
		line:SetJustifyH("LEFT")
		-- One row per line, so long step texts are truncated instead of overlapping the next line.
		line:SetWordWrap(false)
		lines[i] = line
	end

	local gap = (WIDTH - PADDING * 2 - BUTTON_WIDTH * 3) / 2
	backButton = newButton(L.BUTTON_BACK, PADDING, function()
		ns.Engine.Back()
	end)
	doneButton = newButton(L.BUTTON_DONE, PADDING + BUTTON_WIDTH + gap, function()
		ns.Engine.Done()
	end)
	skipButton = newButton(L.BUTTON_SKIP, PADDING + (BUTTON_WIDTH + gap) * 2, function()
		ns.Engine.Skip()
	end)

	if uiDB().hidden then
		frame:Hide()
	end
end

local function setLines(first, second, third)
	lines[1]:SetText(first or "")
	lines[2]:SetText(second or "")
	lines[3]:SetText(third or "")
end

function StepFrame.Refresh()
	if not frame then
		build()
	end
	local route, index, step = ns.Engine.Current()
	local locale = ns.Game.Locale()

	if route == nil then
		title:SetText(L.ADDON_TITLE)
		setLines(L.NO_ROUTE)
		backButton:Hide()
		doneButton:Hide()
		skipButton:Hide()
		return
	end

	title:SetText(ns.StepText.RouteName(route, locale))
	backButton:Show()
	if step == nil then
		setLines(CURRENT_COLOR .. L.ROUTE_COMPLETE .. "|r")
		doneButton:Hide()
		skipButton:Hide()
		return
	end

	local steps = route.steps
	for i = 1, LINE_COUNT do
		local upcoming = steps[index + i - 1]
		if upcoming then
			local color = i == 1 and CURRENT_COLOR or UPCOMING_COLOR
			lines[i]:SetText(color .. ns.StepText.For(upcoming, locale) .. "|r")
		else
			lines[i]:SetText("")
		end
	end
	doneButton:SetShown(ns.Engine.IsManual(step))
	skipButton:Show()
end

function StepFrame.Show()
	if not frame then
		build()
	end
	uiDB().hidden = nil
	frame:Show()
	StepFrame.Refresh()
end

function StepFrame.Hide()
	if not frame then
		build()
	end
	uiDB().hidden = true
	frame:Hide()
end

ns.Engine.OnChange(StepFrame.Refresh)
