local ADDON_NAME, ns = ...

-- Chat: placement, look, timestamps and scrollback.
--
-- Placement: the main chat window sits left of action bar 2, bottom-aligned
-- with it and as tall as the minimap, at most MAX_WIDTH wide. If that would
-- run into the stance bar (small screens), it sits on top of the stance bar
-- instead, its bottom-left corner on the stance bar's top-left. The window
-- is pinned inside a frame of ours (`holder`) that carries the background;
-- Blizzard's own attempts to move it (Edit Mode, dock updates) are undone.
--
-- Look: a flat translucent black background and no border. The tabs above
-- it are plain outlined text, and the edit box sits above the tabs: a flat
-- darker fill, no art, invisible unless typing. The social, channels and
-- menu buttons are outlined text at the right end of the tab row. No
-- scrollbar: scrolled up, a glow along the bottom says new lines came in.
--
-- Timestamps: Blizzard's own (the showTimestamps CVar), in a muted colour.
-- Its chat code adds them, so nothing is hooked.
--
-- Scrollback (after Prat's): each window's recent lines are saved at logout
-- and put back above a divider on the next login or reload. Lines carry the
-- timestamp they were shown with. Secret (protected) lines are never saved.

local MAX_WIDTH = 400 -- UI units
local GAP = 1 -- physical pixels from bar 2 and the stance bar
local PAD = 4 -- physical pixels between the background's edge and the text
local BACKGROUND = { 0, 0, 0, 0.3 }

local TIMESTAMP = '|cff7a7a7a%H:%M|r ' -- strftime, before every line
local TAB_FONT_SIZE = 12
local EDIT_FONT_SIZE = 13
local EDIT_HEIGHT = 20 -- UI units
local EDIT_BACKGROUND = { 0, 0, 0, 0.6 } -- a little darker than the chat, for typing
local ROW_HEIGHT = 20 -- UI units: the tab row's buttons
local BUTTON_GAP = 8 -- UI units between the row's buttons
local BUTTON_COLOR = { 0.7, 0.7, 0.7 } -- white on hover
local GLOW_COLOR = { 0.62, 0.78, 0.95 } -- pale blue, as the proc border
local GLOW_ALPHA = 0.35 -- at the bottom edge, fading to nothing
local GLOW_HEIGHT = 10 -- physical pixels

local MAX_LINES = 200 -- kept (at least) and saved per window
local MAX_AGE = 24 * 60 * 60 -- seconds; older lines aren't restored
local DIVIDER = '|cff5a5a5a--- %s ago ---|r'

local NUM_WINDOWS = NUM_CHAT_WINDOWS or (Constants.ChatFrameConstants and Constants.ChatFrameConstants.MaxChatWindows) or 10
local COMBAT_LOG = 'ChatFrame2' -- rebuilt by the client; never saved

local hidden = CreateFrame('Frame')
hidden:Hide()

local holder = CreateFrame('Frame', 'miniuiChat', UIParent)
holder:SetFrameStrata('BACKGROUND')
local background = holder:CreateTexture(nil, 'BACKGROUND')
background:SetAllPoints()
background:SetColorTexture(unpack(BACKGROUND))

-- Placement ---------------------------------------------------------------------

local placing = false

-- The tab row's buttons, right to left (filled in at login).
local rowButtons = {}

local function Pin()
	local px = ns.Pixels(holder, 1)
	placing = true
	ChatFrame1:ClearAllPoints()
	ChatFrame1:SetPoint('TOPLEFT', holder, 'TOPLEFT', PAD * px, -PAD * px)
	ChatFrame1:SetPoint('BOTTOMRIGHT', holder, 'BOTTOMRIGHT', -PAD * px, PAD * px)

	-- Buttons at the right end of the tab row, right on top of the background.
	local right, offset = holder, 0
	for _, button in ipairs(rowButtons) do
		button:ClearAllPoints()
		button:SetPoint('BOTTOMRIGHT', right, right == holder and 'TOPRIGHT' or 'BOTTOMLEFT', offset, 0)
		right, offset = button, -BUTTON_GAP
	end

	-- The tabs fill the rest of the row.
	local rowHeight = ROW_HEIGHT
	if GeneralDockManager then
		GeneralDockManager:ClearAllPoints()
		GeneralDockManager:SetPoint('BOTTOMLEFT', holder, 'TOPLEFT', 0, 0)
		if right == holder then
			GeneralDockManager:SetPoint('BOTTOMRIGHT', holder, 'TOPRIGHT', 0, 0)
		else
			GeneralDockManager:SetPoint('BOTTOMRIGHT', right, 'BOTTOMLEFT', -BUTTON_GAP, 0)
		end
		rowHeight = math.max(rowHeight, GeneralDockManager:GetHeight())
	end

	-- Edit boxes above the row, as wide as the background. Every window has
	-- its own; the docked ones all type here.
	for i = 1, NUM_WINDOWS do
		local editBox = _G['ChatFrame' .. i .. 'EditBox']
		if editBox then
			editBox:ClearAllPoints()
			editBox:SetPoint('BOTTOMLEFT', holder, 'TOPLEFT', 0, rowHeight + px)
			editBox:SetPoint('BOTTOMRIGHT', holder, 'TOPRIGHT', 0, rowHeight + px)
		end
	end

	-- Battle.net toasts (friends coming online...) anchor to the social
	-- button, which would put them over the edit box: above it instead,
	-- on the chat's left edge.
	if BNToastFrame then
		BNToastFrame:ClearAllPoints()
		BNToastFrame:SetPoint('BOTTOMLEFT', holder, 'TOPLEFT', 0, rowHeight + ns.Snap(holder, EDIT_HEIGHT) + 2 * px)
	end
	placing = false
end

-- Worked out in screen coordinates from the bars' edges rather than anchored to
-- them: they're protected, and anchoring to them would restrict this frame.
local function Place()
	local bar2, stance = ns.actionbar.bar2, ns.stancebar
	if not (bar2 and bar2:GetLeft() and ns.minimap) then
		return
	end
	local px = ns.Pixels(holder, 1)
	local gap = GAP * px

	local right = bar2:GetLeft() - gap
	local bottom = bar2:GetBottom()
	local height = ns.minimap:GetHeight()
	local width = math.min(math.floor(MAX_WIDTH / px) * px, right)
	local left = right - width

	-- Too wide to fit beside the stance bar: stand on it instead.
	if stance and stance.count > 0 and stance:GetRight()
		and left < stance:GetRight() + gap and bottom < stance:GetTop() then
		left = stance:GetLeft()
		bottom = stance:GetTop() + gap
		width = math.min(width, right - left)
	end

	holder:SetSize(width, height)
	holder:ClearAllPoints()
	holder:SetPoint('BOTTOMLEFT', UIParent, 'BOTTOMLEFT', left, bottom)
	Pin()
end

-- Look ----------------------------------------------------------------------------

-- Tab textures across client versions: Retail names, then Classic ones.
local TAB_TEXTURES = {
	'Left', 'Middle', 'Right',
	'HighlightLeft', 'HighlightMiddle', 'HighlightRight',
	'ActiveLeft', 'ActiveMiddle', 'ActiveRight',
	'SelectedLeft', 'SelectedMiddle', 'SelectedRight',
}

-- Blizzard keeps fading and recolouring these; parked on a hidden frame,
-- whatever it does to them never shows.
local function Park(region)
	if region then
		region:SetParent(hidden)
	end
end

local tabFont = CreateFont('miniuiChatTabFont')
tabFont:SetFont(ns.media.font.semibold, TAB_FONT_SIZE, 'OUTLINE')

-- On a dark background, so no outline. The header ("Say:") is SemiBold.
local editFont = CreateFont('miniuiChatEditFont')
editFont:SetFont(ns.media.font.regular, EDIT_FONT_SIZE, '')
local editHeaderFont = CreateFont('miniuiChatEditHeaderFont')
editHeaderFont:SetFont(ns.media.font.semibold, EDIT_FONT_SIZE, '')

-- Blizzard's edit box art (left/middle/right, and the focused versions) is
-- parked; a flat fill takes its place.
local function StyleEditBox(editBox)
	for _, region in ipairs({ editBox:GetRegions() }) do
		if region:IsObjectType('Texture') then
			Park(region)
		end
	end
	local fill = editBox:CreateTexture(nil, 'BACKGROUND')
	fill:SetAllPoints()
	fill:SetColorTexture(unpack(EDIT_BACKGROUND))

	editBox:SetHeight(ns.Snap(editBox, EDIT_HEIGHT))
	editBox:SetFontObject(editFont)
	local header = editBox.header or _G[editBox:GetName() .. 'Header']
	if header then
		header:SetFontObject(editHeaderFont)
	end
	local suffix = editBox.headerSuffix or _G[editBox:GetName() .. 'HeaderSuffix']
	if suffix then
		suffix:SetFontObject(editHeaderFont)
	end

	-- Invisible unless typing. With the classic chat style Blizzard keeps the
	-- box shown and sets its own alpha; that's overridden too.
	local fading = false
	local function Fade()
		fading = true
		editBox:SetAlpha(editBox:HasFocus() and 1 or 0)
		fading = false
	end
	editBox:HookScript('OnEditFocusGained', Fade)
	editBox:HookScript('OnEditFocusLost', Fade)
	hooksecurefunc(editBox, 'SetAlpha', function()
		if not fading then
			Fade()
		end
	end)
	Fade()
end

-- No scrollbar. Blizzard's scroll-to-bottom button flashes when lines arrive
-- while scrolled up; it's shrunk out of sight (hiding it would stop the
-- flash) and its flash drives a glow along the bottom of the background.
local function GlowOnNewLines(frame)
	if frame.ScrollBar then
		Park(frame.ScrollBar)
	end
	local button = frame.ScrollToBottomButton
	if not (button and button.Flash) then
		return
	end
	button:SetSize(0.1, 0.1)
	button:SetAlpha(0)
	button:EnableMouse(false)

	local px = ns.Pixels(frame, 1)
	local glow = frame:CreateTexture(nil, 'BACKGROUND')
	glow:SetPoint('BOTTOMLEFT', frame, 'BOTTOMLEFT', -PAD * px, -PAD * px)
	glow:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', PAD * px, -PAD * px)
	glow:SetHeight(GLOW_HEIGHT * px)
	glow:SetColorTexture(1, 1, 1, 1)
	local r, g, b = unpack(GLOW_COLOR)
	glow:SetGradient('VERTICAL', CreateColor(r, g, b, GLOW_ALPHA), CreateColor(r, g, b, 0))
	glow:SetShown(button.Flash:IsShown())

	button.Flash:HookScript('OnShow', function() glow:Show() end)
	button.Flash:HookScript('OnHide', function() glow:Hide() end)
end

-- Social (with the online friends count), channels and chat menu buttons:
-- their art parked, a text label instead, moved into the tab row. Their
-- clicks, tooltips and the social button's toasts are Blizzard's, unchanged.
local ROW_BUTTONS = { -- right to left
	{ name = 'ChatFrameMenuButton', label = 'Menu' },
	{ name = 'ChatFrameChannelButton', label = 'Channels' },
	{ name = 'QuickJoinToastButton', label = 'Social', count = 'FriendCount' },
}

local function StyleRowButtons()
	for _, def in ipairs(ROW_BUTTONS) do
		local button = _G[def.name]
		if button then
			button:SetParent(holder)
			for _, region in ipairs({ button:GetRegions() }) do
				if region:IsObjectType('Texture') then
					Park(region)
				end
			end

			local label = ns.CreateText(button, TAB_FONT_SIZE, 'semibold', 'OUTLINE')
			label:SetText(def.label)
			label:SetTextColor(unpack(BUTTON_COLOR))
			label:SetPoint('LEFT')
			local width = label:GetStringWidth()

			-- The friends count follows the label, in the same type.
			local count = def.count and button[def.count]
			if count then
				count:SetFontObject(tabFont)
				count:SetTextColor(unpack(BUTTON_COLOR))
				count:ClearAllPoints()
				count:SetPoint('LEFT', label, 'RIGHT', 3, 0)
				width = width + 3 + 14 -- room for two digits
			end

			button:SetSize(math.ceil(width), ROW_HEIGHT)
			button:HookScript('OnEnter', function() label:SetTextColor(1, 1, 1) end)
			button:HookScript('OnLeave', function() label:SetTextColor(unpack(BUTTON_COLOR)) end)
			table.insert(rowButtons, button)
		end
	end
end

-- Windows are clamped to the screen with insets reaching past their edges
-- (room for the tab and buttons). Ours sits near the bottom of the screen,
-- so Blizzard's insets, which it puts back whenever it docks a window or
-- redraws its background, push the text up off the background until a
-- reload. Kept at zero (as Prat does).
local unclampPending = {}

local function Unclamp(frame)
	local clamping = false
	local function Zero()
		if InCombatLockdown() then
			unclampPending[frame] = true
			return
		end
		clamping = true
		frame:SetClampRectInsets(0, 0, 0, 0)
		clamping = false
		if not placing then
			Pin() -- re-anchoring drops any clamp offset already applied
		end
	end
	hooksecurefunc(frame, 'SetClampRectInsets', function()
		if not clamping then
			Zero()
		end
	end)
	Zero()
end

local function Style(index)
	local name = 'ChatFrame' .. index
	local frame = _G[name]
	if not frame or frame.miniuiStyled then
		return
	end
	frame.miniuiStyled = true

	for _, texture in ipairs(CHAT_FRAME_TEXTURES or {}) do
		Park(_G[name .. texture])
	end
	-- The strip beside each window: scroll, minimize and (on the first)
	-- voice buttons. The first window's social, channels and menu buttons
	-- have been moved out of it by then.
	Park(_G[name .. 'ButtonFrame'])

	local tab = _G[name .. 'Tab']
	if tab then
		for _, key in ipairs(TAB_TEXTURES) do
			Park(tab[key])
		end
		tab:SetNormalFontObject(tabFont)
		tab:SetHighlightFontObject(tabFont)
		tab:SetDisabledFontObject(tabFont)
	end

	local editBox = _G[name .. 'EditBox']
	if editBox then
		StyleEditBox(editBox)
	end

	GlowOnNewLines(frame)
	Unclamp(frame)

	-- Shift+wheel, either way, jumps to the latest line. Blizzard's handler
	-- runs first (shift+up goes to the top); this lands at the bottom after.
	frame:HookScript('OnMouseWheel', function(self)
		if IsShiftKeyDown() then
			self:ScrollToBottom()
		end
	end)
end

-- Scrollback ------------------------------------------------------------------------

local restoredTimes = setmetatable({}, { __mode = 'k' }) -- entry -> server time it was first shown
local dividers = setmetatable({}, { __mode = 'k' }) -- divider entries, never saved

-- Lines in a window's history (Blizzard's CircularBuffer).
local function Count(buffer)
	if buffer.GetNumElements then
		return buffer:GetNumElements()
	end
	return buffer.elements and #buffer.elements or 0
end

local function Readable(value)
	return value ~= nil and not (issecretvalue and issecretvalue(value))
end

-- Battle.net names are protected per session: links from an earlier session
-- would show garbage, so they keep only their display text.
local function Clean(message)
	message = message:gsub('|K.-|k', '???')
	message = message:gsub('|HBNplayer:.-|h(.-)|h', '%1')
	return message
end

local function Save()
	local now, uptime = GetServerTime(), GetTime()
	local db = {}
	for i = 1, NUM_WINDOWS do
		local name = 'ChatFrame' .. i
		local frame = _G[name]
		local buffer = frame and frame.historyBuffer
		if buffer and name ~= COMBAT_LOG and not frame.isTemporary then
			local lines = {}
			-- Index 1 is the newest; walk oldest to newest.
			for index = math.min(Count(buffer), MAX_LINES), 1, -1 do
				local entry = buffer:GetEntryAtIndex(index)
				local message = entry and entry.message
				if Readable(message) and type(message) == 'string' and not dividers[entry] then
					local time = restoredTimes[entry]
					if not time then
						local shown = entry.timestamp
						time = Readable(shown) and type(shown) == 'number' and math.floor(now - (uptime - shown)) or now
					end
					if now - time <= MAX_AGE then
						local r, g, b = entry.r, entry.g, entry.b
						if not (Readable(r) and Readable(g) and Readable(b)) then
							r, g, b = 1, 1, 1
						end
						table.insert(lines, { message = message, r = r, g = g, b = b, time = time })
					end
				end
			end
			db[name] = lines
		end
	end
	miniuiChatDB = db
end

-- Windows keep a few hundred lines by default; raised so scrollback has room.
-- Changing it empties the window, so it's done before restoring.
local function Grow()
	for i = 1, NUM_WINDOWS do
		local name = 'ChatFrame' .. i
		local frame = _G[name]
		if frame and name ~= COMBAT_LOG and frame.GetMaxLines and frame:GetMaxLines() < MAX_LINES then
			frame:SetMaxLines(MAX_LINES)
		end
	end
end

local function Restore()
	local db = miniuiChatDB
	if type(db) ~= 'table' then
		return
	end
	local now = GetServerTime()
	for name, lines in pairs(db) do
		local frame = type(lines) == 'table' and name:match('^ChatFrame%d+$') and _G[name]
		local buffer = frame and frame.historyBuffer
		if buffer and name ~= COMBAT_LOG and #lines > 0 then
			-- BackFillMessage adds above everything shown so far: the divider
			-- first, then the lines newest to oldest.
			local newest = lines[#lines].time or now
			frame:BackFillMessage(DIVIDER:format(SecondsToTime(math.max(1, now - newest), false, true, 1)))
			dividers[buffer:GetEntryAtIndex(Count(buffer))] = true
			for i = #lines, 1, -1 do
				local line = lines[i]
				if type(line.message) == 'string' and now - (line.time or 0) <= MAX_AGE then
					local message = Clean(line.message)
					frame:BackFillMessage(message, line.r, line.g, line.b)
					local entry = buffer:GetEntryAtIndex(Count(buffer))
					if entry and entry.message == message then
						restoredTimes[entry] = line.time
					end
				end
			end
		end
	end
end

-- Events ------------------------------------------------------------------------------

table.insert(ns.actionbar.onLayout, Place)
table.insert(ns.stancebar.onLayout, Place)

holder:RegisterEvent('PLAYER_LOGIN')
holder:RegisterEvent('PLAYER_LOGOUT')
holder:RegisterEvent('PLAYER_REGEN_ENABLED')
holder:RegisterEvent('ADDON_LOADED')
holder:SetScript('OnEvent', function(_, event, arg)
	if event == 'ADDON_LOADED' then
		-- A table from the start, so `/dump miniuiChatDB` tells a saved
		-- variable that isn't registered (nil) from a save that failed.
		if arg == ADDON_NAME and type(miniuiChatDB) ~= 'table' then
			miniuiChatDB = {}
		end
		return
	end
	if event == 'PLAYER_REGEN_ENABLED' then
		-- Insets Blizzard reset during combat.
		for frame in pairs(unclampPending) do
			unclampPending[frame] = nil
			frame:SetClampRectInsets(0, 0, 0, 0)
			Pin()
		end
		return
	end
	if event == 'PLAYER_LOGIN' then
		SetCVar('showTimestamps', TIMESTAMP)
		StyleRowButtons() -- before Style parks the button frame they live in
		for i = 1, NUM_WINDOWS do
			Style(i)
		end
		-- Windows made later (whispers popped out, new tabs).
		if FCF_OpenTemporaryWindow then
			hooksecurefunc('FCF_OpenTemporaryWindow', function()
				for i = 1, NUM_WINDOWS do
					Style(i)
				end
				for _, frameName in ipairs(CHAT_FRAMES or {}) do
					local index = frameName:match('^ChatFrame(%d+)$')
					if index then
						Style(tonumber(index))
					end
				end
			end)
		end
		-- Blizzard re-anchors these (Edit Mode layouts, docking, button side);
		-- put them back.
		local pinned = { ChatFrame1, GeneralDockManager, BNToastFrame }
		for i = 1, NUM_WINDOWS do
			table.insert(pinned, _G['ChatFrame' .. i .. 'EditBox'])
		end
		for _, button in ipairs(rowButtons) do
			table.insert(pinned, button)
		end
		for _, frame in pairs(pinned) do
			hooksecurefunc(frame, 'SetPoint', function()
				if not placing then
					Pin()
				end
			end)
		end
		Place()
		Grow()
		Restore()
	elseif event == 'PLAYER_LOGOUT' then
		-- Errors at logout are never shown; keep the last one where /dump
		-- can find it.
		local ok, err = pcall(Save)
		if not ok then
			miniuiChatDB = miniuiChatDB or {}
			miniuiChatDB.error = tostring(err)
		end
	end
end)
