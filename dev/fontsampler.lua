-- Dev tool: font sampler for picking the UI font. Rendered at UIParent scale so
-- text looks the way it would on the unit frames. Remove from the .toc (and
-- trim media/fonts) once a font has been picked.
--
--   /mfonts           toggle
--   /mfonts <text>    show only fonts whose name or path contains <text>
--   /mfonts all       clear the filter

local addonName = ...
local MEDIA = [[Interface\AddOns\]] .. addonName .. [[\media\fonts\]]

-- Bundled fonts: one entry per weight, at MEDIA .. base .. '-' .. weight .. '.ttf'.
local WEIGHTS = { 'Regular', 'SemiBold' }
local FAMILIES = {
	{ 'IBM Plex Sans Condensed', [[IBM_Plex_Sans_Condensed\IBMPlexSansCondensed]] },
}

-- Clean built-in fonts (no Morpheus, Skurri, Kai/Lei brush fonts, K_Damage).
-- Paths that don't exist in this client are probed and listed as missing.
local BUILTIN = {
	{ [[Fonts\FRIZQT__.TTF]], 'Friz Quadrata' },
	{ [[Fonts\FRIZQT___CYR.TTF]], 'Friz Quadrata (Cyrillic)' },
	{ [[Fonts\ARIALN.TTF]], 'Arial Narrow' },
	{ [[Fonts\2002.TTF]], '2002 (Korean)' },
	{ [[Fonts\2002B.TTF]], '2002 Bold (Korean)' },
	{ [[Fonts\ARHei.ttf]], 'AR Hei (Simplified Chinese)' },
	{ [[Fonts\bHEI00M.ttf]], 'Hei Medium (Traditional Chinese)' },
	{ [[Fonts\bHEI01B.ttf]], 'Hei Bold (Traditional Chinese)' },
	{ [[Fonts\K_Pagetext.TTF]], 'Pagetext (Korean book)' },
	{ [[Fonts\NIM_____.ttf]], 'Nimrod' },
}

-- Font globals the default UI uses; shown next to whichever file they point at.
local GLOBALS = { 'STANDARD_TEXT_FONT', 'UNIT_NAME_FONT', 'DAMAGE_TEXT_FONT', 'NAMEPLATE_FONT' }

local SIZES = { 10, 11, 12, 13, 14, 16, 18 }
local CHARSET_SIZE = 13

local SAMPLE = "Kel'Thuzad 98.7% 12.3k 45/100"
local CHARSET = {
	"ABCDEFGHIJKLMNOPQRSTUVWXYZ  abcdefghijklmnopqrstuvwxyz  Il1 O0",
	"Åsa Ölmé Øyvind Ñoño Łukasz Žofie  Привет Мир",
	"0123456789   1,234,567   987.6k   1.2M   98.7%   45/100   3:07   -12   +8",
	"( ) [ ] { } < > ! ? # & * : ; ' \" _ = ~ @ $ ^ || \\   • · … — – × ÷ ° ±",
}

-- Column backgrounds: the UI keeps text on dark surfaces only.
local COLUMNS = {
	{ label = 'shadow / dark', bg = { 0.15, 0.15, 0.15 }, flags = '', shadow = true },
	{ label = 'OUTLINE / dark', bg = { 0.15, 0.15, 0.15 }, flags = 'OUTLINE' },
	{ label = 'shadow / mid green', bg = { 0.2, 0.45, 0.2 }, flags = '', shadow = true },
}

local LABEL_W, COL_W, GAP, PAD = 34, 380, 6, 12
local WIDTH = PAD * 2 + LABEL_W + #COLUMNS * (COL_W + GAP)
local HEIGHT = 720
local SECTION_GAP = 24

local frame, scroll, content
local sections = {}
local missing = {}

local function Normalize(path)
	return (path:gsub('/', '\\'):lower())
end

local function Exists(parent, path)
	-- 12.0+: the client indexes UI files up front; this is what LibSharedMedia
	-- uses. SetFont/GetFont can't be trusted as an existence check there.
	if C_UIFileAsset and C_UIFileAsset.IsKnownFile then
		return C_UIFileAsset.IsKnownFile(path)
	end

	-- Older clients: a fresh FontString has no font, so GetFont() stays nil if SetFont fails.
	local fs = parent:CreateFontString()
	local ok = fs:SetFont(path, 12, '')
	fs:Hide()
	if ok ~= nil then
		return ok
	end
	return fs:GetFont() ~= nil
end

-- WoW can't enable OpenType features, so digits must be equal-width by default
-- for numbers to not jitter as they change.
local function DigitsTabular(parent, path)
	local a = parent:CreateFontString()
	local b = parent:CreateFontString()
	a:SetFont(path, 20, '')
	b:SetFont(path, 20, '')
	a:SetText('1111111111')
	b:SetText('0000000000')
	local wa, wb = a:GetStringWidth(), b:GetStringWidth()
	a:Hide()
	b:Hide()
	if wa == 0 or wb == 0 then
		return nil
	end
	return math.abs(wa - wb) < 0.5
end

local function Text(parent, path, size, flags, shadow)
	local fs = parent:CreateFontString(nil, 'OVERLAY')
	fs:SetFont(path, size, flags)
	fs:SetTextColor(1, 1, 1)
	if shadow then
		fs:SetShadowOffset(1, -1)
		fs:SetShadowColor(0, 0, 0, 1)
	end
	fs:SetJustifyH('LEFT')
	fs:SetWordWrap(false)
	return fs
end

local function Label(parent, text, r, g, b)
	local fs = parent:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	fs:SetText(text)
	if r then
		fs:SetTextColor(r, g, b)
	end
	fs:SetJustifyH('LEFT')
	return fs
end

local function BuildSection(name, path, globals)
	local section = CreateFrame('Frame', nil, content)
	section:SetWidth(WIDTH - PAD * 2)
	section.search = (name .. ' ' .. path):lower()

	local tabular = DigitsTabular(section, path)
	local digits = tabular == nil and '|cff888888digits ?|r'
		or tabular and '|cff66dd66tabular digits|r'
		or '|cffff9933proportional digits|r'

	local header = Label(section, '')
	header:SetPoint('TOPLEFT')
	header:SetFormattedText('%s   %s   |cff888888%s|r%s', name, digits, path,
		globals and ('   |cff66ccff' .. globals .. '|r') or '')
	local y = 22

	for _, size in ipairs(SIZES) do
		local rowH = math.max(size + 8, 16)

		local sizeLabel = Label(section, tostring(size), 0.6, 0.6, 0.6)
		sizeLabel:SetPoint('LEFT', section, 'TOPLEFT', 0, -y - rowH / 2)

		for i, col in ipairs(COLUMNS) do
			local x = LABEL_W + (i - 1) * (COL_W + GAP)

			local cell = section:CreateTexture(nil, 'BACKGROUND')
			cell:SetPoint('TOPLEFT', x, -y)
			cell:SetSize(COL_W, rowH)
			cell:SetColorTexture(col.bg[1], col.bg[2], col.bg[3])

			local fs = Text(section, path, size, col.flags, col.shadow)
			fs:SetPoint('LEFT', cell, 'LEFT', 4, 0)
			fs:SetPoint('RIGHT', cell, 'RIGHT', -4, 0)
			fs:SetText(SAMPLE)
		end

		y = y + rowH + 2
	end

	y = y + 4
	for _, line in ipairs(CHARSET) do
		local fs = Text(section, path, CHARSET_SIZE, '', true)
		fs:SetPoint('TOPLEFT', LABEL_W, -y)
		fs:SetText(line)
		y = y + CHARSET_SIZE + 6
	end

	section:SetHeight(y)
	table.insert(sections, section)
end

local function Layout(filter)
	filter = filter and filter ~= '' and filter:lower() or nil
	local y, shown = 0, 0
	for _, section in ipairs(sections) do
		if not filter or section.search:find(filter, 1, true) then
			section:ClearAllPoints()
			section:SetPoint('TOPLEFT', 0, -y)
			section:Show()
			y = y + section:GetHeight() + SECTION_GAP
			shown = shown + 1
		else
			section:Hide()
		end
	end

	if shown == 0 then
		frame.empty:SetFormattedText('No fonts match "%s".', filter)
		frame.empty:SetPoint('TOPLEFT', 0, -y)
		frame.empty:Show()
		y = y + 24
	else
		frame.empty:Hide()
	end

	if #missing > 0 and not filter then
		frame.missing:SetPoint('TOPLEFT', 0, -y)
		frame.missing:Show()
		y = y + 40
	else
		frame.missing:Hide()
	end

	content:SetHeight(math.max(y, 1))
	scroll:SetVerticalScroll(0)
	frame.filter:SetText(filter and ('filter: ' .. filter) or '')
end

local function Build()
	frame = CreateFrame('Frame', 'miniuiFontSampler', UIParent)
	frame:SetSize(WIDTH, HEIGHT)
	frame:SetPoint('CENTER')
	frame:SetFrameStrata('DIALOG')
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag('LeftButton')
	frame:SetScript('OnDragStart', frame.StartMoving)
	frame:SetScript('OnDragStop', frame.StopMovingOrSizing)
	table.insert(UISpecialFrames, frame:GetName()) -- Escape closes it

	local bg = frame:CreateTexture(nil, 'BACKGROUND')
	bg:SetAllPoints()
	bg:SetColorTexture(0.05, 0.05, 0.05, 0.97)

	local title = Label(frame, '')
	title:SetPoint('TOPLEFT', PAD, -PAD)
	title:SetFormattedText('miniui font sampler   —   UI scale %.3f, effective %.3f   —   /mfonts <text> to filter, Esc to close',
		UIParent:GetScale(), frame:GetEffectiveScale())

	frame.filter = Label(frame, '', 0.4, 0.8, 1)
	frame.filter:SetPoint('TOPRIGHT', -PAD, -PAD)

	scroll = CreateFrame('ScrollFrame', nil, frame)
	scroll:SetPoint('TOPLEFT', PAD, -PAD - 40)
	scroll:SetPoint('BOTTOMRIGHT', -PAD, PAD)
	scroll:EnableMouseWheel(true)
	scroll:SetScript('OnMouseWheel', function(self, delta)
		local y = self:GetVerticalScroll() - delta * 80
		self:SetVerticalScroll(math.max(0, math.min(y, self:GetVerticalScrollRange())))
	end)

	content = CreateFrame('Frame', nil, scroll)
	content:SetWidth(WIDTH - PAD * 2)
	scroll:SetScrollChild(content)

	for i, col in ipairs(COLUMNS) do
		local legend = Label(frame, col.label, 0.6, 0.6, 0.6)
		legend:SetPoint('BOTTOMLEFT', scroll, 'TOPLEFT', LABEL_W + (i - 1) * (COL_W + GAP), 2)
	end

	-- Which default-UI globals point at which file.
	local usedBy = {}
	for _, name in ipairs(GLOBALS) do
		local path = _G[name]
		if type(path) == 'string' then
			local key = Normalize(path)
			usedBy[key] = usedBy[key] and (usedBy[key] .. ', ' .. name) or name
		end
	end

	local function Add(name, path)
		if Exists(content, path) then
			BuildSection(name, path, usedBy[Normalize(path)])
		else
			table.insert(missing, path)
		end
	end

	for _, family in ipairs(FAMILIES) do
		local name, base, weights = family[1], family[2], family[3] or WEIGHTS
		for _, weight in ipairs(weights) do
			Add(name .. ' ' .. weight, MEDIA .. base .. '-' .. weight .. '.ttf')
		end
	end

	for _, entry in ipairs(BUILTIN) do
		Add(entry[2], entry[1])
	end

	frame.empty = Label(content, '', 0.8, 0.4, 0.4)

	frame.missing = Label(content, 'Not found: ' .. table.concat(missing, ', '), 0.8, 0.4, 0.4)
	frame.missing:SetWidth(WIDTH - PAD * 2)
	frame.missing:SetWordWrap(true)
end

SLASH_MINIUIFONTS1 = '/mfonts'
SlashCmdList.MINIUIFONTS = function(msg)
	msg = strtrim(msg or '')
	if not frame then
		Build()
	elseif msg == '' then
		frame:SetShown(not frame:IsShown())
		return
	end

	Layout(msg ~= 'all' and msg or nil)
	frame:Show()
end
