local TEAM_NUMBER_OF_PLAYERS = TEAM_NUMBER_OF_PLAYERS
local Task_SetTaskPriority = Task_SetTaskPriority
local XETA_SCORE_DO_NOT_RUN = XETA_SCORE_DO_NOT_RUN

local JUNGLE_ITEM_PLAYER_ID = -1
local JUNGLE_ITEM_ITEM_SLOT = 16

local ITEMS_JUNGLE = ITEMS_JUNGLE

local task_handle = Task_CreateNewTask()

local blueprint

local max = math.max
local sqrt = math.sqrt

local farm_lane_handle

local function estimated_time_til_completed(gsiPlayer, objective)
	return 0
end
local function task_init_func(taskJobDomain)
	if VERBOSE then VEBUG_print(string.format("pick_up_item: Initialized with handle #%d.", task_handle)) end

	use_ability = UseAbility_GetTaskHandle()

	Task_RegisterTask(task_handle, PLAYERS_ALL, blueprint.run, blueprint.score, blueprint.init)

	taskJobDomain:RegisterJob(
			function(workingSet)
				if workingSet.throttle:allowed() then
					local droppedItems = GetDroppedItemList()
			--		if droppedItems and droppedItems[1] then
			--			Util_TablePrint({"DROPPED ITEM LIST", droppedItems})
			--		end
					Task_SetTaskPriority(task_handle, PLAYERS_ALL, TASK_PRIORITY_TOP)
				end
			end,
			{["throttle"] = Time_CreateThrottle(1.0)}, -- score is static
			"JOB_TASK_SCORING_PRIORITY_PICK_UP_ITEM"
		)
	Blueprint_RegisterTaskActivityType(task_handle, ACTIVITY_TYPE["NOT_APPLICABLE"])
	task_init_func = nil
	return task_handle, estimated_time_til_completed
end
Blueprint_RegisterTask(task_init_func)

blueprint = {
	run = function(gsiPlayer, objective, xetaScore)
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
		local droppedItems = GetDroppedItemList()
		
		if not droppedItems or not droppedItems[1] then
			return false, XETA_SCORE_DO_NOT_RUN
		end
		
		--Util_TablePrint(table.sort(getmetatable(gsiPlayer.hUnit)))
		if gsiPlayer.hUnit:GetItemInSlot(JUNGLE_ITEM_ITEM_SLOT) then
			return false, XETA_SCORE_DO_NOT_RUN
		end
		local PointDistance = Vector_PointDistance2D
		local jungleItemKeys = ITEMS_JUNGLE
		local playerLoc = gsiPlayer.lastSeen.location
		local nearestItem
		local nearestItemDist = 0xFFFF
		for i=1,#droppedItems do
			local thisItem = droppedItems[i]
			local thisDist = PointDistance(playerLoc, thisItem.location)
			
			if jungleItemKeys[thisItem.item:GetName()] then
				if thisDist < nearestItemDist then
					nearestItemDist = thisDist
					nearestItem = thisItem
				end
			end
		end
		
		if nearestItemDist > 700 then
			return false, XETA_SCORE_DO_NOT_RUN
		end
		local currentActivityType = Blueprint_GetCurrentTaskActivityType(gsiPlayer)
		if currentActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION
				and nearestItemDist < 200 then
			return nearestItem, 150
		elseif currentActivityType >= ACTIVITY_TYPE.CAREFUL then
			if PointDistance(playerLoc, TEAM_FOUNTAIN)
					> PointDistance(nearestItem.location, TEAM_FOUNTAIN) then
				return nearestItem, 300 - Math_ETA(gsiPlayer, nearestItem.location)*50
			end
			return false, XETA_SCORE_DO_NOT_RUN
		else
			return nearestItem, 300 - Math_ETA(gsiPlayer, nearestItem.location)*50
		end
	end,
	
	init = function(gsiPlayer, objective, extrapolatedXeta)
		return extrapolatedXeta
	end
}

function PickUpItem_GetTaskHandle()
	return task_handle
end
