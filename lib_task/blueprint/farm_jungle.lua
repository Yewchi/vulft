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

JUNGLE_CAMP_EASY = 1
JUNGLE_CAMP_MEDIUM = 2
JUNGLE_CAMP_HARD = 3
JUNGLE_CAMP_ANCIENT = 4

JUNGLE_CAMP_APPROX_HEALTH = 1
JUNGLE_CAMP_APPROX_DPS = 2

local BASIC_FACTOR = 0.75
local PIERCE_FACTOR = 0.5

local EASY_HP = 240*3 + (325+400)/0.95 	-- EASY 1483 ehp
local EASY_DPS = (58 / 1.35)*BASIC_FACTOR -- EASY 32 dps
local MEDIUM_HP = 600/0.85 + 500*2/0.95	-- MED	1758 ehp
local MEDIUM_DPS = (40*2*PIERCE_FACTOR + 40*1.4*BASIC_FACTOR)/1.35 -- MED 61 dps
local HARD_HP = 950/0.79 + 700/0.85 -- HARD 2026 ehp
local HARD_DPS = 52/1.35 + 41/1.3 -- HARD 70 dps
local ANCIENT_HP = (1400 + 800*2)/0.9 -- ANCIENT 3333 ehp
local ANCIENT_DPS = (62 + 88*BASIC_FACTOR)/1.44 -- ANCIENT 88 dps

local average_difficulty_factors = {
	[JUNGLE_CAMP_EASY] = {EASY_HP, EASY_DPS},
	[JUNGLE_CAMP_MEDIUM] = {MEDIUM_HP, MEDIUM_DPS},
	[JUNGLE_CAMP_HARD] = {HARD_HP, HARD_DPS},
	[JUNGLE_CAMP_ANCIENT] = {ANCIENT_HP, ANCIENT_DPS}
}

local CLOSEST_NEUTRALS_VALID_TIME = 2
local SPAWNER_STATUS_MISSING = 1
local SPAWNER_STATUS_UNKNOWN = 2
local SPAWNER_STATUS_AVAILABLE = 3

local CLOSEST_NEUTRALS_I__SPAWNER = 1
local CLOSEST_NEUTRALS_I__SPAWNER_INDEX = 2
local CLOSEST_NEUTRALS_I__EXPIRES = 3

local INCENTIVISE_JUNGLE_STAKES_DISTANCE = MAP_COORDINATE_BOUND_NUMERICAL*2

SPAWNER_STATUS = {
	["MISSING"] = 1,
	["UNKNOWN"] = 2,
	["AVAILABLE"] = 3
}

local MAX_DIFFICULTY_LIMIT = 4
SPAWNER_TYPE = {
	[1] = 1,
	[2] = 2,
	[3] = 3,
	[4] = 4,
	["small"] = 1,
	["medium"] = 2,
	["large"] = 3,
	["ancient"] = 4
}
local SPAWNER_TYPE = SPAWNER_TYPE

local t_unit_closest_neutrals = {}
local t_spawner
local t_spawner_status = {}

local confirmed_request_denials_until_next_cycle = {} -- Don't farm that pack, it's mine!!

local dawdle_handle

local sqrt = math.sqrt
local abs = math.abs
local max = math.max
local min = math.min

local function register_set_farm_request_jungle(gsiPlayer, creepSet, extrapolatedXeta)
	-- If Lion requests: Anti-Mage can foresee farming that within the next cycle: Deny request until next cycle.
	-- If Lion requests: Anti-Mage is on the other side of the map, and is farming lane: Accept request.
	-- If Anti-Mage requests: Accept request.
	
	if not confirmed_request_denials_until_next_cycle[creepSet] then
		confirmed_request_denials_until_next_cycle[creepSet] = {}
	end
	local confirmedDenial = confirmed_request_denials_until_next_cycle[creepSet]
	confirmedDenial.player = gsiPlayer
	confirmedDenial.extrapolatedXeta = extrapolatedXeta
end

local function time_to_kill(gsiPlayer, difficulty)
	return average_difficulty_factors[difficulty][JUNGLE_CAMP_APPROX_HEALTH]*gsiPlayer.hUnit:GetAttackSpeed()/gsiPlayer.hUnit:GetAttackDamage()*0.9
end
local function time_to_kill_jungle_objective(gsiPlayer, objective)
	return time_to_kill(gsiPlayer, objective.jungleDifficulty)
end
local function estimated_time_til_completed(gsiPlayer, objective)
	return time_to_kill_jungle_objective(gsiPlayer, objective) + Math_PointToPointDistance2D(gsiPlayer.lastSeen.location, objective.lastSeen.location)
end

function FarmJungle_Initialize()
	dawdle_handle = Dawdle_GetTaskHandle()
	local spawners = GetNeutralSpawners()
	-- copy spawners out of userdata -- This is almost definitely not neccessary -- TODO
	t_spawner = {}
	for k,v in pairs(spawners) do
		local thisSpawner = {}
		for l,m in pairs(v) do
			if (l == "location") then
				thisSpawner[l] = Vector(m.x, m.y, m.z)
			else
				thisSpawner[l] = m
			end
		end
		t_spawner[k] = thisSpawner
	end
	FarmJungle_Init = nil
end

-- TODO
-- TODO
-- TODO Jungle objective MUST implement an iObjective.jugnleDifficulty flag
-- TODO
-- TODO
function Farm_TrySetRequestJungle(gsiPlayer, creepSet, extrapolatedXeta)
	local confirmedDenial = confirmed_request_denials_until_next_cycle[creepSet]
	if confirmedDenial then
		if confirmedDenial.playerDenying == gsiPlayer then
			return true
		end
		if gsiPlayer.vibe.greed * extrapolatedXeta > 
				confirmedDenial.player.vibe.greed * confirmedDenial.player.vibe.extrapolatedXeta then
			Task_InformObjectiveDisallow(confirmedDenial.player, {creepSet, DENIAL_TYPE_FARM_JUNGLE_SET})
			register_set_farm_request_jungle(gsiPlayer, creepSet, extrapolatedXeta)
			return true
		end
		return false
	end
	register_set_farm_request_jungle(gsiPlayer)
end

-- Used for deducing cost of health and time to farming, or generic deductions about physical damage stand-offs
function Farm_JungleCampClearViability(gsiPlayer, difficulty)
	local standAndTakeItTime = gsiPlayer.lastSeenHealth / (average_difficulty_factors[difficulty][JUNGLE_CAMP_APPROX_DPS]*Unit_GetArmorPhysicalFactor(gsiPlayer))
	return standAndTakeItTime/time_to_kill(gsiPlayer, difficulty)
end
local clear_viability = Farm_JungleCampClearViability

function FarmJungle_GetGreedyCantJungle(gsiPlayer, players, dontIndex)
	local timeData = gsiPlayer.time.data
	if not dontIndex and timeData.greedyPlayer then
		return timeData.greedyPlayer
	end
	local greedyPlayer
	local greedyWeakScore = 0
	for i=1,#players do
		local thisPlayer = players[i]
		local score = thisPlayer.vibe.greedRating
				* 1/Farm_JungleCampClearViability(thisPlayer, JUNGLE_CAMP_ANCIENT)
		if score > greedyWeakScore then
			greedyPlayer = thisPlayer
			greedyWeakScore = score
		end
	end
	if not dontIndex then
		timeData.greedyPlayer = greedyPlayer
	end
	return greedyPlayer
end

local function get_difficulty_limit(gsiPlayer)
	local viabilityRequired = gsiPlayer.isRanged and 0.66 or 1
	for i=4,1,-1 do
		if clear_viability(gsiPlayer, i) > viabilityRequired then
			return i
		end
	end
	return false
end

function Farm_CancelConfirmedDenialJungle(gsiPlayer, objectiveDenied)
	confirmed_request_denials_until_next_cycle[objectiveDenied] = nil
end

function Farm_CancelAnyConfirmedDenialsJungle(gsiPlayer)
	for creepSet,tConfirmedDenial in pairs(confirmed_request_denials_until_next_cycle) do
		if tConfirmedDenial.player == gsiPlayer then 
			confirmed_request_denials_until_next_cycle[creepSet] = nil
		end
	end
end

local jungle_incentive_update = {}; for i=1,TEAM_NUMBER_OF_PLAYERS do jungle_incentive_update[i] = 0 end
function FarmJungle_IncentiviseJungling(gsiPlayer, objective)
	-- Funky, plausible flips TODO
	if gsiPlayer.level < 5 then return; end
	if jungle_incentive_update[gsiPlayer.nOnTeam] < GameTime() then
		jungle_incentive_update[gsiPlayer.nOnTeam] = GameTime() + 0.897
		local objectiveLoc = objective.lastSeen and objective.lastSeen.location
				or objective.center
		if objective.type == UNIT_TYPE_BUILDING
				or (objective.type ~= UNIT_TYPE_IMAGINARY
					and Vector_PointDistance2D(
						gsiPlayer.lastSeen.location,
						objectiveLoc
					) < 1100
				) then
			return;
		end
		local nearbyEnemies = Set_GetEnemyHeroesInPlayerRadius(gsiPlayer, 1800, 5)
		if nearbyEnemies[1] then 
			return;
		end
		local objectiveNearbyEnemies = Set_GetEnemyHeroesInLocRadOuter(objectiveLoc, 1750, 1750, 1)
		if objectiveNearbyEnemies[1] then 
			return;
		end
	--	local laneTower = GSI_GetLowestTierDefensible(ENEMY_TEAM,
	--			objective.lane or Map_GetLaneValueOfMapPoint(objectiveLoc)
	--		)
		local distEndgameFactor = (INCENTIVISE_JUNGLE_STAKES_DISTANCE - abs(objectiveLoc.x + objectiveLoc.y))/
				INCENTIVISE_JUNGLE_STAKES_DISTANCE
		local nearbyAllies = Set_GetAlliedHeroesInPlayerRadius(gsiPlayer, 2200, true)
		if #nearbyAllies > 1 then
			local hpp = gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth
			local effectiveHpp = hpp * gsiPlayer.hUnit:GetArmor() -- effective hit point >percent<
			local allowed = (#nearbyAllies / (2.2 + 0.8*GSI_GetAliveAdvantageFactor())) + distEndgameFactor
			for i=1,#nearbyAllies do
				local allied = nearbyAllies[i]
				if allied ~= gsiPlayer
						and effectiveHpp
--[[PRIMITIVE]]					< allied.lastSeenHealth/allied.maxHealth -- flips on dmg taken BAD
									* allied.hUnit:GetArmor() then
					allowed = allowed - 1
					if allowed < 0 then
						return;
					end
				end
			end
			Task_IncentiviseTask(gsiPlayer, dawdle_handle,
					distEndgameFactor * (gsiPlayer.level >= 25 and 120
							or 27 * sqrt(gsiPlayer.level-5)
						) * gsiPlayer.lastSeenHealth/gsiPlayer.maxHealth,
					14
				)
		end
	end
end

local CLEANUP_INTERVAL = 60
local ALLOWED_RECYCLE_TBL_SIZE = 20
local cleanup_throttle = Time_CreateThrottle(CLEANUP_INTERVAL)
local recycle_closest_neutrals = {}
function FarmJungle_GetNearestUncertainUncleared(gsiUnit, difficultyLimit)
	-- TODO Tempest double / illusions / dominated unit jungle farming
	-- TODO Optimize, fun stuff
	if DotaTime() <= 60 then
		return false
	end
	local cached = t_unit_closest_neutrals[gsiUnit]
	local difficultyLimit = SPAWNER_TYPE[difficultyLimit] or MAX_DIFFICULTY_LIMIT
	local unitLoc = gsiUnit.lastSeen.location
	--print(cached and SPAWNER_TYPE[cached[CLOSEST_NEUTRALS_I__SPAWNER].type], difficultyLimit)
	if cached and (SPAWNER_TYPE[cached[CLOSEST_NEUTRALS_I__SPAWNER].type] <= difficultyLimit) then
		local spawnerIndex = cached[CLOSEST_NEUTRALS_I__SPAWNER_INDEX]
		if GameTime() > cached[CLOSEST_NEUTRALS_I__EXPIRES]
				or t_spawner_status[spawnerIndex]
						== SPAWNER_STATUS_MISSING then -- other unit updated spawner?
			table.insert(recycle_closest_neutrals, cached)
			t_unit_closest_neutrals[gsiUnit] = nil
			-- Expired - Go to find closest
		else
			local loc = cached[CLOSEST_NEUTRALS_I__SPAWNER].location
			if IsLocationVisible(loc) and Vector_PointDistance2D(unitLoc, loc) < 250 then
				local nearbyNeutrals = gsiUnit.hUnit:GetNearbyNeutralCreeps(1200)
				if not nearbyNeutrals or not nearbyNeutrals[1] then
					-- found unknown camp is empty
					t_spawner_status[spawnerIndex] = SPAWNER_STATUS_MISSING
					table.insert(recycle_closest_neutrals, cached)
					t_unit_closest_neutrals[gsiUnit] = nil
					-- Camp cleared - Go to find closest
				else -- visible, probably have the right camp
					return loc,
							t_spawner_status[spawnerIndex] == SPAWNER_STATUS_AVAILABLE,
							nearbyNeutrals
				end
			else -- Not visible, don't search
				return loc,
						t_spawner_status[spawnerIndex] == SPAWNER_STATUS_AVAILABLE,
						gsiUnit.hUnit:GetNearbyNeutralCreeps(1200)
			end
		end
	end
	if cleanup_throttle:allowed() then
		local cleanTime = GameTime() - CLEANUP_INTERVAL / 3
		local n=0
		for i=ALLOWED_RECYCLE_TBL_SIZE+1,#recycle_closest_neutrals do
			recycle_closest_neutrals[i] = nil
		end
		for key,tbl in pairs(t_unit_closest_neutrals) do
			if tbl[CLOSEST_NEUTRALS_I__EXPIRES] < cleanTime then
				table.insert(recycle_closest_neutrals, cached)
				t_unit_closest_neutrals[gsiUnit] = nil
				n = n + 1
			end
		end
		if DEBUG then
			INFO_print(string.format(
					"[farm_jungle] Expired cached gsiUnit closest neutral proximity count: %d.",
					n
				)
			)
		end
	end
	-- Find closest unknown or available, or dry run set nearest unknown to missing without
	-- - a camp returning
	local t_spawner = t_spawner
	local closestDist = 0xFFFF
	local closestSpawner
	local closestIndex 
	
	for i=1,#t_spawner do
		local thisSpawner = t_spawner[i]
		if t_spawner_status[i] ~= SPAWNER_STATUS_MISSING then
			local thisDist = Vector_PointDistance2D(unitLoc, thisSpawner.location)
			if thisDist < closestDist and t_spawner_status[i] ~= SPAWNER_STATUS_MISSING
					and SPAWNER_TYPE[thisSpawner.type] <= difficultyLimit then
				closestDist = thisDist
				closestSpawner = thisSpawner
				closestIndex = i
			end
		end
	end
	if not closestSpawner then
		if VERBOSE then
			VEBUG_print(string.format("[farm_jungle] No suitable spawners found for %s. Difficulty limit: %d.",
						gsiUnit.shortName or gsiUnit.hUnit:GetUnitName(), difficultyLimit
					)
				)
		end
		return false, false, false
	end
	local loc = closestSpawner.location
	local nearbyNeutrals = gsiUnit.hUnit:GetNearbyNeutralCreeps(1200)
	if IsLocationVisible(loc) and Vector_PointDistance2D(unitLoc, loc) < 250 then -- TODO TEMP
		if nearbyNeutrals and nearbyNeutrals[1]
			-- bugged if camps are pulled into other camps by kiting
				and Vector_PointDistance2D(loc, nearbyNeutrals[1]:GetLocation())
					< 600 then
			t_spawner_status[closestIndex] = SPAWNER_STATUS_AVAILABLE
			local newCached = table.remove(recycle_closest_neutrals) or {}
			newCached[CLOSEST_NEUTRALS_I__SPAWNER] = closestSpawner
			newCached[CLOSEST_NEUTRALS_I__SPAWNER_INDEX] = closestIndex
			newCached[CLOSEST_NEUTRALS_I__EXPIRES] = GameTime() + CLOSEST_NEUTRALS_VALID_TIME
			t_unit_closest_neutrals[gsiUnit] = newCached
			return loc, true, nearbyNeutrals
		end
		t_spawner_status[closestIndex] = SPAWNER_STATUS_MISSING
		return false, false, false
	end
	local newCached = table.remove(recycle_closest_neutrals) or {}
	newCached[CLOSEST_NEUTRALS_I__SPAWNER] = closestSpawner
	newCached[CLOSEST_NEUTRALS_I__SPAWNER_INDEX] = closestIndex
	newCached[CLOSEST_NEUTRALS_I__EXPIRES] = GameTime() + CLOSEST_NEUTRALS_VALID_TIME
	t_unit_closest_neutrals[gsiUnit] = newCached

	return loc, false, nearbyNeutrals and (nearbyNeutrals[1] and nearbyNeutrals) or false
end
local get_nearest_uncertain_uncleared = FarmJungle_GetNearestUncertainUncleared

function FarmJungle_SimpleRunLimitTime(gsiPlayer, timeAllowed, desiredAfterFarmed,
		withinRangeOf, range)
	-- Temporary
	local difficultyLimit = get_difficulty_limit(gsiPlayer)
	if not difficultyLimit then
		--print(gsiPlayer.shortName, "no difficulty")
		return false;
	end
	local loc, available, creeps = get_nearest_uncertain_uncleared(gsiPlayer, difficultyLimit)
	if VERBOSE then
		VEBUG_print(string.format("%s in FarmJungle_SimpleRunLimitTime(). t=%d, difficulty=%d, "..
					"loc=(%.1f,%.1f,%.1f), avail=%s, creepsValid=%s",
					gsiPlayer.shortName, timeAllowed, difficultyLimit,
					loc and loc.x or -0, loc and loc.y or -0, loc and loc.z or -0,
					tostring(available), creeps and creeps[1] and "yes" or "no"
				)
			)
	end
	if not loc then
		--print("no loc")
		return false;
	elseif withinRangeOf and range and Vector_PointDistance2D(withinRangeOf, loc)
				> range then
		
		return false;
	end
	if not creeps or not creeps[1] then
		--print("no creeps")
		Positioning_MoveDirectly(gsiPlayer, loc)
		return true;
	end
	local lowHp = 0xFFFF
	local lowCreep = nil
	for i=1,#creeps do
		if creeps[i]:GetHealth() < lowHp then
			lowHp = creeps[i]:GetHealth()
			lowCreep = creeps[i]
		end
	end
	if not lowCreep then
		--print("no low")
		return false;
	end
	--print(lowCreep, "low", lowHp*1.66 > gsiPlayer.lastSeenHealth, lowCreep and Lhp_CageFightKillTime(gsiPlayer, cUnit_NewSafeUnit(lowCreep)))
	-- the line below requires persistance for units which do not have the required combat efficiency
	-- - to farm the pack, so it's removed and difficulty will need to be determined by pack type
--	if not lowCreep or lowHp*1.66 > gsiPlayer.lastSeenHealth or Lhp_CageFightKillTime(gsiPlayer, cUnit_NewSafeUnit(lowCreep)) > timeAllowed then
--		return false
--	end
--	print(Unit_GetTimeTilNextAttackStart(gsiPlayer) - 0.15, math.max(0.1, gsiPlayer.attackRange
--					- Vector_PointDistance2D(gsiPlayer.lastSeen.location, lowCreep:GetLocation())
--					- 120
--				) / gsiPlayer.currentMovementSpeed)
	if Unit_GetTimeTilNextAttackStart(gsiPlayer) - 0.1
			< math.max(0, gsiPlayer.attackRange
					- Vector_PointDistance2D(gsiPlayer.lastSeen.location, lowCreep:GetLocation())
					- 120
				) / gsiPlayer.currentMovementSpeed
			or Vector_UnitFacingUnit(lowCreep, gsiPlayer) < 0 then
		gsiPlayer.hUnit:Action_AttackUnit(lowCreep, false)
		
	else
		
		Positioning_MoveDirectly(gsiPlayer,
				Vector_Addition(
						gsiPlayer.lastSeen.location, 
						desiredAfterFarmed or Vector_ScalarMultiply2D(
								Vector_UnitDirectionalPointToPoint(
										lowCreep:GetLocation(),
										gsiPlayer.lastSeen.location
									),
								300
							)
					)
			)
	end
	return true;
end
