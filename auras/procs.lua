local _, ns = ...

-- Proc borders: a pulsing coloured border around action bar 1 while a watched
-- buff is up. Add a proc by adding a line to PROCS.
--
-- Aura data is secret in combat, so Lua never learns whether a proc is up.
-- Each proc is instead an AuraContainer with one aura group that only accepts
-- that spell ID (as the AuraTimers addon does): the client decides when the
-- group's button is shown, and the button is built here as nothing but the
-- border.
--
-- The client is strict about that button:
-- - It can't have script handlers, or the client refuses to show and hide it
--   (a script would reveal whether the proc is up).
-- - Everything made in initializeFrame is forbidden to addon code afterwards,
--   so it must be complete when built: the border anchors to the container
--   (which we own and can move), and the pulse is an animation the client
--   plays itself each time the aura shows (AddAuraShownAnimation).
-- - Containers and groups can only be built while auras aren't secret, or
--   during login. They're built on bar 1's first layout, which runs at login.
--
-- The border is 2px: bar 1's outer black edge plus the 1px gap around it, so
-- it never covers icons or neighbouring frames. Procs up at the same time
-- draw on top of each other, later entries on top.

local PROCS = {
	{ spell = 16870, color = { 0.62, 0.78, 0.95 } }, -- Clearcasting (Omen of Clarity): pale blue
}

local THICKNESS = 2 -- physical pixels
local PULSE = true -- false: a steady border
local PULSE_MIN = 0.35 -- border opacity at the bottom of the pulse
local PULSE_TIME = 0.6 -- seconds from full to PULSE_MIN

local containers = {}

-- Builds the group's button: four edge textures on a child frame that covers
-- the container, plus the pulse. Nothing here may be touched later.
local function InitBorder(container, color, button)
	button:EnableMouse(false) -- clicks and tooltips go to the action buttons

	local glow = CreateFrame('Frame', nil, button)
	glow:SetAllPoints(container) -- follows the container on later layouts

	local t = ns.Pixels(container, THICKNESS)
	local function Edge()
		local edge = glow:CreateTexture(nil, 'OVERLAY')
		edge:SetColorTexture(color[1], color[2], color[3], 1)
		return edge
	end

	local top = Edge()
	top:SetPoint('TOPLEFT')
	top:SetPoint('TOPRIGHT')
	top:SetHeight(t)
	local bottom = Edge()
	bottom:SetPoint('BOTTOMLEFT')
	bottom:SetPoint('BOTTOMRIGHT')
	bottom:SetHeight(t)
	local left = Edge()
	left:SetPoint('TOPLEFT', 0, -t)
	left:SetPoint('BOTTOMLEFT', 0, t)
	left:SetWidth(t)
	local right = Edge()
	right:SetPoint('TOPRIGHT', 0, -t)
	right:SetPoint('BOTTOMRIGHT', 0, t)
	right:SetWidth(t)

	if PULSE and button.AddAuraShownAnimation then
		local pulse = glow:CreateAnimationGroup()
		pulse:SetLooping('BOUNCE')
		local fade = pulse:CreateAnimation('Alpha')
		fade:SetFromAlpha(1)
		fade:SetToAlpha(PULSE_MIN)
		fade:SetDuration(PULSE_TIME)
		fade:SetSmoothing('IN_OUT')
		button:AddAuraShownAnimation(pulse)
	end
end

-- Covers bar 1 plus 1px on every side. Positioned from the bar's edges rather
-- than anchored to it: the bar is protected, and frames anchored to it can't
-- be shown in combat.
local function Place(container)
	local bar = ns.actionbar
	local px = ns.Pixels(container, 1)
	local width, height = bar:GetWidth() + 2 * px, bar:GetHeight() + 2 * px

	container:SetSize(width, height)
	container:ClearAllPoints()
	container:SetPoint('TOPLEFT', UIParent, 'BOTTOMLEFT', bar:GetLeft() - px, bar:GetTop() + px)
	container:SetFlowLayoutMaximumLineSize(width)
	return width, height
end

local function Create(proc, index)
	local container = CreateFrame('AuraContainer', nil, UIParent, 'CustomAuraContainerTemplate')
	if not (container and container.AddAuraGroup) then
		return
	end
	-- The template fills containers with made-up auras in Edit Mode.
	if container.SetEditModePreviewEnabled then
		container:SetEditModePreviewEnabled(false)
	end

	-- Above the action buttons and their cooldowns; the border only overlaps
	-- the bar's outer edge.
	container:SetFrameStrata('HIGH')
	container:SetFrameLevel(10 + index)
	container:EnableMouse(false)
	local width, height = Place(container)
	container:SetUnit('player')
	container:SetEnabled(true)

	container:AddAuraGroup('Proc', 'HELPFUL', {
		maxFrameCount = 1,
		candidateFilters = { includeSpellIDs = { [proc.spell] = true } },
		initializeFrame = GenerateClosure(InitBorder, container, proc.color),
		layout = {
			elementSpacing = 0,
			lineSpacing = 0,
			elementWidth = width,
			elementHeight = height,
		},
	})

	container:SetFlowLayoutPadding(0, 0, 0, 0)
	container:SetFlowLayoutAnchorPoint('TOPLEFT')
	container:Show()
	table.insert(containers, container)
end

-- Built on bar 1's first layout (at login, when building is allowed); later
-- layouts only move them.
table.insert(ns.actionbar.onLayout, function()
	if #containers == 0 then
		for index, proc in ipairs(PROCS) do
			Create(proc, index)
		end
	else
		for _, container in ipairs(containers) do
			Place(container)
		end
	end
end)
