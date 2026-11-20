local _, ns = ...

-- Frame rate in the top-right corner: plain number on a dark plate, since
-- text never sits directly on the world.

local RIGHT = 10 -- UI units from the right edge, like the bags
local TOP = 10 -- UI units from the top
local INTERVAL = 0.5 -- seconds between updates
local TEXT_SIZE = 12

local frame = CreateFrame('Frame', 'miniuiFPS', UIParent)
frame:SetFrameStrata('LOW')

local plate = frame:CreateTexture(nil, 'BACKGROUND')
plate:SetAllPoints()
plate:SetColorTexture(0, 0, 0, 0.8)

local text = ns.CreateText(frame, TEXT_SIZE, 'semibold')
text:SetPoint('RIGHT', -4, 0)
text:SetJustifyH('RIGHT')
text:SetTextColor(0.85, 0.85, 0.85)

local function Place()
	local px = ns.Pixels(frame, 1)
	frame:SetSize(math.floor(40 / px + 0.5) * px, math.floor(16 / px + 0.5) * px)
	frame:ClearAllPoints()
	frame:SetPoint('TOPRIGHT', UIParent, 'TOPRIGHT', -math.floor(RIGHT / px + 0.5) * px, -math.floor(TOP / px + 0.5) * px)
end

local elapsed = INTERVAL
frame:SetScript('OnUpdate', function(_, delta)
	elapsed = elapsed + delta
	if elapsed >= INTERVAL then
		elapsed = 0
		text:SetFormattedText('%d fps', GetFramerate() + 0.5)
	end
end)

frame:RegisterEvent('PLAYER_LOGIN')
frame:RegisterEvent('UI_SCALE_CHANGED')
frame:RegisterEvent('DISPLAY_SIZE_CHANGED')
frame:SetScript('OnEvent', Place)
