local hero_data = {
	"abyssal_underlord",
	{3, 1, 2, 1, 1, 4, 1, 2, 2, 6, 2, 4, 3, 3, 7, 3, 4, 9, 11},
	{
		"item_quelling_blade","item_gauntlets","item_gauntlets","item_tango","item_branches","item_faerie_fire","item_ring_of_health","item_soul_ring","item_vanguard","item_boots","item_magic_wand","item_arcane_boots","item_vitality_booster","item_rod_of_atos","item_aghanims_shard","item_chainmail","item_headdress","item_buckler","item_guardian_greaves","item_void_stone","item_platemail","item_pers","item_energy_booster","item_lotus_orb","item_platemail","item_shivas_guard","item_heart","item_gungir",
	},
	{ {3,3,3,3,3,}, {3,3,3,3,3,}, 0.1 },
	{
		"Firestorm","Pit of Malice","Atrophy Aura","Fiend's Gate","+5 Armor","+75 Firestorm Radius","+75 Pit of Malice AoE","-3s Firestorm Cooldown","+0.8% Firestorm Burn Damage","+15% Atrophy Aura Attack Damage Reduction","+0.65s Pit of Malice Root","+50% Atrophy Allied Hero Bonus",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local HIGH_USE_FS = 140 + 100
local HIGH_USE_POM = 130 + 100
local HIGH_USE_D_R = 130 + 140

local ABILITY_USE_RANGE = 675

local nearbyOuter = Set_GetEnemyHeroesInPlayerRadiusAndOuter
local ENCASED_IN_RECT = Set_GetEnemiesInRectangle
local currentTask = Task_GetCurrentTaskHandle
local AbilityLogic_AbilityCanBeCast = AbilityLogic_AbilityCanBeCast
local CROWDED_RATING = Set_GetCrowdedRatingToSetTypeAtLocation
local USE_ABILITY = UseAbility_RegisterAbilityUseAndLockToScore
local VEC_UNIT_DIRECTIONAL = Vector_UnitDirectionalPointToPoint
local PASSIVE_ACTIVITY_TYPE_LIMIT = PASSIVE_ACTIVITY_TYPE_LIMIT
local ACTIVITY_TYPE = ACTIVITY_TYPE
local currentActivityType = Blueprint_GetCurrentTaskActivityType
local currentTask = Task_GetCurrentTaskHandle
local HIGH_USE = AbilityLogic_HighUseAllowOffensive

local push_task_handle = Push_GetTaskHandle()
local fight_harass_task_task_handle = FightHarass_GetTaskHandle()

local abilities = {
		[0] = {"abyssal_underlord_firestorm", ABILITY_TYPE.NUKE + ABILITY_TYPE.AOE + ABILITY_TYPE.POINT_TARGET},
		{"abyssal_underlord_pit_of_malice", ABILITY_TYPE.ROOT + ABILITY_TYPE.AOE + ABILITY_TYPE.POINT_TARGET},
		{"abyssal_underlord_atrophy_aura", ABILITY_TYPE.PASSIVE + ABILITY_TYPE.BUFF + ABILITY_TYPE.DEGEN},
		[5] = {"abyssal_underlord_dark_rift", ABILITY_TYPE.MOBILITY},
		{"abyssal_underlord_cancel_dark_rift", ABILITY_TYPE.SECONDARY}
}

local t_player_abilities = {}

local d
d = {
	["InformLevelUpSuccess"] = function(gsiPlayer)
		AbilityLogic_UpdateHighUseMana(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam])
		AbilityLogic_UpdatePlayerAbilitiesIndex(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam], abilities)
	end,
	["Initialize"] = function(gsiPlayer)
		AbilityLogic_CreatePlayerAbilitiesIndex(t_player_abilities, gsiPlayer, abilities)
		AbilityLogic_UpdateHighUseMana(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam])
		gsiPlayer.InformLevelUpSuccess = d.InformLevelUpSuccess
	end,
	["AbilityThink"] = function(gsiPlayer) 
		local abilityLocked, _, queuedAbility = UseAbility_IsPlayerLocked(gsiPlayer)
		if not abilityLocked then
			local abilities = t_player_abilities[gsiPlayer.nOnTeam]
			local firestorm = abilities[1]
			local pitOfMalice = abilities[2]
			local darkRift = abilities[4]
			local currActivityType = currentActivityType(gsiPlayer)
			local currTask = currentTask(gsiPlayer)
			local playerHealthPercent = gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth
			local nearbyEnemies = Set_GetEnemyHeroesInPlayerRadius(gsiPlayer, ABILITY_USE_RANGE)
			if not nearbyEnemies[1] then
				-- dark rift

				-- push wave fs
				local currTask = currentTask(gsiPlayer)
				if currTask == push_task_handle then
					-- TODO firestorm building damage
					if AbilityLogic_AbilityCanBeCast(gsiPlayer, firestorm) and HIGH_USE(gsiPlayer, firestorm, HIGH_USE_FS, 1) then
						local enemyCreepSet = Set_GetNearestEnemyCreepSetToLocation(gsiPlayer.lastSeen.location)
						if enemyCreepSet and #(enemyCreepSet.units) > 4 and Math_PointToPointDistance2D(gsiPlayer.lastSeen.location, enemyCreepSet.center) < ABILITY_USE_RANGE then
							USE_ABILITY(gsiPlayer, firestorm, enemyCreepSet.center, 400, nil)
							return
						end
					end
				end
			end
			-- have nearby enemies
			if currActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION or currTask == push_task_handle then
				-- firstorm crowding
				local fightHarassTarget = Task_GetTaskObjective(gsiPlayer, fight_harass_task_task_handle)
				if fightHarassTarget then
					if AbilityLogic_AbilityCanBeCast(gsiPlayer, firestorm) then
						local crowdingCenter, crowdedRating = CROWDED_RATING(fightHarassTarget.lastSeen.location, SET_HERO_ENEMY)
						--print("underlord sees crowded Firestorm Heroes", crowdedRating)
						if crowdedRating > 1.5 then
							USE_ABILITY(gsiPlayer, firestorm, crowdingCenter, 400, nil)
							return
						end

						crowdingCenter, crowdedRating = CROWDED_RATING(fightHarassTarget.lastSeen.location, SET_CREEP_ENEMY)
						--print("underlord sees crowded Firestorm Creeps", crowdedRating)
						if crowdedRating > 3 then
							USE_ABILITY(gsiPlayer, firestorm, crowdingCenter, 400, nil)
							return
						end
						if not fightHarassTarget.typeIsNone and (fightHarassTarget.hUnit:IsStunned() or fightHarassTarget.hUnit:IsRooted()) then
							USE_ABILITY(gsiPlayer, firestorm, fightHarassTarget.lastSeen.location)
							return
						end
					end
					if AbilityLogic_AbilityCanBeCast(gsiPlayer, pitOfMalice) then
						local crowdingCenter, crowdedRating = CROWDED_RATING(fightHarassTarget.lastSeen.location, SET_HERO_ENEMY)
						--print("underlord sees crowded Firestorm Heroes", crowdedRating)
						if (not fightHarassTarget.typeIsNone and fightHarassTarget.hUnit:HasModifier("modifier_abyssal_underlord_firestorm_burn")) or (currActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION and Unit_GetHealthPercent(fightHarassTarget) < 0.35 and (fightHarassTarget.typeIsNone or Vector_UnitFacingUnit(fightHarassTarget, gsiPlayer) < 0)) then
							USE_ABILITY(gsiPlayer, pitOfMalice, crowdingCenter, 400, nil)
							return
						end
					end
				end
				--print("underlord ability think fightHarassTarget was ", fightHarassTarget)
			elseif currActivityType > ACTIVITY_TYPE.CAREFUL then
				local nearbyAndFogged = Set_GetEnemyHeroesInPlayerRadius(gsiPlayer, 1100, 2)
				--print("undi plant", nearbyAndFogged[1], gsiPlayer.hUnit:GetMovementDirectionStability())
				if nearbyAndFogged[1] and gsiPlayer.hUnit:GetMovementDirectionStability() > 0.1 then
					local infrontOfPlayer = Vector_Addition(
							gsiPlayer.lastSeen.location,
							Vector_ScalarMultiply2D(
								Vector_UnitDirectionalFacingDirection(gsiPlayer.hUnit:GetFacing()),
								175)
						)
					if AbilityLogic_AbilityCanBeCast(gsiPlayer, pitOfMalice) then
						USE_ABILITY(gsiPlayer, pitOfMalice, infrontOfPlayer, 400, nil)
						return
					end
					if playerHealthPercent < 0.45
								and Analytics_GetTotalDamageInTimeline(gsiPlayer.hUnit) > gsiPlayer.hUnit:GetAttackDamage()
								and AbilityLogic_AbilityCanBeCast(gsiPlayer, firestorm) then
						if Math_PointToPointDistance2D(infrontOfPlayer, nearbyAndFogged[1].lastSeen.location) > 650 then
							infrontOfPlayer = Vector_PointBetweenPoints(infrontOfPlayer, nearbyAndFogged[1].lastSeen.location)
						end
						USE_ABILITY(gsiPlayer, firestorm, infrontOfPlayer, 400, nil)
						return
					end
				end
			end
		end
	end,
}

local hero_access = function(key) return d[key] end

do
	HeroData_SetHeroData(hero_data, abilities, hero_access)
end
