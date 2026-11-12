local _, ns = ...
local oUF = ns.oUF

oUF:Factory(function(self)
	self:SetActiveStyle('miniui')

	local player = self:Spawn('player')
	PixelUtil.SetPoint(player, 'CENTER', UIParent, 'CENTER', -260, -180)

	local target = self:Spawn('target')
	PixelUtil.SetPoint(target, 'CENTER', UIParent, 'CENTER', 260, -180)
end)
