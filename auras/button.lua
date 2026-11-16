local _, ns = ...
local oUF = ns.oUF

-- Aura data is processed by the client inside AuraContainer frames; Lua only
-- defines groups, layout and what each button is made of. Buttons here are a
-- wide icon strip (cropped to fit) on a black plate with a 1px edge, plus an
-- optional 1px coloured ring just inside it (buff, debuff or dispel type,
-- options.edgeColor / dispelBorder). Neighbours overlap by 1px so they share
-- their black edge. Instead of
-- a cooldown swirl, a translucent dark bar grows over the icon as the aura's
-- time passes. Outlined text on the icon: stack count left, timer right.
-- options.mirrored flips all of it: the bar fills from the left and the
-- texts swap sides, as on mirrored unit frames.

ns.auras = {
	WIDTH = 32, -- UI units, snapped to whole pixels per container
	HEIGHT = 16,
	-- Inner ring tints (options.edgeColor). A debuff's dispel type colour
	-- replaces its tint.
	BUFF_EDGE = { 0.16, 0.30, 0.17 }, -- dark green
	DEBUFF_EDGE = { 0.36, 0.13, 0.12 }, -- dark red
}

local ELAPSED_COLOR = { 0, 0, 0, 0.6 } -- the part of the icon whose time has passed

-- The elapsed bar is pushed straight to its value: an eased push would
-- restart from empty whenever any aura on the unit changes. Elapsed rather than
-- remaining time, so auras without a duration show no bar at all.
local INTERPOLATION = Enum.StatusBarInterpolation
	and (Enum.StatusBarInterpolation.Immediate or Enum.StatusBarInterpolation.None)
local ELAPSED = Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.ElapsedTime

-- Timer text: a bare number, with no unit. Brightness tells the unit
-- instead: white for seconds ("8.2", then "42"), fading through three greys
-- for minutes, minutes past ten, and hours. The client formats it, since the
-- remaining time itself is never handed to Lua: each breakpoint applies from
-- its threshold (in seconds) up to the next one. Whole units round down, so
-- a grey "1" means at least a minute is left.
local DOWN = Enum.NumericRuleFormatRounding and Enum.NumericRuleFormatRounding.Down

local FADES = { -- from threshold (seconds): unit (seconds), text grey
	{ from = 60, unit = 60, grey = 0.75 }, -- minutes
	{ from = 600, unit = 60, grey = 0.58 }, -- ten minutes or more
	{ from = 3600, unit = 3600, grey = 0.42 }, -- hours
}

local durationFormatter
if C_StringUtil.CreateNumericRuleFormatter then
	durationFormatter = C_StringUtil.CreateNumericRuleFormatter()
	durationFormatter:AddBreakpoint({ threshold = 0, format = '%.1f', step = 0.1 })
	durationFormatter:AddBreakpoint({ threshold = 10, format = '%d', step = 1, rounding = DOWN })
	for _, fade in ipairs(FADES) do
		local hex = ('%02x'):format(math.floor(fade.grey * 255 + 0.5))
		durationFormatter:AddBreakpoint({
			threshold = fade.from,
			format = '|cff' .. hex:rep(3) .. '%d|r',
			components = { { div = fade.unit, step = 1, rounding = DOWN } },
		})
	end
else
	-- Fallback: Blizzard's style, "42 m".
	durationFormatter = C_StringUtil.CreateSecondsFormatter()
	durationFormatter:SetDefaultAbbreviation(Enum.SecondsFormatterAbbreviation.OneLetter)
	durationFormatter:SetMinInterval(Enum.SecondsFormatterInterval.Seconds)
	durationFormatter:SetMillisecondsThreshold(10)
end

-- Button initializer, shared by unit frame and standalone containers.
-- Signature matches oUF's CreateButton override: (element, options, button).
-- Options used: width, height, mirrored, edgeColor, dispelBorder,
-- cancelButton, disableMouse.
function ns.auras.InitButton(element, options, button)
	local width, height = options.width, options.height
	button:SetSize(width, height)
	button:EnableMouse(not options.disableMouse)
	button:SetTooltipAnchorPoint('ANCHOR_CURSOR', 0, 0)

	local px = ns.Pixels(button, 1)

	-- The plate shows only as the 1px black edge around everything else.
	local plate = button:CreateTexture(nil, 'BACKGROUND')
	plate:SetAllPoints()
	plate:SetColorTexture(0, 0, 0, 1)

	-- With a ring, the icon moves in another pixel and the ring shows as the
	-- 1px between it and the black edge: fills under the icon, inset by 1px.
	local ringed = options.edgeColor or options.dispelBorder
	local inset = ringed and 2 * px or px
	if options.edgeColor then
		local c = options.edgeColor
		local ring = button:CreateTexture(nil, 'BACKGROUND', nil, 1)
		ring:SetPoint('TOPLEFT', px, -px)
		ring:SetPoint('BOTTOMRIGHT', -px, px)
		ring:SetColorTexture(c[1], c[2], c[3], 1)
	end

	-- Dispel type colours the ring instead of Blizzard's glossy border
	-- overlay: a white fill above the tint, coloured by the client. Debuffs
	-- without a type keep the tint.
	if options.dispelBorder then
		local edge = button:CreateTexture(nil, 'BACKGROUND', nil, 2)
		edge:SetPoint('TOPLEFT', px, -px)
		edge:SetPoint('BOTTOMRIGHT', -px, px)
		edge:SetTexture([[Interface\Buttons\WHITE8X8]])
		button.Border = edge
		button:AddDispelTypeTexture(edge, {
			style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
			showWhenHarmful = true,
			showWhenHelpful = false,
			customDispelColorMap = oUF.colors.dispel,
		})
	end

	local icon = button:CreateTexture(nil, 'BORDER')
	icon:SetPoint('TOPLEFT', inset, -inset)
	icon:SetPoint('BOTTOMRIGHT', -inset, inset)
	-- Crop the baked-in icon border, then a centred band matching the strip's
	-- shape, so the art isn't squashed.
	local band = 0.84 * (height - 2 * inset) / (width - 2 * inset) / 2
	icon:SetTexCoord(0.08, 0.92, 0.5 - band, 0.5 + band)
	button.Icon = icon
	button:SetIcon(icon)

	-- Time passed, filling in from the right (left when mirrored), so the
	-- bright part drains toward the other side. The range must be set before
	-- the binding, or the client drops it.
	local elapsed = CreateFrame('StatusBar', nil, button)
	elapsed:SetAllPoints(icon)
	elapsed:SetMinMaxValues(0, 1)
	elapsed:SetReverseFill(not options.mirrored)
	elapsed:SetStatusBarTexture(ns.media.texture)
	elapsed:SetStatusBarColor(unpack(ELAPSED_COLOR))
	button.Elapsed = elapsed
	button:SetDurationBar(elapsed, { direction = ELAPSED, interpolation = INTERPOLATION })

	-- Above the elapsed bar.
	local overlay = CreateFrame('Frame', nil, button)
	overlay:SetAllPoints()
	overlay:SetFrameLevel(elapsed:GetFrameLevel() + 1)

	local duration = ns.CreateText(overlay, 10, 'semibold', 'OUTLINE')
	local timeSide, countSide = 'RIGHT', 'LEFT'
	if options.mirrored then
		timeSide, countSide = countSide, timeSide
	end
	-- Both texts reach 1px past the icon onto the ring, offsetting the font's
	-- built-in side bearing so the digits sit close to the edge.
	local function Out(side) return side == 'LEFT' and -px or px end
	duration:SetPoint(timeSide, icon, timeSide, Out(timeSide), 0)
	duration:SetJustifyH(timeSide)
	button.Time = duration
	button:SetDurationText(duration, { textFormatter = durationFormatter })

	local count = ns.CreateText(overlay, 10, 'semibold', 'OUTLINE')
	count:SetPoint(countSide, icon, countSide, Out(countSide), 0)
	count:SetJustifyH(countSide)
	button.Count = count
	button:SetApplicationCount(count, {})

	if options.cancelButton then
		button:SetCancelAuraButtons(options.cancelButton)
	end

	-- The container places buttons itself, possibly between pixels; rounding
	-- the button's layout keeps its 1px edge whole on every side.
	if PixelUtil.SetRoundLayoutToNearestPixelRecursively then
		PixelUtil.SetRoundLayoutToNearestPixelRecursively(button, true)
	end
end

