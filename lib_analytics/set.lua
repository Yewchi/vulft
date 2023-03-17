-- Deduces clusters of units on the map for certain types. Useful for fast imaginary scoring, positioning,
--- or also a quick search of a small subset of a unit type nearby.

SET_ALL =						UNIT_LIST_ALL -- almost definitely unused.
SET_ALL_ALLIED =				UNIT_LIST_ALLIES -- TODO Refactor these names or remove for UNIT_LIST
SET_HERO_ALLIED =				UNIT_LIST_ALLIED_HEROES
SET_CREEP_ALLIED =				UNIT_LIST_ALLIED_CREEPS
SET_CREEP_ALLIED_CONTROLLED = 	0xFF01
SET_WARD_ALLIED =				UNIT_LIST_ALLIED_WARDS
SET_BUILDING_ALLIED =			UNIT_LIST_ALLIED_BUILDINGS
SET_ALL_ENEMY =					UNIT_LIST_ENEMIES
SET_HERO_ENEMY =				UNIT_LIST_ENEMY_HEROES
SET_CREEP_ENEMY = 				UNIT_LIST_ENEMY_CREEPS
SET_CREEP_ENEMY_CONTROLLED = 	0xFF02
SET_WARD_ENEMY =				UNIT_LIST_ENEMY_WARDS
SET_CREEP_NEUTRAL =				UNIT_LIST_NEUTRAL_CREEPS
SET_BUILDING_ENEMY =			UNIT_LIST_ENEMY_BUILDINGS

SET_HERO = 				UNIT_TYPE_HERO

PLAYER_CONTROLED_UNIT_SETS_ALLIED = 	22
PLAYER_CONTROLLED_UNIT_SETS_ENEMY = 	23

ALLOWABLE_CREEP_SET_DIAMETER = 1000
CONSIDER_CRASHED_CREEP_SET_RANGE = ALLOWABLE_CREEP_SET_DIAMETER * 1.5 -- 250 unit overlap will link

-- SET_TYPE_TO_UNIT_LIST = {
		-- UNIT_LIST_ALLIED_CREEPS,
		-- UNIT_LIST_ENEMY_CREEPS,
		-- UNIT_LIST_NEUTRAL_CREEPS,
		-- UNIT_LIST_ALLIED_HEROES,
		-- UNIT_LIST_ENEMY_HEROES,
-- }

---- set indicies --
local lane_front_most_recent = {[MAP_LOGICAL_TOP_LANE]={}, [MAP_LOGICAL_MIDDLE_LANE]={}, [MAP_LOGICAL_BOTTOM_LANE]={}, [MAP_LOGICAL_RADIANT_BASE] = {}, [MAP_LOGICAL_DIRE_BASE] = {}}
local LANE_FRONT_I__ALLIED = 1
local LANE_FRONT_I__ENEMY = 2
local LANE_FRONT_I__LAST_SEEN_WAVE_CRASH_LOC = 3
local LANE_FRONT_I__PREDICTED_WAVE_CRASH_LOC = 4
local LANE_FRONT_I__PREDICTED_WAVE_CRASH_TIME = 5
--

---- set constants --
local NUM_SET_TYPES = 14

local CREEP_IS_NOT_CONTROLLED_PLAYER_ID = -1

local DEFAULT_NEARBY_LIMIT_DISTANCE = 2000

local THROTTLE_SET_ALL_UPDATE = DEBUG and not USER_HAS_NO_EPILEPSY_RISK_DEBUG_THROTTLES and 0.0 or 0.2 -- slow throttle (greater than 0.0) has epileptic risk
if DEBUG then
	if THROTTLE_SET_ALL_UPDATE < 0.2 then
		DEBUG_print("set: set updates are "..(THROTTLE_SET_ALL_UPDATE < 0.2 and "" or "not ").."fast.")
	end
end
local THROTTLE_UPDATE_LANE_FRONTS = DEBUG and not USER_HAS_NO_EPILEPSY_RISK_DEBUG_THROTTLES and 0.0 or 0.37 -- slow throttle (greater than 0.0) has epileptic risk

local SET_SCREEN_TRACKING = true and VERBOSE

local TEAM = TEAM
local ENEMY_TEAM = ENEMY_TEAM
local TEAM_NUMBER_OF_PLAYERS = TEAM_NUMBER_OF_PLAYERS
local Map_ExtrapolatedLaneFrontWhenDeadBasic = Map_ExtrapolatedLaneFrontWhenDeadBasic
local Map_GetLaneValueOfMapPoint = Map_GetLaneValueOfMapPoint
local Map_GetBaseOrLaneLocation = Map_GetBaseOrLaneLocation
local Math_PointToPointDistance2D = Math_PointToPointDistance2D
local Vector_SideOfPlane = Vector_SideOfPlane
local EMPTY_TABLE = EMPTY_TABLE
local ORTHOGONAL_Z = ORTHOGONAL_Z
local HIGH_32_BIT = HIGH_32_BIT

local RADIANT_FOUNTAIN_LOC = Map_GetLogicalLocation(MAP_POINT_RADIANT_FOUNTAIN_CENTER)
local DIRE_FOUNTAIN_LOC = Map_GetLogicalLocation(MAP_POINT_DIRE_FOUNTAIN_CENTER)
--
local team_lane_creep_spawner

local t_sets = {}
local all_towers = {} -- All towers i-index
local all_towers_packaged -- Is for uniform processing at higher levels
local fast_nasty_towers = {} -- TODO Implement A cascading i-index table of the towers that are not protected by the tower up the lane

local updated_towers_player = GetBot()
local updated_towers_frame_time = 0

local job_domain

-- N.B. center key may be used to check a set type

do
	for i=1,NUM_SET_TYPES,1 do
		t_sets[i] = {}
	end
	t_sets[SET_CREEP_ALLIED_CONTROLLED] = {}
	t_sets[SET_CREEP_ENEMY_CONTROLLED] = {}
end

local function has_creep_set_likely_died(prevLaneFrontLoc, currLaneFrontLoc)
	return not prevLaneFrontLoc or
			not currLaneFrontLoc or (
					math.abs(prevLaneFrontLoc.x - currLaneFrontLoc.x) > ALLOWABLE_CREEP_SET_DIAMETER
						or math.abs(prevLaneFrontLoc.y - currLaneFrontLoc.y) > ALLOWABLE_CREEP_SET_DIAMETER
				)
end

local distGreatestForLane = {}
local function reset_dist_max() for i=1,3,1 do distGreatestForLane[i] = 0 end distGreatestForLane[4] = 0xFFFF distGreatestForLane[5] = 0xFFFF end
local function lane_indexed_set_if_lesser(team, dist, tblOfLesser, set)
	local lane = set.lane
	local dist = Math_PointToPointDistance2D(
			set.center,
			lane == MAP_LOGICAL_RADIANT_BASE and RADIANT_FOUNTAIN_LOC or DIRE_FOUNTAIN_LOC
		)
	if dist < distGreatestForLane[lane] then
		distGreatestForLane[lane] = dist
		tblOfLesser[lane] = set
	end
end

local function lane_indexed_set_if_greater(team, dist, tblOfGreatest, set)
	local lane = set.lane
	if lane >= 4 then lane_indexed_set_if_lesser(team, dist, tblOfGreatest, set) return end
	local dist = Math_PointToPointDistance2D(set.center, team_lane_creep_spawner[team][lane])
	if dist > distGreatestForLane[lane] then
		distGreatestForLane[lane] = dist
		tblOfGreatest[lane] = set
	end
end

-------------- update_lane_fronts()
local function update_lane_fronts()
	local tCreepSetsAllied = t_sets[SET_CREEP_ALLIED]
	local alliedFronts = {}
	reset_dist_max()
	if tCreepSetsAllied then
		for s=1,#tCreepSetsAllied,1 do
			lane_indexed_set_if_greater(TEAM, dist, alliedFronts, tCreepSetsAllied[s])
		end
	end
	local tCreepSetsEnemy = t_sets[SET_CREEP_ENEMY]
	local enemyFronts = {}
	reset_dist_max()
	if tCreepSetsEnemy then
		for s=1,#tCreepSetsEnemy,1 do
			lane_indexed_set_if_greater(ENEMY_TEAM, dist, enemyFronts, tCreepSetsEnemy[s])
		end
	end
	for iLane=1,3,1 do
		local thisLaneFrontLocations = lane_front_most_recent[iLane]
--[VERBOSE]]if VERBOSE and alliedFronts[iLane] then DebugDrawCircle(alliedFronts[iLane].center, 1000, TEAM == TEAM_RADIANT and 0 or 25, TEAM == TEAM_RADIANT and 25 or 0, 0) end
--[VERBOSE]]if VERBOSE and enemyFronts[iLane] then DebugDrawCircle(enemyFronts[iLane].center, 1000, 15, 15, 90) end
		if alliedFronts[iLane] and enemyFronts[iLane] then 
			if #(alliedFronts[iLane].units)*4 < #(enemyFronts[iLane].units) then 
				alliedFronts[iLane] = nil  -- Run from our creeps if they're being swarmed
			elseif Math_PointToPointDistance2D(alliedFronts[iLane].center, enemyFronts[iLane].center) < CONSIDER_CRASHED_CREEP_SET_RANGE then
			-- The wave is crashed
				thisLaneFrontLocations[LANE_FRONT_I__LAST_SEEN_WAVE_CRASH_LOC] = Vector_PointBetweenPoints(alliedFronts[iLane].center, enemyFronts[iLane].center)
				thisLaneFrontLocations[LANE_FRONT_I__PREDICTED_WAVE_CRASH_LOC] = nil
				goto NEXT_LANE
			end
		end
		do
			-- The wave is seperated
			local theoreticalAlliedFrontLoc = alliedFronts[iLane] and alliedFronts[iLane].center
					or GetGameState() == GAME_STATE_PRE_GAME
							and GSI_GetTeamLaneTierTower(TEAM, iLane, 2).lastSeen.location
					or Map_ExtrapolatedLaneFrontWhenDeadBasic(
							TEAM, iLane, thisLaneFrontLocations[LANE_FRONT_I__LAST_SEEN_WAVE_CRASH_LOC]
						)
			local theoreticalEnemyFrontLoc = enemyFronts[iLane] and enemyFronts[iLane].center
					or Map_ExtrapolatedLaneFrontWhenDeadBasic(
							ENEMY_TEAM, iLane, theoreticalAlliedFrontLoc
						)

			if DEBUG then
				DebugDrawCircle(theoreticalEnemyFrontLoc, 80, 125, 125, 125)
			end
			if VERBOSE then
				DebugDrawText(
						TEAM == TEAM_RADIANT and 50 or 900, 650+15*iLane, 
						string.format("%d backup %s, %s, (%d, %d, %d), (%d, %d, %d), (%d, %d, %d), (%d, %d, %d)", 
						iLane,
						string.sub(Util_Printable(alliedFronts[1]), 1, 20), 
						string.sub(tostring(enemyFronts[1]), 1, 20), 
						theoreticalAlliedFrontLoc.x, theoreticalAlliedFrontLoc.y, theoreticalAlliedFrontLoc.z,
						theoreticalEnemyFrontLoc.x, theoreticalEnemyFrontLoc.y, theoreticalEnemyFrontLoc.z,
						thisLaneFrontLocations[LANE_FRONT_I__LAST_SEEN_WAVE_CRASH_LOC].x or -1,
						thisLaneFrontLocations[LANE_FRONT_I__LAST_SEEN_WAVE_CRASH_LOC].y or -1,
						thisLaneFrontLocations[LANE_FRONT_I__LAST_SEEN_WAVE_CRASH_LOC].z or -1,
						thisLaneFrontLocations[LANE_FRONT_I__PREDICTED_WAVE_CRASH_LOC]
								and thisLaneFrontLocations[LANE_FRONT_I__PREDICTED_WAVE_CRASH_LOC].x or -1,
						thisLaneFrontLocations[LANE_FRONT_I__PREDICTED_WAVE_CRASH_LOC]
								and thisLaneFrontLocations[LANE_FRONT_I__PREDICTED_WAVE_CRASH_LOC].y or -1,
						thisLaneFrontLocations[LANE_FRONT_I__PREDICTED_WAVE_CRASH_LOC]
								and thisLaneFrontLocations[LANE_FRONT_I__PREDICTED_WAVE_CRASH_LOC].z or -1
						), 
						255, 255, 255
					)
			end

			if not enemyFronts[iLane] or not alliedFronts[iLane]
					or has_creep_set_likely_died(
							thisLaneFrontLocations[LANE_FRONT_I__LAST_SEEN_WAVE_CRASH_LOC],
							theoreticalAlliedFrontLoc
						)
					or has_creep_set_likely_died(
							thisLaneFrontLocations[LANE_FRONT_I__LAST_SEEN_WAVE_CRASH_LOC],
							enemyFronts[iLane].center
					) then
				thisLaneFrontLocations[LANE_FRONT_I__PREDICTED_WAVE_CRASH_LOC],
				thisLaneFrontLocations[LANE_FRONT_I__PREDICTED_WAVE_CRASH_TIME] = Map_LaneHalfwayPoint(
						iLane, theoreticalAlliedFrontLoc, theoreticalEnemyFrontLoc
					)
			end
			--[DEBUG]]print(thisLaneFrontLocations[LANE_FRONT_I__PREDICTED_WAVE_CRASH_LOC], thisLaneFrontLocations[LANE_FRONT_I__PREDICTED_WAVE_CRASH_TIME])
			if not thisLaneFrontLocations[LANE_FRONT_I__PREDICTED_WAVE_CRASH_LOC] then -- backup can't determine (happens?) set predicted location to natural meet
				print("/VUL-FT/ <ARN> Lane wave crash prediction using natural meet location")
				thisLaneFrontLocations[LANE_FRONT_I__PREDICTED_WAVE_CRASH_LOC] = Map_LaneLogicalToNaturalMeet(iLane)
				thisLaneFrontLocations[LANE_FRONT_I__PREDICTED_WAVE_CRASH_TIME] = DotaTime() - (30 - (DotaTime() % 30)) -- TODO Remove? This answer is wrong and I'm not sure what I intended the value for.
			end
	--[VERBOSE]]if VERBOSE and thisLaneFrontLocations[LANE_FRONT_I__PREDICTED_WAVE_CRASH_LOC] then DebugDrawCircle(thisLaneFrontLocations[LANE_FRONT_I__PREDICTED_WAVE_CRASH_LOC], 300, TEAM == TEAM_RADIANT and 0 or 30, TEAM == TEAM_RADIANT and 30 or 0, 70) end
		end
		::NEXT_LANE::
		thisLaneFrontLocations[LANE_FRONT_I__ALLIED] = alliedFronts[iLane] -- N.B. Previous values before the update on this line may be implied above
		thisLaneFrontLocations[LANE_FRONT_I__ENEMY] = enemyFronts[iLane]
	end
	for iLane=4,5 do
		local newCrashPrediction = enemyFronts[iLane] and enemyFronts[iLane].center
		lane_front_most_recent[iLane][LANE_FRONT_I__ALLIED] = alliedFronts[iLane]
		lane_front_most_recent[iLane][LANE_FRONT_I__ENEMY] = enemyFronts[iLane]
		lane_front_most_recent[iLane][LANE_FRONT_I__LAST_SEEN_WAVE_CRASH_LOC] = newCrashPrediction or lane_front_most_recent[iLane][LANE_FRONT_I__LAST_SEEN_WAVE_CRASH_LOC]
		lane_front_most_recent[iLane][LANE_FRONT_I__PREDICTED_WAVE_CRASH_LOC] = newCrashPrediction or lane_front_most_recent[iLane][LANE_FRONT_I__PREDICTED_WAVE_CRASH_LOC]
		lane_front_most_recent[iLane][LANE_FRONT_I__PREDICTED_WAVE_CRASH_TIME] = GameTime()
	end
end

local function update_creep_set_type(creepSetType)
	local sameReactPlayerCreepSetType
	if creepSetType == SET_CREEP_ALLIED then
		sameReactPlayerCreepSetType = SET_CREEP_ALLIED_CONTROLLED
		if t_sets[sameReactPlayerCreepSetType][1] then
			t_sets[sameReactPlayerCreepSetType] = {}
		end
	elseif creepSetType == SET_CREEP_ENEMY then
		sameReactPlayerCreepSetType = SET_CREEP_ENEMY_CONTROLLED
		if t_sets[sameReactPlayerCreepSetType][1] then
			t_sets[sameReactPlayerCreepSetType] = {}
		end
	else
		sameReactPlayerCreepSetType = -1
	end
	
	t_sets[creepSetType] = {} -- N.B. a lightweight operation. The freshly unreferenced tables are the data about the sets (or 'metadata' of each set), SafeUnits are flipped out of creep.lua if already existing. The 'metadata' proper (total, center=Vector, etc) may be larger than the table of units[i] = SafeUnitRefs (which are indexed in creep.lua)
	
	local tCreepList = cUnit_ConvertListToSafeUnits(GetUnitList(creepSetType))

	local tCreepSets = t_sets[creepSetType]
	for i=1,#tCreepList,1 do
		local thisCreep = tCreepList[i]
		if cUnit_IsNullOrDead(thisCreep) then print("WTF") Util_TablePrint(thisCreep) end
		local thisCreepLoc = thisCreep.lastSeen.location
		local thisCreepPlayerID = thisCreep.hUnit.GetPlayerID and thisCreep.hUnit:GetPlayerID() or CREEP_IS_NOT_CONTROLLED_PLAYER_ID
--[[DEBUG]]if DEBUG and creepSetType == SET_CREEP_ALLIED then DEBUG_DrawCreepData(thisCreep) end
		if thisCreepPlayerID ~= CREEP_IS_NOT_CONTROLLED_PLAYER_ID then -- Add the player controlled unit
			table.insert(t_sets[sameReactPlayerCreepSetType], thisCreep)
			if creepSetType == SET_CREEP_ALLIED then
				pUnit_CreateDominatedUnit(thisCreepPlayerID, thisCreep)
			end
		else -- Add the lane creep to it's proximity set
			local s = 1
			while(s <= #tCreepSets) do
				local thisCreepSet = tCreepSets[s]
				if Math_PointToPointDistance2D(thisCreepLoc, thisCreepSet.center) < ALLOWABLE_CREEP_SET_DIAMETER then
					local thisX, thisY = thisCreepSet.center.x, thisCreepSet.center.y
					thisCreep.ofUnitSet = thisCreepSet
					table.insert(thisCreepSet.units, thisCreep)
					thisCreepSet.total = thisCreepSet.total + 1
					thisCreepSet.center.x = thisX + (thisCreepLoc.x - thisX)/thisCreepSet.total -- Adjusts to the new center x
					thisCreepSet.center.y = thisY + (thisCreepLoc.y - thisY)/thisCreepSet.total -- ...and y
					break
				end
				s = s + 1
			end
			
			if s >= #tCreepSets+1 then -- Did the creep not go to an existing set? Create new set
				-- Initialize a new set with it's first creep
				thisCreep.ofUnitSet = {total=1, center=Vector(thisCreepLoc.x, thisCreepLoc.y, thisCreepLoc.z), lane=Map_GetBaseOrLaneLocation(thisCreepLoc), units={thisCreep}}
				table.insert(tCreepSets, thisCreep.ofUnitSet)
			end
		end
	end
	-- if creepSetType == SET_CREEP_ALLIED then -- N.B. set logic-breaking hack
		-- for i=#tCreepSets,1,-1 do
			-- if tCreepSets[i].total == 1 then
				-- table.remove(tCreepSets, i) -- Abandon the final creep of a wave, so we don't get swamped off a stun / slow
			-- end
		-- end
	-- end
end

local function update_enemy_buildings()
	local tBuildingListEnemy = bUnit_ConvertListToSafeUnits(GetUnitList(SET_BUILDING_ENEMY))
	t_sets[SET_BUILDING_ENEMY] = {units={}, towers={}}
	for i=1,#tBuildingListEnemy,1 do
		local gsiThisBuilding = tBuildingListEnemy[i]
		table.insert(t_sets[SET_BUILDING_ENEMY].units, gsiThisBuilding)
		if gsiThisBuilding.isTower then
			table.insert(t_sets[SET_BUILDING_ENEMY].towers, gsiThisBuilding)
			table.insert(all_towers, gsiThisBuilding)
		end
	end
end

local function update_all_sets__job(workingSet)
	if workingSet.throttleEnemy:allowed() then
		if workingSet.throttleAllied:allowed() then
			update_creep_set_type(SET_CREEP_ALLIED)
		end
		update_creep_set_type(SET_CREEP_ENEMY)
		if workingSet.throttleUpdateLaneFronts:allowed() then
			update_lane_fronts()
		end
	end
end

local function DEBUG_update_all_sets__job(workingSet)
	local tCreepSetsEnemy = t_sets[SET_CREEP_ENEMY]
	for i=1,#tCreepSetsEnemy,1 do
		local x, y = Math_ScreenCoordsToCartesianCentered(tCreepSetsEnemy[i].center.x, -tCreepSetsEnemy[i].center.y*0.75, MAP_COORDS_TO_MINIMAP_SCALE)
		x = x - 850
		y = y + 200
		local redC = TEAM==TEAM_DIRE and 30 or 255
		local greenC = TEAM==TEAM_RADIANT and 30 or 255
		-- DebugDrawCircle(tCreepSetsEnemy[i].center, 50, redC, greenC, 30)
		-- DebugDrawText(x, y, tCreepSetsEnemy[i].lane == 1 and "T" or tCreepSetsEnemy[i].lane == 2 and "M" or "B", redC, greenC, 30)
		-- DebugDrawText(x, y+20, string.format("%d", Set_GetLowestCreepHealthInSetPercent(tCreepSetsEnemy[i]) * 100), redC, greenC, 30)
	end
	update_enemy_buildings()
	update_all_sets__job(workingSet)
end

function Set_Initialize()
	-- Create building sets (has module structural importance, not because towers need to be assorted)
	local tBuildingListAllied = bUnit_ConvertListToSafeUnits(GetUnitList(SET_BUILDING_ALLIED))
	t_sets[SET_BUILDING_ALLIED] = {units={}, towers={}}
	for i=1,#tBuildingListAllied,1 do
		local gsiThisBuilding = tBuildingListAllied[i]
		table.insert(t_sets[SET_BUILDING_ALLIED].units, gsiThisBuilding)
		if string.find(gsiThisBuilding.name, "tower") then
			table.insert(t_sets[SET_BUILDING_ALLIED].towers, gsiThisBuilding)
			table.insert(all_towers, gsiThisBuilding)
			Map_ReportTowerLocation(gsiThisBuilding.name, gsiThisBuilding.lastSeen.location)
		end
	end
	local tBuildingListEnemy = bUnit_ConvertListToSafeUnits(GetUnitList(SET_BUILDING_ENEMY))
	t_sets[SET_BUILDING_ENEMY] = {units={}, towers={}}
	for i=1,#tBuildingListEnemy,1 do
		local gsiThisBuilding = tBuildingListEnemy[i]
		table.insert(t_sets[SET_BUILDING_ENEMY].units, gsiThisBuilding)
		if string.find(gsiThisBuilding.name, "tower") then
			table.insert(t_sets[SET_BUILDING_ENEMY].towers, gsiThisBuilding)
			table.insert(all_towers, gsiThisBuilding)
			Map_ReportTowerLocation(gsiThisBuilding.name, gsiThisBuilding.lastSeen.location)
		end
	end
	job_domain:RegisterJob(
			function(workingSet) if workingSet.throttle:allowed() then update_enemy_buildings() end end, -- N.B. This is a data-consistency failsafe, not our dead-tower detection proper.
			{["throttle"] = Time_CreateThrottle(5.03)},
			"JOB_BUILDING_SAFETY_UPDATE"
		)
	
	all_towers_packaged = {units=all_towers}
	
	-- Get fast index creep spawners
	team_lane_creep_spawner = {}
	for t=TEAM_RADIANT,TEAM_DIRE,1 do
		team_lane_creep_spawner[t] = {}
		for lane=1,5,1 do -- including enemies-in-base fountain spawner (lane 4 and 5 are radiant and dire bases, a creep location with no lane)
			team_lane_creep_spawner[t][lane] = Map_TeamSpawnerLoc(t, lane)
		end
	end
	
	-- Placeholder data to the previous and imaginary lane creep locations -- Or zero vector if the tower is dead (probably a script reload)
	-- lane_front_most_recent[MAP_LOGICAL_TOP_LANE][LANE_FRONT_I__ALLIED] = {center=Map_GetLogicalLocation(Map_GetMapPointIndexForTower(TEAM, 1, MAP_LOGICAL_TOP_LANE)) or Map_GetAncientOnRopesFightLocation(TEAM)}
	-- lane_front_most_recent[MAP_LOGICAL_MIDDLE_LANE][LANE_FRONT_I__ALLIED] = {center=Map_GetLogicalLocation(Map_GetMapPointIndexForTower(TEAM, 1, MAP_LOGICAL_MIDDLE_LANE)) or Map_GetAncientOnRopesFightLocation(TEAM)}
	-- lane_front_most_recent[MAP_LOGICAL_BOTTOM_LANE][LANE_FRONT_I__ALLIED] = {center=Map_GetLogicalLocation(Map_GetMapPointIndexForTower(TEAM, 1, MAP_LOGICAL_BOTTOM_LANE)) or Map_GetAncientOnRopesFightLocation(TEAM)}
	-- lane_front_most_recent[MAP_LOGICAL_TOP_LANE][LANE_FRONT_I__ENEMY] = {center=Map_GetLogicalLocation(Map_GetMapPointIndexForTower(TEAM, 1, MAP_LOGICAL_TOP_LANE)) or Map_GetAncientOnRopesFightLocation(TEAM)}
	-- lane_front_most_recent[MAP_LOGICAL_MIDDLE_LANE][LANE_FRONT_I__ENEMY] = {center=Map_GetLogicalLocation(Map_GetMapPointIndexForTower(TEAM, 1, MAP_LOGICAL_MIDDLE_LANE)) or Map_GetAncientOnRopesFightLocation(TEAM)}
	-- lane_front_most_recent[MAP_LOGICAL_BOTTOM_LANE][LANE_FRONT_I__ENEMY] = {center=Map_GetLogicalLocation(Map_GetMapPointIndexForTower(TEAM, 1, MAP_LOGICAL_BOTTOM_LANE)) or Map_GetAncientOnRopesFightLocation(TEAM)}
	
	lane_front_most_recent[MAP_LOGICAL_TOP_LANE][LANE_FRONT_I__LAST_SEEN_WAVE_CRASH_LOC] = Map_GetLogicalLocation(Map_GetMapPointIndexForTower(ENEMY_TEAM, 1, MAP_LOGICAL_TOP_LANE)) or Map_GetAncientOnRopesFightLocation(TEAM)
	lane_front_most_recent[MAP_LOGICAL_MIDDLE_LANE][LANE_FRONT_I__LAST_SEEN_WAVE_CRASH_LOC] = Map_GetAncientOnRopesFightLocation(TEAM)
	lane_front_most_recent[MAP_LOGICAL_BOTTOM_LANE][LANE_FRONT_I__LAST_SEEN_WAVE_CRASH_LOC] = Map_GetLogicalLocation(Map_GetMapPointIndexForTower(ENEMY_TEAM, 1, MAP_LOGICAL_BOTTOM_LANE)) or Map_GetAncientOnRopesFightLocation(TEAM)
	lane_front_most_recent[MAP_LOGICAL_RADIANT_BASE][LANE_FRONT_I__LAST_SEEN_WAVE_CRASH_LOC] = RADIANT_FOUNTAIN_LOC
	lane_front_most_recent[MAP_LOGICAL_DIRE_BASE][LANE_FRONT_I__LAST_SEEN_WAVE_CRASH_LOC] = DIRE_FOUNTAIN_LOC
	
	-- if DEBUG then for i=1,3,1 do if not lane_front_most_recent[i][LANE_FRONT_I__LAST_SEEN_WAVE_CRASH_LOC] then print("Invalid lane set at", i, TEAM_READABLE, Map_GetMapPointIndexForTower(ENEMY_TEAM, 1, i)) end end end

	-- TowersNearAllies platter
	updated_towers_player = GSI_GetBot()
	updated_towers_frame_time = 0
	
	Set_Initialize = nil
end

-- Don't know how to improve the tracking of these computationally (and yet to be a problem), after a short investigation to find consistant identifiers for enemy units.
-- Currently entirely recreates each set whenever it is ran.
-- Currently has no consideration for units a few notches away from a set which is not thoroughly centered
-- No such thing as straglers for lane determination, it's not top, not bot -> mid. Based on first creep in set.
-- Profiling shows ~0.122ms run-time, although I believe that is a unit time-block (it will occassionally show 0.244ms run time)
function Set_UpdateAllSets()
	update_creep_set_type(SET_CREEP_ALLIED)
	update_creep_set_type(SET_CREEP_ENEMY)
	update_enemy_buildings()
	update_lane_fronts()
end

function Set_UpdateAlliedCreepSets()
	t_sets[CREEP_SET_ALLIED] = {}
	update_creep_set_type(SET_CREEP_ALLIED)
end

function Set_UpdateEnemyCreepSets()
	t_sets[CREEP_SET_ALLIED] = {}
	update_creep_set_type(SET_CREEP_ENEMY)
end

function Set_UpdateAlliedHeroSets() -- TODO IMPLEMENT
	t_sets[HERO_SET_ENEMY] = {}
	update_hero_set_type(SET_HERO_ENEMY)
end

function Set_UpdateEnemyHeroSets() -- TODO IMPLEMENT
	t_sets[HERO_SET_ENEMY] = {}
	update_hero_set_type(SET_HERO_ENEMY)
end

function Set_UpdateEnemyBuildingSets() -- TODO IMPLEMENT

end

function Set_UpdateAlliedBuldingSets() -- TODO IMPLEMENT

end

function Set_NumericalIndexUnion(s1, s2) -- Destructive to s1 SetUnion
	local s1Size = #s1
	if s1Size == 0 then
		if #s2 > 0 then
			return s2
		end
		return EMPTY_TABLE
	else
		if #s2 > 0 then
			for offset,v in ipairs(s2) do
				s1[s1Size+offset] = v
			end
			return s1
		end
		return s1
	end
end

function Set_GetSetUnitNearestToLocation(loc, set)
	local units = set.units or set
	local nearestUnit
	local nearestDist = 0xFFFF
	for i=1,#units do
		local dist = Math_PointToPointDistance2D(loc, units[i].lastSeen.location)
		if dist < nearestDist then
			nearestUnit = units[i]
			nearestDist = dist
		end
	end
	return nearestUnit, nearestDist
end

function Set_GetSetUnitFarthestToLocation(loc, set)
	local units = set.units or set
	local farthestUnit
	local farthestDist = 0
	for i=1,#units do
		local dist = Math_PointToPointDistance2D(loc, units[i].lastSeen.location)
		if dist > farthestDist then
			farthestUnit = units[i]
			farthestDist = dist
		end
	end
	return farthestUnit, farthestDist
end

function Set_GetCrowdedRatingToSetTypeAtLocation(location, setType, checkSet, maxRange)
	-- Units may be randomly excluded via the maxRange based on the order of the
	-- -| checkSet table. As such, this should only be used when ensuring all
	-- -| possible units are included in an AoE cast that prioritizes a
	-- -| specific unit (like the FHT), or that *self* is far enough away from
	-- -| allies, etc.  However, it is good enough and as fast as possible.
	local list = checkSet or GetUnitList(setType)
	local maxRange = maxRange or 1400
	local crowdingRating = 0
	local crowdingCenter = Vector(location.x, location.y, 0)
	local thisBot = GetBot()
	if list then
		local totalCrowdingUnits = 1
		for i=1,#list,1 do
			if thisBot ~= list[i] then
				local thisLocationOfCrowding = list[i].lastSeen and list[i].lastSeen.location
						or list[i]:GetLocation() 
				local dist = Math_PointToPointDistance2D(location, thisLocationOfCrowding)
				if dist < maxRange then
					totalCrowdingUnits = totalCrowdingUnits + 1
					crowdingRating = crowdingRating + (maxRange - dist) / maxRange
					crowdingCenter.x = crowdingCenter.x
							+ (thisLocationOfCrowding.x - crowdingCenter.x) / totalCrowdingUnits
					crowdingCenter.y = crowdingCenter.y
							+ (thisLocationOfCrowding.y - crowdingCenter.y) / totalCrowdingUnits
				end
			end
		end
	end
	return crowdingCenter, crowdingRating
end

function Set_GetCenterOfSetUnits(set)
	if set and set[1] then
		local crowdingCenter = set[1].lastSeen and set[1].lastSeen.location
				or set[1]:GetLocation() 
		-- <LINE OF DEATH>
		crowdingCenter = Vector(crowdingCenter.x, crowdingCenter.y, crowdingCenter.z)
		-- </LINE OF DEATH>
		local totalCrowdingUnits = 1
		for i=2,#set,1 do
			local thisLocationOfCrowding = set[i].lastSeen and set[i].lastSeen.location
					or set[i]:GetLocation() 
			totalCrowdingUnits = totalCrowdingUnits + 1
			crowdingCenter.x = crowdingCenter.x
					+ (thisLocationOfCrowding.x - crowdingCenter.x) / totalCrowdingUnits
			crowdingCenter.y = crowdingCenter.y
					+ (thisLocationOfCrowding.y - crowdingCenter.y) / totalCrowdingUnits
		end
		return crowdingCenter
	end
	return false
end

local recycle_empty, recycle_empty2
-- Put creeps in s1 for early bail
function Set_GetEnemiesInRectangle(baseLoc, topLoc, delta, s1, s2, bailIfCreep) -- e.g. #units == 1 and units[1] == myTarget .'. mirana arrow shot looks clear of creeps
--	delta is the half-diameter of the rectangle
	local units = recycle_empty or {}
	local directional = Vector_PointToPointLine(baseLoc, topLoc)
	local unitNormal = Vector_ToDirectionalUnitVector(Vector_CrossProduct(directional, ORTHOGONAL_Z))
	local leftP1 = Vector(baseLoc.x+(-delta*unitNormal.x), baseLoc.y+(-delta*unitNormal.y), 0)
	local leftP2 = Vector(leftP1.x+directional.x, leftP1.y+directional.y, 0)
	local rightP1 = Vector(baseLoc.x+delta*unitNormal.x, baseLoc.y+delta*unitNormal.y, 0)
	local rightP2 = Vector(rightP1.x+directional.x, rightP1.y+directional.y, 0)









	local s1Units = s1 and (s1.units or (s1[1] and s1) or (s1.shortName and {s1}))
	local s2Units = s2 and (s2.units or (s2[1] and s2) or (s1.shortName and {s2}))
	if s1Units then
		for i=1,#s1Units do
			local unitLoc = s1Units[i].lastSeen.location
			-- Counter clock-wise (postive) encased
			if Vector_SideOfPlane(unitLoc, leftP1, rightP1) > 0
					and Vector_SideOfPlane(unitLoc, rightP1, rightP2) > 0
					and Vector_SideOfPlane(unitLoc, rightP2, leftP2) > 0
					and Vector_SideOfPlane(unitLoc, leftP2, leftP1) > 0 then
				table.insert(units, s1Units[i])
				-- DebugDrawCircle(unitLoc, 60, 0, 0, 255)
				if bailIfCreep and s1Units[i].type == UNIT_TYPE_CREEP then
					goto RETURN
				end
			else
				DebugDrawCircle(unitLoc, 15, 255, 0, 0)
			end
		end
	end
	if s2Units then
		for i=1,#s2Units do
			local unitLoc = s2Units[i].lastSeen.location
			-- Clock-wise encased
			if Vector_SideOfPlane(unitLoc, leftP1, rightP1) > 0
					and Vector_SideOfPlane(unitLoc, rightP1, rightP2) > 0
					and Vector_SideOfPlane(unitLoc, rightP2, leftP2) > 0
					and Vector_SideOfPlane(unitLoc, leftP2, leftP1) > 0 then
				table.insert(units, s2Units[i])
			end
		end
	end
	::RETURN::
	if units[1] then
		recycle_empty = {}
		return units
	end
	return EMPTY_TABLE
end

function Set_GetUnitsInRadiusCircle(location, radius, s1, s2, bailIfCreep) -- e.g. #units == 1 and units[1] == myTarget .'. mirana arrow shot looks clear of creeps
	local units = recycle_empty or {}

	--DebugDrawCircle(location, radius, 10, 25, 21)

	if s1 and s1.units then
		local s1Units = s1.units
		for i=1,#s1Units do
			local unitLoc = s1Units[i].lastSeen.location
			--print("Checking unit with distance", Math_PointToPointDistance2D(location, unitLoc))
			if Math_PointToPointDistance2D(location, unitLoc) < radius then
				table.insert(units, s1Units[i])
				-- DebugDrawCircle(unitLoc, 60, 0, 0, 255)
				if bailIfCreep and s1Units[i].type == UNIT_TYPE_CREEP then
					goto RETURN
				end
			end
		end
	end
	if s2 then
		local s2Units = s2.units
		for i=1,#s2Units do
			local unitLoc = units[i].lastSeen.location
			if Math_PointToPointDistance2D(location, unitLoc) < radius then
				table.insert(units, s1Units[i])
				-- DebugDrawCircle(unitLoc, 60, 0, 0, 255)
			end
		end
	end
	::RETURN::
	if units[1] then
		recycle_empty = {}
		return units
	end
	return EMPTY_TABLE
end

function Set_GetTowers() 
	return all_towers_packaged
end

local function get_nearest_tower_to_location(set, loc, notShrine)
	local closestDistance = HIGH_32_BIT
	local closestTower
	if set then
		for i=1,#set,1 do
			local thisBuilding = set[i]
			if not notShrine or not thisBuilding.isShrine then
				local dist = Math_PointToPointDistance2D(thisBuilding.lastSeen.location, loc)
				if dist < closestDistance then
					closestDistance = dist
					closestTower = thisBuilding
				end
			end
		end
	end
	return closestTower, closestDistance
end

function Set_GetSaferLaneObject(setOrUnit, minimumDistance)
	local location = setOrUnit.center or location.lastSeen.location
	local minimumDistance = minimumDistance or 500
	local creepSets = t_sets[SET_CREEP_ALLIED]
	local topRightness = location.x + location.y
	local closestDist = 0xFFFF
	local closestObject
	for i=1,#creepSets do
		local thisCreepSet = creepSets[i]
		local thisCreepSetLoc = thisCreepSet.center
		local thisDist = Vector_PointDistance2D(location, thisCreepSetLoc)
		if thisDist > minimumDistance
				and thisDist < closestDist
				and (TEAM_IS_RADIANT and thisCreepSetLoc.x + thisCreepSetLoc.y < topRightness
						or thisCreepSetLoc.x + thisCreepSetLoc.y > topRightness
				) then
			closestDist = thisDist
			closestObject = thisCreepSet
		end
	end
	local towerUnits = t_sets[SET_BUILDING_ALLIED].towers
	for i=1,#towerUnits do
		local thisTower = towerUnits[i]
		local thisTowerLoc = thisTower.lastSeen.location
		local thisDist = Vector_PointDistance2D(location, thisTowerLoc)
		if thisDist > minimumDistance
				and thisDist < closestDist
				and (TEAM_IS_RADIANT and thisTowerLoc.x + thisTowerLoc.y < topRightness
						or thisTowerLoc.x + thisTowerLoc.y > topRightness
				) then
			closestDist = thisDist
			closestObject = thisTower
		end
	end
	if closestObject then
		return closestObject, closestDist
	end
	local fountain = GSI_GetTeamFountainUnit(TEAM)
	return fountain, Vector_PointDistance2D(location, fountain)
end

-- k-d tree, or something more simplistic?. tower-quadrant cache.
function Set_GetNearestTeamBuildingToLoc(team, loc, notShrine)
	return get_nearest_tower_to_location(t_sets[team == TEAM and SET_BUILDING_ALLIED or SET_BUILDING_ENEMY].units, loc, notShrine)
end

function Set_InformBuildingFell(gsiBuilding)
	local setSearched = gsiBuilding.team == TEAM
			and t_sets[SET_BUILDING_ALLIED].towers or t_sets[SET_BUILDING_ENEMY].towers
	for iKey,tableRef in pairs(setSearched) do
		if gsiBuilding == tableRef then
			table.remove(setSearched, iKey)
			break;
		end
	end
	local setSearched = gsiBuilding.team == TEAM
			and t_sets[SET_BUILDING_ALLIED].units or t_sets[SET_BUILDING_ENEMY].units
	for iKey,tableRef in pairs(setSearched) do
		if gsiBuilding == tableRef then
			table.remove(setSearched, iKey)
			break;
		end
	end
end

function Set_GetNearestTeamTowerToPlayer(team, gsiPlayer)
	local timeData = gsiPlayer.time.data
	if team == TEAM then
		if timeData.nearTeamTower and not bUnit_IsNullOrDead(timeData.nearTeamTower) then
			--print("Tower at location is not dead nor null", timeData.nearTeamTower.lastSeen.location, timeData.nearTeamTower.hUnit:GetHealth())
			return timeData.nearTeamTower, timeData.nearTeamTowerDistance
		end
		timeData.nearTeamTower, timeData.nearTeamTowerDistance =
				get_nearest_tower_to_location(t_sets[SET_BUILDING_ALLIED].towers, gsiPlayer.lastSeen.location)
		return timeData.nearTeamTower, timeData.nearTeamTowerDistance
	else
		if timeData.nearEnemyTower and not bUnit_IsNullOrDead(timeData.nearEnemyTower) then
			return timeData.nearEnemyTower, timeData.nearEnemyTowerDistance
		end
		timeData.nearEnemyTower, timeData.nearEnemyTowerDistance =
				get_nearest_tower_to_location(t_sets[SET_BUILDING_ENEMY].towers, gsiPlayer.lastSeen.location)
		return timeData.nearEnemyTower, timeData.nearEnemyTowerDistance
	end
end

function Set_GetEnemyTowerPlayerIsUnder(gsiPlayer)
	local nearestTower = Set_GetNearestTeamTowerToPlayer(ENEMY_TEAM, gsiPlayer)
	if nearestTower and Math_PointToPointDistance2D(nearestTower.lastSeen.location, gsiPlayer.lastSeen.location) < nearestTower.attackRange then
		return nearestTower
	end
	return false
end

local t_sets_platter = {{}, {}}
local function update_towers_near_allied_heroes() -- sub func to Set_GetTowersNearAlliedHeroes() below
	local tGsiPlayers = GSI_GetTeamPlayers(TEAM)
	t_sets_platter[1].units = {} t_sets_platter[2].units = {}
	
	local tBuildingListAllied = t_sets[SET_BUILDING_ALLIED].towers
	if tBuildingListAllied then
		for i=1,#tBuildingListAllied,1 do
			local gsiThisTower = tBuildingListAllied[i]
			-- if not bUnit_IsNullOrDead(gsiThisTower) then  -- TODO Raises questions about hUnit scope if buildings are not to be updated each frame. 
			for n=1,TEAM_NUMBER_OF_PLAYERS,1 do
				if Math_PointToPointDistance2D(gsiThisTower.lastSeen.location, tGsiPlayers[n].lastSeen.location) 
						< DEFAULT_NEARBY_LIMIT_DISTANCE then
					table.insert(t_sets_platter[1].units, gsiThisTower)
					break
				end
			end
			-- else
				-- table.remove(t_sets[SET_BUILDING_ENEMY], i) -- TODO If this is the "sure thing", it probably still needs a backup, like a check every mod(t) where t = time it takes for unit to transition from dead to null
			-- end
		end
	end
	local tBuildingListEnemy = t_sets[SET_BUILDING_ENEMY].towers
	if tBuildingListEnemy then
		for i=#tBuildingListEnemy,1,-1 do
			local gsiThisTower = tBuildingListEnemy[i]
			-- if not bUnit_IsNullOrDead(gsiThisTower) then --
			for n=1,TEAM_NUMBER_OF_PLAYERS,1 do
				if Math_PointToPointDistance2D(gsiThisTower.lastSeen.location, tGsiPlayers[n].lastSeen.location) 
						< DEFAULT_NEARBY_LIMIT_DISTANCE then
					table.insert(t_sets_platter[2].units, gsiThisTower)
					break
				end
			end
			-- else
				-- table.remove(t_sets[SET_BUILDING_ENEMY], i) -- TODO If this is the "sure thing", it probably still needs a backup, like a check every mod(t) where t = time it takes for unit to transition from dead to null
			-- end
		end
	end
end

function Set_GetTowersNearAlliedHeroes()
	if updated_towers_player.time.currFrame ~= updated_towers_frame_time then
		update_towers_near_allied_heroes()
		updated_towers_player = GSI_GetBot()
		updated_towers_frame_time = updated_towers_player.time.currFrame
	end
	if t_sets_platter[1].units[1] or t_sets_platter[2].units[1] then
		return t_sets_platter
	end
	return EMPTY_TABLE
end

local re_gehsnah
function Set_GetEnemyHeroSetsNearAlliedHeroes() -- TEMPORARY PATCHWORK FUNC
	local tTeamPlayers = GSI_GetTeamPlayers(TEAM)
	tSet = re_gehsnah or {{units={}}}
	local tEnemyHeroes = GSI_GetTeamPlayers(ENEMY_TEAM)
	if tEnemyHeroes then
		for iEnemy=1,#tEnemyHeroes,1 do
			local gsiThisHero = tEnemyHeroes[iEnemy]
			if not gsiThisHero.typeIsNone then
				for n=1,TEAM_NUMBER_OF_PLAYERS,1 do
					if Math_PointToPointDistance2D(gsiThisHero.lastSeen.location, tTeamPlayers[n].lastSeen.location) 
							< ALLOWABLE_CREEP_SET_DIAMETER then
						table.insert(tSet[1].units, gsiThisHero)
						break
					end
				end
			end
		end
	end
	if tSet[1].units[1] then
		re_gehsnah = {{units={}}}
		return tSet
	end
	return EMPTY_TABLE
end


-- parameter "forAnalyticsTime" indicates the unit is not for interaction via Action_xyz() calls, and will include fogged heroes
function Set_GetEnemyHeroesInPlayerRadius(gsiPlayer, radius, forAnalyticsTime)
	local tEnemyHeroes = GSI_GetTeamPlayers(ENEMY_TEAM)
	local tInRadius = recycle_empty or {}
	local playerLocation = gsiPlayer.lastSeen.location
	if tEnemyHeroes then
		for n=1,#tEnemyHeroes,1 do
			local gsiThisHero = tEnemyHeroes[n]
			if ( not gsiThisHero.typeIsNone and not pUnit_IsNullOrDead(gsiThisHero) )
					or (forAnalyticsTime and gsiThisHero.lastSeen.timeStamp + forAnalyticsTime > GameTime()
						and not IsLocationVisible(gsiThisHero.lastSeen.location)) then
				local dist = Math_PointToPointDistance2D(gsiPlayer.lastSeen.location, gsiThisHero.lastSeen.location)
				if radius > dist then
					table.insert(tInRadius, gsiThisHero)
				end
			end
		end
	end
	if tInRadius[1] then
		recycle_empty = {}
		return tInRadius
	end
	return EMPTY_TABLE
end

-- TODO Depreciate
function Set_GetEnemyHeroesInPlayerRadiusAndOuter(location, radius, outer, forAnalyticsTime) -- Used when we're going to iterate over the heroes, but may need outer if radius is empty (Cold Snap a close target? None. Use my invoked Tornado)
	local tEnemyHeroes = GSI_GetTeamPlayers(ENEMY_TEAM)
	local tInRadius = recycle_empty or {}
	local tOuter = recycle_empty2 or {}
	if tEnemyHeroes then
		for n=1,#tEnemyHeroes,1 do
			local gsiThisHero = tEnemyHeroes[n]
			if ( not gsiThisHero.typeIsNone and not pUnit_IsNullOrDead(gsiThisHero) )
					or (forAnalyticsTime and gsiThisHero.lastSeen.timeStamp + forAnalyticsTime > GameTime()) then
				local dist = Math_PointToPointDistance2D(location, gsiThisHero.lastSeen.location)
				if radius > dist then
					table.insert(tInRadius, gsiThisHero)
				elseif outer > dist then
					table.insert(tOuter, gsiThisHero)
				end
			end
		end
	end
	--print(tInRadius[1], tOuter[1], "nearby outer")
	if tInRadius[1] then
		recycle_empty = {}
		if tOuter[1] then
			recycle_empty2 = {}
			return tInRadius, tOuter
		else
			return tInRadius, EMPTY_TABLE
		end
	else
		if tOuter[1] then
			recycle_empty2 = {}
			return EMPTY_TABLE, tOuter
		end
		return EMPTY_TABLE, EMPTY_TABLE
	end
end
Set_GetEnemyHeroesInLocRadOuter = Set_GetEnemyHeroesInPlayerRadiusAndOuter

function Set_GetAlliedHeroesInPlayerRadius(gsiPlayer, radius, includeSelf)
	local tAlliedHeroes = GSI_GetTeamPlayers(TEAM)
	local tInRadius = recycle_empty or {}
	if includeSelf then
		tInRadius[1] = gsiPlayer
	end
	local playerLocation = gsiPlayer.lastSeen.location
	for n=1,#tAlliedHeroes,1 do
		local gsiThisHero = tAlliedHeroes[n]
		if gsiThisHero ~= gsiPlayer and not pUnit_IsNullOrDead(gsiThisHero) then
			if radius > Math_PointToPointDistance2D(playerLocation,
					gsiThisHero.lastSeen.location) then
				table.insert(tInRadius, gsiThisHero)
			end
		end
	end
	if tInRadius[1] then
		recycle_empty = {}
		return tInRadius
	end
	return EMPTY_TABLE
end

function Set_GetAlliedHeroesInLocRadius(gsiPlayer, loc, radius, includeSelf)
	local tAlliedHeroes = GSI_GetTeamPlayers(TEAM)
	local tInRadius = recycle_empty or {}
	for n=1,#tAlliedHeroes,1 do
		local gsiThisHero = tAlliedHeroes[n]
		if (includeSelf or gsiThisHero ~= gsiPlayer)
				and not pUnit_IsNullOrDead(gsiThisHero) then
			if radius > Math_PointToPointDistance2D(loc,
					gsiThisHero.lastSeen.location) then
				table.insert(tInRadius, gsiThisHero)
			end
		end
	end
	if tInRadius[1] then
		recycle_empty = {}
		return tInRadius
	end
	return EMPTY_TABLE
end

function Set_GetNearestAlliedHeroToLocation(location)
	local nearestHero
	local nearestDistance = HIGH_32_BIT
	local alliedHeroesList = GSI_GetTeamPlayers(TEAM)
	if alliedHeroesList then
		for i=1,#alliedHeroesList,1 do
			local thisHero = alliedHeroesList[i]
			if not pUnit_IsNullOrDead(thisHero) then
				local dist = Math_PointToPointDistance2D(location, thisHero.lastSeen.location)
				if dist < nearestDistance then
					nearestDistance = dist
					nearestHero = thisHero
				end
			end
		end
	end
	return nearestHero, nearestDistance
end

function Set_GetNearestEnemyHeroToLocation(location, forAnalyticsTime)
	local nearestHero
	local nearestDistance = HIGH_32_BIT
	local enemyHeroesList = GSI_GetTeamPlayers(ENEMY_TEAM)
	if enemyHeroesList then
		for i=1,#enemyHeroesList,1 do
			local thisEnemy = enemyHeroesList[i]
			if not pUnit_IsNullOrDead(thisEnemy)
					or (forAnalyticsTime and thisEnemy.lastSeen.timeStamp + forAnalyticsTime > GameTime())then
				local dist = Math_PointToPointDistance2D(location, thisEnemy.lastSeen.location)
				if dist < nearestDistance then
					nearestDistance = dist
					nearestHero = thisEnemy
				end
			end
		end
	end
	return nearestHero, nearestDistance
end

function Set_GetCreepSetsNearAlliedHeroes() -- nb. This is naturally cleaned by LHP create_future_damage_lists__job to save looping each sets creeps
	if TEST and GetBot() ~= TEAM_CAPTAIN_UNIT then print(debug.traceback()) end
	local tGsiPlayers = GSI_GetTeamPlayers(TEAM)
	local tSets = recycle_empty or {}
	local tCreepSetsAllied = t_sets[SET_CREEP_ALLIED]
	for s=1,#tCreepSetsAllied,1 do
		for n=1,TEAM_NUMBER_OF_PLAYERS,1 do
			if Math_PointToPointDistance2D(tCreepSetsAllied[s].center, tGsiPlayers[n].lastSeen.location) 
					< ALLOWABLE_CREEP_SET_DIAMETER then
				table.insert(tSets, tCreepSetsAllied[s])
				break
			end
		end
	end
	local tCreepSetsEnemy = t_sets[SET_CREEP_ENEMY]
	for s=1,#tCreepSetsEnemy,1 do
		for n=1,TEAM_NUMBER_OF_PLAYERS,1 do
			if Math_PointToPointDistance2D(tCreepSetsEnemy[s].center, tGsiPlayers[n].lastSeen.location) 
					< ALLOWABLE_CREEP_SET_DIAMETER then
				table.insert(tSets, tCreepSetsEnemy[s])
				break
			end
		end
	end
	if tSets[1] then
		recycle_empty = {}
		return tSets
	end
	return EMPTY_TABLE
end

function Set_GetAlliedCreepSetsInLane(lane)
	local tCreepSetsAllied = t_sets[SET_CREEP_ALLIED]
	local theseSets = recycle_empty or {}
	for s=1,#tCreepSetsAllied,1 do
		if tCreepSetsAllied[s].lane == lane then
			table.insert(theseSets, tCreepSetsAllied[s])
		end
	end
	if theseSets[1] then
		recycle_empty = {}
		return theseSets
	end
	return EMPTY_TABLE
end

function Set_GetNearestAlliedCreepSetInLane(gsiPlayer, lane)
	local tCreepSetsAllied = t_sets[SET_CREEP_ALLIED]
	local closestSet = nil
	local closestSetDistance = HIGH_32_BIT
	local thisPlayerLocation = gsiPlayer.lastSeen.location
	
	for s=1,#tCreepSetsAllied,1 do
		local thisCreepSet = tCreepSetsAllied[s]
		local thisDistance = Math_PointToPointDistance2D(thisCreepSet.center, thisPlayerLocation)
		if thisCreepSet.lane == lane and thisDistance < closestSetDistance then
			closestSetDistance = thisDistance
			closestSet = thisCreepSet
		end
	end
	
	return closestSet, closestSetDistance
end

function Set_GetNearestAlliedCreepSetToLocation(location)
	local tCreepSetsAllied = t_sets[SET_CREEP_ALLIED]
	local closestSet = nil
	local closestSetDistance = HIGH_32_BIT
	for s=1,#tCreepSetsAllied,1 do
		local thisCreepSet = tCreepSetsAllied[s]
		local thisDistance = Math_PointToPointDistance2D(thisCreepSet.center, location)
		if thisDistance < closestSetDistance then
			closestSetDistance = thisDistance
			closestSet = thisCreepSet
		end
	end
	return closestSet, closestSetDistance
end

function Set_GetNearestEnemyCreepSetAtLaneLoc(location, lane)
	local tCreepSetsEnemy = t_sets[SET_CREEP_ENEMY]
	local closestSet = nil
	local closestSetDistance = HIGH_32_BIT
	
	for s=1,#tCreepSetsEnemy,1 do
		local thisCreepSet = tCreepSetsEnemy[s]
		local thisDistance = Math_PointToPointDistance2D(thisCreepSet.center, location)
		if thisCreepSet.lane == lane and thisDistance < closestSetDistance then
			closestSetDistance = thisDistance
			closestSet = thisCreepSet
		end
	end
	
	return closestSet, closestSetDistance
end

function Set_GetNearestEnemyCreepSetToLocation(location)
	local tCreepSetsEnemy = t_sets[SET_CREEP_ENEMY]
	local closestSet = nil
	local closestSetDistance = HIGH_32_BIT
	for s=1,#tCreepSetsEnemy,1 do
		local thisCreepSet = tCreepSetsEnemy[s]
		local thisDistance = Math_PointToPointDistance2D(thisCreepSet.center, location)
		if thisDistance < closestSetDistance then
			closestSetDistance = thisDistance
			closestSet = thisCreepSet
		end
	end
	return closestSet, closestSetDistance
end

function Set_LaneFrontCrashIsReal(lane)
	return lane_front_most_recent[lane][LANE_FRONT_I__PREDICTED_WAVE_CRASH_LOC] == nil
end

function Set_GetPredictedLaneFrontLocation(lane)
	return lane_front_most_recent[lane][LANE_FRONT_I__PREDICTED_WAVE_CRASH_LOC]
					or lane_front_most_recent[lane][LANE_FRONT_I__LAST_SEEN_WAVE_CRASH_LOC],
			lane_front_most_recent[lane][LANE_FRONT_I__PREDICTED_WAVE_CRASH_TIME]
					or 0
end

function Set_GetAlliedCreepSetLaneFrontStored(lane)
	return lane_front_most_recent[lane][LANE_FRONT_I__ALLIED] or team_lane_creep_spawner[TEAM][lane]
end

function Set_GetEnemyCreepSetLaneFrontStored(lane)
	return lane_front_most_recent[lane][LANE_FRONT_I__ENEMY] or team_lane_creep_spawner[TEAM][lane]
end

function Set_GetAlliedCreepSetLaneFront(lane)
	if lane_front_most_recent[lane][LANE_FRONT_I__PREDICTED_WAVE_CRASH_LOC] == nil then -- A general, soft indicator that the lane front information is frame-ready
		return lane_front_most_recent[lane][LANE_FRONT_I__ALLIED]
	end
	local tCreepSetsAllied = t_sets[SET_CREEP_ALLIED]
	local alliedFront
	local greatestDistance = 0
	if tCreepSetsAllied then
		for s=1,#tCreepSetsAllied,1 do
			local thisCreepSet = tCreepSetsAllied[s]
			local dist = Math_PointToPointDistance2D(thisCreepSet.center, team_lane_creep_spawner[ENEMY_TEAM][thisCreepSet.lane])
			if thisCreepSet.lane == lane and
					dist > greatestDistance then
				greatestDistance = dist
				alliedFront = thisCreepSet
			end
		end
	end
	return alliedFront
end

function Set_GetEnemyCreepSetLaneFront(lane)
	if lane_front_most_recent[lane][LANE_FRONT_I__PREDICTED_WAVE_CRASH_LOC] == nil then
		return lane_front_most_recent[lane][LANE_FRONT_I__ENEMY]
	end
	local tCreepSetsEnemy = t_sets[SET_CREEP_ENEMY]
	local enemyFront
	local greatestDistance = 0
	if tCreepSetsEnemy then
		for s=1,#tCreepSetsEnemy,1 do
			local thisCreepSet = tCreepSetsEnemy[s]
			local dist = Math_PointToPointDistance2D(thisCreepSet.center, team_lane_creep_spawner[TEAM][thisCreepSet.lane])
			if thisCreepSet.lane == lane and
					dist > greatestDistance then
				greatestDistance = dist
				enemyFront = thisCreepSet
			end
		end
	end
	return enemyFront
end

local re_gacsnah
function Set_GetAlliedCreepSetsNearAlliedHeroes()
	local tGsiPlayers = GSI_GetTeamPlayers(TEAM)
	local tCreepSetsAllied = t_sets[SET_CREEP_ALLIED]
	local tSets = re_gacsnah or {}
	for s=1,#tCreepSetsAllied,1 do
		for n=1,TEAM_NUMBER_OF_PLAYERS,1 do
			if Math_PointToPointDistance2D(tCreepSetsAllied[s].center, tGsiPlayers[n].lastSeen.location) 
					< ALLOWABLE_CREEP_SET_DIAMETER then
				table.insert(tSets, tCreepSetsAllied[s])
				break
			end
		end
	end
	if tSets[1] then
		re_gacsnah = {}
		return tSets
	end
	return EMPTY_TABLE
end

function Set_GetEnemyCreepSetsInLane(lane)
	local tCreepSetsEnemy = t_sets[SET_CREEP_ENEMY]
	local theseSets = recycle_empty or {}
	if tCreepSetsEnemy then
		for s=1,#tCreepSetsEnemy,1 do
			if tCreepSetsEnemy[s].lane == lane then
				table.insert(theseSets, tCreepSetsEnemy[s])
			end
		end
	end
	if theseSets[1] then
		recycle_empty = {}
		return theseSets
	end
	return EMPTY_TABLE
end

function Set_GetLowestCreepHealthInSetPercent(set)
	local lowestHpPercent = HIGH_32_BIT
	local lowestCreep
	local thisSetUnits = set.units
	for i=1,#thisSetUnits,1 do
		if thisSetUnits[i].lastSeenHealth / thisSetUnits[i].maxHealth < lowestHpPercent then
			lowestHpPercent = thisSetUnits[i].lastSeenHealth / thisSetUnits[i].maxHealth
			lowestCreep = thisSetUnits[i]
		end
	end
	if lowestHpPercent < HIGH_32_BIT then
		return lowestHpPercent, lowestCreep
	end
	return -1
end

function Set_GetLowestCreepHealthInSet(set)
	local lowestHp = HIGH_32_BIT
	local lowestCreep
	if set and set.units then
		local thisSetUnits = set.units
		for i=1,#thisSetUnits,1 do
			if thisSetUnits[i].lastSeenHealth < lowestHp then
				lowestHp = thisSetUnits[i].lastSeenHealth
				lowestCreep = thisSetUnits[i]
			end
		end
		if lowestHp < HIGH_32_BIT then
			return lowestHp, lowestCreep
		end
	end
	return -1
end

function Set_SetIsDotaType(setType)
	return setType < SET_HERO
end


function GSI_CreateUpdateUnitSets()
	job_domain:RegisterJob(
			not SET_SCREEN_TRACKING and update_all_sets__job or DEBUG_update_all_sets__job,
			{
				["throttleEnemy"] = Time_CreateThrottle(THROTTLE_SET_ALL_UPDATE),
				["throttleAllied"] = Time_CreateThrottle(
						DEBUG and not USER_HAS_NO_EPILEPSY_RISK_DEBUG_THROTTLES and
						THROTTLE_SET_ALL_UPDATE or THROTTLE_SET_ALL_UPDATE/3
					),
				["throttleUpdateLaneFronts"] = Time_CreateThrottle(THROTTLE_UPDATE_LANE_FRONTS)
			},
			"JOB_UPDATE_UNIT_SETS"
		)
	Set_UpdateAllSets()
end

-- function GSI_CreateUpdateCleanSets()
	-- job_domain:RegisterJob(
			-- function()
				-- for stuff
			-- end
		-- )
-- end

function GSI_RegisterGSIJobDomainToSet(jobDomain)
	job_domain = jobDomain
end
