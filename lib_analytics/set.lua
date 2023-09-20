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

-- Deduces clusters of units on the map for certain types. Useful for fast imaginary scoring, positioning,
--- or also a quick search of a small subset of a unit type nearby.

local PRINT_EMPTY_TABLE_ERR = DEBUG or false

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
SET_BUILDING_ENEMY =			UNIT_LIST_ENEMY_BUILDINGS
SET_CREEP_NEUTRAL =				UNIT_LIST_NEUTRAL_CREEPS
SET_BUILDING_NEUTRAL =			0xFF03
-- ~
local SET_ALL = SET_ALL
local SET_ALL_ALLIED = SET_ALL_ALLIED
local SET_HERO_ALLIED = SET_HERO_ALLIED
local SET_CREEP_ALLIED = SET_CREEP_ALLIED
local SET_CREEP_ALLIED_CONTROLLED = SET_CREEP_ALLIED_CONTROLLED
local SET_WARD_ALLIED = SET_WARD_ALLIED
local SET_BUILDING_ALLIED = SET_BUILDING_ALLIED
local SET_ALL_ENEMY = SET_ALL_ENEMY
local SET_HERO_ENEMY = SET_HERO_ENEMY
local SET_CREEP_ENEMY = SET_CREEP_ENEMY
local SET_CREEP_ENEMY_CONTROLLED = SET_CREEP_ENEMY_CONTROLLED
local SET_WARD_ENEMY = SET_WARD_ENEMY
local SET_BUILDING_ENEMY = SET_BUILDING_ENEMY
local SET_CREEP_NEUTRAL = SET_CREEP_NEUTRAL
local SET_BUILDING_NEUTRAL = SET_BUILDING_NEUTRAL

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

--local CREEP_IS_NOT_CONTROLLED_PLAYER_ID = -1

local DEFAULT_NEARBY_LIMIT_DISTANCE = 2000

local THROTTLE_SET_ALL_UPDATE = DEBUG and not USER_HAS_NO_EPILEPSY_RISK_DEBUG_THROTTLES and 0.0 or 0.2 -- slow throttle (greater than 0.0) has epileptic risk
if DEBUG then
	if THROTTLE_SET_ALL_UPDATE < 0.2 then
		DEBUG_print("set: set updates are "..(THROTTLE_SET_ALL_UPDATE < 0.2 and "" or "not ").."fast.")
	end
end
local THROTTLE_UPDATE_LANE_FRONTS = DEBUG and not USER_HAS_NO_EPILEPSY_RISK_DEBUG_THROTTLES and 0.0 or 0.37 -- slow throttle (greater than 0.0) has epileptic risk
local THROTTLE_UPDATE_NEUTRALS = 0.67

local SET_SCREEN_TRACKING = true and VERBOSE

local insert = table.insert
local remove = table.remove
local next = next
local TEAM = TEAM
local ENEMY_TEAM = ENEMY_TEAM
local TEAM_NUMBER_OF_PLAYERS = TEAM_NUMBER_OF_PLAYERS
local ENEMY_TEAM_NUMBER_OF_PLAYERS = ENEMY_TEAM_NUMBER_OF_PLAYERS
local GAME_STATE_PRE_GAME = GAME_STATE_PRE_GAME
local GSI_GetTeamPlayers = GSI_GetTeamPlayers
local Map_LaneHalfwayPoint = Map_LaneHalfwayPoint
local Map_LaneLogicalToNaturalMeet = Map_LaneLogicalToNaturalMeet
local Map_ExtrapolatedLaneFrontWhenDeadBasic = Map_ExtrapolatedLaneFrontWhenDeadBasic
local Map_GetLaneValueOfMapPoint = Map_GetLaneValueOfMapPoint
local Map_GetBaseOrLaneLocation = Map_GetBaseOrLaneLocation
local Math_PointToPointDistance2D = Math_PointToPointDistance2D
local Vector_SideOfPlane = Vector_SideOfPlane
local pUnit_IsNullOrDead = pUnit_IsNullOrDead
local bUnit_IsNullOrDead = bUnit_IsNullOrDead
local cUnit_IsNullOrDead = cUnit_IsNullOrDead
local cUnit_ConvertListToSafeUnits = cUnit_ConvertListToSafeUnits
local GetUnitList = GetUnitList
local Vector = Vector
local EMPTY_TABLE = EMPTY_TABLE
local ORTHOGONAL_Z = ORTHOGONAL_Z
local HIGH_32_BIT = HIGH_32_BIT

local MAP_LOGICAL_MIDDLE_LANE = MAP_LOGICAL_MIDDLE_LANE
local RADIANT_FOUNTAIN_LOC = Map_GetLogicalLocation(MAP_POINT_RADIANT_FOUNTAIN_CENTER)
local DIRE_FOUNTAIN_LOC = Map_GetLogicalLocation(MAP_POINT_DIRE_FOUNTAIN_CENTER)
--
local team_lane_creep_spawner

local t_sets = {}
local all_towers = {} -- All towers i-index
local all_towers_packaged -- Is for uniform processing at higher levels
local fast_nasty_towers = {} -- TODO Implement A cascading i-index table of the towers that are not protected by the tower up the lane

local updated_towers_time_data -- gsiCaptainTimeData
local updated_towers_frame_time = 0

local abs = math.abs
local floor = math.floor
local ceil = math.ceil
local min = math.min
local max = math.max

local recycle_tbls = {}

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
local t_allied_fronts = {}; local t_enemy_fronts = {};
local function reset_dist_max(isTeam)
	local fronts = isTeam and t_allied_fronts or t_enemy_fronts
	for i=1,3,1 do
		distGreatestForLane[i] = 0
		fronts[i] = nil
	end
	distGreatestForLane[4] = 0xFFFF
	distGreatestForLane[5] = 0xFFFF
	return fronts
end
local function lane_indexed_set_if_lesser(team, tblOfLesser, set)
	local lane = set.lane
	local center = set.center
	local fountainLoc = lane == MAP_LOGICAL_RADIANT_BASE and RADIANT_FOUNTAIN_LOC or DIRE_FOUNTAIN_LOC
	local dist = ((center.x-fountainLoc.x)^2 + (center.y-fountainLoc.y)^2)^0.5
	if dist < distGreatestForLane[lane] then
		distGreatestForLane[lane] = dist
		tblOfLesser[lane] = set
	end
end

local function lane_indexed_set_if_greater(team, tblOfGreatest, set)
	local lane = set.lane
	if lane >= 4 then lane_indexed_set_if_lesser(team, tblOfGreatest, set) return end
	local center = set.center
	local spawnerLoc = team_lane_creep_spawner[team][lane]
	local dist = ((center.x-spawnerLoc.x)^2 + (center.y-spawnerLoc.y)^2)^0.5
	if dist > distGreatestForLane[lane] then
		distGreatestForLane[lane] = dist
		tblOfGreatest[lane] = set
	end
end

-------------- update_lane_fronts()
local function update_lane_fronts()
	local tCreepSetsAllied = t_sets[SET_CREEP_ALLIED]
	local alliedFronts = reset_dist_max(true)
	if tCreepSetsAllied then
		for s=1,#tCreepSetsAllied,1 do
			lane_indexed_set_if_greater(TEAM, alliedFronts, tCreepSetsAllied[s])
		end
	end
	local tCreepSetsEnemy = t_sets[SET_CREEP_ENEMY]
	local enemyFronts = reset_dist_max(false)
	if tCreepSetsEnemy then
		for s=1,#tCreepSetsEnemy,1 do
			lane_indexed_set_if_greater(ENEMY_TEAM, enemyFronts, tCreepSetsEnemy[s])
		end
	end
	local gameTime = GameTime()
	local isPreGame = GetGameState() == GAME_STATE_PRE_GAME
	for iLane=1,3,1 do
		local aFront = alliedFronts[iLane]
		local aFrontC = aFront and aFront.center
		local eFront = enemyFronts[iLane]
		local eFrontC = eFront and eFront.center
		local thisLaneFrontLocations = lane_front_most_recent[iLane]
		if aFront and eFront then 
			if #(aFront.units)*4 < #(eFront.units) then 
				alliedFronts[iLane] = nil  -- Run from our creeps if they're being swarmed
				aFront = nil
				aFrontC = nil
			elseif ((aFrontC.x-eFrontC.x)^2 + (aFrontC.y-eFrontC.y)^2)^0.5 < CONSIDER_CRASHED_CREEP_SET_RANGE then
			-- The wave is crashed
				thisLaneFrontLocations[LANE_FRONT_I__LAST_SEEN_WAVE_CRASH_LOC]
						= Vector(aFrontC.x + (eFrontC.x - aFrontC.x)/2,
								aFrontC.y + (eFrontC.y - aFrontC.y)/2, 0 )
				thisLaneFrontLocations[LANE_FRONT_I__PREDICTED_WAVE_CRASH_LOC] = nil
				goto NEXT_LANE;
			end
		end
		do
			-- The wave is seperated
			local theoreticalAlliedFrontLoc = aFrontC
					or isPreGame 
							and GSI_GetTeamLaneTierTower(TEAM, iLane, 2).lastSeen.location
					or Map_ExtrapolatedLaneFrontWhenDeadBasic(
							TEAM, iLane, thisLaneFrontLocations[LANE_FRONT_I__LAST_SEEN_WAVE_CRASH_LOC]
						)
			local theoreticalEnemyFrontLoc = eFrontC
					or Map_ExtrapolatedLaneFrontWhenDeadBasic(
							ENEMY_TEAM, iLane, theoreticalAlliedFrontLoc
						)

			if DEBUG then
				DebugDrawCircle(theoreticalEnemyFrontLoc, 5, 125, 125, 125)
			end























			if not eFront or not aFront
					or has_creep_set_likely_died(
							thisLaneFrontLocations[LANE_FRONT_I__LAST_SEEN_WAVE_CRASH_LOC],
							theoreticalAlliedFrontLoc
						)
					or has_creep_set_likely_died(
							thisLaneFrontLocations[LANE_FRONT_I__LAST_SEEN_WAVE_CRASH_LOC],
							eFrontC
					) then
				thisLaneFrontLocations[LANE_FRONT_I__PREDICTED_WAVE_CRASH_LOC],
				thisLaneFrontLocations[LANE_FRONT_I__PREDICTED_WAVE_CRASH_TIME] = Map_LaneHalfwayPoint(
						iLane, theoreticalAlliedFrontLoc, theoreticalEnemyFrontLoc
					)
			end
			--[DEBUG]]print(thisLaneFrontLocations[LANE_FRONT_I__PREDICTED_WAVE_CRASH_LOC], thisLaneFrontLocations[LANE_FRONT_I__PREDICTED_WAVE_CRASH_TIME])
			if not thisLaneFrontLocations[LANE_FRONT_I__PREDICTED_WAVE_CRASH_LOC] then -- backup can't determine (happens?) set predicted location to natural meet
				print("/VUL-FT/ <WARN> Lane wave crash prediction using natural meet location")
				local laneCrash = Map_LaneLogicalToNaturalMeet(iLane)
				thisLaneFrontLocations[LANE_FRONT_I__PREDICTED_WAVE_CRASH_LOC] = laneCrash
				thisLaneFrontLocations[LANE_FRONT_I__PREDICTED_WAVE_CRASH_TIME]
						= gameTime + ((aFrontC.x-laneCrash.x)^2 + (aFrontC.y-laneCrash.y)^2)^0.5 * 0.003
			end
	--[VERBOSE]]if VERBOSE and thisLaneFrontLocations[LANE_FRONT_I__PREDICTED_WAVE_CRASH_LOC] then DebugDrawCircle(thisLaneFrontLocations[LANE_FRONT_I__PREDICTED_WAVE_CRASH_LOC], 300, TEAM == TEAM_RADIANT and 0 or 30, TEAM == TEAM_RADIANT and 30 or 0, 70) end
		end
		::NEXT_LANE::
		thisLaneFrontLocations[LANE_FRONT_I__ALLIED] = aFront -- N.B. Previous values before the update on this line may be implied above
		thisLaneFrontLocations[LANE_FRONT_I__ENEMY] = eFront
	end
	for iLane=4,5 do
		local newCrashPrediction = enemyFronts[iLane] and enemyFronts[iLane].center
		lane_front_most_recent[iLane][LANE_FRONT_I__ALLIED] = alliedFronts[iLane]
		lane_front_most_recent[iLane][LANE_FRONT_I__ENEMY] = enemyFronts[iLane]
		lane_front_most_recent[iLane][LANE_FRONT_I__LAST_SEEN_WAVE_CRASH_LOC] = newCrashPrediction or lane_front_most_recent[iLane][LANE_FRONT_I__LAST_SEEN_WAVE_CRASH_LOC]
		lane_front_most_recent[iLane][LANE_FRONT_I__PREDICTED_WAVE_CRASH_LOC] = newCrashPrediction or lane_front_most_recent[iLane][LANE_FRONT_I__PREDICTED_WAVE_CRASH_LOC]
		lane_front_most_recent[iLane][LANE_FRONT_I__PREDICTED_WAVE_CRASH_TIME] = gameTime
	end
end

local function update_neutral_set()
	print("DONT USE THIS")
	local neuts = GetUnitList(SET_CREEP_NEUTRAL)
	local neutsSet = t_sets[neuts] or {}
	for i=1,#neuts do
		print("NEUTS", neuts[i]:GetUnitName())
		if neuts[i]:IsBuilding() then
			insert(neutsSet, bUnit_NewSafeUnit(neuts[i]))
		end
	end
	local team = GSI_GetTeamBuildings(TEAM)
	for k,v in next,team do
		print(k, v, v.name)
	end
end

-- Call me when your data exists for only a known code block,
-- -| and it will never cross over CaptainThink(), and it only
-- -| stores numerically indexed data. Do not remove data from
-- -| the table unless it done cleanly: t[i] = t[#t]; t[#t] = nil;
-------- Set_DisposableNumerical()
function Set_DisposableNumerical()
	local recycle_tbls = recycle_tbls
	local disposable = recycle_tbls[#recycle_tbls]
	-- No remove from recycles, you agreed to the rule by calling
	if not disposable then
		disposable = {}
		recycle_tbls[1] = disposable
	end
	return disposable
end

-- If not t then do DisposableNumerical() behavior, with the programmer agreeing
-- -| to the rules above that function.
-------- Set_NumericalIndexUnion()
function Set_NumericalIndexUnion(t, s1, s2, s3, s4) -- Destructive to t. Breaks at nil arg
	local EMPTY_TABLE = EMPTY_TABLE
	for k,v in next,EMPTY_TABLE do
		if true or PRINT_EMPTY_TABLE_ERR then
			ERROR_print(true, not DEBUG, "[set] EMPTY TABLE %s HAS BEEN MODIFIED %s %s %s %s TEAM: %s",
					EMPTY_TABLE, type(k), type(v), tostring(k), STR(v), TEAM_IS_RADIENT and "Radiant" or "Dire"
				)
		end
		Util_TablePrint(EMPTY_TABLE, 3)
		EMPTY_TABLE = {}
		break;
	end
	if not t then
		local recycle_tbls = recycle_tbls
		t = recycle_tbls[#recycle_tbls]
		-- no clear (rules)
		if not t then
			-- DisposableNumerical rules that you unknowingly signed up for
			t = {}
			recycle_tbls[1] = t
		end
		t[1] = nil
	end

	local preTSize = #t
	local tSize = t[1] and preTSize or 0
	

	local sSize
	if s1 then
		local i=1
		sSize = #s1
		while(i<=sSize) do
			t[tSize+i] = s1[i]
			i = i + 1
		end
		tSize = tSize + sSize
	else goto NSU_END; end
	if s2 then
		local i=1
		sSize = #s2
		while(i<=sSize) do
			t[tSize+i] = s2[i]
			i = i + 1
		end
		tSize = tSize + sSize
	else goto NSU_END; end
	if s3 then
		local i=1
		sSize = #s3
		while(i<=sSize) do
			t[tSize+i] = s3[i]
			i = i + 1
		end
		tSize = tSize + sSize
	else goto NSU_END; end
	if s4 then
		local i=1
		sSize = #s4
		while(i<=sSize) do
			t[tSize+i] = s4[i]
			i = i + 1
		end
		tSize = tSize + sSize
	end
	
	::NSU_END::
	for i=tSize+1,preTSize do
		t[i] = nil
	end
	
	return t;
end

--function Set_RemoveCreepFromSet(gsiCreep)
--	local set = gsiCreep.ofUnitSet
--	if set and set.units then
--		local setUnits = gsiCreep.ofUnitSet.units
--		if setUnits then
--			for i=1,#setUnits do
--				if setUnits[i] == gsiCreep then
--					remove(setUnits, i)
--					set.total = set.total - 1
--					break;
--				end
--			end
--		end
--		gsiCreep.ofUnitSet = nil
--		if not setUnits[1] then
--			local tCreepSets
--			if gsiCreep.team == TEAM then
--				tCreepSets = t_sets[gsiCreep.playerID == -1 and SET_CREEP_ALLIED
--						or SET_CREEP_ALLIED_CONTROLLED]
--			else
--				tCreepSets = t_sets[gsiCreep.playerID == -1 and SET_CREEP_ENEMY
--						or SET_CREEP_ENEMY_CONTROLLED]
--			end
--			for i=1,#tCreepSets do
--				if tCreepSets[i] == set then
--					-- Allow the set to sit in limbo for stale task objectives and garb collect
--					remove(tCreepSets, i)
--					-- But the empty units tbl can be recycled as tasks should only use sets as
--					-- -| objectives, and not their units tbl.
--					insert(recycle_tbls, setUnits)
--					set.units = EMPTY_TABLE
--					set.total = 0
--					return;
--				end
--			end
--		end
--	end
--end

-------------- update_creep_set_type()
local function update_creep_set_type(creepSetType)
	local EMPTY_TABLE = EMPTY_TABLE
	local recycle_tbls = recycle_tbls
	local recycleSize = #recycle_tbls

	local sameReactPlayerCreepSetType
--	if creepSetType == SET_CREEP_ALLIED then
--		sameReactPlayerCreepSetType = SET_CREEP_ALLIED_CONTROLLED
--		if t_sets[sameReactPlayerCreepSetType][1] then
--			t_sets[sameReactPlayerCreepSetType] = {}
--		end
--	elseif creepSetType == SET_CREEP_ENEMY then
--		sameReactPlayerCreepSetType = SET_CREEP_ENEMY_CONTROLLED
--		if t_sets[sameReactPlayerCreepSetType][1] then
--			t_sets[sameReactPlayerCreepSetType] = {}
--		end
--	else
--		sameReactPlayerCreepSetType = -1
--	end

	local tCreepSets = t_sets[creepSetType]

	local tCreepList = cUnit_ConvertListToSafeUnits(GetUnitList(creepSetType))

	local addSetDist = ALLOWABLE_CREEP_SET_DIAMETER
	local splitSetDist = addSetDist*1.67

	local sizeSets = #tCreepSets

	for i=1,sizeSets do
		local thisSet = tCreepSets[i]
		thisSet.total = 0
		thisSet.mustRecenter = true
	end
	local reLane = false
	if tCreepSets.throttleGlue:allowed() and tCreepSets[2] then
		reLane = true
		
		local updateIndex = (tCreepSets.updateIndex + 1) % #tCreepSets + 1
		tCreepSets.updateIndex = updateIndex
		local glueDist = addSetDist*0.75
		local glueSet = tCreepSets[updateIndex]
		local glueSetLoc = glueSet.center
		
		for i=1,sizeSets do
			if i ~= updateIndex then
				local compareSet = tCreepSets[i]
				local compareSetLoc = compareSet.center
				if ((compareSetLoc.x-glueSetLoc.x)^2 + (compareSetLoc.y-glueSetLoc.y)^2)^0.5
						< glueDist then
					-- garb collect, allow stale GetTaskObjective(..)s that will find no creeps in set
					
					
					tCreepSets[updateIndex] = tCreepSets[sizeSets]
					tCreepSets[sizeSets] = nil
					glueSet.total = 0
					local unitsTbl = glueSet.units
					recycleSize = recycleSize + 1
					recycle_tbls[recycleSize] = unitsTbl
					for j=1,#unitsTbl do
						unitsTbl[j].ofUnitSet = nil
					end
					glueSet.units = EMPTY_TABLE
					tCreepSets.updateIndex = updateIndex - 1
					break;
				end
			end
		end
	end
	for i=1,#tCreepList,1 do
		-- for thisCreep in creeps:
		-- (IsNew || Recenter->goto next || Split stray) && (Insert near set || Create new set)
		local thisCreep = tCreepList[i]
		local thisCreepLoc = thisCreep.lastSeen.location
--[[DEBUG]]if DEBUG and creepSetType == SET_CREEP_ALLIED then DEBUG_DrawCreepData(thisCreep) end
		local ofSet = thisCreep.ofUnitSet
		if ofSet and ofSet.units ~= EMPTY_TABLE then
			local center = ofSet.center
			if ((center.x-thisCreepLoc.x)^2 + (center.y-thisCreepLoc.y)^2)^0.5 < splitSetDist then
				-- Confirm it's still close to the set
				ofSet.total = ofSet.total + 1
				if ofSet.mustRecenter then
					center.x = thisCreepLoc.x
					center.y = thisCreepLoc.y
					if reLane then
						ofSet.lane = Map_GetBaseOrLaneLocation(thisCreepLoc)
					end
					ofSet.mustRecenter = false
				else
					center.x = center.x + (thisCreepLoc.x - center.x)/ofSet.total
					center.y = center.y + (thisCreepLoc.y - center.y)/ofSet.total
				end
				ofSet.units[ofSet.total] = thisCreep
				
				goto UPDATE_CREEP_SETS_NEXT_CREEP;
			else
				-- Creep has run off
				local unitsCreepSet = ofSet.units
				for i=1,#unitsCreepSet do
					if unitsCreepSet[i] == thisCreep then
						remove(unitsCreepSet, i) -- (total was 0'd)
						
						break;
					end
				end
			end
		end
		if thisCreep.playerID ~= -1 then -- Add the player controlled unit
		--	insert(t_sets[sameReactPlayerCreepSetType], thisCreep)
			if creepSetType == SET_CREEP_ALLIED then
				pUnit_CreateDominatedUnit(thisCreep.playerID, thisCreep)
			end
		else -- Add the lane creep to it's proximity set
			local s = 1
			while(s <= #tCreepSets) do
				local thisCreepSet = tCreepSets[s]
				local setCenter = thisCreepSet.center
				if ((thisCreepLoc.x-setCenter.x)^2 + (thisCreepLoc.y-setCenter.y)^2)^0.5
						< addSetDist then
					local thisX, thisY = setCenter.x, setCenter.y
					
					thisCreep.ofUnitSet = thisCreepSet
					thisCreepSet.total = thisCreepSet.total + 1
					thisCreepSet.units[thisCreepSet.total] = thisCreep
					setCenter.x = thisX + (thisCreepLoc.x - thisX)/thisCreepSet.total -- Adjusts to the new center x
					setCenter.y = thisY + (thisCreepLoc.y - thisY)/thisCreepSet.total -- ...and y
					break;
				end
				s = s + 1
			end
			
			if s >= #tCreepSets+1 then -- Did the creep not go to an existing set? Create new set
				-- Initialize a new set with it's first creep
				
				local unitsTbl
				if recycleSize > 0 then
					unitsTbl = recycle_tbls[recycleSize]
					recycle_tbls[recycleSize] = nil
					recycleSize = recycleSize-1;
				else unitsTbl = {}; end
				unitsTbl[1] = thisCreep
				thisCreep.ofUnitSet = { total=1,
						center=Vector(thisCreepLoc.x, thisCreepLoc.y, thisCreepLoc.z),
						lane=Map_GetBaseOrLaneLocation(thisCreepLoc),
						units=unitsTbl 
					}
				insert(tCreepSets, thisCreep.ofUnitSet)
			end
		end
		::UPDATE_CREEP_SETS_NEXT_CREEP::
	end
	local sizeSets = #tCreepSets
	local i=1
	
	
	
	
	
	while(i<=sizeSets) do
		local thisSet = tCreepSets[i]
		
		if thisSet.total == 0 or thisSet.mustRecenter == true then
			
			tCreepSets[i] = tCreepSets[sizeSets]
			tCreepSets[sizeSets] = nil
			local unitsTbl = thisSet.units
			recycleSize = recycleSize + 1
			recycleSize = recycleSize < 1 and 1 or recycleSize
			recycle_tbls[recycleSize] = unitsTbl
			thisSet.units = EMPTY_TABLE
			thisSet.total = 0
			sizeSets = sizeSets - 1
			
		else
			
			
			local setUnits = thisSet.units
			-- Any creeps that remain past the inserted total must be nulled.
			for j=thisSet.total+1,#setUnits do
				setUnits[j] = nil
			end
			i=i+1
		end
	end
end

local function update_enemy_buildings()
	local tBuildingListEnemy = bUnit_ConvertListToSafeUnits(GetUnitList(SET_BUILDING_ENEMY))
	t_sets[SET_BUILDING_ENEMY] = {units={}, towers={}}
	for i=1,#tBuildingListEnemy,1 do
		local gsiThisBuilding = tBuildingListEnemy[i]
		insert(t_sets[SET_BUILDING_ENEMY].units, gsiThisBuilding)
		if gsiThisBuilding.isTower then
			insert(t_sets[SET_BUILDING_ENEMY].towers, gsiThisBuilding)
			insert(all_towers, gsiThisBuilding)
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
--	no	if workingSet.throttleUpdateNeutrals:allowed() then
--			update_neutral_set()
--		end
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
	--update_enemy_buildings()
	update_all_sets__job(workingSet)
end

-------- Set_Initialize()
function Set_Initialize()
	-- Create lane creep sets
	local creepSet = {}
	creepSet.updateIndex = 1
	creepSet.throttleGlue = Time_CreateThrottle(0.4)
	t_sets[SET_CREEP_ALLIED] = creepSet
	creepSet = {}
	creepSet.updateIndex = 1
	creepSet.throttleGlue = Time_CreateThrottle(0.2)
	creepSet.throttleGlue.next = creepSet.throttleGlue.next + 0.2
	t_sets[SET_CREEP_ENEMY] = creepSet

	-- Create building sets
	
	-- building.lua NB Enemy building data is utilizing allied tier::data for valid minute -1:30 data.
	local tBuildingListAllied = bUnit_ConvertListToSafeUnits(GetUnitList(SET_BUILDING_ALLIED))
	t_sets[SET_BUILDING_ALLIED] = {units={}, towers={}}
	t_sets[SET_BUILDING_ENEMY] = {units={}, towers={}}
	t_sets[SET_BUILDING_NEUTRAL] = {units={}, outposts={}, mangoTrees={}, twinGates={},
			lanterns={}, boss={} }
	for i=1,#tBuildingListAllied,1 do
		local gsiThisBuilding = tBuildingListAllied[i]
		if gsiThisBuilding.isOutpost then
			insert(t_sets[SET_BUILDING_NEUTRAL].units, gsiThisBuilding)
			insert(t_sets[SET_BUILDING_NEUTRAL].outposts, gsiThisBuilding)
		else
			insert(t_sets[SET_BUILDING_ALLIED].units, gsiThisBuilding)
			if string.find(gsiThisBuilding.name, "tower") then
				insert(t_sets[SET_BUILDING_ALLIED].towers, gsiThisBuilding)
				insert(all_towers, gsiThisBuilding)
				Map_ReportTowerLocation(gsiThisBuilding.name, gsiThisBuilding.lastSeen.location)
			end
		end
	end
	local tBuildingListEnemy = bUnit_ConvertListToSafeUnits(GetUnitList(SET_BUILDING_ENEMY))
	for i=1,#tBuildingListEnemy,1 do
		local gsiThisBuilding = tBuildingListEnemy[i]
		if gsiThisBuilding.isOutpost then
			insert(t_sets[SET_BUILDING_NEUTRAL].units, gsiThisBuilding)
			insert(t_sets[SET_BUILDING_NEUTRAL].outposts, gsiThisBuilding)
		else
			insert(t_sets[SET_BUILDING_ENEMY].units, gsiThisBuilding)
			if string.find(gsiThisBuilding.name, "tower") then
				insert(t_sets[SET_BUILDING_ENEMY].towers, gsiThisBuilding)
				insert(all_towers, gsiThisBuilding)
				Map_ReportTowerLocation(gsiThisBuilding.name, gsiThisBuilding.lastSeen.location)
			end
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
	updated_towers_time_data = GSI_GetBot().time
	updated_towers_frame_time = 0

	local neuts = GetUnitList(SET_CREEP_NEUTRAL)
	local neutSet = t_sets[SET_BUILDING_NEUTRAL]
	for i=1,#neuts do
		
		if neuts[i]:IsBuilding() then
			local neutSafe = bUnit_NewSafeUnit(neuts[i])
			insert(neutSet.units, neutSafe)
			if string.find(neutSafe.name, "lantern") then
				
				insert(neutSet.lanterns, neutSafe)
			elseif string.find(neutSafe.name, "twin_gate") then
				
				insert(neutSet.twinGates, neutSafe)
			elseif string.find(neutSafe.name, "mango_tree") then
				
				insert(neutSet.mangoTrees, neutSafe)
			else
				INFO_print("[set] unknown neutral building type found: %s", neutSafe.name)
			end
		elseif string.find(neuts[i]:GetUnitName(), "miniboss") then
			local neutSafe = cUnit_NewSafeUnit(neuts[i])
			insert(neutSet.units, neutSafe)
			insert(neutSet.boss, neutSafe)
		end
	end

	




	
	
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
	update_creep_set_type(SET_CREEP_ALLIED)
end

function Set_UpdateEnemyCreepSets()
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

local score_platter = {}
local score_funcs = {
	["-a"] = function(setUnits, ...)
		local scores = score_platter
		for i=1,#setUnits do
			local unit = setUnits[i]

		end
		return 2 -- ret argsEaten
	end,
}

function Set_Score(setUnits, ...)
	
end

function Set_GetSetUnitNearestToLocation(loc, set)
	local units = set.units or set
	local nearestUnit
	local nearestDist = 0xFFFF
	for i=1,#units do
		local unitLoc = units[i].lastSeen.location
		local dist = ((loc.x-unitLoc.x)^2 + (loc.y-unitLoc.y)^2)^0.5
		if dist < nearestDist then
			nearestUnit = units[i]
			nearestDist = dist
		end
	end
	return nearestUnit, nearestDist
end

function Set_GetSetTypeUnitNearestToLocation(loc, setType, subType)
	local units = t_sets[setType]
	if subType then
		units = units[subType]
		if not units or type(subType) ~= "string" then
			ERROR_print(true, not DEBUG, "[set] Set_GetSetTypeUnitNearestToLocation%s: no such setType",
					Util_ParamString(loc, setType, subType)
				)
			return nil, 14142
		end
	end

	local nearestUnit
	local nearestDist = 0xFFFF
	for i=1,#units do
		local unitLoc = units[i].lastSeen.location
		local dist = ((loc.x-unitLoc.x)^2 + (loc.y-unitLoc.y)^2)^0.5
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
				local dist = ((location.x-thisLocationOfCrowding.x)^2 + (location.y-thisLocationOfCrowding.y)^2)^0.5
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
		crowdingCenter = Vector(crowdingCenter.x, crowdingCenter.y, crowdingCenter.z)
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

local recycle_empty={}; local recycle_empty2={}
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
				insert(units, s1Units[i])
				-- DebugDrawCircle(unitLoc, 60, 0, 0, 255)
				if bailIfCreep and s1Units[i].type == UNIT_TYPE_CREEP then
					goto RETURN
				end
			else
				
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
				insert(units, s2Units[i])
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
			if ((location.x-unitLoc.x)^2 + (location.y-unitLoc.y)^2)^0.5 < radius then
				insert(units, s1Units[i])
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
			if ((location.x-unitLoc.x)^2 + (location.y-unitLoc.y)^2)^0.5 < radius then
				insert(units, s1Units[i])
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

local function get_nearest_tower_to_loc(set, loc, notShrine)
	local closestDistance = HIGH_32_BIT
	local closestTower
	local x = loc.x; local y = loc.y
	if set then
		for i=1,#set,1 do
			local thisBuilding = set[i]
			if not notShrine or not thisBuilding.isShrine then
				local thisLoc = thisBuilding.lastSeen.location
				local dist = ((thisLoc.x-x)^2 + (thisLoc.y-y)^2)^0.5
				if dist < closestDistance then
					closestDistance = dist
					closestTower = thisBuilding
				end
			end
		end
	end
	return closestTower, closestDistance
end

local loc_cache_tower_atk = {}
local clear_list = {}
do local t = loc_cache_tower_atk for i=1,174 do t[i] = {} end end -- 2MB at a guess
-- cached, use team value
-------- Set_GetTowerOverLocation()
function Set_GetTowerOverLocation(loc, requireTeam)
	--[[TOWERS NO LEGS BAKE]]
	local loc_cache = loc_cache_tower_atk
	local x = 87+floor(0.5+loc.x/80) --[[WORLD BOUNDS BAKE]]
	x = x<=1 and 1 or x < 174 and x or 174
	local y = 87+floor(0.5+loc.y/80)
	y = y<=1 and 1 or y < 174 and y or 174
	
	local overLocTower = loc_cache[x][y]
	if overLocTower then
		
		if clear_list[overLocTower] or bUnit_IsNullOrDead(overLocTower) then
			clear_list[overLocTower] = true
			local towerLoc = overLocTower.lastSeen.location
			local clx = 87+floor(40+towerLoc.x/80)
			clx = clx<=1 and clx or clx < 174 and clx or 174
			local cly = 87+floor(40+towerLoc.y/80)
			cly = cly<=1 and cly or cly < 174 and cly or 174
			local size = 24
			if not loc_cache[clx][cly] then
				size = 10
				clx = x
				cly = y
				for i=1,10 do
					if clx <= 3 or overLocTower ~= loc_cache[clx-1][cly] then
						-- eg. this wouldn't need floor(i/2) if the clear operation was a diamond.
						-- -| but it is a square. get founds square center
						clx = clx+floor(i/2) - 3
						clx = clx > 1 and clx or 1
						for k=1,10 do
							if cly <= 3 or overLocTower ~= loc_cache[clx][cly-1] then
								-- founds square center
								cly = cly+floor(k/2) - 3
								cly = cly > 1 and cly or 1
								break;
							end
							cly = cly - 1
						end
						break;
					end
					clx = clx - 1
				end
				
				
				
			else
				clx = clx - 12
				clx = clx > 1 and clx or 1
				cly = cly - 12
				cly = cly > 1 and cly or 1
				for i=1,size do
					for k=1,size do
						if loc_cache[clx][cly] == overLocTower then
							loc_cache[clx][cly] = false
						end
						cly = cly + 1
						if cly > 174 then break; end
					end
					clx = clx + 1
					if clx > 174 then break; end
				end
			end
		end
	elseif overLocTower == nil then
		-- set cache even if wrong team
		
		local overLocTower = get_nearest_tower_to_loc(t_sets[SET_BUILDING_ENEMY].towers, loc)
		local overLocTeamTower = get_nearest_tower_to_loc(t_sets[SET_BUILDING_ENEMY].towers, loc)
		local tLoc = overLocTower and overLocTower.lastSeen.location
		local dist = overLocTower
				and ((tLoc.x-loc.x)^2 + (tLoc.y-loc.y)^2)^0.5
		local distTeam = overLocTeamTower
				and ((overLocTeamTower.lastSeen.location.x-loc.y)^2
					+ (overLocTeamTower.lastSeen.location.y-loc.y)^2)^0.5
		if (overLocTower and overLocTeamTower and distTeam < dist)
				or (not overLocTower and overLocTeamTower) then
			tLoc = overLocTeamTower.lastSeen.location
			overLocTower = overLocTeamTower
			dist = distTeam
		end
		
		loc_cache[x][y] = overLocTower
				and ((loc.x-tLoc.x)^2 + (loc.y-tLoc.y)^2)^0.5
					< overLocTower.attackRange
				and overLocTower
				or false
		
		
		-- TODO minor optim, use distance to fill cache in a known-true square
	end
	if overLocTower and (not requireTeam or overLocTower.team == requireTeam) then
		local tLoc = overLocTower.lastSeen.location
		
		return overLocTower, ((tLoc.x - loc.x)^2 + (tLoc.y - loc.y)^2)^0.5, overLocTower
	end
end
local get_tower_over_location = Set_GetTowerOverLocation

local t_sets_platter = {{units={}}, {units={}}}
local function update_towers_near_allied_heroes() -- sub func to Set_GetTowersNearAlliedHeroes() below
	local tGsiPlayers = GSI_GetTeamPlayers(TEAM)
	--t_sets_platter[1].units = {} t_sets_platter[2].units = {}

	--local DEFAULT_NEARBY_LIMIT_DISTANCE = 2000
	
	local tBuildingListAllied = t_sets[SET_BUILDING_ALLIED].towers
	local tUnits = t_sets_platter[1].units
	local preTotal = #tUnits
	local total=0
	if tBuildingListAllied then
		for i=1,#tBuildingListAllied,1 do
			local gsiThisTower = tBuildingListAllied[i]
			local towerLoc = gsiThisTower.lastSeen.location
			-- if not bUnit_IsNullOrDead(gsiThisTower) then  -- TODO Raises questions about hUnit scope if buildings are not to be updated each frame. 
			for n=1,TEAM_NUMBER_OF_PLAYERS,1 do
				local playerLoc = tGsiPlayers[n].lastSeen.location
				if ((towerLoc.x-playerLoc.x)^2 + (towerLoc.y-playerLoc.y)^2)^0.5
						< 2000 then
					total = total + 1
					tUnits[total] = gsiThisTower
					break
				end
			end
			-- else
				-- remove(t_sets[SET_BUILDING_ENEMY], i) -- TODO If this is the "sure thing", it probably still needs a backup, like a check every mod(t) where t = time it takes for unit to transition from dead to null
			-- end
		end
	end
	for i=total+1,preTotal do
		tUnits[i] = nil
	end
	local tBuildingListEnemy = t_sets[SET_BUILDING_ENEMY].towers
	local tUnits = t_sets_platter[2].units
	preTotal = #tUnits
	total = 0
	if tBuildingListEnemy then
		for i=#tBuildingListEnemy,1,-1 do
			local gsiThisTower = tBuildingListEnemy[i]
			local towerLoc = gsiThisTower.lastSeen.location
			-- if not bUnit_IsNullOrDead(gsiThisTower) then --
			for n=1,TEAM_NUMBER_OF_PLAYERS,1 do
				local playerLoc = tGsiPlayers[n].lastSeen.location
				if ((towerLoc.x-playerLoc.x)^2 + (towerLoc.y-playerLoc.y)^2)^0.5
						< 2000 then
					total = total + 1
					tUnits[total] = gsiThisTower
					break;
				end
			end
			-- else
				-- remove(t_sets[SET_BUILDING_ENEMY], i) -- TODO If this is the "sure thing", it probably still needs a backup, like a check every mod(t) where t = time it takes for unit to transition from dead to null
			-- end
		end
	end
	for i=total+1,preTotal do
		tUnits[i] = nil
	end
end

function Set_GetTowersNearAlliedHeroes()
	if updated_towers_time_data.currFrame ~= updated_towers_frame_time then
		update_towers_near_allied_heroes()
		updated_towers_frame_time = updated_towers_time_data.currFrame
	end
	if t_sets_platter[1].units[1] or t_sets_platter[2].units[1] then
		return t_sets_platter
	end
	return EMPTY_TABLE
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
		local thisDist = ((location.x-thisCreepSetLoc.x)^2 + (location.y-thisCreepSetLoc.y)^2)^0.5
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
		local thisDist = ((location.x-thisTowerLoc.x)^2 + (location.y-thisTowerLoc.y)^2)^0.5
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
	return fountain, ((location.x-fountain.x)^2 + (location.y-fountain.y))^0.5
end

-- k-d tree, or something more simplistic?. tower-quadrant cache.
function Set_GetNearestTeamBuildingToLoc(team, loc, notShrine)
	return get_nearest_tower_to_loc(t_sets[team == TEAM and SET_BUILDING_ALLIED or SET_BUILDING_ENEMY].units, loc, notShrine)
end

function Set_InformBuildingFell(gsiBuilding)
	local setSearched = gsiBuilding.team == TEAM
			and t_sets[SET_BUILDING_ALLIED].towers or t_sets[SET_BUILDING_ENEMY].towers
	
	for iKey,tableRef in next,setSearched do
		if gsiBuilding == tableRef then
			
			remove(setSearched, iKey)
			break;
		end
	end
	local setSearched = gsiBuilding.team == TEAM
			and t_sets[SET_BUILDING_ALLIED].units or t_sets[SET_BUILDING_ENEMY].units
	for iKey,tableRef in next,setSearched do
		if gsiBuilding == tableRef then
			
			remove(setSearched, iKey)
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
				get_nearest_tower_to_loc(t_sets[SET_BUILDING_ALLIED].towers, gsiPlayer.lastSeen.location)
		return timeData.nearTeamTower, timeData.nearTeamTowerDistance
	else
		if timeData.nearEnemyTower and not bUnit_IsNullOrDead(timeData.nearEnemyTower) then
			return timeData.nearEnemyTower, timeData.nearEnemyTowerDistance
		end
		timeData.nearEnemyTower, timeData.nearEnemyTowerDistance =
				get_nearest_tower_to_loc(t_sets[SET_BUILDING_ENEMY].towers, gsiPlayer.lastSeen.location)
		return timeData.nearEnemyTower, timeData.nearEnemyTowerDistance
	end
end

function Set_GetEnemyTowerPlayerIsUnder(gsiPlayer)
	local nearestTower, distToTower = Set_GetTowerOverLocation(gsiPlayer.lastSeen.location, ENEMY_TEAM)
	if not nearestTower then return false; end
	return nearestTower, distToTower
end

local re_gehsnah = {{units={}}}
function Set_GetEnemyHeroSetsNearAlliedHeroes(range) -- TEMPORARY PATCHWORK FUNC
	local tTeamPlayers = GSI_GetTeamPlayers(TEAM)
	range = range or 2200
	tSet = re_gehsnah
	local tEnemyHeroes = GSI_GetTeamPlayers(ENEMY_TEAM)
	local total = 0
	local heroUnits = tSet[1].units
	if tEnemyHeroes then
		for iEnemy=1,#tEnemyHeroes,1 do
			local gsiThisHero = tEnemyHeroes[iEnemy]
			local heroLoc = gsiThisHero.lastSeen.location
			if not gsiThisHero.typeIsNone then
				for n=1,TEAM_NUMBER_OF_PLAYERS,1 do
					local alliedLoc = tTeamPlayers[n].lastSeen.location
					if ((heroLoc.x-alliedLoc.x)^2 + (heroLoc.y-alliedLoc.y)^2)^0.5 
							< range then
						total = total + 1
						heroUnits[total] = gsiThisHero
						break;
					end
				end
			end
		end
	end
	for i=total+1,#heroUnits do
		heroUnits[i] = nil
	end
	if tSet[1].units[1] then
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
				local enemyLoc = gsiThisHero.lastSeen.location
				local dist = ((playerLocation.x-enemyLoc.x)^2 + (playerLocation.y-enemyLoc.y)^2)^0.5
				if radius > dist then
					insert(tInRadius, gsiThisHero)
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
	local radSize = 0
	local outSize = 0
	if tEnemyHeroes then
		for n=1,#tEnemyHeroes,1 do
			local gsiThisHero = tEnemyHeroes[n]
			if ( not gsiThisHero.typeIsNone and not pUnit_IsNullOrDead(gsiThisHero) )
					or (forAnalyticsTime and IsHeroAlive(gsiThisHero.playerID)
						and gsiThisHero.lastSeen.timeStamp + forAnalyticsTime > GameTime()
					) then
				local enemyLoc = gsiThisHero.lastSeen.location
				local dist = ((location.x-enemyLoc.x)^2 + (location.y-enemyLoc.y)^2)^0.5
				if radius > dist then
					radSize = radSize + 1
					tInRadius[radSize] = gsiThisHero
				elseif outer > dist then
					outSize = outSize + 1
					tOuter[outSize] = gsiThisHero
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
			local alliedLoc = gsiThisHero.lastSeen.location
			if radius > ((playerLocation.x-alliedLoc.x)^2 + (playerLocation.y-alliedLoc.y)^2)^0.5 then
				insert(tInRadius, gsiThisHero)
			end
		end
	end
	if tInRadius[1] then
		recycle_empty = {}
		return tInRadius
	end
	return EMPTY_TABLE
end

-------- Set_GetTeamHeroesInLocRad()
function Set_GetTeamHeroesInLocRad(team, loc, rad)
	local tHeroes = team == TEAM and GSI_GetTeamPlayers(TEAM) or GSI_GetTeamPlayers(ENEMY_TEAM)
	local tInRadius = recycle_empty or {}
	for n=1,#tHeroes,1 do
		local gsiThisHero = tHeroes[n]
		if not pUnit_IsNullOrDead(gsiThisHero) then
			local heroLoc = gsiThisHero.lastSeen.location
			if rad > ((loc.x-heroLoc.x)^2 + (loc.y-heroLoc.y)^2)^0.5 then
				insert(tInRadius, gsiThisHero)
			end
		end
	end
	if tInRadius[1] then
		recycle_empty = {}
		return tInRadius
	end
	return EMPTY_TABLE
end

function Set_GetEnemyHeroesInLocRad(loc, rad, forAnalyticsTime)
	local tEnemies = GSI_GetTeamPlayers(ENEMY_TEAM)
	local tInRadius = recycle_empty or {}
	for n=1,#tEnemies,1 do
		local thisEnemy = tEnemies[n]
		if not pUnit_IsNullOrDead(thisEnemy)
				or (forAnalyticsTime and thisEnemy.lastSeen.timeStamp + forAnalyticsTime
					> GameTime()
				) then
			local enemyLoc = thisEnemy.lastSeen.location
			if rad > ((loc.x-enemyLoc.x)^2 + (loc.y-enemyLoc.y)^2)^0.5 then
				insert(tInRadius, thisEnemy)
			end
		end
	end
	if tInRadius[1] then
		recycle_empty = {}
		return tInRadius
	end
	return EMPTY_TABLE
end

function Set_GetAlliedHeroesInLocRad(gsiPlayer, loc, radius, includeSelf)
	local tAlliedHeroes = GSI_GetTeamPlayers(TEAM)
	local tInRadius = recycle_empty or {}
	for n=1,#tAlliedHeroes,1 do
		local gsiThisHero = tAlliedHeroes[n]
		if (includeSelf or gsiThisHero ~= gsiPlayer)
				and not pUnit_IsNullOrDead(gsiThisHero) then
			local alliedLoc = gsiThisHero.lastSeen.location
			if radius > ((loc.x-alliedLoc.x)^2 + (loc.y-alliedLoc.y)^2)^0.5 then
				insert(tInRadius, gsiThisHero)
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
				local alliedLoc = thisHero.lastSeen.location
				local dist = ((location.x-alliedLoc.x)^2 + (location.y-alliedLoc.y)^2)^0.5
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
					or (forAnalyticsTime and thisEnemy.lastSeen.timeStamp + forAnalyticsTime
						> GameTime()
					)then
				local enemyLoc = thisEnemy.lastSeen.location
				local dist = ((location.x-enemyLoc.x)^2 + (location.y-enemyLoc.y)^2)^0.5
				if dist < nearestDistance then
					nearestDistance = dist
					nearestHero = thisEnemy
				end
			end
		end
	end
	return nearestHero, nearestDistance
end

function Set_GetNearestHeroToLocation(location, forAnalyticsTime)
	local allied, distAllied = Set_GetNearestAlliedHeroToLocation(location)
	local enemy, distEnemy = Set_GetNearestEnemyHeroToLocation(location, forAnalyticsTime)
	if distAllied > distEnemy then
		return allied, distAllied
	end
	return enemy, distEnemy
end

function Set_GetFurthestEnemyHeroToLocation(location, forAnalyticsTime, heroTbl)
	local furthestHero
	local furthestDistance = 0
	local enemyHeroesList = heroTbl or GSI_GetTeamPlayers(ENEMY_TEAM)
	if enemyHeroesList then
		for i=1,#enemyHeroesList,1 do
			local thisEnemy = enemyHeroesList[i]
			if not pUnit_IsNullOrDead(thisEnemy)
					or (forAnalyticsTime and thisEnemy.lastSeen.timeStamp + forAnalyticsTime > GameTime())then
				local enemyLoc = thisEnemy.lastSeen.location
				local dist = ((location.x-enemyLoc.x)^2 + (location.y-enemyLoc.y)^2)^0.5
				if dist > furthestDistance then
					furthestDistance = dist
					furthestHero = thisEnemy
				end
			end
		end
	end
	return furthestHero, furthestDistance
end

local t_creeps_platter = {}
function Set_GetCreepSetsNearAlliedHeroes() -- nb. This is naturally cleaned by LHP create_future_damage_lists__job to save looping each sets creeps
	if TEST and GetBot() ~= TEAM_CAPTAIN_UNIT then print(debug.traceback()) end
	local tGsiPlayers = GSI_GetTeamPlayers(TEAM)
	local tSets = t_creeps_platter
	local total = 0
	local tCreepSetsAllied = t_sets[SET_CREEP_ALLIED]
	for s=1,#tCreepSetsAllied,1 do
		local creepSetCenter = tCreepSetsAllied[s].center
		for n=1,TEAM_NUMBER_OF_PLAYERS,1 do
			local playerLoc = tGsiPlayers[n].lastSeen.location
			if ((creepSetCenter.x-playerLoc.x)^2 + (creepSetCenter.y-playerLoc.y)^2)^0.5 
					< ALLOWABLE_CREEP_SET_DIAMETER then
				total = total + 1
				tSets[total] = tCreepSetsAllied[s]
				break;
			end
		end
	end
	local tCreepSetsEnemy = t_sets[SET_CREEP_ENEMY]
	for s=1,#tCreepSetsEnemy,1 do
		local creepSetCenter = tCreepSetsEnemy[s].center
		for n=1,TEAM_NUMBER_OF_PLAYERS,1 do
			local playerLoc = tGsiPlayers[n].lastSeen.location
			if ((creepSetCenter.x-playerLoc.x)^2 + (creepSetCenter.y-playerLoc.y)^2)^0.5 
					< ALLOWABLE_CREEP_SET_DIAMETER then
				total = total + 1
				tSets[total] = tCreepSetsEnemy[s]
				break;
			end
		end
	end
	for i=total+1,#tSets do
		tSets[i] = nil
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
			insert(theseSets, tCreepSetsAllied[s])
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
	local playerLoc = gsiPlayer.lastSeen.location
	
	for s=1,#tCreepSetsAllied,1 do
		local thisCreepSet = tCreepSetsAllied[s]
		local creepSetCenter = thisCreepSet.center
		if thisCreepSet.lane == lane then
			local thisDistance = ((creepSetCenter.x-playerLoc.x)^2 + (creepSetCenter.y-playerLoc.y)^2)^0.5
			if thisDistance < closestSetDistance then
				closestSetDistance = thisDistance
				closestSet = thisCreepSet
			end
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
		local creepSetCenter = thisCreepSet.center
		local thisDistance = ((creepSetCenter.x-location.x)^2 + (creepSetCenter.y-location.y)^2)^0.5
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
		local creepSetCenter = thisCreepSet.center
		if thisCreepSet.lane == lane then
			local thisDistance = ((creepSetCenter.x-location.x)^2 + (creepSetCenter.y-location.y)^2)^0.5
			if thisDistance < closestSetDistance then
				closestSetDistance = thisDistance
				closestSet = thisCreepSet
			end
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
		local creepSetCenter = thisCreepSet.center
		local thisDistance = ((creepSetCenter.x-location.x)^2 + (creepSetCenter.y-location.y)^2)^0.5
		if thisDistance < closestSetDistance then
			closestSetDistance = thisDistance
			closestSet = thisCreepSet
		end
	end
	return closestSet, closestSetDistance
end

function Set_LaneFrontCrashIsReal(lane)
	return lane_front_most_recent[lane][ANE_FRONT_I__PREDICTED_WAVE_CRASH_LOC] == nil
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
		local spawnerLoc = team_lane_creep_spawner[TEAM][lane]
		for s=1,#tCreepSetsAllied,1 do
			local thisCreepSet = tCreepSetsAllied[s]
			if thisCreepSet.lane == lane then
				local setCenter = thisCreepSet.center
				local dist = ((setCenter.x-spawnerLoc.x)^2 + (setCenter.y-spawnerLoc.y)^2)^0.5 -- [[MAJOR BUG FIX v0.7]]
				if dist > greatestDistance then
					greatestDistance = dist
					alliedFront = thisCreepSet
				end
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
		local spawnerLoc = team_lane_creep_spawner[ENEMY_TEAM][lane]
		for s=1,#tCreepSetsEnemy,1 do
			local thisCreepSet = tCreepSetsEnemy[s]
			if thisCreepSet.lane == lane then
				local setCenter = thisCreepSet.center
				local dist = ((setCenter.x-spawnerLoc.x)^2 + (setCenter.y-spawnerLoc.y)^2)^0.5 -- [[MAJOR BUG FIX v0.7]]
				if dist > greatestDistance then
					greatestDistance = dist
					enemyFront = thisCreepSet
				end
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
		local creepSetCenter = tCreepSetsAllied[s].center
		for n=1,TEAM_NUMBER_OF_PLAYERS,1 do
			local playerLoc = tGsiPlayers[n].lastSeen.location
			if ((creepSetCenter.x-playerLoc.x)^2 + (creepSetCenter.y-playerLoc.y)^2)^0.5 
					< ALLOWABLE_CREEP_SET_DIAMETER then
				insert(tSets, tCreepSetsAllied[s])
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
				insert(theseSets, tCreepSetsEnemy[s])
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

function Set_GetNearestTeamOutpostInLocRad(team, loc, radius)
	local units = t_sets[SET_BUILDING_NEUTRAL].outposts
	radius = radius or 14142
	local closestOutpost
	local closestDist = 0xFFFFFF
	for i=1,#units do
		local thisOutpost = units[i]
		thisOutpost.team = thisOutpost.hUnit:GetTeam()
		if thisOutpost.team == team then
			local dist = ((loc.x-thisOutpost.lastSeen.location.x)^2 + (loc.y-thisOutpost.lastSeen.location.y)^2)^0.5
			if dist <= radius and dist < closestDist then
				closestDist = dist
				closestOutpost = thisOutpost
			end
		end
	end
	return closestOutpost, closestDist
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
				["throttleUpdateLaneFronts"] = Time_CreateThrottle(THROTTLE_UPDATE_LANE_FRONTS),
				-- TODO Really like a fightclimate typed throttle that increases delta when fighting
				-- -| so that I can imply that fightclimate will become more robust and gamified.
				["throttleUpdateNeutrals"] = Time_CreateThrottle(THROTTLE_UPDATE_NEUTRALS),
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
