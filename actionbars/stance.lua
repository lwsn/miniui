local _, ns = ...

-- Stance / form bar: one button per form, in a row at the bottom left of the
-- screen, mirroring the bags at the bottom right. Action button skin and
-- size. Bare secure buttons that cast the form's spell (Blizzard's stance
-- template would taint its shared updates, like the action bar one did).
-- Keys bound to Blizzard's stance buttons (SHAPESHIFTBUTTON1-10) click these.
--
-- Which forms exist only changes out of combat in practice; if it does change
-- in combat, the buttons catch up when combat ends.

local LEFT = 10 -- UI units from the left edge, like the bags from the right
local BOTTOM = 10 -- UI units from the bottom
local MAX = 10

local UNUSABLE = { 0.45, 0.45, 0.45 } -- as on the action bars, with desaturation

local BLIZZARD = { 'StanceBar', 'StanceBarFrame', 'ShapeshiftBarFrame' }

local holder = CreateFrame('Frame', 'miniuiStanceBar', UIParent)

local hidden = CreateFrame('Frame')
hidden:Hide()

local buttons = {}
local count = 0 -- forms laid out

-- Display -----------------------------------------------------------------------

local function UpdateButton(button)
	local icon, active, castable = GetShapeshiftFormInfo(button.index)
	if not icon then return end
	button.icon:SetTexture(icon)
	button:SetChecked(active and true or false)
	button.icon:SetDesaturated(not castable)
	if castable then
		button.icon:SetVertexColor(1, 1, 1)
	else
		button.icon:SetVertexColor(unpack(UNUSABLE))
	end
	local start, duration, enabled = GetShapeshiftFormCooldown(button.index)
	if issecretvalue and (issecretvalue(start) or issecretvalue(duration) or issecretvalue(enabled)) then
		button.cooldown:SetCooldown(start, duration) -- hidden values go straight to the widget
	elseif enabled and enabled ~= 0 and start and duration then
		button.cooldown:SetCooldown(start, duration)
	else
		button.cooldown:Clear()
	end
end

local function UpdateAll()
	for i = 1, count do
		UpdateButton(buttons[i])
	end
end

-- Buttons ------------------------------------------------------------------------

local function OnEnter(button)
	GameTooltip_SetDefaultAnchor(GameTooltip, button)
	GameTooltip:SetShapeshift(button.index)
end

local function OnLeave()
	GameTooltip:Hide()
end

for i = 1, MAX do
	local button = CreateFrame('CheckButton', 'miniuiStanceButton' .. i, holder, 'SecureActionButtonTemplate')
	button.index = i
	button.binding = 'SHAPESHIFTBUTTON' .. i
	button:SetAttribute('type', 'spell')
	button:RegisterForClicks('AnyUp', 'AnyDown') -- the template honours the cast-on-key-down setting
	button:SetScript('OnEnter', OnEnter)
	button:SetScript('OnLeave', OnLeave)
	-- The secure click casts; the checked state is ours to set.
	button:HookScript('PostClick', UpdateButton)
	ns.SkinButton(button)
	button:Hide()
	buttons[i] = button
end

-- Layout (out of combat only: the buttons are protected) --------------------------

local function Setup()
	count = math.min(MAX, GetNumShapeshiftForms() or 0)

	local px = ns.Pixels(holder, 1)
	local size = ns.layout.ButtonPixels(holder)
	local step = size + ns.layout.buttonSpacing

	holder:SetSize(math.max(1, ns.layout.GridPixels(holder, math.max(1, count))) * px, size * px)
	holder:ClearAllPoints()
	holder:SetPoint('BOTTOMLEFT', UIParent, 'BOTTOMLEFT',
		math.floor(LEFT / px + 0.5) * px, math.floor(BOTTOM / px + 0.5) * px)

	for i, button in ipairs(buttons) do
		if i <= count then
			local _, _, _, spellID = GetShapeshiftFormInfo(i)
			button:SetAttribute('spell', spellID)
			button:SetSize(size * px, size * px)
			button:ClearAllPoints()
			button:SetPoint('TOPLEFT', holder, 'TOPLEFT', (i - 1) * step * px, 0)
			button:Show()
		else
			button:SetAttribute('spell', nil)
			button:Hide()
		end
	end

	ClearOverrideBindings(holder)
	for i = 1, count do
		local button = buttons[i]
		for _, key in ipairs({ GetBindingKey(button.binding) }) do
			SetOverrideBindingClick(holder, false, key, button:GetName(), 'LeftButton')
		end
		ns.UpdateHotkey(button)
	end

	UpdateAll()
end

local pending = false

local function RequestSetup()
	if InCombatLockdown() then
		pending = true
	else
		Setup()
	end
end

-- Events ---------------------------------------------------------------------------

local EVENTS = {
	UPDATE_SHAPESHIFT_FORMS = RequestSetup,
	UPDATE_BINDINGS = RequestSetup,
	UI_SCALE_CHANGED = RequestSetup,
	DISPLAY_SIZE_CHANGED = RequestSetup,
	PLAYER_ENTERING_WORLD = RequestSetup,
	PLAYER_REGEN_ENABLED = function()
		if pending then
			pending = false
			Setup()
		end
	end,
	UPDATE_SHAPESHIFT_FORM = UpdateAll,
	UPDATE_SHAPESHIFT_USABLE = UpdateAll,
	UPDATE_SHAPESHIFT_COOLDOWN = UpdateAll,
	ACTIONBAR_UPDATE_COOLDOWN = UpdateAll,
	SPELL_UPDATE_COOLDOWN = UpdateAll,
}

holder:RegisterEvent('PLAYER_LOGIN')
holder:SetScript('OnEvent', function(_, event)
	if event == 'PLAYER_LOGIN' then
		for _, name in ipairs(BLIZZARD) do
			local frame = _G[name]
			if frame then
				frame:SetParent(hidden)
			end
		end
		for e in next, EVENTS do
			if not (C_EventUtils and C_EventUtils.IsEventValid) or C_EventUtils.IsEventValid(e) then
				holder:RegisterEvent(e)
			end
		end
		Setup()
	else
		EVENTS[event]()
	end
end)
