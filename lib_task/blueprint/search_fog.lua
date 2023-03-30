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

local SEARCH_FOG_THROTTLE = 0.213 -- rotates

local TEAM_NUMBER_OF_PLAYERS = TEAM_NUMBER_OF_PLAYERS

local task_handle = Task_CreateNewTask()

local next_player = 1

local t_enemy_players

local ENEMY_FOUNTAIN = ENEMY_FOUNTAIN

local t_player_check_location = {}

local TEST = false

local max = math.max

local function estimated_time_til_completed(gsiPlayer, objective)
	return 3 -- don't care
end
local function task_init_func(taskJobDomain)
	Blueprint_RegisterTaskName(task_handle, "search_fog")
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
--[[DEV]]if DEBUG and TEST then
--[[DEV]]	INFO_print(string.format("[search_fog] %s searches for %s at %s.",
--[[DEV]]				gsiPlayer.shortName, objective.shortName, 
--[[DEV]]				objective.lastSeen.location
--[[DEV]]			)
--[[DEV]]		)
--[[DEV]]	DebugDrawCircle(objective.lastSeen.location, 150*(GameTime()-objective.lastSeen.timeStamp), 220, 80, 80)
--[[DEV]]end
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
		local lowestHealthNearestTowerDist = 1100
		if danger > -0.5 or Blueprint_GetCurrentTaskActivityType(gsiPlayer) >= ACTIVITY_TYPE.FEAR then
			return false, XETA_SCORE_DO_NOT_RUN
		end
		local timeStampConsiderUnknown = GameTime() - gsiPlayer.time.frameElapsed*3
		local nearestTower
		local nearestTowerDist
		local nearestTowerLoc
		t_player_check_location[gsiPlayer.nOnTeam] = nil
		for i=1,#t_enemy_players do
			local thisEnemy = t_enemy_players[i]
--[[DEV]]	if TEST then
--[[DEV]]		print("search_fog", gsiPlayer.shortName, thisEnemy.shortName, Vector_PointDistance2D(gsiPlayer.lastSeen.location, thisEnemy.lastSeen.location),
--[[DEV]]				GameTime() - thisEnemy.lastSeen.timeStamp
--[[DEV]]			)
--[[DEV]]	end
			local lastSeenTime = thisEnemy.lastSeen.timeStamp
--[[DEV]]	if TEST then
--[[DEV]]		print("search_fog", thisEnemy.playerID, thisEnemy.hUnit and thisEnemy.hUnit.IsNull and not thisEnemy.hUnit:IsNull() and thisEnemy.hUnit:GetPlayerID(), IsHeroAlive(thisEnemy.playerID))
--[[DEV]]	end
			if IsHeroAlive(thisEnemy.playerID)
					and lastSeenTime < timeStampConsiderUnknown and GameTime() - lastSeenTime < 8
					and Vector_PointDistance2D(gsiPlayer.lastSeen.location, thisEnemy.lastSeen.location)
						< 1700 then
				local thisHpp = thisEnemy.lastSeenHealth / thisEnemy.maxHealth
				if thisHpp < lowestHealthPercent then
					local thisEnemyLoc = thisEnemy.lastSeen.location
					nearestTower, nearestTowerDist = Set_GetNearestTeamBuildingToLoc(ENEMY_TEAM, thisEnemyLoc, true)
					nearestTowerLoc = nearestTower and nearestTower.lastSeen.location
					local checkLocation = Vector_Addition(
							thisEnemy.lastSeen.location,
							Vector_ScalarMultiply2D(
									Vector_UnitDirectionalPointToPoint(thisEnemyLoc,
											nearestTower and nearestTower.lastSeen.location or ENEMY_FOUNTAIN
										),
									(GameTime() - thisEnemy.lastSeen.timeStamp)*thisEnemy.currentMovementSpeed*1.25
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
						lowestHealthNearestTowerDist = nearestTowerDist
					end
				end
			end
		end
		if lowestHealthEnemy then
			local towerFear = max(0, 30*(
						(1100 - (lowestHealthNearestTowerDist+300*(GameTime() - lowestHealthEnemy.lastSeen.timeStamp)))/500
						- Analytics_GetPowerLevel(gsiPlayer)
					)
				)
			local earlyGameReduction = DotaTime() < 720 and 1+(720 - DotaTime())/720 or 1
			t_player_check_location[gsiPlayer.nOnTeam] = lowestHealthCheckLocation
			return lowestHealthEnemy, (30 - earlyGameReduction*2*(GameTime() - lowestHealthEnemy.lastSeen.timeStamp))
					* (-danger)*((1-lowestHealthPercent)+0.33) - towerFear
		end
		return false, XETA_SCORE_DO_NOT_RUN
	end,
	
	init = function(gsiPlayer, objective, extrapolatedXeta)
		Task_IndicateSuccessfulInitShortTask(gsiPlayer, task_handle)
		return extrapolatedXeta
	end
}

function SearchFog_GetTaskHandle()
	return task_handle
end
