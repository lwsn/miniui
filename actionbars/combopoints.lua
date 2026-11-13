local _, ns = ...

-- Combo points as a row of square dots, centred just above action bar 1.
-- One dot per possible point, lit up to the current count; hidden while you
-- have none.

local SIZE = 10 -- UI units per dot, border included
local GAP = 2 -- physical pixels between dots
local OFFSET = 3 -- physical pixels between the dots and the bar
local MAX = 10

local COLOR = { 0.75, 0.35, 0.15 } -- muted orange-red, clear of energy's yellow
local UNLIT_SHADE = 0.35 -- empty dots: the colour darkened, like bar backgrounds

local COMBO = Enum.PowerType.ComboPoints

local holder = CreateFrame('Frame', 'miniuiComboPoints', ns.actionbar)
holder:Hide()

local dots = {}
for i = 1, MAX do
	local dot = CreateFrame('Frame', nil, holder)
	local border = dot:CreateTexture(nil, 'BACKGROUND')
	border:SetAllPoints()
	border:SetColorTexture(0, 0, 0, 1)
	dot.fill = dot:CreateTexture(nil, 'ARTWORK')
	dots[i] = dot
end

local shown = 0 -- number of dots laid out

-- Lays out `count` dots in whole pixels, centred on the bar.
local function Layout(count)
	shown = count
	local px = ns.Pixels(holder, 1)
	local size = math.max(3, math.floor(SIZE / px + 0.5))
	local width = count * size + (count - 1) * GAP
	local barWidth = math.floor(ns.actionbar:GetWidth() / px + 0.5)

	holder:SetSize(width * px, size * px)
	holder:ClearAllPoints()
	holder:SetPoint('BOTTOMLEFT', ns.actionbar, 'TOPLEFT', math.floor((barWidth - width) / 2) * px, OFFSET * px)

	for i, dot in ipairs(dots) do
		dot:SetShown(i <= count)
		dot:SetSize(size * px, size * px)
		dot:ClearAllPoints()
		dot:SetPoint('TOPLEFT', holder, 'TOPLEFT', (i - 1) * (size + GAP) * px, 0)
		dot.fill:ClearAllPoints()
		dot.fill:SetPoint('TOPLEFT', px, -px)
		dot.fill:SetPoint('BOTTOMRIGHT', -px, px)
	end
end

local function Update()
	local cur, max = UnitPower('player', COMBO), UnitPowerMax('player', COMBO)
	if issecretvalue and (issecretvalue(cur) or issecretvalue(max)) then
		return
	end
	max = math.min(MAX, max or 0)
	if max == 0 or (cur or 0) == 0 then
		holder:Hide()
		return
	end
	if max ~= shown then
		Layout(max)
	end

	local r, g, b = unpack(COLOR)
	for i = 1, max do
		if i <= cur then
			dots[i].fill:SetColorTexture(r, g, b)
		else
			dots[i].fill:SetColorTexture(r * UNLIT_SHADE, g * UNLIT_SHADE, b * UNLIT_SHADE)
		end
	end
	holder:Show()
end

holder:RegisterEvent('PLAYER_LOGIN')
holder:SetScript('OnEvent', function(_, event)
	if event == 'PLAYER_LOGIN' then
		holder:RegisterUnitEvent('UNIT_POWER_FREQUENT', 'player')
		holder:RegisterUnitEvent('UNIT_MAXPOWER', 'player')
		holder:RegisterUnitEvent('UNIT_DISPLAYPOWER', 'player')
		holder:RegisterEvent('PLAYER_TARGET_CHANGED') -- clients where points live on the target
		holder:RegisterEvent('PLAYER_ENTERING_WORLD')
		holder:RegisterEvent('UI_SCALE_CHANGED')
		holder:RegisterEvent('DISPLAY_SIZE_CHANGED')
	elseif event == 'UI_SCALE_CHANGED' or event == 'DISPLAY_SIZE_CHANGED' then
		shown = 0 -- re-layout at the new scale
	end
	Update()
end)
