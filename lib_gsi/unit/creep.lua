CREEP_TYPE_UNKNOWN = 0
CREEP_TYPE_SIEGE = 1
CREEP_TYPE_MELEE = 2
CREEP_TYPE_RANGED = 3
CREEP_TYPE_S_MELEE = 4
CREEP_TYPE_S_RANGED = 5
CREEP_TYPE_M_MELEE = 6
CREEP_TYPE_M_MELEE = 7
CREEP_TYPE_NEUTRAL = 8

NEUTRAL_SMALL = 1
NETURAL_MEDIUM = 2
NEUTRAL_LARGE = 3
NEUTRAL_ANCIENT = 4

LANE_CREEP_MOVEMENT_SPEED = 325

SIEGE_CREEP_LATE_RELEASE_BEHIND_ADJUST = 0.015 + 80 / 1100
RANGE_CREEP_DIFFERENCE_IN_RELEASE_IN_PERCENT = 0.05 -- TODO not finely measured

SIEGE_CREEP_MAX_HEALTH = 950
HIGH_CREEP_MAX_HEALTH = SIEGE_CREEP_MAX_HEALTH

-- GETS_HIT_Z_TYPEX = BAKED @ cUnit_NewSafeUnit

-- SIEGE_CREEP_ATTACK_POINT = 0.3 -- Seige creeps charge up a 0 - 0.4 animation cycle, cancel it, then animate 0.0 -> 0.3 attack -> 1.0 and repeat. Advertised attack point is 0.6.
--

CREEP_UNIT_DATA_UPDATE_THROTTLE = 0.0

CREEP_FLUSH_THROTTLE = 60

local Map_CreateLastSeenTable
local cUnit_GetCreepType
local Unit_UnitIsRanged

local t_recyclable_safe_unit_sets = {}
local t_recyclable_safe_units = {}

local t_creeps = {}

local job_domain_gsi

local recycle_list = {}
local function create_or_recycle_safe_unit()
	return table.remove(recycle_list) or {}
end

--local function set_recyclable(hUnit)
--	table.insert(recycle_list, t_creeps[hUnit])
--	t_creeps[hUnit] = nil
--end

function GSI_CreateUpdateCreepUnits()
	local function delete_none_typed__job(workingSet)
		if workingSet.dataThrottle:allowed() then
			local newLoc
			for hUnit,safeUnit in pairs(t_creeps) do
				if hUnit:IsNull() or not hUnit:IsAlive() then
					t_creeps[hUnit] = nil
				elseif hUnit:CanBeSeen() then
					newLoc = hUnit:GetLocation()
					if not (newLoc.x == 0 and newLoc.y == 0 and newLoc.z == 0) then -- happens, not sure why, but it can cause TPS to mid. other weird behavior
						safeUnit.lastSeen:Update(hUnit:GetLocation())
						safeUnit.lastSeenHealth = hUnit:GetHealth()
						safeUnit.maxHealth = hUnit:GetMaxHealth()
					end
				end
			end
			if workingSet.flushThrottle:allowed() then
				for hUnit,safeUnit in pairs(t_creeps) do
					cUnit_IsNullOrDead(safeUnit)
				end
			end
		end
	end
	
	job_domain_gsi:RegisterJob(
			delete_none_typed__job,
			{
				["dataThrottle"] = Time_CreateThrottle(CREEP_UNIT_DATA_UPDATE_THROTTLE),
				["flushThrottle"] = Time_CreateThrottle(CREEP_FLUSH_THROTTLE)
			},
			"JOB_UPDATE_CREEP_UNITS"
		)
end

function GSI_RegisterGSIJobDomainToCreep(jobDomainGSI)
	job_domain_gsi = jobDomainGSI
	Map_CreateLastSeenTable = _G.Map_CreateLastSeenTable
	cUnit_GetCreepType = _G.cUnit_GetCreepType
	Unit_UnitIsRanged = _G.Unit_UnitIsRanged
end

function cUnit_UpdateHealthAndLocation(gsiCreep)
	local hUnitCreep = gsiCreep.hUnit
	gsiCreep.lastSeen:Update(hUnitCreep:GetLocation())
	gsiCreep.lastSeenHealth = hUnitCreep:GetHealth()
	gsiCreep.maxHealth = hUnitCreep:GetMaxHealth()
	gsiCreep.attackPointPercent = hUnitCreep:GetAttackPoint()
end

function cUnit_IsNullOrDead(creep) -- Call this if you know you're dealing with a creep and the creep will be removed from local hUnit -> creepSafeUnit storage
	if creep.hUnit then
		if not creep.hUnit.IsNull or creep.hUnit:IsNull()
				or not creep.hUnit:IsAlive() then
			table.insert(recycle_list, t_creeps[creep])
			t_creeps[creep] = nil
			return true;
		end
	elseif creep.IsNull then
		if ( creep:IsNull() or not creep:IsAlive() ) then
			return true;
		end
	else return true; end
	return false;
end

function cUnit_ConvertListToSafeUnits(list)
	for i=1,#list,1 do
		list[i] = t_creeps[list[i]] or cUnit_NewSafeUnit(list[i]) -- Place the previously created SafeUnit into the list. This allows higher-level functions to skip re-initialization, while still confirming all creeps are visible, and we have all visible GetUnitList creeps in safeunits.
	end
	return list
end

_G.cUnit_GetCreepType = function(name)
	if string.find(name, "sieg") then
		return CREEP_TYPE_SIEGE
	elseif string.find(name, "mele") or string.find(name, "lagb") then
		return CREEP_TYPE_MELEE
	elseif string.find(name, "rang") then
		return CREEP_TYPE_RANGED
	end
	return UNIT_TYPE_UNKNOWN
end

function cUnit_NewSafeUnit(hUnit)
	if t_creeps[hUnit] then return t_creeps[hUnit] end
	local newSafeUnit = create_or_recycle_safe_unit()
	
	newSafeUnit.hUnit = hUnit
	newSafeUnit.isNull = hUnit.IsNull
	newSafeUnit.name = hUnit:GetUnitName()
	newSafeUnit.team = hUnit:GetTeam()
	if (hUnit:GetLocation().x == 0 and hUnit:GetLocation().y == 0) then print("FOUND ZEROED CREEP\n\n\n\n\n\n\n\nFOUND ZEROED CREEP") end
	newSafeUnit.lastSeen = Map_CreateLastSeenTable(hUnit:GetLocation())
	newSafeUnit.lastSeenHealth = hUnit:GetHealth()
	newSafeUnit.isCreep = true
	newSafeUnit.maxHealth = hUnit:GetMaxHealth()
	newSafeUnit.creepType = cUnit_GetCreepType(newSafeUnit.name)
	newSafeUnit.attackPointPercent = hUnit:GetAttackPoint() -- updated in projtl
	newSafeUnit.isRanged = Unit_UnitIsRanged(newSafeUnit)
	newSafeUnit.playerID = hUnit.GetPlayerID and hUnit:GetPlayerID() or -1
	newSafeUnit.halfSecAttack = hUnit:GetSecondsPerAttack() / 2
	newSafeUnit.Key = Unit_Key
	newSafeUnit.dotaType = hUnit:GetTeam() == TEAM and CREEP_ALLIED or CREEP_ENEMY
	newSafeUnit.type = UNIT_TYPE_CREEP
	if newSafeUnit.creepType == CREEP_TYPE_SIEGE then
		newSafeUnit.attackPointPercent = newSafeUnit.attackPointPercent
		newSafeUnit.getsHitZ = 27
	elseif newSafeUnit.creepType == CREEP_TYPE_RANGED then
		newSafeUnit.attackPointPercent = newSafeUnit.attackPointPercent
		newSafeUnit.getsHitZ = 106
	else
		newSafeUnit.getsHitZ = 88
	end
	
	t_creeps[hUnit] = newSafeUnit
	
	return newSafeUnit
end
