local _, ns = ...

-- Square minimap with a 1px black border, centred at the bottom of the screen
-- and raised a little off the edge. The action bars line up against it
-- (actionbars/actionbars.lua). Sizes snap to whole pixels from a
-- pixel-aligned origin, like the bars.
--
-- Blizzard's minimap cluster (zone text, clock, tracking, mail and so on) is
-- hidden; the Minimap frame itself is moved out of it.

local BOTTOM = 10 -- UI units from the bottom of the screen to the border's bottom edge

-- Holder: the map plus its 1px border. Other modules anchor to this.
local holder = CreateFrame('Frame', 'miniuiMinimap', UIParent)
holder:SetFrameStrata('LOW')
ns.minimap = holder

local border = holder:CreateTexture(nil, 'BACKGROUND')
border:SetAllPoints()
border:SetColorTexture(0, 0, 0, 1)

local hidden = CreateFrame('Frame')
hidden:Hide()

-- Addons that place buttons around the minimap (LibDBIcon) ask for its shape.
function GetMinimapShape()
	return 'SQUARE'
end

local placing = false

local function Place()
	placing = true
	local px = ns.Pixels(holder, 1)
	local outer = ns.layout.MainPixels(holder) -- action bar 1's width, border included
	local size = outer - 2

	-- The action bars are anchored to the holder, so it only moves out of
	-- combat.
	if not InCombatLockdown() then
		holder:SetSize(outer * px, outer * px)
		holder:ClearAllPoints()
		-- BOTTOMLEFT rather than BOTTOM: an odd pixel width centred would
		-- land on half pixels.
		holder:SetPoint('BOTTOMLEFT', UIParent, 'BOTTOM', -math.floor(outer / 2) * px, math.floor(BOTTOM / px + 0.5) * px)
	end

	Minimap:SetParent(holder)
	Minimap:SetFrameLevel(holder:GetFrameLevel() + 1)
	Minimap:ClearAllPoints()
	Minimap:SetPoint('TOPLEFT', holder, 'TOPLEFT', px, -px)
	Minimap:SetSize(size * px, size * px)
	placing = false
end

local function SquareMask()
	Minimap:SetMaskTexture(ns.media.texture)
	-- The map used in some instances has its own round mask.
	if HybridMinimap and HybridMinimap.CircleMask then
		HybridMinimap.CircleMask:SetTexture(ns.media.texture)
	end
end

local function HideBlizzard()
	if MinimapCluster then
		MinimapCluster:SetParent(hidden)
	end
	for _, region in ipairs({
		_G.MinimapCompassTexture,
		_G.MinimapBackdrop,
		Minimap.ZoomIn,
		Minimap.ZoomOut,
		Minimap.ZoomHitArea,
	}) do
		if region then
			region:SetParent(hidden)
		end
	end
end

-- Scroll to zoom, since the zoom buttons are gone.
-- Right-click: Blizzard's tracking menu, at the cursor. Its button lives in
-- the hidden cluster, so its menu is reopened here: the menu-system
-- generator where the client has one, the old dropdown otherwise.
local function OpenTrackingMenu()
	local tracking = MinimapCluster and MinimapCluster.Tracking
	local button = tracking and tracking.Button
	if button and button.menuGenerator and MenuUtil and MenuUtil.CreateContextMenu then
		MenuUtil.CreateContextMenu(Minimap, button.menuGenerator)
		return
	end
	local dropdown = (tracking and tracking.DropDown) or _G.MiniMapTrackingDropDown
	if dropdown and ToggleDropDownMenu then
		ToggleDropDownMenu(1, nil, dropdown, 'cursor', 0, 0)
		return
	end
	if button and button.OpenMenu then
		button:OpenMenu()
	end
end

-- Replaces Blizzard's handler, which pings on any button: only the left
-- button reaches it now.
local blizzardOnMouseUp

local function OnMouseUp(self, mouseButton, ...)
	if mouseButton == 'RightButton' then
		OpenTrackingMenu()
	elseif mouseButton == 'MiddleButton' then
		if ns.ToggleMinimapButtons then
			ns.ToggleMinimapButtons() -- minimap/buttons.lua
		end
	elseif blizzardOnMouseUp then
		blizzardOnMouseUp(self, mouseButton, ...)
	end
end

local function OnMouseWheel(_, delta)
	local zoom = Minimap:GetZoom() + (delta > 0 and 1 or -1)
	Minimap:SetZoom(math.max(0, math.min(Minimap:GetZoomLevels() - 1, zoom)))
end

holder:RegisterEvent('PLAYER_LOGIN')
holder:RegisterEvent('ADDON_LOADED')
holder:RegisterEvent('UI_SCALE_CHANGED')
holder:RegisterEvent('DISPLAY_SIZE_CHANGED')
holder:SetScript('OnEvent', function(_, event, name)
	if event == 'PLAYER_LOGIN' then
		Place()
		HideBlizzard()
		SquareMask()
		Minimap:EnableMouseWheel(true)
		Minimap:SetScript('OnMouseWheel', OnMouseWheel)
		blizzardOnMouseUp = Minimap:GetScript('OnMouseUp')
		Minimap:SetScript('OnMouseUp', OnMouseUp)
		-- Blizzard re-anchors the minimap inside its cluster on some layout
		-- changes; put it back.
		hooksecurefunc(Minimap, 'SetPoint', function()
			if not placing then
				Place()
			end
		end)
	elseif event == 'ADDON_LOADED' then
		if name == 'Blizzard_HybridMinimap' then
			SquareMask()
		end
	elseif not InCombatLockdown() then
		Place()
	end
end)
