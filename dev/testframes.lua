-- Dev tool: /mtest toggles a grid of mock unit frames, one row per class and
-- one column per health step, built with the real unit frame layout and
-- colours. Remove from the .toc when no longer needed.

local _, ns = ...
local oUF = ns.oUF

local STEPS = { 1, 25, 50, 75, 100 }
local GAP, PAD, HEADER = 8, 12, 40
local MAX_HEIGHT = 760

-- Primary power per class for the mock power bar; anything else shows mana.
local CLASS_POWER = {
	WARRIOR = 'RAGE',
	ROGUE = 'ENERGY',
	MONK = 'ENERGY',
	DEATHKNIGHT = 'RUNIC_POWER',
	DEMONHUNTER = 'FURY',
}

local frame

local function SortedClasses()
	local classes = {}
	for class in next, oUF.colors.class do
		if LOCALIZED_CLASS_NAMES_MALE[class] then
			table.insert(classes, class)
		end
	end
	table.sort(classes, function(a, b)
		return LOCALIZED_CLASS_NAMES_MALE[a] < LOCALIZED_CLASS_NAMES_MALE[b]
	end)
	return classes
end

local function MockFrame(parent, class, pct)
	local cell = CreateFrame('Frame', nil, parent)
	ns.unitframes.Layout(cell)
	cell.Castbar:Hide() -- hangs below the frame, into the next grid row

	local health = cell.Health
	health:SetMinMaxValues(0, 100)
	health:SetValue(pct)
	health.Text:SetText(pct)

	local curves = ns.colors.health
	local x = pct / 100
	ns.unitframes.ApplyHealthColors(health,
		curves.bar:Evaluate(x), curves.bg:Evaluate(x), curves.text:Evaluate(x))

	local power = oUF.colors.power[CLASS_POWER[class]] or oUF.colors.power.MANA
	cell.Power:SetMinMaxValues(0, 100)
	cell.Power:SetValue(pct)
	cell.Power:SetStatusBarColor(power:GetRGB())
	cell.Power.Text:SetText(pct)
	ns.unitframes.ApplyPowerColors(cell.Power, power:GetRGB())

	cell.NameText:SetText(ns.colors.class[class] .. LOCALIZED_CLASS_NAMES_MALE[class])
	return cell
end

local function Build()
	frame = CreateFrame('Frame', 'miniuiTestFrames', UIParent)
	frame:SetFrameStrata('DIALOG')
	frame:SetPoint('CENTER')
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag('LeftButton')
	frame:SetScript('OnDragStart', frame.StartMoving)
	frame:SetScript('OnDragStop', frame.StopMovingOrSizing)
	table.insert(UISpecialFrames, frame:GetName()) -- Escape closes it

	local bg = frame:CreateTexture(nil, 'BACKGROUND')
	bg:SetAllPoints()
	bg:SetColorTexture(0.05, 0.05, 0.05, 0.97)

	local title = frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	title:SetPoint('TOPLEFT', PAD, -PAD)
	title:SetText('miniui test frames   —   drag to move, wheel to scroll, Esc to close')

	local scroll = CreateFrame('ScrollFrame', nil, frame)
	scroll:SetPoint('TOPLEFT', PAD, -PAD - HEADER)
	scroll:SetPoint('BOTTOMRIGHT', -PAD, PAD)
	scroll:EnableMouseWheel(true)
	scroll:SetScript('OnMouseWheel', function(self, delta)
		local y = self:GetVerticalScroll() - delta * 60
		self:SetVerticalScroll(math.max(0, math.min(y, self:GetVerticalScrollRange())))
	end)

	local content = CreateFrame('Frame', nil, scroll)
	scroll:SetScrollChild(content)

	local cellW, cellH
	local classes = SortedClasses()
	for row, class in ipairs(classes) do
		for col, pct in ipairs(STEPS) do
			local cell = MockFrame(content, class, pct)
			cellW, cellH = cell:GetSize()
			PixelUtil.SetPoint(cell, 'TOPLEFT', content, 'TOPLEFT',
				(col - 1) * (cellW + GAP), -(row - 1) * (cellH + GAP))
		end
	end

	local width = #STEPS * (cellW + GAP) - GAP
	local height = #classes * (cellH + GAP) - GAP
	content:SetSize(width, height)

	for col, pct in ipairs(STEPS) do
		local label = frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
		label:SetPoint('BOTTOM', scroll, 'TOPLEFT', (col - 1) * (cellW + GAP) + cellW / 2, 6)
		label:SetText(pct .. '%')
	end

	frame:SetSize(width + PAD * 2, math.min(height + PAD * 2 + HEADER, MAX_HEIGHT))
end

SLASH_MINIUITEST1 = '/mtest'
SlashCmdList.MINIUITEST = function()
	if not frame then
		Build()
	else
		frame:SetShown(not frame:IsShown())
	end
end
