local _, ns = ...
local oUF = ns.oUF

local TEXTURE = [[Interface\Buttons\WHITE8x8]]
local WIDTH, HEIGHT = 220, 44
local POWER_HEIGHT = 8
local PADDING = 1 -- physical pixels between the backdrop edge and the bars, and between bars

-- UI units are not screen pixels unless the UI scale is exactly 768/screenHeight,
-- so a 1-unit offset can render as 1px on one edge and 2px on another. These
-- helpers work in real pixels for the frame's current effective scale.
local function Pixels(frame, n)
	return n * PixelUtil.GetPixelToUIUnitFactor() / frame:GetEffectiveScale()
end

-- Snap a UI-unit size to a whole, even number of pixels so a frame anchored by
-- its CENTER still has its edges on the pixel grid.
local function SnapEven(frame, size)
	local perPixel = Pixels(frame, 1)
	local pixels = math.max(2, 2 * math.floor(size / perPixel / 2 + 0.5))
	return pixels * perPixel
end

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

local function Style(self, unit)
	self.mirrored = IsMirrored(unit)

	self:RegisterForClicks('AnyUp')
	self:SetScript('OnEnter', UnitFrame_OnEnter)
	self:SetScript('OnLeave', UnitFrame_OnLeave)

	self:SetSize(SnapEven(self, WIDTH), SnapEven(self, HEIGHT))
	local pad = Pixels(self, PADDING)

	-- Backdrop fills the frame exactly; the bars sit inside it, padded by a
	-- pixel, so the backdrop shows as a 1px outline and a 1px divider.
	local backdrop = self:CreateTexture(nil, 'BACKGROUND')
	backdrop:SetAllPoints()
	backdrop:SetColorTexture(0, 0, 0, 0.8)

	-- Power
	local Power = CreateBar(self)
	Point(self, Power, 'BOTTOMLEFT', pad, pad)
	Point(self, Power, 'BOTTOMRIGHT', -pad, pad)
	Power:SetHeight(SnapEven(self, POWER_HEIGHT))
	Power.frequentUpdates = true
	Power.colorDisconnected = true
	Power.colorTapping = true
	Power.colorPower = true
	self.Power = Power

	-- Health
	local Health = CreateBar(self)
	Point(self, Health, 'TOPLEFT', pad, -pad)
	Point(self, Health, 'TOPRIGHT', -pad, -pad)
	Point(self, Health, 'BOTTOMLEFT', Power, 'TOPLEFT', 0, pad)
	Point(self, Health, 'BOTTOMRIGHT', Power, 'TOPRIGHT', 0, pad)
	Health.colorDisconnected = true
	Health.colorTapping = true
	Health.colorClass = true
	Health.colorReaction = true
	Health.colorHealth = true
	self.Health = Health

	-- Text
	local name = Health:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
	Point(self, name, 'LEFT', 4, 0)
	Point(self, name, 'RIGHT', Health, 'CENTER', 20, 0)
	Justify(self, name, 'LEFT')
	name:SetWordWrap(false)
	self:Tag(name, '[name]')

	local hp = Health:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
	Point(self, hp, 'RIGHT', -4, 0)
	Justify(self, hp, 'RIGHT')
	self:Tag(hp, '[dead][offline][perhp<$%]')

	local level = Health:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	Point(self, level, 'BOTTOMLEFT', Health, 'TOPLEFT', 0, 3)
	self:Tag(level, '[smartlevel] [rare]')
end

oUF:RegisterStyle('miniui', Style)
