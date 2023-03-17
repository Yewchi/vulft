local SEARCH_FOG_THROTTLE = 0.213 -- rotates

local TEAM_NUMBER_OF_PLAYERS = TEAM_NUMBER_OF_PLAYERS

local task_handle = Task_CreateNewTask()

local next_player = 1

local t_enemy_players

local ENEMY_FOUNTAIN = ENEMY_FOUNTAIN

local t_player_check_location = {}

local TEST = false

local function estimated_time_til_completed(gsiPlayer, objective)
	return 3 -- don't care
end
local function task_init_func(taskJobDomain)
	if VERBOSE then VEBUG_print(string.format("search_fog: Initialized with handle #%d.", task_handle)) end
	task_handle = Task_CreateNewTask()

	Task_RegisterTask(task_handle, PLAYERS_ALL, blueprint.run, blueprint.score, blueprint.init)

	t_enemy_players = GSI_GetTeamPlayers(ENEMY_TEAM)

	local next_player = 1
	taskJobDomain:RegisterJob(
			function(workingSet)
				if workingSet.throttle:allowed() then
					Task_SetTaskPriority(task_handle, next_player, TASK_PRIORITY_TOP)
					next_player = Task_RotatePlayerOnTeam(next_player)
				end
			end,
			{["throttle"] = Time_CreateThrottle(SEARCH_FOG_THROTTLE)},
			"JOB_TASK_SCORING_PRIORITY_SEARCH_FOG"
		)
	Blueprint_RegisterTaskActivityType(task_handle, ACTIVITY_TYPE["NOT_APPLICABLE"])
	task_init_func = nil
	return task_handle, estimated_time_til_completed
end
Blueprint_RegisterTask(task_init_func)

blueprint = {
	run = function(gsiPlayer, objective, xetaScore)
		local checkLocation = t_player_check_location[gsiPlayer.nOnTeam]








		if not checkLocation then
			return XETA_SCORE_DO_NOT_RUN
		end
		Positioning_ZSMoveCasual(gsiPlayer, checkLocation, 650, 1100)
		return xetaScore
	end,
	
	score = function(gsiPlayer, prevObjective, prevScore)
		local nearbyEnemies = Set_GetEnemyHeroesInPlayerRadius(gsiPlayer, 1300, 5)
		local danger = Analytics_GetTheoreticalDangerAmount(gsiPlayer)
		local lowestHealthPercent = 1.1
		local lowestHealthEnemy
		local lowestHealthCheckLocation
		if danger > -0.5 or Blueprint_GetCurrentTaskActivityType(gsiPlayer) >= ACTIVITY_TYPE.FEAR then
			return false, XETA_SCORE_DO_NOT_RUN
		end
		local timeStampConsiderUnknown = GameTime() - gsiPlayer.time.frameElapsed*3
		local nearestTower
		local nearestTowerLoc
		t_player_check_location[gsiPlayer.nOnTeam] = nil
		for i=1,#t_enemy_players do
			local thisEnemy = t_enemy_players[i]





			local lastSeenTime = thisEnemy.lastSeen.timeStamp



			if IsHeroAlive(thisEnemy.playerID)
					and lastSeenTime < timeStampConsiderUnknown and GameTime() - lastSeenTime < 8
					and Vector_PointDistance2D(gsiPlayer.lastSeen.location, thisEnemy.lastSeen.location)
						< 1700 then
				local thisHpp = thisEnemy.lastSeenHealth / thisEnemy.maxHealth
				if thisHpp < lowestHealthPercent then
					nearestTower = nearestTower or Set_GetNearestTeamTowerToPlayer(ENEMY_TEAM, gsiPlayer)
					nearestTowerLoc = nearestTower and nearestTower.lastSeen.location
					local checkLocation = Vector_Addition(
							thisEnemy.lastSeen.location,
							Vector_ScalarMultiply(
									ENEMY_FOUNTAIN,
									(GameTime() - thisEnemy.lastSeen.timeStamp)*150
								)
						)
					if not nearestTower
							or ( Vector_PointDistance(checkLocation, nearestTower.lastSeen.location)
											> nearestTower.attackRange + 200
									and not Positioning_WillAttackCmdExposeToLocRad(
											gsiPlayer, thisEnemy, nearestTowerLoc, nearestTower.attackRange+100
										) 
								) then
						lowestHealthPercent = thisHpp
						lowestHealthEnemy = thisEnemy
						lowestHealthCheckLocation = checkLocation
					end
				end
			end
		end
		if lowestHealthEnemy then
			local earlyGameReduction = DotaTime() < 720 and 1+(720 - DotaTime())/720 or 1
			t_player_check_location[gsiPlayer.nOnTeam] = lowestHealthCheckLocation
			return lowestHealthEnemy, (30 - earlyGameReduction*2*(GameTime() - lowestHealthEnemy.lastSeen.timeStamp))*(-danger)*(lowestHealthPercent+0.33)
		end
		return false, XETA_SCORE_DO_NOT_RUN
	end,
	
	init = function(gsiPlayer, objective, extrapolatedXeta)
		return extrapolatedXeta
	end
}

function SearchFog_GetTaskHandle()
	return task_handle
end
