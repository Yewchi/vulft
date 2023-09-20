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

-- #include at end of ability_logic
ABILITY_USE_TYPES = {
		["DEFENSIVE"] =			0x000001, -- target nearby enemies, target allies in danager
		["SCARY"] =				0x000002, -- target aggresive allies or enemies highly engaged in a fight, and crowded
		["SCARED"] =			0x000004, -- target allies or enemies disengaging
		["VULNERABLE"] =		0x000008, -- target allies or enemies at risk of death
		["LAZY"] =				0x000010, -- target allies or enemies at fight outskirts
		["SMITE"] =				0x000020, -- target allies or enemies without castrange, prioritize danger
		[""] = 0
}

local USE_ABILITY = UseAbility_RegisterAbilityUseAndLockToScore
local USE_ABILITY_LOCKED = UseAbility_IsPlayerLocked
local CURR_TASK = Task_GetCurrentTaskHandle
local CURR_TASK_ACTIVITY = Task_GetCurrentTaskActivityType
local INCENTIVISE_TASK = Task_IncentiviseTask
local TASK_OBJ = Task_GetTaskObjective
local VEC_SM = Vector_ScalarMultiply
local VEC_UDFD = Vector_UnitDirectionalFacingDirection
local VEC_UDPTP = Vector_UnitDirectionalPointToPoint
local VEC_ADD = Vector_Addition
local SET_ALLIED_HERO_NEAR_LOC = Set_GetNearestAlliedHeroToLocation
local SET_ENEMY_HEROES_NEARBY_OUTER = Set_GetEnemyHeroesInLocRacOuter
local FC_ANY_INTENT = FightClimate_AnyIntentToHarm
local DANGER_AMOUNT = Analytics_GetTheoreticalDangerAmount
local GET_NUKE = AbilityLogic_GetBestNuke
local GET_STUN = AbilityLogic_GetBestStun
local GET_SLOW = AbilityLogic_GetBestSlow
local GET_ROOT = AbilityLogic_GetBestRoot
local GET_DEGEN = AbilityLogic_GetBestDegen
local GET_BUFF = AbilityLogic_GetBestBuff
local GET_HEAL = AbilityLogic_GetBestHeal
local GET_SHIELD = AbilityLogic_GetBestShield
local GET_MOBILITY = AbilityLogic_GetBestMobility
local GET_SMITE = AbilityLogic_GetBestSmite
local GET_SUMMON = AbilityLogic_GetBestSummon
local GET_ATTACK_MOD = AbilityLogic_GetBestAttackMod
local GET_INVIS = AbilityLogic_GetInvis
local HIGH_USE = AbilityLogic_HighUseAllowCast or AbilityLogic_HighUseAllowOffensive -- TODO Rename
local SET_ALLIED_HERO_RADIUS = Set_GetAlliedHeroesInPlayerRadius
local LOWEST_HEALTH_PERCENT = Unit_LowestHealthPercentUnit
local MATH_PTPD = Math_PointToPointDistance
local MATH_PTPD2D = Math_PointToPointDistance2D
local TEAM_FOUNTAIN = TEAM_FOUNTAIN
local ENEMY_FOUNTAIN = ENEMY_FOUNTAIN
local B_AND = bit.band
local max = math.max
local min = math.min
local abs = math.abs

local TEAM = TEAM
local ENEMY_TEAM = ENEMY_TEAM

local ACTIVITY_TYPE

local UNIT_TYPE_HERO = UNIT_TYPE_HERO
local UNIT_TYPE_CREEP = UNIT_TYPE_CREEP
local UNIT_TYPE_SIEGE = UNIT_TYPE_SIEGE
local UNIT_TYPE_NEUTRAL = UNIT_TYPE_NEUTRAL
local UNIT_TYPE_WARD = UNIT_TYPE_WARD
local UNIT_TYPE_BUILDING = UNIT_TYPE_BUILDING
local UNIT_TYPE_ALLIED_ILLUSION = UNIT_TYPE_ALLIED_ILLUSION
local UNIT_TYPE_IMAGINARY = UNIT_TYPE_IMAGINARY

local ABILITY_BEHAVIOR_AUTOCAST = ABILITY_BEHAVIOR_AUTOCAST
local ABILITY_BEHAVIOR_UNIT_TARGET = ABILITY_BEHAVIOR_UNIT_TARGET
local ABILITY_BEHAVIOR_POINT = ABILITY_BEHAVIOR_POINT
local ABILITY_BEHAVIOR_NO_TARGET = ABILITY_BEHAVIOR_NO_TARGET
local ABILITY_TARGET_TYPE_NONE = ABILITY_TARGET_TYPE_NONE
local ABILITY_TARGET_TYPE_HERO = ABILITY_TARGET_TYPE_HERO
local ABILITY_TARGET_TYPE_CREEP = ABILITY_TARGET_TYPE_CREEP
local ABILITY_TARGET_TYPE_BUILDING = ABILITY_TARGET_TYPE_BUILDING
local ABILITY_TARGET_TYPE_COURIER = ABILITY_TARGET_TYPE_COURIER
local ABILITY_TARGET_TYPE_TREE = ABILITY_TARGET_TYPE_TREE
local ABILITY_TARGET_TYPE_BASIC = ABILITY_TARGET_TYPE_BASIC
local ABILITY_TARGET_TYPE_ALL = ABILITY_TARGET_TYPE_ALL

local fight_harass_handle
local push_handle

function AbilityLogic_RegisterGenericsModule()
	fight_harass_handle = FightHarass_GetTaskHandle()
	push_handle = Push_GetTaskHandle()
	ACTIVITY_TYPE = _G.ACTIVITY_TYPE
	AbilityLogic_RegisterGenericsModule = nil
end

function AbilityLogic_GetTargetBehavior(hAbility)
	local b = hAbility:GetBehavior()
	local team = hAbility:GetTargetTeam()
	local types = hAbility:GetTargetFlags()
	return B_AND(team, ABILITY_TARGET_TEAM_FRIENDLY), B_AND(team, ABILITY_TARGET_TEAM_ENEMY),
			B_AND(types, ABILITY_TARGET_TYPE_HERO), B_AND(b, ABILITY_BEHAVIOR_AOE),
			B_AND(b, ABILITY_BEHAVIOR_UNIT_TARGET), B_AND(b, ABILITY_BEHAVIOR_POINT_TARGET),
			B_AND(b, ABILITY_BEHAVIOR_NO_TARGET), B_AND(types, ABILITY_BEHAVIOR_TREE)
end

-- Return: funcName, targetType, targetTeam
function AbilityLogic_GetBestFitCastFunc(gsiPlayer, hAbility, target, asString)
	local behaviorFlags = hAbility:GetBehavior()
	local funcStr
	local targetType = hAbility:GetTargetType()
	local targetTeam = hAbility:GetTargetTeam()
	if B_AND(behaviorFlags, ABILITY_BEHAVIOR_AUTOCAST) > 0 then
		funcStr = asString and "ToggleAutoCast" or hAbility.ToggleAutoCast
		if TEST then print(gsiPlayer.shortName, hAbility:GetName(), "ToggleAutoCast", funcStr) end
	elseif B_AND(behaviorFlags, ABILITY_BEHAVIOR_POINT) > 0 and (not target or target.x
			or B_AND(behaviorFlags, ABILITY_BEHAVIOR_UNIT_TARGET) == 0) then
		funcStr = asString and "Action_UseAbilityOnLocation" or gsiPlayer.hUnit.Action_UseAbilityOnLocation
		if TEST then print(gsiPlayer.shortName, hAbility:GetName(), "UseAbilityOnLocation", funcStr) end
	elseif B_AND(behaviorFlags, ABILITY_BEHAVIOR_UNIT_TARGET) > 0 and (
				not target or target.hUnit or target.GetUnitName) then
		funcStr = asString and "Action_UseAbilityOnEntity" or gsiPlayer.hUnit.Action_UseAbilityOnEntity
		if TEST then print(gsiPlayer.shortName, hAbility:GetName(), "UseAbilityOnEntity", funcStr) end
	elseif B_AND(behaviorFlags, ABILITY_BEHAVIOR_NO_TARGET) > 0 then
		funcStr = asString and "Action_UseAbility" or gsiPlayer.hUnit.Action_UseAbility
		if TEST then print(gsiPlayer.shortName, hAbility:GetName(), "UseAbility", funcStr) end
	elseif targetType == ABILITY_TARGET_TYPE_TREE and (not target or type(target) == "number") then
		funcStr = asString and "Action_UseAbilityOnTree" or gsiPlayer.hUnit.Action_UseAbilityOnTree
		if TEST then print(gsiPlayer.shortName, hAbility:GetName(), "UseAbilityOnTree", funcStr) end
	end
	--print(behaviorFlags, targetType, targetTeam)
	return funcStr, targetType, targetTeam
end

local make_target_allied_vulnerable
local make_target_allied_scary
local make_target_allied_scared
local make_target_allied_aoe
local make_target_allied_lazy -- "lazy" here means away from the fight, i.e. blinkstrike safe
local make_target_allied_annoint -- chen pull hero away, dawnbreaker ulti
local make_target_enemy_vulnerable
local make_target_enemy_scary
local make_target_enemy_scared
local make_target_enemy_aoe
local make_target_enemy_lazy -- i.e. nightmare their full-health opportunistic sniper
local make_target_enemy_smite
local make_target_allied_creep
local make_target_allied_creep_aoe
local make_target_enemy_creep
local make_target_enemy_creep_aoe
local make_target_building_heal
local make_target_building_buff
local make_target_building_far_safe

-- allies in danger. low health. around enemies. cache[having high-reads of theoretical danger in the near past.] disregard modes
local make_target_allied_vulnerable = function(gsiPlayer, target, castRangeAllow)
	local timeData = gsiPlayer.time.data
	local castRangeAllow = castRangeAllow
			+ castRangeAllow/4 * max(0, -(timeData.theorizedDanger or DANGER_AMOUNT(gsiPlayer)))
	if target.type ~= UNIT_TYPE_HERO or target.team == ENEMY_TEAM then
		local lowestHpHero, lowestHp = LOWEST_HEALTH_PERCENT(SET_ALLIED_HERO_RADIUS(gsiPlayer, castRangeAllow))
		if lowestHp > 0.88 then
			return nil
		end
		return lowestHpHero
	end
end
-- allies in combat, or entering combat. cores that are keen to fight. physical attack heroes most often. Danger factories.
local make_target_allied_scary = function(gsiPlayer, target, castRangeAllow)
	return target
end
-- allies in fear mode, and prioritising low health while vulnerable.
local make_target_allied_scared = function(gsiPlayer, target, castRangeAllow)
	return target

end
-- find the nearest allied aoe center.
local make_target_allied_aoe = function(gsiPlayer, target, castRangeAllow)
	return target
end
-- allies on the outskirts of a fight, while near to it. Can be used for safe escapes
local make_target_allied_lazy = function(gsiPlayer, target, castRangeAllow)
	return target
end
-- allies anywhere on the map needing healing or help.
local make_target_allied_annoint = function(gsiPlayer, target)

	return target
end
-- enemies in danger of death.
local make_target_enemy_vulnerable = function(gsiPlayer, target, castRangeAllow)

	return target
end
-- enemies deeply engaged in the fight and being highly effective
local make_target_enemy_scary = function(gsiPlayer, target, castRangeAllow)

	return target
end
-- enemies trying to escape.
local make_target_enemy_scared = function(gsiPlayer, target, castRangeAllow)

	return target
end
-- find the nearest enemy aoe cluster center
local make_target_enemy_aoe = function(gsiPlayer, target, castRangeAllow)

	return target
end
-- enemies on the outskirts of a fight, for nightmares / sheeps / sleeps / disarms while highly effective
local make_target_enemy_lazy = function(gsiPlayer, target, castRangeAllow)

	return target
end
-- enemies of a known or guessed location for sunstrikes, NP teleports
local make_target_enemy_smite = function(gsiPlayer, target)

	return target
end
-- allied creep nearby, enigma consume
local make_target_allied_creep = function(gsiPlayer, target, castRangeAllow)

	return target
end
-- allied creep aoe cluster center
local make_target_allied_creep_aoe = function(gsiPlayer, target, castRangeAllow)

	return target
end
-- enemy creep nearby
local make_target_enemy_creep = function(gsiPlayer, target, castRangeAllow)

	return target
end
-- enemy creep aoe cluster center, usually for pushing aggressively with abilities
local make_target_enemy_creep_aoe = function(gsiPlayer, target, castRangeAllow)

	return target
end
-- building needing health
local make_target_building_heal = function(gsiPlayer, target, castRangeAllow)

	return target
end
-- building with active combat needing buff
local make_target_building_buff = function(gsiPlayer, target, castRangeAllow)

	return target
end
-- building as a target for safe teleports
local make_target_building_far_safe = function(gsiPlayer, target)

	return target
end

-- TODO move all the action stuff into this file.
function AbilityLogic_UseLantern(gsiPlayer, lantern)
	local useLantern = gsiPlayer.hUnit:GetAbilityByName("ability_lamp_use")
	--local useLantern = gsiPlayer.hUnit:GetAbilityByName("ability_pluck_famango")
	print(useLantern)
	if useLantern then
		print('using lantern', useLantern:GetCastRange())
		if Vector_DistUnitToUnit(gsiPlayer, lantern)
				> useLantern:GetCastRange()*0.8 then
			gsiPlayer.hUnit:Action_MoveDirectly(lantern.lastSeen.location)
			return true
		end
		-- 'attempting' 201 0 3 64
		print('attemping', useLantern:GetBehavior(), useLantern:GetTargetType(), useLantern:GetTargetTeam(), useLantern:GetTargetFlags())
		print(gsiPlayer.shortName, lantern.hUnit)
		local hUnit = gsiPlayer.hUnit
		if RandomInt(1, 5) == 5 then 
			--[[ TEST FAILED 2023-05-03 ]]
			-- RESULT: IDLES -- hUnit confirmed, and tried straight from GetUnitList,
			-- -| they will move to the unit, get in range, and never trigger a cast.
			-- -| Players cast ability_lamp_use, the location associated with
			-- -| the cast is <0,0,0>. Famangoes and Twin Gates will show the cast at
			-- -| the location of the building/caster didn't check.
			-- - Tried stealing the player's ability handle as well, also failed.
			gsiPlayer.hUnit:Action_UseAbilityOnEntity(useLantern, lantern.hUnit)--nothing
			--gsiPlayer.hUnit:Action_UseAbility(useLantern, lantern.hUnit)--nothing
			--gsiPlayer.hUnit:Action_UseShrine(lantern.hUnit)--nothing
		end
		return true
	end
	return false
end

function AbilityLogic_UseOutpost(gsiPlayer, outpost)
	if outpost then
		if outpost.hUnit:HasModifier("modifier_invulnerable") then
			return false, false
		end
		if Vector_DistUnitToUnit(gsiPlayer, outpost) > 400 then
			gsiPlayer.hUnit:Action_MoveDirectly(outpost.lastSeen.location)
			return true, false
		end
		local abilityCapture = gsiPlayer.hUnit:GetAbilityByName("ability_capture")
		local activeAbility = gsiPlayer.hUnit:GetCurrentActiveAbility()
		-- WORKS
		if gsiPlayer.hUnit:GetCurrentActiveAbility() ~= abilityCapture then
			gsiPlayer.hUnit:Action_UseAbilityOnEntity(abilityCapture, outpost.hUnit)
			return true, false
		else
			return true, true
		end
	end
	return false, false
end

function AbilityLogic_UseFamangoTree(gsiPlayer, mangoTree, distLimit)
--	local humans = GSI_GetTeamHumans(TEAM)
	if mangoTree then
		local distToUnit = Vector_DistUnitToUnit(gsiPlayer, mangoTree)
		if distLimit and distToUnit > distLimit then
			return false, false, distToUnit
		end
		if distToUnit > 500 then
			gsiPlayer.hUnit:Action_MoveDirectly(mangoTree.lastSeen.location)
			return true, false, distToUnit
		end
		local pluck = gsiPlayer.hUnit:GetAbilityByName("ability_pluck_famango")
--		pluck = humans[1] and humans[1].hUnit:GetAbilityByName("ability_pluck_famango")
		if pluck then
			INFO_print("[ability_generics] %s plucking %s at %s", gsiPlayer.shortName,
					mangoTree.name, mangoTree.lastSeen.location
				) -- prints
			-- RESULT: IDLES
			if RandomInt(1, 7) == 7 then
				gsiPlayer.hUnit:Action_UseAbilityOnEntity(abilityCapture, mangoTree)
			end
			return true, gsiPlayer.hUnit:GetCurrentActiveAbility() == abilityCapture,
					distToUnit
		end
	end
	return false, false, distToUnit
end

function AbilityLogic_UseTwinGate(gsiPlayer, twinGate, distLimit)
	if twinGate then
		local distToUnit = Vector_DistUnitToUnit(gsiPlayer, twinGate)
		if distLimit and distToUnit > distLimit then
			return false, false, distToUnit
		end
		if distToUnit > 350 then
			gsiPlayer.hUnit:Action_MoveDirectly(twinGate.lastSeen.location)
			return true, false, distToUnit
		end
		local gateWarp = gsiPlayer.hUnit:GetAbilityByName("twin_gate_portal_warp")
		if gateWarp then
			INFO_print("[ability_generics] %s warping from %s at %s",
					gsiPlayer.shortName, twinGate.name, twinGate.lastSeen.location
				)
			-- RESULT: IDLES
			gsiPlayer.hUnit:Action_UseAbilityOnEntity(gateWarp, twinGate)
			return true, gsiPlayer.hUnit:GetCurrentActiveAbility() == gateWarp,
					distToUnit
		end
	end
	return false, false, distToUnit
end

function AbilityLogic_GetBlinkLocation(gsiPlayer, hAbility, castRange, activityType,
		activityHandle, fightHarassTarget, dangerLimit, nearbyAllies, nearbyEnemies)
	-- Assumes a blink at FHT is desirable if aggressive AcTy. i.e. they are not dead / dotted up
	-- They may be out of vision but it is assumed the last seen is reliable.
	--[[
	local attackRange = gsiPlayer.attackRange
	local danger = Analytics_GetTheoreticalDangerAmount(gsiPlayer, nearbyAllies)
	if GetHeightLevel(location) >= 5 then return false end -- TODO TEMP PREVENT STUCK
	if activityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION and fightHarassTarget
			and activityHandle == fight_harass_handle then
		local fhtLoc = fightHarassTarget.lastSeen.location
		local oneFourthAttackRange = max(100, attackRange / 4)
		local uvecAlliedFountainFht = Vector_UnitDirectionalPointToPoint(
				fhtLoc,
				TEAM_FOUNTAIN
			)
		local uvecEnemyFountainFht = Vector_UnitDirectionalPointToPoint(
				fhtLoc,
				ENEMY_FOUNTAIN
			)
		local safetyZeroed = max(0, -danger)
		local dangerZeroed = max(0, danger)
		local softMagSafe = max(oneFourthAttackRange, min(danger*

		local softDangerAdjust = Vector_Addition(
				fhtLoc,
				softDangerVec
				
		local dangerLocation
				= Analytics_GetTheoreticalDangerAmount(gsiPlayer, nearbyAllies)
		local toAlliedFountainFht = Vector_Addition(
				fightHarassTarget,

		local location = Vector_Addition(gsiPlayer.lastSeen.location,
				Vector_ScalarMultiply(
					Vector_UnitDirectionalPointToPoint(
						gsiPlayer.lastSeen.location,
						location),
				
			dangerLimit = dangerLimit or 0
		local dangerLocation
				= Analytics_GetTheoreticalDangerAmount(gsiPlayer, nearbyAllies, location)
		
		
	elseif activityType > ACTIVITY_TYPE.CAREFUL then
		
	end--]]
end

-- for generics and placeholder hero functionality
-- modules calling this function don't necessarily know how the ability functions, and that is assumed
-- TODO -- If the abiilties usage is confirmed valid, if/when the end-of-nested-code was abstracted,
-- 		-- we can store the target-resolving functionality in a table, indexed by a bitmaks flag of the
-- 		-- cast-type-requested for the ability; then always avoiding the target/team/request resolving code

--local I_INITIATE = 9 -- combo the ability into a group of enemies with a blink or movement speed
local instruction_set = {}
local BEST_FIT_CAST = AbilityLogic_GetBestFitCastFunc
-------- AbilityLogic_DeduceBestFitCastAndUse()
function AbilityLogic_DeduceBestFitCastAndUse(gsiPlayer, hAbility, target, setAutoCastOn)
	local castFunc, targetType, targetTeam = BEST_FIT_CAST(gsiPlayer, hAbility, nil, true)
	if hAbility:IsHidden() then print("CAN'T USE", hAbility:GetName()) return false end
	if TEST then print("al_dbfcau:", gsiPlayer.shortName, hAbility:GetName(), target.x, target.hUnit, "best fit", castFunc, targetType, targetTeam) end
		if castFunc == "Action_UseAbilityOnLocation" and (target.lastSeen or target.x or target.center) then
		local castRange = hAbility:GetCastRange()
		castRange = castRange == 0 and 24000 or castRange
		if TEST then print(gsiPlayer.shortName, hAbility:GetName(), castFunc, "ability range", castRange) end

		local targetIsEnemy = target.team and target.team == ENEMY_TEAM or false
		if targetTeam == ABILITY_TARGET_TEAM_FRIENDLY then
			target = target.team == ENEMY_TEAM and Set_GetNearestAlliedHeroToLocation(gsiPlayer.lastSeen.location) or target
			target = (target.x and target) or target.center or target.lastSeen.location
			-- target ground infront of self
			target = Vector_Addition(
					target,
					Vector_ScalarMultiply2D(
							Vector_UnitDirectionalFacingDirection(gsiPlayer.hUnit:GetFacing()),
							castRange
						)
				)
			if Math_PointToPointDistance(
							gsiPlayer.lastSeen.location,
							target) < castRange*0.9 then
				UseAbility_RegisterAbilityUseAndLockToScore(
						gsiPlayer,
						hAbility,
						target,
						400
					)
				return true
			end
		else
			if target.team == TEAM then
				local nearbyEnemies = gsiPlayer.hUnit:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
				target = target.team == ENEMY_TEAM and target or nearbyEnemies and nearbyEnemies[1]
				if not target then return false end
				target = target:GetLocation()
			end
			target = (target.x and target) or target.center or target.lastSeen.location
			local distToTarget = Math_PointToPointDistance(
					gsiPlayer.lastSeen.location,
					target
				)
			if distToTarget < castRange*0.88 then
				target = Vector_Addition(
						gsiPlayer.lastSeen.location,
						Vector_ScalarMultiply2D(
								Vector_UnitDirectionalPointToPoint(gsiPlayer.lastSeen.location, target),
								min(castRange, distToTarget + 175)
							)
					)
				UseAbility_RegisterAbilityUseAndLockToScore(gsiPlayer, hAbility, target, 400)
				return true
			end
		end
	elseif castFunc == "Action_UseAbilityOnEntity" then
		local castRange = hAbility:GetCastRange()
		castRange = castRange == 0 and 24000 or castRange
		if TEST then print(gsiPlayer.shortName, hAbility:GetName(), castFunc, "ability range", castRange, targetTeam, targetType) end
		if targetTeam == ABILITY_TARGET_TEAM_FRIENDLY then
			if B_AND(targetType, ABILITY_TARGET_TYPE_HERO) > 0 then
				--[[TEMP TEST]]target = make_target_allied_vulnerable(gsiPlayer, target, castRange)
				UseAbility_RegisterAbilityUseAndLockToScore(gsiPlayer, hAbility, gsiPlayer, 400)
				return true
			end
		elseif castRange
				> Math_PointToPointDistance2D(
						gsiPlayer.lastSeen.location,
						target.x and target or target.lastSeen.location
					) then -- BEST_FIT_CAST was not informed we were using a location if we are. use_ability will confirm
			UseAbility_RegisterAbilityUseAndLockToScore(gsiPlayer, hAbility, target.x and gsiPlayer or target, 400)
			return true
		end
	elseif castFunc == "Action_UseAbility" then
		local radius = hAbility:GetSpecialValueInt("radius")
		radius = radius == 0 and (gsiPlayer.isMelee and 350 or 500) or radius
		if TEST then print(gsiPlayer.shortName, hAbility:GetName(), castFunc, "ability rad", radius) end
		local targetLoc = (target.x and target) or target.center or target.lastSeen.location
		if Math_PointToPointDistance(
						gsiPlayer.lastSeen.location,
						targetLoc) < radius*0.8 then
			UseAbility_RegisterAbilityUseAndLockToScore(gsiPlayer, hAbility, nil, 400)
			return true
		end
		if TEST then print(gsiPlayer.shortName, hAbility:GetName(), "out of range.") end
	elseif castFunc == "ToggleAutoCast" then
		AbilityLogic_HandleAutocastGeneric(gsiPlayer, hAbility)
		return false -- shouldn't matter for toggle auto
	end
	return false
end

-- This function is chonky, but often gives satisfactory 2-minute hero implementation, it can also be vastly optimised TODO
local DEDUCE_CAST = AbilityLogic_DeduceBestFitCastAndUse
-- TODO many local optimisations
function AbilityLogic_PlaceholderGenericAbilityUse(gsiPlayer, abilities)
	-- TODO Make a table of known-valid tables for each hero, so we only check what we have
	if UseAbility_IsPlayerLocked(gsiPlayer) then return false end
	local currTask = Task_GetCurrentTaskHandle(gsiPlayer)
	local currActivityType = Blueprint_GetCurrentTaskActivityType(gsiPlayer)
	local fightHarassTarget = Task_GetTaskObjective(gsiPlayer, FightHarass_GetTaskHandle())
	--print("PlACEHOLDER", gsiPlayer.shortName, currTask, currActivityType, fightHarassTarget)
	if currActivityType > ACTIVITY_TYPE.CAREFUL then
		local nearbyEnemies, outerEnemies = Set_GetEnemyHeroesInLocRadOuter(gsiPlayer.lastSeen.location, 600, 1200, 2)
		local survive = AbilityLogic_GetBestSurvivability(gsiPlayer)
		if survive and AbilityLogic_AbilityCanBeCast(gsiPlayer, survive)
				and AbilityLogic_HighUseAllowOffensive(
						gsiPlayer,
						survive,
						gsiPlayer.highUseManaSimple - survive:GetManaCost(),
						Unit_GetHealthPercent(gsiPlayer)
				) then
			if DEDUCE_CAST(gsiPlayer, survive, gsiPlayer) then
				return
			end
		end
		local mobility = AbilityLogic_GetBestMobility(gsiPlayer)
		if mobility and AbilityLogic_AbilityCanBeCast(gsiPlayer, mobility)
				and (nearbyEnemies[1] or outerEnemies[1]) then
			if AbilityLogic_HighUseAllowOffensive(
						gsiPlayer,
						mobility,
						gsiPlayer.highUseManaSimple - mobility:GetManaCost(),
						Unit_GetHealthPercent(gsiPlayer)
					) then
				if TEST then print(gsiPlayer.shortName, "trying cast", mobility:GetName()) end
				if DEDUCE_CAST(gsiPlayer, mobility, TEAM_FOUNTAIN) then
					return
				end
			end
		end
		if nearbyEnemies[1] and (nearbyEnemies[1].currentMovementSpeed > gsiPlayer.currentMovementSpeed or #nearbyEnemies >= 2) then
			local stun = AbilityLogic_GetBestStun(gsiPlayer, false)
			if stun and AbilityLogic_AbilityCanBeCast(gsiPlayer, stun) then
				if AbilityLogic_HighUseAllowOffensive(
							gsiPlayer,
							stun,
							gsiPlayer.highUseManaSimple - stun:GetManaCost(),
							Unit_GetHealthPercent(gsiPlayer)
						) then
					if DEDUCE_CAST(gsiPlayer, stun, nearbyEnemies[1]) then
						return
					end
				end
			end
			local antiMobility = AbilityLogic_GetBestAntiMobility(gsiPlayer, false)
			
			if antiMobility and AbilityLogic_AbilityCanBeCast(gsiPlayer, antiMobility) then
				
				if AbilityLogic_HighUseAllowOffensive(
							gsiPlayer,
							antiMobility,
							gsiPlayer.highUseManaSimple - antiMobility:GetManaCost(),
							Unit_GetHealthPercent(gsiPlayer)
						) then
					if DEDUCE_CAST(gsiPlayer, antiMobility, nearbyEnemies[1]) then
						return
					else

end
				else
					
				end
			end
		end
		if nearbyEnemies[1] or outerEnemies[1] then
			local invis = AbilityLogic_GetBestInvis(gsiPlayer, false)
			if invis and AbilityLogic_AbilityCanBeCast(gsiPlayer, invis) then
				if AbilityLogic_HighUseAllowOffensive(
							gsiPlayer,
							invis,
							gsiPlayer.highUseManaSimple - invis:GetManaCost(),
							Unit_GetHealthPercent(gsiPlayer)
						) then
					if DEDUCE_CAST(gsiPlayer, invis, gsiPlayer) then
						return
					end
				end
			end
		end
	elseif currActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION then
		if fightHarassTarget then
			--print(gsiPlayer.shortName, "agressive generics")
			local crowdedCenter, crowdedRating =
					Set_GetCrowdedRatingToSetTypeAtLocation(fightHarassTarget.lastSeen.location, SET_HERO_ENEMY)
			local nuke, isAoe = AbilityLogic_GetBestNuke(gsiPlayer, crowdedRating > 1.5)
			if nuke and AbilityLogic_AbilityCanBeCast(gsiPlayer, nuke) then
				--print(gsiPlayer.shortName, "checks for", nuke:GetName())
				if AbilityLogic_HighUseAllowOffensive(
							gsiPlayer,
							nuke,
							gsiPlayer.highUseManaSimple - nuke:GetManaCost(),
							Unit_GetHealthPercent(fightHarassTarget)
						) then
					if DEDUCE_CAST(gsiPlayer, nuke, fightHarassTarget) then
						return
					end
				end
			end
			local stun, isAoe = AbilityLogic_GetBestStun(gsiPlayer, crowdedRating > 1.5)
			if stun and AbilityLogic_AbilityCanBeCast(gsiPlayer, stun) then
			--print(gsiPlayer.shortName, "checks for", stun:GetName())
				if AbilityLogic_HighUseAllowOffensive(
							gsiPlayer,
							stun,
							gsiPlayer.highUseManaSimple - stun:GetManaCost(),
							Unit_GetHealthPercent(fightHarassTarget)
						) then
					if DEDUCE_CAST(gsiPlayer, stun, fightHarassTarget) then
						return
					end
				end
			end
			local antiMobility, isAoe = AbilityLogic_GetBestAntiMobility(gsiPlayer, crowdedRating > 1.5)
			if antiMobility and AbilityLogic_AbilityCanBeCast(gsiPlayer, antiMobility) then
				--print(gsiPlayer.shortName, "checks for", antiMobility:GetName())
				if AbilityLogic_HighUseAllowOffensive(
							gsiPlayer,
							antiMobility,
							gsiPlayer.highUseManaSimple - antiMobility:GetManaCost(),
							Unit_GetHealthPercent(fightHarassTarget)
						) then
					if DEDUCE_CAST(gsiPlayer, antiMobility, fightHarassTarget) then
						return
					end
				end
			end
			local attackMod = AbilityLogic_GetBestAttackMod(gsiPlayer)
			if attackMod and AbilityLogic_AbilityCanBeCast(gsiPlayer, attackMod) then 
				--print(gsiPlayer.shortName, "checks for", attackMod:GetName())
				if (attackMod:GetManaCost() == 0
							or AbilityLogic_HighUseAllowOffensive(
								gsiPlayer,
								attackMod,
								gsiPlayer.highUseManaSimple - attackMod:GetManaCost(),
								Unit_GetHealthPercent(fightHarassTarget)
							)
						) then
					if DEDUCE_CAST(gsiPlayer, attackMod, fightHarassTarget, true) then
						Task_IncentiviseTask(gsiPlayer, FightHarass_GetTaskHandle(), 10, 2)
						return
					end
				else
					if DEDUCE_CAST(gsiPlayer, attackMod, fightHarassTarget, true) then -- incase it was auto-cast
						return
					end
				end
			end
			local degen = AbilityLogic_GetBestDegen(gsiPlayer)
			if degen and AbilityLogic_AbilityCanBeCast(gsiPlayer, degen) then 
				--print(gsiPlayer.shortName, "checks for", degen:GetName())
				if (degen:GetManaCost() == 0
							or AbilityLogic_HighUseAllowOffensive(
								gsiPlayer,
								degen,
								gsiPlayer.highUseManaSimple - degen:GetManaCost(),
								Unit_GetHealthPercent(fightHarassTarget)
							)
						) then
					if DEDUCE_CAST(gsiPlayer, degen, fightHarassTarget) then
						return
					end
				end
			end
			local buff = AbilityLogic_GetBestBuff(gsiPlayer)
			if buff and AbilityLogic_AbilityCanBeCast(gsiPlayer, buff) then 
				--print(gsiPlayer.shortName, "checks for", buff:GetName())
				if (buff:GetManaCost() == 0
							or AbilityLogic_HighUseAllowOffensive(
								gsiPlayer,
								buff,
								gsiPlayer.highUseManaSimple - buff:GetManaCost(),
								Unit_GetHealthPercent(fightHarassTarget)
							)
						) then
					if DEDUCE_CAST(gsiPlayer, buff, gsiPlayer) then
						return
					end
				end
			end
			local mobility = AbilityLogic_GetBestMobility(gsiPlayer)
			if mobility and AbilityLogic_AbilityCanBeCast(gsiPlayer, mobility) then 
				--print(gsiPlayer.shortName, "checks for", mobility:GetName())
				if (mobility:GetManaCost() == 0
							or AbilityLogic_HighUseAllowOffensive(
								gsiPlayer,
								mobility,
								gsiPlayer.highUseManaSimple - mobility:GetManaCost(),
								Unit_GetHealthPercent(fightHarassTarget)
							)
						) then
					if DEDUCE_CAST(gsiPlayer, mobility, fightHarassTarget.lastSeen.location) then
						return
					end
				end
			end
		end
	end
end

function AbilityLogic_HandleAutocastGeneric(gsiPlayer, ability)
	local fightHarassTarget = Task_GetTaskObjective(gsiPlayer, fight_harass_handle)
	local highUseMana = gsiPlayer.highUseManaSimple
	local currManaPercent = gsiPlayer.lastSeenMana / gsiPlayer.maxMana

	if fightHarassTarget and not pUnit_IsNullOrDead(fightHarassTarget)
			and Blueprint_GetCurrentTaskActivityType(gsiPlayer) <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION then 
		local fhtDmgFactor = AbilityLogic_CastOnTargetWillSucceed(gsiPlayer, fightHarassTarget, ability)
		local fightHarassPercentHealth = Unit_GetHealthPercent(fightHarassTarget)
		if fhtDmgFactor == 0
				or gsiPlayer.lastSeenMana - ability:GetManaCost()
						< highUseMana*(0.5 + fightHarassPercentHealth) then
			if ability:GetAutoCastState() then
				ability:ToggleAutoCast() -- Enemies are high health, conserve low mana
				--print(gsiPlayer.shortName, "high health off")
			end
		elseif fhtDmgFactor > 0 and not ability:GetAutoCastState() then
			ability:ToggleAutoCast()
			--print(gsiPlayer.shortName, "low health on")
		end
	elseif currManaPercent < 0.95 then
		if ability:GetAutoCastState() then
			ability:ToggleAutoCast() -- jungle faster
			--print(gsiPlayer.shortName, "start mana regen benefit off")
		end
		-- otherwise don't check if it's off
	elseif not ability:GetAutoCastState() then
		ability:ToggleAutoCast()
		--print(gsiPlayer.shortName, "start mana regen benefit on")
	end
end

function AbilityLogic_PreCastFindLocation(gsiPlayer, hAbility, hittableUnits,
			requiredTarget, areaOfEffect, projectileSpeed
		)
	local castPoint = hAbility:GetCastPoint()
	local timeTilCast = castPoint + Projectil_TimeTilFacingDirectional()
end
