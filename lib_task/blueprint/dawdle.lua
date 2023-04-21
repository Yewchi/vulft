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

local HALF_PUSH_DISIRE_TIME = 26*60 -- .'. theoretically, you would want to push twice as much at minute 52 than minute 26, if you have alive advantage.

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
			{["throttle"] = Time_CreateThrottle(3.0)},
			"JOB_TASK_SCORING_PRIORITY_DAWDLE"
		)
	Blueprint_RegisterTaskActivityType(task_handle, ACTIVITY_TYPE["NOT_APPLICABLE"])
	task_init_func = nil
	return task_handle, estimated_time_til_completed
end
Blueprint_RegisterTask(task_init_func)

function Dawdle_GetCantJunglePushHeroNearby(gsiPlayer)
	local nearbyAllies = Set_GetAlliedHeroesInPlayerRadius(gsiPlayer, 2400)

	local farmLaneObjective = Task_GetTaskObjective(gsiPlayer, farm_lane_handle)
	local farmLaneObjectiveLoc = farmLaneObjective and (
					farmLaneObjective.x and farmLaneObjective
					or farmLaneObjective.center and farmLaneObjective.center
					or farmLaneObjective.lastSeen and farmLaneObjective.lastSeen.location
			) or false

	local flScore = Task_GetTaskScore(gsiPlayer, farm_lane_handle)
	if farmLaneObjective and #nearbyAllies > 0 then
		table.insert(nearbyAllies, gsiPlayer);
		local greedyPlayer = FarmJungle_GetGreedyCantJungle(gsiPlayer, nearbyAllies);
		nearbyAllies[#nearbyAllies] = nil;

		return greedyPlayer
	end
end

blueprint = {
	run = function(gsiPlayer, objective, xetaScore)
		local danger = Analytics_GetTheoreticalDangerAmount(gsiPlayer)
		Map_CheckForLurkPockets(gsiPlayer)
		if danger < 0.5 then -- TODO do it properly
			local aliveAdvantage = GSI_GetAliveAdvantageFactor()
			local teamAvgLevel = GSI_GetTeamAverageLevel(TEAM)
			local enemyAvgLevel = GSI_GetTeamAverageLevel(ENEMY_TEAM)
			
			local pushHarderFactor = Analytics_GetPushHarderMetricFightIgnorant(gsiPlayer, danger, aliveAdvantage)
			if danger < -1 and pushHarderFactor >= 1.25 or imPusher then
				-- TODO TEMP
				-- Push the lane instead of standing near allies or jungling, if you have advantage on the push
				local pushCreepSet, pushLoc, pushLane, pushScore = Analytics_GetMostEffectivePush(gsiPlayer)
				
				local moveTo = Vector_Addition(
						pushLoc,
						Vector_ScalarMultiply2D(
								Vector_UnitDirectionalPointToPoint(pushLoc, ENEMY_FOUNTAIN),
								1100 - gsiPlayer.attackRange
							)
					)
				
				Positioning_ZSMoveCasual(gsiPlayer, moveTo, 700,
						max(600, 2000 - (gsiPlayer.locationVariation or 1000)), false, false
					)
				return xetaScore;
			end

			-- Stand near allies. TODO Decide on highground locations
			
			local nearbyAllies = Set_GetAlliedHeroesInPlayerRadius(gsiPlayer, 2400)

			local farmLaneObjective = Task_GetTaskObjective(gsiPlayer, farm_lane_handle)
			local farmLaneObjectiveLoc = LeechExp_GetStandingLoc(gsiPlayer)
			local playerLoc = gsiPlayer.lastSeen.location
							
			local towardsFarmLaneObjective = Vector_PointToPointLimitedMin2D(
					playerLoc, farmLaneObjectiveLoc, 1400
				)

			if FarmJungle_SimpleRunLimitTime(gsiPlayer, 25,
						towardsFarmLaneObjective,
						8*gsiPlayer.currentMovementSpeed
					) then
				return xetaScore;
			end

			local moveTo = Positioning_AdjustToAvoidCrowdingSetType(
					gsiPlayer,
					gsiPlayer.lastSeen.location,
					SET_HERO_ALLIED,
					600
				)

			local crowdingRating
			moveTo, crowdingRating = CROWDED_RATING(moveTo, SET_HERO_ALLIED, nearbyAllies, 8000)
			moveTo = Vector_ScalePointToPointByFactor(moveTo, farmLaneObjectiveLoc or TEAM_FOUNTAIN, 0.1)
			if crowdingRating > 1 then
				if farmLaneObjectiveLoc then
					--print("adjusting dawdle to farmLaneObjective", farmLaneObjective)
					moveTo = Vector_PointBetweenPoints(
							moveTo,
							farmLaneObjectiveLoc
						)
				end
			end
			
			moveTo = Positioning_AdjustToAvoidCrowdingSetType(gsiPlayer, moveTo, SET_HERO_ENEMY, 1200)
			moveTo = Positioning_AdjustToAvoidCrowdingSetType(gsiPlayer, moveTo, SET_BUILDING_ENEMY, 1400, 1000)
			
			
			
			Positioning_MoveDirectly(gsiPlayer, moveTo)
		end
		return xetaScore
	end,
	
	score = function(gsiPlayer, prevObjective, prevScore)
		local pushHarderFactor = Analytics_GetPushHarderMetricFightIgnorant(gsiPlayer, danger, aliveAdvantage)
		local cantJungleFactorNotAggressivePush = 0
		if pushHarderFactor < 1.25 and not FarmLane_IsUtilizingLaneSafety(gsiPlayer) then
			local greedyPlayer = Dawdle_GetCantJunglePushHeroNearby(gsiPlayer)
			if greedyPlayer == gsiPlayer then
				cantJungleFactorNotAggressivePush = XETA_SCORE_DO_NOT_RUN_SOFT
			end
		end
		return gsiPlayer, (GetGameState() == GAME_STATE_PRE_GAME and -200
					or -30 + max(0, (pushHarderFactor - 1.25) * 20)
				) + cantJungleFactorNotAggressivePush
	end,
	
	init = function(gsiPlayer, objective, extrapolatedXeta)
		return extrapolatedXeta
	end
}

function Dawdle_GetTaskHandle()
	return task_handle
end
