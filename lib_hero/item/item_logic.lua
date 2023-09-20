-- - #################################################################################### -
-- - - VUL-FT Full Takeover Bot Script for Dota 2 by yewchi // 'does stuff' on Steam
-- - - 
-- - - MIT License
-- - - 
-- - - Copyright (c) 2022 Michael, zyewchi@gmail.com, github.com/yewchi, gitlab.com/yewchi
-- - - 
-- - - Permission is hereby granted, free of charge, to any person obtaining a copy
-- - - of this software and associated documentation files (the "Software"), to deal
-- - - in the Software without restriction, including without limitation the rights
-- - - to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- - - copies of the Software, and to permit persons to whom the Software is
-- - - furnished to do so, subject to the following conditions:
-- - - 
-- - - The above copyright notice and this permission notice shall be included in all
-- - - copies or substantial portions of the Software.
-- - - 
-- - - THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- - - IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- - - FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- - - AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- - - LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- - - OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- - - SOFTWARE.
-- - #################################################################################### -

-- Detects component items so we can know that a hero doesn't need to re-buy something after reloads, or any other reason for reset of data.
-- TODO TODO TODO Make an item build choice relational map with the C-side and reformulate it each fortnight,
-- - when heroes run out of items to build, use their current items bought to pick items that score most likely
-- - to be bought based on previous choices.
local ITEM_MAX_PLAYER_STORAGE = ITEM_MAX_PLAYER_STORAGE
local ITEM_INVENTORY_AND_BACKPACK_STORAGE = ITEM_INVENTORY_AND_BACKPACK_STORAGE
local ITEM_MAX_COURIER_STORAGE = ITEM_INVENTORY_AND_BACKPACK_STORAGE

local TPSCROLL_SLOT = TPSCROLL_SLOT
local NEUTRAL_ITEM_SLOT = NEUTRAL_ITEM_SLOT

local ITEM_END_INVENTORY_INDEX = ITEM_END_INVENTORY_INDEX
local ITEM_END_BACKPACK_INDEX = ITEM_END_BACKPACK_INDEX
local ITEM_END_STASH_INDEX = ITEM_END_STASH_INDEX

local ITEM_NAME_SEARCH_START = ITEM_NAME_SEARCH_START

ITEM_ENSURE_RESULT_READY = true
ITEM_ENSURE_RESULT_WAIT = 1
ITEM_ENSURE_RESULT_LOCKED = false
local ITEM_ENSURE_RESULT_READY = ITEM_ENSURE_RESULT_READY
local ITEM_ENSURE_RESULT_WAIT = ITEM_ENSURE_RESULT_WAIT
local ITEM_ENSURE_RESULT_LOCKED = ITEM_ENSURE_RESULT_LOCKED

local ITEM_HAVE_AGHS_SHARD_MYSTERIOUS = ITEM_HAVE_AGHS_SHARD_MYSTERIOUS

ITEM_NOT_FOUND = -1 -- the fail result of FindItemInSlot
local ITEM_NOT_FOUND = ITEM_NOT_FOUND

ITEM_SWITCH_ITEM_READY_TIME = 7.0
local ITEM_SWITCH_ITEM_READY_TIME = ITEM_SWITCH_ITEM_READY_TIME

local ITEM_WAVE_CLEAR_NOT_ATTACK = ITEM_WAVE_CLEAR_NOT_ATTACK
local ITEM_WAVE_CLEAR_ATTACK = ITEM_WAVE_CLEAR_ATTACK

APPROX_MJOL_STATIC_TAKEN_PER_HIT = 0.75*200/5
local APPROX_MJOL_STATIC_TAKEN_PER_HIT = APPROX_MJOL_STATIC_TAKEN_PER_HIT

local max = math.max
local min = math.min

local ITEM_RES_MAP_COMPONENTS_I__COMBINES_TO = 0
local item_resolution_map = {} -- end of file init

local EMPTY_TABLE = EMPTY_TABLE
print("THE EMPTY TABLE IS WHILE LOADING", EMPTY_TABLE, EMPTY_TABLE[1])

---- item_logic constants --
local PLACEHOLDER_PURCHASE_SUCCESS = -1 -- Not sure, observed return when courier picking up new item via pUnit:ActionImmediate_PurchaseItem(). 

local CONSUMABLE_ITEM_SEARCH = {
		"faer", --2, -- item_faerie_fire -- N.B. Requires string.find, shares behavior # with what looks like a 'basic' item number.
		"tem_tang", --8, -- item_tango
		"tem_ward", --8240, -- item_ward_* (dispenser, observer, sentry)
		"tem_flas", --33556488, -- item_flask, -- item_clarity
		"_clarity",
		"tem_dust",
		"ant_mang", --33564676, -- item_enchanted_mango
		"smoke_of", --33554436, -- item_smoke_of_deceit
		"lood_gre"
}
local HEALTH_ON_USE_ITEM_SEARCH = {
		"faer",
		"tang",
		"flas",
		"magic_",
		"holy_l",
		"bott",
		"meka",
		"guar"
}
local MANA_ON_USE_ITEM_SEARCH = {
		"clarity",
		"ench",
		"magic_",
		"holy_l",
		"bott",
		"arca",
		"guar"
}
local INVIS_ITEM_SEARCH = {
		"shadow_amulet",
		"shadow_blade",
		"silver_edge"
}

local zero_f = function() return 0, 0 end
local wand_f = function(p, i) return 15*i:GetCurrentCharges(), 0 end
local RESOURCE_VALUE_OF_ITEM = {
		["item_tango"] = {function(p, i) return 112*i:GetCurrentCharges(), 16*i:GetCurrentCharges() end, zero_f},
		["item_clarity"] = {zero_f, function() return 180, 30 end},
		["item_flask"] = {function() return 400, 0 end, zero_f},
		["item_magic_stick"] = {wand_f, wand_f},
		["item_magic_wand"] = {wand_f, wand_f},
		["item_holy_locket"] = {wand_f, wand_f},
		["item_bloodstone"] = {function(p) return p.maxMana*0.6, 2 end, function(p) return -p.maxMana*0.3, 0 end},
		["item_enchanted_mango"] = {zero_f, function() return 100, 0 end},
		["item_bottle"] = {function(p, i) return 125*i:GetCurrentCharges(), 2.5*i:GetCurrentCharges() end, function(p, i) return 75*i:GetCurrentCharges(), 2.5*i:GetCurrentCharges() end},
		["item_faerie_fire"] = {function() return 85, 0 end, zero_f},
		["item_mekansm"] = {function() return 275, 0 end, zero_f},
		["item_arcane_boots"] = {zero_f, function() return 160, 0 end},
		["item_guardian_greaves"] = {function() return 300, 0 end, function() return 200, 0 end},
		["item_urn_of_shadows"] = {function(p, i) return 240*i:GetCurrentCharges(), 8*i:GetCurrentCharges() end, zero_f},
		["item_spirit_vessel"] = {function(p, i) return 320*i:GetCurrentCharges(), 8*i:GetCurrentCharges() end, zero_f},
}

local ITEM_PURCHASE_TIME_REQUIREMENT = {
	["item_aghanims_shard"] = 20*60,
	["item_tome_of_knowledge"] = 10*60
}

local ADDITIONAL_VALUE_OF_BOOT_ITEM = 2000 -- Used to switch out aegis or w/e.

local FAERIE_FIRE_MANGO_CARRIED_VALUE = GetItemCost("item_flask") + 1
local FAERIE_FIRE_MANGO_VALUE = GetItemCost("item_faerie_fire") -- N.B. Bugged logic in best-swap check function if patch makes any consumable with no benefit to carry has same cost.

local STAT_RESTORED_PER_CHARGE_WAND = 15
local MAX_CHARGES_MAGIC_WAND = 20
local WAND_CHARGE_VALUE = (VALUE_OF_ONE_MANA + VALUE_OF_ONE_HEALTH) * STAT_RESTORED_PER_CHARGE_WAND

local INCREASE_BAG_CLEARING_ZEALOTRY_THRESHOLD = 8 -- When we buy our 9th item, be eager to use faerie fires or mangos

local PURCHASE_OUT_OF_STOCK_AGH_SHARD = 0 -- Not sure about this, but is the return value after buying aghs shard and trying again when it's unavailable
--

local RETURN_COURIER_DIST_ON_PURCHASE = 3000 -- If the courier is over 3000 away from fountain, complete deliv' first

local t_pnot_inventory_locked = {}
local t_pnot_inventory_index_locked = {}
for i=1,TEAM_NUMBER_OF_PLAYERS do
	t_pnot_inventory_index_locked[i] = {}
end

local t_item_build_order_next = {}
local t_player_item_build = {}
local t_player_completed_build = {}
local t_player_becomes_junk_index = {}
local t_player_junk_updated_index = {}
local t_player_can_only_be_junk = {}
local t_player_buying_aghs = {} -- Aghs components are removed from next item build during reload fixing if HasScepter

local PRIMARY_ATTRIBUTE_TREADS_ITEM = {
	[0] = "item_belt_of_strength",
	[1] = "item_boots_of_elves",
	[2] = "item_robe",
	[3] = "item_belt_of_strength"
}

local function get_item_components(itemName, ownersPrimaryAttribute) -- for #arr
	if string.find(itemName, "power_treads") then
		return {"item_boots", "item_gloves", PRIMARY_ATTRIBUTE_TREADS_ITEM[ownersPrimaryAttribute]}
	end
	local componentParts = GetItemComponents(itemName)
	if Util_TableEmpty(componentParts) then componentParts[1] = itemName else componentParts = componentParts[1] end
	return componentParts
end

local function break_item_until_basic(itemOrItemTbl, superItemTbl, ownersPrimaryAttribute, index)
	if index == nil then 
		return break_item_until_basic(
				{itemOrItemTbl.GetName and itemOrItemTbl:GetName() or itemOrItemTbl},
				{}, 
				ownersPrimaryAttribute,
				1
			) -- the recursive process is now only using strings (if we had a hItem)
	else
		if itemOrItemTbl and itemOrItemTbl[index] then
			local componentParts = get_item_components(itemOrItemTbl[index], ownersPrimaryAttribute)
			itemOrItemTbl[#itemOrItemTbl] = componentParts[1] -- replace the assembled item with the first component
			if #componentParts == 1 then -- GetItemComponents specific
				return itemOrItemTbl, superItemTbl -- Only relevant return is to top-level init block
			end
			table.insert(superItemTbl, componentParts[1]) -- Items with components
			break_item_until_basic(itemOrItemTbl, superItemTbl, ownersPrimaryAttribute, #itemOrItemTbl)
			for j=2,#componentParts,1 do -- break the components
				itemOrItemTbl[#itemOrItemTbl+1] = componentParts[j]
				break_item_until_basic(itemOrItemTbl, superItemTbl, ownersPrimaryAttribute, #itemOrItemTbl)
			end
		end
	end
	return itemOrItemTbl -- Only relevant return is to top-level init block
end

local t_swap_index_time = {}
for pnot=1,TEAM_NUMBER_OF_PLAYERS do
	t_swap_index_time[pnot] = {}
end
function Item_SwapItems(gsiPlayer, slot1, slot2)
	if slot1 == slot2 then return; end
	gsiPlayer.hUnit:ActionImmediate_SwapItems(slot1, slot2)
	local playerSwapCooldowns = t_swap_index_time[gsiPlayer.nOnTeam]
	if slot1 > ITEM_END_INVENTORY_INDEX or slot2 > ITEM_END_INVENTORY_INDEX then
		local endCooldown = GameTime() + 6.51
		playerSwapCooldowns[slot1] = endCooldown
		playerSwapCooldowns[slot2] = endCooldown
	else
		local tmp = playerSwapCooldowns[slot1]
		playerSwapCooldowns[slot1] = playerSwapCooldowns[slot2]
		playerSwapCooldowns[slot2] = tmp
	end
end
local F_SWAP_ITEMS = Item_SwapItems

local courierActionThrottle = Time_CreateOneFrameGoThrottle(0.02)
local checkCombinesThrottle = Time_CreateOneFrameGoThrottle(1.321)
local checkSellJunkThrottle = Time_CreateOneFrameGoThrottle(0.5)
function Item_HandleItemShop(gsiPlayer)
	local itemBuild = t_player_item_build[gsiPlayer.nOnTeam]
	local nextItemBuildIndex = t_item_build_order_next[gsiPlayer.nOnTeam]
	local nextPurchase = itemBuild[nextItemBuildIndex]
	local gold = gsiPlayer.hUnit:GetGold()
	if not nextPurchase then return end
	-- cont have purchase
	
	--[[DEV]]if DEBUG and DEBUG_IsBotTheIntern() then INFO_print(string.format("[item_logic] HandleItemShop Junk - %s %s check if able to sell junk fount %d secret %d.", gsiPlayer.shortName, checkSellJunkThrottle:allowed() and "will" or "won't", gsiPlayer.hUnit:DistanceFromFountain(), gsiPlayer.hUnit:DistanceFromSecretShop())) end
	-- Check for uncombinable junk when held item limit
	if checkSellJunkThrottle:allowed()
			and (gsiPlayer.hUnit:DistanceFromFountain() == 0
				or gsiPlayer.hUnit:DistanceFromSecretShop() == 0 )
			and Item_NumberItemsCarried(gsiPlayer) == ITEM_INVENTORY_AND_BACKPACK_STORAGE then
		Item_SellOrDropJunk(gsiPlayer, nextItemBuildIndex)
	end

	--print("checking secret", gsiPlayer.shortName, IsItemPurchasedFromSecretShop(nextPurchase),
	--		gsiPlayer.hUnit:GetGold()+GSI_GetPlayerGPM(gsiPlayer)/4 > GetItemCost(nextPurchase),
	--		gsiPlayer.hUnit:DistanceFromSecretShop() > 0,
	--		(gsiPlayer.hCourier and gsiPlayer.hCourier:DistanceFromSecretShop() > 0),
	--		GetCourierState(gsiPlayer.hCourier))
	if IsItemPurchasedFromSecretShop(nextPurchase)
			and gold + GSI_GetPlayerGPM(gsiPlayer)/4 > GetItemCost(nextPurchase)
			and gsiPlayer.hUnit:DistanceFromSecretShop() > 0
			and (gsiPlayer.hCourier and gsiPlayer.hCourier:DistanceFromSecretShop() > 0) then
		if GetCourierState(gsiPlayer.hCourier) < COURIER_STATE_MOVING
				and courierActionThrottle:allowed() then 
			gsiPlayer.hUnit:ActionImmediate_Courier(gsiPlayer.hCourier, COURIER_ACTION_SECRET_SHOP)
		end
	elseif gsiPlayer.hUnit:GetGold() >= GetItemCost(nextPurchase) then
		local purchaseResult
		if not IsItemPurchasedFromSecretShop(nextPurchase)
				or gsiPlayer.hUnit:DistanceFromSecretShop() <= 0 then
			-- Purchase standard or secret shop item on player
			if DEBUG then INFO_print(gsiPlayer.shortName, "purchasing", nextPurchase, " and transfering") end
			purchaseResult = gsiPlayer.hUnit:ActionImmediate_PurchaseItem(nextPurchase)
			--print(gsiPlayer.shortName, "purchase result:", purchaseResult)
		elseif gsiPlayer.hCourier and gsiPlayer.hCourier:DistanceFromSecretShop() <= 0 then
			-- Purchase secret shop item on courier (the current code block is only if we have secret shop access)
			purchaseResult = gsiPlayer.hCourier:ActionImmediate_PurchaseItem(nextPurchase)
			--print(gsiPlayer.shortName, "purchase result:", purchaseResult)
		end
		if purchaseResult == PLACEHOLDER_PURCHASE_SUCCESS or purchaseResult == PURCHASE_ITEM_SUCCESS
				or purchaseResult == ITEM_HAVE_AGHS_SHARD_MYSTERIOUS then
			-- PURCHASE_SUCCESS
			t_item_build_order_next[gsiPlayer.nOnTeam] = t_item_build_order_next[gsiPlayer.nOnTeam] + 1

			if not Consumable_IsBotEagerToMakeSpace(gsiPlayer)
					and Item_NumberItemsCarried(gsiPlayer) > INCREASE_BAG_CLEARING_ZEALOTRY_THRESHOLD then
				Consumable_IndicateClearBagsSoon(gsiPlayer)
			end
			if USABLE_ITEMS_FOR_INDEXING[nextPurchase] then
				--print(gsiPlayer.shortName, "adds to purchasedUsables", nextPurchase)
				Item_EnsureListedPurchasedUsables(gsiPlayer, nextPurchase)
			else
				local combines, combinedResult = Item_CourierDeliveryWillCombineUpgrade(gsiPlayer, nextPurchase)
				if combines and USABLE_ITEMS_FOR_INDEXING[combinedResult] then
					--print(gsiPlayer.shortName, "adds to purchasedUsables", combinedResult)
					Item_EnsureListedPurchasedUsables(gsiPlayer, combinedResult)
				end
				if combinedResult == "item_rapier" then
					gsiPlayer.hasBoughtRapier = true
				end
			end
			-- Get Courier ETA ( can inform supports, don't get bounty in a hard lane until I get my flask )
		--	if gsiPlayer.hCourier then
		--		local hCourier = gsiPlayer.hCourier
		--		local courierState = GetCourierState(hCourier)
		--		local backToFountainDist = courierState == COURIER_STATE_RETURNING_TO_BASE and
		--				hCourier:DistanceFromFountain() or 0
		--		backToFountainDist = backToFountainDist >= RETURN_COURIER_DIST_ON_PURCHASE
		--				and 0 or backToFountainDist -- is it currently on too-far-just-complete delivery
		--		local toPlayerDist =
		--				Math_PointToPointDistance2D(gsiPlayer.lastSeen.location, Map_GetTeamFountainLocation())
		--						/ hCourier:GetCurrentMovementSpeed()
		--		gsiPlayer.courierEta = (backToFountainDist + toPlayerDist) / hCourier:GetCurrentMovementSpeed()
		--	end
		elseif purchaseResult == PURCHASE_ITEM_INVALID_ITEM_NAME then
			-- Skip invalid item names
			--[[DEV]]print(string.format("/VUL-FT/ <WARN> hero_behavior: %s attempted to purchase invalid item name '%s'.", gsiPlayer.shortName, nextPurchase))
			--[[DEV]]if DEBUG then DEBUG_KILLSWITCH = true; ERROR_print(true, false, "Above is kill") end
			t_item_build_order_next[gsiPlayer.nOnTeam] = t_item_build_order_next[gsiPlayer.nOnTeam] + 1
		elseif purchaseResult == PURCHASE_ITEM_OUT_OF_STOCK
				or purchaseResult == PURCHASE_ITEM_DISALLOWED_ITEM then 
			-- Could be 7.29 Aghanim's Shard / Tome of Knowledge. Push it up the item build
			local newNext = itemBuild[nextItemBuildIndex+1]
			local rotatedItemNum = 1
			while(GameTime() < Item_ItemTimedRequirement(newNext)) do -- search forward for an item that we can buy time-wise
				rotatedItemNum = rotatedItemNum + 1
				newNext = itemBuild[nextItemBuildIndex+rotatedItemNum]
				if nextItemBuildIndex+rotatedItemNum > #itemBuild then
					break;
				end
			end
			local prevItem = nextPurchase
			itemBuild[nextItemBuildIndex] = newNext
			for i=1,rotatedItemNum do
				local tmpItem = itemBuild[nextItemBuildIndex+i]
				itemBuild[nextItemBuildIndex+i] = prevItem
				prevItem = tmpItem
			end
		end
	end
	-- Handle courier
	local itemsInStash, stashSlot = Item_AnyItemsInStash(gsiPlayer)
	if itemsInStash
			and
			(	Item_NumberItemsCarried(gsiPlayer)
					< ITEM_INVENTORY_AND_BACKPACK_STORAGE
				or
				(	checkCombinesThrottle:allowed()
						and Item_CourierDeliveryWillCombineUpgrade(gsiPlayer)
				)
			) then
		--print("have stashed, free invent", gsiPlayer.shortName)
		if Math_PointToPointDistance2D(
				gsiPlayer.lastSeen.location,	
				Map_GetTeamFountainLocation()) < 600 then
			-- IN FOUNTAIN SWAP
			local hasFree, freeSlot = Item_HaveFreeInventorySlot(gsiPlayer)
			if hasFree then
				gsiPlayer.hUnit:ActionImmediate_SwapItems(
						stashSlot,
						freeSlot
					)
			end
			-- TODO Better items are just ignored? Don't want to use BestSwap because wards not impl. yet.
			-- -- don't want wards stuck in stash
		elseif gsiPlayer.hCourier then
			--print("have courier", gsiPlayer.shortName)
			local courierFountainDist = Math_PointToPointDistance2D(
					gsiPlayer.hCourier:GetLocation(),
					Map_GetTeamFountainLocation())
			if gsiPlayer.hCourier:DistanceFromFountain() == 0
					or gsiPlayer.hCourier:DistanceFromSecretShop() == 0 then
				if courierActionThrottle:allowed() then
					gsiPlayer.hUnit:ActionImmediate_Courier(
							gsiPlayer.hCourier, 
							COURIER_ACTION_TAKE_AND_TRANSFER_ITEMS)
				end
			elseif courierFountainDist < RETURN_COURIER_DIST_ON_PURCHASE then
				if courierActionThrottle:allowed() then
					gsiPlayer.hUnit:ActionImmediate_Courier(
							gsiPlayer.hCourier, 
							COURIER_ACTION_RETURN)
				end
			end
			return
		end
	end
	if gsiPlayer.hCourier and Item_AnyItemsOnCourier(gsiPlayer) then
		if GetCourierState(gsiPlayer.hCourier) < COURIER_STATE_MOVING
				and courierActionThrottle:allowed() then
			gsiPlayer.hUnit:ActionImmediate_Courier(
					gsiPlayer.hCourier, 
					COURIER_ACTION_TAKE_AND_TRANSFER_ITEMS)
		end
	end
end

function Item_ItemTimedRequirement(item)
	local itemPurchaseTimeRequirement = ITEM_PURCHASE_TIME_REQUIREMENT[item]
	if item == "item_tome_of_knowledge" then
		-- DEPRECIATED > 7.32e
		return GameTime() < itemPurchaseTimeRequirement and itemPurchaseTimeRequirement
				or GameTime() % itemPurchaseTimeRequirement < 5 and 0 or HIGH_32_BIT
	end
	return ITEM_PURCHASE_TIME_REQUIREMENT[item] or 0
end

function Item_AnyItemsInStash(gsiPlayer)
	for inventoryIndex=ITEM_END_BACKPACK_INDEX+1,ITEM_END_STASH_INDEX do
		if gsiPlayer.hUnit:GetItemInSlot(inventoryIndex) then
			return true, inventoryIndex 
		end
	end
	return false
end

function Item_AnyItemsOnCourier(gsiPlayer)
	local hCourier = gsiPlayer.hCourier
	if hCourier then
		for inventoryIndex=0,ITEM_END_BACKPACK_INDEX do
			if hCourier:GetItemInSlot(inventoryIndex) then
				return true, inventoryIndex 
			end
		end
	end
	return false
end

function Item_DistanceToAliveCourier(gsiPlayer)
	local hCourier = gsiPlayer.hCourier
	if hCourier then
		local courierLoc = hCourier:GetLocation()
		local playerLoc = gsiPlayer.lastSeen.location
		return ((courierLoc.x-playerLoc.x)^2 + (courierLoc.y-playerLoc.y^2))^0.5
	end
	return 20000
end

function Item_CountItemsOnCourier(gsiPlayer)
	local hCourier = gsiPlayer.hCourier
	local countItems = 0
	if hCourier then
		for inventoryIndex=0,ITEM_END_BACKPACK_INDEX do
			if hCourier:GetItemInSlot(inventoryIndex) ~= ITEM_NOT_FOUND then
				countItems = countItems + 1
			end
		end
	end
	return countItems
end

function Item_GetTreeCuttingItem(gsiPlayer)
	return select(2, Item_ItemOwnedAnywhere(gsiPlayer, "item_quelling_blade"))
			or select(2, Item_ItemOwnedAnywhere(gsiPlayer, "item_bfury"))
end

function Item_GetForceStaffItem(gsiPlayer)
	return select(2, Item_ItemOwnedAnywhere(gsiPlayer, "item_force_staff"))
			or select(2, Item_ItemOwnedAnywhere(gsiPlayer, "item_hurricane_pike"))
end

function Item_UseBottleIntelligently(gsiPlayer, forceHold, forceUse)
	local _, bottle = Item_ItemInHeroStorage(gsiPlayer, "item_bottle")
	if not bottle then return end
	local couldUse = bottle:GetCurrentCharges() > 0 and bottle:GetCooldownTimeRemaining() == 0
	if forceHold or couldUse then 
		if gsiPlayer.usableItemCache.powerTreads
				and gsiPlayer.hUnit:FindItemSlot("item_power_treads")
						< ITEM_END_INVENTORY_INDEX then
			UseItem_PowerTreadsStatLock(gsiPlayer, ATTRIBUTE_AGILITY,
					bottle:GetSpecialValueFloat("restore_time"), 500
				)
		end
		if couldUse and Item_EnsureCarriedItemInInventory(gsiPlayer, bottle)
					== ITEM_ENSURE_RESULT_READY then
			Item_LockInventorySwitching(gsiPlayer, 3)
			if not UseAbility_IsPlayerLocked(gsiPlayer) 
					and not gsiPlayer.hUnit:HasModifier("modifier_bottle_regeneration") then
				--print("Smart bottle use", gsiPlayer.shortName)
				UseAbility_RegisterAbilityUseAndLockToScore(gsiPlayer, bottle, nil, 500)
			end
		end
	end
end

-- Will be overridden by other actions on the same tick
-------- Item_DropItemNow()
function Item_DropItemNow(gsiPlayer, hItem)
	local dropLoc = Vector_Addition(gsiPlayer.lastSeen.location,
			Vector_ScalarMultiply(
				Vector_UnitDirectionalFacingDegrees(gsiPlayer.hUnit:GetFacing()),
				30
			)
		)
	GetBot():Action_DropItem(hItem, dropLoc)
end

function Item_PlayerDropItemAtSlot(pUnit, slot)

end

function Item_PlayerDropItemWithName(gsiPlayer, itemName)
	local pUnit = gsiPlayer.hUnit
	for i=0,ITEM_END_BACKPACK_INDEX,1 do 
		local thisItem = pUnit:GetItemInSlot(i)
		if thisItem and thisItem:GetName() == itemName then
			pUnit:Action_DropItem(thisItem, gsiPlayer.lastSeen.location)
		end
	end
end

function Item_HaveFreeInventorySlot(gsiPlayer)
	for inventoryIndex=0,ITEM_END_BACKPACK_INDEX do
		if not gsiPlayer.hUnit:GetItemInSlot(inventoryIndex) then
			return true, inventoryIndex 
		end
	end
	return false
end

function Item_NumberItemsInBackpack(gsiPlayer)
	local c = 0
	for i=ITEM_END_INVENTORY_INDEX+1,ITEM_END_BACKPACK_INDEX,1 do
		if gsiPlayer.hUnit:GetItemInSlot(i) then
			c = c + 1
		end
	end
	return c
end

function Item_NumberItemsInInventory(gsiPlayer)
	local c = 0
	for i=0,ITEM_END_INVENTORY_INDEX,1 do
		if gsiPlayer.hUnit:GetItemInSlot(i) then
			c = c + 1
		end
	end
	return c
end

function Item_NumberItemsCarried(unit)
	local c = 0
	local hUnit = unit.hUnit or unit
	for i=0,ITEM_END_BACKPACK_INDEX,1 do
		if hUnit:GetItemInSlot(i) then
			c = c + 1
		end
	end
	return c
end

--[FUNCVAL]]local replenishHealthPlatter = {}
--[FUNCVAL]]local replenishManaPlatter = {}
local t_item_platter1, t_item_platter2 = {}, {}
function Item_GetReplenishers(gsiPlayer, removeBackpackIfLocked) -- TODO Inventory tracking is probably easier and faster
	local pUnit = gsiPlayer.hUnit
	local endSearchIndex = removeBackpackIfLocked and not Item_IsInventorySwitchingAllowed(gsiPlayer) and ITEM_END_INVENTORY_INDEX or ITEM_END_BACKPACK_INDEX
	local iPlatterHealth = 0
	local iPlatterMana = 0
	local healthReplenishAvailable = t_item_platter1
	local manaReplenishAvailable = t_item_platter2
	local preHealthPlatterSize = #healthReplenishAvailable
	local preManaPlatterSize = #manaReplenishAvailable

	for i=0,endSearchIndex,1 do
		local thisItem = pUnit:GetItemInSlot(i)
		if thisItem then
			local itemName = thisItem:GetName()
			if Item_IsManaOnUse(itemName) then
				iPlatterMana = iPlatterMana + 1
				manaReplenishAvailable[iPlatterMana] = thisItem -- INSERT
				if itemName == "item_magic_stick"
						or itemName == "item_magic_wand" 
						or itemName == "item_holy_locket" 
						or itemName == "item_bottle"
						or itemName == "item_guardian_greaves" then
					iPlatterHealth = iPlatterHealth + 1
					healthReplenishAvailable[iPlatterHealth] = thisItem -- HEALTH+MANA INSERT
				end
			elseif Item_IsHealthOnUse(itemName) then
				iPlatterHealth = iPlatterHealth + 1
				healthReplenishAvailable[iPlatterHealth] = thisItem -- INSERT
			end
		end
	end
	for i=iPlatterHealth+1,preHealthPlatterSize do
		healthReplenishAvailable[i] = nil
	end
	for i=iPlatterMana+1,preManaPlatterSize do
		manaReplenishAvailable[i] = nil
	end
	for i=1,#manaReplenishAvailable do
		if not manaReplenishAvailable[i]
				or not manaReplenishAvailable[i].GetName then
			print("WTF? REPLENISH")
			Util_TablePrint(manaReplenishAvailable, 3)
		end
	end
	for i=1,#healthReplenishAvailable do
		if not healthReplenishAvailable[i]
				or not healthReplenishAvailable[i].GetName then
			print("WTF? REPLENISH H")
			Util_TablePrint(healthReplenishAvailable, 3)
		end
	end
	if EMPTY_TABLE[1] then
		print("THE EMPTY TABLE IS REPLENISH", EMPTY_TABLE, EMPTY_TABLE[1], EMPTY_TABLE[1] and Util_TablePrint(EMPTY_TABLE[1] or "fine", 2))
	end
	if healthReplenishAvailable[1] then
		recycle_table = {}
		if manaReplenishAvailable[1] then
			recycle_table2 = {}
			return healthReplenishAvailable, manaReplenishAvailable
		end
		return healthReplenishAvailable, EMPTY_TABLE
	else
		if manaReplenishAvailable[1] then
			recycle_table2 = {}
			return EMPTY_TABLE, manaReplenishAvailable
		end
		return EMPTY_TABLE, EMPTY_TABLE
	end 
end
function Item_GetUsableNonReplenishers(gsiPlayer, removeBackpackIfLocked)
	local pUnit = gsiPlayer.hUnit
	local endSearchIndex = removeBackpackIfLocked and not Item_IsInventorySwitchingAllowed(gsiPlayer) and ITEM_END_INVENTORY_INDEX or ITEM_END_BACKPACK_INDEX
	local iPlatterHealth = 1
	local iPlatterMana = 1
	local itemsAvailable = recycle_table or {}
	for i=0,endSearchIndex,1 do
		local thisItem = pUnit:GetItemInSlot(i)
		if thisItem then
			if Item_IsManaOnUse(thisItem:GetName()) then
				manaReplenishAvailable[iPlatterMana] = thisItem
				iPlatterMana = iPlatterMana + 1
				if string.find(thisItem:GetName(), "magi", ITEM_NAME_SEARCH_START) 
				or string.find(thisItem:GetName(), "holy_l", ITEM_NAME_SEARCH_START) 
				or string.find(thisItem:GetName(), "bott", ITEM_NAME_SEARCH_START) 
				or string.find(thisItem:GetName(), "guar", ITEM_NAME_SEARCH_START) then
					healthReplenishAvailable[iPlatterHealth] = thisItem
					iPlatterHealth = iPlatterHealth + 1
				end
			elseif Item_IsHealthOnUse(thisItem:GetName()) then
				healthReplenishAvailable[iPlatterHealth] = thisItem
				iPlatterHealth = iPlatterHealth + 1
			end
		end
	end
	print("THE EMPTY TABLE IS REPLENISH", EMPTY_TABLE, EMPTY_TABLE[1])
	if healthReplenishAvailable[1] then
		recycle_table = {}
		if manaReplenishAvailable[1] then
			recycle_table2 = {}
			return healthReplenishAvailable, manaReplenishAvailable
		end
		return healthReplenishAvailable, EMPTY_TABLE
	else
		if manaReplenishAvailable[1] then
			recycle_table2 = {}
			return EMPTY_TABLE, manaReplenishAvailable
		end
		return EMPTY_TABLE, EMPTY_TABLE
	end 
end

function Item_GetBestSwitchOutInInventory(gsiPlayer, useConsumable, keepWards)
	local lowestValue = HIGH_32_BIT
	local lowestValueSlot = 0
	local lowestValueConsumable = HIGH_32_BIT
	local lowestValueConsumableSlot
	local useConsumable = useConsumable or false -- triggers on two consumables
	local pUnit = gsiPlayer.hUnit
	local lockedIndices = t_pnot_inventory_index_locked[gsiPlayer.nOnTeam]
	local currTime = GameTime()
	for i=0,ITEM_END_INVENTORY_INDEX,1 do
		if lockedIndices[i] then
			if lockedIndices[i] < currTime then
				lockedIndices[i] = nil
			else
				goto CONT_I_GBSOII;
			end
		end

		local thisItem = pUnit:GetItemInSlot(i)
		if not thisItem then return i end
		local thisItemCost = GetItemCost(thisItem:GetName())
		if Item_IsConsumable(thisItem:GetName()) then
			if thisItemCost < lowestValueConsumable then
				if lowestValueConsumableSlot then 
					useConsumable = true 
				end
				lowestValueConsumable = thisItemCost
				lowestValueConsumableSlot = i
			end
		else
			if thisItemCost < lowestValue then
				lowestValue = thisItemCost
				lowestValueSlot = i
			end
		end
		::CONT_I_GBSOII::
	end
	return useConsumable and lowestValueConsumableSlot or lowestValueSlot
end

function Item_IsHoldingAnyDispenser(gsiPlayer)
	local hUnit = gsiPlayer.hUnit
	for i=0,ITEM_END_BACKPACK_INDEX do
		local item = hUnit:GetItemInSlot(i)
		if item and string.find(item:GetName(), "item_ward_") then
			return true, i, item
		end
	end
	return false, -1, nil
end

function Item_OnItemSwapCooldown(gsiPlayer, hItem, itemSlot)
	local itemSlot = itemSlot or gsiPlayer.hUnit:FindItemSlot(hItem:GetName())
	local swapTime = t_swap_index_time[gsiPlayer.nOnTeam][itemSlot]
	if itemSlot > ITEM_END_INVENTORY_INDEX --[[and itemSlot < ITEM_END_BACKPACK_INDEX]] then
		if VERBOSE then 
			ALERT_print(
					string.format(
						"[item_logic]: %s Query on item not in the inventory.",
						Util_ParamString("Item_OnItemSwapCooldown", gsiPlayer, hItem, itemSlot)
					)
				)
			return true, itemSlot
		end
	end
	swapTime = swapTime and swapTime or 0
	--print("swap time is", swapTime, GameTime())
	return swapTime > GameTime()
end

function Item_EnsureCarriedItemInInventory(gsiPlayer, hItem, forceSlot, dryRun) -- N.B. Could be reversed without a following inventory lock
	local thisItemSlot = gsiPlayer.hUnit:FindItemSlot(hItem:GetName())
	-- TODO Stash and at fountain, courier in vicinity (does swapping work then) checks?
	--[[DEV]]print("ITEM ENSURE", hItem:GetName(), hItem:GetCooldownTimeRemaining(), thisItemSlot)
	if thisItemSlot == ITEM_NOT_FOUND then
		return ITEM_NOT_FOUND, thisItemSlot
	elseif thisItemSlot <= ITEM_END_INVENTORY_INDEX and (not forceSlot
				or thisItemSlot == forceSlot
			) then
		local swapCd = t_swap_index_time[gsiPlayer.nOnTeam][thisItemSlot]
--[[DEV]]print("EnsureCarried in invent swap cd:", swapCd, hItem:GetName(), swapCd and swapCd > GameTime()
--[[DEV]]		and ITEM_ENSURE_RESULT_WAIT or ITEM_ENSURE_RESULT_READY)
		return swapCd and swapCd > GameTime()
				and ITEM_ENSURE_RESULT_WAIT or ITEM_ENSURE_RESULT_READY,
				thisItemSlot
	elseif not Item_IsInventorySwitchingAllowed(gsiPlayer) then 
		return ITEM_ENSURE_RESULT_LOCKED, thisItemSlot
	end
	local switchOutSlot = forceSlot or Item_GetBestSwitchOutInInventory(gsiPlayer)
	if switchOutSlot then
		if not dryRun then
			--[[DEBUG]]if VERBOSE then VEBUG_print(string.format("%s switching item slots #%d, #%d for ensure carried operation.", gsiPlayer.shortName, thisItemSlot, switchOutSlot)) end
			F_SWAP_ITEMS(gsiPlayer, thisItemSlot, switchOutSlot)
		end
		--[[DEV]]print("ITEM ENSURE", hItem:GetName(), hItem:GetCooldownTimeRemaining())
		return ITEM_ENSURE_RESULT_WAIT, switchOutSlot -- .'. check ~= false and we will have the item soon / ready now.
	end
end

-- Best use is a task blueprint copying it's own throttled time / expected task time and just repeatedly locking for that on it's interval. On end, if invterval low, just forget about it the lock
function Item_LockInventorySwitching(gsiPlayer, timeLocked)
	timeLocked = timeLocked or ITEM_SWITCH_ITEM_READY_TIME+1
	t_pnot_inventory_locked[gsiPlayer.nOnTeam] = GameTime() + timeLocked
end

function Item_LockInventoryIndex(gsiPlayer, inventoryIndex, timeLocked)
	timeLocked = timeLocked or ITEM_SWITCH_ITEM_READY_TIME+1
	t_pnot_inventory_index_locked[gsiPlayer.nOnTeam][inventoryIndex] = GameTime() + timeLocked
end

function Item_IsInventorySwitchingAllowed(gsiPlayer)
	if t_pnot_inventory_locked[gsiPlayer.nOnTeam] then
		if t_pnot_inventory_locked[gsiPlayer.nOnTeam] < GameTime() then
			t_pnot_inventory_locked[gsiPlayer.nOnTeam] = nil
			return true
		end
	else
		return true
	end
end

local inventory_indexing_throttle = Time_CreateOneFrameGoThrottle(0.33)
local iui_scan_throttle = Time_CreateThrottle(1.0001)
local iui_pnot_rotate = 1
local iui_scan_next = false -- hacked as on at optimal_inventory_orientation allowed
local function index_usable_items(gsiPlayer)
	local hUnit = gsiPlayer.hUnit
	local purchasedUsables = gsiPlayer.purchasedUsables
	local usableItemsForIndexing
	local itemCache = gsiPlayer.usableItemCache
	--print("INDEXING", gsiPlayer.shortName, gsiPlayer.nOnTeam, iui_pnot_rotate, iui_scan_throttle.next, GameTime())
	if iui_scan_throttle:allowed() then
		for i=1,TEAM_NUMBER_OF_PLAYERS do
			iui_pnot_rotate = (iui_pnot_rotate % TEAM_NUMBER_OF_PLAYERS) + 1
			--print("iui rotates", iui_pnot_rotate)
			local nextPlayer = GetTeamMember(iui_pnot_rotate)
			if nextPlayer and nextPlayer:IsBot() then
				iui_scan_next = true
				break;
			end
		end
	end
	if gsiPlayer.nOnTeam == iui_pnot_rotate and iui_scan_next then
		if VERBOSE then
			VEBUG_print(
					string.format("[item_logic] %s scans full inventory for usables",
						gsiPlayer.shortName
					)
				)
		end

		usableItemsForIndexing = USABLE_ITEMS_FOR_INDEXING
		-- Run full scan on just this player on this frame (once every
		-- 	-	optimal_inventory_orientation_throttle)
		for k,item in pairs(itemCache) do
			itemCache[k] = nil
		end
		local numPurchasedUsables = #purchasedUsables
		for i=0,ITEM_END_BACKPACK_INDEX do
			local thisItem = hUnit:GetItemInSlot(i)
			local thisItemName = thisItem and thisItem:GetName()
			local itemVarName = usableItemsForIndexing[thisItemName]
			if itemVarName then
				--print("Added %s", thisItemName)
				itemCache[itemVarName] = thisItem
				local iPurch=1
				while(iPurch<=numPurchasedUsables) do
					if thisItemName == purchasedUsables[iPurch] then
						break;
					end
					iPurch=iPurch+1
				end
				if iPurch>numPurchasedUsables then
					if VERBOSE then
						VEBUG_print(
								string.format("[item_logic] new usable: %s",
									thisItemName
								)
							)
					end
					purchasedUsables[iPurch] = thisItemName
					numPurchasedUsables = numPurchasedUsables + 1
				end
			end
		end
		if VERBOSE then Util_TablePrint(purchasedUsables) end
		iui_scan_next = false
		return;
	end
	for i=1,#purchasedUsables do
		--print("finding", purchasedUsables[i])
		usableItemsForIndexing = usableItemsForIndexing or USABLE_ITEMS_FOR_INDEXING

		local itemVarName = USABLE_ITEMS_FOR_INDEXING[purchasedUsables[i]]
		if itemVarName then
			local itemSlot = hUnit:FindItemSlot(purchasedUsables[i])
			-- TODO currently ignores items in backpack for convenience.
			-- - case for improvement: bkb on long cooldown switch to 7-slotted when fight starts
			-- - ... essentially to speed up a module that switches and locks when fights start
			-- - if it's suited.
			if itemSlot and itemSlot <= ITEM_END_BACKPACK_INDEX then
				itemCache[itemVarName] = hUnit:GetItemInSlot(itemSlot)
				--print(gsiPlayer.shortName, "has", purchasedUsables[i])
			else
				itemCache[itemVarName] = nil
				--print(gsiPlayer.shortName, "doesn't have", purchasedUsables[i])
			end
			--print(itemCache[itemVarName])
		end
	end
	::EXIT_IUI::
end

--[[FUNCVALS]]	local optimal_inventory_orientation_throttle = Time_CreateOneFrameGoThrottle(3.49)
-------- Item_TryOptimalInventoryOrientation() -- O(n) (per bot)
function Item_TryOptimalInventoryOrientation(gsiPlayer) -- TODO Primitive
	if inventory_indexing_throttle:allowed() then
		index_usable_items(gsiPlayer)
	end
	if not Item_IsInventorySwitchingAllowed(gsiPlayer) then return end
	if optimal_inventory_orientation_throttle:allowed() then
		--print("reorder")
		local lowestValue = HIGH_32_BIT
		local lowestValueSlot = nil
		local highestValueBackpack = -1
		local highestValueBackpackSlot = nil
		local multipleConsumablesInInventory = false
		local lowestValueConsumable = HIGH_32_BIT
		local lowestValueConsumableSlot = nil
		local highestValueConsumableBackpack = -1
		local highestValueConsumableBackpackSlot = nil
		local foundWardIndex = nil
		local freeInventorySlot = nil
		
		local pUnit = gsiPlayer.hUnit
		
		for thisBackpackSlot=6,8,1 do -- Check backpack valuables
			local thisItem = pUnit:GetItemInSlot(thisBackpackSlot)
			if thisItem then
				local thisItemName = thisItem:GetName()
				local thisItemCost = GetItemCost(thisItemName)
				if string.find(thisItemName, "m_recipe", ITEM_NAME_SEARCH_START) then -- Move recipes into backpack
					--continue
				elseif string.find(thisItemName, "tem_magi", ITEM_NAME_SEARCH_START) or string.find(thisItemName, "holy_loc", ITEM_NAME_SEARCH_START) then
					thisItemCost = thisItemCost + thisItem:GetCurrentCharges() * WAND_CHARGE_VALUE
					if thisItemCost > highestValueConsumableBackpack then
						highestValueConsumableBackpack = thisItemCost -- Beat all consumables but rosh.
						highestValueConsumableBackpackSlot = thisBackpackSlot
					end
					if thisItemCost > highestValueBackpack then 
						highestValueBackpack = thisItemCost
						highestValueBackpackSlot = thisBackpackSlot
					end
				elseif Item_IsConsumable(thisItemName) then
					if thisItemCost == FAERIE_FIRE_MANGO_VALUE then thisItemCost = FAERIE_FIRE_MANGO_CARRIED_VALUE end
					--print(gsiPlayer.shortName, "checking", thisItemName)
					if string.find(thisItemName, "tem_ward") then
						if foundWardIndex then
							--gsiPlayer.hUnit:ActionImmediate_SwapItems(thisBackpackSlot, foundWardIndex)
						else
							foundWardIndex = thisBackpackSlot
						end
					elseif thisItemCost > highestValueConsumableBackpack then
						--print(gsiPlayer.shortName, "storing", thisItemName)
						highestValueConsumableBackpack = thisItemCost
						highestValueConsumableBackpackSlot = thisBackpackSlot
					end
				else
					if ITEMS_BOOTS[thisItemName] then
						thisItemCost = thisItemCost + ADDITIONAL_VALUE_OF_BOOT_ITEM -- Take off your boots only if you're 7-slotted high value / 6-slotted+aegis TODO IMPLEMENT AEGIS
					end
					if thisItemCost > highestValueBackpack then
						highestValueBackpack = thisItemCost
						highestValueBackpackSlot = thisBackpackSlot
					end
				end
			end
		end
		if not highestValueBackpackSlot and not highestValueConsumableBackpack then return end -- Exit with empty backpack
		local slot_locked_time = t_pnot_inventory_index_locked[gsiPlayer.nOnTeam]
		for thisInventorySlot=0,5,1 do -- Check inventory valuables
			if slot_locked_time[thisInventorySlot] then
				if slot_locked_time[thisInventorySlot] < GameTime() then
					slot_locked_time[thisInventorySlot] = nil
				else
					goto CONT_I_TOIO_INVENTORY;
				end
			end
			local thisItem = pUnit:GetItemInSlot(thisInventorySlot)
			if thisItem then
				local thisItemName = thisItem:GetName()
				local thisItemCost = GetItemCost(thisItemName)
				--if thisItemName == "item_ward_observer" then print("obs cost", thisItemCost) end
				if string.find(thisItemName, "m_recipe", ITEM_NAME_SEARCH_START) then -- Move recipes into backpack
					lowestValue = -1 
					lowestValueSlot = thisInventorySlot
					break
				elseif string.find(thisItemName, "tem_magi", ITEM_NAME_SEARCH_START) or string.find(thisItemName, "holy_loc", ITEM_NAME_SEARCH_START) then
					thisItemCost = thisItemCost + thisItem:GetCurrentCharges() * WAND_CHARGE_VALUE
					if thisItemCost < lowestValueConsumable then -- Probably cheese in inventory
						if lowestValueConsumableSlot then
							multipleConsumablesInInventory = true
						end
						lowestValueConsumable = thisItemCost
						lowestValueConsumableSlot = thisInventorySlot
					end
					if thisItemCost < lowestValue then 
						lowestValue = thisItemCost
						lowestValueSlot = thisInventorySlot
					end
				elseif Item_IsConsumable(thisItemName) then 
					if thisItemCost == FAERIE_FIRE_MANGO_VALUE then thisItemCost = FAERIE_FIRE_MANGO_CARRIED_VALUE end
					if string.find(thisItemName, "tem_ward") then
						if foundWardIndex then
							gsiPlayer.hUnit:ActionImmediate_SwapItems(thisInventorySlot, foundWardIndex)
						else
							foundWardIndex = thisInventorySlot
						end
					elseif lowestValueConsumableSlot then
						multipleConsumablesInInventory = true
						if thisItemCost < lowestValueConsumable then
							-- TODO Cheese still has high gold value? Not sure about Roshan refresher.
							lowestValueConsumable = thisItemCost
							lowestValueConsumableSlot = thisInventorySlot
						end
					else
						lowestValueConsumable = thisItemCost
						lowestValueConsumableSlot = thisInventorySlot
					end
				else
					if ITEMS_BOOTS[thisItemName] then
						thisItemCost = thisItemCost + ADDITIONAL_VALUE_OF_BOOT_ITEM -- Take off your boots only if you're 7-slotted high value / 6-slotted+aegis TODO IMPLEMENT AEGIS
					end
					if thisItemCost < lowestValue then 
						lowestValue = thisItemCost
						lowestValueSlot = thisInventorySlot
					end
				end
			else
				freeInventorySlot = thisInventorySlot
			end
			::CONT_I_TOIO_INVENTORY::
		end
		if ( highestValueBackpackSlot and highestValueBackpack ~= -1 ) or highestValueConsumableBackpackSlot then
			--[[DEV]]print(gsiPlayer.shortName, "sees switchable", highestValueBackpackSlot, highestValueConsumableBackpackSlot,  lowestValueSlot, lowestValueConsumableSlot, freeInventorySlot)
			if freeInventorySlot then
				--[[DEV]]print(gsiPlayer.shortName, "free slot", highestValueBackpackSlot, highestValueConsumableBackpackSlot)
				if highestValueBackpackSlot then -- Switch high value items into empty slot
					F_SWAP_ITEMS(gsiPlayer, highestValueBackpackSlot, freeInventorySlot)
				elseif highestValueConsumableBackpackSlot then -- Switch high value consumables into empty slot
					F_SWAP_ITEMS(gsiPlayer, highestValueConsumableBackpackSlot, freeInventorySlot)
				end
			elseif multipleConsumablesInInventory then
				--[[DEV]]print(gsiPlayer.shortName, "multipleConsumables in invent")
				if highestValueBackpackSlot then -- switch the lowest value consumable of 2 for highest backpack item
					F_SWAP_ITEMS(gsiPlayer, highestValueBackpackSlot, lowestValueConsumableSlot)
				elseif highestValueConsumableBackpack > lowestValueConsumable then -- switch any higher value consumable from backpack into the slot of a lower value consumable
					F_SWAP_ITEMS(gsiPlayer, highestValueConsumableBackpackSlot, lowestValueConsumableSlot)
				end
			elseif highestValueBackpack > lowestValue then -- switch highest value backpack into inventory slot with lower value; allows one consumable
				--[[DEV]]print("highestValueBackpack over lowestValue", GetItemCost(gsiPlayer.hUnit:GetItemInSlot(highestValueBackpackSlot):GetName()), highestValueBackpack, GetItemCost(gsiPlayer.hUnit:GetItemInSlot(lowestValueSlot):GetName()), lowestValue)
				F_SWAP_ITEMS(gsiPlayer, highestValueBackpackSlot, lowestValueSlot) 
			elseif highestValueConsumableBackpack > lowestValueConsumable then
				F_SWAP_ITEMS(gsiPlayer, highestValueConsumableBackpackSlot, lowestValueConsumableSlot)
			end
		end
	end
end
function Item_DetectNextItemBuildIndex(gsiPlayer, itemBuild) -- Used for resolving discrepencies, not to increment build order.
	local nOnTeam = gsiPlayer.nOnTeam
	local pUnit = gsiPlayer.hUnit
	local courierUnit = gsiPlayer.hCourier
	local playerPrimaryAttribute = gsiPlayer.hUnit:GetPrimaryAttribute()
	local ownedComponents = {}
	for s=0,ITEM_MAX_PLAYER_STORAGE-1,1 do
		local thisItem = pUnit:GetItemInSlot(s)
		if thisItem then
			if USABLE_ITEMS_FOR_INDEXING[thisItem:GetName()] then
				--print(gsiPlayer.shortName, "adds to purchasedUsables", thisItem:GetName())
				Item_EnsureListedPurchasedUsables(gsiPlayer, thisItem:GetName())
			end
			for _,itemComponent in ipairs(break_item_until_basic(thisItem, playerPrimaryAttribute)) do
				table.insert(ownedComponents, itemComponent)
				--[[DEV]]if VERBOSE then VEBUG_print(string.format("%s's item slot#%d has: '%s'.", gsiPlayer.shortName, s, pUnit:GetItemInSlot(s):GetName())) end
			end
		end
	end
	if courierUnit then
		for s=0,ITEM_MAX_COURIER_STORAGE-1,1 do
			local thisItem = courierUnit:GetItemInSlot(s)
			if thisItem then
				if USABLE_ITEMS_FOR_INDEXING[thisItem:GetName()] then
					--print(gsiPlayer.shortName, "adds to purchasedUsables", thisItem:GetName())
					Item_EnsureListedPurchasedUsables(gsiPlayer, thisItem:GetName())
				end
				for _,itemComponent in ipairs(break_item_until_basic(thisItem, playerPrimaryAttribute)) do
					table.insert(ownedComponents, itemComponent)
					--[VERBOSE]]if VERBOSE then VEBUG_print(string.format("%s's courer's item slot#%d has: '%s'.", gsiPlayer.shortName, s, courierUnit:GetItemInSlot(s):GetName())) end
				end
			end
		end
	end
	local found
	local i = 1
	if #ownedComponents <= 1 then -- Will allow consumables until an item is owned.
		return 1
	end
	if gsiPlayer.hUnit:HasScepter() and t_player_buying_aghs[gsiPlayer.nOnTeam] then -- Novelty stat stick -> heaven's halberd -> aghs, etc.
		local aghsComponents = get_item_components(t_player_buying_aghs[gsiPlayer.nOnTeam], playerPrimaryAttribute)
	end
	local lastNotFound = -1 -- afterLastFound = (afterLastFound+1 == i and afterLastFound or i)
	local becomesJunkTbl = t_player_becomes_junk_index[gsiPlayer.nOnTeam]
	while(i < #itemBuild) do
		found = false
		itemComponentString = itemBuild[i]
		if not Item_IsConsumable(itemComponentString) then -- TODO [not] IsConsumable()
			for k,v in ipairs(ownedComponents) do
				if itemComponentString == v then -- TODO Item_IsConsumable(itemName)
					table.remove(ownedComponents, k)
					--[[DEV]]if VERBOSE then print(gsiPlayer.shortname, "removing from itemBuild", i, itemBuild[i]) end
					table.remove(itemBuild, i) -- HACK FIX
					Util_ShiftElementsToLowerTblsOfTbl(becomesJunkTbl, i)
					i = i - 1
					--print(gsiPlayer.shortName, "found matching item", v, "for", itemBuild[i])
					found = true
					break
				end
			end
			if itemComponentString == "item_aghanims_shard" then
				--print(gsiPlayer.hUnit:ActionImmediate_PurchaseItem("item_aghanims_shard"), "shard purchase return")
			end
			if not found
					and not (
						itemComponentString == "item_aghanims_shard"
						and GameTime() > ITEM_PURCHASE_TIME_REQUIREMENT["item_aghanims_shard"]
						and gsiPlayer.hUnit:ActionImmediate_PurchaseItem("item_aghanims_shard") == PURCHASE_OUT_OF_STOCK_AGH_SHARD
					) then -- If it is out of stock after the time requirement, we already have it. Aghs Scepter is bugged for now. Reloads I can only imagine being debug anyways
			end
		else
			--[[DEV]]if VERBOSE then INFO_print(string.format("removing from itemBuild %d, %s", i, itemBuild[i])) end
			table.remove(itemBuild, i)
			Util_ShiftElementsToLowerTblsOfTbl(becomesJunkTbl, i)
			i = i - 1
		end
		--[VERBOSE]]if VERBOSE then VEBUG_print(string.format("%s skipping owned item or consumable '%s'.", gsiPlayer.shortName, itemBuild[i])) end
		i = i + 1
	end
	--[[DEBUG]]if DEBUG then DEBUG_print(string.format("item_logic: %s reset their item list at index %d, next purchase: '%s'.", gsiPlayer.shortName, 1, itemBuild[1])) end
	return 1 -- HACK FIX TODO This is mainly for dev dota_bot_reload_scripts, also above. -- TODO item builds should be better at self-repairing anyways
end

-----	Item_ResolvePartiallyCombinedBuild() Functions --
--	Map is stored as a flat list of items yet to have a super item, including super
--	items. The array is searchable for unlinked sub-items to link to a super item.
-- 
-- Indices of item map:
-- 			ITEM_NAME = 1
-- 			SUPER_ITEM_NODE = 2,
-- 			SUB_ITEM_NODES_TBL = 3,
-- 			ITEM_BUILD_INDEX_WHEN_COMBINES = 4
--

local running_item_build_index = -1
-- becomes_junk is poorly found and could be found in the loop of another func (of combine resolution) TODO
local function search_down_for_junk(presentJunkTbl, itemNode, becomesJunkIndex)
	--print(itemNode[1])
	if itemNode[3] then
		for i=1,#(itemNode[3]) do
			search_down_for_junk(presentJunkTbl, itemNode[3][i], becomesJunkIndex)
		end
	end
	local prevJunkBuyIndex = presentJunkTbl[itemNode[1]] or -1
	if becomesJunkIndex > prevJunkBuyIndex then
		presentJunkTbl[ itemNode[1] ] = becomesJunkIndex
	end
	if VERBOSE then
		VEBUG_print(string.format("[item_logic]: Adding junk %s, %d", itemNode[1], becomesJunkIndex))
	end
end
local function create_becomes_junk_table(map)
	local junkTable = {}
	local presentJunkTbl = {} -- [str]
	local highestIndexFound = 0
	--print("creating junk table")
	for i=1,#map do
		search_down_for_junk(presentJunkTbl, map[i], map[i][4])
		highestIndexFound = map[i][4] > highestIndexFound and map[i][4] or highestIndexFound
	end
	for i=1,highestIndexFound do
		if junkTable[i] == nil then
			junkTable[i] = {} -- a consequence of saving indicies of buy before doing fix-build checks
		end
	end
	for itemName,index in pairs(presentJunkTbl) do
		table.insert(junkTable[index], itemName)
	end
	-- ensure correct #arr checks
	return junkTable
end
local function create_item_node(itemName)
	return {itemName, nil, {}, running_item_build_index} -- {itemName, head, subNodes, buildIndexOfBuy}
end
local function map_insert_item_node(map, itemNode)
	table.insert(map, itemNode)
end
local function map_link_sub_to_super_item(map, subItemName, superItemNode)
	-- Finds loose subItemNode with name, links it to the known superItemNode. If the 
	-- subItemNode doesn't exist, it is created and needsAcquisition flag is set. i.e. 
	-- the subItem may already be half-bought, and needs to be checked here also.
	local i = 1
	local mapSize = #map
	local subItemNode
	while(i<=mapSize) do
		if subItemName == map[i][1] and not map[i][2] then
			subItemNode = map[i]
			subItemNode[2] = superItemNode
			table.insert(superItemNode[3], subItemNode)
			table.remove(map, i)
			return subItemNode, false -- subNodeLinked, needsAcquisition
		end
		i = i + 1
	end
	subItemNode = create_item_node(subItemName)
	subItemNode[2] = superItemNode
	table.insert(superItemNode[3], subItemNode)
	return subItemNode, true -- subNodeLinked, needsAcquisition
end
local function insert_needing_buy(itemBuild, itemBuildMap, itemName, superItemNode, primaryAttribute)
	-- Recursively build map and link item's subItems (if it has any), to formulate how the
	-- build is ordered, while avoiding re-buys of subItems when the original build lists a
	-- superItem that may or may not be half-bought.
	local subItems = get_item_components(itemName, primaryAttribute)
	--if itemName == "item_power_treads" then print("power treads components:") Util_TablePrint(subItems) end
	numComponents = #subItems
	if numComponents == 1 then
		if superItemNode then -- map this base item and link it to our already known superItem
			local _, needsAcquisition = 
					map_link_sub_to_super_item(itemBuildMap, itemName, superItemNode)
			if needsAcquisition then
				itemBuild[running_item_build_index] = itemName
				running_item_build_index = running_item_build_index + 1
				return -- base item was not present in the original build
			end
		else -- map this base item
			map_insert_item_node(itemBuildMap, create_item_node(itemName))
			itemBuild[running_item_build_index] = itemName -- item was in the original build
			running_item_build_index = running_item_build_index + 1
		end
	else
		local newSuperItemNode, needsAcquisition
		if superItemNode then
			newSuperItemNode, needsAcquisition = -- link to superItemNode, see if already owned
				map_link_sub_to_super_item(itemBuildMap, itemName, superItemNode)
			if not needsAcquisition then
				return -- item (a sub or super-type itself) exists and is now our sub item.
			end
		else
			newSuperItemNode = create_item_node(itemName)
			map_insert_item_node(itemBuildMap, newSuperItemNode)
		end
		for i=1,numComponents do  -- recursively link to this superItem
			insert_needing_buy(itemBuild, itemBuildMap, subItems[i], newSuperItemNode, primaryAttribute)
		end
	end
end
function Item_ResolvePartiallyCombinedBuild(gsiPlayer, prevItemBuild)
	local newItemBuild = {}
	local buildSize
	local itemComponentString
	local itemBuildMap = {} 
	local atBreakCombinedIndex
	local iComponent
	local numComponents
	local primaryAttribute = gsiPlayer.hUnit:GetPrimaryAttribute()
	running_item_build_index = 1
	local i = 1
	while(prevItemBuild[i]) do
		itemComponentString = prevItemBuild[i]
		-- Place consumables first in the build
		if i < 8 and Item_IsConsumable(itemComponentString) then
			-- insert early consumable
			buildSize = #newItemBuild
			for iItemBuild=1, buildSize-1, 1 do
				local thisItemName = newItemBuild[iItemBuild]
				if not Item_IsConsumable(newItemBuild[iItemBuild])
						and not (thisItemName == "item_magic_stick"
							or thisItemName == "item_magic_wand"
						) then
					-- Shift items up by 1 from this earliest non-consumable
					for iShift=buildSize,iItemBuild,-1 do
						newItemBuild[iShift+1] = newItemBuild[iShift] -- [ ]>>>>
					end
					newItemBuild[iItemBuild] = itemComponentString -- [^]\___/ consumable insert
					running_item_build_index = running_item_build_index + 1
					goto NEXT;
				end
			end
			newItemBuild[buildSize+1] = itemComponentString
			running_item_build_index = running_item_build_index + 1
		else
			-- Build list from original item build
			insert_needing_buy(newItemBuild, itemBuildMap, itemComponentString, nil, primaryAttribute)
			if itemComponentString:find("item_agh") and not itemComponentString:find("shard") then
				t_player_buying_aghs[gsiPlayer.nOnTeam] = itemComponentString
			end
		end
		::NEXT::
		i = i + 1
	end
--	for i=1,#newItemBuild do
--		print(gsiPlayer.shortName, i, newItemBuild[i])
--	end
	t_player_becomes_junk_index[gsiPlayer.nOnTeam] -- for detecting full-bag uncombined junk sells
			= create_becomes_junk_table(itemBuildMap)
	t_player_junk_updated_index[gsiPlayer.nOnTeam] = 0
	t_player_can_only_be_junk[gsiPlayer.nOnTeam] = {}
	return newItemBuild
end

local function update_table_of_possible_junk(gsiPlayer, buildOrderIndex)
	local pnot = gsiPlayer.nOnTeam
	local updatedIndex = t_player_junk_updated_index[pnot]
	--[[DEV]]INFO_print("update_table_of_possible_junk %s, %s, %s", gsiPlayer.shortName, updatedIndex, buildOrderIndex)
	for i=updatedIndex+1,buildOrderIndex-1 do
		local nowJunkTable = t_player_becomes_junk_index[pnot][i]
		if nowJunkTable then
			for iJunk=1,#nowJunkTable do
				table.insert(t_player_can_only_be_junk[pnot], nowJunkTable[iJunk])
			end
		end
		t_player_junk_updated_index[pnot] = updatedIndex
	end
	return t_player_can_only_be_junk[pnot]
end
local function sell_or_drop_junk_update_table(gsiPlayer, hItem, junkTable)
	if gsiPlayer.hUnit:DistanceFromFountain() == 0
			or gsiPlayer.hUnit:DistanceFromSecretShop() == 0 then
		INFO_print(string.format("[item_logic] Junk - SOLD %s %s", gsiPlayer.shortName, hItem:GetName()))
		gsiPlayer.hUnit:ActionImmediate_SellItem(hItem)
	else
		--INFO_print(string.format("[item_logic] Junk - DROPPED %s %s", gsiPlayer.shortName, hItem:GetName()))
		--gsiPlayer.hUnit:Action_DropItem(hItem, gsiPlayer.hUnit:GetLocation())
	end
end
local MAX_JUNK_CHECKS = 4
-- used on a throttle, and intended only while at a shop
-- TODO TEST
--[[DEV]]local VERBOSE = true
function Item_SellOrDropJunk(gsiPlayer, buildOrderIndex)
	local junkTable = update_table_of_possible_junk(gsiPlayer, buildOrderIndex)
	if not junkTable then
		--[[DEV]]if VERBOSE then INFO_print(string.format("[item_logic]::Item_SellOrDropJunk - No junk to sell %s", gsiPlayer.shortName)) end
		return;
	end
--[[DEV]]if VERBOSE then
--[[DEV]]	DEBUG_print(string.format("[item_logic] Junk - %s iBuild %d: %s",
--[[DEV]]				gsiPlayer.shortName, buildOrderIndex,
--[[DEV]]				Util_PrintableTable({"junk index ", t_player_becomes_junk_index[gsiPlayer.nOnTeam]})
--[[DEV]]			)
--[[DEV]]		)
--[[DEV]]	Util_TablePrint({["junkTable"] = junkTable})
--[[DEV]]end
	local numPossibleJunk = junkTable and #junkTable
	local sortedValueItems, itemsHeld = Item_SortHeldByValue(gsiPlayer, false)
--[[DEV]]if VERBOSE then for i=0,#sortedValueItems do local item = sortedValueItems[i]; if item then print("sortedValueItems:", item:GetName()) end end end
	local anyFreeSlots = false
	for iInventory=0,ITEM_END_BACKPACK_INDEX do
		local thisItem = sortedValueItems[iInventory]
		if not thisItem then
			break;
		end
		for iJunk=1,numPossibleJunk do
			if thisItem:GetName() == junkTable[iJunk] then
				INFO_print(string.format("[item_logic]::Item_SellOrDropJunk() %s selling junk: %s", gsiPlayer.shortName, junkTable[iJunk] or "nil"))
				sell_or_drop_junk_update_table(gsiPlayer, thisItem, junkTable)
				return;
			end
		end
	end
end
-- SortHeldByValue uses 0 indexing to avoid funk
local sorted_platter = {}
function Item_SortHeldByValue(gsiPlayer, highToLow)
	local sorted_platter = sorted_platter
	local ITEMS_BOOTS = ITEMS_BOOTS
	local itemsHeld = 0
	local hUnit = gsiPlayer.hUnit
	for i=0,ITEM_END_BACKPACK_INDEX do
		local thisItem = hUnit:GetItemInSlot(i)
		if thisItem then
			sorted_platter[itemsHeld] = thisItem
			itemsHeld = itemsHeld + 1
		end
	end
	itemsHeld = itemsHeld - 1
	sorted_platter[itemsHeld+1] = nil
	sorted_platter[itemsHeld+2] = nil -- #arr works
	for i=0,itemsHeld-1 do
		for j=itemsHeld,i+1,-1 do
			local itemPrev = sorted_platter[j-1]
			local itemCurr = sorted_platter[j]
			local upperIsHigher =
					GetItemCost(itemCurr:GetName())
						+ ( ITEMS_BOOTS[itemCurr:GetName()] and ADDITIONAL_VALUE_OF_BOOT_ITEM or 0)
					> GetItemCost(itemPrev:GetName()) 
						+ ( ITEMS_BOOTS[itemPrev:GetName()] and ADDITIONAL_VALUE_OF_BOOT_ITEM or 0)
			if (highToLow and upperIsHigher)
					or not (highToLow or upperIsHigher) then
				sorted_platter[j-1] = itemCurr
				sorted_platter[j] = itemPrev
			end
		end
	end
	return sorted_platter, itemsHeld
end

function Item_CourierDeliveryWillCombineUpgrade(gsiPlayer, ensureIncluded)
	local playerInventory = {} -- names of combinables
	local hUnit = gsiPlayer.hUnit
	local item_resolution_map = item_resolution_map
	local hCourier = gsiPlayer.hCourier
	if not hCourier then return false end
	local iInventory = 0
	for iSlot=0,ITEM_END_BACKPACK_INDEX do
		local hItem = hUnit:GetItemInSlot(iSlot)
		if hItem then
			local combinesToList = item_resolution_map[hItem:GetName()]
			if combinesToList then
				iInventory = iInventory+1
				playerInventory[iInventory] = hItem:GetName()
			end
		end
	end
	--Util_TablePrint(playerInventory)
	local stashAndCourierInventory = {} -- tables of combinations
	local testCombines = {}
	local jInventory = 0
	--if ensureIncluded then
	--	jInventory = 1
	--	local combinesToList = item_resolution_map[ensureIncluded]
	--	if combinesToList then
	--		stashAndCourierInventory[1] = ensureIncluded
	--		testCombines[1] = combinesToList
	--	end
	--end
	for iSlot=0,ITEM_END_BACKPACK_INDEX do
		local hItem = hCourier:GetItemInSlot(iSlot)
		if hItem then
			local combinesToList = item_resolution_map[hItem:GetName()]
			if combinesToList then
				jInventory = jInventory+1
				stashAndCourierInventory[jInventory] = hItem:GetName()
				testCombines[jInventory] = combinesToList
			end
		end
	end
	for iSlot=ITEM_END_BACKPACK_INDEX+1,ITEM_END_STASH_INDEX do
		local hItem = hUnit:GetItemInSlot(iSlot)
		if hItem then
			local combinesToList = item_resolution_map[hItem:GetName()]
			if combinesToList then
				jInventory = jInventory+1
				stashAndCourierInventory[jInventory] = hItem:GetName()
				testCombines[jInventory] = combinesToList
			end
		end
	end
		
--	Util_TablePrint(stashAndCourierInventory)
--	print("and")
--	Util_TablePrint(testCombines)
	-- TODO ignores doubles
	if iInventory==0 or jInventory==0 then return false end
	for jSending=1,jInventory do
		local thisUpgradesList = testCombines[jSending]
		for iUpgrade=1,#thisUpgradesList do
			local recipe = thisUpgradesList[iUpgrade]
			local totalNeeded = #recipe
			for iItem=1,totalNeeded do
				local findItem = recipe[iItem]
				for iPlayerInventory=1,iInventory do
					if playerInventory[iPlayerInventory] == findItem then
						goto SUCCESS_NEXT_ITEM;
					end
				end
				for iOtherInventory=1,jInventory do
					if stashAndCourierInventory[iOtherInventory] == findItem then
						--print(findItem)
						goto SUCCESS_NEXT_ITEM;
					end
				end
				goto FAILED_NEXT_UPGRADE;
				::SUCCESS_NEXT_ITEM::
				if iItem == totalNeeded then
					return true, recipe[ITEM_RES_MAP_COMPONENTS_I__COMBINES_TO]
				end
			end
			::FAILED_NEXT_UPGRADE::
		end
	end
	return false, nil
end

local synonym_non_purchased = {
	["item_ward_observer"] = "item_ward_dispenser",
	["item_ward_sentry"] = "item_ward_dispenser"
}
function Item_EnsureListedPurchasedUsables(gsiPlayer, itemName, noRecurse)
	if USABLE_ITEMS_FOR_INDEXING[itemName] then
		local usables = gsiPlayer.purchasedUsables
		for i=1,#usables do
			if usables[i] == itemName then
				return;
			end
		end
		if not noRecurse then
			for k,synonym in pairs(synonym_non_purchased) do
				Item_EnsureListedPurchasedUsables(gsiPlayer, synonym, true)
			end
		end
		INFO_print(gsiPlayer.shortName, "adds to purchasedUsables", itemName)
		table.insert(usables, itemName)
	end
end

-- Manual add, usually consumables needed
function Item_InsertItemToItemBuild(gsiPlayer, itemName)
	table.insert(t_player_item_build[gsiPlayer.nOnTeam], t_item_build_order_next[gsiPlayer.nOnTeam], itemName)
	Item_EnsureListedPurchasedUsables(gsiPlayer, itemName)
end

function Item_GetNextItemBuildItem(gsiPlayer)
	return t_player_item_build[gsiPlayer.nOnTeam][t_item_build_order_next[gsiPlayer.nOnTeam]]
end

function Item_ItemInBuild(gsiPlayer, itemName, inFuture)
	local itemBuild = t_player_item_build[gsiPlayer.nOnTeam]
	local startIndex = inFuture and t_item_build_order_next[gsiPlayer.nOnTeam] or 1
	for i=startIndex,#itemBuild do
		if itemName == itemBuild[i] then
			return true
		end
	end
	return false
end

function Item_ItemInHeroStorage(gsiPlayer, itemName)
	local itemSlot = gsiPlayer.hUnit:FindItemSlot(itemName)
	if itemSlot > ITEM_END_BACKPACK_INDEX or itemSlot == ITEM_NOT_FOUND then
		return false, gsiPlayer.hUnit:GetItemInSlot(itemSlot)
	end
	return true, gsiPlayer.hUnit:GetItemInSlot(itemSlot)
end

function Item_ItemOwnedAnywhere(gsiPlayer, itemName)
	local hUnit = gsiPlayer.hUnit
	for i=0,ITEM_MAX_PLAYER_STORAGE-1,1 do
		if hUnit:GetItemInSlot(i) and hUnit:GetItemInSlot(i):GetName() == itemName then
			return true, hUnit:GetItemInSlot(i), i
		end
	end
	local courierUnit = gsiPlayer.hCourier
	if courierUnit then
		for i=0,ITEM_MAX_COURIER_STORAGE-1,1 do
			if courierUnit:GetItemInSlot(i) and courierUnit:GetItemInSlot(i):GetName() == itemName then
				return true, courierUnit:GetItemInSlot(i), i
			end
		end
	end
	return false, nil, -1
end

function Item_HasInvisItem(gsiPlayer)
	local hUnit = gsiPlayer.hUnit
	for i=1,#ITEM_INVIS_SEARCH do
		if hUnit:FindItemSlot(ITEM_INVIS_SEARCH[i]) >= 0 then
			return true
		end
	end
	return false
end

function Item_HasWaveClearOn(gsiPlayer, useAttack)
	local searchTbl = ((useAttack or useAttack == nil) and ITEM_WAVE_CLEAR_ATTACK)
			or useAttack == false and ITEM_WAVE_CLEAR_NOT_ATTACK
	local hUnit = gsiPlayer.hUnit
	for i=1,#searchTbl do
		if hUnit:FindItemSlot(searchTbl[i]) >= 0 then
			return true, hItem
		end
	end
	if useAttack == nil then
		return Item_HasWaveClearOn(gsiPlayer, false)
	end
	return false
end

function Item_GetItemByName(gsiPlayer, name)
	local itemSlot = gsiPlayer.hUnit:FindItemSlot(name)
	return itemSlot >= 0 and gsiPlayer.hUnit:GetItemInSlot(itemSlot)
end

function Item_TownPortalScrollsOwned(gsiPlayer)
	local hUnit = gsiPlayer.hUnit
	local scrollCount = hUnit:GetItemInSlot(TPSCROLL_SLOT) 
					and hUnit:GetItemInSlot(TPSCROLL_SLOT):GetCurrentCharges() 
					or 0
	for i=ITEM_END_BACKPACK_INDEX+1,ITEM_END_STASH_INDEX,1 do
		local thisStashItem = hUnit:GetItemInSlot(i)
		if thisStashItem and thisStashItem.GetName and thisStashItem:GetName() == "item_tpscroll" then
			scrollCount = scrollCount + thisStashItem:GetCurrentCharges()
		end
	end
	local courierUnit = gsiPlayer.hCourier
	if courierUnit then
		for i=0,ITEM_MAX_COURIER_STORAGE-1,1 do
			local thisItem = courierUnit:GetItemInSlot(i)
			if thisItem and thisItem:GetName() == "item_tpscroll" then
				return scrollCount + thisItem:GetCurrentCharges()
			end
		end
	end
	return scrollCount
end

function Item_TownPortalScrollCooldown(gsiPlayer)
	local tpScroll = gsiPlayer.hUnit:GetItemInSlot(TPSCROLL_SLOT)
	return tpScroll and tpScroll:GetCooldownTimeRemaining() or 80
end

function Item_IsConsumable(itemString)
	for i=1,#CONSUMABLE_ITEM_SEARCH,1 do
		if string.find(itemString, CONSUMABLE_ITEM_SEARCH[i], ITEM_NAME_SEARCH_START) then
			return true
		end
	end
	return false
end

function Item_IsHealthOnUse(itemString)
	for i=1,#HEALTH_ON_USE_ITEM_SEARCH,1 do
		if string.find(itemString, HEALTH_ON_USE_ITEM_SEARCH[i], ITEM_NAME_SEARCH_START) then
			return true
		end
	end
	return false
end

function Item_IsManaOnUse(itemString)
	for i=1,#MANA_ON_USE_ITEM_SEARCH,1 do
		if string.find(itemString, MANA_ON_USE_ITEM_SEARCH[i], ITEM_NAME_SEARCH_START) then
			return true
		end
	end
	return false
end

function Item_ResourcesAfterUsingConsumables(gsiPlayer)
	local hUnit = gsiPlayer.hUnit
	local healthGain = 0
	local healthTime = 0
	local manaGain = 0
	local manaTime = 0
	local hItem
	local resourceFuncs
	local healthGet = 0
	local healthTimeGet = 0
	local manaGet = 0
	local manaTimeGet = 0
	
	for i=0,ITEM_MAX_PLAYER_STORAGE-1,1 do
		hItem = hUnit:GetItemInSlot(i)
		resourceFuncs = hItem and RESOURCE_VALUE_OF_ITEM[hItem:GetName()]
		if resourceFuncs then
			healthGet, healthTimeGet = resourceFuncs[1](gsiPlayer, hItem)
			manaGet, manaTimeGet = resourceFuncs[2](gsiPlayer, hItem)
			healthGain = healthGain + healthGet
			healthTime = healthTime + healthTimeGet
			manaGain = manaGain + manaGet
			manaTime = manaTime + manaTimeGet
		end
	end
	local courierUnit = gsiPlayer.hCourier
	if courierUnit then
		for i=0,ITEM_MAX_PLAYER_STORAGE-1,1 do
			hItem = hUnit:GetItemInSlot(i)
			resourceFuncs = hItem and RESOURCE_VALUE_OF_ITEM[hItem:GetName()]
			if resourceFuncs then
				healthGet, healthTimeGet = resourceFuncs[1](gsiPlayer, hItem)
				manaGet, manaTimeGet = resourceFuncs[2](gsiPlayer, hItem)
				healthGain = healthGain + healthGet
				healthTime = healthTime + healthTimeGet
				manaGain = manaGain + manaGet
				manaTime = manaTime + manaTimeGet
			end
		end
	end
	--[DEBUG]]print(gsiPlayer.shortName, healthGain, healthTime)
	return healthGain, healthTime, manaGain, manaTime
end

function Item_RAUCMitigateDelivery(gsiPlayer)
	local hUnit = gsiPlayer.hUnit
	local healthGain = 0
	local healthTime = 0
	local manaGain = 0
	local manaTime = 0
	local hItem
	local resourceFuncs
	local healthGet = 0
	local healthTimeGet = 0
	local manaGet = 0
	local manaTimeGet = 0
	
	for i=0,ITEM_END_BACKPACK_INDEX-1,1 do
		hItem = hUnit:GetItemInSlot(i)
		resourceFuncs = hItem and RESOURCE_VALUE_OF_ITEM[hItem:GetName()]
		if resourceFuncs then
			healthGet, healthTimeGet = resourceFuncs[1](gsiPlayer, hItem)
			manaGet, manaTimeGet = resourceFuncs[2](gsiPlayer, hItem)
			healthGain = healthGain + healthGet
			healthTime = healthTime + healthTimeGet
			manaGain = manaGain + manaGet
			manaTime = manaTime + manaTimeGet
		end
	end
	local courierUnit = gsiPlayer.hCourier
	if courierUnit and GetCourierState(courierUnit) ~= COURIER_STATE_DEAD then
		--[[ Look at this stupid code that's been in the script for half a year
				local courierDeliveryMitigate =
				Vector_PointDistance(gsiPlayer.lastSeen.location, courierUnit:GetLocation())
						* max(0, Vector_UnitFacingUnit(courierUnit, gsiPlayer))
		]]
		local courierDeliveryMitigate =
				max(0.25, 
					1 - 0.005*Vector_PointDistance(gsiPlayer.lastSeen.location, courierUnit:GetLocation())
						/ courierUnit:GetCurrentMovementSpeed() 
					)
		for i=0,ITEM_MAX_PLAYER_STORAGE-1,1 do
			hItem = hUnit:GetItemInSlot(i)
			resourceFuncs = hItem and RESOURCE_VALUE_OF_ITEM[hItem:GetName()]
			if resourceFuncs then
				healthGet, healthTimeGet = resourceFuncs[1](gsiPlayer, hItem)
				manaGet, manaTimeGet = resourceFuncs[2](gsiPlayer, hItem)
				healthGain = healthGain + healthGet * courierDeliveryMitigate
				healthTime = healthTime + healthTimeGet
				manaGain = manaGain + manaGet * courierDeliveryMitigate
				manaTime = manaTime + manaTimeGet
			end
		end
	end
	--[DEBUG]]print(gsiPlayer.shortName, healthGain, healthTime)
	return healthGain, healthTime, manaGain, manaTime
end

function Item_InitializePlayer(gsiPlayer, itemBuildTable)
	if gsiPlayer.team == TEAM then -- TODO if anything for enemies
		INFO_print("/VUL-FT/ [item_logic] formulating item build order for %s.", gsiPlayer.shortName)
		t_player_item_build[gsiPlayer.nOnTeam] = Item_ResolvePartiallyCombinedBuild(gsiPlayer, itemBuildTable)
		t_item_build_order_next[gsiPlayer.nOnTeam] = Item_DetectNextItemBuildIndex(gsiPlayer, t_player_item_build[gsiPlayer.nOnTeam])
		--Util_TablePrint(t_player_becomes_junk_index[gsiPlayer.nOnTeam])
	--	for i=1,#t_player_item_build[gsiPlayer.nOnTeam] do
	--		print(t_player_item_build[gsiPlayer.nOnTeam][i])
	--	end
	end
end

-- item_resolution_map init
do
	local itemUpgradesArr = ITEM_UPGRADES
	for iItem=1,#ITEM_UPGRADES do
		local thisUpgradeName = itemUpgradesArr[iItem]
		local components = get_item_components(thisUpgradeName, 0)
		for iComponent=1,#components do
			local thisComponentName = components[iComponent]
			if not item_resolution_map[thisComponentName] then
				item_resolution_map[thisComponentName] = {}
			end
			table.insert(item_resolution_map[thisComponentName], components)
		end
	--	if VERBOSE then
	--		INFO_print(string.format("Setting %s component table. %s", thisUpgradeName,
	--						Util_PrintableTable(components)
	--					)
	--			)
	--	end
		components[ITEM_RES_MAP_COMPONENTS_I__COMBINES_TO] = thisUpgradeName
	end
end
