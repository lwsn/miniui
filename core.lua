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

-- Shortens a name to at most `max` characters. Creature names reduce words to
-- initials left to right, keeping the last word whole:
--   'Sparkleshell Snapper', 12 => 'S. Snapper'
--   'Salt Flats Scavenger', 16 => 'S. F. Scavenger'
-- Player names (`person`, "Firstname Lastname") keep the first name whole and
-- shorten from the end instead, then drop to the first name alone:
--   'Annabelle Thornquist', 14 => 'Annabelle T.'
--   'Annabelle Thornquist', 8  => 'Annabelle'
-- Stops as soon as it fits; if even the shortest form is too long it's
-- returned as is and the font string truncates it. Secret names pass through.
local function FirstChar(word)
	return word:match('^[%z\1-\127\194-\244][\128-\191]*') or word:sub(1, 1)
end

function ns.AbbreviateName(name, max, person)
	if not name or (issecretvalue and issecretvalue(name)) then
		return name
	end
	if not max or strlenutf8(name) <= max then
		return name
	end
	local words = { strsplit(' ', name) }
	local first, last, step
	if person then
		first, last, step = #words, 2, -1
	else
		first, last, step = 1, #words - 1, 1
	end
	for i = first, last, step do
		words[i] = FirstChar(words[i]) .. '.'
		local short = table.concat(words, ' ')
		if strlenutf8(short) <= max then
			return short
		end
	end
	if person then
		return words[1]
	end
	return table.concat(words, ' ')
end

-- /rl: shorthand for /reload
SLASH_MINIUIRELOAD1 = '/rl'
SlashCmdList.MINIUIRELOAD = ReloadUI
