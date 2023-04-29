BUILDING_PROJECTILE_HEIGHT_ADJUST = 384 -- Approximation
BUILDING_T1_ATTACK_DAMAGE = 92
BUILDING_T2_T4_ATTACK_DAMAGE = 172 -- TODO Self kill job finds dmg
BUILDING_TOWER_ATTACK_RANGE = 880 -- GetAttackRange will show 700. Testing shows 880 from center-tower.
FOUNTAIN_ATTACK_RANGE = 1200
FOUNTAIN_ATTACK_DAMAGE = 300
FOUNTAIN_ATTACK_SPEED = 0.15
BARRACKS_TYPE_MELEE = 6
BARRACKS_TYPE_RANGE = 7
FOUNTAIN_TIER = 5

DOTA_TOWER_NUM_TIERS = 5
local UNLIKELY_CHOICE = 69 -- default, valid, reasonable, but least likely tower damage as patched
TOWER_TIER_ATTACK_DAMAGE = {UNLIKELY_CHOICE, UNLIKELY_CHOICE, UNLIKELY_CHOICE, UNLIKELY_CHOICE, UNLIKELY_CHOICE}
TOWER_TIER_ATTACK_DPS = {UNLIKELY_CHOICE, UNLIKELY_CHOICE, UNLIKELY_CHOICE, UNLIKELY_CHOICE, UNLIKELY_CHOICE}

local INVALID_TOWER_HEALTH = -1

TOTAL_BARRACKS_TEAM = 6
TOTAL_TOWERS_TEAM = 11

NUM_TOWERS_UP_TEAM = 0 -- inform late-game map pressure and task consideration
NUM_BARRACKS_UP_TEAM = 0

local team_ancient
local enemy_ancient

local GOLD_VALUES = {
	[1] = 570,
	[2] = 690,
	[3] = 785,
	[4] = 905,
	["melee"] = 888,
	["range"] = 568,
	["fillers"] = 68,
	["fort"] = 1776
}

---- building constants
local JUNGLE_STASH_HEALTH = 150
--

local t_recyclable_safe_unit_sets = {}
local t_recyclable_safe_units = {}

local t_buildings = {}
local t_buildings_index = {} -- Storing tier 4s in [team][top/bottom][4]

local t_team_lane_tier_locations = {}

local t_outposts = {}

local job_domain_gsi

do
	t_buildings_index[1] = {} -- TODO Does this force better pointer-arithmetic-based indexing?
	t_team_lane_tier_locations[1] = {}
	for team=TEAM_RADIANT,TEAM_DIRE,1 do
		t_buildings_index[team] = {}
		t_team_lane_tier_locations[team] = {}
		for lane=1,5,1 do -- table 4 and 5 are for Radiant and Dire base, and are only for valid access T4s are TOP/BOTTOM, ancient is T4 MID
			t_buildings_index[team][lane] = {--[[tiers]]}
			t_team_lane_tier_locations[team][lane] = {}
		end
	end
	t_buildings[TEAM_NEUTRAL] = {}
	t_buildings[TEAM_RADIANT] = {}
	t_buildings[TEAM_DIRE] = {}
end

function GSI_GetTeamTowers(team)
	return t_buildings_index[team]
end

function GSI_GetTeamBuildings(team)
	return t_buildings[team]
end

function GSI_GetTeamLaneTierTower(team, lane, tier)
	return t_buildings_index[team][lane][tier]
end

function GSI_GetTeamLaneTierTowerLoc(team, lane, tier)
	return t_team_lane_tier_locations[team][lane][tier]
end

function GSI_GetLowestTierTeamLaneTower(team, lane)
	local lowest
	local teamLaneTowers = t_buildings_index[team][lane]
	-- TODO Consider tier 4 internal tier is 6, melee is 4, range is 5
	for i=1,3 do
		if teamLaneTowers[i] then
			if not bUnit_IsNullOrDead(teamLaneTowers[i]) then
				return teamLaneTowers[i]
			end
		end
	end
	if teamLaneTowers[BARRACKS_TYPE_MELEE] then
		if not bUnit_IsNullOrDead(teamLaneTowers[BARRACKS_TYPE_MELEE]) then
			return teamLaneTowers[BARRACKS_TYPE_MELEE]
		end
	elseif teamLaneTowers[BARRACKS_TYPE_RANGE] then
		if not bUnit_IsNullOrDead(teamLaneTowers[BARRACKS_TYPE_RANGE]) then
			return teamLaneTowers[BARRACKS_TYPE_RANGE]
		end
	end
	return team == TEAM and team_ancient or enemy_ancient
end

-------- GSI_GetHigherTierTower() - intended for finding safe or unsafe areas, i.e. no racks
function GSI_GetHigherTierTower(tower)
	local higher
	if tower and tower.tier and tower.lane then
		higher = t_buildings_index[tower.team][tower.lane][tower.tier+1]
	end
	return higher or tower.team == TEAM and team_ancient or enemy_ancient
end

function GSI_GetHighestValueTeamLaneRacks(team, lane)
	return t_buildings_index[team][lane][BARRACKS_TYPE_MELEE]
			or t_buildings_index[team][lane][BARRACKS_TYPE_MELEE] or false
end

function GSI_GetLowestTierDefensible(team, lane)
	--print("requested building", team, lane)
	local lowestTowerOrAncient = GSI_GetLowestTierTeamLaneTower(team, lane)
	--print("got lowest tier", lowestTowerOrAncient.tier, lowestTowerOrAncient.isAncient)
	if lowestTowerOrAncient.tier and lowestTowerOrAncient.tier >= 4 then
		local lowestRacks = GSI_GetHighestValueTeamLaneRacks(team, lane)
		return lowestRacks or lowestTowerOrAncient
	end
	return lowestTowerOrAncient
end

function GSI_AnyTierUnderHealthPercent(tier, percent)
	for iLane=1,3 do
		local thisTower = t_buildings_index[TEAM][iLane][tier]
		if thisTower then
			if thisTower.lastSeenHealth / thisTower.maxHealth < percent then
				return true, thisTower
			end
		end
	end
end

function GSI_LowestTierHealthPercentWithDead(tier)
	local lowest = 1.0
	for iLane=1,3 do
		local thisTower = t_buildings_index[TEAM][iLane][tier]
		if thisTower then
			local towerHpp = thisTower.lastSeenHealth / thisTower.maxHealth
			if towerHpp < lowest then
				lowest = towerHpp
			end
		else
			return 0.0
		end
	end
	return lowest
end

function GSI_GetApproxNearestPortableStructure(team, loc)
	local laneOfLoc = Map_GetLaneValueOfMapPoint(loc)
	return GSI_GetLowestTierDefensible(team, lane)
end

local function update_team_buildings_data(list)
	for hUnit,safeUnit in pairs(list) do
		if hUnit:IsNull() or not hUnit:IsAlive() then
			safeUnit.typeIsNone = true
			t_buildings[safeUnit.team][hUnit] = nil
		elseif hUnit:CanBeSeen() then
			--print("updating", safeUnit.lane, safeUnit.tier, safeUnit.team, safeUnit.lastSeenHealth, hUnit:GetHealth(), hUnit:GetMaxHealth())
			safeUnit.lastSeen:Update(hUnit:GetLocation())
			safeUnit.maxHealth = hUnit:GetMaxHealth() ~= INVALID_TOWER_HEALTH
					and hUnit:GetMaxHealth() or safeUnit.maxHealth
			safeUnit.lastSeenHealth = hUnit:GetHealth() ~= INVALID_TOWER_HEALTH
					and hUnit:GetHealth() or safeUnit.lastSeenHealth
			safeUnit.attackPointPercent = hUnit:GetAttackPoint()
		end
	end
end
local function handle_dead_building(gsiBuilding)
	gsiBuilding.typeIsNone = true
	if gsiBuilding.lane
			and t_buildings_index[gsiBuilding.team][gsiBuilding.lane][gsiBuilding.tier] then
		if gsiBuilding.team == TEAM then
			if gsiBuilding.isTower then
				--print(gsiBuilding.name, gsiBuilding.shortName, "is a tower")
				NUM_TOWERS_UP_TEAM = NUM_TOWERS_UP_TEAM - 1
			elseif gsiBuilding.barracksType then
				NUM_BARRACKS_UP_TEAM = NUM_BARRACKS_UP_TEAM - 1
			end
		end
		t_buildings_index[gsiBuilding.team][gsiBuilding.lane][gsiBuilding.tier] = nil
		Analytics_InformBuildingFell(gsiBuilding)
		t_buildings[gsiBuilding.team][gsiBuilding.hUnit] = nil
	else






	end
end
local function update_team_buildings_none_typed(team)
	local list = t_buildings[team]
	for hUnit,safeUnit in pairs(list) do
		if hUnit:IsNull() or not hUnit:IsAlive() then
			handle_dead_building(safeUnit)
		end
	end
end
function GSI_CreateUpdateBuildingUnits()
	local function delete_none_typed__job(workingSet)
		if workingSet.datathrottle:allowed() then -- throttled data update (has none-typed check)
			local runTeam = workingSet.runTeam
			update_team_buildings_data(t_buildings[runTeam])
			workingSet.runTeam = runTeam == 3 and 2 or 3
		else -- every frame none-type will be checked
			update_team_buildings_none_typed(TEAM_RADIANT)
			update_team_buildings_none_typed(TEAM_DIRE)
		end
	end
	
	if DEBUG then
		local thisJobElapsed = 0.0
		job_domain_gsi:RegisterJob(
				function(workingSet) local prevTime = RealTime() delete_none_typed__job(workingSet) thisJobElapsed = thisJobElapsed + RealTime() - prevTime if workingSet.dbgthrottle:allowed() then DebugDrawCircle(Vector(0, 0, 0), 500, 255, 255, 255) DEBUG_print("Last 10s building none-type finding, health updates elapsed "..(thisJobElapsed*1000).."ms.".." RealTime is "..RealTime()) thisJobElapsed = 0.0 end end,
				{ ["dbgthrottle"] = Time_CreateThrottle(10),
					["datathrottle"] = Time_CreateThrottle(0.223),
					["runTeam"] = TEAM_RADIANT}, 
				"JOB_UPDATE_BUILDING_UNITS"
			)
	else
		job_domain_gsi:RegisterJob(
				delete_none_typed__job,
				{ ["datathrottle"] = Time_CreateThrottle(0.223),
					["runTeam"] = TEAM_RADIANT},
				"JOB_UPDATE_BUILDING_UNITS"
			)
	end
end

function GSI_RegisterGSIJobDomainToBuilding(jobDomainGSI)
	job_domain_gsi = jobDomainGSI
end

function bUnit_UpdateHealthAndLocation(gsiBuilding)
	local hUnitBuilding = gsiBuilding.hUnit
	gsiBuilding.lastSeen:Update(hUnitBuilding:GetLocation())
	gsiBuilding.lastSeenHealth = hUnitBuilding:GetHealth() ~= INVALID_TOWER_HEALTH
			and hUnitBuilding:GetHealth() or gsiBuilding.lastSeenHealth or gsiBuilding.maxHealth
	gsiBuilding.maxHealth = hUnitBuilding:GetMaxHealth() ~= INVALID_TOWER_HEALTH
			and hUnitBuilding:GetMaxHealth() or gsiBuilding.maxHealth
	newSafeUnit.halfSecAttack = hUnitBuilding:GetSecondsPerAttack() / 2
end

function bUnit_GetBuildingTeamGoldValue(gsiBuilding)
	local key = string.match(gsiBuilding.name, "%d")
	key = not key and string.match(gsiBuilding.name, "guys_([a-z]+)") or tonumber(key)
	return gsiBuilding.goldBounty or GOLD_VALUES[key]
end

function bUnit_IsNullOrDead(gsiBuilding)
	if not gsiBuilding.hUnit or not gsiBuilding.hUnit.IsNull or
			gsiBuilding.hUnit:IsNull() or not gsiBuilding.hUnit:IsAlive() then

		handle_dead_building(gsiBuilding)
		return true
	end
	return false
end

function bUnit_ConvertListToSafeUnits(list)
	local nCount = 0
	for i=1,#list,1 do
		local gsiUnit = t_buildings[list[i]:GetTeam()][list[i]] or bUnit_NewSafeUnit(list[i])
		if gsiUnit then
			nCount = nCount + 1
			list[nCount] = gsiUnit
		
		end
	end
	for i=nCount+1,#list do
		list[i] = nil
	end
	return list
end

function bUnit_ConvertToSafeUnit(hUnit)
	return t_buildings[hUnit:GetTeam()][hUnit] or not Unit_IsNullOrDead(hUnit) and bUnit_NewSafeUnit(hUnit, true)
end

function bUnit_IsTower(thisUnit)
	return thisUnit.isTower or (thisUnit.IsNull and not thisUnit:IsNull() and thisUnit:IsTower())
			or (t_buildings[TEAM][thisUnit] and true) or (t_buildings[ENEMY_TEAM][thisUnit] and true)
end

-- function cUnit_RecycleUnitsInSets(unitSets) -- UNIMPLMENT -- I've flipped between solutions so many times trying to get clean, readable, safe code with understandable function parameter 
	-- for i=1,#unitSets,1 do
		-- local thisUnitSet = unitSets[i]
		-- table.insert(t_recyclable_safe_unit_sets, thisUnitSet)
	-- end
-- end

-- function cUnit_CreateNewUnitWithName(hUnit, nameOfUnit)
	-- if #t_recyclable_safe_units > 0 then
		-- return table.remove(t_recyclable_safe_units) or {}
	-- elseif #t_recyclable_safe_unit_sets > 0 then
		-- t_recyclable_safe_units = table.remove(t_recyclable_safe_unit_sets)
		-- return table.remove(t_recyclable_safe_units) or {}
	-- end
	-- return {}
-- end

function GSI_GetTeamFountainUnit(team)
	return t_buildings_index[team][MAP_LOGICAL_MIDDLE_LANE][5]
end

function GSI_GetTeamAncient(team)
	if team == TEAM then return team_ancient
	elseif team == ENEMY_TEAM then return enemy_ancient end
	return nil
end

local function assign_to_building_index(gsiBuilding) -- Initialization only
	local team = gsiBuilding.team
	if gsiBuilding.isFountain then
		t_buildings_index[team][MAP_LOGICAL_MIDDLE_LANE][5] = gsiBuilding -- 4 is nil but #arr will fix
		t_buildings_index[team][MAP_LOGICAL_TOP_LANE][5] = gsiBuilding
		t_buildings_index[team][MAP_LOGICAL_BOTTOM_LANE][5] = gsiBuilding
		gsiBuilding.tier = FOUNTAIN_TIER
	else
		local tier = tonumber(string.match(gsiBuilding.name, "%d"))
		gsiBuilding.tier = tier
		if tier == 4 then
			local topT4 = t_buildings_index[team][MAP_LOGICAL_TOP_LANE][4]
			if not topT4 then -- Temp store first T4
				t_buildings_index[team][MAP_LOGICAL_TOP_LANE][4] = gsiBuilding
				gsiBuilding.lane = MAP_LOGICAL_TOP_LANE
			else -- Compare and orient
				if (team == TEAM_RADIANT and topT4.lastSeen.location.x < gsiBuilding.lastSeen.location.x)
						or (team == TEAM_DIRE and topT4.lastSeen.location.x > gsiBuilding.lastSeen.location.x) then
					t_buildings_index[team][MAP_LOGICAL_BOTTOM_LANE][4] = gsiBuilding
					gsiBuilding.lane = MAP_LOGICAL_BOTTOM_LANE
				else
					t_buildings_index[team][MAP_LOGICAL_BOTTOM_LANE][4] = topT4
					topT4.lane = MAP_LOGICAL_BOTTOM_LANE
					t_buildings_index[team][MAP_LOGICAL_TOP_LANE][4] = gsiBuilding
					gsiBuilding.lane = MAP_LOGICAL_TOP_LANE
				end
			end
		else
			local lane = string.find(gsiBuilding.name, "top")
					and MAP_LOGICAL_TOP_LANE or string.find(gsiBuilding.name, "bot")
					and MAP_LOGICAL_BOTTOM_LANE or MAP_LOGICAL_MIDDLE_LANE
			if gsiBuilding.isTower then
				t_buildings_index[team][lane][tier] = gsiBuilding
			else
				gsiBuilding.tier = gsiBuilding.barracksType
				t_buildings_index[team][lane][gsiBuilding.barracksType] = gsiBuilding
				if gsiBuilding.team == TEAM then
					NUM_BARRACKS_UP_TEAM = NUM_BARRACKS_UP_TEAM + 1
				end
			end
			gsiBuilding.lane = lane
		end
	end
	if gsiBuilding.isTower then
		t_team_lane_tier_locations[team][gsiBuilding.lane][gsiBuilding.tier]
				= gsiBuilding.lastSeen.location
		if gsiBuilding.team == TEAM then
			NUM_TOWERS_UP_TEAM = NUM_TOWERS_UP_TEAM + 1
		end
	end
end

local function bunit_new_safe_unit_no_scan(hUnit, dontIndex)
	if not hUnit or hUnit:IsNull() or not hUnit:IsAlive() then return nil end
	if t_buildings[hUnit:GetTeam()][hUnit] then return t_buildings[hUnit:GetTeam()][hUnit] end
	local maxHealth = hUnit:GetMaxHealth()

	local newSafeUnit = {}
	local unitLocation = hUnit:GetLocation()
	
	

	newSafeUnit.hUnit = hUnit
	newSafeUnit.isNull = hUnit.IsNull
	newSafeUnit.name = hUnit:GetUnitName()
	newSafeUnit.team = hUnit:GetTeam()
	newSafeUnit.lastSeen = Map_CreateLastSeenTable(Vector(unitLocation.x, unitLocation.y, unitLocation.z--[[ + BUILDING_PROJECTILE_HEIGHT_ADJUST]]))
	newSafeUnit.maxHealth = maxHealth ~= INVALID_TOWER_HEALTH and maxHealth
			or 1800
	newSafeUnit.lastSeenHealth = hUnit:GetHealth() ~= INVALID_TOWER_HEALTH
			and hUnit:GetHealth() or newSafeUnit.maxHealth
	newSafeUnit.dotaType = TEAM == hUnit:GetTeam() and BUILDING_ALLIED or BUILDING_ENEMY
	newSafeUnit.type = UNIT_TYPE_BUILDING
	newSafeUnit.isTower = hUnit:IsTower()
	newSafeUnit.isRanged = true
	newSafeUnit.isFountain = newSafeUnit.name == "dota_fountain"
	newSafeUnit.releaseProjectileZ = newSafeUnit.isTower and 170 or 20 --[[PROJECTILE BAKE]]
	newSafeUnit.getsHitZ = newSafeUnit.isTower and 144 or 20 --[[PROJECTILE BAKE]]
	newSafeUnit.attackPointPercent = hUnit:GetAttackPoint() -- updated in projtl
	newSafeUnit.halfSecAttack = hUnit:GetSecondsPerAttack() / 2
	newSafeUnit.attackRange = newSafeUnit.isTower and BUILDING_TOWER_ATTACK_RANGE
			or newSafeUnit.isFountain and FOUNTAIN_ATTACK_RANGE
			or hUnit:GetAttackRange()
	newSafeUnit.Key = Unit_Key
	-- newSafeUnit.tier = 1234
	
	local bountyReward = bUnit_GetBuildingTeamGoldValue(newSafeUnit)
	newSafeUnit.goldBounty = bountyReward
	newSafeUnit.barracksType = not newSafeUnit.isTower and not newSafeUnit.isFountain
			and string.find(newSafeUnit.name, "melee") and BARRACKS_TYPE_MELEE
			or string.find(newSafeUnit.name, "range") and BARRACKS_TYPE_RANGE or false
	newSafeUnit.isShrine = string.find(newSafeUnit.name, "filler") and true or false
	newSafeUnit.isAncient = hUnit:IsFort()
	newSafeUnit.isOutpost = string.find(newSafeUnit.name, "Outpost") and true or false
	newSafeUnit.isMangoTree = string.find(newSafeUnit.name, "mango_tree") and true or false
	newSafeUnit.isTwinGate = string.find(newSafeUnit.name, "twin_gate") and true or false
	newSafeUnit.isLamp = string.find(newSafeUnit.name, "lantern") and true or false
	if newSafeUnit.isAncient then
		if newSafeUnit.team == TEAM then
			team_ancient = newSafeUnit
		else
			enemy_ancient = newSafeUnit
		end
	end
	
	if not dontIndex then
		
		t_buildings[newSafeUnit.team][hUnit] = newSafeUnit
		
		if newSafeUnit.isTower or newSafeUnit.isFountain or newSafeUnit.barracksType then
			assign_to_building_index(newSafeUnit)
		elseif newSafeUnit.isOutpost then
			t_outposts[hUnit] = newSafeUnit
		end

	
	end


	-- updated on seen
	newSafeUnit.attackDamage = not (newSafeUnit.isTower or newSafeUnit.isFountain) and 0
			or newSafeUnit.team == TEAM and hUnit:GetAttackDamage()
			or newSafeUnit.tier and TOWER_TIER_ATTACK_DAMAGE[newSafeUnit.tier]
			or BUILDING_T1_ATTACK_DAMAGE
	
	return newSafeUnit
end
local function bunit_new_safe_unit_scan_data(hUnit, dontIndex)
	local newSafeUnit = bunit_new_safe_unit_no_scan(hUnit, dontIndex)
	if not newSafeUnit then return nil end

	if newSafeUnit.team == TEAM and newSafeUnit.tier
			and (newSafeUnit.isTower or newSafeUnit.isFountain) then
		TOWER_TIER_ATTACK_DAMAGE[newSafeUnit.tier] = newSafeUnit.attackDamage
		TOWER_TIER_ATTACK_DPS[newSafeUnit.tier] =
				newSafeUnit.attackDamage / newSafeUnit.hUnit:GetAttackSpeed()
	end
	
	local handover = true
	for i=1,DOTA_TOWER_NUM_TIERS do
		if TOWER_TIER_ATTACK_DAMAGE[i] == UNLIKELY_CHOICE then
			handover = false
			break;
		end
	end
	if handover then
		bUnit_NewSafeUnit = bunit_new_safe_unit_no_scan
		INFO_print(string.format("[building] Found all attack values for %d tower types (+fountain):",
					DOTA_TOWER_NUM_TIERS
				)
			)
		Util_TablePrint(TOWER_TIER_ATTACK_DAMAGE)
		bunit_new_safe_unit_scan_data = nil
		local enemyTeam = ENEMY_TEAM
		local dmgTiersTbl = TOWER_TIER_ATTACK_DAMAGE
		for hUnit,gsiBuilding in pairs(t_buildings_index) do
			if gsiBuilding.team == enemyTeam then
				gsiBuilding.attackDamage = dmgTiersTbl[gsiBuilding.tier]
			end
		end
	end
	return newSafeUnit
end

-- bUnit_NewSafeUnit(hUnit, dontIndex)
bUnit_NewSafeUnit = bunit_new_safe_unit_scan_data

