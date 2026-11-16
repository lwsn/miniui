local _, ns = ...

-- Hides Blizzard's buff frame. Player buffs and debuffs are shown above the
-- player frame instead (unitframes/auras.lua).

-- Weapon enchants (poisons, oils) live in TemporaryEnchantFrame on clients
-- that have it; it's left alone because aura containers don't show them.
local BLIZZARD = { 'BuffFrame', 'DebuffFrame' }

local hidden = CreateFrame('Frame')
hidden:Hide()

local loader = CreateFrame('Frame')
loader:RegisterEvent('PLAYER_LOGIN')
loader:SetScript('OnEvent', function()
	for _, name in ipairs(BLIZZARD) do
		local frame = _G[name]
		if frame then
			frame:UnregisterAllEvents()
			frame:SetParent(hidden)
		end
	end
end)
