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

CREEP_AGRO_RANGE = 600
local CREEP_PRESSURE_RANGE = 1.3*CREEP_AGRO_RANGE

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

local ALLOW_TIER_ONE_DEF_AVG_TEAM_LEVEL = 7
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

-- Returns safety in terms of player's power. This means if a safety rating is 1, then rejecting to attend a
-- 		lane will make the safety rating 0 (again, relative to your power level)
-- 	- - also returns laneHelpNeeded which is scaled to the importance of the player in the late-game, based on role
function Analytics_SafetyOfLaneFarm(gsiPlayer, lane, presentOrCommittedTbl)
	local timeData = gsiPlayer.time.data.safetyOfLane
	if timeData then
		if timeData[lane] then
			--[[DEV]]if tostring(timeData[lane]) == tostring(0/0) then
				--[[DEV]]DebugDrawText(900, 500, string.format("%s NAN NAN", gsiPlayer.shortName), 255, 0, 0)
			--[[DEV]]end
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
--[[DEV]]if VERBOSE then VEBUG_print(string.format("[lane_pressure] check is for lane %d's lanefront %s to enemy tower %.0f dist away",
--[[DEV]]				lane, tostring(laneFront), lowestTierDist
--[[DEV]]			)
--[[DEV]]		)
--[[DEV]]end
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
local function update_creep_tower_pressure__job()
	-- Enemy team pressure
	if not tier_one_defend_allowed then
		if Analytics_GetAverageTeamLevel(TEAM) >= ALLOW_TIER_ONE_DEF_AVG_TEAM_LEVEL then
			tier_one_defend_allowed = true
		end
	end
	for iLane=1,3 do -- TODO INCLUDE BASE PRESSURE -- JUST NEEDS SET REQUEST FOR BASE-WISE SET AND SPECIAL CHECK FOR WHICH BUILDING (MOST?) THREATENED
		-- TODO IMPROVE
		-- TODO INCLUDE ENEMY BUILDING PRESSURE FOR SAFE-BUT-DISTANT-PUSHING (OR FURION)
		-- Using the lowest-tier team defensible...
		local buildingForNotice = GSI_GetLowestTierDefensible(TEAM, iLane)
		local enemyCreeps = Set_GetEnemyCreepSetLaneFront(iLane) or zero_creeps
		local alliedCreeps = Set_GetAlliedCreepSetLaneFront(iLane) or zero_creeps
		
		--print("pre fix creep pressure", TEAM, iLane, enemyCreeps==zero_creeps, alliedCreeps==zero_creeps, buildingForNotice.name)

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
				goto NEXT_LANE;
			end
			enemyCreeps = creepsInBase
			--DebugDrawLine(creepsInBase.center, buildingForNotice.lastSeen.location, 0, 255, 0)
		end

		-- ..Determine pressure on structure of heroes and creeps..
		local numEnemyCreeps = #(enemyCreeps.units)
		local numAlliedCreeps = #(alliedCreeps.units)
		--print(TEAM, iLane, numEnemyCreeps, numAlliedCreeps)
		local creepPressure = creep_pressure(nil, alliedCreeps.units, enemyCreeps.units) 

		local laneCrash = (enemyCreeps and enemyCreeps.center) or Set_GetPredictedLaneFrontLocation(iLane)
		--print(laneCrash, enemyCreeps, enemyCreeps and enemyCreeps.center, Map_GetAncientOnRopesFightLocation(baseTeam))
		if not buildingForNotice then
			buildingForNotice = GSI_GetTeamAncient(TEAM)
		end
		local tierDistance = buildingForNotice.tier or 3

		local prevPressure = t_seen_creep_pressure[iLane]
		t_seen_creep_pressure[iLane] = math.min(2, math.max(0, prevPressure + (creepPressure > prevPressure and 0.1 or -0.1))) -- .1 / second

		-- ..Check Glyph needed..
		if GetGlyphCooldown() == 0 then
			local nearbyEnemyHeroes = Set_GetEnemyHeroesInLocRadOuter(buildingForNotice.lastSeen.location, 700, -1, 0)
			if DEBUG and enemyCreep and not enemyCreep.center then
				ERROR_print("lane_pressure.lua found an enemy creep set with units but no center")
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

		--print("blip test:", iLane, laneCrash, creepPressure, buildingForNotice.lastSeen.location)
		--print(not buildingForNotice.typeIsNone, (tier_one_defend_allowed or buildingForNotice.tier ~= 1 or buildingForNotice.lastSeenHealth < 450), laneCrash, creepPressure >= 1.4, Math_PointToPointDistance2D(buildingForNotice.lastSeen.location, laneCrash))
		-- ..Check if defense poster is justified..
		if not buildingForNotice.typeIsNone
				and (tier_one_defend_allowed or buildingForNotice.tier ~= 1 or buildingForNotice.lastSeenHealth < 450)
				and laneCrash and creepPressure >= 1.4
				and Math_PointToPointDistance2D(buildingForNotice.lastSeen.location, laneCrash)
					< START_DEFENCE_THREAT_DIST_MULTIPLIER*tierDistance then
			--print('lane: ', iLane, TEAM, baseTeam, laneCrash, buildingForNotice.name, buildingForNotice.lastSeen.location, enemyCreeps)
			--print(GSI_GetLowestTierTeamLaneTower(TEAM, iLane), Set_GetNearestTeamBuildingToLoc(baseTeam, laneCrash))
			if buildingForNotice.team == TEAM then
				ZoneDefend_RegisterBuildingDefenceBlip(buildingForNotice, t_seen_creep_pressure[iLane])
			else
				PushLane_RegisterHighPressureOption(buildingForNotice, t_seen_creep_pressure[iLane])
			end
		elseif buildingForNotice.wp and creepPressure == 0 then
			ZoneDefend_RegisterBuildingDefenceSafe(buildingForNotice, t_seen_creep_pressure[iLane])
		end
		::NEXT_LANE::
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
	Analytics_RegisterAnalyticsJobDomainToLanePressure = nil
end
