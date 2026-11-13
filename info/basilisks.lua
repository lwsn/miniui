local _, ns = ...

-- Basilisk kill counter, on its own plate 1px left of the fps. Counts kills
-- that give you experience ("Ashmane Basilisk dies, you gain 123 experience."),
-- which read the mob's name without the combat log. Any mob whose name ends
-- in one of SUFFIXES counts, all toward the one total. Saved per character;
-- hidden until the first kill.

local SUFFIXES = { 'basilisk$', 'crystalhide$' } -- matched lower-cased
local TEXT_SIZE = 12
local GAP = 1 -- physical pixels from the fps plate

local frame = CreateFrame('Frame', 'miniuiBasilisks', UIParent)
frame:SetFrameStrata('LOW')
frame:Hide()

local plate = frame:CreateTexture(nil, 'BACKGROUND')
plate:SetAllPoints()
plate:SetColorTexture(0, 0, 0, 0.8)

local text = ns.CreateText(frame, TEXT_SIZE, 'semibold')
text:SetPoint('RIGHT', -4, 0)
text:SetJustifyH('RIGHT')
text:SetTextColor(0.85, 0.85, 0.85)

-- "%s dies, you gain %d experience." => "^(.-) dies, you gain "
local function KillPattern()
	local format = COMBATLOG_XPGAIN_FIRSTPERSON or '%s dies, you gain %d experience.'
	local before, after = format:match('^(.-)%%s(.-)%%')
	if not before then
		return '^(.-) dies, you gain '
	end
	local function Escape(s)
		return (s:gsub('[%^%$%(%)%%%.%[%]%*%+%-%?]', '%%%0'))
	end
	return '^' .. Escape(before) .. '(.-)' .. Escape(after)
end

local pattern = KillPattern()

local function Count()
	return miniuiBasiliskDB and miniuiBasiliskDB.count or 0
end

-- Plate fitted to the text, in whole pixels, its right edge against the fps.
local function Refresh()
	local count = Count()
	if count <= 0 then
		frame:Hide()
		return
	end
	text:SetFormattedText('%d basilisk%s', count, count == 1 and '' or 's')
	local px = ns.Pixels(frame, 1)
	local width = math.ceil((text:GetUnboundedStringWidth() + 8) / px)
	frame:SetSize(width * px, math.floor(16 / px + 0.5) * px)
	frame:ClearAllPoints()
	frame:SetPoint('TOPRIGHT', miniuiFPS, 'TOPLEFT', -GAP * px, 0)
	frame:Show()
end

frame:RegisterEvent('PLAYER_LOGIN')
frame:RegisterEvent('CHAT_MSG_COMBAT_XP_GAIN')
frame:RegisterEvent('UI_SCALE_CHANGED')
frame:RegisterEvent('DISPLAY_SIZE_CHANGED')
frame:SetScript('OnEvent', function(_, event, message)
	if event == 'PLAYER_LOGIN' then
		if type(miniuiBasiliskDB) ~= 'table' then
			miniuiBasiliskDB = { count = 0 }
		end
	elseif event == 'CHAT_MSG_COMBAT_XP_GAIN' then
		if type(message) ~= 'string' or (issecretvalue and issecretvalue(message)) then return end
		local name = message:match(pattern)
		if not name then return end
		name = name:lower()
		local match
		for _, suffix in ipairs(SUFFIXES) do
			if name:find(suffix) then
				match = true
				break
			end
		end
		if not match then return end
		miniuiBasiliskDB.count = Count() + 1
	end
	Refresh()
end)
