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

local SET_TYPE_UNIT_NEARBY = Set_GetSetTypeUnitNearestToLocation
local SET_CREEP_NEUTRAL = SET_CREEP_NEUTRAL

local HALF_PUSH_DISIRE_TIME = 26*60 -- .'. theoretically, you would want to push twice as much at minute 52 than minute 26, if you have alive advantage.

local task_handle = Task_CreateNewTask()

local blueprint

local min = math.min
local max = math.max

local farm_lane_handle
local push_handle

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

local function estimated_time_til_completed(gsiPlayer, objective)
	return 0
end
local function task_init_func(taskJobDomain)
	Blueprint_RegisterTaskName(task_handle, "dawdle")
	if VERBOSE then VEBUG_print(string.format("dawdle: Initialized with handle #%d.", task_handle)) end

	farm_lane_handle = FarmLane_GetTaskHandle()
	push_handle = Push_GetTaskHandle()

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

blueprint = {
	run = function(gsiPlayer, objective, xetaScore)
		if objective and objective.type == UNIT_TYPE_BUILDING then
			if objective.isOutpost then 
				AbilityLogic_UseOutpost(gsiPlayer, objective)
			elseif objective.isLamp then
				AbilityLogic_UseLantern(gsiPlayer, objective)
			elseif objective.isTwinGate then
				AbilityLogic_UseTwinGate(gsiPlayer, objective) -- result: unusable
			elseif objective.isMangoTree then
				AbilityLogic_UseFamangoTree(gsiPlayer, objective) -- result: unusable
			end
			-- TEMP
			return xetaScore;
		end
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
				--[[DEV]]print("dawd pushhard", gsiPlayer.shortName, moveTo)
				Positioning_ZSMoveCasual(gsiPlayer, moveTo, 700,
						max(600, 2000 - (gsiPlayer.locationVariation or 1000)), false, false
					)
				return xetaScore;
			end

			-- Stand near allies. TODO Decide on highground locations
			--[[DEV]]print("dawd farm jung", gsiPlayer.shortName, moveTo)
			local nearbyAllies = Set_GetAlliedHeroesInPlayerRadius(gsiPlayer, 2400)

			local farmLaneObjective = Task_GetTaskObjective(gsiPlayer, farm_lane_handle)
			local farmLaneObjectiveLoc = LeechExp_GetStandingLoc(gsiPlayer)
			local playerLoc = gsiPlayer.lastSeen.location
							
			local towardsFarmLaneObjective = Vector_PointToPointLimitedMin2D(
					playerLoc, farmLaneObjectiveLoc, 1400
				)

			if FarmJungle_SimpleRunLimitTime(gsiPlayer, 25,
						towardsFarmLaneObjective,
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
			moveTo = Vector_ScalePointToPointByFactor(moveTo, farmLaneObjectiveLoc or TEAM_FOUNTAIN, 0.025)
			if crowdingRating > 1 then
				if farmLaneObjectiveLoc then
					--print("adjusting dawdle to farmLaneObjective", farmLaneObjective)
					moveTo = Vector_PointBetweenPoints(
							moveTo,
							farmLaneObjectiveLoc
						)
				end
			end
			--[[DEV]]local oldMoveTo = moveTo
			moveTo = Positioning_AdjustToAvoidCrowdingSetType(gsiPlayer, moveTo, SET_HERO_ENEMY, 1200)
			moveTo = Positioning_AdjustToAvoidCrowdingSetType(gsiPlayer, moveTo, SET_BUILDING_ENEMY, 1400, 1000)
			--[[DEV]]if DEBUG then DebugDrawLine(gsiPlayer.lastSeen.location, oldMoveTo, GetDBGColor(gsiPlayer, 1), GetDBGColor(gsiPlayer, 2), GetDBGColor(gsiPlayer, 3)) end
			--[[DEV]]if DEBUG then DebugDrawLine(moveTo, oldMoveTo, GetDBGColor(gsiPlayer, 1), GetDBGColor(gsiPlayer, 2), GetDBGColor(gsiPlayer, 3)) end
			--[[DEV]]print("dawd normally", gsiPlayer.shortName, moveTo)
			Positioning_MoveDirectly(gsiPlayer, moveTo)
		end
		return xetaScore
	end,
	
	score = function(gsiPlayer, prevObjective, prevScore)
		local danger, known, theory = Analytics_GetTheoreticalDangerAmount(gsiPlayer)
		local pushHarderFactor, aliveAdvantage
				= Analytics_GetPushHarderMetricFightIgnorant(gsiPlayer, danger, aliveAdvantage)
		local cantJungleFactorNotAggressivePush = 0
		local pushObj = Task_GetTaskObjective(gsiPlayer, push_handle)
		if pushHarderFactor < 1.25 and aliveAdvantage <= 0.5 and
				not FarmLane_IsUtilizingLaneSafety(gsiPlayer)
				and not (pushObj and pushObj.isTower) then -- stuck in jungle? hate this. TODO i.e. push's tower acquisition range, push needs to set tower earlier than unagroablePush
			local greedyPlayer = Dawdle_GetCantJunglePushHeroNearby(gsiPlayer)
			--[[DEV]]if VERBOSE then VEBUG_print("[dawdle] score: greedy player for %s is %s",
			--[[DEV]]		gsiPlayer.shortName, greedyPlayer and greedyPlayer.shortName) end
			if greedyPlayer then -- TODO ALL of this needs to be separated
				if greedyPlayer == gsiPlayer then
					cantJungleFactorNotAggressivePush = XETA_SCORE_DO_NOT_RUN_SOFT
				else
					cantJungleFactorNotAggressivePush = max(
							Task_GetTaskScore(gsiPlayer, farm_lane_handle), Task_GetTaskScore(gsiPlayer, push_handle)
						) * 1.25
				end
			end
		end
		local outpost = Set_GetNearestTeamOutpostInLocRad(ENEMY_TEAM, gsiPlayer.lastSeen.location,
				gsiPlayer.currentMovementSpeed*9/(1+0.75*gsiPlayer.vibe.greedRating+max(0,danger+1))
			)
		if outpost and not outpost.hUnit:HasModifier("modifier_invulnerable")
				and not gsiPlayer.hUnit:IsSilenced()
				and outpost.team ~= gsiPlayer.team then
			-- TEMP
			--[[DEV]]print("Checking outpost", gsiPlayer.shortName)
			local averageLevel = GSI_GetTeamAverageLevel(TEAM)
			local averageLevelEnemy = GSI_GetTeamAverageLevel(ENEMY_TEAM)
			local utilizedFactor = (averageLevel < 29 and 0.5 or 0.2) + (averageLevelEnemy < 29 and 0.5 or 0.2)
			local abilityCapture = gsiPlayer.hUnit:GetAbilityByName("ability_capture")
			local captureDuration = abilityCapture:GetDuration()
			local channelingOutpost, _, expires = UseItem_IsChanneling(gsiPlayer, "ability_capture")
			local channelRemaining = chanellingOutpost and expires - GameTime() or captureDuration
			if danger < 1.0 and (#known == 0 or channelingOutpost
						and #known < max(0.1, (captureDuration-channelRemaining-danger))
					) and (chanellingOutpost or #theory <= 2) then
				local scoreOutpost = Math_GetFastThrottledBounded(
						Xeta_EvaluateExperienceGain(gsiPlayer, GameTime() * 2),
						80, 250, 600
					)
				scoreOutpost = scoreOutpost * (1-0.15*gsiPlayer.vibe.greedRating)
							* min(1, (-danger-1)) + (captureDuration - channelRemaining)*45
				--[[DEV]]if DEBUG then INFO_print("[dawdle] take outpost score %.2f", scoreOutpost) end
				return outpost, scoreOutpost
			end
		end
		-- [[ TESTS FAILED 2023-19-09 7.34c ]]
		if false then
			local lantern, lanternDist = SET_TYPE_UNIT_NEARBY(
					gsiPlayer.lastSeen.location, SET_BUILDING_NEUTRAL, "lanterns"
				)
			--[[DEV]]if VERBOSE then VEBUG_print("[dawdle] test lantern %s %d", gsiPlayer.shortName, lanternDist) end
			if lantern then
				return lantern, 50000
			end
		elseif false then
			local twinGate, twinGateDist = SET_TYPE_UNIT_NEARBY(
					gsiPlayer.lastSeen.location, SET_BUILDING_NEUTRAL, "twinGates"
				)
			--[[DEV]]if VERBOSE then VEBUG_print("[dawdle] test twin gate %s %d", gsiPlayer.shortName, twinGateDist) end
			if twinGate then
				return twinGate, 50000
			end
		elseif false then
			local mangoTree, mangoTreeDist = SET_TYPE_UNIT_NEARBY(
					gsiPlayer.lastSeen.location, SET_BUILDING_NEUTRAL, "mangoTrees"
				)
			--[[DEV]]if VERBOSE then VEBUG_print("[dawdle] test famango tree %s %d", gsiPlayer.shortName, mangoTreeDist) end
			if mangoTree then
				return mangoTree, 50000
			end
		end

		if #known > 0 then
			return false, XETA_SCORE_DO_NOT_RUN;
		end

		local score = (GetGameState() == GAME_STATE_PRE_GAME and -200
				or (cantJungleFactorNotAggressivePush == 0 and -30 or 0)) -- GETTING COSY IN HERE TODO
				+ cantJungleFactorNotAggressivePush
		if cantJungleFactorNotAggressivePush < 0 then
			score = score + Math_GetFastThrottledBounded(max(0, 100*pushHarderFactor - 125), 110, 180, 250)
		else
			score = score + 25
		end
		--[[DEV]]if VERBOSE or DEBUG and DEBUG_IsBotTheIntern() then DEBUG_print("[dawdle] %s score returning %s, jungleInstead: %s", gsiPlayer.shortName, score, cantJungleFactorNotAggressivePush) end
		return gsiPlayer, score
	end,
	
	init = function(gsiPlayer, objective, extrapolatedXeta)
		return extrapolatedXeta
	end
}

function Dawdle_GetTaskHandle()
	return task_handle
end
