local _, ns = ...
local oUF = ns.oUF

-- Player and target hang off either side of action bar 1, top-aligned, 1px
-- away. The bar owns the screen position (actionbars/actionbars.lua).
oUF:Factory(function(self)
	self:SetActiveStyle('miniui')
	local bar = ns.actionbar

	local player = self:Spawn('player')
	player:SetPoint('TOPRIGHT', bar, 'TOPLEFT', -ns.Pixels(player, 1), 0)
	ns.playerFrame = player -- utility/fader.lua

	local target = self:Spawn('target')
	target:SetPoint('TOPLEFT', bar, 'TOPRIGHT', ns.Pixels(target, 1), 0)

	-- Party: a column under the player frame, left edges aligned, the first
	-- member's top level with the pet bar / leave-vehicle button (1px below
	-- bar 1). 1px apart. Sized in the secure config
	-- so members joining in combat still get the right size.
	local px = ns.Pixels(UIParent, 1)
	local width, height = ns.unitframes.PartySize(UIParent)
	local party = self:SpawnHeader('miniuiParty', nil,
		'showParty', true,
		'showPlayer', false,
		'point', 'TOP',
		'yOffset', -px, -- 1px gap between members
		'oUF-initialConfigFunction', ('self:SetWidth(%.6f) self:SetHeight(%.6f)'):format(width, height)
	)
	party:SetVisibility('custom [group:party,nogroup:raid] show; hide')
	-- The player frame's left edge: bar 1's left, minus the 1px gap and the
	-- player frame's width.
	party:SetPoint('TOPLEFT', bar, 'BOTTOMLEFT', -(1 + ns.layout.UnitFramePixels(UIParent)) * px, -px)
end)
