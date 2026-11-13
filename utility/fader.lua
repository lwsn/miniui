local _, ns = ...

-- Fades idle frames. Only opacity changes, which is allowed on secure frames
-- in combat; faded frames keep working (clicks, keybinds).
--
--   player frame: 50% at full health, no target, out of combat, not casting
--   action bar 1: 50% with no target, out of combat
--
-- Health is a hidden value on this client, so "full health" can't be tested
-- in Lua. Instead the client evaluates an opacity curve over health % (1 below
-- full, FADED at full) and the hidden result goes straight to SetAlpha. If the
-- client refuses the hidden value, the frame stays visible.
--
-- Changes are instant: the health path can't be animated (its opacity is
-- hidden), so nothing is, to keep the two consistent.

local FADED = 0.5

local state = {
	combat = false,
	target = false,
	casting = false,
	fullHealth = true,
}

local function Known(...)
	if not issecretvalue then return true end
	for i = 1, select('#', ...) do
		if issecretvalue((select(i, ...))) then
			return false
		end
	end
	return true
end

-- Opacity over health %: 1 up to just below full, FADED at full.
local healthAlpha = C_CurveUtil.CreateColorCurve()
healthAlpha:AddPoint(0, CreateColor(1, 1, 1, 1))
healthAlpha:AddPoint(0.999, CreateColor(1, 1, 1, 1))
healthAlpha:AddPoint(1, CreateColor(1, 1, 1, FADED))

local curveRefused = false

-- Sets the player frame's opacity from the curve. Returns false if it can't.
local function ApplyHealthAlpha(frame)
	if curveRefused then return false end
	local values = frame.Health and frame.Health.values
	if not values then return false end
	local color = values:EvaluateCurrentHealthPercent(healthAlpha)
	local _, _, _, alpha = color:GetRGBA()
	if not pcall(frame.SetAlpha, frame, alpha) then
		curveRefused = true
		return false
	end
	return true
end

-- Rules: frame getter, and when it should be fully visible. A rule may
-- return 'health' to hand opacity to the health curve.
local FADERS = {
	{
		frame = function() return ns.playerFrame end,
		visible = function()
			if state.combat or state.target or state.casting then
				return true
			elseif state.fullHealth == nil then
				return 'health' -- hidden: let the client decide
			end
			return not state.fullHealth
		end,
	},
	{
		frame = function() return ns.actionbar end,
		visible = function()
			return state.combat or state.target
		end,
	},
}

local function Update()
	for _, fader in ipairs(FADERS) do
		local frame = fader.frame()
		if frame then
			local visible = fader.visible()
			if visible == 'health' then
				if not ApplyHealthAlpha(frame) then
					frame:SetAlpha(1)
				end
			else
				frame:SetAlpha(visible and 1 or FADED)
			end
		end
	end
end

-- State ------------------------------------------------------------------------

-- true / false when health is readable, nil when it's hidden.
local function UpdateHealth()
	local health, max = UnitHealth('player'), UnitHealthMax('player')
	if Known(health, max) then
		state.fullHealth = health >= max
	else
		state.fullHealth = nil
	end
end

local function UpdateCasting()
	local casting = UnitCastingInfo('player')
	local channeling = UnitChannelInfo('player')
	if not Known(casting, channeling) then
		state.casting = true
	else
		state.casting = casting ~= nil or channeling ~= nil
	end
end

local frame = CreateFrame('Frame')

local EVENTS = {
	PLAYER_REGEN_DISABLED = function() state.combat = true end,
	PLAYER_REGEN_ENABLED = function() state.combat = false end,
	PLAYER_TARGET_CHANGED = function() state.target = UnitExists('target') end,
	UNIT_HEALTH = UpdateHealth,
	UNIT_MAXHEALTH = UpdateHealth,
	UNIT_SPELLCAST_START = UpdateCasting,
	UNIT_SPELLCAST_STOP = UpdateCasting,
	UNIT_SPELLCAST_FAILED = UpdateCasting,
	UNIT_SPELLCAST_INTERRUPTED = UpdateCasting,
	UNIT_SPELLCAST_CHANNEL_START = UpdateCasting,
	UNIT_SPELLCAST_CHANNEL_STOP = UpdateCasting,
	UNIT_SPELLCAST_EMPOWER_START = UpdateCasting,
	UNIT_SPELLCAST_EMPOWER_STOP = UpdateCasting,
	PLAYER_LOGIN = function()
		-- Re-evaluate after oUF has refreshed the frame's health values, so
		-- the curve reads current health.
		local health = ns.playerFrame and ns.playerFrame.Health
		if health then
			local post = health.PostUpdate
			health.PostUpdate = function(...)
				if post then post(...) end
				Update()
			end
		end
	end,
	PLAYER_ENTERING_WORLD = function()
		state.combat = InCombatLockdown() or UnitAffectingCombat('player')
		state.target = UnitExists('target')
		UpdateHealth()
		UpdateCasting()
	end,
}

local UNIT_EVENTS = {
	UNIT_HEALTH = true, UNIT_MAXHEALTH = true,
	UNIT_SPELLCAST_START = true, UNIT_SPELLCAST_STOP = true,
	UNIT_SPELLCAST_FAILED = true, UNIT_SPELLCAST_INTERRUPTED = true,
	UNIT_SPELLCAST_CHANNEL_START = true, UNIT_SPELLCAST_CHANNEL_STOP = true,
	UNIT_SPELLCAST_EMPOWER_START = true, UNIT_SPELLCAST_EMPOWER_STOP = true,
}

for event in next, EVENTS do
	if not (C_EventUtils and C_EventUtils.IsEventValid) or C_EventUtils.IsEventValid(event) then
		if UNIT_EVENTS[event] then
			frame:RegisterUnitEvent(event, 'player')
		else
			frame:RegisterEvent(event)
		end
	end
end
frame:SetScript('OnEvent', function(_, event)
	EVENTS[event]()
	Update()
end)
