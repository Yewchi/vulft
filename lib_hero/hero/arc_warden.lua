local hero_data = {
	"arc_warden",
	{3, 1, 1, 3, 1, 4, 1, 3, 3, 5, 2, 4, 2, 2, 7, 2, 4, 9, 11},
	{
		"item_branches","item_branches","item_branches","item_circlet","item_faerie_fire","item_circlet","item_gloves","item_hand_of_midas","item_javelin","item_mithril_hammer","item_boots","item_maelstrom","item_rod_of_atos","item_gungir","item_arcane_boots","item_aether_lens","item_octarine_core","item_point_booster","item_staff_of_wizardry","item_ultimate_scepter","item_blink","item_sheepstick","item_ultimate_scepter_2","item_overwhelming_blink","item_staff_of_wizardry","item_wind_lace","item_void_stone","item_cyclone","item_mystic_staff","item_wind_waker","item_aghanims_shard","item_moon_shard","item_ethereal_blade","item_solar_crest",
	},
	{ {2,2,2,2,1,}, {2,2,2,2,1,}, 0.1 },
	{
		"Flux","Magnetic Field","Spark Wraith","Tempest Double","+175 Flux Cast Range","+225 Health","+2s Flux Duration","+40 Magnetic Field Attack Speed","+125 Spark Wraith Damage","+40 Flux Damage","+50% Tempest Double Cooldown Reduction","+12s Tempest Double Duration",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"arc_warden_flux", ABILITY_TYPE.NUKE + ABILITY_TYPE.UNIT_TARGET + ABILITY_TYPE.SINGLE_TARGET + ABILITY_TYPE.DEGEN + ABILITY_TYPE.SLOW},
		{"arc_warden_magnetic_field", ABILITY_TYPE.AOE + ABILITY_TYPE.BUFF},
		{"arc_warden_spark_wraith", ABILITY_TYPE.NUKE + ABILITY_TYPE.SLOW},
		[5] = {"arc_warden_tempest_double", ABILITY_TYPE.SUMMON}
}

local HIGH_USE_FLUX_REMAINING_MANA = 110 + 80
local HIGH_USE_S_W_REMAINING_MANA = 110 + 75
local HIGH_USE_M_F_REMAINING_MANA = 160 + 75
local S_W_EXTRAPOLATE_TIME = 2

local USE_MAGNETIC_WHEN_CLOSER_RANGE = 400

local Blueprint_GetCurrentTaskActivityType = Blueprint_GetCurrentTaskActivityType
local farm_lane_handle = FarmLane_GetTaskHandle()
local push_lane_handle = Push_GetTaskHandle()
local currentTask = Task_GetCurrentTaskHandle
local nearbyOuter = Set_GetEnemyHeroesInPlayerRadiusAndOuter	
local unitsInRadius = Set_GetUnitsInRadiusCircle
local Item_ItemOwnedAnywhere = Item_ItemOwnedAnywhere
local Farm_JungleCampClearViability = Farm_JungleCampClearViability
local UseAbility_RegisterAbilityUseAndLockToScore = UseAbility_RegisterAbilityUseAndLockToScore
local PASSIVE_ACTIVITY_TYPE_LIMIT = PASSIVE_ACTIVITY_TYPE_LIMIT

local HAND_OF_MIDAS_SCORE = T_ITEM_FUNCS["item_hand_of_midas"][ITEM_FUNCS_I.SCORE_FUNC]

local max = math.max
local min = math.min

local fight_kill_commit_task_handle = FightKillCommit_GetTaskHandle()
local fight_harass_task_handle = FightHarass_GetTaskHandle()
local increase_safety_handle = IncreaseSafety_GetTaskHandle()

local NOT_WAITING_PORT_START = 1
local WAITING_PORT_START = 2

local t_player_abilities = {}
local t_tempest = {}
local t_tempest_port_expiry = {}
local t_tempest_port_state = {}

local t_have_midas = {}

do
	for pnot=1,TEAM_NUMBER_OF_PLAYERS do
		t_tempest_port_expiry[pnot] = 0
		t_tempest_port_state[pnot] = NOT_PORTING
	end
end

local function tempest_double_cast(gsiTempest, ability, target)
	local f = AbilityLogic_DeduceTargetTypeCastFunc(gsiTempest, target)
	--print(ability, ability:GetName(), gsiTempest.hUnit:GetAbilityByName(ability:GetName()))
	local abilityName = ability:GetName()
	local botAbility = abilityName == "arc_warden_flux" and gsiTempest.hUnit:GetAbilityInSlot(0)
			or abilityName == "arc_warden_magnetic_field" and gsiTempest.hUnit:GetAbilityInSlot(1)
			or abilityName == "arc_warden_spark_wraith" and gsiTempest.hUnit:GetAbilityInSlot(2)
	--print("Tempest casting", botAbility:GetName(), f, target, target.x, target.hUnit, target.GetName and target:GetName())
	f(gsiTempest.hUnit, botAbility, target and target.hUnit and target.hUnit or target)
end

local function tempest_double_think(genericAbilityThink)
	local tempestDouble = GSI_GetZetTempestGsiUnit()
	if DEBUG then DEBUG_print(string.format("tempest_double_think: %s", Util_Printable(tempestDouble))) end
	if tempestDouble == nil then return end -- Relevent for reloads // persistent job or player.lua data
	local hUnit = tempestDouble.hUnit
	local gsiPlayer = GSI_GetPlayerFromPlayerID(tempestDouble.playerID)
	local pnot = gsiPlayer.nOnTeam
	--print("arc tempest run", GameTime())
	local baseOrLaneLocation = Map_GetBaseOrLaneLocation(tempestDouble.lastSeen.location) 
	local remainingTime = hUnit:GetRemainingLifespan()

	-- Teleport Logic. Rather than explain logic, the problem is: item_tpscroll is put on cd before cast starts
	local castingTeleport = tempestDouble.hUnit:GetCurrentActiveAbility()
	castingTeleport = castingTeleport and castingTeleport:GetName() == "item_tpscroll"
	local expiredTeleport = t_tempest_port_expiry[pnot] < GameTime()
	--print(castingTeleport)
	if castingTeleport or expiredTeleport then
		t_tempest_port_state[pnot] = NOT_WAITING_PORT_START
	end
	local hTpScroll = hUnit:GetItemInSlot(TPSCROLL_SLOT)
	if hTpScroll then
		--print("zet double port vals:", t_tempest_port_state[pnot], castingTeleport, AbilityLogic_AbilityCanBeCast(tempestDouble, hTpScroll), Map_BaseLogicalLocationIsTeam(baseOrLaneLocation)--[[, not WP_AnyBaseDefence()]])
		if castingTeleport or t_tempest_port_state[pnot] == WAITING_PORT_START
				or ((AbilityLogic_AbilityCanBeCast(tempestDouble, hTpScroll) and Map_BaseLogicalLocationIsTeam(baseOrLaneLocation) and not ZoneDefend_AnyBuildingDefence())) then
			if not castingTeleport or t_tempest_port_state[pnot] == WAITING_PORT_START then
				local nearestCreeps = Set_GetNearestEnemyCreepSetToLocation(tempestDouble.lastSeen.location)
				if not castingTeleport and Math_PointToPointDistance2D(tempestDouble.lastSeen.location, nearestCreeps.center) > 2000 and not Farm_AnyOtherCoresInLane(tempestDouble, nearestCreeps) then
					if t_tempest_port_state[pnot] == NOT_WAITING_PORT_START then
						t_tempest_port_expiry[pnot] = GameTime() + 7
					end
					t_tempest_port_state[pnot] = WAITING_PORT_START
				end
				hUnit:Action_UseAbilityOnLocation(hTpScroll, nearestCreeps.center)
			end
			return;
		end
	end
	if genericAbilityThink(tempestDouble) then
		--print("non-ability")
		-- TODO Port table to prevent port interrupt
		local nearbyEnemies = Set_GetEnemyHeroesInPlayerRadius(
				tempestDouble, max(1200, min(3500, (remainingTime - 4)*tempestDouble.currentMovementSpeed)), 4)
if DEBUG then
		for i=1,#nearbyEnemies do
			DebugDrawLine(hUnit:GetLocation(), nearbyEnemies[i].lastSeen.location, 100, 255, 50)
		end
end
		local nearbyCreeps
		local tempestHealthPercent = tempestDouble.lastSeenHealth / tempestDouble.maxHealth
		local lowestPlayer, lowestHealthPercent = Unit_LowestHealthPercentPlayer(nearbyEnemies)

		if (nearbyEnemies[1] and tempestHealthPercent < 0.45) or tempestHealthPercent < 0.2
				or (Farm_JungleCampClearViability(tempestDouble, JUNGLE_CAMP_EASY) < 1
					and lowestPlayer and lowestHealthPercent > 0.15) then
			hUnit:Action_MoveDirectly(Map_GetTeamFountainLocation(TEAM))
			local owned, midas = Item_ItemOwnedAnywhere(tempestDouble, "item_hand_of_midas")
			--print("see midas", owned, midas and midas:GetName())
			if owned then
				local target = HAND_OF_MIDAS_SCORE(tempestDouble, midas)
				if target then
					hUnit:Action_UseAbilityOnEntity(midas, target)
				end
			end
			return;
		end
		if nearbyEnemies[1] then
			--print("tempest in attack")
			if hUnit:IsCastingAbility() then
				--print("casting")
				return;
			end
			local sparkWraith = hUnit:GetAbilityInSlot(2)
			if hUnit:GetRemainingLifespan() < 0.67
					and sparkWraith:IsCooldownReady()
					and tempestDouble.lastSeenMana > sparkWraith:GetManaCost()
					and not hUnit:IsSilenced()
					and (lowestPlayer.lastSeenHealth > hUnit:GetAttackDamage()
						or Vector_PointDistance2D(hUnit:GetLocation(), lowestPlayer.lastSeen.location)
								> tempestDouble.attackRange
						) then
				local extrapolated = lowestPlayer.hUnit:GetExtrapolatedLocation(S_W_EXTRAPOLATE_TIME)
				extrapolated = Vector_ScalePointToPointByFactor(
						tempestDouble.lastSeen.location, extrapolated,
						1, sparkWraith:GetCastRange()
					)
				--print("end of lifespan spark")
				hUnit:Action_UseAbilityOnLocation(sparkWraith, extrapolated)
				return;
			end
			if GSI_UnitCanStartAttack(tempestDouble) then
				--print(nearbyEnemies[1].hUnit, lowestPlayer.hUnit, lowestPlayer.hUnit:IsNull())
				--print(lowestPlayer.shortName, nearbyEnemies[1].shortName)
				--DebugDrawLine(hUnit:GetLocation(), lowestPlayer.lastSeen.location, 255, 255, 255)
				--print(hUnit, gsiPlayer.hUnit, hUnit.Action_AttackUnit, gsiPlayer.hUnit.Action_AttackUnit)
				--hUnit:ActionQueue_AttackUnit(lowestPlayer.hUnit, true)
				hUnit:Action_AttackUnit(lowestPlayer.hUnit, true)
				return;
			else
				--print("tempest attack move")
				Positioning_ZSAttackRangeUnitHugAllied(tempestDouble, lowestPlayer.lastSeen.location, SET_ENEMY_HERO, 50, 0.15)
			end
		end
		local owned, midas = Item_ItemOwnedAnywhere(tempestDouble, "item_hand_of_midas")
		if owned then
			local target = HAND_OF_MIDAS_SCORE(tempestDouble, midas)
			if target then
				hUnit:Action_UseAbilityOnEntity(midas, target)
				return;
			end
		end
		--TEMP
		--print("end")
		if not hUnit:GetAttackTarget() then
			local nearbyTower = hUnit:GetNearbyTowers(1600, true)
			if nearbyTower[1] then
				hUnit:Action_AttackMove(Map_GetAncientOnRopesFightLocation(ENEMY_TEAM))
				return;
				--hUnit:Action_AttackUnit(GetUnitList(UNIT_LIST_ENEMY_CREEPS)[1], true)
			else
				local loc, available, creeps = FarmJungle_GetNearestUncertainUncleared(
						tempestDouble)
				--print("jugnle loc", loc, available, creeps)
				if loc and Math_ETA(tempestDouble, loc) + 1 < hUnit:GetRemainingLifespan() then
					hUnit:Action_AttackMove(loc)
					return;
				end
			end
			hUnit:Action_AttackMove(Map_GetAncientOnRopesFightLocation(ENEMY_TEAM))
		end
		return;
	end
end

local d
d = {
	["ReponseNeeds"] = function()
		return nil, {RESPONSE_TYPE_KNOCKBACK, 2}, nil, nil
	end,
	["InformLevelUpSuccess"] = function(gsiPlayer)
		AbilityLogic_UpdateHighUseMana(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam])
	end,
	["Initialize"] = function(gsiPlayer)
		AbilityLogic_CreatePlayerAbilitiesIndex(t_player_abilities, gsiPlayer, abilities)
		AbilityLogic_UpdateHighUseMana(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam])
	end,
	["TempestDoubleThink"] = function() tempest_double_think(d.AbilityThink) end,
	["AbilityThink"] = function(gsiPlayer)
-- Returns true if tempest double is not casting a spell
		local USE_ABILITY
		local tempestAggressive = gsiPlayer.isTempest and gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth > 0.35
		if gsiPlayer.isTempest then -- Are we in a deeper stack with a tempest from tempest_double_think()? (the else code-block)
			USE_ABILITY = tempest_double_cast
		else
			USE_ABILITY = UseAbility_RegisterAbilityUseAndLockToScore
		end

		local pnot = gsiPlayer.nOnTeam
		local thisPlayerAbilities = t_player_abilities[pnot]
		local flux, magneticField, sparkWraith, tempestDouble
		if gsiPlayer.isTempest then
			local hTempestUnit = gsiPlayer.hUnit
			flux = hTempestUnit:GetAbilityInSlot(0)
			magneticField = hTempestUnit:GetAbilityInSlot(1)
			sparkWraith = hTempestUnit:GetAbilityInSlot(2)
			tempestDouble = hTempestUnit:GetAbilityInSlot(5)
		else
			flux = thisPlayerAbilities[1]
			magneticField = thisPlayerAbilities[2]
			sparkWraith = thisPlayerAbilities[3]
			tempestDouble = thisPlayerAbilities[4]
			t_have_midas[pnot] = t_have_midas[pnot] or Item_ItemOwnedAnywhere(gsiPlayer, "item_hand_of_midas")
		end
		if not UseAbility_IsPlayerLocked(gsiPlayer) then
			local currActivityType = Blueprint_GetCurrentTaskActivityType(gsiPlayer)
			local currTask = currentTask(gsiPlayer)
			local fightHarassTarget = Task_GetTaskObjective(gsiPlayer, fight_harass_task_handle)
			local nearbyEnemies, outerEnemies = nearbyOuter(gsiPlayer.lastSeen.location, max(thisPlayerAbilities[1]:GetCastRange()+100, gsiPlayer.attackRange), thisPlayerAbilities[3]:GetCastRange())
			local basicTarget = fightHarassTarget or nearbyEnemies[1]

			if not gsiPlayer.isTempest and AbilityLogic_AbilityCanBeCast(gsiPlayer, tempestDouble)
					and (
						(t_have_midas[pnot] or currTask == increase_safety_handle
								and not nearbyEnemies[1] and not outerEnemies[1]
						) or (currActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION 
							and (AbilityLogic_AbilityCanBeCast(gsiPlayer, tempestDouble)
									and (gsiPlayer.lastSeenHealth
											- Analytics_GetTotalDamageInTimeline(gsiPlayer.hUnit)
										) / gsiPlayer.maxHealth > 0.5 + #nearbyEnemies*0.075
								)
							)
						) then
				USE_ABILITY(gsiPlayer, tempestDouble, nil, 400)
				return
			end
			if currActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION or tempestAggressive then
				-- cast flux on a nearby target
				if basicTarget then
					--if gsiPlayer.isTempest then print(AbilityLogic_AbilityCanBeCast(gsiPlayer, flux)) end
					if AbilityLogic_AbilityCanBeCast(gsiPlayer, flux) 
							and (gsiPlayer.isTempest or AbilityLogic_HighUseAllowOffensive(gsiPlayer, flux, HIGH_USE_FLUX_REMAINING_MANA, Unit_GetHealthPercent(basicTarget))) then
						USE_ABILITY(gsiPlayer, flux, basicTarget, 400)
						if not gsiPlayer.isTempest then Task_IncentiviseTask(gsiPlayer, FightHarass_GetTaskHandle(), 12, 2) end
						return
					end
				end
				-- include outer enemies into ability targeting if we had no target
				local lowestHealthPercent
				if not basicTarget then
					basicTarget, lowestHealthPercent = Unit_LowestHealthPercentPlayer(outerEnemies)
				else
					lowestHealthPercent = basicTarget.lastSeenHealth / basicTarget.maxHealth
				end

				-- try spark wraith
				if basicTarget and not basicTarget.typeIsNone then
					if AbilityLogic_AbilityCanBeCast(gsiPlayer, sparkWraith) and basicTarget.hUnit:GetMovementDirectionStability() > 0.3 
							and (gsiPlayer.isTempest or AbilityLogic_HighUseAllowOffensive(gsiPlayer, sparkWraith, HIGH_USE_S_W_REMAINING_MANA, lowestHealthPercent)) then
						--print("ARC WARDEN -- USE SPARK AGGRESSIVE")
						local extrapolatedLocation = basicTarget.hUnit:GetExtrapolatedLocation(S_W_EXTRAPOLATE_TIME)
						if not Set_GetUnitsInRadiusCircle(extrapolatedLocation, 600, Set_GetNearestEnemyCreepSetToLocation(extrapolatedLocation), nil, true)[1] then
							USE_ABILITY(gsiPlayer, sparkWraith, extrapolatedLocation, 400)
							if not gsiPlayer.isTempest then Task_IncentiviseTask(gsiPlayer, fight_kill_commit_task_handle, 10, 4) end
							return
						end
					end
				end
			elseif currActivityType > ACTIVITY_TYPE.CAREFUL or tempestAggressive == false then
				local nearestEnemyIncludesFog, nearestEnemyIncludesFogDist = Set_GetNearestEnemyHeroToLocation(gsiPlayer.lastSeen.location, 1.5) -- safety throw down a spark wraith while you're juking, even if they become fogged
				--print("safe spark check ", nearestEnemyIncludesFog, nearestEnemyIncludesFogDist, not Set_GetUnitsInRadiusCircle(gsiPlayer.lastSeen.location, 600, Set_GetNearestEnemyCreepSetToLocation(gsiPlayer.lastSeen.location), nil, true)[1])
				if nearestEnemyIncludesFog and nearestEnemyIncludesFogDist < 1400
						and not Set_GetUnitsInRadiusCircle(gsiPlayer.lastSeen.location, 600, Set_GetNearestEnemyCreepSetToLocation(gsiPlayer.lastSeen.location), nil, true)[1] then
					if AbilityLogic_AbilityCanBeCast(gsiPlayer, sparkWraith) 
							and (gsiPlayer.isTempest or AbilityLogic_HighUseAllowOffensive(gsiPlayer, sparkWraith, HIGH_USE_S_W_REMAINING_MANA, Unit_GetHealthPercent(nearestEnemyIncludesFog))) then
						--print("ARC WARDEN -- USE SPARK SAFE")
						local unitFacingDirectional = Vector_UnitDirectionalFacingDirection(gsiPlayer.hUnit:GetFacing())
						local aheadOfPlayer = Vector_Addition(gsiPlayer.lastSeen.location, Vector_ScalarMultiply2D(unitFacingDirectional, 400))
						USE_ABILITY(gsiPlayer, sparkWraith, aheadOfPlayer, 400)
						return
					end
				end
				if nearbyEnemies[1] then
					if gsiPlayer.hUnit:TimeSinceDamagedByAnyHero() < 1.0 or not Set_GetUnitsInRadiusCircle(gsiPlayer.lastSeen.location, 600, Set_GetNearestEnemyCreepSetToLocation(gsiPlayer.lastSeen.location), nil, true)[1] then
						if AbilityLogic_AbilityCanBeCast(gsiPlayer, flux)
								and (gsiPlayer.isTempest or AbilityLogic_HighUseAllowOffensive(gsiPlayer, flux, HIGH_USE_FLUX_REMAINING_MANA, Unit_GetHealthPercent(nearbyEnemies[1]))) then
							USE_ABILITY(gsiPlayer, flux, nearbyEnemies[1], 400)
							return
						end
					end
				end
			end
			if AbilityLogic_AbilityCanBeCast(gsiPlayer, magneticField) and not gsiPlayer.hUnit:HasModifier("modifier_magnetic_field") 
					and AbilityLogic_HighUseAllowOffensive(gsiPlayer, magneticField, HIGH_USE_M_F_REMAINING_MANA, Unit_GetHealthPercent(gsiPlayer))
					and ((currTask == push_lane_handle and #(gsiPlayer.hUnit:GetNearbyTowers(gsiPlayer.attackRange+50, true)) > 0
							or #(gsiPlayer.hUnit:GetNearbyCreeps(gsiPlayer.attackRange+50, true)) >= 4
							or (currTask == fight_harass_handle and fightHarassTarget
									and Math_PointToPointDistance2D(gsiPlayer.lastSeen.location, fightHarassTarget.lastSeen.location) < gsiPlayer.attackRange - USE_MAGNETIC_WHEN_CLOSER_RANGE)
						)
					) then
				USE_ABILITY(gsiPlayer, magneticField, gsiPlayer.lastSeen.location, 400)	
				--print("doingstuff")
				return
			end
		end
		return true
	end,
}
local hero_access = function(key) return d[key] end

do
	HeroData_SetHeroData(hero_data, abilities, hero_access)
end
