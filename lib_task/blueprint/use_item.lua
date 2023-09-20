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

require(GetScriptDirectory().."/lib_hero/item/urn_logic")

local USABLE_ITEMS_FOR_INDEXING = USABLE_ITEMS_FOR_INDEXING
local TEAM_NUMBER_OF_PLAYERS = TEAM_NUMBER_OF_PLAYERS
local Task_SetTaskPriority = Task_SetTaskPriority
local XETA_SCORE_DO_NOT_RUN = XETA_SCORE_DO_NOT_RUN
local Math_GetFastThrottledBounded = Math_GetFastThrottledBounded
local CURRENT_TASK = Task_GetCurrentTaskHandle
local Vector_PointDistance2D = Vector_PointDistance2D
local NEAREST_UNIT = Vector_GetNearestToUnitForUnits
local Set_GetEnemyHeroesInPlayerRadius = Set_GetEnemyHeroesInPlayerRadius
local Set_GetAlliedHeroesInPlayerRadius = Set_GetAlliedHeroesInPlayerRadius
local ACTUAL_ATTACK = Lhp_GetActualFromUnitToUnitAttackOnce
local ACTIVITY_TYPE = ACTIVITY_TYPE
local COUNT_ACTIVITY_TYPES = COUNT_ACTIVITY_TYPES
local CURR_ACTIVITY_TYPE = Blueprint_GetCurrentTaskActivityType
local TASK_OBJ = Task_GetTaskObjective
local CROWDED_RATING = Set_GetCrowdedRatingToSetTypeAtLocation
local CURR_TASK_OBJ = Task_GetCurrentTaskObjective
local ITEM_END_INVENTORY_INDEX = ITEM_END_INVENTORY_INDEX
local CAN_BE_CAST = AbilityLogic_AbilityCanBeCast
local HIGH_USE = AbilityLogic_HighUseAllowOffensive
local ENEMY_FOUNTAIN
local WARD_LOCS
local min = math.min
local max = math.max
local abs = math.abs

local ITEM_POWER_TREADS_STATE_STAT = ITEM_POWER_TREADS_STATE_STAT
local ITEM_FORCE_STAFF_PUSH_RANGE = ITEM_FORCE_STAFF_PUSH_RANGE

local INCOMING_TRACKING_PROJECTILES_I__LOC = 1
local INCOMING_TRACKING_PROJECTILES_I__CASTER = 2
local INCOMING_TRACKING_PROJECTILES_I__PLAYER = 3
local INCOMING_TRACKING_PROJECTILES_I__ABILITY = 4
local INCOMING_TRACKING_PROJECTILES_I__DODGEABLE = 5
local INCOMING_TRACKING_PROJECTILES_I__IS_ATTACK = 6

local fight_harass_handle
local push_handle
local search_fog_handle

local UrnLogic_ScoreUrnVessel = UrnLogic_ScoreUrnVessel

local USE_ITEM_RESCORE_THROTTLE = 0.1493

local task_handle = Task_CreateNewTask()

local blueprint

local max = math.max
local sqrt = math.sqrt

local VERBOSE = VERBOSE or DEBUG_TARGET and string.find(DEBUG_TARGET, "use_item")
local DEBUG = DEBUG or VERBOSE
local TEST = TEST

local ARMOR_FACTOR = 0.06
local GLEIPNIR_PROJECTILE_SPEED = 1900
local GLEIPNIR_RADIUS = 450
local METEOR_HAMMER_RADIUS = 315

local function estimated_time_til_completed(gsiPlayer, objective)
	return 0
end

local t_player_current_use = {}
local t_player_current_ward_index = {}

local t_tree_target = {}

local t_player_power_treads_stat_lock = {} -- [pnot]={attributeValue<0-2>, expires, score}

local USE_WITHOUT_TARGET_TYPE = EMPTY_TABLE

local INSTANT_NO_TURNING_SCORE = 1000 -- lame

local t_recent_cast = {}
local t_recent_cast_expires = {}
function UseItem_RegisterCaughtAbility(gsiPlayer, hAbility)
	if gsiPlayer.team ~= TEAM then return; end
	
	local channelTime = hAbility:GetChannelTime()
	local cd = hAbility:GetCooldown()
	local cdRemaining = hAbility:GetCooldownTimeRemaining()
	if cd - channelTime > cdRemaining - 0.03 then
		return;
	end
	local takeDelay
	local abilityBehavior = hAbility:GetBehavior()
	local usingTurningRate = (bit.band(ABILITY_BEHAVIOR_UNIT_TARGET, abilityBehavior) > 0
				or bit.band(ABILITY_BEHAVIOR_POINT, abilityBehavior) > 0
			) and max(0.15, 4/gsiPlayer.turnRate) or 0
	local expires = GameTime() + min(10,
			(cdRemaining > 0 and cd > 0 and channelTime > 0
				and cdRemaining+0.17 > cd and cdRemaining - cd
				or 0
			) + channelTime + 0.07 + usingTurningRate
		)
	t_recent_cast[gsiPlayer.nOnTeam] = hAbility:GetName()
	t_recent_cast_expires[gsiPlayer.nOnTeam] = expires
end

-- TODO Refactor UseAbility or AbilityLogic
function UseItem_IsChanneling(gsiPlayer, itemName)
	local expires = t_recent_cast_expires[gsiPlayer.nOnTeam]
	if expires and expires < GameTime() then
		t_recent_cast[gsiPlayer.nOnTeam] = nil
	end
	local isCastingItem = itemName and t_recent_cast[gsiPlayer.nOnTeam] == itemName
	return isCastingItem, t_recent_cast[gsiPlayer.nOnTeam], expires
end

function UseItem_PowerTreadsStatLock(gsiPlayer, stat, duration, score, force)
	
	local treadsLock = t_player_power_treads_stat_lock[gsiPlayer.nOnTeam]
	if not treadsLock then
		t_player_power_treads_stat_lock[gsiPlayer.nOnTeam] = {
				stat, GameTime()+duration, score
			}
		return true;
	end
	if force or not treadsLock[2] or treadsLock[2] < GameTime() then
		treadsLock[1] = stat
		treadsLock[2] = GameTime() + duration
		treadsLock[3] = score
		return true;
	end
	return false;
end
local TREADS_LOCK = UseItem_PowerTreadsStatLock
local function get_power_treads_desired_stat(gsiPlayer)
	treadsLock = t_player_power_treads_stat_lock[gsiPlayer.nOnTeam]
	local primary = gsiPlayer.hUnit:GetPrimaryAttribute()
	if treadsLock and treadsLock[2] then
		if treadsLock[2] >= GameTime() then
			return treadsLock[1];
		else
			treadsLock[2] = false
		end
	end
	local currActivityType = CURR_ACTIVITY_TYPE(gsiPlayer)
	local primaryIsValidTreadsState = ITEM_POWER_TREADS_STATE_STAT[primary] and true -- e.g. universal
	local speed = 0.75/(1+gsiPlayer.hUnit:GetDifficulty())
	if not primaryIsValidTreadsState then
		if currActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION then
			TREADS_LOCK(gsiPlayer, ATTRIBUTE_AGILITY, RandomFloat(0.15, 0.2+speed*#gsiPlayer.usableItemCache), INSTANT_NO_TURNING_SCORE)
			return ATTRIBUTE_AGILITY;
		elseif currActivityType >= ACTIVITY_TYPE.FEAR then
			TREADS_LOCK(gsiPlayer, ATTRIBUTE_STRENGTH, RandomFloat(0.15, 0.2+speed*#gsiPlayer.usableItemCache), INSTANT_NO_TURNING_SCORE)
			return ATTRIBUTE_STRENGTH;
		end
		return ATTRIBUTE_AGILITY
	end
	if currActivityType >= ACTIVITY_TYPE.FEAR then
		TREADS_LOCK(gsiPlayer, ATTRIBUTE_STRENGTH, RandomFloat(0.15, 0.67), INSTANT_NO_TURNING_SCORE)
		return ATTRIBUTE_STRENGTH;
	end
	return primary
end


local function generic_run_func(gsiPlayer, target, hItem)
	if target.hUnit then
		gsiPlayer.hUnit:Action_UseAbilityOnEntity(
				t_player_current_use[gsiPlayer.nOnTeam], target.hUnit
			)
	elseif target.x then
		gsiPlayer.hUnit:Action_UseAbilityOnLocation(
				t_player_current_use[gsiPlayer.nOnTeam], target
			)
	elseif target == USE_WITHOUT_TARGET_TYPE then
		gsiPlayer.hUnit:Action_UseAbility(
				t_player_current_use[gsiPlayer.nOnTeam]
			)
	elseif type(target) == "number" then
		gsiPlayer.hUnit:Action_UseAbilityOnTree(
				t_player_current_use[gsiPlayer.nOnTeam], target
			)
	end
end

function generic_no_target_func(gsiPlayer, target, hItem)
	gsiPlayer.hUnit:Action_UseAbility(
			t_player_current_use[gsiPlayer.nOnTeam]
		)
end
function generic_on_location_func(gsiPlayer, target, hItem)
	local currentActive = gsiPlayer.hUnit:GetCurrentActiveAbility()
	if currentActive and currentActive:GetName() == (hItem and hItem:GetName()) then
		Task_IncentiviseTask(gsiPlayer, task_handle, 100, 30)
	end
	gsiPlayer.hUnit:Action_UseAbilityOnLocation(
			t_player_current_use[gsiPlayer.nOnTeam], target
		)
end
function generic_on_entity_func(gsiPlayer, target, hItem)
	gsiPlayer.hUnit:Action_UseAbilityOnEntity(
			t_player_current_use[gsiPlayer.nOnTeam], target.hUnit or target
		)
end
function generic_on_tree_func(gsiPlayer, tree, hItem)
	tree = t_tree_target[gsiPlayer.nOnTeam]
	gsiPlayer.hUnit:Action_UseAbilityOnTree(
			t_player_current_use[gsiPlayer.nOnTeam], tree
		)
end
function generic_avoid_magical_dmg_score(gsiPlayer, hItem, nearbyEnemies, nearbyAllies)
	-- FUNCTION IS TEMP SOLN
	if not (hItem:GetCooldownTimeRemaining() == 0 and hItem:IsFullyCastable()
			and HIGH_USE(
					gsiPlayer, hItem, gsiPlayer.highUseManaSimple,
					gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth
				)
			) then
		if TEST then print("can't use generic") end
		return false, XETA_SCORE_DO_NOT_RUN
	end
	if TEST then print(gsiPlayer.shortName, hItem:GetCooldownTimeRemaining() == 0, hItem:IsFullyCastable(), hItem:GetCooldownTimeRemaining()) end
	local projectilesTbl = gsiPlayer.hUnit:GetIncomingTrackingProjectiles()
	for i=1,#projectilesTbl-1 do
		local thisProjectile = projectilesTbl[i]
		if thisProjectile then
			local thisCaster = thisProjectile.caster
			local thisAbility = thisProjectile.ability
			local theorizedDanger = gsiPlayer.time.data.theorizedDanger
			if herothisAbility and (not thisCaster or thisCaster:GetTeam() ~= TEAM)
					and thisAbility:GetDamageType() == DAMAGE_TYPE_MAGICAL
					and (not gsiPlayer.hUnit:IsMagicImmune()
						or B_AND(
								thisAbility:GetTargetFlags(),
								ABILITY_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES
							) > 0
						) then
				if TEST then print("generic magic immune returning") end
				return USE_WITHOUT_TARGET_TYPE, INSTANT_NO_TURNING_SCORE
			end
		end
	end
	if nearbyEnemies[1] then
		local harmIntended, intentsTbl = FightClimate_AnyIntentToHarm(gsiPlayer, nearbyEnemies)
		if TEST then
			
			for i=1,#nearbyEnemies do
				
			end
			for i=1,#intentsTbl do
				--print("intent", intentsTbl[i] and intentsTbl[i].shortName)
			end
		end
		if harmIntended and gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth
					< 0.65 + 0.066*#intentsTbl + 0.033*#nearbyEnemies then
			if TEST then print("generic magic immune returning detecting intent to harm") end
			return USE_WITHOUT_TARGET_TYPE, INSTANT_NO_TURNING_SCORE
		end
	end
	return false, XETA_SCORE_DO_NOT_RUN
end
function generic_self_avoid_magical_dmg_score(gsiPlayer, hItem, nearbyEnemies, nearbyAllies)
	local target, score = generic_avoid_magical_dmg_score(gsiPlayer, hItem, nearbyEnemies, nearbyAllies)
	return target and gsiPlayer or target, score
end
function use_ward_func(gsiPlayer, targetLoc, hItem)
	local itemCarriedResult, wardInventorySlot = Item_EnsureCarriedItemInInventory(gsiPlayer, hItem)
	if itemCarriedResult == ITEM_NOT_FOUND
			or itemCarriedResult == ITEM_ENSURE_RESULT_LOCKED then
		
		return false
	end

	Item_LockInventoryIndex(gsiPlayer, wardInventorySlot, 6)

	if Item_OnItemSwapCooldown(gsiPlayer, hItem) then
		
		Positioning_MoveDirectly(gsiPlayer, targetLoc)
		return true
	end

	if IsLocationVisible(targetLoc) then -- TODO false +ve for flying vision!!!
		
		return false
	end
	if not VAN_GuideWardAtIndexKillDevalued(
				gsiPlayer, t_player_current_ward_index[gsiPlayer.nOnTeam], hItem
			) then
		
		t_player_current_ward_index[gsiPlayer.nOnTeam] = 1
		return false
	end
	
	return gsiPlayer.usableItemCache.wards
end

local printed_fs_err_count = 0
local end_print_fs_err_count = 5
local FSTUT_TARGET_INDEX = 1
local FSTUT_GIVEUP_TIME_INDEX = 2
local FSTUT_DELAY_IF_UNSTABLE = 3
local force_staff_to_unit_tbls = {}
local force_staff_to_unit_dominate
force_staff_to_unit_dominate = function()
	-- Fill force_staff_to_unit_tbls for the player, set dominate. Has timeout / impossible kill.
	local gsiPlayer = GSI_GetBot()
	local fstut_tbl = force_staff_to_unit_tbls[gsiPlayer.nOnTeam]
	if DEBUG then DebugDrawText(500, 530, gsiPlayer.shortName, 255, 255, 0) end
	if not fstut_tbl or not fstut_tbl[1] then
		ERROR_print(false, not DEBUG, "'%s' dominate func had no data!!!\n%s",
				gsiPlayer.shortName or "???",
				Util_PrintableTable(fstut_tbl)
			)
		if fstut_tbl then
			fstut_tbl[1] = false
			fstut_tbl[2] = 0
			fstut_tbl[3] = GameTime() + 40 + RandomInt(0,300) -- + REDUCE_BUGS_TIME_DEF
		end
		if DEBUG then DebugDrawText(500, 540, gsiPlayer.shortName, 255, 255, 0) end
		return
	end

	local target = fstut_tbl[1]
	local giveUp = fstut_tbl[2]
	local forceStaffItemWithinTime = giveUp > GameTime() and Item_GetForceStaffItem(gsiPlayer) or false
	if not forceStaffItemWithinTime then
		
		-- reduce bugs, if applicable, randomly so the player mightn't notice
		if DEBUG then DebugDrawText(500, 540, gsiPlayer.shortName, 255, 0, 0) end
		DOMINATE_SetDominateFunc(gsiPlayer, "DIRECTLY_FS", force_staff_to_unit_dominate, false)
		fstut_tbl[3] = GameTime() + 40 + RandomInt(0,300) -- + REDUCE_BUGS_TIME_DEF
		return
	end
	local distanceToTarget = pUnit_IsNullOrDead(target)
			and false or Vector_PointDistance2D(gsiPlayer.lastSeen.location, target.lastSeen.location)
	if not forceStaffItemWithinTime or not distanceToTarget
			or distanceToTarget < min(400, gsiPlayer.attackRange*0.95) or distanceToTarget > 1400
			or forceStaffItemWithinTime:GetCooldownTimeRemaining() > 0.1 then
		fstut_tbl[1] = false
		fstut_tbl[2] = 0
		fstut_tbl[3] = 0
		DOMINATE_SetDominateFunc(gsiPlayer, "DIRECTLY_FS", force_staff_to_unit_dominate, false)
		if DEBUG then DebugDrawText(500, 540, gsiPlayer.shortName, 255, 0, 255) end
		return
	end
	if Vector_UnitFacingUnit(gsiPlayer, target) > 0.9 then
		gsiPlayer.hUnit:Action_UseAbilityOnEntity(forceStaffItemWithinTime, gsiPlayer.hUnit)
		if DEBUG then DebugDrawText(500, 540, gsiPlayer.shortName, 0, 255, 255) end
		return
	end
	local playerLoc = gsiPlayer.hUnit:GetLocation()
	local moveTo = Vector_UnitDirectionalPointToPoint(playerLoc, target.lastSeen.location)
	if DEBUG then DebugDrawText(500, 550, gsiPlayer.shortName, 255, 255, 255) end
	moveTo = Vector_ScalarMultiply2D(moveTo, 10)
	moveTo = Vector_Addition(playerLoc, moveTo)
	
	
	gsiPlayer.hUnit:Action_MoveDirectly(moveTo)
end

local ITEM_FUNCS_I__SCORE_FUNC = 1
local ITEM_FUNCS_I__RUN_FUNC = 2
ITEM_FUNCS_I = {
	["SCORE_FUNC"] = ITEM_FUNCS_I__SCORE_FUNC,
	["RUN_FUNC"] = ITEM_FUNCS_I__RUN_FUNC
}
T_ITEM_FUNCS = {--[item_name] = {score_func, run_func}, ....
-- TODO Everything
	["item_urn_of_shadows"] = {
			function(gsiPlayer, hItem, nearbyEnemies, nearbyAllies)
				-- NB. urn // vessel generic
				if hItem:GetCurrentCharges() > 0
						and hItem:GetCooldownTimeRemaining() == 0 and hItem:IsFullyCastable() then
					local bestTarget, score = UrnLogic_ScoreUrnVessel(gsiPlayer, nearbyEnemies, nearbyAllies)
					if bestTarget
							and Vector_PointDistance2D(gsiPlayer.lastSeen.location, bestTarget.lastSeen.location)
								< hItem:GetCastRange() then
						-- TODO out-of-range frustration over time
						return bestTarget, score
					end
					-- TODO check FindItemInSlot if it's needed, for now, keep an eye on bugs from this
					-- - due to 0.33s update time in item_logic itemCache indexing.
					return false, XETA_SCORE_DO_NOT_RUN
				end
			end,
			generic_on_entity_func
	},
	["item_phase_boots"] = {
			function(gsiPlayer, hItem, nearbyEnemies, nearbyAllies)
				if hItem:GetCooldownTimeRemaining() == 0 and hItem:IsFullyCastable() then
					local activityType = Blueprint_GetCurrentTaskActivityType(gsiPlayer)
					if activityType >= ACTIVITY_TYPE.FEAR
							or activityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION then
						if TEST then print("phase boots returning") end
						return USE_WITHOUT_TARGET_TYPE, INSTANT_NO_TURNING_SCORE
					end
				end
			end,
			generic_no_target_func	
	},
	["item_glimmer_cape"] = {
			function(gsiPlayer, hItem, nearbyEnemies, nearbyAllies)
				if hItem:GetCooldownTimeRemaining() == 0 and hItem:IsFullyCastable()
						and HIGH_USE(
								gsiPlayer, hItem, gsiPlayer.highUseManaSimple,
								gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth
							) then
					local activityType = Blueprint_GetCurrentTaskActivityType(gsiPlayer)
					local currTaskHandle = CURRENT_TASK(gsiPlayer)
					if activityType >= ACTIVITY_TYPE.FEAR
							or (currTaskHandle == lurk_task_handle
								and vectorAddedMovementThreeHundredUnitsIsKnownVisibleToEnemy) then -- TODO
						if TEST then print("glimmer returning") end
						return gsiPlayer, INSTANT_NO_TURNING_SCORE
					end
				end
			end,
			generic_on_entity_func
	},
	["item_invis_sword"] = {
			function(gsiPlayer, hItem, nearbyEnemies, nearbyAllies)
				if TEST then print(hItem:GetCooldownTimeRemaining() == 0, hItem:IsFullyCastable(), HIGH_USE(
							gsiPlayer, hItem,
							gsiPlayer.highUseManaSimple, gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth
						)
					) end
				if hItem:GetCooldownTimeRemaining() == 0 and hItem:IsFullyCastable() 
						and HIGH_USE(
								gsiPlayer, hItem, gsiPlayer.highUseManaSimple,
								gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth
							) then
					local activityType = Blueprint_GetCurrentTaskActivityType(gsiPlayer)
					local currTaskHandle = CURRENT_TASK(gsiPlayer)
					local theorizedDanger = gsiPlayer.time.data.theorizedDanger
					local fht = TASK_OBJ(gsiPlayer, fight_harass_handle)
					local fhtHpp = fht and Unit_GetHealthPercent(fht)
					local distToFht = fht
							and Vector_PointDistance2D(gsiPlayer.lastSeen.location, fht.lastSeen.location)
					if TEST then print(activityType >= ACTIVITY_TYPE.FEAR) end
					if activityType >= ACTIVITY_TYPE.FEAR
							or (fht and theorizedDanger and currTaskHandle == fight_harass_handle
									and theorizedDanger < -3.0 and fhtHpp < 0.1
									and fht.lastSeenHealth > ACTUAL_ATTACK(gsiPlayer.hUnit, fht.hUnit)
									and distToFht / gsiPlayer.attackRange
											> 0.6 -- orb walk efficiency, save SB if you don't need it
												+ 0.2 * gsiPlayer.attackPointPercent
													* gsiPlayer.hUnit:GetSecondsPerAttack())
							or (currTaskHandle == lurk_task_handle
								and vectorAddedMovementThreeHundredUnitsIsKnownVisibleToEnemy) then -- TODO
						if TEST then print("shadow blade returning") end
						return USE_WITHOUT_TARGET_TYPE, INSTANT_NO_TURNING_SCORE
					end
				end
			end,
			generic_no_target_func
	},
	["item_lotus_orb"] = nil, --[[{
			generic_self_avoid_magical_dmg_score,
			generic_on_entity_func
	},]]
	["item_hand_of_midas"] = {
			function(gsiPlayer, hItem, nearbyEnemies, nearbyAllies)
				local castRange = hItem:GetCastRange()
				if not (hItem:GetCooldownTimeRemaining() == 0 and hItem:IsFullyCastable()) then
					return false, XETA_SCORE_DO_NOT_RUN
				end
				local activityType = CURR_ACTIVITY_TYPE(gsiPlayer)
				if activityType >= ACTIVITY_TYPE.FEAR then
					local nearbyCreeps = gsiPlayer.hUnit:GetNearbyCreeps(castRange, true) -- yoink, bye
					if nearbyCreeps[1] and not nearbyCreeps[1]:IsAncientCreep() then
						if TEST then print("midas 1 returning", nearbyCreeps[1], INSTANT_NO_TURNING_SCORE) end
						return nearbyCreeps[1], INSTANT_NO_TURNING_SCORE
					end
					return false, XETA_SCORE_DO_NOT_RUN
				end
				local nearbyCreeps = gsiPlayer.hUnit:GetNearbyCreeps(castRange*1.66, true) -- yoink, bye
				if nearbyCreeps[1] then
					local highestXP = 0
					local highestUnit
					for i=1,#nearbyCreeps do
						local thisCreep = nearbyCreeps[i]
						if not thisCreep:IsAncientCreep() and thisCreep:GetBountyXP() > highestXP then
							highestXP = thisCreep:GetBountyXP()
							highestUnit = thisCreep
						end
					end
					--print("trying eat", midas:GetName())
					if highestUnit and
							(activityType > ACTIVITY_TYPE.CONTROLLED_AGGRESSION
								or Vector_PointDistance2D(
									gsiPlayer.lastSeen.location,
									highestUnit:GetLocation()
								) < castRange
							) then
						if TEST then
							DebugDrawLine(gsiPlayer.lastSeen.location, highestUnit:GetLocation(), 0, 255, 255)
							
						end
						-- only walk to it if you're not fighting (we arne't feared)
						-- always use it in range
						return highestUnit, INSTANT_NO_TURNING_SCORE
					end
					return false, XETA_SCORE_DO_NOT_RUN
				end
			end,
			generic_on_entity_func
	},
	["item_hood_of_defiance"] = {
			generic_avoid_magical_dmg_score,
			generic_no_target_func
	},
	["item_pipe"] = {
			generic_avoid_magical_dmg_score,
			generic_no_target_func
	},
	["item_soul_ring"] = {
			function(gsiPlayer, hItem, nearbyEnemies, nearbyAllies)
				-- TODO simplistic for now -- rather per-ability checks registered, or use to allow a stun if trying to escape
				local hUnitPlayer = gsiPlayer.hUnit
				local qAbility = hUnitPlayer:GetAbilityInSlot(0)
				local wAbility = hUnitPlayer:GetAbilityInSlot(1)
				local eAbility = hUnitPlayer:GetAbilityInSlot(2)
				
				if nearbyEnemies[1] and gsiPlayer.lastSeenMana < gsiPlayer.highUseManaSimple * 2.5
						and ( (not qAbility:IsPassive() and qAbility:GetCooldownTimeRemaining() == 0)
							or (not wAbility:IsPassive() and wAbility:GetCooldownTimeRemaining() == 0)
							or (not eAbility:IsPassive() and eAbility:GetCooldownTimeRemaining() == 0)
						) then
					local playerHpp = gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth
					local activityType = CURR_ACTIVITY_TYPE(gsiPlayer)
					local danger = Analytics_GetTheoreticalDangerAmount(gsiPlayer)
					if activityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION
							and danger < (-2.0 + 1.5*(playerHpp)) then
						return USE_WITHOUT_TARGET_TYPE, INSTANT_NO_TURNING_SCORE
					else
						local nearestEnemy, nearestEnemyDist
								= Set_GetNearestEnemyHeroToLocation(gsiPlayer.lastSeen.location)
						if activityType >= ACTIVITY_TYPE.CAREFUL
							and nearestEnemy and gsiPlayer.lastSeenMana < gsiPlayer.highUseManaSimple/2
							and gsiPlayer.lastSeenHealth > (pUnit_IsNullOrDead(nearestEnemy) and 120 or nearestEnemy.hUnit:GetAttackDamage()*#nearbyEnemies)
							and playerHpp < abs(danger)^3 then -- If your health is less than extreme danger or extreme non-danger -- i.e. hero is probably dead either way, or very doubtful to be caught anyways
							if nearestEnemyDist < nearestEnemy.attackRange*1.5 then
								return USE_WITHOUT_TARGET_TYPE, INSTANT_NO_TURNING_SCORE
							end
						end
					end
				end
			end,
			generic_no_target_func
	},
	["item_black_king_bar"] = {
			generic_avoid_magical_dmg_score,
			generic_no_target_func
	},
	["item_blink"] = {
			function(gsiPlayer, hItem, nearbyEnemies, nearbyAllies)
				-- TODO 
				if not (hItem:GetCooldownTimeRemaining() == 0 and hItem:IsFullyCastable()) then
					return false, XETA_SCORE_DO_NOT_RUN
				end
				local playerLoc = gsiPlayer.lastSeen.location
				local currTaskHandle = CURRENT_TASK(gsiPlayer)
				local theorizedDanger = gsiPlayer.time.data.theorizedDanger
				local fht = TASK_OBJ(gsiPlayer, fight_harass_handle)
				if TEST then print("blink", currTaskHandle, theorizedDanger) end
				if (currTaskHandle == fight_harass_handle and fht)
						and theorizedDanger and theorizedDanger < -2
						and Vector_PointDistance2D(playerLoc, fht.lastSeen.location)
								> min(350, gsiPlayer.attackRange
										* (gsiPlayer.currentMovementSpeed
												/ fht.currentMovementSpeed
											)
									) then
					if TEST then print("blink returning") end
					local blinkLoc = Vector_Addition(
							fht.lastSeen.location,
							Vector_ScalarMultiply2D(
									Vector_UnitDirectionalPointToPoint(
											playerLoc,
											fht.lastSeen.location
										),
									max(200, gsiPlayer.attackRange*0.75)
								)
						)
					return blinkLoc, INSTANT_NO_TURNING_SCORE
				elseif currTaskHandle == search_fog_handle then
					local escapeEstimate = SearchFog_GetEscapeGuess(gsiPlayer)
					escapeEstimate = escapeEstimate and escapeEstimate.val
					local distToEscapeEstimate = escapeEstimate and Vector_PointDistance2D(
							playerLoc,
							escapeEstimate
						)
					if escapeEstimate and distToEscapeEstimate > 450 then
						if Analytics_GetTheoreticalDangerAmount(gsiPlayer, nil, escapeEstimate) < -1 then
							local blinkLocation = Vector_Addition(playerLoc,
									Vector_ScalarMultiply(
										Vector_UnitDirectionalPointToPoint(playerLoc, escapeEstimate),
										600 + 0.75*(distToEscapeEstimate - 600)
									)
								)
							return blinkLocation, INSTANT_NO_TURNING_SCORE
						end
					end
				end
				local activityType = CURR_ACTIVITY_TYPE(gsiPlayer)
				if TEST then print(activityType) end
				if activityType >= ACTIVITY_TYPE.FEAR then
					if TEST then print("fear blink returning") end
					return TEAM_FOUNTAIN, INSTANT_NO_TURNING_SCORE
				end
				return false, XETA_SCORE_DO_NOT_RUN
			end,
			generic_on_location_func
	},
	["item_crimson_guard"] = {
			function(gsiPlayer, hItem, nearbyEnemies, nearbyAllies)
				if hItem:GetCooldownTimeRemaining() > 0 then return; end
				if nearbyEnemies[1] then
					local harmIntended, intentsTbl = FightClimate_AnyIntentToHarm(gsiPlayer, nearbyEnemies)
					local numEnemies = #nearbyEnemies
					for i=1,numEnemies do
						if harmIntended and intentsTbl[i] then
							if Vector_PointDistance(
											intentsTbl[i].lastSeen.location,
											nearbyEnemies[i].lastSeen.location
										) < 1150
									and intentsTbl[i].lastSeenHealth / intentsTbl[i].maxHealth
										< 0.66*numEnemies then
								return USE_WITHOUT_TARGET_TYPE, INSTANT_NO_TURNING_SCORE
							end
						end
					end
				end
			end,
			generic_no_target_func
	},
	["item_diffusal_blade"] = {
			function(gsiPlayer, hItem, nearbyEnemies, nearbyAllies)
				if hItem:GetCooldownTimeRemaining() > 0 then return; end
				local fht, fhtReal = FightHarass_GetTarget(gsiPlayer)
				if not fhtReal then return; end
				if FightClimate_IsTryingToEscapeFromPlayer(fht, gsiPlayer) then
					return fht, INSTANT_NO_TURNING_SCORE
				end
			end,
			generic_on_entity_func
	},
	["item_blood_grenade"] = {
			function(gsiPlayer, hItem, nearbyEnemies, nearbyAllies)
				if hItem:GetCooldownTimeRemaining() > 0 then return; end

				local activityType = CURR_ACTIVITY_TYPE(gsiPlayer)
				if activityType > ACTIVITY_TYPE.CONTROLLED_AGGRESSION then return; end

				local fht, fhtReal = FightHarass_GetTarget(gsiPlayer)
				if not fhtReal then return; end

				local distUnits = Vector_DistUnitToUnit(gsiPlayer, fht)
				
				if distUnits > hItem:GetCastRange() + 150 then return; end
				if FightClimate_IsTryingToEscapeFromPlayer(fht, gsiPlayer) then
					
					if FightClimate_NoSlowIsLostKillSimple( gsiPlayer, fht, 0.15, 93)
							and gsiPlayer.lastSeenHealth > 300 then
						return fht.lastSeen.location, INSTANT_NO_TURNING_SCORE
					end
					
				end
				if fht.lastSeenHealth + fht.hUnit:GetHealthRegen()*6
							< 125 * fht.magicTaken
						and ( fht.currentMovementSpeed > gsiPlayer.currentMovementSpeed
						and distUnits > gsiPlayer.attackRange + 40
						or Analytics_GetFutureDamageInTimeline(gsiPlayer.hUnit)
								> gsiPlayer.lastSeenHealth
						) then
					return fht.hUnit:GetExtrapolatedLocation(0.25), INSTANT_NO_TURNING_SCORE*2
				end
			end,
			generic_on_location_func
	},
	["item_gungir"] = {
			function(gsiPlayer, hItem, nearbyEnemies, nearbyAllies)
				--TODO TEMP
				local playerHpp = gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth
				if not (hItem:GetCooldownTimeRemaining() == 0 and hItem:IsFullyCastable()
							and HIGH_USE(gsiPlayer, hItem, gsiPlayer.highUseManaSimple, playerHpp)
						) then
					return false, XETA_SCORE_DO_NOT_RUN
				end
				local activityType = CURR_ACTIVITY_TYPE(gsiPlayer)
				local fht = TASK_OBJ(gsiPlayer, fight_harass_handle)
				local usingNearest = false
				if activityType >= ACTIVITY_TYPE.FEAR then
					fht = NEAREST_UNIT(gsiPlayer, nearbyEnemies)
					usingNearest = true
				end
				fht = fht and not fht.typeIsNone and fht or false
				local fhtLoc = fht and fht.lastSeen.location
				local distanceToFht = fht and Vector_PointDistance2D(
						gsiPlayer.lastSeen.location, fhtLoc
					)
				if fht and (usingNearest or activityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION)
						and distanceToFht < hItem:GetCastRange()
								*(1+0.1*Vector_UnitFacingUnit(gsiPlayer, fht)) then
					local timeToPredict = distanceToFht / GLEIPNIR_PROJECTILE_SPEED
					local extrapolatedLocFht = fht.hUnit:GetExtrapolatedLocation(timeToPredict)
					local crowdedCenter, crowdedRating = CROWDED_RATING(extrapolatedLocFht, SET_HERO_ENEMY)
					-- TODO cop-out from finding most units hit
					-- TODO Help allies
					if Vector_PointDistance2D(fhtLoc, crowdedCenter) > GLEIPNIR_RADIUS*0.85 then
						return extrapolatedLocFht, INSTANT_NO_TURNING_SCORE
					elseif HIGH_USE(
								gsiPlayer, hItem, 
								2*gsiPlayer.highUseManaSimple/crowdedRating, playerHpp
							) then
						return crowdedCenter, INSTANT_NO_TURNING_SCORE
					end
				end
				return false, XETA_SCORE_DO_NOT_RUN
			end,
			generic_on_location_func
	},
	["item_rod_of_atos"] = {
			function(gsiPlayer, hItem, nearbyEnemies, nearbyAllies)
				if not (hItem:GetCooldownTimeRemaining() == 0 and hItem:IsFullyCastable()) then
					return false, XETA_SCORE_DO_NOT_RUN
				end
				-- TODO TEMP
				local activityType = CURR_ACTIVITY_TYPE(gsiPlayer)
				local targ = TASK_OBJ(gsiPlayer, fight_harass_handle)
				if not targ then
					targ = NEAREST_UNIT(gsiPlayer, nearbyEnemies)
				end
				if targ and Vector_PointDistance2D(gsiPlayer.lastSeen.location, targ.lastSeen.location)
							< hItem:GetCastRange()
						and (activityType >= ACTIVITY_TYPE.FEAR
								or activityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION
							)
						and HIGH_USE(
							gsiPlayer, hItem, gsiPlayer.highUseManaSimple, targ.lastSeenHealth/targ.maxHealth)
						then
					return targ, INSTANT_NO_TURNING_SCORE
				end
			end,
			generic_on_entity_func
	},
	["item_cyclone"] = {
			function(gsiPlayer, hItem, nearbyEnemies, nearbyAllies)
				if not (hItem:GetCooldownTimeRemaining() == 0 and hItem:IsFullyCastable()
							and HIGH_USE(gsiPlayer, hItem, gsiPlayer.highUseManaSimple,
									gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth
								)
						) then
					return false, XETA_SCORE_DO_NOT_RUN
				end
				local activityType = CURR_ACTIVITY_TYPE(gsiPlayer)
				local _, intentsTbl
				if nearbyEnemies[1] then
					_, intentsTbl = FightClimate_AnyIntentToHarm(gsiPlayer, nearbyEnemies)
				else
					return false, XETA_SCORE_DO_NOT_RUN
				end
				local fht = TASK_OBJ(gsiPlayer, fight_harass_handle)
				local highestUseTarget
				local highestUseScore = 0
				local selfFeared = activityType >= ACTIVITY_TYPE.FEAR
				local castRange = hItem:GetCastRange() + (selfFeared and 50 or 250)
				local numberNearbyEnemies = #nearbyEnemies
				-- TODO TEMP -- add use of registered important phase, stun, root responses
				for i=1,numberNearbyEnemies do
					local thisIntended = intentsTbl[i]
					local thisAggressor = nearbyEnemies[i]
					if thisIntended and not pUnit_IsNullOrDead(thisAggressor)
								and (numberNearbyEnemies > 1 and not thisAggressor == fht
								-- do not euls a solo enemy if nobody is in serious danger
								or thisIntended.lastSeenHealth / thisIntended.maxHealth < 0.25
							) and Vector_PointDistance2D(
									gsiPlayer.lastSeen.location,
									thisAggressor.lastSeen.location
								) < castRange then
						local alliedArmor = gsiPlayer.hUnit:GetArmor()
						local alliedArmorFactor = 1 - (ARMOR_FACTOR*alliedArmor)
								/ (1+ARMOR_FACTOR*abs(alliedArmor))
						local thisUseScore = (thisAggressor.hUnit:GetAttackDamage()
									* thisAggressor.lastSeenHealth / thisAggressor.maxHealth
								) * thisIntended.lastSeenHealth * alliedArmorFactor
						if thisUseScore > highestUseScore then
							highestUseScore = thisUseScore
							highestUseTarget = thisAggressor
						end
					end
				end
				if highestUseTarget then
					return highestUseTarget, INSTANT_NO_TURNING_SCORE
				end
			end,
			generic_on_entity_func
	},
	["item_meteor_hammer"] = {
			function(gsiPlayer, hItem, nearbyEnemies, nearbyAllies)
				if not (hItem:GetCooldownTimeRemaining() == 0 and hItem:IsFullyCastable()) then
					return false, XETA_SCORE_DO_NOT_RUN
				end
				local activityType = CURR_ACTIVITY_TYPE(gsiPlayer)
				local currTask = CURRENT_TASK(gsiPlayer)
				local danger = Analytics_GetTheoreticalDangerAmount(gsiPlayer)
					local nearbyTower = Set_GetNearestTeamTowerToPlayer(ENEMY_TEAM, gsiPlayer)
				if TEST then print(
						HIGH_USE(gsiPlayer, hItem, gsiPlayer.highUseManaSimple*2,
								1 - gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth
							),
					nearbyTower, nearbyTower and nearbyTower.lastSeenHealth
								> gsiPlayer.hUnit:GetAttackDamage()*0.2*3, 
								nearbyTower and Vector_PointDistance2D(
									gsiPlayer.lastSeen.location,
									nearbyTower.lastSeen.location
								) < hItem:GetCastRange() * 1.75,
							not gsiPlayer.hUnit:WasRecentlyDamagedByAnyHero(2.5),
							not gsiPlayer.hUnit:WasRecentlyDamagedByTower(1.5))
				end
				if currTask == push_handle and danger and danger < -1.5
						and HIGH_USE(gsiPlayer, hItem, gsiPlayer.highUseManaSimple*2,
								1 - gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth
							) then
					local nearbyTower = Set_GetNearestTeamTowerToPlayer(ENEMY_TEAM, gsiPlayer)
					if nearbyTower and nearbyTower.lastSeenHealth
								> gsiPlayer.hUnit:GetAttackDamage()*0.2*3
							and Vector_PointDistance2D(
									gsiPlayer.lastSeen.location,
									nearbyTower.lastSeen.location
								) < hItem:GetCastRange() * 1.75
							and not gsiPlayer.hUnit:WasRecentlyDamagedByAnyHero(2.5)
							and not gsiPlayer.hUnit:WasRecentlyDamagedByTower(1.5) then
						return Vector_ScalePointToPointByFactor(
									nearbyTower.lastSeen.location, gsiPlayer.lastSeen.location,
									1, METEOR_HAMMER_RADIUS*0.85
								),
								INSTANT_NO_TURNING_SCORE
					end
				end
			end,
			function(gsiPlayer, target, hItem)
				local currentCd = hItem:GetCooldownTimeRemaining()
				local currentActive = gsiPlayer.hUnit:GetCurrentActiveAbility()
				if currentActive and currentActive:GetName() == (hItem and hItem:GetName()) then
					Task_IncentiviseTask(gsiPlayer, task_handle, 100, 30)
				end
				gsiPlayer.hUnit:Action_UseAbilityOnLocation(
						t_player_current_use[gsiPlayer.nOnTeam], target
					)
				if currentCd == 0 and Vector_PointDistance2D(gsiPlayer.lastSeen.location, target)
							< hItem:GetCastRange()
						and hItem:GetManaCost() < gsiPlayer.lastSeenMana
						and CAN_BE_CAST(gsiPlayer, hItem) then
					UseItem_RegisterCaughtAbility(gsiPlayer, hItem) -- hotfix
					return true
				end
			end
	},
	["item_shivas_guard"] = {
			function(gsiPlayer, hItem, nearbyEnemies, nearbyAllies)
				--TODO TEMP
				local playerHpp = gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth
				if not (hItem:GetCooldownTimeRemaining() == 0 and hItem:IsFullyCastable()
							and HIGH_USE(gsiPlayer, hItem, gsiPlayer.highUseManaSimple, playerHpp)
						) then
					return false, XETA_SCORE_DO_NOT_RUN
				end
				local activityType = CURR_ACTIVITY_TYPE(gsiPlayer)
				local fht = TASK_OBJ(gsiPlayer, fight_harass_handle)
				local usingNearest = false
				if activityType >= ACTIVITY_TYPE.FEAR then
					fht = NEAREST_UNIT(gsiPlayer, nearbyEnemies)
					usingNearest = true
				end
				local radius = hItem:GetSpecialValueInt("blast_radius")
				local playerLoc = gsiPlayer.lastSeen.location
				local nearbyCount = #nearbyEnemies
				local inRangeCount = 0
				for i=1,nearbyCount do
					if Vector_PointDistance2D(playerLoc, nearbyEnemies[i].lastSeen.location) < radius then
						inRangeCount = inRangeCount + 1
					end
				end
				if TEST then print(fht, usingNearest, inRangeCount, nearbyCount) end
				-- TODO Register a timed desired distance to a (percentage / danger) of enemies to positioning
				if fht and (usingNearest or inRangeCount >= max(1, nearbyCount * 0.5)) then
					return USE_WITHOUT_TARGET_TYPE, INSTANT_NO_TURNING_SCORE
				end
				return false, XETA_SCORE_DO_NOT_RUN
			end,
			generic_no_target_func
	},
	["item_hurricane_pike"] = {
			function(gsiPlayer, hItem, nearbyEnemies, nearbyAllies)
				-- TODO TEMP			
				local playerHpp = gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth
				local activityType = CURR_ACTIVITY_TYPE(gsiPlayer)
				if not (hItem:GetCooldownTimeRemaining() == 0 and hItem:IsFullyCastable()
							and HIGH_USE(gsiPlayer, hItem,
									gsiPlayer.highUseManaSimple
										* (1 + (activityType-COUNT_ACTIVITY_TYPES) * 0.5 / COUNT_ACTIVITY_TYPES),
									playerHpp
								)
						) then
					return false, XETA_SCORE_DO_NOT_RUN
				end
				local activityType = CURR_ACTIVITY_TYPE(gsiPlayer)
				local fht = TASK_OBJ(gsiPlayer, fight_harass_handle)
				local fhtReal = fht and not pUnit_IsNullOrDead(fht)
				local usingNearest = false
				if activityType >= ACTIVITY_TYPE.FEAR then
					fht = NEAREST_UNIT(gsiPlayer, nearbyEnemies)
					usingNearest = true
				end
				if not fht or not fhtReal then
					return false, XETA_SCORE_DO_NOT_RUN
				end
				local danger = Analytics_GetTheoreticalDangerAmount(gsiPlayer)
				local playerLoc = gsiPlayer.lastSeen.location
				local fhtInRange = Vector_PointDistance2D(playerLoc, fht.lastSeen.location)
						< hItem:GetCastRange()*1.1
				if usingNearest then
				--[[	if fhtInRange and Vector_UnitFacingUnit(fht, gsiPlayer) > 0.85 then
						return fht, INSTANT_NO_TURNING_SCORE
						-- Bugged if we are between scary unit and more enemies
					end	--]]
					if Vector_UnitFacingUnit(gsiPlayer, GSI_GetTeamFountainUnit(TEAM)) > 0.8
							and Analytics_GetTheoreticalDangerAmount(gsiPlayer,
									nearbyAllies,
									Vector_Addition(
											playerLoc,
											Vector_ScalarMultiply2D(
													Vector_UnitDirectionalFacingDirection(
															gsiPlayer.hUnit:GetFacing()
														),
													550
												)
										)
								) < danger then
						return gsiPlayer, INSTANT_NO_TURNING_SCORE
					end
				end
				if fht and activityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION
						and (1.25-fht.lastSeenHealth/fht.maxHealth) * danger < -0.5 then
					if DEBUG then DebugDrawText(500, 510, string.format("%.3s fs cons", gsiPlayer.shortName), 255, 255, 255) end
					local distanceToFht = Vector_PointDistance2D(gsiPlayer.lastSeen.location, fht.lastSeen.location)
					if distanceToFht < max(200, gsiPlayer.attackRange*0.8) or distanceToFht > 1400 then
						if DEBUG then DebugDrawText(550, 510, gsiPlayer.shortName, 255, 255, 255) end
						return false, XETA_SCORE_DO_NOT_RUN
					end
					local facingAmount = Vector_UnitFacingUnit(fht, gsiPlayer)
					if facingAmount >= 0.75 then
						if DEBUG then DebugDrawText(500, 520, gsiPlayer.shortName, 255, 255, 255) end
						if facingAmount > 0.95 then
							if DEBUG then DebugDrawText(550, 520, gsiPlayer.shortName, 255, 255, 255) end
							return fht, INSTANT_NO_TURNING_SCORE
						end
						-- Dominate a direct force staff move
						if DEBUG then
							INFO_print(string.format("%s is being dominated for force staff move.", gsiPlayer.shortName))
						end
						local fstut_tbl = force_staff_to_unit_tbls[gsiPlayer.nOnTeam]
						if not fstut_tbl then
							fstut_tbl = {}
							force_staff_to_unit_tbls[gsiPlayer.nOnTeam] = fstut_tbl
						elseif fstut_tbl[FSTUT_DELAY_IF_UNSTABLE] > GameTime() then
							if DEBUG then DebugDrawText(750, 520, gsiPlayer.shortName, 255, 255, 255) end
							return false, XETA_SCORE_DO_NOT_RUN
						end
						fstut_tbl[1] = fht
						fstut_tbl[2] = GameTime() + 0.5
						fstut_tbl[3] = 0

						DOMINATE_SetDominateFunc(gsiPlayer, "DIRECTLY_FS", force_staff_to_unit_dominate, true)
						return false, XETA_SCORE_DO_NOT_RUN -- It is not ready for use, technically
					end
				end
				return false, XETA_SCORE_DO_NOT_RUN
			end,
			generic_on_entity_func
	},
	["item_orchid"] = {
			function(gsiPlayer, hItem, nearbyEnemies, nearbyAllies)
				if TEST then print(hItem:GetCooldownTimeRemaining() == 0, hItem:IsFullyCastable()) end
				if not (hItem:GetCooldownTimeRemaining() == 0 and hItem:IsFullyCastable()) then
					return false, XETA_SCORE_DO_NOT_RUN
				end
				-- TODO TEMP
				local activityType = CURR_ACTIVITY_TYPE(gsiPlayer)
				local targ = TASK_OBJ(gsiPlayer, fight_harass_handle)
				if not targ then
					targ = NEAREST_UNIT(gsiPlayer, nearbyEnemies)
				end
				if TEST then print(targ) end
				if targ and Vector_PointDistance2D(gsiPlayer.lastSeen.location, targ.lastSeen.location)
							< hItem:GetCastRange()
						and (activityType >= ACTIVITY_TYPE.FEAR
								or activityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION
							)
						and HIGH_USE(
							gsiPlayer, hItem, gsiPlayer.highUseManaSimple, targ.lastSeenHealth/targ.maxHealth)
						then
					return targ, INSTANT_NO_TURNING_SCORE
				end
				return false, XETA_SCORE_DO_NOT_RUN
			end,
			generic_on_entity_func
	},
	["item_satanic"] = {
			function(gsiPlayer, hItem, nearbyEnemies, nearbyAllies)
				if TEST then print(hItem:GetCooldownTimeRemaining() == 0, hItem:IsFullyCastable()) end
				if not (hItem:GetCooldownTimeRemaining() == 0 and hItem:IsFullyCastable())
						or gsiPlayer.hUnit:IsDisarmed()
						or Analytics_GetNearFutureHealth(gsiPlayer) > gsiPlayer.maxHealth / 2 then
					return false, XETA_SCORE_DO_NOT_RUN
				end
				-- TODO TEMP
				local activityType = CURR_ACTIVITY_TYPE(gsiPlayer)
				local targ = TASK_OBJ(gsiPlayer, fight_harass_handle)
				if not targ then
					return false, XETA_SCORE_DO_NOT_RUN
				end
				if Vector_PointDistance2D(gsiPlayer.lastSeen.location, targ.lastSeen.location)
							< gsiPlayer.attackRange
						and activityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION then
					return targ, INSTANT_NO_TURNING_SCORE
				end
				return false, XETA_SCORE_DO_NOT_RUN
			end,
			generic_on_entity_func
	},
	["item_harpoon"] = {
			function(gsiPlayer, hItem, nearbyEnemies, nearbyAllies)
				if hItem:GetCooldownTimeRemaining() > 0 then return; end
				local activityType = CURR_ACTIVITY_TYPE(gsiPlayer)
				local fht = TASK_OBJ(gsiPlayer, fight_harass_handle)

				if not fht or activityType > ACTIVITY_TYPE.CONTROLLED_AGGRESSION
						or pUnit_IsNullOrDead(fht) then
					return;
				end
				local distFht = Vector_DistUnitToUnit(gsiPlayer, fht)

				local castRange = hItem:GetCastRange()

				

				if distFht > castRange*0.8 and distFht < castRange+40 then
					return fht, INSTANT_NO_TURNING_SCORE
				end
			end,
			generic_on_entity_func
	},
	["item_dagon"] = {
			function(gsiPlayer, hItem, nearbyEnemies, nearbyAllies)
				if not (hItem:GetCooldownTimeRemaining() == 0 and hItem:IsFullyCastable()) then
					return false, XETA_SCORE_DO_NOT_RUN
				end
				-- TODO TEMP
				local activityType = CURR_ACTIVITY_TYPE(gsiPlayer)
				local targ = TASK_OBJ(gsiPlayer, fight_harass_handle)
				-- TODO find kills
				if not targ then
					return false, XETA_SCORE_DO_NOT_RUN
				end
				if Vector_PointDistance2D(gsiPlayer.lastSeen.location, targ.lastSeen.location)
							< hItem:GetCastRange()
						and (activityType >= ACTIVITY_TYPE.FEAR
								or activityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION
							)
						and HIGH_USE(
							gsiPlayer, hItem, gsiPlayer.highUseManaSimple, targ.lastSeenHealth/targ.maxHealth)
						then
					return targ, INSTANT_NO_TURNING_SCORE
				end
			end,
			generic_on_entity_func
	},
	["item_sheepstick"] = {
			function(gsiPlayer, hItem, nearbyEnemies, nearbyAllies)
				if not (hItem:GetCooldownTimeRemaining() == 0 and hItem:IsFullyCastable()) then
					return false, XETA_SCORE_DO_NOT_RUN
				end
				-- TODO TEMP
				local activityType = CURR_ACTIVITY_TYPE(gsiPlayer)
				local targ = TASK_OBJ(gsiPlayer, fight_harass_handle)
				if not targ then
					targ = NEAREST_UNIT(gsiPlayer, nearbyEnemies)
				end
				if targ and Vector_PointDistance2D(gsiPlayer.lastSeen.location, targ.lastSeen.location)
							< hItem:GetCastRange()
						and (activityType >= ACTIVITY_TYPE.FEAR
								or activityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION
							)
						and HIGH_USE(
							gsiPlayer, hItem, gsiPlayer.highUseManaSimple, targ.lastSeenHealth/targ.maxHealth)
						then
					return targ, INSTANT_NO_TURNING_SCORE
				end
			end,
			generic_on_entity_func
	},
	["item_ward_dispenser"] = {
			function(gsiPlayer, hItem, nearbyEnemies, nearbyAllies)
				-- TODO IS SIMPLISTIC
				if hItem:IsNull() then
					return false
				end
				local wardLoc, wardIndex, wardDist
						= VAN_GetClosestBestWardToLoc(gsiPlayer.lastSeen.location)
				if not wardLoc then
					return false
				end
				local wardNowScore = gsiPlayer.time.data.wardNowScore
				if not wardNowScore then
					local wardsUp = GetUnitList(UNIT_LIST_ALLIED_WARDS)
					wardsUpCount = wardsUp and #wardsUp or 0
					distToWardMayPlace = Vector_PointDistance(
							gsiPlayer.lastSeen.location,
							wardLoc
						)
					local nearestEnemy, nearestEnemyDist
							= Set_GetNearestEnemyHeroToLocation(gsiPlayer.lastSeen.location, 8)
					local timeOfDay = GetTimeOfDay()
					wardNowScore = 180 - (
							55*wardsUpCount
							+ min(160, (distToWardMayPlace^2)/400000)
							+ (nearestEnemy
								and 180 - max(0, min(180,
										(nearestEnemyDist
											- ((timeOfDay>0.75 or timeOfDay<0.25) and 850 or 1650)
										) / 3
									)
								) or 0
							)
						)

					gsiPlayer.time.data.wardNowScore = wardNowScore
					gsiPlayer.time.data.wardScoreIndex = wardIndex
				end
				--print("ward", wardIndex, gsiPlayer.time.data.wardScoreIndex, gsiPlayer.time.data.wardNowScore, wardLoc)
				-- confirm wards on map state is still the same if using time data
				if wardIndex == gsiPlayer.time.data.wardScoreIndex--[[ and wardNowScore*0.85 > Task_GetCurrentTaskScore(gsiPlayer)]] then
					local ensureResult, index = Item_EnsureCarriedItemInInventory(gsiPlayer,
							hItem, false, wardNowScore < Task_GetCurrentTaskScore(gsiPlayer)) -- TODO shoddy, what's current frame best? Causes mistakes rarely but switch items is a whole thing in terms of item logic.
					Item_LockInventoryIndex(gsiPlayer, index, 6)
					t_player_current_ward_index[gsiPlayer.nOnTeam] = wardIndex
					return wardLoc, wardNowScore
				end
			end,
			use_ward_func
	},
	["item_quelling_blade"] =  {
			function(gsiPlayer, hItem, nearbyEnemies, nearbyAllies)
				if not (hItem:GetCooldownTimeRemaining() == 0 and hItem:IsFullyCastable()) then
					return false, XETA_SCORE_DO_NOT_RUN
				end
				if GameTime() % 0.33 < 0.05 then
					local lastSeen = gsiPlayer.lastSeen
					if not (gsiPlayer.hUnit:IsStunned() or gsiPlayer.hUnit:IsRooted())
							and gsiPlayer.hUnit:GetMovementDirectionStability() == 1 then
						local facingMoveTo = gsiPlayer.recentMoveTo
								and Vector_UnitFacingLoc(gsiPlayer, gsiPlayer.recentMoveTo) or -1
						local isMoving = lastSeen.previousLocation ~= lastSeen.location
								and lastSeen.facingDegrees ~= lastSeen.previousFacingDegrees
						if isMoving and facingMoveTo < 0.67 then
							local trees = gsiPlayer.hUnit:GetNearbyTrees(125)
							if not trees or not trees[1] then return; end
							t_tree_target[gsiPlayer.nOnTeam] = trees[1]
							return GetTreeLocation(trees[1]), INSTANT_NO_TURNING_SCORE / 2
						end
					end

					if gsiPlayer.recentMoveTo
							and (GameTime()+gsiPlayer.nOnTeam*0.1) % 0.5 < 0.1 then
						local trees = gsiPlayer.hUnit:GetNearbyTrees(250)
						if not trees or not trees[1] then return; end
						local closestTree = 0xFFF
						local closestFacingTree
						local playerLoc = gsiPlayer.lastSeen.location
						for i=1,#trees do
							local treeLoc = GetTreeLocation(trees[i])
							local facing = Vector_UnitFacingLoc(gsiPlayer, treeLoc)
							if facing > 0.5 then
								local dist = ((playerLoc.x-treeLoc.x)^2 + (playerLoc.y-treeLoc.y)^2)^0.5
								if facing > 0.95 - 0.1*(dist/250) and dist < closestTree then
									closestTree = dist
									closestFacingTree = trees[i]
								end
							end
						end
						if closestFacingTree then
							t_tree_target[gsiPlayer.nOnTeam] = closestFacingTree
							return GetTreeLocation(closestFacingTree), INSTANT_NO_TURNING_SCORE*0.75
						end
					end
				end
			end,
			generic_on_tree_func
	},
	["item_armlet"] = {
			function(gsiPlayer, hItem, nearbyEnemies, nearbyAllies)
				if gsiPlayer.dontToggleArmletExpires then
					if gsiPlayer.dontToggleArmletExpires < GameTime() then
						gsiPlayer.dontToggleArmletExpires = false
					else return; end
				end
				local hUnit = gsiPlayer.hUnit
				local slot = hUnit:FindItemSlot(hItem:GetName())
				if slot < 0 or slot > ITEM_END_INVENTORY_INDEX then return; end

				local fht = TASK_OBJ(gsiPlayer, fight_harass_handle)

				local armletIsOn = hItem:GetToggleState()

				local override = SpecialBehavior_GetBooleanOr("armletSuggestOverride", nil, gsiPlayer, hItem)
				if override ~= nil and override ~= armletIsOn then
					return gsiPlayer, INSTANT_NO_TURNING_SCORE;
				end


				local inCombat, intent = FightClimate_InvolvedInAnyCombat(gsiPlayer)
				
				if nearbyEnemies[1] and inCombat then
					if intent == gsiPlayer then -- we are not fighting, but their intent is us.
						if armletIsOn and gsiPlayer.lastSeenHealth
									< max(150, min(280, 
										nearbyEnemies[1].hUnit:IsNull() and 60 + 5*nearbyEnemies[1].level
										or nearbyEnemies[1].hUnit:GetAttackDamage()*1.25)) then
							
							local projectiles = hUnit:GetIncomingTrackingProjectiles()
							local playerLoc = gsiPlayer.lastSeen.location
							for i=1,#projectiles do
								local proj = projectiles[i]
								if proj and Vector_PointDistance2D(proj.location, playerLoc) > 400 then
									
									gsiPlayer.hUnit:Action_UseAbility(hItem)
									return gsiPlayer, INSTANT_NO_TURNING_SCORE;
								end
							end
						end
					elseif not armletIsOn and fht
							and (hUnit:GetAttackTarget() == fht.hUnit
								or Vector_PointDistance2D(fht.lastSeen.location, gsiPlayer.lastSeen.location)
									+ (fht.currentMovementSpeed - gsiPlayer.currentMovementSpeed)*2
									< max(350, gsiPlayer.attackRange*1.5)) then
						
						return gsiPlayer, INSTANT_NO_TURNING_SCORE;
					end
				elseif armletIsOn and #nearbyEnemies == 0 and not hUnit:GetAttackTarget()
						and GameTime() - hUnit:GetLastAttackTime()
							> hUnit:GetSecondsPerAttack() + 0.5
						and gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth < 0.95 then
						
					return gsiPlayer, INSTANT_NO_TURNING_SCORE;
				elseif not armletIsOn then
						
					if hUnit:GetDifficulty() >= 3 then
						local projectiles = hUnit:GetIncomingTrackingProjectiles()
						local playerLoc = gsiPlayer.lastSeen.location
						for i=1,#projectiles do
							local proj = projectiles[i]
							if proj and Vector_PointDistance(proj.location, playerLoc) > 450
									or gsiPlayer.lastSeenHealth < 700 + 15 * gsiPlayer.level then
								
						
								return gsiPlayer, INSTANT_NO_TURNING_SCORE;
							end
						end
					end
					if hUnit:GetAttackTarget() and gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth > 0.75
							- Analytics_GetTheoreticalDangerAmount(gsiPlayer) * 0.125 then
						
						return gsiPlayer, INSTANT_NO_TURNING_SCORE;
					end
				end
				
			end,
			generic_no_target_func
	},
	["item_mjollnir"] = {
			function(gsiPlayer, hItem, nearbyEnemies, nearbyAllies)
				if (GameTime()+gsiPlayer.nOnTeam*0.1) % 0.5 > 0.1
						or not (hItem:GetCooldownTimeRemaining() == 0 and hItem:IsFullyCastable())
						or #nearbyEnemies == 0
						or gsiPlayer.lastSeenMana < hItem:GetManaCost() then
					return false, XETA_SCORE_DO_NOT_RUN
				end
				local harmIsIntended, intents, harmIntended
						= FightClimate_AnyIntentToHarm(gsiPlayer, nearbyEnemies)
				if harmIntended > #nearbyEnemies * 0.9
						and gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth > 0.75
						and HIGH_USE( gsiPlayer, hItem, gsiPlayer.highUseManaSimple,
								hItem:GetManaCost(), 1 - 0.04*(#nearbyEnemies)*harmIntended
						) then
					return gsiPlayer, INSTANT_NO_TURNING_SCORE
				end
				local crowdedLoc = CROWDED_RATING(gsiPlayer.lastSeen.location, SET_HERO_ENEMY) 
				local bestReflect
				local bestReflectScore = 0
				for i=1,#intents do
					if intents[i] and Analytics_GetFutureDamageInTimeline(intents[i].hUnit) > 0
							and Vector_UnitFacingLoc(intents[i], crowdedLoc) > 0 then
						local loc = intents[i].lastSeen.location
						local reflectScore = (0.67+0.33*intents[i].vibe.greedRating)
								* intents[i].lastSeenHealth / intents[i].maxHealth	
								/ max(600, ((crowdedLoc.x-loc.x)^2 + (crowdedLoc.y-loc.y)^2)^0.5)
						for q=i+1,#intents do
							if intents[q] == intents[i] then
								reflectScore = reflectScore*1.15 
							end
						end
						if reflectScore > 0.00167 and reflectScore > bestReflectScore then
							bestReflectScore = reflectScore
							bestReflect = intents[i]
						end
					end
				end
				if bestReflect
						and Vector_PointDistance2D(bestReflect.lastSeen.location, gsiPlayer.lastSeen.location)
							< hItem:GetCastRange() then
					return bestReflect, INSTANT_NO_TURNING_SCORE;
				end
				--TODO it's good fight_climate
			end,
			generic_on_entity_func
	},
	["item_refresher"] = {
			function(gsiPlayer, hItem, nearbyEnemies, nearbyAllies)
				if not (hItem:GetCooldownTimeRemaining() == 0 and hItem:IsFullyCastable()) then
					return false, XETA_SCORE_DO_NOT_RUN
				end
				local danger, known = Analytics_GetTheoreticalDangerAmount(gsiPlayer)
				local totalHpp = 0
				for i=1,#known do
					local thisEnemy = known[i]
					totalHpp = totalHpp + thisEnemy.lastSeenHealth / thisEnemy.maxHealth
				end
				local _, lowestHealthPercent = Unit_LowestHealthPercentUnit(nearbyAllies)
				if totalHpp / (#known)^0.6 < 0.75 - (1.5-max(0.45, lowestHealthPercent))
						* (#nearbyAllies-#known) then
					return; -- Return in clearly won fights with no clutch saves, or low stakes
				end
				if gsiPlayer.lastSeenMana-hItem:GetManaCost() < gsiPlayer.highUseManaSimple*0.85
						or CURRENT_TASK(gsiPlayer) ~= fight_harass_handle
						or gsiPlayer.lastSeenHealth
							< 350 + 0.3*max(0, 1.5+danger)*gsiPlayer.maxHealth then
					return;
				end
				local hUnit = gsiPlayer.hUnit
				for i=0,2 do
					local ability = hUnit:GetAbilityInSlot(i)
					if ability and ability:GetCooldown() > 8
							and ability:GetCooldownTimeRemaining() == 0 then
						return;
					end
				end
				return gsiPlayer, INSTANT_NO_TURNING_SCORE;
			end,
			generic_no_target_func
	},
	["item_manta"] = {
			function(gsiPlayer, hItem, nearbyEnemies, nearbyAllies)
				if not (hItem:GetCooldownTimeRemaining() == 0 and hItem:IsFullyCastable()) then
					return false, XETA_SCORE_DO_NOT_RUN
				end
				if SpecialBehavior_GetBooleanOr("useItemMantaStyleOverride", nil,
							gsiPlayer, hItem, nearbyEnemies, nearbyAllies
						) then
					return;
				end

				local hasImmune = gsiPlayer.hUnit:IsMagicImmune()
				if gsiPlayer.hUnit:IsSilenced() or gsiPlayer.hUnit:IsRooted()
						or AbilityLogic_AnyProjectilesDodgeable(gsiPlayer, hasImmune) then
					return gsiPlayer, INSTANT_NO_TURNING_SCORE;
				end
			end,
			generic_no_target_func
	},
	["item_satanic"] = {
			function(gsiPlayer, hItem, nearbyEnemies, nearbyAllies)
				-- TODO TEMP
				if not (hItem:GetCooldownTimeRemaining() == 0 and hItem:IsFullyCastable()) then
					return false, XETA_SCORE_DO_NOT_RUN
				end
				if gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth < 0.45
						and CURR_ACTIVITY_TYPE(gsiPlayer)
								<= ACTIVITY_TYPE.CONTROLLED_AGGRESSION then
					local target = gsiPlayer.hUnit:GetAttackTarget()
					if target and target:IsHero() then
						return hItem, INSTANT_NO_TURNING_SCORE
					end
				end
			end,
			generic_no_target_func
	},
	["item_power_treads"] = {
			function(gsiPlayer, hItem, nearbyEnemies, nearbyAllies)
				local treadsLock = t_player_power_treads_stat_lock[gsiPlayer.nOnTeam]
				local currTreadsValue = hItem:GetPowerTreadsStat()
				local currTreadStat = ITEM_POWER_TREADS_STATE_STAT[currTreadsValue]
				local powerTreadsDesiredStat = get_power_treads_desired_stat(gsiPlayer)
				if currTreadStat ~= powerTreadsDesiredStat then
					return gsiPlayer, INSTANT_NO_TURNING_SCORE
				end
				return;
			end,
			function(gsiPlayer, target, hItem)
				local treadsLock = t_player_power_treads_stat_lock[gsiPlayer.nOnTeam]
				local currTreadsValue = hItem:GetPowerTreadsStat()
				local currTreadsStat = ITEM_POWER_TREADS_STATE_STAT[currTreadsValue]
				
				local targetTreads = get_power_treads_desired_stat(gsiPlayer)
				if currTreadsStat ~= targetTreads then
					gsiPlayer.hUnit:Action_UseAbility(hItem)
					if ITEM_POWER_TREADS_STATE_STAT[(currTreadsValue+1) % 2]
							~= targetTreads then
						return treadsLock and treadsLock[3] or INSTANT_NO_TURNING_SCORE;
					end
				end
				return XETA_SCORE_DO_NOT_RUN;
			end
	}
}

T_ITEM_FUNCS["item_hurricane_pike"][3]
	= function(gsiPlayer, hItem, nearbyEnemies, nearbyAllies)
		local currTask = CURR_ACTIVITY_TYPE(gsiPlayer)
		for k,v in pairs(hItem) do
			print(k, v)
		end
		print(hItem:GetCastRange())
		if currTask > ACTIVITY_TYPE.CAREFUL then
			if select(2, FightClimate_ImmediatelyExposedToAttack(gsiPlayer,
					nearbyEnemies, 1.0, 450
				)) < select(2, FightClimate_ImmediatelyExposedToAttack(gsiPlayer,
					nearbyEnemies, 1.0, 450, ZEROED_VECTOR
				)) then
			end
		end
	end

-- functional copies TODO temp
T_ITEM_FUNCS["item_force_staff"] = T_ITEM_FUNCS["item_hurricane_pike"]
T_ITEM_FUNCS["item_spirit_vessel"] = T_ITEM_FUNCS["item_urn_of_shadows"]
T_ITEM_FUNCS["item_silver_edge"] = T_ITEM_FUNCS["item_invis_sword"]
T_ITEM_FUNCS["item_dagon_2"] = T_ITEM_FUNCS["item_dagon"]
T_ITEM_FUNCS["item_dagon_3"] = T_ITEM_FUNCS["item_dagon"]
T_ITEM_FUNCS["item_dagon_4"] = T_ITEM_FUNCS["item_dagon"]
T_ITEM_FUNCS["item_dagon_5"] = T_ITEM_FUNCS["item_dagon"]
T_ITEM_FUNCS["item_ward_observer"] = T_ITEM_FUNCS["item_ward_dispenser"]
T_ITEM_FUNCS["item_ward_sentry"] = T_ITEM_FUNCS["item_ward_dispenser"]
T_ITEM_FUNCS["item_overwhelming_blink"] = T_ITEM_FUNCS["item_blink"]
T_ITEM_FUNCS["item_swift_blink"] = T_ITEM_FUNCS["item_blink"]
T_ITEM_FUNCS["item_arcane_blink"] = T_ITEM_FUNCS["item_blink"]
T_ITEM_FUNCS["item_bfury"] = T_ITEM_FUNCS["item_quelling_blade"]
local ITEM_FUNCS_I__SCORE_FUNC = ITEM_FUNCS_I__SCORE_FUNC
local ITEM_FUNCS_I__RUN_FUNC = ITEM_FUNCS_I__RUN_FUNC
local T_ITEM_FUNCS = T_ITEM_FUNCS

local t_ignore_on_swap_cd = {
	["item_ward_observer"] = true,
	["item_ward_sentry"] = true,
	["item_ward_dispenser"] = true
}
local t_ignore_keep_casting = {
	["item_ward_observer"] = true,
	["item_ward_sentry"] = true,
	["item_ward_dispenser"] = true
}

local t_wait_for_run_exit = {}

local next_player = 1

local external_task_control_lock_expire = 0
local exteral_task_handle = false

local function task_init_func(taskJobDomain)
	Blueprint_RegisterTaskName(task_handle, "use_item")
	if VERBOSE then VEBUG_print(string.format("[use_item]: Initialized with handle #%d.", task_handle)) end

	fight_harass_handle = FightHarass_GetTaskHandle()
	push_handle = Push_GetTaskHandle()
	search_fog_handle = SearchFog_GetTaskHandle()

	UrnLogic_Initialize()

	Task_RegisterTask(task_handle, PLAYERS_ALL, blueprint.run, blueprint.score, blueprint.init)

	WARD_LOCS = VAN_GetWardLocations()
	ENEMY_FOUNTAIN = Map_GetFountainLocationTeam(ENEMY_TEAM)

	taskJobDomain:RegisterJob(
			function(workingSet)
				if workingSet.throttle:allowed() then
					Task_SetTaskPriority(task_handle, next_player, TASK_PRIORITY_TOP)
					next_player = Task_RotatePlayerOnTeam(next_player)
				end
			end,
			{["throttle"] = Time_CreateThrottle(USE_ITEM_RESCORE_THROTTLE)},
			"JOB_TASK_SCORING_PRIORITY_USE_ITEM"
		)
	Blueprint_RegisterTaskActivityType(task_handle, ACTIVITY_TYPE["NOT_APPLICABLE"])
	task_init_func = nil
	return task_handle, estimated_time_til_completed
end
Blueprint_RegisterTask(task_init_func)

blueprint = {
	run = function(gsiPlayer, objective, xetaScore)
		-- TODO Everything
		local itemToUse = t_player_current_use[gsiPlayer.nOnTeam]
		local currentlyCasting = gsiPlayer.hUnit:GetCurrentActiveAbility()
		if DEBUG and currentlyCasting then
			INFO_print(string.format("[use_item] %s cast time of %s, %s (%s): %.2f, %.2f",
							gsiPlayer.shortName, currentlyCasting:GetName(), currentlyCasting, itemToUse,
							currentlyCasting:GetChannelTime(), currentlyCasting:GetDuration()
						)
				)
		end
		if itemToUse:IsNull() then
			return XETA_SCORE_DO_NOT_RUN
		end
		
		local itemName = itemToUse and not itemToUse:IsNull() and itemToUse:GetName()
		if not t_ignore_keep_casting[itemName]
				and ( (itemToUse and currentlyCasting == itemToUse)
					or UseItem_IsChanneling(gsiPlayer, itemName)
					or itemToUse:IsNull()
				) then
			
			return xetaScore
		end


		local itemSlot = gsiPlayer.hUnit:FindItemSlot(itemToUse:GetName())
		if not t_ignore_on_swap_cd[itemToUse:GetName()]
				and Item_OnItemSwapCooldown(gsiPlayer, nil, itemSlot) then
			
			return XETA_SCORE_DO_NOT_RUN
		end
		itemToUse = gsiPlayer.hUnit:GetItemInSlot(itemSlot)
		if itemToUse and not itemToUse:IsNull() and itemToUse:IsFullyCastable()
				and itemToUse:GetCooldownTimeRemaining() == 0
				and not gsiPlayer.hUnit:IsStunned()
				and not gsiPlayer.hUnit:IsMuted() then
			-- RUN
			local runResult = T_ITEM_FUNCS[itemToUse:GetName()][ITEM_FUNCS_I__RUN_FUNC](
						gsiPlayer, objective, itemToUse
					)
			if runResult then
				return xetaScore
			elseif runResult == false then
				return XETA_SCORE_DO_NOT_RUN
			end
			if gsiPlayer.hUnit:GetCurrentActiveAbility() then
				return xetaScore
			end
		end
		
		return XETA_SCORE_DO_NOT_RUN
	end,
	
	score = function(gsiPlayer, prevObjective, prevScore)
		if gsiPlayer.hUnit:IsMuted() then
			return false, XETA_SCORE_DO_NOT_RUN
		end
		local currentlyCasting = gsiPlayer.hUnit:GetCurrentActiveAbility()
		local allowInvisBreaks = not gsiPlayer.hUnit:IsInvisible()
		if not allowInvisBreaks then
			-- TODO temp
			return false, XETA_SCORE_DO_NOT_RUN
		end
		local currentItem = t_player_current_use[gsiPlayer.nOnTeam]
		if currentlyCasting and Task_GetCurrentTaskHandle(gsiPlayer) == task_handle
				or currentItem and not currentItem:IsNull()
				and UseItem_IsChanneling(gsiPlayer, currentItem:GetName()) then
			return prevObjective, prevScore
		end
		-- TODO EVERYTHING
		-- Iterate over purchasedUsables, store a [item_name] = {score_func, run_func}.
		-- - write a lot of generics for situations that arise, like targets running away
		-- - for too long, and abndon task.
		if GameTime() < external_task_control_lock_expire then
			-- e.g. search_fog.lua has set blink as the current use, it will call us to run
			-- - the using of blink into fog to catch a foe, we will assume safety and obey.
			-- - ... ward module said use shivas guard flying vision ...
			-- - ... after a complicated analysis, fight module indicated silver edge for break.
			return false, XETA_SCORE_DO_NOT_RUN
		elseif external_task_handle then
			external_task_handle = false
			t_player_current_use[gsiPlayer.nOnTeam] = false
		end
		local hUnit = gsiPlayer.hUnit
		local highestScore = -0xFF
		local highestItem
		local highestTarget
		-- TODO cache / each player
		local nearbyEnemies = nearbyEnemies or Set_GetEnemyHeroesInPlayerRadius(gsiPlayer, 1600, 1)
		local nearbyAllies = nearbyAllies or Set_GetAlliedHeroesInPlayerRadius(gsiPlayer, 1600, true)
		
		local usableItemsForIndexing = USABLE_ITEMS_FOR_INDEXING

		local itemCache = gsiPlayer.usableItemCache
		local purchasedUsables = gsiPlayer.purchasedUsables
		local ignoreSwap = t_ignore_on_swap_cd
		for i=1,#purchasedUsables do
			--print('del', purchasedUsables[i])
			local itemName = purchasedUsables[i]
			local thisItem = itemCache[usableItemsForIndexing[itemName]]
			if VERBOSE then
				VEBUG_print(
						string.format("[use_item] %s checking purchasedUsable %s, present in inventory: %s",
							gsiPlayer.shortName,
							itemName, thisItem and not thisItem:IsNull() and "yes" or "no"
						)
					)
			end
			-- TODO NB. no inventory switching if not in main inventory
			local itemSlot = hUnit:FindItemSlot(itemName)
			if thisItem and itemSlot >= 0 and itemSlot <= ITEM_END_BACKPACK_INDEX
					and (ignoreSwap[itemName]
						or not Item_OnItemSwapCooldown(gsiPlayer, nil, itemSlot)
					) then
				thisItem = hUnit:GetItemInSlot(itemSlot)
				local thisScoreFunc = T_ITEM_FUNCS[itemName]
				thisScoreFunc = thisScoreFunc and thisScoreFunc[ITEM_FUNCS_I__SCORE_FUNC]
				--print(thisScoreFunc)
				if thisItem and thisScoreFunc then
					local thisTarget, thisScore
							= thisScoreFunc(gsiPlayer, thisItem, nearbyEnemies, nearbyAllies)
					--print(thisTarget and thisTarget.shortName or thisTarget, thisScore)
					if thisTarget and thisScore > highestScore then
						highestTarget = thisTarget
						highestItem = thisItem
						highestScore = thisScore
					end
				end
			end
		end
		if VERBOSE and TEST then
			INFO_print( string.format("[use_item]: %s highest target %s using %s, score %d", gsiPlayer.shortName,
					Util_Printable(highestTarget), highestItem and highestItem:GetName(),
					highestItem and highestScore or -0)
				)
		end
		if highestTarget then
			t_player_current_use[gsiPlayer.nOnTeam] = highestItem
			return highestTarget, highestScore
		end
		if highestItem then
			t_player_current_use[gsiPlayer.nOnTeam] = highestItem
			return highestTarget, highestScore
		end
		return false, XETA_SCORE_DO_NOT_RUN
	end,
	
	init = function(gsiPlayer, objective, extrapolatedXeta)
		if TEST then
			DEBUG_print(string.format("[use_item] %s inits use_item with '%s' - score: %.2f", gsiPlayer.shortName, t_player_current_use[gsiPlayer.nOnTeam], extrapolatedXeta))
		end
		Task_IndicateSuccessfulInitShortTask(gsiPlayer, task_handle)
		return extrapolatedXeta
	end
}

function UseItem_GetTaskHandle()
	return task_handle
end
