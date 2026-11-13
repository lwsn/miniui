local _, ns = ...

-- Player buffs and debuffs, replacing Blizzard's buff frame. Standalone (not
-- part of the player unit frame): buffs fill right-to-left from the top-right
-- corner, debuffs start on a new row below them.

local SIZE = 32
local SPACING = 4
local PER_ROW = 12
local MAX_BUFFS = 32
local MAX_DEBUFFS = 16

-- Weapon enchants (poisons, oils) live in TemporaryEnchantFrame on clients
-- that have it; it's left alone because aura containers don't show them.
local BLIZZARD = { 'BuffFrame', 'DebuffFrame' }

local hidden = CreateFrame('Frame')
hidden:Hide()

local function HideBlizzard()
	for _, name in ipairs(BLIZZARD) do
		local frame = _G[name]
		if frame then
			frame:UnregisterAllEvents()
			frame:SetParent(hidden)
		end
	end
end

-- Size and spacing in whole pixels, so every icon lands on the pixel grid.
local function AddGroup(container, key, filter, options, size, spacing)
	options.size = size
	options.layout = {
		elementSpacing = spacing,
		lineSpacing = spacing,
		groupLineSpacing = spacing * 3,
		forceNewLine = true,
	}
	options.sortMethod = AuraContainerSortMethod.ExpirationOnly
	options.sortDirection = ns.auras.SORT_REVERSED
	options.initializeFrame = GenerateClosure(ns.auras.InitButton, container, options)
	container:AddAuraGroup(key, filter, options)
end

local function Create()
	local container = CreateFrame('AuraContainer', 'miniuiPlayerAuras', UIParent, 'CustomAuraContainerTemplate')
	local size, spacing = ns.Snap(container, SIZE), ns.Snap(container, SPACING)
	local lineSize = PER_ROW * (size + spacing) - spacing
	container:SetSize(lineSize, size)
	container:SetPoint('TOPRIGHT', UIParent, 'TOPRIGHT', -ns.Snap(container, 220), -ns.Snap(container, 16))

	container:SetFlowLayoutAnchorPoint('TOPRIGHT')
	container:SetFlowLayoutMaximumLineSize(lineSize)
	container:SetFlowLayoutGrowthDirection(-1, -1) -- left, then down
	container:SetFlowLayoutPadding(0, 0, 0, 0)

	AddGroup(container, 'Buffs', 'HELPFUL', {
		maxFrameCount = MAX_BUFFS,
		cancelButton = 'RightButtonUp',
	}, size, spacing)
	AddGroup(container, 'Debuffs', 'HARMFUL', {
		maxFrameCount = MAX_DEBUFFS,
		dispelBorder = true,
	}, size, spacing)

	container:SetUnit('player')
	container:SetEnabled(true)
end

local loader = CreateFrame('Frame')
loader:RegisterEvent('PLAYER_LOGIN')
loader:SetScript('OnEvent', function()
	HideBlizzard()
	Create()
end)
