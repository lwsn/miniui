local _, ns = ...
local oUF = ns.oUF

-- Aura data is processed by the client inside AuraContainer frames; Lua only
-- defines groups, layout and what each button is made of. Buttons here are a
-- cropped icon on a black plate with a 1px edge, with outlined text drawn on
-- the icon: stack count top right, timer bottom left.

ns.auras = {}

-- Timer text: decimals under 10 seconds. The formatter is the client's, since
-- the remaining time itself is never handed to Lua.
local durationFormatter = C_StringUtil.CreateSecondsFormatter()
durationFormatter:SetDefaultAbbreviation(Enum.SecondsFormatterAbbreviation.OneLetter)
durationFormatter:SetMinInterval(Enum.SecondsFormatterInterval.Seconds)
durationFormatter:SetMillisecondsThreshold(10)
-- '42m' rather than '42 m 32 s'. Named after Blizzard's Lua SecondsFormatter;
-- guarded in case the client-side formatter lacks them.
if durationFormatter.SetDesiredUnitCount then
	durationFormatter:SetDesiredUnitCount(1)
end
if durationFormatter.SetStripIntervalWhitespace then
	durationFormatter:SetStripIntervalWhitespace(true)
end

-- The opposite of AuraContainerSortDirection.Normal, looked up rather than
-- named, since it's the enum's only other value.
for _, value in next, AuraContainerSortDirection do
	if value ~= AuraContainerSortDirection.Normal then
		ns.auras.SORT_REVERSED = value
	end
end

-- Button initializer, shared by unit frame and standalone containers.
-- Signature matches oUF's CreateButton override: (element, options, button).
-- Options used: size, dispelBorder, cancelButton, disableMouse.
function ns.auras.InitButton(element, options, button)
	local size = options.size
	button:SetSize(size, size)
	button:EnableMouse(not options.disableMouse)
	button:SetTooltipAnchorPoint('ANCHOR_CURSOR', 0, 0)

	local px = ns.Pixels(button, 1)

	local plate = button:CreateTexture(nil, 'BACKGROUND')
	plate:SetAllPoints()
	plate:SetColorTexture(0, 0, 0, 0.9)

	-- Dispel type tints the 1px edge instead of Blizzard's glossy border
	-- overlay: a white fill over the plate, under the icon, coloured by the
	-- client. Debuffs without a type keep the black edge.
	if options.dispelBorder then
		local edge = button:CreateTexture(nil, 'BACKGROUND', nil, 1)
		edge:SetAllPoints()
		edge:SetTexture([[Interface\Buttons\WHITE8X8]])
		button.Border = edge
		button:AddDispelTypeTexture(edge, {
			style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
			showWhenHarmful = true,
			showWhenHelpful = false,
			customDispelColorMap = oUF.colors.dispel,
		})
	end

	local icon = button:CreateTexture(nil, 'BORDER')
	icon:SetPoint('TOPLEFT', px, -px)
	icon:SetPoint('BOTTOMRIGHT', -px, px)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- crop the baked-in icon border
	button.Icon = icon
	button:SetIcon(icon)

	local cooldown = CreateFrame('Cooldown', nil, button, 'CooldownFrameTemplate')
	cooldown:SetAllPoints(icon)
	cooldown:SetDrawEdge(false)
	cooldown:SetReverse(true) -- the dark swipe grows as time runs out, instead of shrinking
	cooldown:SetHideCountdownNumbers(true) -- our timer text replaces it
	button.Cooldown = cooldown
	button:SetDurationCooldown(cooldown)

	-- Above the cooldown spiral.
	local overlay = CreateFrame('Frame', nil, button)
	overlay:SetAllPoints()
	overlay:SetFrameLevel(cooldown:GetFrameLevel() + 1)

	local duration = ns.CreateText(overlay, 10, 'semibold', 'OUTLINE')
	duration:SetPoint('BOTTOMLEFT', icon, 'BOTTOMLEFT', 1, 0)
	button.Time = duration
	button:SetDurationText(duration, { textFormatter = durationFormatter })

	local count = ns.CreateText(overlay, 11, 'semibold', 'OUTLINE')
	count:SetPoint('TOPRIGHT', icon, 'TOPRIGHT', 0, 0)
	button.Count = count
	button:SetApplicationCount(count, {})

	if options.cancelButton then
		button:SetCancelAuraButtons(options.cancelButton)
	end
end

