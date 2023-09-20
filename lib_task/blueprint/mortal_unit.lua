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
local Math_GetFastThrottledBounded = Math_GetFastThrottledBounded
local CROWDED_RATING = Set_GetCrowdedRatingToSetTypeAtLocation

local task_handle = Task_CreateNewTask()

local blueprint

local max = math.max
local sqrt = math.sqrt

local farm_lane_handle

local t_team_players

local t_wards_to_kill = {}

local function estimated_time_til_completed(gsiPlayer, objective)
	return 0
end
local function task_init_func(taskJobDomain)
	Blueprint_RegisterTaskName(task_handle, "mortal_unit")
	if VERBOSE then VEBUG_print(string.format("mortal_unit: Initialized with handle #%d.", task_handle)) end

	farm_lane_handle = FarmLane_GetTaskHandle()
	t_team_players = GSI_GetTeamPlayers(TEAM)

	Task_RegisterTask(task_handle, PLAYERS_ALL, blueprint.run, blueprint.score, blueprint.init)

	local process_pnot = 1

	taskJobDomain:RegisterJob(
			function(workingSet)
				if workingSet.throttle:allowed() then
					--[[
					local thisPlayer = t_team_players[process_pnot]
					local enemyWards = Set_GetTeamWardsInPlayerRadius(gsiPlayer, 3000)
					local pLoc = thisPlayer.lastSeen.location
					for i=1,#enemyWards do
						local wLoc = enemyWards[i].lastSeen.location
						if Analytics_GetTheoreticalDangerAmount(gsiPlayer, nil, enemyWards.lastSeen.location)
								< 0.5 then
							
							Task_SetTaskPriority(task_handle, process_pnot, TASK_PRIORITY_TOP)
						end
					end
					next_pnot = ((process_pnot + 1) % #t_team_players) + 1
					]]
				end
			end,
			{["throttle"] = Time_CreateThrottle(0.33)},
			"JOB_TASK_SCORING_PRIORITY_MORTAL_UNIT"
		)
	Blueprint_RegisterTaskActivityType(task_handle, ACTIVITY_TYPE["NOT_APPLICABLE"])
	task_init_func = nil
	return task_handle, estimated_time_til_completed
end
Blueprint_RegisterTask(task_init_func)

blueprint = {
	run = function(gsiPlayer, objective, xetaScore)
		local danger = Analytics_GetTheoreticalDangerAmount(gsiPlayer)
		local nearbyAllies = Set_GetAlliedHeroesInPlayerRadius(gsiPlayer, 2400)

		return xetaScore
	end,
	
	score = function(gsiPlayer, prevObjective, prevScore)
		local pLoc = gsiPlayer.lastSeen.location
		local enemyWards = {}
		for i=1,#enemyWards do
			
		end
		if killWard then
			wLoc = killWard.lastSeen.location
			local danger = Analytics_GetTheoreticalDangerAmount(gsiPlayer, nil, wLoc)
			return gsiPlayer, 180 - Xeta_CostOfTravelToLocation(gsiPlayer, location)
		end
		return false, XETA_SCORE_DO_NOT_RUN
	end,
	
	init = function(gsiPlayer, objective, extrapolatedXeta)
		return extrapolatedXeta
	end
}

function Dawdle_GetTaskHandle()
	return task_handle
end
