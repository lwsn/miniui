local _, ns = ...

-- Shorter chat lines:
--   [Guild] [Name]: hi           ->  Name: hi        (guild, party, party
--   [Party Leader] [Name]: hi    ->  Name: hi         leader, raid, raid
--   [Name] says: hi              ->  Name: hi         leader, say and yell
--   [Name] yells: HI             ->  Name: HI         are told apart by colour)
--   [1. General - Elwynn] [Name]: hi  ->  1. Name: hi
-- Player names lose their brackets everywhere.
--
-- How: Blizzard's chat code is left alone (replacing its strings or its
-- AddMessage would taint it, and its secret-value checks would then fail).
-- After each AddMessage, a hook rewrites the line just stored in the
-- window's history; the window draws it on its next update, so the
-- original never shows. Secret (protected) lines aren't readable and keep
-- Blizzard's format. Restored scrollback was already rewritten when saved.

local COMBAT_LOG = 'ChatFrame2'
local NUM_WINDOWS = NUM_CHAT_WINDOWS or (Constants.ChatFrameConstants and Constants.ChatFrameConstants.MaxChatWindows) or 10

-- Channel links whose label is dropped: the line's colour says it all.
local SILENT = { GUILD = true, PARTY = true, RAID = true }

-- " says: " / " yells: ", from the client's own (localized) strings.
local function Verb(format)
	if type(format) ~= 'string' then
		return nil
	end
	local verb = format:gsub('%%s', '', 1)
	-- Escape for use as a Lua pattern.
	return (verb:gsub('[%%%.%-%+%*%?%[%]%^%$%(%)]', '%%%0'))
end
local VERBS = { Verb(CHAT_SAY_GET), Verb(CHAT_YELL_GET) }

local function Channel(link, label)
	if SILENT[link] then
		return ''
	end
	-- "[1. General - Elwynn Forest]" -> "1."
	local number = label:match('^%[(%d+)%.')
	if number then
		return ('|Hchannel:%s|h%s.|h '):format(link, number)
	end
end

local function Rewrite(message)
	-- Channel labels, with the space after them.
	message = message:gsub('|Hchannel:([^|]+)|h(%[.-%])|h ', Channel)
	-- Brackets around player and Battle.net names.
	message = message:gsub('(|Hplayer:.-|h)%[(.-)%]|h', '%1%2|h')
	message = message:gsub('(|HBNplayer:.-|h)%[(.-)%]|h', '%1%2|h')
	-- "Name says: " -> "Name: ", only right after a player link.
	for _, verb in ipairs(VERBS) do
		message = message:gsub('(|Hplayer:.-|h.-|h)' .. verb, '%1: ', 1)
	end
	return message
end

local done = setmetatable({}, { __mode = 'k' }) -- entries already rewritten

local function OnAddMessage(frame)
	local buffer = frame.historyBuffer
	local entry = buffer and buffer:GetEntryAtIndex(1) -- the newest
	if not entry or done[entry] then
		return
	end
	done[entry] = true
	local message = entry.message
	if type(message) == 'string' and not (issecretvalue and issecretvalue(message)) then
		entry.message = Rewrite(message)
	end
end

local hooked = {}

local function Hook(frame)
	if frame and not hooked[frame] and frame:GetName() ~= COMBAT_LOG and frame.historyBuffer then
		hooked[frame] = true
		hooksecurefunc(frame, 'AddMessage', OnAddMessage)
	end
end

local loader = CreateFrame('Frame')
loader:RegisterEvent('PLAYER_LOGIN')
loader:SetScript('OnEvent', function()
	for i = 1, NUM_WINDOWS do
		Hook(_G['ChatFrame' .. i])
	end
	-- Windows made later (whispers popped out, new tabs).
	if FCF_OpenTemporaryWindow then
		hooksecurefunc('FCF_OpenTemporaryWindow', function()
			for _, name in ipairs(CHAT_FRAMES or {}) do
				Hook(_G[name])
			end
		end)
	end
end)
