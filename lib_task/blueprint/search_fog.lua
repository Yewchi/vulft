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

local TIME_SINCE_SEEN_LIMIT_SEARCH = 8

local t_team_players
local t_enemy_players

local ENEMY_FOUNTAIN = ENEMY_FOUNTAIN

local t_player_check_location = {}
local t_player_bezier_escape = {}

local TEST = true

local max = math.max

local function estimated_time_til_completed(gsiPlayer, objective)
	return 3 -- don't care
end
local function task_init_func(taskJobDomain)
	Blueprint_RegisterTaskName(task_handle, "search_fog")
	if VERBOSE then VEBUG_print(string.format("search_fog: Initialized with handle #%d.", task_handle)) end

	Task_RegisterTask(task_handle, PLAYERS_ALL, blueprint.run, blueprint.score, blueprint.init)

	t_team_players = GSI_GetTeamPlayers(TEAM)
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

local bezier_platter = {}
function SearchFog_GetNearbyBezier(location, radius)
	local beziers = t_player_bezier_escape
	local countBeziers = 0
	for i=1,TEAM_NUMBER_OF_PLAYERS do
		local bez = beziers[i]
		if bez then
			if bez.expires < GameTime() then
				beziers[i] = nil
			elseif Vector_PointDistance(location, bez.val or bez.p0) < radius then
				countBeziers = countBeziers + 1
				bezier_platter[countBeziers] = bez
			end
		end
	end
	bezier_platter[countBeziers+1] = nil
	bezier_platter[countBeziers+2] = nil
	bezier_platter[countBeziers+3] = nil
	return bezier_platter
end

function SearchFog_GetRevealLocNearby(gsiPlayer, radius, location)
	local beziers = t_player_bezier_escape
	location = location or gsiPlayer.lastSeen.location
	local i = gsiPlayer.nOnTeam
	local exitIndex = (i + TEAM_NUMBER_OF_PLAYERS - 2) % TEAM_NUMBER_OF_PLAYERS + 1
	while(i ~= exitIndex) do
		local bez = beziers[i]
		if bez and bez.val then
			if bez.expires < GameTime() then
				beziers[i] = nil
			elseif Vector_PointDistance(location, bez.val or bez.p0) < radius then
				return bez.val, bez
			end
		end
		i = i % TEAM_NUMBER_OF_PLAYERS + 1
	end
end

function SearchFog_GetEscapeGuess(gsiPlayer)
	return t_player_bezier_escape[gsiPlayer.nOnTeam]
end
SearchFog_GetPlayerBezier = SearchFog_GetEscapeGuess

function SearchFog_InformFreshNull(gsiEnemy)
	local teamPlayers = t_team_players
	local enemyLoc = gsiEnemy.lastSeen.location
	for i=1,#teamPlayers do
		if teamPlayers[i].hUnit:IsAlive() then
			local playerLoc = teamPlayers[i].lastSeen.location
			if ((playerLoc.x-enemyLoc.x)^2 + (playerLoc.y-enemyLoc.y)^2)^0.5 < 2400 then
				Task_SetTaskPriority(task_handle, i, TASK_PRIORITY_TOP)
			end
		end
	end
end

blueprint = {
	run = function(gsiPlayer, objective, xetaScore)
		local currTime = GameTime()
		local checkLocation = t_player_check_location[gsiPlayer.nOnTeam]
		local timeSinceSeen = currTime-objective.lastSeen.timeStamp








		if not checkLocation then
			return XETA_SCORE_DO_NOT_RUN
		end

		local lastSeenLoc = objective.lastSeen.location

		local checkBezier = t_player_bezier_escape[gsiPlayer.nOnTeam]
		if not checkBezier or checkBezier and (checkBezier.hero ~= objective or checkBezier.expires < currTime) then
			local forwardsFacing = Vector_Addition(
					lastSeenLoc,
					Vector_ScalarMultiply2D(Vector_UnitDirectionalFacingDegrees(
							objective.lastSeen.facingDegrees
						),
						objective.currentMovementSpeed*TIME_SINCE_SEEN_LIMIT_SEARCH/2
					)
				)
			local forwardsToFountainUnit = Vector_UnitDirectionalPointToPoint(forwardsFacing, ENEMY_FOUNTAIN)
			forwardsFacing = Vector_Addition(forwardsFacing, Vector_ScalarMultiply2D(
						Vector_Inverse(forwardsToFountainUnit),
						objective.currentMovementSpeed * TIME_SINCE_SEEN_LIMIT_SEARCH/4
					)
				)
			checkBezier = Vector_CreateBezierFunction(objective.lastSeen.location,
					forwardsFacing,
					Vector_Addition(
						Vector_PointBetweenPoints(lastSeenLoc, forwardsFacing),
						Vector_ScalarMultiply2D(Vector_UnitDirectionalPointToPoint(
								lastSeenLoc, ENEMY_FOUNTAIN -- using lastSeenLoc here ends up closer to the ^|channel|^ towards fountain of the forwardsFacing location, it is in interception.
							),
							objective.currentMovementSpeed*TIME_SINCE_SEEN_LIMIT_SEARCH*1.15
						)
					)
				)
			checkBezier.expires = currTime + TIME_SINCE_SEEN_LIMIT_SEARCH
			checkBezier.forPlayer = objective
			t_player_bezier_escape[gsiPlayer.nOnTeam] = checkBezier
		end

		Positioning_ZSMoveCasual(gsiPlayer, checkBezier:compute((timeSinceSeen+0.5) / TIME_SINCE_SEEN_LIMIT_SEARCH), 650, 1100, 0.05)
		gsiPlayer.recentMoveTo = objective.location

		
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
		local enemyFountain = ENEMY_FOUNTAIN
		local playerEhp = (1 + Unit_GetArmorPhysicalFactor(gsiPlayer)) * gsiPlayer.lastSeenHealth
		t_player_check_location[gsiPlayer.nOnTeam] = nil
		for i=1,#t_enemy_players do
			local thisEnemy = t_enemy_players[i]





			local lastSeenTime = thisEnemy.lastSeen.timeStamp



			if IsHeroAlive(thisEnemy.playerID)
					and lastSeenTime < timeStampConsiderUnknown and GameTime() - lastSeenTime < TIME_SINCE_SEEN_LIMIT_SEARCH
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
					local playerCanWithstandOrNoTower = (not nearestTower
							or playerEhp / nearestTower.attackDamage > 4 * (thisHpp + #t_enemy_players))
							and ((checkLocation.x-enemyFountain.x)^2 + (checkLocation.y-enemyFountain.y)^2)^0.5 < 1600
					if playerCanWithstandOrNoTower
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
			local checkBezier = t_player_bezier_escape[gsiPlayer.nOnTeam]
			local scaredFountainFactor = 0
			if checkBezier and checkBezier.val then
				local guessLoc = checkBezier.val
				local distFountain = ((guessLoc.x-enemyFountain.x)^2 + (guessLoc.y-enemyFountain.y)^2)^0.5
				if distFountain < 1800 or not (guessLoc.x > enemyFountain.x or guessLoc.y > enemyFountain.y) then
					distFountain = 1 - (distFountain - 1000)/1400
					if distFountain > 0 then
						distFountain = distFountain > 1 and 1 or distFountain
						scaredFountainFactor = -3200 + Math_GetFastThrottledBounded((gsiPlayer.lastSeenHealth*0.01
									/ (Unit_GetArmorPhysicalFactor(gsiPlayer)*(1-gsiPlayer.evasion))),
								3000, 3200, 20000
							) * distFountain
					end
				end
			end
			return lowestHealthEnemy, (30 - earlyGameReduction*2*(GameTime() - lowestHealthEnemy.lastSeen.timeStamp))
					* (-danger)*((1-lowestHealthPercent)+0.33) - towerFear + scaredFountainFactor
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
