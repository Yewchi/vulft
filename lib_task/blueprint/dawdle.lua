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

-- In-between tasks task. A fall-back, never to be assumed to be active
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

local function estimated_time_til_completed(gsiPlayer, objective)
	return 0
end
local function task_init_func(taskJobDomain)
	Blueprint_RegisterTaskName(task_handle, "dawdle")
	if VERBOSE then VEBUG_print(string.format("dawdle: Initialized with handle #%d.", task_handle)) end

	farm_lane_handle = FarmLane_GetTaskHandle()

	Task_RegisterTask(task_handle, PLAYERS_ALL, blueprint.run, blueprint.score, blueprint.init)

	taskJobDomain:RegisterJob(
			function(workingSet)
				if workingSet.throttle:allowed() then
					Task_SetTaskPriority(task_handle, PLAYERS_ALL, TASK_PRIORITY_TOP)
				end
			end,
			{["throttle"] = Time_CreateThrottle(3.0)}, -- score is static
			"JOB_TASK_SCORING_PRIORITY_DAWDLE"
		)
	Blueprint_RegisterTaskActivityType(task_handle, ACTIVITY_TYPE["NOT_APPLICABLE"])
	task_init_func = nil
	return task_handle, estimated_time_til_completed
end
Blueprint_RegisterTask(task_init_func)

blueprint = {
	run = function(gsiPlayer, objective, xetaScore)
		if gsiPlayer.time.data.theorizedDanger and gsiPlayer.time.data.theorizedDanger < 0.5 then -- TODO do it properly

			-- Stand near allies. TODO Decide on highground locations
			if FarmJungle_SimpleRunLimitTime(gsiPlayer, 30) then
				return xetaScore
			end

			local nearbyAllies = Set_GetAlliedHeroesInPlayerRadius(gsiPlayer, 2400)
			local moveTo = Positioning_AdjustToAvoidCrowdingSetType(
					gsiPlayer,
					gsiPlayer.lastSeen.location,
					SET_HERO_ALLIED,
					600
				)

			local crowdingRating
			moveTo, crowdingRating = CROWDED_RATING(moveTo, SET_HERO_ALLIED, nearbyAllies, 8000)
			moveTo = Vector_ScalePointToPointByFactor(moveTo, TEAM_FOUNTAIN, 0.1)
			if crowdingRating > 1 then
				local farmLaneObjective = Task_GetTaskObjective(gsiPlayer, farm_lane_handle)
				farmLaneObjective = farmLaneObjective and (
								farmLaneObjective.x and farmLaneObjective
								or farmLaneObjective.center and farmLaneObjective.center
								or farmLaneObjective.lastSeen and farmLaneObjective.lastSeen.location
						) or false
				if farmLaneObjective then
					--print("adjusting dawdle to farmLaneObjective", farmLaneObjective)
					moveTo = Vector_PointBetweenPoints(
							moveTo,
							farmLaneObjective
						)
				end
			end
			
			moveTo = Positioning_AdjustToAvoidCrowdingSetType(gsiPlayer, moveTo, SET_HERO_ENEMY, 1200)
			
			
			gsiPlayer.hUnit:Action_MoveDirectly(moveTo)
		end
		return xetaScore
	end,
	
	score = function(gsiPlayer, prevObjective, prevScore)
		return gsiPlayer, GetGameState() == GAME_STATE_PRE_GAME and -200 or -30
	end,
	
	init = function(gsiPlayer, objective, extrapolatedXeta)
		return extrapolatedXeta
	end
}

function Dawdle_GetTaskHandle()
	return task_handle
end
