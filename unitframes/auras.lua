local _, ns = ...

-- Target auras: everything you cast on the target, debuffs first, then buffs.
-- No hostility switching needed: you can't buff enemies, and your debuffs on
-- friends are rare and worth seeing (Weakened Soul, Forbearance). The only
-- buffs that show on a hostile target are ones cast before it turned hostile,
-- like on a duel partner.

local SIZE = 28 -- UI units, like the bars
local SPACING = 1 -- physical pixels: between icons, and between the frame and the icons
local MAX = 16

local function GroupOptions(self, options)
	local spacing = ns.Pixels(self, SPACING)
	options.size = SIZE
	options.maxFrameCount = MAX
	options.tooltipAnchor = self.mirrored and 'ANCHOR_TOPRIGHT' or 'ANCHOR_TOPLEFT'
	options.layout = { elementSpacing = spacing, lineSpacing = spacing }
	options.sortDirection = AuraContainerSortDirection.Normal -- shortest remaining first, at the left
	options.CreateButton = ns.auras.InitButton
	return options
end

function ns.auras.AttachTarget(self)
	-- Always left-to-right, even on mirrored frames: reads in sort order.
	local side = 'LEFT'

	local auras = self:CreateAuras({
		initialAnchor = 'BOTTOM' .. side,
		growthX = 'RIGHT',
		growthY = 'UP',
		layoutLimit = self:GetWidth(),
	})
	auras:SetSize(self:GetWidth(), SIZE)
	auras:SetPoint('BOTTOM' .. side, self, 'TOP' .. side, 0, ns.Pixels(self, SPACING))

	auras:AddGroup('HARMFUL|PLAYER', GroupOptions(self, { dispelBorder = true }))
	auras:AddGroup('HELPFUL|PLAYER', GroupOptions(self, {}))
end
