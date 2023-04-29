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

-- Resolves where a lane will push, given heroes in the lane, the current number of creeps in lane added to the number of creeps reinforcing divided by the time until they arrive by some constant

local max = math.max
local min = math.min
local abs = math.abs

local PUSHING_IS_HALF_EXPECTED = 24 * 60 -- in DotaTime, the estimated seconds that pushing is half as desirable as it is twice as desireable. i.e. 24 minutes and 48 minutes. At 48 minutes, not pushing when the enemy is dead is griefing, at 24 minutes, it might be better to get immediately back to farming and warding, especially due to the low respawn time. A core would not be blamed for teleporting to a better farming location at 24:00, but pushing is still on the table.
-- (Mathematical relationships provide fluidity and variety, and step towards the answer, logical limits cause oddness and predictability. I don't meant to say the 24 / 48 rule is very accurate, but the relation is important)
-- This constant is used in addition to the team winning factor as an indication that pushing harder due to dead (or preocupied and distant TODO) enemies is a good idea.
-- See Metrics wiki.

local AVG_LEVEL_PUSH_DIV = 10

local t_enemy_players

CREEP_AGRO_RANGE = 600
local CREEP_PRESSURE_RANGE = 1.3*CREEP_AGRO_RANGE

local CREEP_AGRO_RESET_LIMIT = 2 - 0.15
local CREEP_DEAGRO_RESET_LIMIT = 5

local Map_ExtrapoldatedLaneFrontWhenDeadBasic = Map_ExtrapolatedLaneFrontWhenDeadBasic
local TeamDiagonalReduce = TEAM == TEAM_RADIANT and Vector_SelectLowestDiagonal or Vector_SelectHighestDiagonal
local EnemyTeamDiagonalReduce = ENEMY_TEAM == TEAM_RADIANT and Vector_SelectLowestDiagonal or Vector_SelectHighestDiagonal
local CREEP_AGRO_RANGE = CREEP_AGRO_RANGE

local USE_GLYPH_FOR_RECENT_DMG = 150
local USE_GLYPH_ENEMY_PRESENCE_AT_TOWER = 7
local USE_T1_GLYPH_FOR_RECENT_DMG = 80
local USE_T1_GLYPH_FOR_HEALTH = 300
local USE_T1_GLYPH_FOR_HEALTH_AUTO = 50

local MAX_CREEP_SPAWNED = 10

local TOWER_GENERIC_POWER_FALLOFF = 2300

local job_domain_analytics 

local number_creeps_in_wave = 5

local team_middle_spawn

local t_seen_creep_pressure = {1, 1, 1, 1, 1}

local ALLOW_TIER_ONE_DEF_AVG_TEAM_LEVEL = 6
local tier_one_defend_allowed = false

local START_DEFENCE_THREAT_DIST_MULTIPLIER = 1000
local CONSIDER_CREEPS_ON_BASE_BUILDING = 1200

local ADJUST_DIRE_NEXT_CREEP_CHECK = Vector(-200, -200, 0)
local ADJUST_RADIANT_NEXT_CREEP_CHECK = Vector(200, 200, 0)

local DEBUG = DEBUG
local VERBOSE = VERBOSE
local TEST = TEST

local function adjust_lane_location_for_next_creep_set(team, location)
	if team == TEAM_DIRE then
		return Vector_Addition(location, ADJUST_DIRE_NEXT_CREEP_CHECK)
	else
		return Vector_Addition(location, ADJUST_RADIANT_NEXT_CREEP_CHECK)
	end
end

local creep_agro_reset_time = {}
local disallow_deagro_time = {}

local t_lane_is_sieged = {}

function LanePressure_InformTeamIsSieged(hUnit)
	local gsiBuilding = bUnit_ConvertToSafeUnit(hUnit)
	if gsiBuilding and gsiBuilding.lane then
		t_lane_is_sieged[gsiBuilding.lane] = true
	end
end

function LanePressure_CanDeagroCreeps(gsiPlayer)
	-- TODO dry run, run action
	local pnot = gsiPlayer.nOnTeam
	if not disallow_deagro_time[pnot]
			or disallow_deagro_time[pnot] <= GameTime() then
		return true
	end
	return false
end
function LanePressure_DeagroCreepsNow(gsiPlayer, target, dryRun)
	-- TODO dry run, run action
	local pnot = gsiPlayer.nOnTeam
	if not target then
		--target = Set_GetNearestAlliedCreepSetToLocation(gsiPlayer.lastSeen.location)
		target = gsiPlayer.hUnit:GetNearbyCreeps(900, false)
		for i=1,#target do
			local thisCreep = target[i]
			if thisCreep:GetHealth() < thisCreep:GetMaxHealth()/2 then
				target = thisCreep
				break;
			end
		end
	end
	if target and ( not disallow_deagro_time[pnot]
				or disallow_deagro_time[pnot] <= GameTime()
			) then
		if not dryRun then
			gsiPlayer.hUnit:Action_AttackUnit(target, true)
			disallow_deagro_time[pnot] = GameTime() + CREEP_DEAGRO_RESET_LIMIT
		end
		return true
	end
	return false
end
function LanePressure_CanAgroCreeps(gsiPlayer)



	if creep_agro_reset_time[pnot] and creep_agro_reset_time[pnot] <= GameTime() then
		creep_agro_reset_time[pnot] = false
	end
	return creep_agro_reset_time[pnot]
end
function LanePressure_AgroCreepsNow(gsiPlayer, target, dryRun)
	local pnot = gsiPlayer.nOnTeam
	if not target then
		local enemyPlayers = t_enemy_players
		target = gsiPlayer.difficulty <= 3
				and Set_GetNearestEnemyHeroToLocation(gsiPlayer.lastSeen.location, 0)
				or Set_GetFurthestEnemyHeroToLocation(gsiPlayer.lastSeen.location, 0)
	end
	if target and target.hUnit and not target.typeIsNone
			and ( not creep_agro_reset_time[pnot]
				or creep_agro_reset_time[pnot] <= GameTime()
			) then
		if not dryRun then
			gsiPlayer.hUnit:Action_AttackUnit(target.hUnit, true)
			creep_agro_reset_time[pnot] = GameTime() + CREEP_AGRO_RESET_LIMIT
		end
		return true;
	end
	return false;
end

-- 1 for equal number of creeps, approaches 2 for enemy outnumber allied creeps, approaches 0 for allied outnumber enemy
function Analytics_CreepPressureFast(gsiPlayer, alliedSet, enemySet)
	if not alliedSet or not enemySet then
		alliedSet = gsiPlayer.hUnit:GetNearbyCreeps(CREEP_PRESSURE_RANGE, false) -- use Set cached creep sets, can use 1-2s old data
		enemySet = gsiPlayer.hUnit:GetNearbyCreeps(CREEP_PRESSURE_RANGE, true)
	end
	local numAlliedCreeps = #alliedSet
	local numEnemyCreeps = #enemySet
	if DEBUG and DEBUG_IsBotTheIntern() then
		if gsiPlayer and alliedSet[1] then
			DebugDrawLine(gsiPlayer.lastSeen.location, alliedSet[1]:GetLocation(), 40, 140, 40)
			--print("alliedcreep", gsiPlayer.shortName, numAlliedCreeps)
		end
		if gsiPlayer and enemySet[1] then
			DebugDrawLine(gsiPlayer.lastSeen.location, enemySet[1]:GetLocation(), 140, 40, 40)
			--print("enemycreep", gsiPlayer.shortName, numEnemyCreeps)
		end
	end
	if numAlliedCreeps == numEnemyCreeps then
		return numEnemyCreeps ~= 0 and 1 or 0
	elseif numAlliedCreeps < numEnemyCreeps then
		return 2 - numAlliedCreeps/math.max(1, numEnemyCreeps)
	else
		return numEnemyCreeps/math.max(1, numAlliedCreeps)
	end
end
local creep_pressure = Analytics_CreepPressureFast

function Analytics_GetPushHarderMetricFightIgnorant(gsiPlayer, danger, aliveAdvantage)
	local timeData = gsiPlayer.time.data
	local aliveAdvantage = aliveAdvantage or GSI_GetAliveAdvantageFactor()
	if not timeData.pushHarder then
		local danger, knownE, theoryE = Analytics_GetTheoreticalDangerAmount(gsiPlayer)

		local enemyPlayers = GSI_GetTeamPlayers(ENEMY_TEAM)

		local currTime = GameTime()

		local considerDeadIfFarTimeStampAge = 6 -- nb. (6-timeSinceSeen) / 30; 0 < x < 0.2; 0 to the minimum aliveadvtg dead-added score
		
		local playerLoc = gsiPlayer.lastSeen.location

		local farIsDead = 0
		for i=1,#enemyPlayers do
			local thisEnemy = enemyPlayers[i]
			local timeSinceSeen = currTime - thisEnemy.lastSeen.timeStamp
			if not pUnit_IsNullOrDead(thisEnemy)
					or timeSinceSeen < considerDeadIfFarTimeStampAge then
				local distEnemy = Vector_PointDistance2D(thisEnemy.lastSeen.location, playerLoc)
				if distEnemy > 2400 then
					
					aliveAdvantage = aliveAdvantage + max(0.2, ((6-timeSinceSeen)/30)*min(1, (distEnemy / 4000)))
				end
			end
			
		end

		local gameLate = DotaTime() / PUSHING_IS_HALF_EXPECTED

		local gameLateOrWinning, teamAvgLevel, enemyAvgLevel = GSI_GetWinningFactor()
		gameLateOrWinning = min(1.67, gameLateOrWinning * 0.5
				+ gameLate)

		local playerHpp = gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth

		timeData.pushHarder = gameLateOrWinning
				* ( aliveAdvantage + playerHpp - 0.5*gsiPlayer.vibe.greedRating*(1.67 - gameLateOrWinning)
					+ (teamAvgLevel - enemyAvgLevel)/AVG_LEVEL_PUSH_DIV
					- (1-max(0, aliveAdvantage)/(5.3 - 2*gameLateOrWinning))
				)



	end
	return timeData.pushHarder, aliveAdvantage
end

function Analytics_ShouldPushHard(gsiPlayer, danger, aliveAdvantage)
	local pushHarder = Analytics_GetPushHarderMetricFightIgnorant(gsiPlayer, danger, aliveAdvantage)
	return pushHarder >= 1.25, pushHarder
end

-------- Analytics_GetMostEffectivePush()
function Analytics_GetMostEffectivePush(gsiPlayer)
	local playerLoc = gsiPlayer.lastSeen.location
	local bestScore = 0xFFFF -- TEMP REMOVE TODO
	local bestLaneFrontLocation
	local bestLane = 1
	local bestCreepSet

	local laneReplace
	local enemyBaseCloseCreepSet
	if TEAM_IS_RADIANT and playerLoc.x + playerLoc.y > 2000
			or not TEAM_IS_RADIANT and playerLoc.x + playerLoc.y < -2000 then
		enemyBaseCloseCreepSet
				= Set_GetNearestAlliedCreepSetInLane(gsiPlayer,
						Map_GetTeamBaseLogicalLane(ENEMY_BASE)
					)
		laneReplace = enemyBaseCloseCreepSet
				and Map_GetLaneValueOfMapPoint(enemyBaseCloseCreepSet.center)
	end

	-- temp TODO fight break out safety
	for iLane=1,3 do
		local laneFront = iLane == laneReplace and enemyBaseCloseCreepSet
				or --[[Set_GetAlliedCreepSetLaneFront(iLane) or]] Set_GetPredictedLaneFrontLocation(iLane)
		if iLane == gsiPlayer.nOnTeam and laneFront and laneFront.center then
			gsiPlayer.hUnit:ActionImmediate_Ping(laneFront.center.x, laneFront.center.y, false)
		end
		
		laneFront = laneFront and laneFront or Map_TeamSpawnerLoc(gsiPlayer.TEAM, lane)
		laneFrontLoc = laneFront.center or laneFront.x and laneFront
		local distToLaneFront = Vector_PointDistance2D(playerLoc, laneFrontLoc)
		
		if distToLaneFront < bestScore then -- TEMP
			bestLaneFrontLocation = laneFrontLoc
			bestLane = iLane
			bestScore = distToLaneFront -- TEMP
			bestCreepSet = laneFront.center and laneFront or nil
		end
	end
	
	return bestCreepSet, bestLaneFrontLocation, bestLane, bestScore
end

-- Returns safety in terms of player's power. This means if a safety rating is 1, then rejecting to attend a
-- 		lane will make the safety rating 0 (again, relative to your power level)
-- 	- - also returns laneHelpNeeded which is scaled to the importance of the player in the late-game, based on role
function Analytics_SafetyOfLaneFarm(gsiPlayer, lane, presentOrCommittedTbl)
	local timeData = gsiPlayer.time.data.safetyOfLane
	if timeData then
		if timeData[lane] then
			
				
			
			return timeData[lane], timeData[lane+3], timeData[lane+6], timeData[lane+9]
		end
	else
		timeData = {}
		gsiPlayer.time.data.safetyOfLane = timeData
	end
	local laneFront = Set_GetPredictedLaneFrontLocation(lane) or Set_GetAlliedCreepSetLaneFront(lane)
	laneFront = laneFront and laneFront or Map_TeamSpawnerLoc(gsiPlayer.TEAM, lane)
	local knownEng, theorizedEng, mimicScore = Analytics_GetKnownTheorizedEngageables(gsiPlayer, laneFront)
	local selfPowerLevel = Analytics_GetPowerLevel(gsiPlayer)
	
	local danger = mimicScore - selfPowerLevel
	local laneHelpNeeded = 0
	-- tank the pushingHasPressureScore for known, mainly based on mimic
	local pushingHasPressureScore = max(0, 5 - #knownEng - mimicScore) 
	local lowestTierEnemyTower = GSI_GetLowestTierTeamLaneTower(ENEMY_TEAM, lane)
	local lowestTierDist = Vector_PointDistance(
			lowestTierEnemyTower.lastSeen.location,
			laneFront
		)
	local playerDistToEnemyTower = Vector_PointDistance2D(
			gsiPlayer.lastSeen.location,
			lowestTierEnemyTower.lastSeen.location
		)
	local playerDistToLaneFront = Vector_PointDistance2D(
			gsiPlayer.lastSeen.location,
			laneFront
		)
	local canPortFactor = Item_TownPortalScrollCooldown(gsiPlayer) == 0 and 0.5 or 0.75
	local myFarmScore = (6-gsiPlayer.role)/1.5 * max(0, min(1, lowestTierDist / 4600 - 0.3045))
			* (1 - canPortFactor*max(0, min(1, playerDistToLaneFront / 5400 - 0.556))) 
	if presentOrCommittedTbl then
		for i=1,TEAM_NUMBER_OF_PLAYERS do
			local thisAllied = presentOrCommittedTbl[i]
			if thisAllied and thisAllied.hUnit:IsAlive() then
				local roleDifference = thisAllied.role - gsiPlayer.role
				if roleDifference > 0.1 then
					local thisAlliedPowerLevel = Analytics_GetPowerLevel(thisAllied)
					laneHelpNeeded = laneHelpNeeded + (1.1 - thisAllied.role/10)
					laneHelpNeeded = laneHelpNeeded + (roleDifference*0.5) -- blah
					danger = danger - thisAlliedPowerLevel/selfPowerLevel
				end
			end
		end
	end





	pushingHasPressureScore = pushingHasPressureScore / (1+min(playerDistToEnemyTower, lowestTierDist)/1600) 
	pushingHasPressureScore = pushingHasPressureScore * 0.25
	local laneTower = GSI_GetLowestTierDefensible(gsiPlayer.team, lane) -- TODO should be towers only
	local towerPower = max(80, laneTower.hUnit:GetAttackDamage()) / gsiPlayer.hUnit:GetAttackDamage() -- TODO tier power
	local safety = -( danger - towerPower*max(0,
			(TOWER_GENERIC_POWER_FALLOFF - Math_PointToPointDistance2D(laneTower.lastSeen.location, laneFront))
				/ TOWER_GENERIC_POWER_FALLOFF)
			)
	laneHelpNeeded = laneHelpNeeded * max(0.33, min(1, 1 - abs(safety+0.8)))
	timeData[lane] = safety
	timeData[lane+3] = laneHelpNeeded
	timeData[lane+6] = pushingHasPressureScore
	timeData[lane+9] = myFarmScore
	return safety, laneHelpNeeded, pushingHasPressureScore, myFarmScore
end

local zero_creeps = {}
zero_creeps.units = EMPTY_TABLE
local check_creep_tower_pressure_lane = 1
local function update_creep_tower_pressure__job()
	-- Enemy team pressure
	if not tier_one_defend_allowed then
		if Analytics_GetAverageTeamLevel(TEAM) >= ALLOW_TIER_ONE_DEF_AVG_TEAM_LEVEL then
			tier_one_defend_allowed = true
		end
	end
	laneToCheck = (check_creep_tower_pressure_lane + 1) % 3 + 1
	check_creep_tower_pressure_lane = laneToCheck
	-- TODO IMPROVE
	-- TODO INCLUDE ENEMY BUILDING PRESSURE FOR SAFE-BUT-DISTANT-PUSHING (OR FURION)
	-- Using the lowest-tier team defensible...
	
	local laneIsSieged = t_lane_is_sieged[laneToCheck]
	t_lane_is_sieged[laneToCheck] = false

	local buildingForNotice = GSI_GetLowestTierDefensible(TEAM, laneToCheck)
	local enemyCreeps = Set_GetEnemyCreepSetLaneFront(laneToCheck) or zero_creeps
	local alliedCreeps = Set_GetAlliedCreepSetLaneFront(laneToCheck) or zero_creeps
	
	--print("pre fix creep pressure", TEAM, laneToCheck, enemyCreeps==zero_creeps, alliedCreeps==zero_creeps, buildingForNotice.name)

	-- ..Check if creeps are in base and if they can determined to be pushing a structure..
	if not buildingForNotice.isTower or buildingForNotice.tier >=3 then
		local creepsInBase = Set_GetNearestEnemyCreepSetAtLaneLoc(
				buildingForNotice.lastSeen.location,
				TEAM_IS_RADIANT and MAP_LOGICAL_RADIANT_BASE or MAP_LOGICAL_DIRE_BASE
			)
		if not creepsInBase
				or Math_PointToPointDistance2D(
						creepsInBase.center,
						buildingForNotice.lastSeen.location)
					> CONSIDER_CREEPS_ON_BASE_BUILDING then
			if DEBUG and creepsInBase then DebugDrawLine(creepsInBase.center, buildingForNotice.lastSeen.location, 255, 0, 0) end
			return;
		end
		if creepsInBase then
			local cacheTower = Set_GetTowerOverLocation(creepsInBase.center)
			if cacheTower and cacheTower.tier > 3 then
				buildingForNotice = cacheTower
			end
		end
		enemyCreeps = creepsInBase
		--DebugDrawLine(creepsInBase.center, buildingForNotice.lastSeen.location, 0, 255, 0)
	end

	-- ..Determine pressure on structure of heroes and creeps..
	local numEnemyCreeps = #(enemyCreeps.units)
	local numAlliedCreeps = #(alliedCreeps.units)
	--print(TEAM, laneToCheck, numEnemyCreeps, numAlliedCreeps)
	local creepPressure = creep_pressure(nil, alliedCreeps.units, enemyCreeps.units) 

	local laneCrash = (enemyCreeps and enemyCreeps.center) or Set_GetPredictedLaneFrontLocation(laneToCheck)
	--print(laneCrash, enemyCreeps, enemyCreeps and enemyCreeps.center, Map_GetAncientOnRopesFightLocation(baseTeam))
	if not buildingForNotice then
		buildingForNotice = GSI_GetTeamAncient(TEAM)
	end
	local tierDistance = buildingForNotice.tier or 3

	local prevPressure = t_seen_creep_pressure[laneToCheck]
	t_seen_creep_pressure[laneToCheck] = math.min(2, math.max(0, prevPressure + (creepPressure > prevPressure and 0.05 or -0.05))) -- .1 / second

	local nearbyEnemyHeroes, outerEnemyHeroes = Set_GetEnemyHeroesInLocRadOuter(buildingForNotice.lastSeen.location, 700, 1600, 0)
	-- ..Check Glyph needed..
	if GetGlyphCooldown() == 0 then
		if DEBUG and enemyCreep and not enemyCreep.center then
			ERROR_print(false, not DEBUG, "lane_pressure.lua found an enemy creep set with units but no center")
			Util_TablePrint(enemyCreeps)
		end
		local hUnit = buildingForNotice.hUnit
		if (buildingForNotice.isTower or buildingForNotice.isAncient
				and hUnit and hUnit.IsNull and not hUnit:IsNull() and hUnit:IsAlive()
				) and (numEnemyCreeps > 0
						and (numEnemyCreeps + #nearbyEnemyHeroes*2 > USE_GLYPH_ENEMY_PRESENCE_AT_TOWER -- hero's scale to creep is low because hard to push without creeps
							and Math_PointToPointDistance2D(buildingForNotice.lastSeen.location, enemyCreeps.center) < 500
						) or (buildingForNotice.tier == 1
							and buildingForNotice.lastSeenHealth < USE_T1_GLYPH_FOR_HEALTH_AUTO
						)
				) then
			GetBot():ActionImmediate_Glyph()
		end
	end

	--print("blip test:", laneToCheck, laneCrash, creepPressure, buildingForNotice.lastSeen.location)
	--print(not buildingForNotice.typeIsNone, (tier_one_defend_allowed or buildingForNotice.tier ~= 1 or buildingForNotice.lastSeenHealth < 450), laneCrash, creepPressure >= 1.4, Math_PointToPointDistance2D(buildingForNotice.lastSeen.location, laneCrash))
	-- ..Check if defense poster is justified..
	local urgency = creepPressure
			+ (Analytics_GetFutureDamageInTimeline(buildingForNotice.hUnit)
				/ buildingForNotice.maxHealth) * 100
	if not buildingForNotice.typeIsNone
			and (tier_one_defend_allowed or buildingForNotice.tier ~= 1 or buildingForNotice.lastSeenHealth < 450)
			and laneCrash and urgency >= 2
			and Math_PointToPointDistance2D(buildingForNotice.lastSeen.location, laneCrash)
				< START_DEFENCE_THREAT_DIST_MULTIPLIER*tierDistance then
		--print('lane: ', laneToCheck, TEAM, baseTeam, laneCrash, buildingForNotice.name, buildingForNotice.lastSeen.location, enemyCreeps)
		--print(GSI_GetLowestTierTeamLaneTower(TEAM, laneToCheck), Set_GetNearestTeamBuildingToLoc(baseTeam, laneCrash))
		if buildingForNotice.team == TEAM then
			ZoneDefend_RegisterBuildingDefenceBlip(buildingForNotice, t_seen_creep_pressure[laneToCheck])
		else
			PushLane_RegisterHighPressureOption(buildingForNotice, t_seen_creep_pressure[laneToCheck])
		end
	elseif buildingForNotice.wp and creepPressure == 0 then
		ZoneDefend_RegisterBuildingDefenceSafe(buildingForNotice, t_seen_creep_pressure[laneToCheck])
	end
end

local function update_number_creeps_spawned__job()
	local middleSpawn = Set_GetNearestAlliedCreepSetToLocation(team_middle_spawn)
	local laneFront = Set_GetAlliedCreepSetLaneFrontStored(MAP_LOGICAL_MIDDLE_LANE)
	-- concern is enemy being in a weird place, agroing and keeping the previous creep spawn close to the spawner for the next wave
	if Math_PointToPointDistance2D(team_middle_spawn, laneFront.center) > 1500 and #middleSpawn > number_creeps_in_wave and #middleSpawn <= MAX_CREEP_SPAWN then
		number_creeps_in_wave = #middleSpawn
	end
end

function Analytics_CreateUpdateLanePressure()
	job_domain_analytics:RegisterJob(
			function(workingSet)
				if workingSet.throttle:allowed() then
					
					
					
					update_creep_tower_pressure__job()
				end
			end,
			{["throttle"] = Time_CreateThrottle(0.2)},
			"JOB_UPDATE_LANE_PRESSURE"
		)
	Analytics_CreateUpdateLanePressure = nil
end

function Analytics_CreateUpdateLaneBasicPower()
	team_middle_spawn = Map_TeamSpawnerLoc(TEAM, MAP_LOGICAL_MIDDLE_LANE)
	job_domain_analytics:RegisterJob(
			function(workingSet)
				if workingSet.throttle:allowed() then
					update_number_creeps_spawned__job()
				end
			end,
			{["throttle"] = Time_CreateModThrottle(30, 1)},
			"JOB_UPDATE_LANE_BASIC_POWER"
		)
	Analytics_CreateUpdateLanePressure = nil
end

function Analytics_RegisterAnalyticsJobDomainToLanePressure(analyticsJobDomain)
	job_domain_analytics = analyticsJobDomain

	t_enemy_players = GSI_GetTeamPlayers(ENEMY_TEAM)

	Analytics_RegisterAnalyticsJobDomainToLanePressure = nil
end
