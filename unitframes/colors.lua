local _, ns = ...
local oUF = ns.oUF

local colors = {}
ns.colors = colors

-- Text sits on dark surfaces, so lift dark colours toward white until they
-- reach a minimum perceived brightness. Bright colours are left untouched.
local MIN_LUMINANCE = 0.45

local function Readable(r, g, b)
	local l = 0.2126 * r + 0.7152 * g + 0.0722 * b
	if l >= MIN_LUMINANCE then
		return r, g, b
	end
	local t = (MIN_LUMINANCE - l) / (1 - l)
	return r + (1 - r) * t, g + (1 - g) * t, b + (1 - b) * t
end

local function Hex(r, g, b)
	return string.format('|cff%02x%02x%02x', r * 255, g * 255, b * 255)
end

-- Health: one hue per health percentage, in three brightnesses. The bar uses
-- the base colour, its background a darker shade, and the health text a lighter
-- tint. Each is its own curve, because health may be a secret value that can
-- only be resolved to a colour by the client, never read in Lua.
local HEALTH_STOPS = {
	[0.0] = { 0.55, 0.13, 0.11 }, -- dark red
	[0.5] = { 0.48, 0.30, 0.08 }, -- dark orange
	[1.0] = { 0.23, 0.37, 0.11 }, -- slightly yellowed dark green
}
local BG_SHADE = 0.35 -- background brightness relative to the bar (health and power)
colors.BG_SHADE = BG_SHADE
local TEXT_TINT = 0.6 -- how far the text is mixed toward white (health and power)
colors.TEXT_TINT = TEXT_TINT

local function Curve(transform)
	local curve = C_CurveUtil.CreateColorCurve()
	for x, c in next, HEALTH_STOPS do
		curve:AddPoint(x, CreateColor(transform(c[1], c[2], c[3])))
	end
	return curve
end

colors.health = {
	bar = Curve(function(r, g, b) return r, g, b end),
	bg = Curve(function(r, g, b) return r * BG_SHADE, g * BG_SHADE, b * BG_SHADE end),
	text = Curve(function(r, g, b)
		return r + (1 - r) * TEXT_TINT, g + (1 - g) * TEXT_TINT, b + (1 - b) * TEXT_TINT
	end),
}

-- Units with no meaningful health colour (offline, tapped by someone else) get a
-- flat grey in the same three brightnesses.
colors.inactive = {
	bar = CreateColor(0.35, 0.35, 0.35),
	bg = CreateColor(0.35 * BG_SHADE, 0.35 * BG_SHADE, 0.35 * BG_SHADE),
	text = CreateColor(0.75, 0.75, 0.75),
}

-- Power bar colours, replacing oUF's defaults in place so both the token
-- (colors.power.MANA) and power type index (colors.power[0]) aliases change.
-- An { r, g, b } replaces the colour; a number scales the client's default.
local POWER_OVERRIDES = {
	MANA = { 0.12, 0.42, 0.60 }, -- teal-leaning blue, about as bright as full health
	RAGE = { 0.70, 0.18, 0.15 }, -- red can't reach mana's brightness without turning pink; slightly darker
	ENERGY = { 0.58, 0.52, 0.11 }, -- brighter than mana; yellow any darker reads as mustard
}

for token, c in next, POWER_OVERRIDES do
	local color = oUF.colors.power[token]
	if color then
		if type(c) == 'number' then
			local r, g, b = color:GetRGB()
			color:SetRGB(r * c, g * c, b * c)
		else
			color:SetRGB(c[1], c[2], c[3])
		end
	end
end

-- Cast bar fill. Background and text are derived like power's.
colors.cast = {
	normal = CreateColor(0.42, 0.40, 0.52), -- muted slate, distinct from every power colour
	locked = CreateColor(0.40, 0.40, 0.40), -- can't be interrupted
}

-- Hand-tuned class colours where the automatic lift isn't enough. Used as is.
local CLASS_OVERRIDES = {
	SHAMAN = { 0.35, 0.60, 0.86 }, -- lifted (0.12, 0.51, 0.89), then brighter and less saturated
}

-- Class colours as text markup, lifted for contrast.
colors.class = {}
for class, c in next, oUF.colors.class do
	local override = CLASS_OVERRIDES[class]
	if override then
		colors.class[class] = Hex(override[1], override[2], override[3])
	else
		colors.class[class] = Hex(Readable(c:GetRGB()))
	end
end

-- [miniui:namecolor]: class colour for players, difficulty colour for NPCs.
oUF.Tags.Methods['miniui:namecolor'] = function(unit)
	if UnitIsPlayer(unit) or UnitInPartyIsAI(unit) then
		local _, class = UnitClass(unit)
		if class == nil then
			return
		elseif issecretvalue(class) then
			-- Secret class tokens can't index our table; fall back to the
			-- client's colour, unadjusted.
			return C_ClassColor.GetClassColor(class):GenerateHexColorMarkup()
		end
		return colors.class[class]
	end

	local level = UnitEffectiveLevel(unit)
	local c = GetCreatureDifficultyColor((level > 0) and level or 999)
	return Hex(c.r, c.g, c.b)
end
oUF.Tags.Events['miniui:namecolor'] = 'UNIT_NAME_UPDATE UNIT_FACTION UNIT_LEVEL PLAYER_LEVEL_UP'
