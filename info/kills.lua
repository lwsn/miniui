local _, ns = ...

-- Kill counter, on its own plate 1px left of the fps. Every kill that gives
-- you experience is counted by mob name ("Saltstone Basilisk dies, you gain
-- 123 experience.", read without the combat log); the plate shows the total
-- for the mobs you've chosen. Target a mob and type /grop to add it to the
-- total or take it out again. Saved per character; hidden while the total is
-- zero.
--
-- The earlier basilisk counter kept one number without names. It carries
-- over as `legacy` and stays part of the total.

local TEXT_SIZE = 12
local GAP = 1 -- physical pixels from the fps plate

local db -- miniuiKillsDB: { kills = { [name] = n }, tracked = { [name] = true }, legacy = n }

local frame = CreateFrame('Frame', 'miniuiKills', UIParent)
frame:SetFrameStrata('LOW')
frame:Hide()

local plate = frame:CreateTexture(nil, 'BACKGROUND')
plate:SetAllPoints()
plate:SetColorTexture(0, 0, 0, 0.8)

local text = ns.CreateText(frame, TEXT_SIZE, 'semibold')
text:SetPoint('RIGHT', -4, 0)
text:SetJustifyH('RIGHT')
text:SetTextColor(0.85, 0.85, 0.85)

local function Print(message)
	print('|cff9a9a9aminiui:|r ' .. message)
end

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

local function Total()
	local total = db.legacy or 0
	for name in next, db.tracked do
		total = total + (db.kills[name] or 0)
	end
	return total
end

-- Plate fitted to the text, in whole pixels, its right edge against the fps.
local function Refresh()
	local total = Total()
	if total <= 0 then
		frame:Hide()
		return
	end
	text:SetFormattedText('%d kill%s', total, total == 1 and '' or 's')
	local px = ns.Pixels(frame, 1)
	local width = math.ceil((text:GetUnboundedStringWidth() + 8) / px)
	frame:SetSize(width * px, math.floor(16 / px + 0.5) * px)
	frame:ClearAllPoints()
	frame:SetPoint('TOPRIGHT', miniuiFPS, 'TOPLEFT', -GAP * px, 0)
	frame:Show()
end

local function Load()
	if type(miniuiKillsDB) ~= 'table' then
		miniuiKillsDB = {}
	end
	db = miniuiKillsDB
	db.kills = type(db.kills) == 'table' and db.kills or {}
	db.tracked = type(db.tracked) == 'table' and db.tracked or {}
	-- One-time move from the basilisk counter.
	if type(miniuiBasiliskDB) == 'table' then
		db.legacy = (db.legacy or 0) + (tonumber(miniuiBasiliskDB.count) or 0)
		miniuiBasiliskDB = nil
	end
end

-- /grop: toggle the target in the total.
SLASH_MINIUIGROP1 = '/grop'
SlashCmdList.MINIUIGROP = function()
	local name = UnitExists('target') and not UnitIsPlayer('target') and UnitName('target')
	if not name or (issecretvalue and issecretvalue(name)) then
		Print('target a monster to track it')
		return
	end
	local kills = db.kills[name] or 0
	if db.tracked[name] then
		db.tracked[name] = nil
		Print(('no longer counting %s (%d killed)'):format(name, kills))
	else
		db.tracked[name] = true
		Print(('counting %s (%d killed so far)'):format(name, kills))
	end
	Refresh()
end

frame:RegisterEvent('PLAYER_LOGIN')
frame:RegisterEvent('CHAT_MSG_COMBAT_XP_GAIN')
frame:RegisterEvent('UI_SCALE_CHANGED')
frame:RegisterEvent('DISPLAY_SIZE_CHANGED')
frame:SetScript('OnEvent', function(_, event, message)
	if event == 'PLAYER_LOGIN' then
		Load()
	elseif event == 'CHAT_MSG_COMBAT_XP_GAIN' then
		if not db or type(message) ~= 'string' or (issecretvalue and issecretvalue(message)) then return end
		local name = message:match(pattern)
		if not name or name == '' then return end
		db.kills[name] = (db.kills[name] or 0) + 1
	end
	if db then Refresh() end
end)
