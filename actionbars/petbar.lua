local _, ns = ...

-- Pet bar and leave-vehicle button, below action bar 1 (1px gap), shown only
-- when needed. Vehicle, possess and override abilities don't need a bar of
-- their own: bar 1 pages to them (actionbars/actionbars.lua).
--
-- The pet bar's 10 buttons are sized to span bar 1's width exactly: button
-- size is rounded down and the leftover pixels go one each to the first
-- buttons, so borders stay on whole pixels. Same bare-secure-button approach
-- as the action bars; keys bound to Blizzard's pet buttons
-- (BONUSACTIONBUTTON1-10) click these.

local NUM = NUM_PET_ACTION_SLOTS or 10
local GAP = 1 -- physical pixels below bar 1
local AUTOCAST = { 0.85, 0.7, 0.25 } -- border colour while autocast is on

local EXIT_ICON = [[Interface\Vehicles\UI-Vehicles-Button-Exit-Up]]

local BLIZZARD = { 'PetActionBar', 'PetActionBarFrame', 'MainMenuBarVehicleLeaveButton' }

local bar1 = ns.actionbar

local petbar = CreateFrame('Frame', 'miniuiPetBar', UIParent, 'SecureHandlerStateTemplate')
local buttons = {}

local hidden = CreateFrame('Frame')
hidden:Hide()

-- Display -------------------------------------------------------------------------

local function UpdateButton(button)
	local name, texture, isToken, isActive, autoCastAllowed, autoCastEnabled = GetPetActionInfo(button.index)
	if not name and not texture then
		button.icon:Hide()
		button:SetChecked(false)
		button.cooldown:Clear()
		button.plate:SetColorTexture(0, 0, 0, 1)
		return
	end
	button.icon:SetTexture(isToken and _G[texture] or texture)
	button.icon:Show()
	button:SetChecked(isActive and true or false)

	local usable = GetPetActionSlotUsable and GetPetActionSlotUsable(button.index)
	button.icon:SetDesaturated(usable == false)
	button.icon:SetVertexColor(usable == false and 0.45 or 1, usable == false and 0.45 or 1, usable == false and 0.45 or 1)

	if autoCastAllowed and autoCastEnabled then
		button.plate:SetColorTexture(AUTOCAST[1], AUTOCAST[2], AUTOCAST[3], 1)
	else
		button.plate:SetColorTexture(0, 0, 0, 1)
	end

	local start, duration, enabled = GetPetActionCooldown(button.index)
	if issecretvalue and (issecretvalue(start) or issecretvalue(duration)) then
		button.cooldown:SetCooldown(start, duration)
	elseif enabled and enabled ~= 0 and start and duration and duration > 0 then
		button.cooldown:SetCooldown(start, duration)
	else
		button.cooldown:Clear()
	end
end

local function UpdateAll()
	for _, button in ipairs(buttons) do
		UpdateButton(button)
	end
end

-- Buttons -----------------------------------------------------------------------

local function OnEnter(button)
	GameTooltip_SetDefaultAnchor(GameTooltip, button)
	GameTooltip:SetPetAction(button.index)
end

local function OnLeave()
	GameTooltip:Hide()
end

-- Right-click toggles autocast, like Blizzard's pet buttons. Not a secure
-- click: only left clicks cast.
local function OnMouseUp(button, mouseButton)
	if mouseButton == 'RightButton' and button:IsMouseOver() then
		TogglePetAutocast(button.index)
	end
end

for i = 1, NUM do
	local button = CreateFrame('CheckButton', 'miniuiPetButton' .. i, petbar, 'SecureActionButtonTemplate')
	button.index = i
	button.binding = 'BONUSACTIONBUTTON' .. i
	button:SetAttribute('type', 'pet')
	button:SetAttribute('action', i)
	button:RegisterForClicks('LeftButtonUp', 'LeftButtonDown')
	button:SetScript('OnEnter', OnEnter)
	button:SetScript('OnLeave', OnLeave)
	button:SetScript('OnMouseUp', OnMouseUp)
	button:HookScript('PostClick', UpdateButton)
	ns.SkinButton(button)
	buttons[i] = button
end

-- Shown with a pet, except while a vehicle or pet battle takes over.
RegisterStateDriver(petbar, 'visibility', '[petbattle][vehicleui][overridebar][possessbar] hide; [@pet,exists] show; hide')

-- Leave vehicle -------------------------------------------------------------------

local leave = CreateFrame('Button', 'miniuiLeaveVehicle', UIParent, 'SecureActionButtonTemplate')
leave:SetAttribute('type', 'macro')
leave:SetAttribute('macrotext', '/leavevehicle')
leave:RegisterForClicks('AnyUp')
ns.SkinButton(leave)
leave.icon:SetTexture(EXIT_ICON)
leave.icon:SetTexCoord(0.15, 0.85, 0.15, 0.85)
leave:SetScript('OnEnter', function(self)
	GameTooltip_SetDefaultAnchor(GameTooltip, self)
	GameTooltip:SetText(LEAVE_VEHICLE or 'Leave Vehicle', 1, 1, 1)
	GameTooltip:Show()
end)
leave:SetScript('OnLeave', OnLeave)
RegisterStateDriver(leave, 'visibility', '[canexitvehicle] show; hide')

-- Layout (out of combat only: everything here is protected) -----------------------

local function Layout()
	local px = ns.Pixels(petbar, 1)
	local width = math.floor(bar1:GetWidth() / px + 0.5)
	local spacing = ns.layout.buttonSpacing

	-- NUM buttons plus (NUM - 1) spacings fill `width`; the remainder pixels
	-- widen the first buttons by one each.
	local inner = width - (NUM - 1) * spacing
	local size = math.floor(inner / NUM)
	local extra = inner - size * NUM

	petbar:SetSize(width * px, size * px)
	petbar:ClearAllPoints()
	petbar:SetPoint('TOPLEFT', bar1, 'BOTTOMLEFT', 0, -GAP * px)

	local x = 0
	for i, button in ipairs(buttons) do
		local w = size + (i <= extra and 1 or 0)
		button:SetSize(w * px, size * px)
		button:ClearAllPoints()
		button:SetPoint('TOPLEFT', petbar, 'TOPLEFT', x * px, 0)
		x = x + w + spacing
	end

	-- Leave button: full action button size, under bar 1's left end.
	local buttonSize = ns.layout.ButtonPixels(leave)
	leave:SetSize(buttonSize * px, buttonSize * px)
	leave:ClearAllPoints()
	leave:SetPoint('TOPLEFT', bar1, 'BOTTOMLEFT', 0, -GAP * px)
end

local function Bind()
	ClearOverrideBindings(petbar)
	for _, button in ipairs(buttons) do
		for _, key in ipairs({ GetBindingKey(button.binding) }) do
			SetOverrideBindingClick(petbar, false, key, button:GetName(), 'LeftButton')
		end
		ns.UpdateHotkey(button)
	end
end

local pending = {}

local function Run(fn)
	if InCombatLockdown() then
		pending[fn] = true
	else
		fn()
	end
end

-- Events --------------------------------------------------------------------------

local EVENTS = {
	PET_BAR_UPDATE = UpdateAll,
	PET_BAR_UPDATE_COOLDOWN = UpdateAll,
	PET_BAR_UPDATE_USABLE = UpdateAll,
	PET_UI_UPDATE = UpdateAll,
	PET_SPECIALIZATION_CHANGED = UpdateAll,
	PLAYER_CONTROL_LOST = UpdateAll,
	PLAYER_CONTROL_GAINED = UpdateAll,
	PLAYER_TARGET_CHANGED = UpdateAll,
	UNIT_PET = UpdateAll,
	PLAYER_ENTERING_WORLD = UpdateAll,
	UPDATE_BINDINGS = function() Run(Bind) end,
	UI_SCALE_CHANGED = function() Run(Layout) end,
	DISPLAY_SIZE_CHANGED = function() Run(Layout) end,
	PLAYER_REGEN_ENABLED = function()
		for fn in next, pending do
			pending[fn] = nil
			fn()
		end
	end,
	PLAYER_LOGIN = function()
		for _, name in ipairs(BLIZZARD) do
			local frame = _G[name]
			if frame then
				frame:SetParent(hidden)
			end
		end
		Layout()
		Bind()
		UpdateAll()
	end,
}

for event in next, EVENTS do
	if not (C_EventUtils and C_EventUtils.IsEventValid) or C_EventUtils.IsEventValid(event) then
		petbar:RegisterEvent(event)
	end
end
petbar:SetScript('OnEvent', function(_, event)
	EVENTS[event]()
end)
