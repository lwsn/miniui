local _, ns = ...
local oUF = ns.oUF
assert(oUF, 'miniui: embedded oUF failed to load')

local addonName = ...
local FONTS = [[Interface\AddOns\]] .. addonName .. [[\media\fonts\]]

ns.media = {
	font = {
		regular = FONTS .. [[IBM_Plex_Sans_Condensed\IBMPlexSansCondensed-Regular.ttf]],
		semibold = FONTS .. [[IBM_Plex_Sans_Condensed\IBMPlexSansCondensed-SemiBold.ttf]],
	},
}

ns.media.texture = [[Interface\Buttons\WHITE8x8]]

-- Sizes shared between modules, in UI units.
ns.layout = {
	-- Unit frame health fill. Action button icons match it, so the buttons
	-- line up with the health bar and the divider below it.
	healthHeight = 31,
	-- Physical pixels between action buttons: -1 makes neighbours share
	-- their 1px border.
	buttonSpacing = -1,
	-- Action bar 1's columns. Its width is shared by the unit frames, the
	-- minimap and the pet bar.
	mainColumns = 6,
}

-- Action button size in pixels: icon as tall as the health fill, plus a 1px
-- border on each side.
function ns.layout.ButtonPixels(frame)
	return math.max(1, math.floor(ns.layout.healthHeight / ns.Pixels(frame, 1) + 0.5)) + 2
end

-- Length in pixels of a run of `count` action buttons.
function ns.layout.GridPixels(frame, count)
	return count * ns.layout.ButtonPixels(frame) + (count - 1) * ns.layout.buttonSpacing
end

-- Action bar 1's width in pixels.
function ns.layout.MainPixels(frame)
	return ns.layout.GridPixels(frame, ns.layout.mainColumns)
end

-- UI units are not screen pixels unless the UI scale is exactly 768/screenHeight,
-- so a 1-unit offset can render as 1px on one edge and 2px on another. These
-- helpers work in real pixels for the frame's current effective scale.
function ns.Pixels(frame, n)
	return n * PixelUtil.GetPixelToUIUnitFactor() / frame:GetEffectiveScale()
end

-- Snap a UI-unit size to a whole number of pixels (at least one).
function ns.Snap(frame, size)
	local perPixel = ns.Pixels(frame, 1)
	return math.max(1, math.floor(size / perPixel + 0.5)) * perPixel
end

-- Snap a UI-unit size to a whole, even number of pixels so a frame anchored by
-- its CENTER still has its edges on the pixel grid.
function ns.SnapEven(frame, size)
	local perPixel = ns.Pixels(frame, 1)
	local pixels = math.max(2, 2 * math.floor(size / perPixel / 2 + 0.5))
	return pixels * perPixel
end

-- Text sits on dark surfaces, so it gets no shadow or outline by default.
-- Text drawn over icons passes 'OUTLINE' as flags.
function ns.CreateText(parent, size, weight, flags)
	local fs = parent:CreateFontString(nil, 'OVERLAY')
	fs:SetFont(ns.media.font[weight or 'regular'], size, flags or '')
	fs:SetTextColor(1, 1, 1)
	return fs
end

-- /rl: shorthand for /reload
SLASH_MINIUIRELOAD1 = '/rl'
SlashCmdList.MINIUIRELOAD = ReloadUI
