local _, ns = ...

-- Waypoint arrow (spec §3.4): a rotated texture pointing at the current step's coords and a
-- distance label, both in their own unnamed frame. Updated on every engine tick (0.1 s), also
-- while hidden, so its visibility does not depend on zone events.
local Arrow = {}
ns.Arrow = Arrow

local L = ns.L

local SIZE = 48
-- Built-in client texture of an arrow pointing up. To be verified on Forever.
local ARROW_TEXTURE = "Interface\\Minimap\\MinimapArrow"

local frame, texture, label
local shownYards

local function build()
	frame = CreateFrame("Frame", nil, UIParent)
	frame:SetSize(SIZE, SIZE)
	frame:SetPoint("TOP", UIParent, "TOP", 0, -140)
	frame:SetFrameStrata("MEDIUM")

	texture = frame:CreateTexture(nil, "ARTWORK")
	texture:SetAllPoints()
	texture:SetTexture(ARROW_TEXTURE)

	label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	label:SetPoint("TOP", frame, "BOTTOM", 0, -2)

	frame:Hide()
end

function Arrow.Update()
	if not frame then
		build()
	end
	local distance, bearing = ns.Engine.Navigation()
	local facing = ns.Game.Facing()
	if distance == nil or bearing == nil or facing == nil then
		frame:Hide()
		return
	end
	texture:SetRotation(bearing - facing)
	local yards = math.floor(distance + 0.5)
	if yards ~= shownYards then
		shownYards = yards
		label:SetText(string.format(L.ARROW_DISTANCE, yards))
	end
	frame:Show()
end

ns.Engine.OnChange(Arrow.Update)
ns.Engine.OnTick(Arrow.Update)
