local _, ns = ...

-- Bag buttons in one row at the bottom right of the screen, bottom-aligned
-- with the minimap. Our own buttons with the action button skin
-- (actionbars/skin.lua), not Blizzard's restyled: their art kept coming back.
-- Blizzard's bag bar and the micro menu are hidden.
--
-- Left to right: keyring and reagent bag (where this client has them),
-- bags 4-1, backpack. The backpack shows free slots in regular bags.

local RIGHT = 10 -- UI units from the right edge of the screen
local BOTTOM = 10 -- UI units from the bottom; same as the minimap

local BACKPACK_ICON = 133633 -- INV_Misc_Bag_08
local KEYRING_ICON = 134237 -- INV_Misc_Key_14

local GetContainerNumFreeSlots = C_Container and C_Container.GetContainerNumFreeSlots or GetContainerNumFreeSlots
local ContainerIDToInventoryID = C_Container and C_Container.ContainerIDToInventoryID or ContainerIDToInventoryID
local NUM_BAGS = NUM_BAG_SLOTS or 4

-- Blizzard frames to hide.
local HIDE = {
	'MicroMenuContainer',
	'MicroMenu',
	'MicroButtonAndBagsBar',
	'BagsBar',
	'BagBarExpandToggle',
	'KeyRingButton',
	'CharacterReagentBag0Slot',
	'CharacterBag3Slot',
	'CharacterBag2Slot',
	'CharacterBag1Slot',
	'CharacterBag0Slot',
	'MainMenuBarBackpackButton',
}

local holder = CreateFrame('Frame', 'miniuiBags', UIParent)
ns.bags = holder

local hidden = CreateFrame('Frame')
hidden:Hide()

local buttons = {}

-- Bag definitions -------------------------------------------------------------

local function IsCursorHoldingItem()
	return CursorHasItem and CursorHasItem()
end

local function Backpack()
	return {
		bag = 0,
		icon = function() return BACKPACK_ICON end,
		toggle = function() ToggleBackpack() end,
		tooltip = function() GameTooltip:SetText(BACKPACK_TOOLTIP or 'Backpack', 1, 1, 1) end,
		put = function() PutItemInBackpack() end,
	}
end

-- Equippable bag slot: bags 1-4, and the reagent bag.
local function BagSlot(bag)
	local slot = ContainerIDToInventoryID(bag)
	return {
		bag = bag,
		slot = slot,
		icon = function() return GetInventoryItemTexture('player', slot) end,
		toggle = function() ToggleBag(bag) end,
		tooltip = function()
			if not GameTooltip:SetInventoryItem('player', slot) then
				GameTooltip:SetText(EQUIP_CONTAINER or 'Equip Container', 1, 1, 1)
			end
		end,
		put = function() PutItemInBag(slot) end,
		pickup = function() PickupBagFromSlot(slot) end,
	}
end

local function Keyring()
	return {
		bag = KEYRING_CONTAINER,
		icon = function() return KEYRING_ICON end,
		toggle = function() ToggleKeyRing() end,
		tooltip = function() GameTooltip:SetText(KEYRING or 'Keyring', 1, 1, 1) end,
	}
end

local function Definitions()
	local defs = {}
	if ToggleKeyRing and KEYRING_CONTAINER then
		defs[#defs + 1] = Keyring()
	end
	local reagent = Enum.BagIndex and Enum.BagIndex.ReagentBag
	if reagent and ContainerIDToInventoryID(reagent) then
		defs[#defs + 1] = BagSlot(reagent)
	end
	for bag = NUM_BAGS, 1, -1 do
		defs[#defs + 1] = BagSlot(bag)
	end
	defs[#defs + 1] = Backpack()
	return defs
end

-- Display ---------------------------------------------------------------------

local function UpdateIcon(button)
	local icon = button.def.icon()
	button.icon:SetTexture(icon)
	button.icon:SetShown(icon ~= nil)
end

local function UpdateChecked(button)
	local bag = button.def.bag
	button:SetChecked(bag ~= nil and IsBagOpen(bag) and true or false)
end

-- Free slots in regular bags only, like Blizzard's backpack count.
local function UpdateFreeSlots(button)
	if button.def.bag ~= 0 then return end
	local free = 0
	for bag = 0, NUM_BAGS do
		local slots, family = GetContainerNumFreeSlots(bag)
		if family == 0 then
			free = free + (slots or 0)
		end
	end
	button.Count:SetText(free)
end

local function UpdateAll()
	for _, button in ipairs(buttons) do
		UpdateIcon(button)
		UpdateChecked(button)
		UpdateFreeSlots(button)
	end
end

-- Interaction -----------------------------------------------------------------

local function OnClick(button)
	local def = button.def
	if IsCursorHoldingItem() and def.put then
		def.put()
	else
		def.toggle()
	end
	UpdateChecked(button) -- undo the CheckButton's own toggle until the bag reports
end

local function OnDragStart(button)
	if button.def.pickup then
		button.def.pickup()
	end
end

local function OnReceiveDrag(button)
	if button.def.put then
		button.def.put()
	end
end

local function OnEnter(button)
	GameTooltip:SetOwner(button, 'ANCHOR_TOPLEFT')
	button.def.tooltip()
	GameTooltip:Show()
end

local function OnLeave()
	GameTooltip:Hide()
end

local function CreateButton(index, def)
	local button = CreateFrame('CheckButton', 'miniuiBag' .. index, holder)
	button.def = def
	button:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
	button:RegisterForDrag('LeftButton')
	button:SetScript('OnClick', OnClick)
	button:SetScript('OnDragStart', OnDragStart)
	button:SetScript('OnReceiveDrag', OnReceiveDrag)
	button:SetScript('OnEnter', OnEnter)
	button:SetScript('OnLeave', OnLeave)
	ns.SkinButton(button)
	return button
end

-- Layout ----------------------------------------------------------------------

local function Place()
	local px = ns.Pixels(holder, 1)
	local size = ns.layout.ButtonPixels(holder)
	local step = size + ns.layout.buttonSpacing

	holder:SetSize(ns.layout.GridPixels(holder, #buttons) * px, size * px)
	holder:ClearAllPoints()
	holder:SetPoint('BOTTOMRIGHT', UIParent, 'BOTTOMRIGHT',
		-math.floor(RIGHT / px + 0.5) * px, math.floor(BOTTOM / px + 0.5) * px)

	for i, button in ipairs(buttons) do
		button:SetSize(size * px, size * px)
		button:ClearAllPoints()
		button:SetPoint('TOPLEFT', holder, 'TOPLEFT', (i - 1) * step * px, 0)
	end
end

local function HideBlizzard()
	for _, name in ipairs(HIDE) do
		local frame = _G[name]
		if frame then
			frame:SetParent(hidden)
		end
	end
end

-- Events ----------------------------------------------------------------------

local EVENTS = {
	'BAG_UPDATE_DELAYED',
	'BAG_OPEN',
	'BAG_CLOSED',
	'BAG_CONTAINER_UPDATE',
	'UNIT_INVENTORY_CHANGED',
	'PLAYER_ENTERING_WORLD',
	'UI_SCALE_CHANGED',
	'DISPLAY_SIZE_CHANGED',
}

local function IsEventValid(event)
	if C_EventUtils and C_EventUtils.IsEventValid then
		return C_EventUtils.IsEventValid(event)
	end
	return pcall(holder.RegisterEvent, holder, event)
end

holder:RegisterEvent('PLAYER_LOGIN')
holder:SetScript('OnEvent', function(_, event, unit)
	if event == 'PLAYER_LOGIN' then
		for i, def in ipairs(Definitions()) do
			buttons[i] = CreateButton(i, def)
		end
		Place()
		HideBlizzard()
		for _, name in ipairs(EVENTS) do
			if IsEventValid(name) then
				holder:RegisterEvent(name)
			end
		end
		UpdateAll()
	elseif event == 'UI_SCALE_CHANGED' or event == 'DISPLAY_SIZE_CHANGED' then
		Place()
	elseif event == 'UNIT_INVENTORY_CHANGED' and unit ~= 'player' then
		return
	else
		UpdateAll()
	end
end)

-- Bags also open and close through keybinds and the bag frames themselves;
-- the checked state follows whichever path was taken.
for _, name in ipairs({ 'ToggleBag', 'ToggleBackpack', 'OpenAllBags', 'CloseAllBags', 'ToggleAllBags' }) do
	if _G[name] then
		hooksecurefunc(name, function()
			C_Timer.After(0, UpdateAll)
		end)
	end
end
