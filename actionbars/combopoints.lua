local _, ns = ...

-- Combo points as a row of wide segments spanning action bar 1, just above it.
-- One dot per possible point, lit up to the current count; hidden while you
-- have none.

local SIZE = 10 -- UI units tall, border included; width fills the bar
local GAP = 1 -- physical pixels between dots
local OFFSET = 1 -- physical pixels between the dots and the bar
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

-- Lays out `count` dots in whole pixels, spanning the bar's width exactly:
-- dot width is rounded down and the leftover pixels go one each to the
-- first dots, like the pet bar.
local function Layout(count)
	shown = count
	local px = ns.Pixels(holder, 1)
	local height = math.max(3, math.floor(SIZE / px + 0.5))
	local barWidth = math.floor(ns.actionbar:GetWidth() / px + 0.5)
	local inner = barWidth - (count - 1) * GAP
	local width = math.floor(inner / count)
	local extra = inner - width * count

	holder:SetSize(barWidth * px, height * px)
	holder:ClearAllPoints()
	holder:SetPoint('BOTTOMLEFT', ns.actionbar, 'TOPLEFT', 0, OFFSET * px)

	local x = 0
	for i, dot in ipairs(dots) do
		local w = width + (i <= extra and 1 or 0)
		dot:SetShown(i <= count)
		dot:SetSize(w * px, height * px)
		dot:ClearAllPoints()
		dot:SetPoint('TOPLEFT', holder, 'TOPLEFT', x * px, 0)
		x = x + w + GAP
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
