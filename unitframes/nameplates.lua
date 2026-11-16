local _, ns = ...
local oUF = ns.oUF

-- Enemy nameplates, styled after the unit frames' power bar: one flat bar the
-- power bar's height, name on the left and health percentage on the right,
-- inside it, no outline. Your own debuffs sit above the bar and a cast bar
-- hangs below. The target is marked by Blizzard's enlarged scale only; a mob
-- you have threat on gets a muted red edge. Friendly plates (where shown at
-- all) are reduced to the name.
--
-- Built on oUF's nameplate driver, which keeps Blizzard's plates (widgets,
-- soft target icons, protected friendly plates in instances) underneath and
-- disables only their unit frame.
--
-- Edges are drawn, not left as gaps. Plates move with the camera at
-- fractional screen positions, and a 1px gap between a backdrop and the bar
-- inside it depends on two rectangles rounding the same way, so it flickers
-- between zero and two pixels. Here the bars fill their whole box, 1px edge
-- textures are drawn over them, and the layout rounds to whole pixels
-- (see RoundPlate).

local Pixels, Snap, CreateText = ns.Pixels, ns.Snap, ns.CreateText

local WIDTH = 120
local HEALTH_HEIGHT = 16 -- UI units, edges excluded; the power bar's height
local TEXT_SIZE = 12 -- the power bar's text size
local CAST_HEIGHT = 10
local CAST_TEXT_SIZE = 9
local AURA_SIZE = 18
local AURA_MAX = 6

-- Edge colour while you have threat on the mob (any UnitThreatSituation
-- status above 0: pulling ahead of the tank, or it's on you).
local THREAT = { 0.72, 0.20, 0.16 } -- muted red

local function Known(value)
	return not (issecretvalue and issecretvalue(value))
end

-- Edges ------------------------------------------------------------------------------

-- Plates move with the camera at fractional positions, and each region
-- rounds to the pixel grid on its own, so 1px edges blink out one at a time.
-- This client can round a frame's whole layout to the nearest pixel instead
-- (Plater does this for its plates and aura buttons). Aura containers are
-- skipped: their buttons get it from InitAuraButton when created.
local RoundLayout = PixelUtil.SetRoundLayoutToNearestPixelRecursively

local function RoundPlate(self)
	if not RoundLayout then return end
	self:SetRoundLayoutToNearestPixel(true)
	for _, region in ipairs({ self:GetRegions() }) do
		region:SetRoundLayoutToNearestPixel(true)
	end
	for _, child in ipairs({ self:GetChildren() }) do
		if child ~= self.DebuffContainer then
			RoundLayout(child, true)
		end
	end
end

local function CreateEdge(parent, layer, sublevel)
	local edge = parent:CreateTexture(nil, layer, nil, sublevel)
	edge:SetColorTexture(0, 0, 0, 1)
	return edge
end

-- Four 1px edge textures on `parent`, positioned by PlaceEdges.
local function CreateEdges(parent, layer, sublevel)
	local edges = {}
	for i = 1, 4 do
		edges[i] = CreateEdge(parent, layer, sublevel)
	end
	return edges
end

-- Outlines the box from `topLeft`'s TOPLEFT to `bottomRight`'s BOTTOMRIGHT,
-- inside it. Top and bottom run the full width; the sides fit between them.
local function PlaceEdges(edges, topLeft, bottomRight, px)
	local top, bottom, left, right = unpack(edges)
	for _, edge in ipairs(edges) do
		edge:ClearAllPoints()
	end
	top:SetPoint('TOPLEFT', topLeft, 'TOPLEFT')
	top:SetPoint('TOPRIGHT', bottomRight, 'TOPRIGHT')
	top:SetHeight(px)
	bottom:SetPoint('BOTTOMLEFT', topLeft, 'BOTTOMLEFT')
	bottom:SetPoint('BOTTOMRIGHT', bottomRight, 'BOTTOMRIGHT')
	bottom:SetHeight(px)
	left:SetPoint('TOPLEFT', topLeft, 'TOPLEFT', 0, -px)
	left:SetPoint('BOTTOMLEFT', topLeft, 'BOTTOMLEFT', 0, px)
	left:SetWidth(px)
	right:SetPoint('TOPRIGHT', bottomRight, 'TOPRIGHT', 0, -px)
	right:SetPoint('BOTTOMRIGHT', bottomRight, 'BOTTOMRIGHT', 0, px)
	right:SetWidth(px)
end

local function ColorEdges(edges, r, g, b)
	for _, edge in ipairs(edges) do
		edge:SetColorTexture(r, g, b, 1)
	end
end

-- Aura buttons ---------------------------------------------------------------------

-- The shared aura button leaves its edge as a 1px gap around the icon, which
-- flickers on a moving plate like the bars did. Here the icon fills the
-- button and drawn edges cover its outer pixel, above the elapsed-time bar and
-- below nothing that matters (timer and count sit well inside).
local function InitAuraButton(element, options, button)
	ns.auras.InitButton(element, options, button)
	button.Icon:ClearAllPoints()
	button.Icon:SetAllPoints(button)

	local border = CreateFrame('Frame', nil, button)
	border:SetAllPoints()
	border:SetFrameLevel(button.Elapsed:GetFrameLevel() + 1)
	PlaceEdges(CreateEdges(border, 'OVERLAY', 0), button, button, Pixels(button, 1))

	if RoundLayout then
		RoundLayout(button, true)
	end
end

-- Threat ---------------------------------------------------------------------------

-- Threat tints the edges; a secret or empty status leaves them black. Not
-- oUF's ThreatIndicator, which compares the status in Lua.
local function UpdateThreat(self, _, unit)
	if unit and unit ~= self.__unit then return end
	unit = self.__unit
	local status = unit and UnitExists(unit) and UnitThreatSituation('player', unit)
	if Known(status) and status and status > 0 then
		ColorEdges(self.Edges, unpack(THREAT))
	else
		ColorEdges(self.Edges, 0, 0, 0)
	end
end

-- Enemy or friendly --------------------------------------------------------------

-- Friendly plates show only the name, outlined since it then sits on the
-- world. Unknown (secret) counts as enemy.
local function UpdateReaction(self)
	local unit = self.__unit
	local canAttack = unit and UnitCanAttack('player', unit)
	local enemy = (not Known(canAttack) or canAttack) and true or false
	self.Bars:SetShown(enemy)
	self.DebuffContainer:SetShown(enemy)
	self.NameText:SetParent(enemy and self.Health or self)
	self.NameText:SetFont(ns.media.font.semibold, TEXT_SIZE, enemy and '' or 'OUTLINE')
end

-- Layout ---------------------------------------------------------------------------

-- Everything sized in pixels, redone whenever a plate is (re)used, since
-- pixel sizes depend on the plate's effective scale.
--
-- Health box: Bars, edges included. Cast box: below it, its top edge on the
-- health box's bottom edge; icon square at the left (edges included), then a
-- divider, then the cast bar.
local function Relayout(self)
	local px = Pixels(self, 1)
	local healthHeight = Snap(self, HEALTH_HEIGHT)
	local castHeight = Snap(self, CAST_HEIGHT)
	local width = Snap(self, WIDTH)

	local bars = self.Bars
	bars:SetSize(width, healthHeight + 2 * px)
	self.Health:SetAllPoints(bars)
	PlaceEdges(self.Edges, bars, bars, px)

	-- Cast bar: from the divider to the right end, the cast box's full height.
	local Castbar = self.Castbar
	Castbar:ClearAllPoints()
	Castbar:SetPoint('TOPLEFT', bars, 'BOTTOMLEFT', castHeight + px, px)
	Castbar:SetPoint('TOPRIGHT', bars, 'BOTTOMRIGHT', 0, px)
	Castbar:SetHeight(castHeight + 2 * px)

	local icon = Castbar.Icon
	icon:ClearAllPoints()
	icon:SetPoint('TOPRIGHT', Castbar, 'TOPLEFT', 0, -px)
	icon:SetSize(castHeight, castHeight)

	-- Cast box outline, from the icon's outer edge to the cast bar's end.
	local castEdges = self.CastEdges
	PlaceEdges(castEdges, self.CastBox, Castbar, px)
	self.CastBox:ClearAllPoints()
	self.CastBox:SetPoint('TOPLEFT', Castbar, 'TOPLEFT', -(castHeight + px), 0)
	self.CastBox:SetPoint('BOTTOMRIGHT', Castbar, 'BOTTOMLEFT', 0, 0)

	local divider = self.CastDivider
	divider:ClearAllPoints()
	divider:SetPoint('TOPLEFT', Castbar, 'TOPLEFT')
	divider:SetPoint('BOTTOMLEFT', Castbar, 'BOTTOMLEFT')
	divider:SetWidth(px)

	local auras = self.DebuffContainer
	auras:ClearAllPoints()
	auras:SetSize(width, AURA_SIZE)
	auras:SetPoint('BOTTOMLEFT', bars, 'TOPLEFT', 0, px)
end

local function Style(self)
	local px = Pixels(self, 1)

	-- Health box, hidden with everything in it on friendly plates.
	local bars = CreateFrame('Frame', nil, self)
	bars:SetPoint('CENTER')
	self.Bars = bars

	local Health = ns.unitframes.CreateBar(bars)
	Health.UpdateColor = ns.unitframes.UpdateHealthColor
	Health.colorReaction = true -- flat hostile/neutral colours
	self.Health = Health

	-- Edges above the bar and its text.
	local border = CreateFrame('Frame', nil, bars)
	border:SetAllPoints()
	border:SetFrameLevel(Health:GetFrameLevel() + 2)
	self.Edges = CreateEdges(border, 'OVERLAY', 0)

	-- Text inside the bar, like the power bar's level and percentage.
	local name = CreateText(Health, TEXT_SIZE, 'semibold')
	name:SetPoint('LEFT', Health, 'LEFT', 4, 0)
	name:SetJustifyH('LEFT')
	name:SetWordWrap(false)
	self.NameText = name
	self:Tag(name, '[miniui:namecolor][miniui:name(14)]')

	local hp = CreateText(Health, TEXT_SIZE, 'semibold')
	hp:SetPoint('RIGHT', -4, 0)
	hp:SetJustifyH('RIGHT')
	Health.Text = hp -- coloured by the health curves
	name:SetPoint('RIGHT', hp, 'LEFT', -6, 0) -- up to the health text
	self:Tag(hp, '[miniui:health]')

	-- Cast bar and its box. The icon, edges and divider sit on a frame above
	-- the bar, parented to it so they show and hide with the cast.
	local Castbar = ns.unitframes.CreateBar(bars)
	self.Castbar = Castbar

	local castBorder = CreateFrame('Frame', nil, Castbar)
	castBorder:SetAllPoints()
	castBorder:SetFrameLevel(Castbar:GetFrameLevel() + 2)

	self.CastBox = castBorder:CreateTexture(nil, 'BACKGROUND') -- icon area, black behind the icon
	self.CastBox:SetColorTexture(0, 0, 0, 1)

	local icon = castBorder:CreateTexture(nil, 'ARTWORK')
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	Castbar.Icon = icon

	self.CastEdges = CreateEdges(castBorder, 'OVERLAY', 0)
	self.CastDivider = CreateEdge(castBorder, 'OVERLAY', 0)

	local shield = Castbar:CreateTexture(nil, 'ARTWORK', nil, 1)
	shield:SetAllPoints(Castbar:GetStatusBarTexture())
	shield:SetTexture(ns.media.texture)
	Castbar.Shield = shield

	local spell = CreateText(castBorder, CAST_TEXT_SIZE, 'semibold')
	spell:SetPoint('LEFT', Castbar, 'LEFT', 4, 0)
	spell:SetPoint('RIGHT', Castbar, 'RIGHT', -24, 0)
	spell:SetJustifyH('LEFT')
	spell:SetWordWrap(false)
	Castbar.Text = spell

	local time = CreateText(castBorder, CAST_TEXT_SIZE, 'semibold')
	time:SetPoint('RIGHT', Castbar, 'RIGHT', -4, 0)
	time:SetJustifyH('RIGHT')
	Castbar.Time = time

	ns.unitframes.ApplyCastColors(Castbar)

	-- Your debuffs, 1px above the bar.
	local auras = self:CreateAuras({
		initialAnchor = 'BOTTOMLEFT',
		growthX = 'RIGHT',
		growthY = 'UP',
		layoutLimit = Snap(self, WIDTH),
	})
	auras:AddGroup('HARMFUL|PLAYER', {
		width = AURA_SIZE, -- square, unlike the strips elsewhere
		height = AURA_SIZE,
		maxFrameCount = AURA_MAX,
		disableMouse = true,
		layout = { elementSpacing = px, lineSpacing = px },
		sortDirection = AuraContainerSortDirection.Normal, -- shortest remaining first
		CreateButton = InitAuraButton,
	})
	self.DebuffContainer = auras

	Relayout(self)
	RoundPlate(self)

	self:RegisterEvent('UNIT_THREAT_SITUATION_UPDATE', UpdateThreat)
	self:RegisterEvent('UNIT_THREAT_LIST_UPDATE', UpdateThreat)
end

oUF:RegisterStyle('miniuiNameplate', Style)

-- Blizzard scales plates by distance and enlarges the target's; fixed at one
-- so pixel sizes stay whole. Names differ between client versions, so only
-- CVars this client has are set.
-- The target keeps Blizzard's enlarged scale: layout rounding (RoundPlate)
-- keeps its edges whole at any scale. It was pinned to 1 for a while, and
-- CVars persist, so it's set back to the client default rather than left.
local SCALE_CVARS = {
	'nameplateGlobalScale', 'nameplateMinScale', 'nameplateMaxScale',
	'nameplateLargerScale',
}
local DEFAULT_CVARS = { 'nameplateSelectedScale' }

local function ScaleCVars()
	local cvars = {}
	for _, name in ipairs(SCALE_CVARS) do
		if C_CVar.GetCVar(name) ~= nil then
			cvars[name] = 1
		end
	end
	for _, name in ipairs(DEFAULT_CVARS) do
		local default = C_CVar.GetCVarDefault(name)
		if default ~= nil then
			cvars[name] = default
		end
	end
	return cvars
end

oUF:Factory(function(self)
	self:SetActiveStyle('miniuiNameplate')
	local driver = self:SpawnNamePlates('miniuiNameplate')
	local px = ns.Pixels(UIParent, 1)
	-- Click area: the health box.
	driver:SetSize(ns.Snap(UIParent, WIDTH), ns.Snap(UIParent, HEALTH_HEIGHT) + 2 * px)
	driver:SetCVars(ScaleCVars())
	driver:SetAddedCallback(function(plate)
		Relayout(plate)
		UpdateReaction(plate)
		UpdateThreat(plate)
	end)
end)
