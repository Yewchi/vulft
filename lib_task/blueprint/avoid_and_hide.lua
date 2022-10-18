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

local task_handle = Task_CreateNewTask()

local increase_safety_handle

local blueprint

local next_player = 1
local function estimated_time_til_completed(gsiPlayer, objective)
	return 20 -- TODO consider
end
local function task_init_func(taskJobDomain)
	if VERBOSE then VEBUG_print(string.format("avoid_and_hide: Initialized with handle #%d.", task_handle)) end

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
		
		if not forceRun and theorizedDanger < 0 then
			return XETA_SCORE_DO_NOT_RUN
		end
		if Math_PointToPointDistance2D(gsiPlayer.lastSeen.location, TEAM_FOUNTAIN) < GO_FOUNTAIN_INSTEAD_DIST then
			Task_IncentiviseTask(gsiPlayer, increase_safety_handle, 100, 20)
		end
		--print(gsiPlayer.shortName, "AvoidHide", nearbyFriendlyTower)
		if nearbyFriendlyTower then	
			local nearbyTowerLoc = nearbyFriendlyTower.lastSeen.location
			local nearestEnemy, distToEnemyHero = Set_GetNearestEnemyHeroToLocation(gsiPlayer.lastSeen.location, 9) -- TODO Redundantly checking full hero list
			local enemiesCenter = Set_GetCrowdedRatingToSetTypeAtLocation(nearestEnemy.lastSeen.location, SET_HERO_ENEMY)
			local healthDiffOutnumbered = FightHarass_GetHealthDiffOutnumbered(gsiPlayer)
			local higherTierTower = GSI_GetHigherTierTower(nearbyFriendlyTower)
			if higherTierTower == nil then print("/VUL-FT/ <DEBUG> No higher tier!!!! --", nearbyFriendlyTower.team, nearbyFriendlyTower.lane, nearbyFriendlyTower.tier, bUnit_IsNullOrDead(nearbyFriendlyTower)) higherTierTower = GSI_GetTeamFountainUnit(TEAM) end
			local enemyDistanceToNearbyTower = nearestEnemy
					and Math_PointToPointDistance2D(
							nearbyFriendlyTower.lastSeen.location,
							enemiesCenter
						)
					or 0xFFFF

			--[[DEBUG]]if DEBUG and DEBUG_IsBotTheIntern() then DebugDrawText(250, 800, string.format("%.1f;%d;%d", healthDiffOutnumbered, enemyDistanceToNearbyTower, distanceToTower), 255, 255, 0) end
			-- If the tower will not help us considerably in a fight, and the enemy is nearby it || closer to it then us, and there are no enemies from us to the higher tier tower, then retreat to a higher tier tower. (Walking past an enemy closer to a backwards-retreatable T1 will flip it from T2 to T1, usually seemlessly)
			local directionalToHigherTier = Vector_UnitDirectionalPointToPoint(gsiPlayer.lastSeen.location, higherTierTower.lastSeen.location)
			local testSafetyStart = Vector_Addition(gsiPlayer.lastSeen.location, Vector_ScalarMultiply2D(directionalToHigherTier, 500))
			--print("printing avoid hide retreat check", gsiPlayer.shortName, healthDiffOutnumbered, enemyDistanceToNearbyTower, distanceToTower, #Set_GetEnemiesInRectangle(testSafetyStart, higherTierTower.lastSeen.location, 900, nearbyEnemies, false, false) == 0)
			if healthDiffOutnumbered < 0
					and (enemyDistanceToNearbyTower < CONSIDER_ENEMIES_DIVING_TOWER_PROXIMITY or enemyDistanceToNearbyTower < distanceToTower)
					and (#Set_GetEnemiesInRectangle(testSafetyStart, higherTierTower.lastSeen.location, 900, nearbyEnemies, false, false) == 0
							or theorizedDanger > 1
						) then
				nearbyFriendlyTower = higherTierTower
				nearbyTowerLoc = nearbyFriendlyTower.lastSeen.location
				distanceToTower = Math_PointToPointDistance2D(gsiPlayer.lastSeen.location, nearbyFriendlyTower.lastSeen.location)
			end
			-- TODO nearestEnemy change to crowded needs test
			local avoidedLocation = enemiesCenter or enemy_fountain_loc
			local behindTowerFromEnemy = Vector_Addition(
					nearbyTowerLoc,
					Vector_ScalarMultiply2D(
						Vector_UnitDirectionalPointToPoint(
							avoidedLocation,
							nearbyTowerLoc
						), 800
					)
				)
			 if DEBUG then DebugDrawLine(gsiPlayer.lastSeen.location, behindTowerFromEnemy, 255, 255, 255) end
		
			if distanceToTower < 1400 then -- Get to tha chopper
				gsiPlayer.hUnit:Action_MoveDirectly(Vector_BoundedToWorld(behindTowerFromEnemy))
			elseif distanceToTower < 5000 then -- Try to 1-2 past your allies 
				local nearbyAllies = Set_GetAlliedHeroesInPlayerRadius(gsiPlayer, 5000)
				if #nearbyAllies > 0 then
					if VERBOSE then VEBUG_print(gsiPlayer.shortName, "using allied grouping retreat") end
					local crowdedCenter = Set_GetCrowdedRatingToSetTypeAtLocation(
							gsiPlayer.lastSeen.location, SET_HERO_ALLIED)
					local sideOfEscapeFormation = Vector_SideOfPlane(
							gsiPlayer.lastSeen.location,
							crowdedCenter,
							behindTowerFromEnemy
						)
					local escapeChannelHead = Vector_Addition(
							crowdedCenter,
							Vector_ScalarMultiply(
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
							Vector_ScalarMultiply(
									Vector_UnitDirectionalPointToPoint(behindTowerFromEnemy, escapeChannelHead),
									min(900, Vector_PointDistance2D(gsiPlayer.lastSeen.location, behindTowerFromEnemy))
								)
						)
					--[[DEBUG]]if DEBUG then DebugDrawLine(escapeChannelHead, behindTowerFromEnemy, 255, 150, 150) end
					moveLocation = Vector_PointBetweenPoints(escapeChannelHead, behindTowerFromEnemy)
					Positioning_ZSMoveCasual(gsiPlayer, moveLocation, 3, 1000, true)
				else
					Positioning_ZSMoveCasual(gsiPlayer, behindTowerFromEnemy, 3, 1000, true)
				end
			else -- lead the enemy across the face of the plane that your nearby allies create, or towards fountain with a 45 degree shift from an ally
				Positioning_ZSMoveCasual(gsiPlayer, TEAM_FOUNTAIN, 3, 1000, true)
			end
		else
			-- no towers remain
			Positioning_ZSMoveCasual(gsiPlayer, TEAM_FOUNTAIN, 3, 1000, true)
		end
		return xetaScore
	end,
	
	score = function(gsiPlayer, prevObjective, prevScore)
		-- TODO On a throttle, calculate the odds of a successful escape, drop score and greatly
		-- -| incentivise fight harass if we seem to be dying
		local theorizedDangerAmount, knownEngageables, theorizedEngageables = Analytics_GetTheoreticalDangerAmount(gsiPlayer)
		if #knownEngageables + #theorizedEngageables == 0 then
			local thisFearedScore = t_stay_feared_score[gsiPlayer.nOnTeam]
			if thisFearedScore < -50 then
				t_stay_feared_score[gsiPlayer.nOnTeam] = XETA_SCORE_DO_NOT_RUN
				return false, XETA_SCORE_DO_NOT_RUN
			else
				local decreaseByBasic = gsiPlayer.time.frameElapsed*DECREASE_FEAR_PER_SECOND
				local danger = Analytics_GetTheoreticalDangerAmount(gsiPlayer)
				t_stay_feared_score[gsiPlayer.nOnTeam] = thisFearedScore
						- max(decreaseByBasic, decreaseByBasic*(1-danger))
			end
			return gsiPlayer, t_stay_feared_score[gsiPlayer.nOnTeam] 
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
		t_stay_feared_score[gsiPlayer.nOnTeam] = thisAvoidScore
		--print(gsiPlayer.shortName, "avoid score is", thisAvoidScore)
		return gsiPlayer, thisAvoidScore
	end,
	
	init = function(gsiPlayer, objective, extrapolatedXeta)
		UseAbility_ClearQueuedAbilities(gsiPlayer)
		return extrapolatedXeta
	end
}

function AvoidHide_GetTaskHandle()
	return task_handle
end
