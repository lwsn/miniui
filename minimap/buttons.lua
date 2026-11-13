local _, ns = ...

-- Addon minimap buttons (LibDBIcon) collected into a bag over the minimap,
-- toggled by middle-clicking the map. Buttons get the action button look:
-- square, cropped icon, 1px shared borders, laid out in rows from the top
-- left. Addons that don't use LibDBIcon aren't collected.

local bag = CreateFrame('Frame', 'miniuiMinimapButtons', ns.minimap)
bag:Hide()

local plate = bag:CreateTexture(nil, 'BACKGROUND')
plate:SetAllPoints()
plate:SetColorTexture(0, 0, 0, 0.8)

local buttons = {}
local placing = false

local function IsHiddenByAddon(button)
	return button.db and button.db.hide
end

-- Rows of buttons across the map's width, the bag sized to fit them.
local function Layout()
	placing = true
	local px = ns.Pixels(bag, 1)
	local size = ns.layout.ButtonPixels(bag)
	local step = size + ns.layout.buttonSpacing
	local mapWidth = math.floor(Minimap:GetWidth() / px + 0.5)
	local columns = math.max(1, math.floor((mapWidth - size) / step) + 1)

	local shown = {}
	for _, button in ipairs(buttons) do
		if not IsHiddenByAddon(button) then
			shown[#shown + 1] = button
		end
	end

	local rows = math.max(1, math.ceil(#shown / columns))
	local cols = math.max(1, math.min(columns, #shown))
	bag:SetSize(ns.layout.GridPixels(bag, cols) * px, ns.layout.GridPixels(bag, rows) * px)
	bag:ClearAllPoints()
	bag:SetPoint('TOPLEFT', Minimap, 'TOPLEFT', 0, 0)
	bag:SetFrameLevel(Minimap:GetFrameLevel() + 10)

	for i, button in ipairs(shown) do
		local col = (i - 1) % columns
		local row = math.floor((i - 1) / columns)
		button:SetParent(bag)
		button:SetSize(size * px, size * px)
		button:ClearAllPoints()
		button:SetPoint('TOPLEFT', bag, 'TOPLEFT', col * step * px, -row * step * px)
		button:SetAlpha(1)
		button:Show()
	end
	placing = false
end

-- Strips LibDBIcon's round art and puts the icon on our plate.
local function Style(button)
	local px = ns.Pixels(bag, 1)
	if button.border then button.border:SetTexture(nil) end
	if button.background then button.background:SetTexture(nil) end
	local highlight = button:GetHighlightTexture()
	if highlight then
		highlight:SetTexture(ns.media.texture)
		highlight:SetVertexColor(1, 1, 1, 0.15)
		highlight:ClearAllPoints()
		highlight:SetPoint('TOPLEFT', px, -px)
		highlight:SetPoint('BOTTOMRIGHT', -px, px)
	end

	local back = button:CreateTexture(nil, 'BACKGROUND', nil, -8)
	back:SetAllPoints()
	back:SetColorTexture(0, 0, 0, 1)

	local icon = button.icon
	icon:ClearAllPoints()
	icon:SetPoint('TOPLEFT', px, -px)
	icon:SetPoint('BOTTOMRIGHT', -px, px)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	-- No dragging around the map, and no pressed-icon shift (it resets the crop).
	button:RegisterForDrag()
	button:SetScript('OnDragStart', nil)
	button:SetScript('OnDragStop', nil)
	button:SetScript('OnMouseDown', nil)
	button:SetScript('OnMouseUp', nil)
	button.showOnMouseover = false

	-- LibDBIcon re-anchors buttons around the map; put them back.
	hooksecurefunc(button, 'SetPoint', function()
		if not placing then
			Layout()
		end
	end)
end

local function Collect(button)
	for _, known in ipairs(buttons) do
		if known == button then return end
	end
	buttons[#buttons + 1] = button
	Style(button)
	Layout()
end

function ns.ToggleMinimapButtons()
	if #buttons == 0 then return end
	Layout()
	bag:SetShown(not bag:IsShown())
end

bag:RegisterEvent('PLAYER_LOGIN')
bag:SetScript('OnEvent', function()
	local icons = LibStub and LibStub('LibDBIcon-1.0', true)
	if not icons then return end
	for _, name in ipairs(icons:GetButtonList()) do
		local button = icons:GetMinimapButton(name)
		if button then
			Collect(button)
		end
	end
	-- Buttons created later (addons loaded on demand).
	icons.RegisterCallback(bag, 'LibDBIcon_IconCreated', function(_, button)
		Collect(button)
	end)
end)
