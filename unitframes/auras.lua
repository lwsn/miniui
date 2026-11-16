local _, ns = ...

-- Unit frame auras: two blocks of columns above the frame, 1px away, growing
-- upwards. Debuffs sit on the side next to action bar 1, buffs on the outer
-- side; column counts are in ns.layout.auraColumns. Every block fills from
-- its outer bottom corner towards the bar, longest-lasting first, so the
-- shortest auras end up innermost on the top row.
--
-- Target: only what you cast. No hostility switching needed: you can't buff
-- enemies, and your debuffs on friends are rare and worth seeing (Weakened
-- Soul, Forbearance). The only buffs that show on a hostile target are ones
-- cast before it turned hostile, like on a duel partner.

local SPACING = 1 -- physical pixels between the frame and the icons
local OVERLAP = -1 -- physical pixels between icons: neighbours share their black edge
local ROWS = 4 -- per block: each shows at most columns * ROWS auras

local function GroupOptions(self, options)
	local spacing = ns.Pixels(self, OVERLAP)
	options.width = ns.Snap(self, ns.auras.WIDTH) -- whole pixels
	options.height = ns.Snap(self, ns.auras.HEIGHT)
	options.mirrored = self.mirrored -- bars drain the same way as the frame's
	options.layout = { elementSpacing = spacing, lineSpacing = spacing }
	options.sortMethod = AuraContainerSortMethod.ExpirationOnly
	options.sortDirection = AuraContainerSortDirection.Reverse -- longest first, shortest last (top, inner)
	options.CreateButton = ns.auras.InitButton
	return options
end

-- A block of `columns` aura columns, placed on the frame's `side` edge and
-- filling towards `inward` (the bar's side).
local function Block(self, side, inward, columns, filter, options)
	local spacing, px = ns.Pixels(self, SPACING), ns.Pixels(self, 1)
	local width, height = ns.Snap(self, ns.auras.WIDTH), ns.Snap(self, ns.auras.HEIGHT)
	local limit = columns * width + (columns - 1) * ns.Pixels(self, OVERLAP)

	local auras = self:CreateAuras({
		initialAnchor = 'BOTTOM' .. (inward == 'LEFT' and 'RIGHT' or 'LEFT'),
		growthX = inward,
		growthY = 'UP',
		-- A pixel of slack: an exact fit can drop the last column to float
		-- error. It's far less than a column, so it never adds one.
		layoutLimit = limit + px,
	})
	auras:SetSize(limit, height)
	auras:SetPoint('BOTTOM' .. side, self, 'TOP' .. side, 0, spacing)
	GroupOptions(self, options)
	options.maxFrameCount = columns * ROWS
	options.edgeColor = filter:find('HARMFUL') and ns.auras.DEBUFF_EDGE or ns.auras.BUFF_EDGE
	auras:AddGroup(filter, options)
end

-- Player is left of bar 1: debuffs on its right.
function ns.auras.AttachPlayer(self)
	local columns = ns.layout.auraColumns.player
	Block(self, 'LEFT', 'RIGHT', columns.buffs, 'HELPFUL', { cancelButton = 'RightButtonUp' })
	Block(self, 'RIGHT', 'RIGHT', columns.debuffs, 'HARMFUL', { dispelBorder = true })
end

-- Target is right of bar 1: debuffs on its left.
function ns.auras.AttachTarget(self)
	local columns = ns.layout.auraColumns.target
	Block(self, 'LEFT', 'LEFT', columns.debuffs, 'HARMFUL|PLAYER', { dispelBorder = true })
	Block(self, 'RIGHT', 'LEFT', columns.buffs, 'HELPFUL|PLAYER', {})
end
