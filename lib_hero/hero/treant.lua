local hero_data = {
	"treant",
	{2, 1, 2, 1, 2, 4, 3, 3, 2, 3, 5, 4, 1, 1, 8, 3, 4, 9, 11},
	{
		"item_orb_of_venom","item_blood_grenade","item_enchanted_mango","item_tango","item_ward_sentry","item_medallion_of_courage","item_boots","item_wind_lace","item_crown","item_tranquil_boots","item_wind_lace","item_solar_crest","item_magic_wand","item_aghanims_shard","item_wind_lace","item_ancient_janggo","item_fluffy_hat","item_staff_of_wizardry","item_force_staff","item_boots_of_bearing","item_blink","item_cornucopia","item_cornucopia","item_refresher","item_gem",
	},
	{ {1,1,1,5,3,}, {5,5,5,4,4,}, 0.1 },
	{
		"Nature's Grasp","Leech Seed","Living Armor","Overgrowth","+2 Living Armor Heal Per Second","-5.0s Nature's Grasp Cooldown","+18% Leech Seed Movement Slow","+30 Nature's Grasp Damage","+8 Living Armor Bonus Armor","+45 Leech Seed Damage/Heal","-40s Overgrowth Cooldown","450 AoE Living Armor",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"treant_natures_grasp", ABILITY_TYPE.SLOW + ABILITY_TYPE.NUKE},
		{"treant_leech_seed", ABILITY_TYPE.SLOW + ABILITY_TYPE.NUKE + ABILITY_TYPE.DEGEN + ABILITY_TYPE.HEAL},
		{"treant_living_armor", ABILITY_TYPE.BUFF + ABILITY_TYPE.HEAL},
		{"treant_natures_guise", ABILITY_TYPE.PASSIVE},
		[5] = {"treant_overgrowth", ABILITY_TYPE.ROOT + ABILITY_TYPE.NUKE},
}

local ZEROED_VECTOR = ZEROED_VECTOR
local playerRadius = Set_GetEnemyHeroesInPlayerRadius
local ENCASED_IN_RECT = Set_GetEnemiesInRectangle
local CURRENT_TASK = Task_GetCurrentTaskHandle
local CAN_BE_CAST = AbilityLogic_AbilityCanBeCast
local CHARGE_CAN_BE_CAST = ChargedCooldown_AbilityCanBeCast
local USE_ABILITY = UseAbility_RegisterAbilityUseAndLockToScore
local VEC_POINT_DISTANCE = Vector_PointDistance
local VEC_UNIT_DIRECTIONAL = Vector_UnitDirectionalPointToPoint
local ACTIVITY_TYPE = ACTIVITY_TYPE
local HANDLE_AUTOCAST_GENERIC = AbilityLogic_HandleAutocastGeneric
local AOHK = AbilityLogic_AllowOneHitKill
local ANY_HARM = FightClimate_AnyIntentToHarm
local CURRENT_ACTIVITY_TYPE = Blueprint_GetCurrentTaskActivityType
local TASK_OBJECTIVE = Task_GetTaskObjective
local HEALTH_PERCENT = Unit_GetHealthPercent
local SET_ENEMY_HERO = SET_ENEMY_HERO
local ABILITY_LOCKED = UseAbility_IsPlayerLocked
local CROWDED_RATING = Set_GetCrowdedRatingToSetTypeAtLocation
local NEARBY_OUTER = Set_GetEnemyHeroesInPlayerRadiusAndOuter
local NEARBY_ENEMY = Set_GetEnemyHeroesInPlayerRadius
local HIGH_USE = AbilityLogic_HighUseAllowOffensive
local SPELL_SUCCESS = AbilityLogic_CastOnTargetWillSucceed
local max = math.max
local min = math.min
local sqrt = math.sqrt
local SAVE_JIT = FightClimate_GetIntentCageFightSaveJIT

local ABILITY_USE_RANGE = 850
local OUTER_RANGE = 1600

local fight_harass_handle = FightHarass_GetTaskHandle()
local push_handle = Push_GetTaskHandle()
local zone_defend_handle = ZoneDefend_GetTaskHandle()

local t_enemy_players
local t_team_players
local team_fountain_unit

local t_player_abilities = {}
local t_watching_tower = {}

local N_G_PATH_LENGTH = 1500
local N_G_EXTRAPOLATE = 0.8 + 135 / 500 -- Full path creation + upper mvspeed enemy time to get through radius
local OVERGROWTH_RADIUS = 900

local d
d = {
	["ReponseNeeds"] = function()
		return nil, REASPONSE_TYPE_DISPEL, nil, {RESPONSE_TYPE_KNOCKBACK, 4}
	end,
	["Initialize"] = function(gsiPlayer)
		AbilityLogic_CreatePlayerAbilitiesIndex(t_player_abilities, gsiPlayer, abilities)
		AbilityLogic_UpdateHighUseMana(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam])
		t_enemy_players = GSI_GetTeamPlayers(ENEMY_TEAM)
		t_team_players = GSI_GetTeamPlayers(TEAM)

		gsiPlayer.InformLevelUpSuccess = d.InformLevelUpSuccess
	end,
	["InformLevelUpSuccess"] = function(gsiPlayer)
		AbilityLogic_UpdateHighUseMana(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam])
		t_player_abilities[gsiPlayer.nOnTeam][3] = gsiPlayer.hUnit:GetAbilityInSlot(2)
		AbilityLogic_UpdatePlayerAbilitiesIndex(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam], abilities)
	end,
	["AbilityThink"] = function(gsiPlayer) 
		if UseAbility_IsPlayerLocked(gsiPlayer) then
			return;
		end
		team_fountain_unit = team_fountain_unit or GSI_GetTeamFountainUnit(TEAM)
		local playerAbilities = t_player_abilities[gsiPlayer.nOnTeam]
		local grasp = playerAbilities[1]
		local seed = playerAbilities[2]
		local livingArmor = playerAbilities[3]
		local overgrowth = playerAbilities[5]

		local highUse = gsiPlayer.highUseManaSimple
		local currentTask = CURRENT_TASK(gsiPlayer)
		local currentActivityType = CURRENT_ACTIVITY_TYPE(gsiPlayer)
		local fht = TASK_OBJECTIVE(gsiPlayer, fight_harass_handle)
		local fhtReal = fht and fht.hUnit.IsNull and not fht.hUnit:IsNull()
		local fhtHUnit = fhtReal and fht.hUnit
		local fhtHpp = fht and fht.lastSeenHealth / fht.maxHealth
		local fhtLoc = fht and fht.lastSeen.location

		local playerHUnit = gsiPlayer.hUnit
		local playerLoc = gsiPlayer.lastSeen.location
		local playerHpp = HEALTH_PERCENT(gsiPlayer)

		local distToFht = fht and VEC_POINT_DISTANCE(playerLoc, fhtLoc)

		local nearbyEnemies, outerEnemies = NEARBY_OUTER(playerLoc, OVERGROWTH_RADIUS,
				N_G_PATH_LENGTH, 2
			)

		local danger = Analytics_GetTheoreticalDangerAmount(gsiPlayer)

		local anyIntent, intentsTbl = FightClimate_AnyIntentToHarm(gsiPlayer, t_enemy_players)
		local nearbyAllies

		local arbitraryEnemy = nearbyEnemies[1] or outerEnemies[1]
		if arbitraryEnemy then
			if CAN_BE_CAST(gsiPlayer, grasp) then
				if currentActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION then
					if fhtReal and HIGH_USE(gsiPlayer, grasp, highUse, fhtHpp)
							and distToFht < N_G_PATH_LENGTH
									* (1 + 0.1*Vector_UnitFacingUnit(fhtHUnit, playerHUnit)) then
						local extrapolatedLoc = fhtHUnit:GetExtrapolatedLocation(
								N_G_EXTRAPOLATE * distToFht / N_G_PATH_LENGTH
							)
						USE_ABILITY(gsiPlayer, grasp, extrapolatedLoc, 500, nil)
						return;
					end
				elseif currentActivityType >= ACTIVITY_TYPE.CAREFUL
						and HIGH_USE(gsiPlayer, grasp, highUse, playerHpp) then
					--Util_TablePrint({"FOUNTAIN TREANT", team_fountain_unit})
					if anyIntent
							and Vector_UnitFacingUnit(gsiPlayer.hUnit, team_fountain_unit) > 0.75 then
						local t_enemy_players = t_enemy_players
						for i=1,#intentsTbl do
							if intentsTbl[i] == gsiPlayer then
								local thisEnemy = t_enemy_players[i]
								if VEC_POINT_DISTANCE(playerLoc, thisEnemy.lastSeen.location)
										< thisEnemy.attackRange*1.1 then
									local castLoc = Vector_Addition(
											playerLoc,
											Vector_ScalarMultiply(
													Vector_UnitDirectionalFacingDirection(playerHUnit:GetFacing()),
													600
												)
										)
									USE_ABILITY(gsiPlayer, grasp, castLoc, 500, nil)
									return;
								end
							end
						end
					end
					nearbyAllies = nearbyAllies or Set_GetAlliedHeroesInPlayerRadius(gsiPlayer, N_G_PATH_LENGTH)
					if nearbyAllies[1] then
						for i=1,#intentsTbl do
							local thisIntent = intentsTbl[i]
							local intentTask = thisIntent and CURRENT_ACTIVITY_TYPE(thisIntent)
							if thisIntent
									and ( intentTask <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION
											or intentTask >= ACTIVITY_TYPE.FEAR
										) then
								local crowdedCenter, crowdedRating = CROWDED_RATING(
										arbitraryEnemy.lastSeen.location,
										SET_HERO_ENEMY,
										nil,
										N_G_PATH_LENGTH
									)
								USE_ABILITY(gsiPlayer, grasp, crowdedCenter, 500, nil)
								return;
							end
						end
					end
				end
			end
			if fhtReal and distToFht < seed:GetCastRange() and CAN_BE_CAST(gsiPlayer, seed)
					and HIGH_USE(gsiPlayer, seed, highUse, fhtHpp) then
				USE_ABILITY(gsiPlayer, seed, fht, 500, nil)
				return;
			end
			if CAN_BE_CAST(gsiPlayer, overgrowth) and nearbyEnemies[2] then
				local nearMiss = false
				local overgrowthNearMissRange = OVERGROWTH_RADIUS*1.25
				for i=1,#outerEnemies do
					if VEC_POINT_DISTANCE(playerLoc, outerEnemies[i].lastSeen.location) 
							< overgrowthNearMissRange then
						nearMiss = true
						break
					end
				end
				if not nearMiss then
					USE_ABILITY(gsiPlayer, overgrowth, nil, 500, nil)
					return;
				end
			end
		end
		if CAN_BE_CAST(gsiPlayer, livingArmor) then
			local saveFrom, saveUnit, secondsSurviving
					= SAVE_JIT(gsiPlayer, t_team_players, t_enemy_players, 24000)
			if saveUnit and secondsSurviving < 8
					and HIGH_USE(gsiPlayer, livingArmor, highUse, 
							saveUnit.lastSeenHealth / saveUnit.maxHealth
						) then
				USE_ABILITY(gsiPlayer, livingArmor, saveUnit, 500, nil, nil, nil, nil, gsiPlayer.hUnit.Action_UseAbilityOnEntity)
				return;
			end
			local lowestPlayer, lowestHpp = Unit_LowestHealthPercentPlayer(t_team_players)
			--print("lowestHpp", lowestHpp, highUse*2)
			if lowestHpp < 0.75 and HIGH_USE(gsiPlayer, livingArmor, highUse*2, lowestHpp) then
				USE_ABILITY(gsiPlayer, livingArmor, lowestPlayer, 500, nil, nil, nil, nil, gsiPlayer.hUnit.Action_UseAbilityOnEntity)
				return;
			end
			-- TODO activity types need to be more stable and persitant when switching to in-and-out
			-- -| tasks like use_ability, use_item, consumable. Currently tree might switch to use_item
			-- -| and say he was in a neutral task, even if he was mid-fight, he may heal a tower,
			-- -| where, the below logic is meant to prevent mid-fight tower healing.
			if currentActivityType > ACTIVITY_TYPE.CONTROLLED_AGGRESSION then
				if currentTask == zone_defend_handle or t_watching_tower[gsiPlayer.nOnTeam] then
					local zoneDefObjective = TASK_OBJECTIVE(gsiPlayer, zone_defend_handle)
					local towerObjective = zoneDefObjective
							and zoneDefObjective.isTower and zoneDefObjective
							or t_watching_tower[gsiPlayer.nOnTeam]
					if towerObjective then
						if t_watching_tower[gsiPlayer.nOnTeam] ~= towerObjective then
							t_watching_tower[gsiPlayer.nOnTeam] = towerObjective
						end
						if HIGH_USE(gsiPlayer, livingArmor, highUse*4,
										towerObjective.lastSeenHealth / towerObjective.maxHealth
									) then
							USE_ABILITY(gsiPlayer, livingArmor, towerObjective, 500, nil, nil, nil, nil, gsiPlayer.hUnit.Action_UseAbilityOnEntity)
							return;
						end
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
