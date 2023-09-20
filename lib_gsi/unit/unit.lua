UNIT_SEARCH_STRING_START_INDEX = 10 -- 'npc_dota_*'

require(GetScriptDirectory().."/lib_gsi/unit/player")
require(GetScriptDirectory().."/lib_gsi/unit/creep")
require(GetScriptDirectory().."/lib_gsi/unit/building")
require(GetScriptDirectory().."/lib_gsi/unit/ward")

local PLAYER_NAME_START_SEARCH_INDEX = PLAYER_NAME_START_SEARCH_INDEX

local CONSIDER_RANGED_ATTACK_MIN = 249

local max = math.max
local min = math.min

-- N.B. Because of the recycling process it is important that variables which are nil-until-set are
--- avoided. If necessary, and not encumbering, initialize them as false. If encumbering, then they
--- must be processed with a safety thisUnit.weirdRareValueIndex = nil either as they are recycled, or 
--- created (incase variable may be set during creation).

-- Unit Data Standards:
--- Units MUST be wrapped in a SafeUnit if they're to be used between frames, including allied units--for functional one-step-check simplicity.
--- All GetSafeUnit() must save the hUnit with structure safeUnit.hUnit = [hUnit from Dota]
--- All SafeUnits should declare their safeUnit.type
--- As above, avoid nil-until-set indices.

-- TODO Investigate reasons for why an enemy would have an undefined attack range. (phased from world?) The unit was not none-typed.

local job_domain_gsi

local team_ancient_unit -- Used for dummy function copies
local dummy_function_redirects

function GSI_RegisterGSIJobDomainToUnitModule(jobDomainGSI)
	job_domain_gsi = jobDomainGSI
end

function Unit_Initialize()
	cUnit_Initialize(job_domain_gsi)
end

function Unit_GetUnitType(thisUnit)
	if thisUnit.hUnit and thisUnit.team == TEAM or
			thisUnit.IsNull and not thisUnit:IsNull() and thisUnit:GetTeam() == TEAM then
		return thisUnit.type or -- If type is not initialized, the parameter was lazily set as a dota-game-state hUnit, or the lib_gsi/unit standards for units were not followed.
			thisUnit.IsNull and not thisUnit:IsNull() and (
					thisUnit:IsCreep() and CREEP_ALLIED or
					thisUnit:IsBuilding() and BUILDING_ALLIED or
					thisUnit:IsHero() and HERO_ALLIED or
				UNIT_TYPE_NONE ) -- Should never happen
	else
		return thisUnit.type or -- If type is not initialized, the parameter was lazily set as a dota-game-state hUnit, or the lib_gsi/unit standards for units were not followed.
			thisUnit.IsNull and not thisUnit:IsNull() and (
					thisUnit:IsCreep() and CREEP_ENEMY or
					thisUnit:IsBuilding() and BUILDING_ENEMY or
					thisUnit:IsHero() and HERO_ENEMY or
				UNIT_TYPE_NONE ) -- Should never happen
	end
end

function GSI_GetUnitName(thisUnit) 
	return thisUnit and (
				thisUnit.GetUnitName and thisUnit:GetUnitName() or
				thisUnit.name or
				thisUnit.hUnit and 
					thisUnit.hUnit.IsNull and not thisUnit.hUnit:IsNull() and thisUnit.hUnit:GetUnitName()
			) or
		"UNIT_NAME_UNKNOWN"
end

function Unit_IsNullOrDead(thisUnit)
	if thisUnit.type then
		if thisUnit.type == UNIT_TYPE_CREEP then
			return cUnit_IsNullOrDead(thisUnit)
		elseif thisUnit.type == UNIT_TYPE_HERO then
			return pUnit_IsNullOrDead(thisUnit)
		elseif thisUnit.type == UNIT_TYPE_BUILDING then
			return bUnit_IsNullOrDead(thisUnit)
		end
	end
	if thisUnit.IsNull then
		return (thisUnit:IsNull() or not thisUnit:IsAlive())
	elseif thisUnit.hUnit then
		return (thisUnit.hUnit:IsNull() or not thisUnit.hUnit:IsAlive())
	end
	return nil
end

function Unit_GetHealthPercent(unit)
	return (unit.lastSeenHealth and unit.lastSeenHealth / unit.maxHealth) or (unit.IsNull and not unit:IsNull() and unit:GetHealth() / unit:GetMaxHealth()) or -1.0
end

function Unit_GetManaPercent(unit)
	return (unit.lastSeenMana and unit.lastSeenMana / unit.maxMana) or (unit.IsNull and not unit.IsNull() and unit.GetMana --[[TODO double check needed]] and unit:GetMana() / unit:GetMaxMana()) or -1.0
end

function Unit_GetTimeTilNextAttackStart(gsiUnit)
	-- max of 0 or backswing - timeSinceAttack
	if not gsiUnit.hUnit:CanBeSeen() then
		return 0
	end
	return max(gsiUnit.hUnit:GetSecondsPerAttack()*(1-gsiUnit.attackPointPercent)
			+ gsiUnit.hUnit:GetLastAttackTime() - GameTime(), 0)
end
local time_til_attack_start = Unit_GetTimeTilNextAttackStart

function Unit_GetTimeTilNextAttackRelease(gsiUnit)
	return time_til_attack_start(gsiUnit) + gsiUnit.hUnit:GetAttackPoint() * gsiUnit.hUnit:GetSecondsPerAttack()
end
local time_til_attack_release = Unit_GetTimeTilNextAttackRelease

--function Unit_GetTimeTilOrbWalkActive(gsiUnit)
--	local nextAttackStart = time_til_attack_start(gsiUnit)
--	print(nextAttackStart, gsiUnit.shortName, "NEXT ATTACK START")
--	return nextAttackStart == 0
--			and gsiUnit.hUnit:GetSecondsPerAttack()*gsiUnit.attackPointPercent
--			or 0
--end

function Unit_GetArmorPhysicalFactor(unit)
	local unitArmor = unit.hUnit:GetArmor()
	return 1-(0.06*unitArmor/(1+0.06*unitArmor))
end

function Unit_IsImmobilized(gsiUnit)
	-- returns false if they are dead
	local hUnit = gsiUnit.hUnit or gsiUnit
	return Unit_IsNullOrDead(gsiUnit) or hUnit:IsNightmared() or hUnit:IsRooted() or hUnit:IsStunned()
end

function Unit_GetSafeUnit(thisUnit)
	if thisUnit.name then return thisUnit end
	if thisUnit:IsCreep() or thisUnit:IsAncientCreep() then
		return cUnit_NewSafeUnit(thisUnit)
	elseif thisUnit:IsBuilding() then
		return bUnit_NewSafeUnit(thisUnit)
	elseif thisUnit:IsHero() then
		return GSI_GetPlayerFromPlayerID(thisUnit:GetPlayerID())
	elseif thisUnit:IsIllusion() then
		return "TODO" + 1 + nil
	end
end

function Unit_UnitIsRanged(thisUnit)
	thisUnit = thisUnit and thisUnit.hUnit or thisUnit.GetUnitName and thisUnit
	if thisUnit:IsNull() or not thisUnit:IsAlive() then return nil end
	return thisUnit:GetAttackProjectileSpeed() > 0
			and thisUnit:GetAttackRange() > CONSIDER_RANGED_ATTACK_MIN
			or false
end

function Unit_ConvertListToSafeUnits(list)
	for i=1,#list,1 do
		list[i] = Unit_GetSafeUnit(list[i])
	end
	return list
end

--[[FUNCVAL]]local MJOL_STATIC_NAME = "modifier_item_mjolnir_static"
--[[FUNCVAL]]local BLADE_MAIL_REFLECT_NAME = "modifier_item_blade_mail_reflect"
--[[FUNCVAL]]local ENCHANTRESS_NAME = "enchantress"
--[[FUNCVAL]]local ENCHANTRESS_GET_ATK_SPEED_DEGEN = "UntouchableAtLevel" 
--[[FUNCVAL]]local ABADDON_NAME = "abaddon"
--[[FUNCVAL]]local ABADDON_BORROWED_TIME = "modifier_abaddon_borrowed_time"
function Unit_GetDegenAttackModifiersOnUnit(gsiUnit)
	-- TODO Formulate a table of namedavariables with defaults of 'false' or '0' whatever is applicable if the hero is not present?
	-- TODO Use a template table global to receive the values set from this function.
	return gsiUnit.hUnit:HasModifier(MJOL_STATIC_NAME),
			gsiUnit.hUnit:HasModifier(BLADE_MAIL_REFLECT_NAME),
			gsiUnit.shortName == ENCHANTRESS_NAME and HeroData_RequestHeroKeyValue(ENCHANTRESS_NAME, ENCHANTRESS_GET_ATK_SPEED_DEGEN)(gsiUnit.level) or 0,
			gsiUnit.shortName == ABADDON_NAME and gsiUnit.hUnit:HasModifier(ABADDON_BORROWED_TIME)
end

function Unit_Key(this)
	return this.hUnit
end

--TODO depreciate
function Unit_LowestHealthPercentPlayer(gsiList, gsiList2)
	local lowestHealthPercent = 1.0
	local lowestHealthPlayer = false
	for i=1,#gsiList do
		local thisPlayer = gsiList[i]
		local thisPlayerHealthPercent = thisPlayer.lastSeenHealth / thisPlayer.maxHealth
		if thisPlayerHealthPercent <= lowestHealthPercent then
			lowestHealthPercent = thisPlayerHealthPercent
			lowestHealthPlayer = thisPlayer
		end
	end
	if gsiList2 then
		for i=1,#gsiList2 do
			local thisPlayer = gsiList2[i]
			local thisPlayerHealthPercent = thisPlayer.lastSeenHealth / thisPlayer.maxHealth
			if thisPlayerHealthPercent <= lowestHealthPercent then
				lowestHealthPercent = thisPlayerHealthPercent
				lowestHealthPlayer = thisPlayer
			end
		end
	end
	return lowestHealthPlayer, lowestHealthPercent
end

function Unit_LowestHealthPercentUnit(gsiList, gsiList2)
	local lowestHealthPercent = 1.0
	local lowestHealthUnit = false
	for i=1,#gsiList do
		local thisUnit = gsiList[i]
		local thisUnitHealthPercent = thisUnit.lastSeenHealth / thisUnit.maxHealth
		if thisUnitHealthPercent <= lowestHealthPercent then
			lowestHealthPercent = thisUnitHealthPercent
			lowestHealthUnit = thisUnit
		end
	end
	if gsiList2 then
		for i=1,#gsiList2 do
			local thisUnit = gsiList2[i]
			local thisUnitHealthPercent = thisUnit.lastSeenHealth / thisUnit.maxHealth
			if thisUnitHealthPercent <= lowestHealthPercent then
				lowestHealthPercent = thisUnit
				lowestHealthUnit = thisUnit
			end
		end
	end
	return lowestHealthUnit, lowestHealthPercent
end

-- do
	-- local buildingList = GetUnitList(BUILDING_ALLIED)
	-- for i=1,#buildingList,1 do
		-- if buildingList[i]:IsFort() then
			-- team_ancient_unit = buildingList[i]
			-- break
		-- end
	-- end
	
	-- local fTrue = function(self) return true end
	-- local fFalse = function(self) return false end
	-- local fNegativeOne = function(self) return -1 end
	-- local fZero = function(self) return 0 end
	-- local fOne = function(self) return 1 end
	
	-- dummy_function_redirects = {
		-- IsBot = fTrue,
		-- GetUnitName = function(self) return self.name end,
		--GetPlayerID = fNegativeOne,
		-- GetTeam = function(self) return self.team end,
		-- IsHero = function(self) return self.type == UNIT_TYPE_HERO end,
		-- IsIllusion = fFalse,
		-- IsCreep = function(self) return self.type == UNIT_TYPE_CREEP end,
		-- IsAncientCreep = function(self) return self.creepType == CREEP_TYPE_NEUTRAL end,
		-- IsBuilding = function(self) return self.type == UNIT_TYPE_BUILDING end,
		-- IsFort = function(self) return self.buidingType == UNIT_TYPE_FORT end,
		-- CanBeSeen = function(self) return IsLocationVisible(self.lastSeen.location) end,
		-- GetHealth = fOne,
		-- GetMaxHealth = fOne,
	-- }
-- end
