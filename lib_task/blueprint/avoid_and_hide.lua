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

local XETA_AVOID_AND_HIDE = XETA_AVOID_AND_HIDE
local FightHarass_GetHealthDiffAndOutnumbered = FightHarass_GetHealthDiffAndOutnumbered
local Set_GetNearestTeamTowerToPlayer = Set_GetNearestTeamTowerToPlayer
local Set_GetNearestEnemyHeroToLocation = Set_GetNearestEnemyHeroToLocation
local GSI_GetNextHighestTierTower = GSI_GetNextHighestTierTower
local max = math.max
local min = math.min

local PRIORITY_UPDATE_AVOID_HIDE_THROTTLE = 0.131 -- rotates

local CONSIDER_ENEMIES_DIVING_TOWER_PROXIMITY = 850

local GO_FOUNTAIN_INSTEAD_DIST = 1600

local ESCAPE_SPACING = 120
local DECREASE_FEAR_PER_SECOND = 20 

local t_stay_feared_score = {}

local t_start_avoid_hide_with_creep_agro = {}

local t_enemy_players
local t_team_players

local task_handle = Task_CreateNewTask()

local increase_safety_handle

local blueprint

local next_player = 1
local function estimated_time_til_completed(gsiPlayer, objective)
	return 20 -- TODO consider
end
local function task_init_func(taskJobDomain)
	Blueprint_RegisterTaskName(task_handle, "avoid_and_hide")
	if VERBOSE then VEBUG_print(string.format("avoid_and_hide: Initialized with handle #%d.", task_handle)) end

	t_enemy_players = GSI_GetTeamPlayers(ENEMY_TEAM)
	t_team_players = GSI_GetTeamPlayers(TEAM)

	for i=1,TEAM_NUMBER_OF_PLAYERS do
		t_stay_feared_score[i] = XETA_SCORE_DO_NOT_RUN
	end

	Task_RegisterTask(task_handle, PLAYERS_ALL, blueprint.run, blueprint.score, blueprint.init)

	enemy_fountain_loc = Map_GetTeamFountainLocation()

	taskJobDomain:RegisterJob(
			function(workingSet)
				if workingSet.throttle:allowed() then
					Task_SetTaskPriority(task_handle, next_player, TASK_PRIORITY_TOP)
					next_player = Task_RotatePlayerOnTeam(next_player)
				end
			end,
			{["throttle"] = Time_CreateThrottle(PRIORITY_UPDATE_AVOID_HIDE_THROTTLE)},
			"JOB_TASK_SCORING_PRIORITY_AVOID_HIDE"
		)
	Blueprint_RegisterTaskActivityType(task_handle, ACTIVITY_TYPE["FEAR"])
	increase_safety_handle = IncreaseSafety_GetTaskHandle()
	task_init_func = nil
	return task_handle, estimated_time_til_completed
end
Blueprint_RegisterTask(task_init_func)

blueprint = {
	run = function(gsiPlayer, objective, xetaScore, forceRun)
		local nearbyFriendlyTower, distanceToTower = Set_GetNearestTeamTowerToPlayer(TEAM, gsiPlayer) -- nb. "nearby" because "nearest" betrays a potential switch to higher tier
		local nearbyEnemies = Set_GetEnemyHeroesInPlayerRadius(gsiPlayer, 1750, 8)
		local theorizedDanger = Analytics_GetTheoreticalDangerAmount(gsiPlayer)
		local playerLoc = gsiPlayer.lastSeen.location

		local currTime = GameTime()

		local getAgroIfLaning = t_start_avoid_hide_with_creep_agro[gsiPlayer.nOnTeam]
		if getAgroIfLaning then
			if getAgroIfLaning < currTime or theorizedDanger > 1.5 then
				t_start_avoid_hide_with_creep_agro[gsiPlayer.nOnTeam] = nil
			elseif getAgroIfLaning - currTime < 0.15 then
				local enemyPlayers = t_enemy_players
				local targetEnemy
				targetEnemy = gsiPlayer.hUnit:GetDifficulty() < 4 and Set_GetNearestEnemyHeroToLocation(playerLoc, 0)
						or Set_GetFurthestEnemyHeroToLocation(playerLoc, 0)
				if targetEnemy then
					gsiPlayer.hUnit:Action_AttackUnit(targetEnemy.hUnit, false)
					return xetaScore
				end
			end
		end
		
		if not forceRun and theorizedDanger < 0 then
			return XETA_SCORE_DO_NOT_RUN
		end
		if Math_PointToPointDistance2D(playerLoc, TEAM_FOUNTAIN) < GO_FOUNTAIN_INSTEAD_DIST then
			Task_IncentiviseTask(gsiPlayer, increase_safety_handle, 100, 20)
		end
		--print(gsiPlayer.shortName, "AvoidHide", nearbyFriendlyTower)
		if nearbyFriendlyTower then	
			local nearbyTowerLoc = nearbyFriendlyTower.lastSeen.location
	
			local nearestEnemy, distToEnemyHero = Set_GetNearestEnemyHeroToLocation(playerLoc, 9) -- TODO Redundantly checking full hero list
			local enemiesCenter = nearestEnemy and Set_GetCrowdedRatingToSetTypeAtLocation(nearestEnemy.lastSeen.location, SET_HERO_ENEMY)
			local healthDiffOutnumbered = FightHarass_GetHealthDiffOutnumbered(gsiPlayer)
			local higherTierTower = GSI_GetHigherTierTower(nearbyFriendlyTower)
			if higherTierTower == nil then
				WARN_print(string.format("[avoid_and_hide] Warning - No higher tier nor fountain unit from nearby tower!"..
								"-- nearbyTower: %s, lane %d, T%d, dead:%s",
							nearbyFriendlyTower.team == TEAM_DIRE and "D" or "R", nearbyFriendlyTower.lane,
							nearbyFriendlyTower.tier, bUnit_IsNullOrDead(nearbyFriendlyTower)
						)
					)
				higherTierTower = GSI_GetTeamFountainUnit(TEAM)
			end
			local enemyDistanceToNearbyTower = nearestEnemy
					and Math_PointToPointDistance2D(
							nearbyFriendlyTower.lastSeen.location,
							enemiesCenter
						)
					or 0xFFFF

			--[[DEBUG]]if DEBUG and DEBUG_IsBotTheIntern() then DebugDrawText(250, 800, string.format("%.1f;%d;%d", healthDiffOutnumbered, enemyDistanceToNearbyTower, distanceToTower), 255, 255, 0) end
			-- If the tower will not help us considerably in a fight, and the enemy is nearby it || closer to it then us, and there are no enemies from us to the higher tier tower, then retreat to a higher tier tower. (Walking past an enemy closer to a backwards-retreatable T1 will flip it from T2 to T1, usually seemlessly)
			local directionalToHigherTier = Vector_UnitDirectionalPointToPoint(playerLoc, higherTierTower.lastSeen.location)
			local testSafetyStart = Vector_Addition(playerLoc, Vector_ScalarMultiply2D(directionalToHigherTier, 500))
			--print("printing avoid hide retreat check", gsiPlayer.shortName, healthDiffOutnumbered, enemyDistanceToNearbyTower, distanceToTower, #Set_GetEnemiesInRectangle(testSafetyStart, higherTierTower.lastSeen.location, 900, nearbyEnemies, false, false) == 0)
			if healthDiffOutnumbered < 0
					and (enemyDistanceToNearbyTower < CONSIDER_ENEMIES_DIVING_TOWER_PROXIMITY or enemyDistanceToNearbyTower < distanceToTower)
					and (#Set_GetEnemiesInRectangle(testSafetyStart, higherTierTower.lastSeen.location, 900, nearbyEnemies, false, false) == 0
							or theorizedDanger > 1
						) then
				nearbyFriendlyTower = higherTierTower
				nearbyTowerLoc = nearbyFriendlyTower.lastSeen.location
				distanceToTower = Math_PointToPointDistance2D(playerLoc, nearbyFriendlyTower.lastSeen.location)
			end
			-- TODO nearestEnemy change to crowded needs test
			local avoidedLocation = enemiesCenter or enemy_fountain_loc
			local behindTowerFromEnemy = Vector_Addition(
					nearbyTowerLoc,
					Vector_ScalarMultiply2D(
						Vector_UnitDirectionalPointToPoint(
							avoidedLocation,
							nearbyTowerLoc
						),
						800
					)
				)
			if DEBUG then DebugDrawLine(playerLoc, behindTowerFromEnemy, 255, 255, 255) end
		
			if distanceToTower < 1400 then -- Get to tha chopper
				Positioning_ZSMoveCasual(gsiPlayer, behindTowerFromEnemy, 150, 1000,
						max(0, 1
								-( (  (behindTowerFromEnemy.x-playerLoc.x)^2
									+ (behindTowerFromEnemy.y-playerLoc.y)^2  )^0.5
							) / 200
						)
					)
			elseif distanceToTower < 5000 then -- Try to 1-2 past your allies 
				local nearbyAllies = Set_GetAlliedHeroesInPlayerRadius(gsiPlayer, 5000)
				if #nearbyAllies > 0 then
					if VERBOSE then VEBUG_print(gsiPlayer.shortName, "using allied grouping retreat") end
					local crowdedCenter = Set_GetCrowdedRatingToSetTypeAtLocation(
							playerLoc, SET_HERO_ALLIED)
					local sideOfEscapeFormation = Vector_SideOfPlane(
							playerLoc,
							crowdedCenter,
							behindTowerFromEnemy
						)
					local escapeChannelHead = Vector_Addition(
							crowdedCenter,
							Vector_ScalarMultiply2D(
								Vector_ToDirectionalUnitVector(
									Vector_CartesianNormal(
										Vector_PointToPointLine(crowdedCenter, behindTowerFromEnemy)
									)
								),
								ESCAPE_SPACING
							)
						)
					local moveLocation = Vector_Addition(
							behindTowerFromEnemy,
							Vector_ScalarMultiply2D(
									Vector_UnitDirectionalPointToPoint(behindTowerFromEnemy, escapeChannelHead),
									min(1100, Vector_PointDistance2D(playerLoc, behindTowerFromEnemy))
								)
						)
					--[[DEBUG]]if DEBUG then DebugDrawLine(escapeChannelHead, behindTowerFromEnemy, 255, 150, 150) end
					moveLocation = Vector_PointBetweenPoints(escapeChannelHead, behindTowerFromEnemy)
					Positioning_ZSMoveCasual(gsiPlayer, moveLocation, 150, 1000, 0)
				else
					Positioning_ZSMoveCasual(gsiPlayer, behindTowerFromEnemy, 150, 1000, 0)
				end
			else -- lead the enemy across the face of the plane that your nearby allies create, or towards fountain with a 45 degree shift from an ally
				Positioning_ZSMoveCasual(gsiPlayer, TEAM_FOUNTAIN, 150, 1000, 0)
			end
		else
			-- no towers remain
			Positioning_ZSMoveCasual(gsiPlayer, TEAM_FOUNTAIN, 150, 1000, 0)
		end
		return xetaScore
	end,
	
	score = function(gsiPlayer, prevObjective, prevScore)
		-- TODO On a throttle, calculate the odds of a successful escape, drop score and greatly
		-- -| incentivise fight harass if we seem to be dying
		local danger, knownEngageables, theorizedEngageables = Analytics_GetTheoreticalDangerAmount(gsiPlayer)
		local farmCreep, farmAttackInTime, farmScore = FarmLane_AnyCreepLastHitTracked(gsiPlayer)
		local lastHitIsNow = - (farmAttackInTime < 1.33 and farmScore / (0.95 + gsiPlayer.level*0.05)  or 0)
		if #knownEngageables == 0 then
			local thisFearedScore = t_stay_feared_score[gsiPlayer.nOnTeam]
			if thisFearedScore < -50 then
	
				t_stay_feared_score[gsiPlayer.nOnTeam] = XETA_SCORE_DO_NOT_RUN
				return false, XETA_SCORE_DO_NOT_RUN
			else
				local decreaseByBasic = gsiPlayer.time.frameElapsed*DECREASE_FEAR_PER_SECOND
				t_stay_feared_score[gsiPlayer.nOnTeam] = thisFearedScore
						- max(decreaseByBasic, decreaseByBasic*(1-danger))
			end
			return gsiPlayer, t_stay_feared_score[gsiPlayer.nOnTeam]
						+ lastHitIsNow
		end
		if #knownEngageables > 0 and #theorizedEngageables == 0 then
			local foundClose = false
			for i=1,#knownEngageables do
				if Vector_PointDistance2D(
								gsiPlayer.lastSeen.location,
								knownEngageables[i].lastSeen.location
							) < max(1350, knownEngageables[i].attackRange * 1.5) then
					foundClose = true
					break
				end
			end
			if not foundClose then
				return false, XETA_SCORE_DO_NOT_RUN
			end
		end
		local thisAvoidScore =  Xeta_EvaluateObjectiveCompletion(
				XETA_AVOID_AND_HIDE, 
				0, 
				1.0,
				gsiPlayer,
				gsiPlayer
			)
		local averageEnemyLevel = GSI_GetTeamAverageLevel(ENEMY_TEAM)
		t_stay_feared_score[gsiPlayer.nOnTeam] = thisAvoidScore
		
		return gsiPlayer, thisAvoidScore + lastHitIsNow
	end,
	
	init = function(gsiPlayer, objective, extrapolatedXeta)
		UseAbility_ClearQueuedAbilities(gsiPlayer)
		if gsiPlayer.lastSeenHealth / 10 > extrapolatedXeta
				and (not t_start_avoid_hide_with_creep_agro[gsiPlayer.nOnTeam]
					or t_start_avoid_hide_with_creep_agro[gsiPlayer.nOnTeam] < GameTime()) then
			local farmCreep, farmAttackInTime, farmScore = FarmLane_AnyCreepLastHitTracked(gsiPlayer)
			if farmCreep and Vector_PointDistance2D(farmCreep.lastSeen.location, gsiPlayer.lastSeen.location) < 600 then
				t_start_avoid_hide_with_creep_agro[gsiPlayer.nOnTeam] = GameTime() + 8
			end
		end
		return extrapolatedXeta
	end
}

function AvoidHide_GetTaskHandle()
	return task_handle
end
