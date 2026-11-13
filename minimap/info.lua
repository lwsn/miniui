local _, ns = ...

-- Text over the minimap: zone name top centre, clock (HH:MM, local time)
-- bottom left, player coordinates bottom right. Outlined, since it's drawn
-- over the map. Same size as the tracking bar text.

local TEXT_SIZE = 12 -- matches the XP bar
local INSET = 4 -- UI units from the map's edges
local COORDS_INTERVAL = 0.2 -- seconds between coordinate updates
local CLOCK_INTERVAL = 1

-- Zone name colours by PvP type, like Blizzard's minimap zone text.
local ZONE_COLORS = {
	sanctuary = { 0.41, 0.8, 0.94 },
	arena = { 1, 0.1, 0.1 },
	combat = { 1, 0.1, 0.1 },
	friendly = { 0.1, 1, 0.1 },
	hostile = { 1, 0.1, 0.1 },
	contested = { 1, 0.7, 0 },
}
local ZONE_DEFAULT = { 1, 0.9, 0.7 }

-- Above the map, inside the holder.
local overlay = CreateFrame('Frame', nil, ns.minimap)
overlay:SetAllPoints(Minimap)

local function Text()
	local fs = ns.CreateText(overlay, TEXT_SIZE, 'semibold', 'OUTLINE')
	fs:SetWordWrap(false)
	return fs
end

local zone = Text()
zone:SetPoint('TOPLEFT', INSET, -INSET)
zone:SetPoint('TOPRIGHT', -INSET, -INSET)
zone:SetJustifyH('CENTER')

local clock = Text()
clock:SetPoint('BOTTOMLEFT', INSET, INSET)

local coords = Text()
coords:SetPoint('BOTTOMRIGHT', -INSET, INSET)

local function UpdateZone()
	zone:SetText(GetMinimapZoneText() or '')
	local pvpType = GetZonePVPInfo and GetZonePVPInfo()
	zone:SetTextColor(unpack(ZONE_COLORS[pvpType] or ZONE_DEFAULT))
end

local function UpdateClock()
	clock:SetText(date('%H:%M'))
end

-- Blank where the map has no position for you (most instances).
local function UpdateCoords()
	local mapID = C_Map.GetBestMapForUnit('player')
	local position = mapID and C_Map.GetPlayerMapPosition(mapID, 'player')
	if position then
		local x, y = position:GetXY()
		if x and y and not (issecretvalue and (issecretvalue(x) or issecretvalue(y))) and (x > 0 or y > 0) then
			coords:SetFormattedText('%.1f, %.1f', x * 100, y * 100)
			return
		end
	end
	coords:SetText('')
end

local sinceCoords, sinceClock = COORDS_INTERVAL, CLOCK_INTERVAL
overlay:SetScript('OnUpdate', function(_, elapsed)
	sinceCoords = sinceCoords + elapsed
	sinceClock = sinceClock + elapsed
	if sinceCoords >= COORDS_INTERVAL then
		sinceCoords = 0
		UpdateCoords()
	end
	if sinceClock >= CLOCK_INTERVAL then
		sinceClock = 0
		UpdateClock()
	end
end)

overlay:RegisterEvent('PLAYER_LOGIN')
overlay:RegisterEvent('PLAYER_ENTERING_WORLD')
overlay:RegisterEvent('ZONE_CHANGED')
overlay:RegisterEvent('ZONE_CHANGED_INDOORS')
overlay:RegisterEvent('ZONE_CHANGED_NEW_AREA')
overlay:SetScript('OnEvent', function()
	-- The map is re-parented into the holder at login; stay above it.
	overlay:SetFrameLevel(Minimap:GetFrameLevel() + 5)
	UpdateZone()
end)
