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

-- Check HP / Mana and state of the game to see if it's worth buying and using consumables.

-- TODO Truely fix unpathable trees (such as radiant offlane left of stonework T1)
-- TODO Assess hero need instead of scoring consumables, then use Item_GetFastHealth / Item_GetEfficientHealth or Mana. Score one best, usable item.
--- Could also use Item_GetFastUnbreakableHealth() if the player is under attack and would like to avoid a flask effect

---- consumable constants --
local INSTANT_CONSIDERATION = 250

local HERO_BASE_KILL_GOLD = 135

local FLASK_HEALTH_REGEN = 40
local FLASK_EAT_TIME = 10
local FLASK_BASIC_HEALTH_GAIN = FLASK_EAT_TIME * FLASK_HEALTH_REGEN

local TANGO_HEALTH_REGEN = 7
local TANGO_EAT_TIME = 16
local TANGO_BASIC_HEALTH_GAIN = TANGO_EAT_TIME * TANGO_HEALTH_REGEN
local BASIC_TIME_TO_CAST_TANGO = 800 / 325

local STICK_POOL_GAIN_PER_CHARGE = 15
local USE_STICK_NOW_PERCENT = 0.35
local USE_STICK_HIGH_EFFICIENCY_UPKEEP = 0.95

local FAERIE_FIRE_HEALTH_GAIN = 85
local FAERIE_FIRE_USE_HEALTH_PERCENT = (2*75/1.3)/700 -- Try to survive something like the last one or two attacks from a 75 dmg right click, with armour 30% and 700hp

local BASIC_REGEN_BUFFER_TIME = 25

local MAX_TREE_FIND_RADIUS = 1600

local CLARITY_MANA_REGEN = 6
local CLARITY_EAT_TIME = 30
local CLARITY_BASIC_MANA_GAIN = CLARITY_EAT_TIME * CLARITY_MANA_REGEN
local CLARITY_USE_ON_MANA_MISSING = 3.5*CLARITY_BASIC_MANA_GAIN -- will cap a hero over 30s if they had 15 mana regen
local CLARITY_USE_ON_MANA_PERCENT = 0.3

local ARCANE_BASIC_MANA_GAIN = 160
local ARCANE_USE_ON_MANA_MISSING = 260
local ARCANE_USE_ON_MANA_PERCENT = 0.6

local MEKANSM_BASIC_HEALTH_GAIN = 275
local MEKANSM_USE_ON_HEALTH_PERCENT = 0.6
local MEKANSM_USE_ON_HEALTH_MISSING = 600

BOTTLE_BASIC_HEALTH_GAIN = 125
BOTTLE_BASIC_MANA_GAIN = 75
local BOTTLE_BASIC_HEALTH_GAIN = BOTTLE_BASIC_HEALTH_GAIN
local BOTTLE_BASIC_MANA_GAIN = BOTTLE_BASIC_MANA_GAIN
local BOTTLE_USE_ON_HEALTH_PERCENT = 0.85 -- After 25s basic regen
local BOTTLE_USE_ON_MANA_PERCENT = 0.3

local CONSUMABLE_RESCORE_THROTTLE = 0.167 -- nOnTeam Rotate

local ITEM_NEEDED_SWITCH_SLOT_WAIT_TIME = ITEM_SWITCH_ITEM_READY_TIME + 2

local BAG_CLEAR_NEEDED_ADDITIONAL_SCORE = 250 -- ~~ Cost of renting an item of middling value at 10 minutes for 10 seconds (because we may otherwise miss the courier or place an item in backpack
local TEMP_BAD_TREE_FIX_X_LIMIT = -6550

local HERO_TARGET_DIAMETER = HERO_TARGET_DIAMETER
--

---- consumable table index --
local SAVED_CONSUME_I__FUNC =	1
local SAVED_CONSUME_I__ITEM =	2
local SAVED_CONSUME_I__TARGET =	3
--

local Task_SetTaskPriority = Task_SetTaskPriority
local Task_RotatePlayerOnTeam = Task_RotatePlayerOnTeam
local Item_LockInventorySwitching = Item_LockInventorySwitching
local Item_EnsureCarriedItemInInventory = Item_EnsureCarriedItemInInventory
local Xeta_EvaluateObjectiveCompletion = Xeta_EvaluateObjectiveCompletion
local VALUE_OF_ONE_HEALTH = VALUE_OF_ONE_HEALTH
local VALUE_OF_ONE_MANA = VALUE_OF_ONE_MANA
local XETA_SCORE_DO_NOT_RUN = XETA_SCORE_DO_NOT_RUN
local ITEM_NEEDED_SWITCH_SLOT_WAIT_TIME = ITEM_NEEDED_SWITCH_SLOT_WAIT_TIME
local VERY_UNTHREATENING_UNIT = VERY_UNTHREATENING_UNIT
local TASK_PRIORITY_TOP = TASK_PRIORITY_TOP
local Task_GetCurrentTaskHandle = Task_GetCurrentTaskHandle
local max = math.max
local min = math.min
local abs = math.abs

local increase_safety_task_handle

local p_increased_bag_clearing_zealotry = {}

local p_saved_instruction = {}

local p_time_task_allowed = {} -- Report low scores until the item we saw was worth switching inventory is ready.

local task_handle = Task_CreateNewTask()

local fight_harass_handle

local WARD_LOCS -- nb. may be empty
local ENEMY_FOUNTAIN
local TEAM_FOUNTAIN_SUM

local DEBUG = DEBUG
local TEST = TEST
local VERBOSE = VERBOSE

local blueprint

local function estimated_time_til_completed(gsiPlayer, objective)
	return 0 -- don't care
end
local next_player = 1

local function inform_dead(gsiPlayer)
	p_saved_instruction[gsiPlayer.nOnTeam][SAVED_CONSUME_I__ITEM] = nil
end

local function task_init_func(taskJobDomain)
	Blueprint_RegisterTaskName(task_handle, "consumable")
	if VERBOSE then VEBUG_print(string.format("consumable: Initialized with handle #%d.", task_handle)) end

	Task_RegisterTask(task_handle, PLAYERS_ALL, blueprint.run, blueprint.score, blueprint.init)

	Blueprint_RegisterInformDeadFunc(inform_dead)
	
	increase_safety_task_handle = IncreaseSafety_GetTaskHandle()
	fight_harass_handle = FightHarass_GetTaskHandle()

	local teamPlayers = GSI_GetTeamPlayers(TEAM)
	for i=1,#teamPlayers,1 do
		p_saved_instruction[i] = {}
		p_time_task_allowed[i] = 0
		p_increased_bag_clearing_zealotry[i] = Item_NumberItemsCarried(teamPlayers[i]) > 8
	end

	TEAM_FOUNTAIN_SUM = Map_GetTeamFountainLocation()
	TEAM_FOUNTAIN_SUM = TEAM_FOUNTAIN_SUM.x + TEAM_FOUNTAIN_SUM.y

	taskJobDomain:RegisterJob(
			function(workingSet)
				if workingSet.throttle:allowed() then
					Task_SetTaskPriority(task_handle, next_player, TASK_PRIORITY_TOP)
					next_player = Task_RotatePlayerOnTeam(next_player)
				end
			end,
			{["throttle"] = Time_CreateThrottle(CONSUMABLE_RESCORE_THROTTLE)},
			"JOB_TASK_SCORING_PRIORITY_CONSUMABLE"
		)
	Blueprint_RegisterTaskActivityType(task_handle, ACTIVITY_TYPE["NOT_APPLICABLE"])

	task_init_func = nil
	return task_handle, estimated_time_til_completed
end
Blueprint_RegisterTask(task_init_func)

local function lock_bags_may_warn(gsiPlayer, tBagLocked, tAllowedRescore)
	if p_time_task_allowed[gsiPlayer.nOnTeam] > GameTime() then -- TODO IMPORTANT there is a global gsiPlayer "somewhere".
		if DEBUG then print("/VUL-FT/ <WARN> consumable: re-locking a locked bag.") end
	end
	p_time_task_allowed[gsiPlayer.nOnTeam] = GameTime() + tAllowedRescore
	Item_LockInventorySwitching(gsiPlayer, tBagLocked)
end

function Consumable_IndicateClearBagsSoon(gsiPlayer) -- A soft-instruction to more loosly use consumables (items are probably on courier now)
	if DEBUG then print(gsiPlayer.shortName, "clear bags please") end
	p_increased_bag_clearing_zealotry[gsiPlayer.nOnTeam] = true
end

function Consumable_IsBotEagerToMakeSpace(gsiPlayer)
	return p_increased_bag_clearing_zealotry[gsiPlayer.nOnTeam]
end

function Consumable_CheckConsumableUse(gsiPlayer, ability)
	if DEBUG then print(gsiPlayer.shortName, "saw ability in CheckConsumableUse", ability:GetName()) end
	if ability:GetName() == "item_flask" then
		Task_IncentiviseTask(gsiPlayer, LeechExperience_GetTaskHandle(), 70, 8)
	elseif ability:GetName() == "item_clarity" then
		Task_IncentiviseTask(gsiPlayer, LeechExperience_GetTaskHandle(), 50, 3)
	end
end

function Consumable_TryUseFlask(gsiPlayer, hItem, hUnit)
	local hUnit = gsiPlayer.hUnit
	if hItem:GetName() == "item_flask" and hUnit:HasModifier("modifier_flask_heal") or hUnit:HasModifier("modifier_bottle_regeneration") then
		if DEBUG and DEBUG_IsBotTheIntern() then print(gsiPlayer.shortName, "cancelling tango task because eating started") end
		return XETA_SCORE_DO_NOT_RUN
	end
	local ensureCarriedResult = Item_EnsureCarriedItemInInventory(gsiPlayer, hItem)
	--[[TEST]]if TEST then print("will attacks block flask for", gsiPlayer.shortName, ":", Analytics_RoshanOrHeroAttacksInTimeline(gsiPlayer) and not hUnit:TimeSinceDamagedByAnyHero()) end
	if ensureCarriedResult and not hUnit:WasRecentlyDamagedByAnyHero(2.0)
			and not Analytics_RoshanOrHeroAttacksInTimeline(gsiPlayer, -2.5) then
		hUnit:Action_UseAbilityOnEntity(hItem, hUnit)
	elseif ensureCarriedResult == ITEM_ENSURE_RESULT_WAIT then
		lock_bags_may_warn(gsiPlayer, ITEM_NEEDED_SWITCH_SLOT_WAIT_TIME, ITEM_SWITCH_ITEM_READY_TIME)
	else
		p_time_task_allowed[gsiPlayer.nOnTeam] = GameTime() + 0.5
	end
	return XETA_SCORE_DO_NOT_RUN
end

function Consumable_TryUseTango(gsiPlayer, hItem, hEntity)
	if gsiPlayer.hUnit:HasModifier("modifier_tango_heal") then
		if DEBUG and DEBUG_IsBotTheIntern() then print(gsiPlayer.shortName, "cancelling tango task because eating started") end
		return XETA_SCORE_DO_NOT_RUN
	end
	local ensureCarriedResult = Item_EnsureCarriedItemInInventory(gsiPlayer, hItem)
	if ensureCarriedResult then
		if type(hEntity) == "number" then
			--if DEBUG and DEBUG_IsBotTheIntern() then print(gsiPlayer.shortName, "using tango on tree") end
			gsiPlayer.hUnit:Action_UseAbilityOnTree(hItem, hEntity) -- .'. player is currently headed to a tree, or casting item_tango (keep the task running)
		else
			gsiPlayer.hUnit:Action_UseAbilityOnEntity(hItem, hEntity)
		end
	elseif ensureCarriedResult == ITEM_ENSURE_RESULT_WAIT then
		lock_bags_may_warn(gsiPlayer, ITEM_NEEDED_SWITCH_SLOT_WAIT_TIME, ITEM_SWITCH_ITEM_READY_TIME)
		--print(gsiPlayer.shortName, "lock bags -- tango")
		return XETA_SCORE_DO_NOT_RUN
	else
		return XETA_SCORE_DO_NOT_RUN
	end
end

function Consumable_TryUseStick(gsiPlayer, hItem)
	local ensureCarriedResult = Item_EnsureCarriedItemInInventory(gsiPlayer, hItem) 
	if ensureCarriedResult then
		gsiPlayer.hUnit:Action_UseAbility(hItem)
	elseif ensureCarriedResult == ITEM_ENSURE_RESULT_WAIT then
		lock_bags_may_warn(gsiPlayer, ITEM_NEEDED_SWITCH_SLOT_WAIT_TIME, ITEM_SWITCH_ITEM_READY_TIME)
	end
	return XETA_SCORE_DO_NOT_RUN
end

function Consumable_TryUseFaerieFire(gsiPlayer, hItem)
	local ensureCarriedResult = Item_EnsureCarriedItemInInventory(gsiPlayer, hItem)
	if ensureCarriedResult then
		gsiPlayer.hUnit:Action_UseAbility(hItem)
		p_increased_bag_clearing_zealotry[gsiPlayer.nOnTeam] = false
	elseif ensureCarriedResult == ITEM_ENSURE_RESULT_WAIT then
		lock_bags_may_warn(gsiPlayer, ITEM_NEEDED_SWITCH_SLOT_WAIT_TIME, ITEM_SWITCH_ITEM_READY_TIME)
	end
	return XETA_SCORE_DO_NOT_RUN
end

function Consumable_TryUseClarity(gsiPlayer, hItem, hUnit)
	if gsiPlayer.hUnit:HasModifier("modifier_clarity_potion") then
		if DEBUG and DEBUG_IsBotTheIntern() then print(gsiPlayer.shortName, "cancelling tango task because eating started") end
		return XETA_SCORE_DO_NOT_RUN
	end
	local ensureCarriedResult = Item_EnsureCarriedItemInInventory(gsiPlayer, hItem)
	--[[TEST]]if TEST then print("will attacks block clarity for", gsiPlayer.shortName, ":", Analytics_RoshanOrHeroAttacksInTimeline(gsiPlayer) and not gsiPlayer.hUnit:TimeSinceDamagedByAnyHero()) end
	if ensureCarriedResult and not Analytics_RoshanOrHeroAttacksInTimeline(gsiPlayer) and not gsiPlayer.hUnit:WasRecentlyDamagedByAnyHero(3.0) then
		gsiPlayer.hUnit:Action_UseAbilityOnEntity(hItem, hUnit)
	elseif ensureCarriedResult == ITEM_ENSURE_RESULT_WAIT then
		lock_bags_may_warn(gsiPlayer, ITEM_NEEDED_SWITCH_SLOT_WAIT_TIME, ITEM_SWITCH_ITEM_READY_TIME)
	else
		p_time_task_allowed[gsiPlayer.nOnTeam] = GameTime() + 0.5
	end
	return XETA_SCORE_DO_NOT_RUN
end

function Consumable_TryUseItem(gsiPlayer, hItem)
	local ensureCarriedResult = Item_EnsureCarriedItemInInventory(gsiPlayer, hItem) 
	if ensureCarriedResult then
		gsiPlayer.hUnit:Action_UseAbility(hItem)
	elseif ensureCarriedResult == ITEM_ENSURE_RESULT_WAIT then
		lock_bags_may_warn(gsiPlayer, ITEM_NEEDED_SWITCH_SLOT_WAIT_TIME, ITEM_SWITCH_ITEM_READY_TIME)
	end
	return XETA_SCORE_DO_NOT_RUN
end

function Consumable_TryUseItemOnEntity(gsiPlayer, hItem, hEntity)
	local ensureCarriedResult = Item_EnsureCarriedItemInInventory(gsiPlayer, hItem)
	if ensureCarriedResult then
		--print(gsiPlayer.shortName, "trying use", hItem:GetName())
		gsiPlayer.hUnit:Action_UseAbilityOnEntity(hItem, hEntity)
	elseif ensureCarriedResult == ITEM_ENSURE_RESULT_WAIT then
		lock_bags_may_warn(gsiPlayer, ITEM_NEEDED_SWITCH_SLOT_WAIT_TIME, ITEM_SWITCH_ITEM_READY_TIME)
	end
	return XETA_SCORE_DO_NOT_RUN
end

function Consumable_TryUseItemOnLocation(gsiPlayer, hItem, loc)
	local ensureCarriedResult = Item_EnsureCarriedItemInInventory(gsiPlayer, hItem)
	if ensureCarriedResult then
		--print(gsiPlayer.shortName, "trying use", hItem:GetName())
		gsiPlayer.hUnit:Action_UseAbilityOnLocation(hItem, loc)
	elseif ensureCarriedResult == ITEM_ENSURE_RESULT_WAIT then
		lock_bags_may_warn(gsiPlayer, ITEM_NEEDED_SWITCH_SLOT_WAIT_TIME, ITEM_SWITCH_ITEM_READY_TIME)
	end
	return XETA_SCORE_DO_NOT_RUN
end

local function check_flask(gsiPlayer, hItem, playerHealthAfterPassiveRegenBuffer, beatScore)
	if gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth < 0.45 or playerHealthAfterPassiveRegenBuffer + FLASK_BASIC_HEALTH_GAIN < gsiPlayer.maxHealth then
		local playerLoc = gsiPlayer.lastSeen.location
		if abs(playerLoc.x + playerLoc.y - TEAM_FOUNTAIN_SUM) > 3200
				and not gsiPlayer.hUnit:HasModifier("modifier_flask_healing")
				and not FightClimate_ImmediatelyExposedToAttack(gsiPlayer, nil, 3, 600) then
			local score = Xeta_EvaluateObjectiveCompletion(XETA_HEALTH_GAIN, 0, FLASK_BASIC_HEALTH_GAIN, gsiPlayer, gsiPlayer)
			--if DEBUG_IsBotTheIntern() then print("scored use flask", score) end 
			if score > beatScore then
				local instruction = p_saved_instruction[gsiPlayer.nOnTeam]
				instruction[SAVED_CONSUME_I__FUNC] = Consumable_TryUseFlask
				instruction[SAVED_CONSUME_I__ITEM] = hItem
				instruction[SAVED_CONSUME_I__TARGET] = gsiPlayer.hUnit
				return hItem, score, 0
			end
		end
	end
	return hItem, XETA_SCORE_DO_NOT_RUN
end

local function check_tango(gsiPlayer, hItem, playerHealthAfterPassiveRegenBuffer, beatScore, timeLimit)
	if hItem:GetCooldownTimeRemaining() == 0 and not gsiPlayer.hUnit:HasModifier("modifier_tango_heal") then
		local playerLoc = gsiPlayer.lastSeen.location
		if abs(playerLoc.x + playerLoc.y - TEAM_FOUNTAIN_SUM) > 2400
				and playerHealthAfterPassiveRegenBuffer + TANGO_BASIC_HEALTH_GAIN < gsiPlayer.maxHealth then
			local treesNearby = gsiPlayer.hUnit:GetNearbyTrees(MAX_TREE_FIND_RADIUS)
			local safeTreeLoc
			local danger = Analytics_GetTheoreticalDangerAmount(gsiPlayer)
			local allowedMovingDanger = 150 - 160*min(1.0, danger)
			local playerCoordsAddedAllowed = playerLoc.x+playerLoc.y
					+ (TEAM==TEAM_RADIANT and allowedMovingDanger or -allowedMovingDanger)
			if treesNearby then
				local safeTree = false
				local nearestEnemyTower = Set_GetNearestTeamTowerToPlayer(ENEMY_TEAM, gsiPlayer) or VERY_UNTHREATENING_UNIT
				if nearestEnemyTower then 
					local towerLocation = nearestEnemyTower.lastSeen.location
					local playerIsUnderEnemyTower = Math_PointToPointDistance2D(playerLoc, towerLocation) < nearestEnemyTower.attackRange-150
					local towerAttackTarget = nearestEnemyTower.hUnit and nearestEnemyTower.hUnit:CanBeSeen()
							and nearestEnemyTower.hUnit:GetAttackTarget()
					local towerConsideredSafe = towerAttackTarget and towerAttackTarget ~= gsiPlayer.hUnit and true or false
					local towerAttackDistance = nearestEnemyTower.attackRange+HERO_TARGET_DIAMETER
					if playerIsUnderEnemyTower then
						safeTree = treesNearby[1] -- Debatable
						if safeTree then
							safeTreeLoc = GetTreeLocation(safeTree)
						end
					else
						for i=1,math.min(10, #treesNearby),1 do
							local treeLocation = GetTreeLocation(treesNearby[i])
							if treeLocation.x > TEMP_BAD_TREE_FIX_X_LIMIT
								and (towerConsideredSafe or towerAttackDistance < Math_PointToPointDistance2D(GetTreeLocation(treesNearby[i]), towerLocation)
									) and ((TEAM == TEAM_RADIANT and treeLocation.x+treeLocation.y < playerCoordsAddedAllowed) 
									or (treeLocation.x+treeLocation.y > playerCoordsAddedAllowed) ) then
								safeTree = treesNearby[i]
								safeTreeLoc = treeLocation
								if DEBUG then DebugDrawLine(playerLoc, GetTreeLocation(treesNearby[i]), 20, 100, 20) end
								break
							end
							if DEBUG then DebugDrawLine(playerLoc, GetTreeLocation(treesNearby[i]), 100, 20, 20) end
						end
					end
				else
					for i=1,math.min(10, #treesNearby),1 do
						local treeLocation = GetTreeLocation(treesNearby[i])
						if treeLocation.x > TEMP_BAD_TREE_FIX_X_LIMIT
							and (towerConsideredSafe or towerAttackDistance < Math_PointToPointDistance2D(GetTreeLocation(treesNearby[i]), towerLocation)
								) and ((TEAM == TEAM_RADIANT and treeLocation.x+treeLocation.y < playerCoordsAddedAllowed) 
								or (treeLocation.x+treeLocation.y > playerCoordsAddedAllowed) ) then
							safeTree = treesNearby[i]
							safeTreeLoc = treeLocation
							if DEBUG then DebugDrawLine(playerLoc, GetTreeLocation(treesNearby[i]), 20, 100, 20) end
							break
						end
						if DEBUG then DebugDrawLine(playerLoc, GetTreeLocation(treesNearby[i]), 100, 20, 20) end
					end
				end
				if safeTree and ( timeLimit > 5
							or timeLimit > Vector_PointDistance2D(playerLoc, safeTreeLoc)
									/ gsiPlayer.currentMovementSpeed
						) and abs(safeTreeLoc.z - playerLoc.z) < 110 then
					local score = Xeta_EvaluateObjectiveCompletion(XETA_HEALTH_GAIN, BASIC_TIME_TO_CAST_TANGO, TANGO_BASIC_HEALTH_GAIN, gsiPlayer, gsiPlayer)
					if score > beatScore then
						local instruction = p_saved_instruction[gsiPlayer.nOnTeam]
						instruction[SAVED_CONSUME_I__FUNC] = Consumable_TryUseTango
						instruction[SAVED_CONSUME_I__ITEM] = hItem
						instruction[SAVED_CONSUME_I__TARGET] = safeTree
						return hItem, score, 0
					end
				end
			end
		end
	end
	return hItem, XETA_SCORE_DO_NOT_RUN
end

-- TODO TEST Make sure they don't stand still due to cooldown stuff, otherwise. Not sure.
local function check_stick(gsiPlayer, hItem, playerHealthAfterPassiveRegenBuffer, playerManaAfterPassiveRegenBuffer, beatScore, isMagicStick)
	local currCharges = hItem:GetCurrentCharges()
	local playerLoc = gsiPlayer.lastSeen.location
	if (abs(playerLoc.x + playerLoc.y - TEAM_FOUNTAIN_SUM) > 2400 or #gsiPlayer.hUnit:GetNearbyHeroes(1600, true, BOT_MODE_NONE))
			and hItem:GetCooldownTimeRemaining() == 0 and currCharges > 0 then
		local stickPoolGain = 15 * currCharges
		local efficacy = ( ( 
					gsiPlayer.maxHealth - playerHealthAfterPassiveRegenBuffer)/stickPoolGain 
					+ (gsiPlayer.maxMana - playerManaAfterPassiveRegenBuffer)/stickPoolGain
				) / 2
		if math.min(Unit_GetHealthPercent(gsiPlayer), 
				Unit_GetManaPercent(gsiPlayer)) < USE_STICK_NOW_PERCENT or
				efficacy > USE_STICK_HIGH_EFFICIENCY_UPKEEP then
			local score = Xeta_EvaluateObjectiveCompletion(XETA_HEALTH_GAIN, 0, stickPoolGain, gsiPlayer, gsiPlayer)
			--if DEBUG and DEBUG_IsBotTheIntern() then print("scored use magic", score) end 
			if score > beatScore then
				local instruction = p_saved_instruction[gsiPlayer.nOnTeam]
				instruction[SAVED_CONSUME_I__FUNC] = isMagicStick and Consumable_TryUseItem or Consumable_TryUseItemOnEntity
				instruction[SAVED_CONSUME_I__ITEM] = hItem
				instruction[SAVED_CONSUME_I__TARGET] = gsiPlayer.hUnit
				return hItem, score, (gsiPlayer.lastSeenHealth < 500 and STICK_INSTANT_CONSIDERATION or 0)
			end
		end
	end
	return hItem, XETA_SCORE_DO_NOT_RUN
end

local function check_faerie_fire(gsiPlayer, hItem, playerHealthAfterPassiveRegenBuffer, beatScore)
	--[DEBUG]]if DEBUG and DEBUG_IsBotTheIntern() then print("checking faeri. increase clearing:", p_increased_bag_clearing_zealotry[gsiPlayer.nOnTeam]) end
	local healthPercent = Unit_GetHealthPercent(gsiPlayer)
	if healthPercent < FAERIE_FIRE_USE_HEALTH_PERCENT or p_increased_bag_clearing_zealotry[gsiPlayer.nOnTeam] then
		local score = Xeta_EvaluateObjectiveCompletion(XETA_HEALTH_GAIN, 0, FAERIE_FIRE_HEALTH_GAIN, gsiPlayer, gsiPlayer) + (p_increased_bag_clearing_zealotry[gsiPlayer.nOnTeam] and BAG_CLEAR_NEEDED_ADDITIONAL_SCORE or 0)
		local nearbyEnemies = Set_GetEnemyHeroesInPlayerRadius(gsiPlayer, 800)
		for i=1,#nearbyEnemies do

		end
		--[DEBUG]]if DEBUG and DEBUG_IsBotTheIntern() then print("scored use faerie", score) end 
		if score > beatScore then
			local instruction = p_saved_instruction[gsiPlayer.nOnTeam]
			instruction[SAVED_CONSUME_I__FUNC] = Consumable_TryUseFaerieFire
			instruction[SAVED_CONSUME_I__ITEM] = hItem
			instruction[SAVED_CONSUME_I__TARGET] = gsiPlayer.hUnit
			local nearFutureHealth = Analytics_GetNearFutureHealth(gsiPlayer)
			return 
				hItem, 
				score,
				(nearFutureHealth < 0 and nearFutureHealth + FAERIE_FIRE_HEALTH_GAIN > 0 
						and INSTANT_CONSIDERATION+HERO_BASE_KILL_GOLD or 0)
		end
	end
	return hItem, XETA_SCORE_DO_NOT_RUN
end

local function check_clarity(gsiPlayer, hItem, playerManaAfterPassiveRegenBuffer, beatScore)
	local playerLoc = gsiPlayer.lastSeen.location
	if (abs(playerLoc.x + playerLoc.y - TEAM_FOUNTAIN_SUM) > 2400 or #gsiPlayer.hUnit:GetNearbyHeroes(1600, true, BOT_MODE_NONE))
			and not gsiPlayer.hUnit:HasModifier("modifier_clarity_potion") then
		local manaPercent = Unit_GetManaPercent(gsiPlayer)
		local currentTask = Task_GetCurrentTaskHandle(gsiPlayer)
		if manaPercent < CLARITY_USE_ON_MANA_PERCENT or gsiPlayer.maxMana-gsiPlayer.lastSeenMana > CLARITY_USE_ON_MANA_MISSING then
			local score = CLARITY_BASIC_MANA_GAIN*VALUE_OF_ONE_MANA
			if score > beatScore then
				local instruction = p_saved_instruction[gsiPlayer.nOnTeam]
				instruction[SAVED_CONSUME_I__FUNC] = Consumable_TryUseClarity
				instruction[SAVED_CONSUME_I__ITEM] = hItem
				instruction[SAVED_CONSUME_I__TARGET] = gsiPlayer.hUnit
				return hItem, score, 0
			end
		end
	end
	return hItem, XETA_SCORE_DO_NOT_RUN
end

local function check_bottle(gsiPlayer, hItem, playerHealthAfterPassiveRegenBuffer, playerManaAfterPassiveRegen, beatScore)
	if hItem:GetCurrentCharges() > 0 and hItem:GetCooldownTimeRemaining() == 0
			and (playerHealthAfterPassiveRegenBuffer/gsiPlayer.maxHealth < BOTTLE_USE_ON_HEALTH_PERCENT
			or playerManaAfterPassiveRegen/gsiPlayer.maxMana < BOTTLE_USE_ON_MANA_PERCENT) then
		local activityType = Blueprint_GetCurrentTaskActivityType(gsiPlayer)
		local currentTaskHandle = Task_GetCurrentTaskHandle(gsiPlayer)
		local score = ( VALUE_OF_ONE_HEALTH*min(
					BOTTLE_BASIC_HEALTH_GAIN,
					gsiPlayer.maxHealth-playerHealthAfterPassiveRegenBuffer)
				+ VALUE_OF_ONE_MANA*min(
					BOTTLE_BASIC_MANA_GAIN,
					gsiPlayer.maxMana-playerManaAfterPassiveRegen) )
				* ((activityType <= ACTIVITY_TYPE.KILL or activityType >= ACTIVITY_TYPE.CAREFUL) and 1.3 or 0.85)
		--if DEBUG and DEBUG_IsBotTheIntern() then print("intern scored bottle", score) end
		if score > beatScore then
			local instruction = p_saved_instruction[gsiPlayer.nOnTeam]
			instruction[SAVED_CONSUME_I__FUNC] = Consumable_TryUseFlask -- same fctnlty for bottle
			instruction[SAVED_CONSUME_I__ITEM] = hItem
			instruction[SAVED_CONSUME_I__TARGET] = gsiPlayer.hUnit
			return hItem, score, 0
		end
	end
	return hItem, XETA_SCORE_DO_NOT_RUN
end

local function check_arcane_boots(gsiPlayer, hItem, playerManaAfterPassiveRegenBuffer, beatScore)
	local manaPercent = Unit_GetManaPercent(gsiPlayer)
	if hItem:GetCooldownTimeRemaining() == 0 and (manaPercent < ARCANE_USE_ON_MANA_PERCENT or gsiPlayer.maxMana-playerManaAfterPassiveRegenBuffer > ARCANE_USE_ON_MANA_MISSING) then
		local score = ARCANE_BASIC_MANA_GAIN*VALUE_OF_ONE_MANA
		if score > beatScore then
			local instruction = p_saved_instruction[gsiPlayer.nOnTeam]
			instruction[SAVED_CONSUME_I__FUNC] = Consumable_TryUseItem
			instruction[SAVED_CONSUME_I__ITEM] = hItem
			instruction[SAVED_CONSUME_I__TARGET] = gsiPlayer.hUnit
			return hItem, score, (manaPercent < 0.55 and INSTANT_CONSIDERATION or 0)
		end
	end
	return hItem, XETA_SCORE_DO_NOT_RUN
end

local function check_mekansm(gsiPlayer, hItem, playerHealthAfterPassiveRegenBuffer, beatScore)
	-- TODO is self only
	local healthPercent = Unit_GetHealthPercent(gsiPlayer)
	if hItem:GetCooldownTimeRemaining() == 0 and (healthPercent < MEKANSM_USE_ON_HEALTH_PERCENT or gsiPlayer.maxHealth-playerHealthAfterPassiveRegenBuffer > MEKANSM_USE_ON_HEALTH_MISSING) then
		local score = MEKANSM_BASIC_HEALTH_GAIN*VALUE_OF_ONE_HEALTH
		if score > beatScore then
			local instruction = p_saved_instruction[gsiPlayer.nOnTeam]
			instruction[SAVED_CONSUME_I__FUNC] = Consumable_TryUseItem
			instruction[SAVED_CONSUME_I__ITEM] = hItem
			instruction[SAVED_CONSUME_I__TARGET] = gsiPlayer.hUnit
			return hItem, score, (healthPercent < 0.55 and INSTANT_CONSIDERATION or 0)
		end
	end
	return hItem, XETA_SCORE_DO_NOT_RUN
end

local function check_guardian_greaves(gsiPlayer, hItem, playerHealthAfterPassiveRegenBuffer, playerManaAfterPassiveRegenBuffer, beatScore)
	-- TODO is self only, just copies mek
	local healthPercent = Unit_GetHealthPercent(gsiPlayer)
	if hItem:GetCooldownTimeRemaining() == 0 and (healthPercent < MEKANSM_USE_ON_HEALTH_PERCENT or gsiPlayer.maxHealth-playerHealthAfterPassiveRegenBuffer > MEKANSM_USE_ON_HEALTH_MISSING) then
		local score = MEKANSM_BASIC_HEALTH_GAIN*VALUE_OF_ONE_HEALTH
		if score > beatScore then
			local instruction = p_saved_instruction[gsiPlayer.nOnTeam]
			instruction[SAVED_CONSUME_I__FUNC] = Consumable_TryUseItem
			instruction[SAVED_CONSUME_I__ITEM] = hItem
			instruction[SAVED_CONSUME_I__TARGET] = gsiPlayer.hUnit
			return hItem, score, (healthPercent < 0.55 and INSTANT_CONSIDERATION or 0)
		end
	end
	return hItem, XETA_SCORE_DO_NOT_RUN
end

local function check_mango(gsiPlayer, hItem, playerManaAfterPassiveRegenBuffer, beatScore)
	--/ TEMPORARY /--
	local manaPercent = Unit_GetManaPercent(gsiPlayer)
	local healthPercent = Unit_GetHealthPercent(gsiPlayer)
	-- (> CAREFUL && (GetBestEscape().GetManaCost < mana) || health > 25) || (<= KILL & mana < high use && health > 70)
	local currTask = Task_GetCurrentTaskHandle(gsiPlayer)
	local fht = Task_GetTaskObjective(gsiPlayer, fight_harass_handle)
	local freeSlots = Item_HaveFreeInventorySlot(gsiPlayer)
	-- TODO BAD -- only chasing
	if currTask == fight_harass_handle and fht and fht.hUnit.IsNull and not fht.hUnit:IsNull()
			and fht.lastSeenHealth < gsiPlayer.lastSeenHealth
			and gsiPlayer.lastSeenHealth > 250 + gsiPlayer.level*50
			and gsiPlayer.lastSeenMana < (freeSlots and gsiPlayer.highUseManaSimple
				or gsiPlayer.maxMana - 150
			) then
		local score = 1234
		local instruction = p_saved_instruction[gsiPlayer.nOnTeam]
		instruction[SAVED_CONSUME_I__FUNC] = Consumable_TryUseClarity
		instruction[SAVED_CONSUME_I__ITEM] = hItem
		instruction[SAVED_CONSUME_I__TARGET] = gsiPlayer.hUnit
		return hItem, score, 0
	end
	return hItem, XETA_SCORE_DO_NOT_RUN
end

blueprint = {
	run = function(gsiPlayer, objective, xetaScore)
		local instruction = p_saved_instruction[gsiPlayer.nOnTeam]
		local instructionItem = instruction[SAVED_CONSUME_I__ITEM]
		--print(instruction[SAVED_CONSUME_I__ITEM]:IsNull())
		--print(gsiPlayer.shortName, "item cooldown", instruction[SAVED_CONSUME_I__ITEM]:GetCooldownTimeRemaining() == 0, instruction[SAVED_CONSUME_I__ITEM]:GetCooldownTimeRemaining())
		if not instructionItem
				or (instructionItem and instructionItem:IsNull()
				or ( instructionItem:GetCooldownTimeRemaining() > 0
					or not instructionItem:IsFullyCastable()) )
				or p_time_task_allowed[gsiPlayer.nOnTeam] > GameTime() then
			return XETA_SCORE_DO_NOT_RUN -- Don't try to run us till we re-score high (because item is ready from backpack switch)
		end











































		--print(gsiPlayer.shortName, "consoom", instruction[SAVED_CONSUME_I__ITEM]:GetName(), instruction[SAVED_CONSUME_I__TARGET])
		return instruction[SAVED_CONSUME_I__FUNC](gsiPlayer, instruction[SAVED_CONSUME_I__ITEM], instruction[SAVED_CONSUME_I__TARGET]) or xetaScore
	end,
	
	score = function(gsiPlayer, prevObjective, prevScore) -- TODO PRIMATIVE; orders the consumables by urgency of use (generally). 
		if p_time_task_allowed[gsiPlayer.nOnTeam] > GameTime() then
			if prevObjective and prevObjective.GetName and not prevObjective:IsNull() and prevObjective:GetName() == "item_tango" then
				return prevObjective, prevScore -- Keep walking to the tree
			end
			return false, XETA_SCORE_DO_NOT_RUN
		elseif Task_GetCurrentTaskHandle(gsiPlayer) == increase_safety_task_handle
				and Task_GetCurrentTaskScore(gsiPlayer) > 100
				and not Set_GetEnemyHeroesInPlayerRadius(gsiPlayer, 1600, 5)[1] then
			-- local _, bottle = Item_ItemInMainInventory(gsiPlayer, "item_bottle")
			-- if bottle and bottle:GetCurrentCharges() > 0 and bottle:GetCooldownTimeRemaining() == 0 then 
				-- if not UseAbility_IsPlayerLocked(gsiPlayer) 
						-- and not gsiPlayer.hUnit:HasModifier("modifier_bottle_regeneration") then
					-- UseAbility_RegisterAbilityUseAndLockToScore(gsiPlayer, bottle, nil, 500)
				-- end
			-- end
			-- Don't use consumables if there are no threats and we're going back to base
			return false, XETA_SCORE_DO_NOT_RUN
		end

		local _, timeLimit = FarmLane_AnyCreepLastHitTracked(gsiPlayer)

		timeLimit = Analytics_GetTheoreticalDangerAmount(gsiPlayer) > 1.2 and 60 or timeLimit

		local allowInvisBreaks = not gsiPlayer.hUnit:IsInvisible()
		if not allowInvisBreaks then
			-- TODO temp
			return false, XETA_SCORE_DO_NOT_RUN
		end

		if gsiPlayer.hUnit:IsMuted() then
			return false, XETA_SCORE_DO_NOT_RUN
		end
		
		local healthReplenishAvailable, manaReplenishAvailable
		
		healthReplenishAvailable, manaReplenishAvailable = Item_GetReplenishers(gsiPlayer) 
		
		local checkTango = check_tango
		local checkFlask = check_flask
		local checkStick = check_stick
		local checkFaerieFire = check_faerie_fire
		local checkBottle = check_bottle
		local checkMek = check_mekansm
		local checkGreaves = check_guardian_greaves
		local checkArcaneBoots = check_arcane_boots
				
		local highestScore = XETA_SCORE_DO_NOT_RUN
		local highestScoreAdded = 0
		local highestScoringObjective = false
		
		local nearbyAllies
		
		local playerHealthAfterPassiveRegenBuffer =  gsiPlayer.lastSeenHealth + gsiPlayer.hUnit:GetHealthRegen() * BASIC_REGEN_BUFFER_TIME
		local playerManaAfterPassiveRegenBuffer = gsiPlayer.lastSeenMana + gsiPlayer.hUnit:GetManaRegen() * BASIC_REGEN_BUFFER_TIME
		if healthReplenishAvailable then
			for i=1,#healthReplenishAvailable,1 do
				local thisItem = healthReplenishAvailable[i]
				local thisItemName = thisItem:GetName()
				
				if checkFlask and string.find(thisItemName, "flask", ITEM_NAME_SEARCH_START) then
					local obj, score, add = checkFlask(gsiPlayer, thisItem, playerHealthAfterPassiveRegenBuffer, highestScore)
					checkFlask = false
					if score > highestScore then
						highestScoringObjective = obj
						highestScore = score
						highestScoreAdded = add
					end
				elseif checkTango and string.find(thisItemName, "tang", ITEM_NAME_SEARCH_START) then -- GetBehavior() == 8?
					local obj, score, add = checkTango(gsiPlayer, thisItem, playerHealthAfterPassiveRegenBuffer, highestScore, timeLimit)
					checkTango = false
					if score > highestScore then
						highestScoringObjective = obj
						highestScore = score
						highestScoreAdded = add
					end
				elseif checkFaerieFire and string.find(thisItemName, "faer", ITEM_NAME_SEARCH_START) then
					local obj, score, add = checkFaerieFire(gsiPlayer, thisItem, playerHealthAfterPassiveRegenBuffer, highestScore)
					checkFaerieFire = false
					if score > highestScore then
						highestScoringObjective = obj
						highestScore = score
						highestScoreAdded = add
					end
				elseif checkBottle and string.find(thisItemName, "bott", ITEM_NAME_SEARCH_START) then
					local obj, score, add = checkBottle(gsiPlayer, thisItem, playerHealthAfterPassiveRegenBuffer, playerManaAfterPassiveRegenBuffer, highestScore)
					checkBottle = false
					if score > highestScore then
						highestScoringObjective = obj
						highestScore = score
						highestScoreAdded = add
					end
				elseif checkMek and string.find(thisItemName, "meka", ITEM_NAME_SEARCH_START) then
					local obj, score, add = checkMek(gsiPlayer, thisItem, playerHealthAfterPassiveRegenBuffer, highestScore)
					checkMek = false
					if score > highestScore then
						highestScoringObjective = obj
						highestScore = score
						highestScoreAdded = add
					end
				elseif checkGreaves and string.find(thisItemName, "guardian_g", ITEM_NAME_SEARCH_START) then
					local obj, score, add = checkGreaves(gsiPlayer, thisItem, playerHealthAfterPassiveRegenBuffer, playerManaAfterPassiveRegenBuffer, highestScore)
					checkGreaves = false
					if score > highestScore then
						highestScoringObjective = obj
						highestScore = score
						highestScoreAdded = add
					end
		-- nb. stick using logical skip, don't move or elseif below it
				elseif checkStick then -- TODO OPTIMIZE Give all items a unique identifier number (if you can't find one in game data) so we don't have to re-check string.find
					local stickFound = string.find(thisItemName, "magic_", ITEM_NAME_SEARCH_START)
					local holyLocketFound = not stickFound and string.find(thisItem:GetName(), "holy_locket", ITEM_NAME_SEARCH_START)
					if stickFound or holyLocketFound then
						local obj, score, add = checkStick(gsiPlayer, thisItem, playerHealthAfterPassiveRegenBuffer, playerManaAfterPassiveRegenBuffer, highestScore, stickFound)
						checkStick = false
						if score > highestScore then
							highestScoringObjective = obj
							highestScore = score
							highestScoreAdded = add
						end
					end
				end
				--elseif checkGuardianGreaves and string.find(health
			end
		end
		local checkClarity = check_clarity
		local checkMango = check_mango
		if manaReplenishAvailable then
			for i=1,#manaReplenishAvailable,1 do
				local thisItem = manaReplenishAvailable[i]
				
				local thisItemName = thisItem:GetName()
				if checkMango and string.find(thisItemName, "ench", ITEM_NAME_SEARCH_START) then
					local obj, score, add = checkMango(gsiPlayer, thisItem, playerManaAfterPassiveRegenBuffer, highestScore)
					checkMango = false
					if score > highestScore then
						highestScoringObjective = obj
						highestScore = score
						highestScoreAdded = add
					end
				elseif checkArcaneBoots and string.find(thisItemName, "arcane_b", ITEM_NAME_SEARCH_START) then
					local obj, score, add = checkArcaneBoots(gsiPlayer, thisItem, playerManaAfterPassiveRegenBuffer, highestScore)
					checkArcaneBoots = false
					if score > highestScore then
						highestScoringObjective = obj
						highestScore = score
						highestScoreAdded = add
					end
				elseif checkClarity and string.find(thisItemName, "clarity", ITEM_NAME_SEARCH_START) then
					local obj, score, add = checkClarity(gsiPlayer, thisItem, playerManaAfterPassiveRegenBuffer, highestScore)
					checkClarity = false
					if score > highestScore then
						highestScoringObjective = obj
						highestScore = score
						highestScoreAdded = add
					end
				end
			end
		end
		
		if DotaTime() < 600 and highestScore < 30
				and Unit_GetHealthPercent(gsiPlayer) < 0.85
				and RandomInt(1, 35) == 35
				and not Item_ItemInBuild(gsiPlayer, "item_flask", true)
				and not Item_ItemInBuild(gsiPlayer, "item_tango", true)
				and Farm_JungleCampClearViability(gsiPlayer, JUNGLE_CAMP_HARD) < 1.5 then
			if Unit_GetHealthPercent(gsiPlayer) < 0.45
					and GetItemStockCount("item_flask")
						> 2.1 - gsiPlayer.vibe.greedRating * 2
					and not Item_ItemOwnedAnywhere(gsiPlayer, "item_flask") then
				Item_InsertItemToItemBuild(gsiPlayer, "item_flask")
			elseif not Item_ItemOwnedAnywhere(gsiPlayer, "item_tango")
					and GetItemStockCount("item_tango")
						> 2.1 - gsiPlayer.vibe.greedRating * 2 then
				Item_InsertItemToItemBuild(gsiPlayer, "item_tango")
			end
		end
		if DotaTime() < 1800 and highestScore < 30 and RandomInt(1, 35) == 35
				and gsiPlayer.lastSeenMana+gsiPlayer.hUnit:GetManaRegen()*20
					< min(gsiPlayer.maxMana * 0.45, gsiPlayer.highUseManaSimple*1.33)
				and ( gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth > 0.45
					or Item_ItemOwnedAnywhere(gsiPlayer, "item_flask")
					or Item_ItemOwnedAnywhere(gsiPlayer, "item_tango")
				) then
			if not Item_ItemInBuild(gsiPlayer, "item_clarity", true) 
					and not Item_ItemOwnedAnywhere(gsiPlayer, "item_clarity")
					and GetItemStockCount("item_clarity")
						> 2.1 - gsiPlayer.vibe.greedRating * 2 then
				Item_InsertItemToItemBuild(gsiPlayer, "item_clarity")
			end
		end
		--if DEBUG and DEBUG_IsBotTheIntern() then print("consumable returning", highestScoringObjective and highestScoringObjective:GetName(), highestScore) end
		return highestScoringObjective, highestScoringObjective and highestScore + highestScoreAdded or XETA_SCORE_DO_NOT_RUN
	end,
	
	init = function(gsiPlayer, objective, extrapolatedXeta)
		if gsiPlayer.usableItemCache.powerTreads
				and gsiPlayer.hUnit:FindItemSlot("item_power_treads") < ITEM_END_INVENTORY_INDEX then
			UseItem_PowerTreadsStatLock(gsiPlayer, ATTRIBUTE_AGILITY, 0.5, 1500)
		end
		local hItem = p_saved_instruction[gsiPlayer.nOnTeam][SAVED_CONSUME_I__ITEM]
		if not hItem or hItem:IsNull() then
			if hItem then print("DEBUG --- ITEM WAS NULL FOR", gsiPlayer.shortName) end
			if DEBUG then ALERT_print("[consumable]: task-score won but no consumable is stored for use.") end
			return false
		end
		local ensureItemCarriedResult = Item_EnsureCarriedItemInInventory(gsiPlayer, hItem)
		
		if ensureItemCarriedResult == ITEM_ENSURE_RESULT_WAIT --[[or Item_OnItemSwapCooldown(gsiPlayer, hItem)]] then
			if VERBOSE then print("/VUL-FT/ [consumable] locking", gsiPlayer.shortName, "for switched in item", hItem:GetName()) end
			lock_bags_may_warn(gsiPlayer, ITEM_NEEDED_SWITCH_SLOT_WAIT_TIME, ITEM_SWITCH_ITEM_READY_TIME)
			return false
		end
		if not hItem:GetCooldownTimeRemaining() == 0 or not hItem:IsFullyCastable() then
			return false
		end
		Task_IndicateSuccessfulInitShortTask(gsiPlayer, task_handle)
		return ensureItemCarriedResult == true and extrapolatedXeta or false
	end
}

function Consumable_GetTaskHandle()
	return task_handle
end
