local _, ns = ...

-- Small always-on conveniences:
--   * sell grey items and repair at merchants
--   * loot everything at once when auto loot applies
--   * accept, progress and turn in quests
--   * maximum camera zoom distance
--   * no drunken haze
-- Holding shift when opening a merchant or quest NPC skips the automation
-- for that visit.

local C = C_Container or {}
local GetContainerNumSlots = C.GetContainerNumSlots or GetContainerNumSlots
local UseContainerItem = C.UseContainerItem or UseContainerItem
local NUM_BAGS = NUM_BAG_SLOTS or 4

local SELL_INTERVAL = 0.15 -- seconds between sales; selling everything at once can be throttled
local LOOT_INTERVAL = 0.3 -- seconds between bulk loot attempts

local function Print(message)
	print('|cff9a9a9aminiui:|r ' .. message)
end

local function Money(copper)
	return GetCoinTextureString and GetCoinTextureString(copper) or tostring(copper)
end

-- Bag item quality and sell value, old and new container APIs.
local function ItemAt(bag, slot)
	if C.GetContainerItemInfo then
		local info = C.GetContainerItemInfo(bag, slot)
		if not info then return end
		return info.quality, info.hasNoValue, info.hyperlink, info.stackCount
	end
	local _, count, _, quality, _, _, link, _, noValue = GetContainerItemInfo(bag, slot)
	return quality, noValue, link, count
end

-- Junk ----------------------------------------------------------------------------

local selling, earned, tried

local function StopSelling()
	if selling then
		selling:Cancel()
		selling = nil
		if earned > 0 then
			Print('sold junk for ' .. Money(earned))
		end
	end
end

-- Sells one grey item per tick until none are left or the merchant closes.
local function SellNext()
	if not MerchantFrame or not MerchantFrame:IsShown() then
		StopSelling()
		return
	end
	for bag = 0, NUM_BAGS do
		for slot = 1, GetContainerNumSlots(bag) or 0 do
			local quality, noValue, link, count = ItemAt(bag, slot)
			local key = bag * 1000 + slot
			if quality == 0 and not noValue and link and not tried[key] then
				local price = select(11, GetItemInfo(link)) or 0
				if price > 0 then
					tried[key] = true -- never retried, in case the merchant refuses it
					earned = earned + price * (count or 1)
					UseContainerItem(bag, slot)
					return
				end
			end
		end
	end
	StopSelling()
end

local function SellJunk()
	StopSelling()
	earned, tried = 0, {}
	selling = C_Timer.NewTicker(SELL_INTERVAL, SellNext)
	SellNext()
end

-- Repairs -------------------------------------------------------------------------

local function Repair()
	if not CanMerchantRepair() then return end
	local cost, canRepair = GetRepairAllCost()
	if not canRepair or cost <= 0 then return end

	-- Guild funds first, where the guild allows it and covers the bill.
	if IsInGuild() and CanGuildBankRepair and CanGuildBankRepair() then
		local allowance = GetGuildBankWithdrawMoney and GetGuildBankWithdrawMoney() or 0
		if allowance == -1 or allowance >= cost then
			RepairAllItems(true)
			Print('repaired for ' .. Money(cost) .. ' (guild)')
			return
		end
	end
	if GetMoney() >= cost then
		RepairAllItems()
		Print('repaired for ' .. Money(cost))
	else
		Print('not enough money to repair (' .. Money(cost) .. ')')
	end
end

-- Faster loot ---------------------------------------------------------------------

local lastLoot = 0

-- Takes every slot at once instead of waiting for the loot window to work
-- through them. Only when auto loot applies (the setting, flipped by its
-- modifier).
local function FastLoot()
	if GetTime() - lastLoot < LOOT_INTERVAL then return end
	if GetCVarBool('autoLootDefault') == IsModifiedClick('AUTOLOOTTOGGLE') then return end
	lastLoot = GetTime()
	for i = GetNumLootItems(), 1, -1 do
		LootSlot(i)
	end
end

-- Quests --------------------------------------------------------------------------

-- Gossip NPCs: turn in finished quests first, then pick up new ones (skipping
-- low-level trivial ones).
local function OnGossip()
	local G = C_GossipInfo
	if not G then return end
	for _, quest in ipairs(G.GetActiveQuests() or {}) do
		if quest.isComplete then
			G.SelectActiveQuest(quest.questID)
			return
		end
	end
	for _, quest in ipairs(G.GetAvailableQuests() or {}) do
		if not quest.isTrivial then
			G.SelectAvailableQuest(quest.questID)
			return
		end
	end
end

-- Older quest greeting windows (no gossip).
local function OnGreeting()
	for i = 1, GetNumActiveQuests() do
		local _, isComplete = GetActiveTitle(i)
		if isComplete then
			SelectActiveQuest(i)
			return
		end
	end
	for i = 1, GetNumAvailableQuests() do
		local isTrivial = GetAvailableQuestInfo and GetAvailableQuestInfo(i)
		if not isTrivial then
			SelectAvailableQuest(i)
			return
		end
	end
end

-- Rewards: take the only one; with a choice, leave it to you.
local function OnComplete()
	if (GetQuestMoneyToGet and GetQuestMoneyToGet() or 0) > 0 then return end
	local choices = GetNumQuestChoices()
	if choices <= 1 then
		GetQuestReward(choices == 1 and 1 or 0)
	end
end

local QUEST_EVENTS = {
	GOSSIP_SHOW = OnGossip,
	QUEST_GREETING = OnGreeting,
	QUEST_DETAIL = function() AcceptQuest() end,
	QUEST_ACCEPT_CONFIRM = function() ConfirmAcceptQuest() end, -- escort quests started by others
	QUEST_PROGRESS = function()
		if IsQuestCompletable() then
			CompleteQuest()
		end
	end,
	QUEST_COMPLETE = OnComplete,
}

-- Events --------------------------------------------------------------------------

local frame = CreateFrame('Frame')

local EVENTS = {
	MERCHANT_SHOW = function()
		if IsShiftKeyDown() then return end
		Repair()
		SellJunk()
	end,
	MERCHANT_CLOSED = StopSelling,
	LOOT_READY = FastLoot,
	PLAYER_LOGIN = function()
		SetCVar('cameraDistanceMaxZoomFactor', 2.6) -- the client's maximum
		SetCVar('ffxGlow', 0) -- full-screen glow, which is what draws the drunken haze
	end,
}

for event, handler in next, QUEST_EVENTS do
	EVENTS[event] = function(...)
		if not IsShiftKeyDown() then
			handler(...)
		end
	end
end

for event in next, EVENTS do
	if not (C_EventUtils and C_EventUtils.IsEventValid) or C_EventUtils.IsEventValid(event) then
		frame:RegisterEvent(event)
	end
end
frame:SetScript('OnEvent', function(_, event, ...)
	EVENTS[event](...)
end)
