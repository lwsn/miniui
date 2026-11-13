local _, ns = ...

-- Tracking bars stacked on top of the minimap, as wide as it: experience
-- first, then the watched reputation. The group sits 1px above the minimap;
-- within it, each bar shares the border below it. A bar
-- that has nothing to show is hidden and the ones above drop down.
--
-- Same height and text as the unit frames' power bar, flat fill, centred
-- percentage without a % sign. Replaces Blizzard's tracking bars.

local HEIGHT = 16 -- UI units; matches the unit frame power bar
local TEXT_SIZE = 12 -- matches the power text

local XP_COLOR = { 0.45, 0.28, 0.62 } -- muted purple
local RESTED_SHADE = 0.6 -- rested segment brightness relative to the fill
local REP_FALLBACK = { 0.30, 0.45, 0.20 } -- when the standing has no colour
-- Standing colours replacing Blizzard's, by reaction; the rest stay Blizzard's.
local REP_COLORS = {
	[5] = { 0.24, 0.40, 0.16 }, -- friendly and up: Blizzard's bright green, toned down
	[6] = { 0.24, 0.40, 0.16 },
	[7] = { 0.24, 0.40, 0.16 },
	[8] = { 0.24, 0.40, 0.16 },
}

local BLIZZARD = { 'StatusTrackingBarManager', 'MainStatusTrackingBarContainer', 'SecondaryStatusTrackingBarContainer', 'MainMenuExpBar', 'ReputationWatchBar' }

local hidden = CreateFrame('Frame')
hidden:Hide()

local bars = {} -- bottom to top

-- Bar construction -------------------------------------------------------------

local function OnEnter(frame)
	GameTooltip:SetOwner(frame, 'ANCHOR_TOP')
	frame:Tooltip()
	GameTooltip:Show()
end

local function OnLeave()
	GameTooltip:Hide()
end

-- A bordered status bar; .extra is a dimmer segment behind the fill (rested).
local function CreateBar(name)
	local frame = CreateFrame('Frame', name, UIParent)
	frame:SetFrameStrata('LOW')
	frame:EnableMouse(true)
	frame:SetScript('OnEnter', OnEnter)
	frame:SetScript('OnLeave', OnLeave)

	local backdrop = frame:CreateTexture(nil, 'BACKGROUND')
	backdrop:SetAllPoints()
	backdrop:SetColorTexture(0, 0, 0, 1) -- opaque, like the minimap border

	local extra = CreateFrame('StatusBar', nil, frame)
	extra:SetStatusBarTexture(ns.media.texture)
	extra:SetMinMaxValues(0, 1)
	extra:SetValue(0)
	frame.extra = extra

	local bar = CreateFrame('StatusBar', nil, frame)
	bar:SetStatusBarTexture(ns.media.texture)
	bar:SetAllPoints(extra)
	bar:SetFrameLevel(extra:GetFrameLevel() + 1)
	frame.bar = bar

	local bg = extra:CreateTexture(nil, 'BACKGROUND')
	bg:SetAllPoints()
	bg:SetTexture(ns.media.texture)
	frame.bg = bg

	local text = ns.CreateText(bar, TEXT_SIZE, 'semibold')
	text:SetPoint('CENTER')
	text:SetJustifyH('CENTER')
	frame.text = text

	bars[#bars + 1] = frame
	return frame
end

-- Fill colour; background and text derived like the power bar's.
local function SetColor(frame, r, g, b)
	local shade, tint = ns.colors.BG_SHADE, ns.colors.TEXT_TINT
	frame.bar:SetStatusBarColor(r, g, b)
	frame.extra:SetStatusBarColor(r * RESTED_SHADE, g * RESTED_SHADE, b * RESTED_SHADE)
	frame.bg:SetVertexColor(r * shade, g * shade, b * shade)
	local tr, tg, tb = r + (1 - r) * tint, g + (1 - g) * tint, b + (1 - b) * tint
	frame.text:SetTextColor(tr, tg, tb)
	if frame.left then frame.left:SetTextColor(tr, tg, tb) end
	if frame.right then frame.right:SetTextColor(tr, tg, tb) end
end

-- Progress through the current span: value of max.
local function SetProgress(frame, value, max)
	max = math.max(1, max)
	value = math.max(0, math.min(max, value))
	frame.bar:SetMinMaxValues(0, max)
	frame.bar:SetValue(value)
	frame.text:SetText(math.floor(value / max * 100))
end

-- 950 => 950, 1500 => 1.5k, 50000 => 50k, 1250000 => 1.3m
local function Short(n)
	local function Trim(value, suffix)
		return (('%.1f'):format(value):gsub('%.0$', '')) .. suffix
	end
	if n >= 1e6 then
		return Trim(n / 1e6, 'm')
	elseif n >= 1e4 then
		return math.floor(n / 1e3 + 0.5) .. 'k'
	elseif n >= 1e3 then
		return Trim(n / 1e3, 'k')
	end
	return tostring(n)
end

-- Experience -------------------------------------------------------------------

local experience = CreateBar('miniuiExperience')
experience:EnableMouse(false) -- numbers are on the bar instead of a tooltip

-- Current and max experience at either end.
experience.left = ns.CreateText(experience.bar, TEXT_SIZE, 'semibold')
experience.left:SetPoint('LEFT', 4, 0)
experience.right = ns.CreateText(experience.bar, TEXT_SIZE, 'semibold')
experience.right:SetPoint('RIGHT', -4, 0)


local function IsMaxLevel()
	if IsPlayerAtEffectiveMaxLevel then
		return IsPlayerAtEffectiveMaxLevel()
	end
	return UnitLevel('player') >= (GetMaxPlayerLevel and GetMaxPlayerLevel() or MAX_PLAYER_LEVEL or 60)
end

function experience:Refresh()
	if IsMaxLevel() or (IsXPUserDisabled and IsXPUserDisabled()) then
		return false
	end
	local cur, max = UnitXP('player'), math.max(1, UnitXPMax('player'))
	local exhaustion = GetXPExhaustion() or 0
	SetProgress(self, cur, max)
	self.extra:SetMinMaxValues(0, max)
	self.extra:SetValue(math.min(max, cur + exhaustion))
	-- Rested as a share of the whole level, in brackets after the progress.
	if exhaustion > 0 then
		self.text:SetFormattedText('%d (%d)', math.floor(cur / max * 100), math.floor(exhaustion / max * 100))
	end
	self.left:SetText(Short(cur))
	self.right:SetText(Short(max))
	return true
end

-- Reputation -------------------------------------------------------------------

local reputation = CreateBar('miniuiReputation')

-- Faction name on the left, reputation still needed on the right.
reputation.right = ns.CreateText(reputation.bar, TEXT_SIZE, 'semibold')
reputation.right:SetPoint('RIGHT', -4, 0)
reputation.left = ns.CreateText(reputation.bar, TEXT_SIZE, 'semibold')
reputation.left:SetPoint('LEFT', 4, 0)
reputation.left:SetPoint('RIGHT', reputation.right, 'LEFT', -4, 0)
reputation.left:SetJustifyH('LEFT')
reputation.left:SetWordWrap(false)

-- The watched faction as { name, standing, value, max, reaction }, value and
-- max being progress through the current standing. Handles renown, friendship
-- and paragon factions where the client has them.
local function WatchedFaction()
	local name, reaction, low, high, value, factionID
	if C_Reputation and C_Reputation.GetWatchedFactionData then
		local data = C_Reputation.GetWatchedFactionData()
		if not data or not data.name or data.name == '' then return end
		name, reaction, factionID = data.name, data.reaction, data.factionID
		low, high, value = data.currentReactionThreshold, data.nextReactionThreshold, data.currentStanding
	elseif GetWatchedFactionInfo then
		name, reaction, low, high, value, factionID = GetWatchedFactionInfo()
		if not name then return end
	else
		return
	end

	local standing = _G['FACTION_STANDING_LABEL' .. tostring(reaction)] or ''

	if factionID and C_Reputation and C_Reputation.IsMajorFaction and C_Reputation.IsMajorFaction(factionID) then
		local info = C_MajorFactions.GetMajorFactionRenownInfo(factionID)
		if info then
			return name, (RENOWN_LEVEL_LABEL and RENOWN_LEVEL_LABEL:format(info.renownLevel)) or ('Renown ' .. info.renownLevel),
				info.renownReputationEarned, info.renownLevelThreshold, reaction
		end
	end

	if factionID and C_Reputation and C_Reputation.IsFactionParagon and C_Reputation.IsFactionParagon(factionID) then
		local current, threshold = C_Reputation.GetFactionParagonInfo(factionID)
		if current and threshold and threshold > 0 then
			return name, 'Paragon', current % threshold, threshold, reaction
		end
	end

	if factionID and C_GossipInfo and C_GossipInfo.GetFriendshipReputation then
		local friend = C_GossipInfo.GetFriendshipReputation(factionID)
		if friend and friend.friendshipFactionID and friend.friendshipFactionID > 0 then
			local nextThreshold = friend.nextThreshold or friend.standing
			return name, friend.reaction or standing,
				friend.standing - friend.reactionThreshold, nextThreshold - friend.reactionThreshold, reaction
		end
	end

	return name, standing, value - low, high - low, reaction
end

function reputation:Refresh()
	local name, _, value, max, reaction = WatchedFaction()
	if not name then
		return false
	end
	local color = FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction]
	if REP_COLORS[reaction] then
		SetColor(self, unpack(REP_COLORS[reaction]))
	elseif color then
		SetColor(self, color.r, color.g, color.b)
	else
		SetColor(self, unpack(REP_FALLBACK))
	end
	SetProgress(self, value, max)
	self.text:SetText('')
	self.left:SetText(name)
	self.right:SetText(Short(math.max(0, max - value)))
	return true
end

function reputation:Tooltip()
	local name, standing, value, max = WatchedFaction()
	if not name then return end
	GameTooltip:AddDoubleLine(name, standing, 1, 1, 1, 1, 1, 1)
	GameTooltip:AddLine(BreakUpLargeNumbers(value) .. ' / ' .. BreakUpLargeNumbers(max), 1, 1, 1)
end

-- Layout -----------------------------------------------------------------------

-- Stacks the visible bars upward: 1px above the minimap, then each bottom
-- border overlapping the top border below it.
local function Stack()
	local px = ns.Pixels(UIParent, 1)
	local height = (math.max(1, math.floor(HEIGHT / px + 0.5)) + 2) * px
	local below = ns.minimap
	for _, frame in ipairs(bars) do
		if frame:IsShown() then
			frame:ClearAllPoints()
			local offset = below == ns.minimap and px or -px
			frame:SetPoint('BOTTOMLEFT', below, 'TOPLEFT', 0, offset)
			frame:SetPoint('BOTTOMRIGHT', below, 'TOPRIGHT', 0, offset)
			frame:SetHeight(height)
			frame.extra:ClearAllPoints()
			frame.extra:SetPoint('TOPLEFT', px, -px)
			frame.extra:SetPoint('BOTTOMRIGHT', -px, px)
			below = frame
		end
	end
end

local function Update()
	for _, frame in ipairs(bars) do
		frame:SetShown(frame:Refresh())
	end
	Stack()
end

-- Events -----------------------------------------------------------------------

local EVENTS = {
	'PLAYER_XP_UPDATE', 'UPDATE_EXHAUSTION', 'PLAYER_LEVEL_UP', 'ENABLE_XP_GAIN', 'DISABLE_XP_GAIN',
	'UPDATE_FACTION', 'MAJOR_FACTION_RENOWN_LEVEL_CHANGED', 'MAJOR_FACTION_UNLOCKED',
	'PLAYER_ENTERING_WORLD', 'UI_SCALE_CHANGED', 'DISPLAY_SIZE_CHANGED',
}

local events = CreateFrame('Frame')
events:RegisterEvent('PLAYER_LOGIN')
events:SetScript('OnEvent', function(_, event)
	if event == 'PLAYER_LOGIN' then
		for _, name in ipairs(BLIZZARD) do
			local blizzard = _G[name]
			if blizzard then
				blizzard:SetParent(hidden)
			end
		end
		SetColor(experience, unpack(XP_COLOR))
		for _, e in ipairs(EVENTS) do
			if not (C_EventUtils and C_EventUtils.IsEventValid) or C_EventUtils.IsEventValid(e) then
				events:RegisterEvent(e)
			end
		end
	end
	Update()
end)
