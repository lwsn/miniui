local _, ns = ...
local oUF = ns.oUF

local Pixels, Snap, CreateText = ns.Pixels, ns.Snap, ns.CreateText

local TEXTURE = ns.media.texture
local HEALTH_HEIGHT = ns.layout.healthHeight
local POWER_HEIGHT = 16
local PADDING = 1 -- physical pixels between the backdrop edge and the bars, and between bars
local PARTY_WIDTH = 140
local PARTY_POWER_HEIGHT = 4

-- Units that keep the normal left-to-right layout. Every other unit is
-- mirrored horizontally: bars fill right-to-left and every anchor and
-- justification is flipped across the vertical axis. Matched on the unit's
-- base name, so 'party3' and 'raidpet12' resolve to 'party' and 'raidpet'.
local NORMAL = {
	player = true,
	pet = true,
	vehicle = true,
	party = true,
	partypet = true,
	raid = true,
	raidpet = true,
}

local function IsMirrored(unit)
	local base = unit and unit:match('^(%a+)')
	return not NORMAL[base]
end

local FLIP = {
	LEFT = 'RIGHT', RIGHT = 'LEFT',
	TOPLEFT = 'TOPRIGHT', TOPRIGHT = 'TOPLEFT',
	BOTTOMLEFT = 'BOTTOMRIGHT', BOTTOMRIGHT = 'BOTTOMLEFT',
}

-- Author layouts as if for the left-hand (unmirrored) frame and route anchors
-- and justification through these helpers; they flip when the frame is mirrored.
local function Point(frame, region, point, ...)
	if not frame.mirrored then
		return region:SetPoint(point, ...)
	end

	point = FLIP[point] or point
	local n = select('#', ...)
	if n == 0 then
		return region:SetPoint(point)
	end

	local a, b, c, d = ...
	if type(a) == 'number' then
		-- (point, x, y)
		return region:SetPoint(point, -a, b)
	elseif n <= 2 then
		-- (point, relativeTo[, relativePoint])
		return region:SetPoint(point, a, FLIP[b] or b)
	else
		-- (point, relativeTo, relativePoint, x, y)
		return region:SetPoint(point, a, FLIP[b] or b, -c, d)
	end
end

local function Justify(frame, fontString, justify)
	fontString:SetJustifyH(frame.mirrored and FLIP[justify] or justify)
end

local function CreateBar(parent)
	local bar = CreateFrame('StatusBar', nil, parent)
	bar:SetStatusBarTexture(TEXTURE)
	bar:SetReverseFill(parent.mirrored == true)

	local bg = bar:CreateTexture(nil, 'BACKGROUND')
	bg:SetAllPoints()
	bg:SetTexture(TEXTURE)
	bg:SetVertexColor(0.15, 0.15, 0.15)
	bar.bg = bg

	return bar
end

local function ApplyHealthColors(element, bar, bg, text)
	element:SetStatusBarColor(bar:GetRGB())
	element.bg:SetVertexColor(bg:GetRGB())
	if element.Text then
		element.Text:SetTextColor(text:GetRGB())
	end
end

-- Power background and text: the bar's colour, darkened and lightened the
-- same way as health's.
local function ApplyPowerColors(element, r, g, b)
	local shade, tint = ns.colors.BG_SHADE, ns.colors.TEXT_TINT
	element.bg:SetVertexColor(r * shade, g * shade, b * shade)
	local tr, tg, tb = r + (1 - r) * tint, g + (1 - g) * tint, b + (1 - b) * tint
	if element.Text then
		element.Text:SetTextColor(tr, tg, tb)
	end
	-- Level text's base colour; its tag overrides it except for even-level units.
	if element.Level then
		element.Level:SetTextColor(tr, tg, tb)
	end
end

-- Cast bar: fill, background and text from colors.cast, the uninterruptible
-- tint drawn over the fill.
local function ApplyCastColors(element)
	local shade, tint = ns.colors.BG_SHADE, ns.colors.TEXT_TINT
	local r, g, b = ns.colors.cast.normal:GetRGB()
	element:SetStatusBarColor(r, g, b)
	element.bg:SetVertexColor(r * shade, g * shade, b * shade)
	local tr, tg, tb = r + (1 - r) * tint, g + (1 - g) * tint, b + (1 - b) * tint
	element.Text:SetTextColor(tr, tg, tb)
	element.Time:SetTextColor(tr, tg, tb)
	element.Shield:SetVertexColor(ns.colors.cast.locked:GetRGB())
end

-- oUF callback: passes either a ColorMixin or raw r, g, b for non-standard powers.
local function PostUpdatePowerColor(element, unit, color, r, g, b)
	if b then
		ApplyPowerColors(element, r, g, b)
	elseif color then
		ApplyPowerColors(element, color:GetRGB())
	end
end

-- Replaces oUF's health colouring: the bar, its background and the health text
-- all follow the unit's health percentage (see colors.lua). Runs after every
-- health update, so the heal-prediction values it evaluates are current.
local function UpdateHealthColor(self, event, unit)
	if not unit or self.__unit ~= unit then return end
	local element = self.Health

	if not UnitIsConnected(unit) or (not UnitPlayerControlled(unit) and UnitIsTapDenied(unit)) then
		local inactive = ns.colors.inactive
		ApplyHealthColors(element, inactive.bar, inactive.bg, inactive.text)
	else
		local curves, values = ns.colors.health, element.values
		ApplyHealthColors(element,
			values:EvaluateCurrentHealthPercent(curves.bar),
			values:EvaluateCurrentHealthPercent(curves.bg),
			values:EvaluateCurrentHealthPercent(curves.text))
	end
end

-- Builds the frame's regions without any oUF wiring, so dev tools can render
-- the exact same layout on plain frames. Sets self.Health and self.Power (each
-- with .Text) and self.NameText.
local function Layout(self)
	local pad = Pixels(self, PADDING)
	-- Bar heights are snapped on their own and the frame is built from them,
	-- so the health bar is exactly as tall as an action button.
	local healthHeight = Snap(self, HEALTH_HEIGHT)
	local powerHeight = Snap(self, POWER_HEIGHT)
	-- As wide as action bar 1.
	self:SetSize(Pixels(self, ns.layout.MainPixels(self)), healthHeight + powerHeight + 3 * pad)

	-- Backdrop fills the frame exactly; the bars sit inside it, padded by a
	-- pixel, so the backdrop shows as a 1px outline and a 1px divider.
	local backdrop = self:CreateTexture(nil, 'BACKGROUND')
	backdrop:SetAllPoints()
	backdrop:SetColorTexture(0, 0, 0, 0.8)

	-- Power
	local Power = CreateBar(self)
	Point(self, Power, 'BOTTOMLEFT', pad, pad)
	Point(self, Power, 'BOTTOMRIGHT', -pad, pad)
	Power:SetHeight(powerHeight)
	self.Power = Power

	-- Health
	local Health = CreateBar(self)
	Point(self, Health, 'TOPLEFT', pad, -pad)
	Point(self, Health, 'TOPRIGHT', -pad, -pad)
	Point(self, Health, 'BOTTOMLEFT', Power, 'TOPLEFT', 0, pad)
	Point(self, Health, 'BOTTOMRIGHT', Power, 'TOPRIGHT', 0, pad)
	self.Health = Health

	-- Cast bar: a strip hung below the frame, its top divider being the
	-- frame's bottom border. Power, divider and cast bar together are as tall
	-- as the health bar, so the frame bottom lines up with the action bar's.
	-- The spell icon fills that height at the outer edge, over the power bar,
	-- and the cast bar starts 1px inside it.
	local Castbar = CreateBar(self)
	Castbar:SetFrameLevel(Power:GetFrameLevel() + 5) -- icon draws over the power bar
	Point(self, Castbar, 'TOPLEFT', self, 'BOTTOMLEFT', healthHeight + 2 * pad, 0)
	Point(self, Castbar, 'TOPRIGHT', self, 'BOTTOMRIGHT', -pad, 0)
	Castbar:SetHeight(math.max(pad, healthHeight - powerHeight - pad))
	self.Castbar = Castbar

	-- Black edges, all 0.8 like the frame's and never overlapping, so every
	-- border pixel is the same shade. The frame's own backdrop supplies the
	-- cast bar's top edge and the icon's edges beside the power bar.
	local function Edge(point1, rel1, relPoint1, x1, y1, point2, rel2, relPoint2, x2, y2)
		local edge = Castbar:CreateTexture(nil, 'BACKGROUND', nil, -8)
		Point(self, edge, point1, rel1, relPoint1, x1, y1)
		Point(self, edge, point2, rel2, relPoint2, x2, y2)
		edge:SetColorTexture(0, 0, 0, 0.8)
	end

	-- Cast bar: inner side and bottom (the icon's edge is its outer side).
	Edge('TOPLEFT', Castbar, 'TOPLEFT', 0, 0, 'BOTTOMRIGHT', Castbar, 'BOTTOMRIGHT', pad, -pad)

	local icon = Castbar:CreateTexture(nil, 'ARTWORK')
	Point(self, icon, 'TOPLEFT', Power, 'TOPLEFT', 0, 0)
	icon:SetSize(healthHeight, healthHeight)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	Castbar.Icon = icon

	-- Icon: divider toward the bars, bottom, and outer side below the frame.
	Edge('TOPLEFT', icon, 'TOPRIGHT', 0, 0, 'BOTTOMRIGHT', icon, 'BOTTOMRIGHT', pad, 0)
	Edge('TOPLEFT', icon, 'BOTTOMLEFT', -pad, 0, 'BOTTOMRIGHT', icon, 'BOTTOMRIGHT', pad, -pad)
	Edge('TOPLEFT', self, 'BOTTOMLEFT', 0, 0, 'BOTTOMRIGHT', icon, 'BOTTOMLEFT', 0, 0)

	-- Uninterruptible tint: covers only the fill, faded in by oUF.
	local shield = Castbar:CreateTexture(nil, 'ARTWORK', nil, 1)
	shield:SetAllPoints(Castbar:GetStatusBarTexture())
	shield:SetTexture(TEXTURE)
	Castbar.Shield = shield

	local spell = CreateText(Castbar, 12, 'semibold')
	Point(self, spell, 'LEFT', 4, 0)
	Point(self, spell, 'RIGHT', Castbar, 'RIGHT', -40, 0)
	Justify(self, spell, 'LEFT')
	spell:SetWordWrap(false)
	Castbar.Text = spell

	local time = CreateText(Castbar, 12, 'semibold')
	Point(self, time, 'RIGHT', Castbar, 'RIGHT', -4, 0)
	Justify(self, time, 'RIGHT')
	Castbar.Time = time

	ApplyCastColors(Castbar)

	-- Text
	local name = CreateText(Health, 13, 'semibold')
	Point(self, name, 'LEFT', 4, 0)
	Point(self, name, 'RIGHT', Health, 'CENTER', 20, 0)
	Justify(self, name, 'LEFT')
	name:SetWordWrap(false)
	self.NameText = name

	local hp = CreateText(Health, 20, 'semibold')
	Point(self, hp, 'RIGHT', -4, 0)
	Justify(self, hp, 'RIGHT')
	Health.Text = hp -- coloured by ApplyHealthColors

	local pp = CreateText(Power, 12, 'semibold')
	Point(self, pp, 'RIGHT', -4, 0)
	Justify(self, pp, 'RIGHT')
	Power.Text = pp -- coloured by ApplyPowerColors

	-- Level opposite the power text; coloured by its tag.
	local level = CreateText(Power, 12, 'semibold')
	Point(self, level, 'LEFT', 4, 0)
	Justify(self, level, 'LEFT')
	self.LevelText = level
	Power.Level = level -- coloured by ApplyPowerColors, unless the tag colours it

end

-- Party frames: the whole frame is as tall as the player's health bar, with a
-- thin text-less power strip at the bottom and no cast bar. Width and height
-- are set by the header's secure config (spawn.lua), since members can join
-- in combat; the bars only anchor to the frame's edges.
local function PartySize(frame)
	return Snap(frame, PARTY_WIDTH), Snap(frame, HEALTH_HEIGHT)
end

local function LayoutParty(self)
	local pad = Pixels(self, PADDING)

	local backdrop = self:CreateTexture(nil, 'BACKGROUND')
	backdrop:SetAllPoints()
	backdrop:SetColorTexture(0, 0, 0, 0.8)

	local Power = CreateBar(self)
	Point(self, Power, 'BOTTOMLEFT', pad, pad)
	Point(self, Power, 'BOTTOMRIGHT', -pad, pad)
	Power:SetHeight(Snap(self, PARTY_POWER_HEIGHT))
	self.Power = Power

	local Health = CreateBar(self)
	Point(self, Health, 'TOPLEFT', pad, -pad)
	Point(self, Health, 'TOPRIGHT', -pad, -pad)
	Point(self, Health, 'BOTTOMLEFT', Power, 'TOPLEFT', 0, pad)
	Point(self, Health, 'BOTTOMRIGHT', Power, 'TOPRIGHT', 0, pad)
	self.Health = Health

	local name = CreateText(Health, 12, 'semibold') -- as the player's power text
	Point(self, name, 'LEFT', 4, 0)
	Point(self, name, 'RIGHT', Health, 'RIGHT', -36, 0)
	Justify(self, name, 'LEFT')
	name:SetWordWrap(false)
	self.NameText = name

	local hp = CreateText(Health, 16, 'semibold')
	Point(self, hp, 'RIGHT', -4, 0)
	Justify(self, hp, 'RIGHT')
	Health.Text = hp

	-- Out of range members fade.
	self.Range = { insideAlpha = 1, outsideAlpha = 0.5 }
end

-- Tooltips. Blizzard's UnitFrame_OnEnter reads frame.unit, which oUF no longer
-- sets; oUF keeps the active unit (vehicle swaps included) in frame.__unit.
-- GameTooltip calls owner.UpdateTooltip periodically while shown.
local function UpdateTooltip(self)
	GameTooltip:SetUnit(self.__unit)
end

local function OnEnter(self)
	if not self.__unit then return end
	GameTooltip_SetDefaultAnchor(GameTooltip, self)
	UpdateTooltip(self)
	self.UpdateTooltip = UpdateTooltip
end

local function OnLeave(self)
	self.UpdateTooltip = nil
	GameTooltip:FadeOut()
end

local function Style(self, unit)
	self.mirrored = IsMirrored(unit)

	self:RegisterForClicks('AnyUp')
	self:SetScript('OnEnter', OnEnter)
	self:SetScript('OnLeave', OnLeave)

	local party = unit == 'party'
	if party then
		LayoutParty(self)
	else
		Layout(self)
	end

	self.Power.frequentUpdates = true
	self.Power.colorDisconnected = true
	self.Power.colorTapping = true
	self.Power.colorPower = true
	self.Power.PostUpdateColor = PostUpdatePowerColor

	self.Health.UpdateColor = UpdateHealthColor

	self:Tag(self.NameText, '[miniui:namecolor][name]')
	self:Tag(self.Health.Text, '[miniui:health]')
	if not party then
		self:Tag(self.Power.Text, '[perpp]')
		self:Tag(self.LevelText, '[miniui:level]')
	end

	if unit == 'target' then
		ns.auras.AttachTarget(self)
	end
end

-- Health text: 'Dead', 'Ghost' or 'Offline' in place of the percentage, not
-- before it (oUF joins separate tags, giving 'Dead0'). Status checks that
-- come back hidden are skipped and the percentage shows.
local function Known(value)
	return not (issecretvalue and issecretvalue(value))
end

oUF.Tags.Methods['miniui:health'] = function(unit)
	local connected = UnitIsConnected(unit)
	if Known(connected) and not connected then
		return 'Offline'
	end
	local dead, ghost = UnitIsDead(unit), UnitIsGhost(unit)
	if Known(dead) and dead then
		return 'Dead'
	elseif Known(ghost) and ghost then
		return 'Ghost'
	end
	return string.format('%d', UnitHealthPercent(unit, true, CurveConstants.ScaleTo100))
end
oUF.Tags.Events['miniui:health'] = 'UNIT_HEALTH UNIT_MAXHEALTH UNIT_CONNECTION PARTY_MEMBER_ENABLE PARTY_MEMBER_DISABLE'

-- Power text follows the fast power event, like the bar (frequentUpdates),
-- instead of the throttled UNIT_POWER_UPDATE.
oUF.Tags.Events.perpp = 'UNIT_MAXPOWER UNIT_POWER_FREQUENT'

oUF:RegisterStyle('miniui', Style)

-- Shared with dev tools.
ns.unitframes = {
	Layout = Layout,
	PartySize = PartySize,
	ApplyHealthColors = ApplyHealthColors,
	ApplyPowerColors = ApplyPowerColors,
}
