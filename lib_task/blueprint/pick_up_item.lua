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

local TEAM_NUMBER_OF_PLAYERS = TEAM_NUMBER_OF_PLAYERS
local Task_SetTaskPriority = Task_SetTaskPriority
local XETA_SCORE_DO_NOT_RUN = XETA_SCORE_DO_NOT_RUN

local JUNGLE_ITEM_PLAYER_ID = -1
local JUNGLE_ITEM_ITEM_SLOT = 16

local MAX_JUNGLE_ITEM_TIER = 5

local ITEMS_JUNGLE = ITEMS_JUNGLE
local ITEMS_END_BACKPACK_INDEX

local PICK_UP_ITEM_DIST = 700
local TRADE_ITEM_DIST = PICK_UP_ITEM_DIST-50
local DROP_IN_FOUNTAIN_DIST = 500
local AVOID_UNNEEDED_NEAR_FOUNTAIN_DIST = 1000
local DROP_EXTRA_JUNGLE_FOR_DELIVERY_SPACE_DIST = 4000

local task_handle = Task_CreateNewTask()

local blueprint

local max = math.max
local sqrt = math.sqrt

local farm_lane_handle

local t_team_humans

local function estimated_time_til_completed(gsiPlayer, objective)
	return 0
end
local function task_init_func(taskJobDomain)
	Blueprint_RegisterTaskName(task_handle, "pick_up_item")
	if VERBOSE then VEBUG_print(string.format("pick_up_item: Initialized with handle #%d.", task_handle)) end

	use_ability = UseAbility_GetTaskHandle()

	Task_RegisterTask(task_handle, PLAYERS_ALL, blueprint.run, blueprint.score, blueprint.init)

	t_team_humans = GSI_GetTeamHumans(TEAM)

	taskJobDomain:RegisterJob(
			function(workingSet)
				if workingSet.throttle:allowed() then
					if workingSet.humanNeedsTierThrottle:allowed() then
						-- Find a tier that is considerable to the human, give extra care to accomodate them.
						local jungleItems = ITEMS_JUNGLE
						for i=1,#t_team_humans do
							local thisHuman = t_team_humans[i]
							local hUnitHuman = thisHuman.hUnit
							local jungleItemSlotted = hUnitHuman:GetItemInSlot(JUNGLE_ITEM_ITEM_SLOT)
							if jungleItemSlotted then
								-- Set to slotted tier + 1 desire
								thisHuman.giveMeAJungleItemTier = jungleItems[jungleItemSlotted:GetName()]+1
							end
							if not thisHuman.giveMeAJungleItemTier then
								local highestTierHeld = 0
								-- Find held but not slotted
								for iSlot=0,JUNGLE_ITEM_ITEM_SLOT do
									local thisItem = hUnitHuman:GetItemInSlot(iSlot)
									local thisTier = thisItem and jungleItems[thisItem:GetName()] or 0
									if thisTier and thisTier > highestTierHeld then
										highestTierHeld = thisTier
									end
									thisHuman.giveMeAJungleItemTier = thisTier
								end
								 -- keep it to the same tier, the human might not want what is held out of slot
								thisHuman.giveMeAJungleItemTier = highestTierHeld
							end
						end -- end human
					end
					-- Update prio
					Task_SetTaskPriority(task_handle, PLAYERS_ALL, TASK_PRIORITY_TOP)
				end
			end,
			{
				["throttle"] = Time_CreateThrottle(1.0), -- score is static
				["humanNeedsTierThrottle"] = Time_CreateThrottle(0.89)
			},
			"JOB_TASK_SCORING_PRIORITY_PICK_UP_ITEM"
		)
	Blueprint_RegisterTaskActivityType(task_handle, ACTIVITY_TYPE["NOT_APPLICABLE"])
	task_init_func = nil
	return task_handle, estimated_time_til_completed
end
Blueprint_RegisterTask(task_init_func)

blueprint = {
	run = function(gsiPlayer, objective, xetaScore)
		local currSlottedJungle = gsiPlayer.hUnit:GetItemInSlot(JUNGLE_ITEM_ITEM_SLOT)
		Util_TablePrint(getmetatable(objective))
		if currSlottedJungle and objective.item
				and objective.item:GetName()
					~= (currSlottedJungle and currSlottedJungle:GetName() or "!") then
			
			Item_DropItemNow(gsiPlayer, currSlottedJungle)
			return xetaScore - 5
		end

		if objective.location
				and Vector_PointDistance2D(
						gsiPlayer.lastSeen.location,
						objective.location
					) < 1000 then
			gsiPlayer.hUnit:Action_PickUpItem(objective.item)
			return xetaScore
		end
		return XETA_SCORE_DO_NOT_RUN
	end,
	
	score = function(gsiPlayer, prevObjective, prevScore)
		local jungleItemKeys = ITEMS_JUNGLE
		local droppedItems = GetDroppedItemList()
		
		
		--Util_TablePrint(table.sort(getmetatable(gsiPlayer.hUnit)))
		local countHeld = 0
		local hUnit = gsiPlayer.hUnit
		local jungleItemLoose
		local iJungleItemLoose
		local bestLooseTier = 0
		for i=0,JUNGLE_ITEM_ITEM_SLOT-1 do
			local itemInSlot = hUnit:GetItemInSlot(i)
			if itemInSlot then
				countHeld = countHeld + 1
				local tier = jungleItemKeys[itemInSlot:GetName()]
				if tier and tier > bestLooseTier then
					bestLooseTier = tier
					iJungleItemLoose = i
					jungleItemLoose = itemInSlot
				end
			end
		end
	
		-- Put your only jungle item held in the jungle slot
		local jungleItemSlotted = gsiPlayer.hUnit:GetItemInSlot(JUNGLE_ITEM_ITEM_SLOT)
		if not jungleItemSlotted
				or (jungleItemLoose
					and jungleItemKeys[jungleItemSlotted:GetName()]
						< bestLooseTier
				) then
			if jungleItemLoose then
				gsiPlayer.hUnit:ActionImmediate_SwapItems(iJungleItemLoose, JUNGLE_ITEM_ITEM_SLOT)
				
				return false, XETA_SCORE_DO_NOT_RUN;
			end
			gsiPlayer.giveMeAJungleItemTier = 0
		else
			gsiPlayer.giveMeAJungleItemTier = jungleItemKeys[jungleItemSlotted:GetName()]+1
					or math.floor(MAX_JUNGLE_ITEM_TIER / 2)
		end

		local nearbyAllies

		local doTrades = MAX_JUNGLE_ITEM_TIER + 1
		if jungleItemLoose then
			nearbyAllies
					= Set_GetAlliedHeroesInPlayerRadius(gsiPlayer, TRADE_ITEM_DIST, false)
			for i=1,#nearbyAllies do
				local asksTier = nearbyAllies[i].giveMeAJungleItemTier
				if asksTier < doTrades then
					doTrades = asksTier;
				end
			end
		end

		local distToCourier = GetCourierState(gsiPlayer.hCourier) == COURIER_STATE_DELIVERING_ITEMS
				and Item_DistanceToAliveCourier(gsiPlayer) or 0xFFFF
		local countHeldIncludeDelivery = countHeld
				+ (distToCourier < DROP_EXTRA_JUNGLE_FOR_DELIVERY_SPACE_DIST
					and Item_CountItemsOnCourier(gsiPlayer)-1 -- note -1 add courier, don't drop if it might combine
					or 0)
		local distToFountain = Vector_PointDistance2D(gsiPlayer.lastSeen.location, TEAM_FOUNTAIN)
		-- Drop a loose jungle item infront of you if you are loaded up, or in the fountain
		if jungleItemLoose and (countHeldIncludeDelivery > 8 -- note -1 add courier, don't drop if it might combine
					or distToFountain < DROP_IN_FOUNTAIN_DIST
					or bestLooseTier >= doTrades
				) then
			
			Item_DropItemNow(gsiPlayer, jungleItemLoose)
		end

		if not droppedItems or not droppedItems[1] then
			-- Don't pick up jungle items if loaded up, or there are none to pickup
			
			return false, XETA_SCORE_DO_NOT_RUN
		end
		
		local PointDistance = Vector_PointDistance2D
		local playerLoc = gsiPlayer.lastSeen.location
		local bestItem
		local bestItemTier = gsiPlayer.giveMeAJungleItemTier-1
		local bestItemDist = 0xFFFF
		for i=1,#droppedItems do
			local thisItem = droppedItems[i]
			local thisDist = PointDistance(playerLoc, thisItem.location)
			
			local thisTierOrNilJungle = jungleItemKeys[thisItem.item:GetName()]
			if thisTierOrNilJungle then
				if thisDist < PICK_UP_ITEM_DIST and thisTierOrNilJungle > bestItemTier then
					bestItemTier = thisTierOrNilJungle
					bestItem = thisItem
					bestItemDist = thisDist
				end
			end
		end
		
		if not bestItem then
			
			return false, XETA_SCORE_DO_NOT_RUN
		end
		local doNothing = jungleItemSlotted and true
		if bestItemTier >= gsiPlayer.giveMeAJungleItemTier or countHeldIncludeDelivery <= 8 then
			
			Item_DropItemNow(gsiPlayer, jungleItemSlotted) -- never works, overridden
			doNothing = false
		end
		if doNothing then
			
			return false, XETA_SCORE_DO_NOT_RUN
		end
		local currentActivityType = Blueprint_GetCurrentTaskActivityType(gsiPlayer)
		if currentActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION
				and bestItemDist < 200 then
			
			return bestItem, 150
		elseif currentActivityType >= ACTIVITY_TYPE.CAREFUL then
			if PointDistance(playerLoc, TEAM_FOUNTAIN)
					> PointDistance(bestItem.location, TEAM_FOUNTAIN) then
				
				return bestItem, 300 - Math_ETA(gsiPlayer, bestItem.location)*50
			end
			
			return false, XETA_SCORE_DO_NOT_RUN
		else
			
			return bestItem, 300 - Math_ETA(gsiPlayer, bestItem.location)*50
		end
	end,
	
	init = function(gsiPlayer, objective, extrapolatedXeta)
		Task_IndicateSuccessfulInitShortTask(gsiPlayer, task_handle)
		return extrapolatedXeta
	end
}

function PickUpItem_GetTaskHandle()
	return task_handle
end
