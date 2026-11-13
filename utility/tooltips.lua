local _, ns = ...

-- Tooltips styled like the unit frames: flat dark body with a 1px black edge,
-- IBM Plex text without shadows, and a health bar hung below the tooltip in
-- the unit frames' flat texture and health colours.
--
-- Every tooltip that would use the default anchor (bottom-right of the
-- screen) follows the mouse instead, Blizzard's and ours alike. Same hook as
-- Leatrix Plus's cursor anchor, without its world-only condition. Our own
-- frames use GameTooltip_SetDefaultAnchor or ANCHOR_CURSOR directly.

local TOOLTIPS = { 'GameTooltip', 'ItemRefTooltip', 'ShoppingTooltip1', 'ShoppingTooltip2' }
local BODY = { 0.09, 0.09, 0.09, 0.85 } -- inside the edge; text sits on this
local BAR_HEIGHT = 8 -- UI units, edges excluded

-- Anchor -------------------------------------------------------------------------

hooksecurefunc('GameTooltip_SetDefaultAnchor', function(tooltip, parent)
	if tooltip and parent then
		tooltip:SetOwner(parent, 'ANCHOR_CURSOR')
	end
end)

-- Fonts ----------------------------------------------------------------------------

-- Font objects shared by every tooltip line.
local FONTS = {
	GameTooltipHeaderText = { 'semibold', 14 },
	GameTooltipText = { 'regular', 12 },
	GameTooltipTextSmall = { 'regular', 11 },
}

for name, def in next, FONTS do
	local font = _G[name]
	if font then
		font:SetFont(ns.media.font[def[1]], def[2], '')
		font:SetShadowOffset(0, 0)
		font:SetShadowColor(0, 0, 0, 0)
	end
end

-- Backdrop -------------------------------------------------------------------------

-- Our backdrop lives on Blizzard's NineSlice frame, whose own pieces are made
-- transparent (not hidden: tooltip code re-shows and recolours them on every
-- SetOwner). The tooltip fade animates the NineSlice's alpha, so the backdrop
-- fades with it instead of lingering at full opacity until the tooltip hides.
local function Skin(tooltip)
	if not tooltip or tooltip.miniuiSkinned then return end
	tooltip.miniuiSkinned = true

	local holder = tooltip.NineSlice or tooltip
	if tooltip.NineSlice then
		for _, region in ipairs({ tooltip.NineSlice:GetRegions() }) do
			region:SetAlpha(0)
		end
	end

	local px = ns.Pixels(tooltip, 1)

	local body = holder:CreateTexture(nil, 'BACKGROUND', nil, -7)
	body:SetPoint('TOPLEFT', px, -px)
	body:SetPoint('BOTTOMRIGHT', -px, px)
	body:SetColorTexture(unpack(BODY))

	-- 1px black edges around the body, not overlapping it.
	local function Edge()
		local edge = holder:CreateTexture(nil, 'BACKGROUND', nil, -8)
		edge:SetColorTexture(0, 0, 0, 1)
		return edge
	end
	local top = Edge()
	top:SetPoint('TOPLEFT')
	top:SetPoint('TOPRIGHT')
	top:SetHeight(px)
	local bottom = Edge()
	bottom:SetPoint('BOTTOMLEFT')
	bottom:SetPoint('BOTTOMRIGHT')
	bottom:SetHeight(px)
	local left = Edge()
	left:SetPoint('TOPLEFT', 0, -px)
	left:SetPoint('BOTTOMLEFT', 0, px)
	left:SetWidth(px)
	local right = Edge()
	right:SetPoint('TOPRIGHT', 0, -px)
	right:SetPoint('BOTTOMRIGHT', 0, px)
	right:SetWidth(px)
end

-- Health bar -----------------------------------------------------------------------

-- Hung below the tooltip, its top edge being the tooltip's bottom edge, like
-- the unit frames' cast bar.
local function SkinHealthBar()
	local bar = GameTooltipStatusBar
	if not bar then return end
	local px = ns.Pixels(GameTooltip, 1)

	bar:SetStatusBarTexture(ns.media.texture)
	bar:ClearAllPoints()
	bar:SetPoint('TOPLEFT', GameTooltip, 'BOTTOMLEFT', px, 0)
	bar:SetPoint('TOPRIGHT', GameTooltip, 'BOTTOMRIGHT', -px, 0)
	bar:SetHeight(ns.Snap(GameTooltip, BAR_HEIGHT))

	local bg = bar:CreateTexture(nil, 'BACKGROUND', nil, -7)
	bg:SetAllPoints()
	bg:SetTexture(ns.media.texture)
	bar.miniuiBG = bg

	-- Sides and bottom; the tooltip's bottom edge is the top.
	local edge = bar:CreateTexture(nil, 'BACKGROUND', nil, -8)
	edge:SetPoint('TOPLEFT', -px, 0)
	edge:SetPoint('BOTTOMRIGHT', px, -px)
	edge:SetColorTexture(0, 0, 0, 1)
end

-- Same colours as the unit frames' health (unitframes/colors.lua), resolved
-- by the client since health may be secret.
local function ColorHealthBar()
	local bar = GameTooltipStatusBar
	if not (bar and bar.miniuiBG) then return end
	local _, unit = GameTooltip:GetUnit()
	if not unit or (issecretvalue and issecretvalue(unit)) then
		unit = 'mouseover'
	end
	if not UnitExists(unit) then return end

	local connected, tapped = UnitIsConnected(unit), not UnitPlayerControlled(unit) and UnitIsTapDenied(unit)
	local known = not (issecretvalue and (issecretvalue(connected) or issecretvalue(tapped)))
	if known and (not connected or tapped) then
		bar:SetStatusBarColor(ns.colors.inactive.bar:GetRGB())
		bar.miniuiBG:SetVertexColor(ns.colors.inactive.bg:GetRGB())
		return
	end
	local curves = ns.colors.health
	local color, bg = UnitHealthPercent(unit, true, curves.bar), UnitHealthPercent(unit, true, curves.bg)
	if color and color.GetRGB then bar:SetStatusBarColor(color:GetRGB()) end
	if bg and bg.GetRGB then bar.miniuiBG:SetVertexColor(bg:GetRGB()) end
end

-- Setup ----------------------------------------------------------------------------

local loader = CreateFrame('Frame')
loader:RegisterEvent('PLAYER_LOGIN')
loader:SetScript('OnEvent', function()
	for _, name in ipairs(TOOLTIPS) do
		Skin(_G[name])
	end
	SkinHealthBar()
	if GameTooltipStatusBar then
		GameTooltipStatusBar:HookScript('OnValueChanged', ColorHealthBar)
		-- The health bar hangs outside the NineSlice; fade it along with it.
		local nineSlice = GameTooltip.NineSlice
		if nineSlice then
			GameTooltip:HookScript('OnUpdate', function()
				GameTooltipStatusBar:SetAlpha(nineSlice:GetAlpha())
			end)
		end
	end
	if TooltipDataProcessor and Enum.TooltipDataType then
		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip)
			if tooltip == GameTooltip then ColorHealthBar() end
		end)
	end
end)
