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

-- Used to raise teleport abilities if possible
MINIMUM_ALLOWED_USE_TP_INSTEAD = 5500
local MINIMUM_ALLOWED_USE_TP_INSTEAD = MINIMUM_ALLOWED_USE_TP_INSTEAD
local SCORED_TO_RUN_FRAME_SHIFT_LIMIT = 1400

local SAFE_TO_TP_DANGER = 0.0

local CHANNELING = 1
local CHECK_PORT_NEEDED = 2
local NO_CHECK_PORT_NEEDED = 3

local PRIORITY_UPDATE_THROTTLE = 0.757

local blueprint

local task_handle = Task_CreateNewTask()

local desired_locations = {}
local port_state = {}

function Port_BuyPortScrollsIfNeeded(gsiPlayer)
	-- 12/10/22 buying behavior should mostly trigger from port.score()
	
	if Item_TownPortalScrollsOwned(gsiPlayer) < 2 and gsiPlayer.hUnit:GetGold() > GetItemCost("item_tpscroll") then
		
		gsiPlayer.hUnit:ActionImmediate_PurchaseItem("item_tpscroll")
		return true
	else
		return false
	end
end

function Port_CheckPortNeeded(gsiPlayer, location, dryRun) -- Checks for good ports are above
	local tpScroll = gsiPlayer.hUnit:GetItemInSlot(TPSCROLL_SLOT)
	local taskStartTime = Task_GetCurrentTaskStartTime(gsiPlayer)
	if not tpScroll or tpScroll:GetCooldownTimeRemaining() > 0 
			or taskStartTime == 0 or GameTime() - taskStartTime < 0.15 then 
		return
	end
	local nearbyEnemyTower, nearbyTowerDist = Set_GetNearestTeamTowerToPlayer(ENEMY_TEAM, gsiPlayer)
	if nearbyTowerDist < 1700 then
		return
	end
	local playerLoc = gsiPlayer.lastSeen.location
	local actualPortLocation = Map_GetNearestPortableStructure(gsiPlayer, location)
	--local distancePlayerToPort = Math_PointToPointDistance2D(playerLoc, actualPortLocation)
	local distancePlayerToDestination = Math_PointToPointDistance2D(playerLoc, location)
	local distancePortToDestination = Math_PointToPointDistance2D(actualPortLocation, location)
	local nOnTeam = gsiPlayer.nOnTeam
	local numAllies = Set_GetAlliedHeroes
	if Analytics_GetTheoreticalDangerAmount(gsiPlayer, nil, location) < SAFE_TO_TP_DANGER then
		location = Map_AdjustLocationForSaferPort(location)
	end
	if Vector_WithinWorldBounds(location, 900)
			and port_state[nOnTeam] == NO_CHECK_PORT_NEEDED
			and distancePlayerToDestination-distancePortToDestination
				> MINIMUM_ALLOWED_USE_TP_INSTEAD then -- Can we just walk there; Is the port a shortcut?
		if dryRun then
			return location
		end
		
		desired_locations[nOnTeam] = location
		port_state[nOnTeam] = CHECK_PORT_NEEDED
		Task_SetTaskPriority(task_handle, nOnTeam, TASK_PRIORITY_TOP)
	end
end

local function estimated_time_til_completed(gsiPlayer, objective)
	return 2 -- don't care
end
local function task_init_func()
	Blueprint_RegisterTaskName(task_handle, "port")
	if VERBOSE then VEBUG_print(string.format("port: Initialized with handle #%d.", task_handle)) end

	Task_RegisterTask(task_handle, PLAYERS_ALL, blueprint.run, blueprint.score, blueprint.init)

	for i=1,TEAM_NUMBER_OF_PLAYERS do
		port_state[i] = NO_CHECK_PORT_NEEDED
	end
	
	Blueprint_RegisterTaskActivityType(task_handle, ACTIVITY_TYPE["CAREFUL"])
	task_init_func = nil
	return task_handle, estimated_time_til_completed
end
Blueprint_RegisterTask(task_init_func)

blueprint = {
	run = function(gsiPlayer, objective, xetaScore)
		local nOnTeam = gsiPlayer.nOnTeam
if DEBUG then
		DebugDrawLine(gsiPlayer.lastSeen.location, desired_locations[nOnTeam], 255, 255, 255)
end
		--print(gsiPlayer.shortName, "trying to use item_tpscroll to", desired_locations[gsiPlayer.nOnTeam], port_state[nOnTeam], gsiPlayer.hUnit:GetCurrentActiveAbility())
		if Math_PointToPointDistance2D(gsiPlayer.lastSeen.location, desired_locations[nOnTeam]) < MINIMUM_ALLOWED_USE_TP_INSTEAD-SCORED_TO_RUN_FRAME_SHIFT_LIMIT then
			desired_locations[nOnTeam] = nil
			port_state[nOnTeam] = NO_CHECK_PORT_NEEDED -- TODO they will cancel sometimes with an 'urgent' objective.
			Task_SetTaskPriority(task_handle, gsiPlayer.nOnTeam, TASK_PRIORITY_FORGOTTEN)
			return XETA_SCORE_DO_NOT_RUN
		end
		--if gsiPlayer.hUnit:GetCurrentActiveAbility() then print("port:", gsiPlayer.shortName, gsiPlayer.hUnit:GetCurrentActiveAbility():GetName()) end
		if port_state[nOnTeam] ~= CHANNELING and gsiPlayer.hUnit:GetCurrentActiveAbility() and gsiPlayer.hUnit:GetCurrentActiveAbility():GetName() == "item_tpscroll" then
			port_state[nOnTeam] = CHANNELING
		elseif port_state[nOnTeam] == CHANNELING and not (gsiPlayer.hUnit:GetCurrentActiveAbility() and gsiPlayer.hUnit:GetCurrentActiveAbility():GetName() == "item_tpscroll") then
			port_state[nOnTeam] = NO_CHECK_PORT_NEEDED
			desired_locations[nOnTeam] = nil
			Task_SetTaskPriority(task_handle, gsiPlayer.nOnTeam, TASK_PRIORITY_FORGOTTEN)
			return XETA_SCORE_DO_NOT_RUN
		end
		local tpscroll = gsiPlayer.hUnit:GetItemInSlot(TPSCROLL_SLOT)
		if tpscroll and gsiPlayer.lastSeenMana >= tpscroll:GetManaCost() then
			if port_state[nOnTeam] ~= CHANNELING then
				gsiPlayer.hUnit:Action_UseAbilityOnLocation(tpscroll, desired_locations[nOnTeam])
				return xetaScore
			end
		else
			return XETA_SCORE_DO_NOT_RUN
		end
		if Vector_PointDistance(desired_locations[nOnTeam], TEAM_FOUNTAIN) > 6000
				and Map_LocIsInTeamFountain(gsiPlayer.lastSeen.location) then
			ItemComms_ICanFillBottleAtLoc(gsiPlayer, desired_locations[nOnTeam])
		end
		return xetaScore
	end,
	
	score = function(gsiPlayer, prevObjective, prevScore)
		Port_BuyPortScrollsIfNeeded(gsiPlayer)

		local pnot = gsiPlayer.nOnTeam
		if port_state[pnot] == NO_CHECK_PORT_NEEDED then return prevObjective, prevScore or XETA_SCORE_DO_NOT_RUN end
		if port_state[pnot] == CHECK_PORT_NEEDED then
			port_state[pnot] = NO_CHECK_PORT_NEEDED
			if desired_locations[pnot] and gsiPlayer.hUnit:GetItemInSlot(TPSCROLL_SLOT) and gsiPlayer.hUnit:GetItemInSlot(TPSCROLL_SLOT):GetCooldownTimeRemaining() == 0 then 
				return gsiPlayer, Xeta_CostOfTravelToLocation(gsiPlayer, desired_locations[pnot]) + (Task_GetCurrentTaskHandle(gsiPlayer) ~= task_handle and math.max(0, Task_GetCurrentTaskScore(gsiPlayer)) or 0)
			else
				desired_locations[pnot] = nil
			end
		end
		return prevObjective, prevScore or XETA_SCORE_DO_NOT_RUN
	end,
	
	init = function(gsiPlayer, objective, extrapolatedXeta)
		Port_BuyPortScrollsIfNeeded(gsiPlayer)
		if not desired_locations[gsiPlayer.nOnTeam] then
			return false
		end
		Task_IndicateSuccessfulInitShortTask(gsiPlayer, task_handle)
		return extrapolatedXeta
	end
}

function Port_GetTaskHandle()
	return task_handle
end
