local _, ns = ...

-- Action bars 1-3. Bar 1 is a 6x2 grid below the screen centre, with the
-- player and target frames hung off its sides (see unitframes/spawn.lua).
-- Bars 2 and 3 are single rows of 12 either side of the minimap
-- (minimap/minimap.lua), bottom-aligned with it. Every size and offset is a whole number of physical
-- pixels, starting from a pixel-aligned origin, so 1px gaps stay 1px.
--
-- Buttons are bare SecureActionButtonTemplate buttons with all display code
-- here. Blizzard's ActionBarButtonTemplate is avoided on purpose: it registers
-- buttons into Blizzard's shared event dispatch, and addon-created entries
-- taint that dispatch for Blizzard's own buttons (secret value errors).
-- The standard keys for Blizzard's bars 1-3 are redirected here with
-- override bindings.

local GAP = 1 -- physical pixels between stacked bars, and between bars and the minimap
local TOP = -154 -- UI units below the screen centre: top edge of bar 1 and unit frames
local RANGE_INTERVAL = 0.2 -- seconds between range checks

local NUM = 12 -- buttons per bar

-- Bars: grid shape, and placement. 'CENTER' is below the screen centre;
-- 'LEFT'/'RIGHT' stack bottom-up beside the minimap, in this order. Bar 1 pages (forms, vehicles...); the others show a fixed set of
-- action slots, the same ones Blizzard's bars 2 and 3 use, and take those
-- bars' keybinds.
local BARS = {
	{ side = 'CENTER', columns = ns.layout.mainColumns, binding = 'ACTIONBUTTON', paging = true }, -- actions 1-12, paged
	{ side = 'LEFT', columns = 12, binding = 'MULTIACTIONBAR1BUTTON', offset = 60 }, -- bar 2 (bottom left): 61-72
	{ side = 'RIGHT', columns = 12, binding = 'MULTIACTIONBAR2BUTTON', offset = 48 }, -- bar 3 (bottom right): 49-60
}

-- Icon states, in priority order. Tints multiply the icon.
local OUT_OF_RANGE = { 1, 0.3, 0.3 }
local NO_RESOURCE = { 0.35, 0.5, 1 }
local UNUSABLE = { 0.45, 0.45, 0.45 } -- on top of desaturation

-- Paging, resolved securely: vehicles, possess and override bars first, then
-- manual paging (shift+number), then stance/form bars, then page 1.
local PAGING = table.concat({
	'[overridebar] override',
	'[vehicleui][possessbar] possess',
	'[shapeshift] shapeshift',
	'[bar:2] 2', '[bar:3] 3', '[bar:4] 4', '[bar:5] 5', '[bar:6] 6',
	'[bonusbar:5] 11', -- skyriding
	'[bonusbar:4] 10', '[bonusbar:3] 9', '[bonusbar:2] 8', '[bonusbar:1] 7',
	'1',
}, '; ')

-- API lookups: C_ActionBar where this client has it, globals otherwise.
local C = C_ActionBar or {}
local HasAction = C.HasAction or HasAction
local GetActionTexture = C.GetActionTexture or GetActionTexture
local IsUsableAction = C.IsUsableAction or IsUsableAction
local IsActionInRange = C.IsActionInRange or IsActionInRange
local IsCurrentAction = C.IsCurrentAction or IsCurrentAction
local IsAutoRepeatAction = C.IsAutoRepeatAction or IsAutoRepeatAction
local IsConsumableAction = C.IsConsumableAction or IsConsumableAction
local IsStackableAction = C.IsStackableAction or IsStackableAction
local GetActionCount = C.GetActionCount or GetActionCount
local GetActionCharges = C.GetActionCharges or GetActionCharges
local GetActionText = C.GetActionText or GetActionText
local GetActionCooldown = C.GetActionCooldown or GetActionCooldown
local GetActionCooldownDuration = C.GetActionCooldownDuration

local function IsSecret(...)
	if not issecretvalue then
		return false
	end
	for i = 1, select('#', ...) do
		if issecretvalue((select(i, ...))) then
			return true
		end
	end
	return false
end

-- Bar 1 is a secure state handler: it rewrites its buttons' actions on page
-- changes. It also owns the override bindings for every bar.
local bar = CreateFrame('Frame', 'miniuiActionBar', UIParent, 'SecureHandlerStateTemplate')
ns.actionbar = bar
-- Functions run after every layout, for frames that follow bar 1 without
-- anchoring to it (anchoring to a protected frame restricts showing them in
-- combat). See auras/procs.lua.
bar.onLayout = {}
BARS[1].frame = bar
for i = 2, #BARS do
	BARS[i].frame = CreateFrame('Frame', 'miniuiActionBar' .. i, UIParent)
end
bar.bar2 = BARS[2].frame -- chat/chat.lua sits left of it

local buttons = {} -- every button, all bars

-- Blizzard's bars. Their buttons stay alive (hidden) so nothing that pokes
-- them errors; the keys are taken over below.
local hidden = CreateFrame('Frame')
hidden:Hide()

local function HideBlizzard()
	for _, name in ipairs({ 'MainActionBar', 'MainMenuBar', 'MultiBarBottomLeft', 'MultiBarBottomRight' }) do
		local frame = _G[name]
		if frame then
			frame:SetParent(hidden)
		end
	end
end

-- Display updates ----------------------------------------------------------

local function UpdateIcon(button)
	local action = button.action
	if action and HasAction(action) then
		button.icon:SetTexture(GetActionTexture(action))
		button.icon:Show()
	else
		button.icon:Hide()
	end
end

local function UpdateState(button)
	local action = button.action
	if not action or not HasAction(action) then
		return
	end

	local usable, noResource = IsUsableAction(action)
	local inRange = IsActionInRange(action) -- nil when the action has no range
	if IsSecret(usable, noResource, inRange) then
		return
	end

	local tint
	if inRange == false then
		tint = OUT_OF_RANGE
	elseif noResource then
		tint = NO_RESOURCE
	elseif not usable then
		tint = UNUSABLE
	end
	button.icon:SetDesaturated(tint == UNUSABLE)
	if tint then
		button.icon:SetVertexColor(tint[1], tint[2], tint[3])
	else
		button.icon:SetVertexColor(1, 1, 1)
	end
end

local function UpdateChecked(button)
	local action = button.action
	local checked = action and (IsCurrentAction(action) or IsAutoRepeatAction(action))
	if not IsSecret(checked) then
		button:SetChecked(checked and true or false)
	end
end

local function UpdateCooldown(button)
	local action = button.action
	local cooldown = button.cooldown
	if not action or not HasAction(action) then
		cooldown:Clear()
		return
	end
	-- Duration objects carry hidden values straight to the widget.
	if GetActionCooldownDuration and cooldown.SetCooldownFromDurationObject then
		local duration = GetActionCooldownDuration(action)
		if duration then
			cooldown:SetCooldownFromDurationObject(duration)
		else
			cooldown:Clear()
		end
		return
	end
	local start, duration, _, modRate = GetActionCooldown(action)
	if type(start) == 'table' then
		start, duration, modRate = start.startTime, start.duration, start.modRate
	end
	cooldown:SetCooldown(start or 0, duration or 0, modRate or 1)
end

local function UpdateCount(button)
	local action = button.action
	local text = ''
	if action and HasAction(action) then
		if IsConsumableAction(action) or IsStackableAction(action) then
			text = GetActionCount(action)
		else
			local charges, maxCharges = GetActionCharges(action)
			if type(charges) == 'table' then
				charges, maxCharges = charges.currentCharges, charges.maxCharges
			end
			if IsSecret(maxCharges) or (maxCharges and maxCharges > 1) then
				text = charges
			end
		end
	end
	button.Count:SetText(text)
end

local function UpdateName(button)
	local action = button.action
	local isItem = action and (IsConsumableAction(action) or IsStackableAction(action))
	button.Name:SetText(action and not isItem and GetActionText(action) or '')
end

local function UpdateHotkey(button)
	ns.UpdateHotkey(button)
end

local function UpdateAll(button)
	UpdateIcon(button)
	UpdateState(button)
	UpdateChecked(button)
	UpdateCooldown(button)
	UpdateCount(button)
	UpdateName(button)
end

-- Button construction ------------------------------------------------------

local function OnEnter(button)
	if button.action and HasAction(button.action) then
		GameTooltip_SetDefaultAnchor(GameTooltip, button)
		GameTooltip:SetAction(button.action)
	end
end

local function OnLeave()
	GameTooltip:Hide()
end

-- Drag and drop out of combat. With bars locked, the pick-up modifier
-- (shift by default) is needed to drag an action off.
local function OnDragStart(button)
	if InCombatLockdown() then
		return
	end
	if not GetCVarBool('lockActionBars') or IsModifiedClick('PICKUPACTION') then
		PickupAction(button.action)
	end
end

local function OnReceiveDrag(button)
	if not InCombatLockdown() then
		PlaceAction(button.action)
	end
end

-- The secure handler sets 'action' when the page changes.
local function OnAttributeChanged(button, name, value)
	if name == 'action' then
		button.action = value
		UpdateAll(button)
	end
end

local function CreateButton(name, parent, binding, action)
	local button = CreateFrame('CheckButton', name, parent, 'SecureActionButtonTemplate')
	button.binding = binding
	button:SetAttribute('type', 'action')
	button:SetAttribute('action', action)
	button.action = action
	button:RegisterForClicks('AnyUp', 'AnyDown') -- the template honours the cast-on-key-down setting
	button:RegisterForDrag('LeftButton')
	button:SetScript('OnEnter', OnEnter)
	button:SetScript('OnLeave', OnLeave)
	button:SetScript('OnDragStart', OnDragStart)
	button:SetScript('OnReceiveDrag', OnReceiveDrag)
	button:HookScript('OnAttributeChanged', OnAttributeChanged)

	ns.SkinButton(button)

	return button
end

for barIndex, def in ipairs(BARS) do
	def.buttons = {}
	for i = 1, NUM do
		local name = barIndex == 1 and 'miniuiActionButton' .. i or ('miniuiActionBar%dButton%d'):format(barIndex, i)
		local button = CreateButton(name, def.frame, def.binding .. i, (def.offset or 0) + i)
		if def.paging then
			bar:SetFrameRef('button' .. i, button)
		end
		def.buttons[i] = button
		buttons[#buttons + 1] = button
	end
end

bar:SetAttribute('_onstate-page', ([[
	if newstate == 'possess' or newstate == 'override' or newstate == 'shapeshift' then
		if HasVehicleActionBar() then
			newstate = GetVehicleBarIndex()
		elseif HasOverrideActionBar() then
			newstate = GetOverrideBarIndex()
		elseif HasTempShapeshiftActionBar() then
			newstate = GetTempShapeshiftBarIndex()
		elseif HasBonusActionBar() then
			newstate = GetBonusBarIndex()
		else
			newstate = 1
		end
	end
	local page = tonumber(newstate) or 1
	for i = 1, %d do
		self:GetFrameRef('button' .. i):SetAttribute('action', i + (page - 1) * %d)
	end
]]):format(NUM, NUM))

-- Layout, in pixels. Called out of combat only: the bar and the unit frames
-- anchored to it are protected.
local function Layout()
	local px = ns.Pixels(bar, 1)
	local size = ns.layout.ButtonPixels(bar)
	local step = size + ns.layout.buttonSpacing

	local below = {} -- per side: the bar the next one stacks on
	for _, def in ipairs(BARS) do
		local frame = def.frame
		local columns = def.columns
		local rows = math.ceil(NUM / columns)
		local width = ns.layout.GridPixels(bar, columns)
		local height = ns.layout.GridPixels(bar, rows)
		frame:SetSize(width * px, height * px)
		frame:ClearAllPoints()
		if def.side == 'CENTER' then
			-- TOPLEFT rather than TOP/CENTER: an odd pixel width centred
			-- would land on half pixels.
			frame:SetPoint('TOPLEFT', UIParent, 'CENTER', -math.floor(width / 2) * px, math.floor(TOP / px + 0.5) * px)
		elseif below[def.side] then
			frame:SetPoint('BOTTOMLEFT', below[def.side], 'TOPLEFT', 0, GAP * px)
		elseif def.side == 'LEFT' then
			frame:SetPoint('BOTTOMRIGHT', ns.minimap, 'BOTTOMLEFT', -GAP * px, 0)
		else
			frame:SetPoint('BOTTOMLEFT', ns.minimap, 'BOTTOMRIGHT', GAP * px, 0)
		end
		below[def.side] = frame

		for i, button in ipairs(def.buttons) do
			local col = (i - 1) % columns
			local row = math.floor((i - 1) / columns)
			button:SetSize(size * px, size * px)
			button:ClearAllPoints()
			button:SetPoint('TOPLEFT', frame, 'TOPLEFT', col * step * px, -row * step * px)
		end
	end

	for _, fn in ipairs(bar.onLayout) do
		fn()
	end
end

-- Standard action bar keys click our buttons instead.
local function Bind()
	ClearOverrideBindings(bar)
	for _, button in ipairs(buttons) do
		for _, key in ipairs({ GetBindingKey(button.binding) }) do
			SetOverrideBindingClick(bar, false, key, button:GetName(), 'LeftButton')
		end
		UpdateHotkey(button)
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

local function ForEach(fn)
	for _, button in ipairs(buttons) do
		fn(button)
	end
end

-- Events --------------------------------------------------------------------

local EVENTS = {
	ACTIONBAR_SLOT_CHANGED = function(slot)
		for _, button in ipairs(buttons) do
			if slot == 0 or button.action == slot then
				UpdateAll(button)
			end
		end
	end,
	ACTIONBAR_UPDATE_STATE = function() ForEach(UpdateChecked) end,
	TRADE_SKILL_SHOW = function() ForEach(UpdateChecked) end,
	TRADE_SKILL_CLOSE = function() ForEach(UpdateChecked) end,
	START_AUTOREPEAT_SPELL = function() ForEach(UpdateChecked) end,
	STOP_AUTOREPEAT_SPELL = function() ForEach(UpdateChecked) end,
	PLAYER_ENTER_COMBAT = function() ForEach(UpdateChecked) end, -- auto-attack on
	PLAYER_LEAVE_COMBAT = function() ForEach(UpdateChecked) end, -- auto-attack off
	ACTIONBAR_UPDATE_USABLE = function() ForEach(UpdateState) end,
	SPELL_UPDATE_USABLE = function() ForEach(UpdateState) end,
	PLAYER_TARGET_CHANGED = function() ForEach(UpdateState) end,
	ACTIONBAR_UPDATE_COOLDOWN = function() ForEach(UpdateCooldown) end,
	SPELL_UPDATE_COOLDOWN = function() ForEach(UpdateCooldown) end,
	SPELL_UPDATE_CHARGES = function() ForEach(UpdateCount) end,
	BAG_UPDATE_DELAYED = function() ForEach(UpdateCount) end,
	UPDATE_BINDINGS = function() Run(Bind) end,
	UI_SCALE_CHANGED = function() Run(Layout) end,
	DISPLAY_SIZE_CHANGED = function() Run(Layout) end,
	PLAYER_ENTERING_WORLD = function() ForEach(UpdateAll) end,
	PLAYER_REGEN_ENABLED = function()
		-- Catch up on anything skipped while values were hidden in combat.
		ForEach(UpdateAll)
		for fn in next, pending do
			pending[fn] = nil
			fn()
		end
	end,
	PLAYER_LOGIN = function()
		HideBlizzard()
		Layout()
		Bind()
		RegisterStateDriver(bar, 'page', PAGING)
		ForEach(UpdateAll)
	end,
}

for event in next, EVENTS do
	bar:RegisterEvent(event)
end
bar:SetScript('OnEvent', function(_, event, ...)
	EVENTS[event](...)
end)

-- Range has no reliable event for every action, so it's polled.
local elapsed = 0
bar:SetScript('OnUpdate', function(_, delta)
	elapsed = elapsed + delta
	if elapsed >= RANGE_INTERVAL then
		elapsed = 0
		ForEach(UpdateState)
	end
end)
