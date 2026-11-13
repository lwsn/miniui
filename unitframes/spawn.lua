local _, ns = ...
local oUF = ns.oUF

-- Player and target hang off either side of action bar 1, top-aligned, 1px
-- away. The bar owns the screen position (actionbars/actionbars.lua).
oUF:Factory(function(self)
	self:SetActiveStyle('miniui')
	local bar = ns.actionbar

	local player = self:Spawn('player')
	player:SetPoint('TOPRIGHT', bar, 'TOPLEFT', -ns.Pixels(player, 1), 0)

	local target = self:Spawn('target')
	target:SetPoint('TOPLEFT', bar, 'TOPRIGHT', ns.Pixels(target, 1), 0)
end)
