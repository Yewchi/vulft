local hero_data = {
	"silencer",
	{2, 1, 1, 3, 1, 4, 1, 3, 3, 3, 5, 4, 2, 2, 7, 2, 4, 10, 12},
	{
		"item_tango","item_magic_stick","item_faerie_fire","item_enchanted_mango","item_branches","item_ward_dispenser","item_boots","item_magic_wand","item_ring_of_basilius","item_crown","item_veil_of_discord","item_staff_of_wizardry","item_force_staff","item_gem","item_glimmer_cape","item_gem","item_arcane_boots","item_energy_booster","item_void_stone","item_aether_lens","item_gem","item_gem",
	},
	{ {1,1,1,1,3,}, {5,5,5,5,4,}, 0.1 },
	{
		"Arcane Curse","Glaives of Wisdom","Last Word","Global Silence","+12 Arcane Curse Damage","+20 Attack Speed","-25.0s Global Silence Cooldown","+0.8x Last Word Int Multiplier","+10% Glaives of Wisdom Damage","Arcane Curse Undispellable","+2 Glaives of Wisdom Bounces","Last Word Mutes",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"silencer_curse_of_the_silent", ABILITY_TYPE.NUKE + ABILITY_TYPE.AOE + ABILITY_TYPE.SLOW},
		{"silencer_glaives_of_wisdom", ABILITY_TYPE.ATTACK_MODIFIER},
		{"silencer_last_word", ABILITY_TYPE.NUKE + ABILITY_TYPE.DEGEN},
		[5] = {"silencer_global_silence", ABILITY_TYPE.DEGEN + ABILITY_TYPE.UTILITY},
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

local fight_harass_handle = FightHarass_GetTaskHandle()

local t_player_abilities = {}

local d = {
	["ReponseNeeds"] = function()
		return nil, REASPONSE_TYPE_DISPEL, nil, {RESPONSE_TYPE_KNOCKBACK, 4}
	end,
	["Initialize"] = function(gsiPlayer)
		AbilityLogic_CreatePlayerAbilitiesIndex(t_player_abilities, gsiPlayer, abilities)
		AbilityLogic_UpdateHighUseMana(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam])
	end,
	["InformLevelUpSuccess"] = function(gsiPlayer)
		AbilityLogic_UpdateHighUseMana(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam])
	end,
	["AbilityThink"] = function(gsiPlayer) 
		if AbilityLogic_PlaceholderGenericAbilityUse(gsiPlayer, t_player_abilities) or true then
			return
		end
		if UseAbility_IsPlayerLocked(gsiPlayer) then
			return;
		end
		local playerAbilities = t_player_abilities[gsiPlayer.nOnTeam]
		local arcaneCurse = playerAbilities[1]
		local glaives = playerAbilities[2]
		local lastWord = playerAbilities[3]
		local silence = playerAbilities[4]

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

		Task_IncentiviseTask(gsiPlayer, fight_harass_handle, 300, 1)

		local distToFht = fht and VEC_POINT_DISTANCE(playerLoc, fhtLoc)

		local nearbyEnemies, outerEnemies = NEARBY_OUTER(playerLoc, rift:GetCastRange(), 1200, 2)

		local danger = Analytics_GetTheoreticalDangerAmount(gsiPlayer)

		local arbitraryEnemy = nearbyEnemies[1] or outerEnemies[1]

		if fhtReal and CAN_BE_CAST(gsiPlayer, arcaneCurse) then
			if currentActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION
					and distToFht < 1300
					and HIGH_USE(gsiPlayer, phantasm, highUse, fhtHpp) then
				local armlet = playerHUnit:FindItemSlot("item_armlet")
				armlet = armlet ~= -1 and playerHUnit:GetItemInSlot(armlet) or false
				--print("ck 2", armlet)
				local previousMaxHealth = 0
				if not playerHUnit:HasModifier("modifier_ancient_apparition_ice_blast")
						and armlet then
					--print("ck 3, registering phantasm")
					USE_ABILITY(gsiPlayer, function()
								if not CAN_BE_CAST(gsiPlayer, phantasm) then return true end
								if not CAN_BE_CAST(gsiPlayer, armlet) then return 1 end
								if armlet:GetAutoCastState() then
									--DebugDrawText(500, 500, "running armlet"..previousMaxHealth, 255, 255, 255)
									local newMaxHealth = playerHUnit:GetMaxHealth()
									if newMaxHealth > previousMaxHealth then
										previousMaxHealth = newMaxHealth
									else
										return 1
									end
								else
									armlet:ToggleAutoCast()
								end
								return false
							end,
							nil, 500, "CHAOS_KNIGHT_ARMLET_PHANTASM",
							nil, nil, 1.5
						)
					USE_ABILITY(gsiPlayer, phantasm, nil, 500, "CHAOS_KNIGHT_ARMLET_PHANTASM", nil, nil, 1)
				else
					USE_ABILITY(gsiPlayer, phantasm, nil, 500, nil)
				end
				return;
			end
		end
		-- TODO Defensive rift into displaced enemy towards fountain
		if fhtReal and CAN_BE_CAST(gsiPlayer, rift)
				and distToFht < rift:GetCastRange()
				and not playerHUnit:GetAttackTarget()
				and distToFht > gsiPlayer.attackRange
				and currentActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION
				and HIGH_USE(gsiPlayer, rift, highUse, fhtHpp) then
			USE_ABILITY(gsiPlayer, rift, fht, 500, nil)
			return;
		end
		if arbitraryEnemy and CAN_BE_CAST(gsiPlayer, bolt) then
			if fhtReal and currentActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION
					and HIGH_USE(gsiPlayer, bolt, highUse, fhtHpp)
					and distToFht < bolt:GetCastRange() then
				USE_ABILITY(gsiPlayer, bolt, fht, 500, nil)
				return;
			end
			if currentActivityType < ACTIVITY_TYPE.CAREFUL then
				local saveFromUnit, saveUnit = FightClimate_GetIntentCageFightSaveJIT(
						gsiPlayer, nil, nearby, bolt:GetCastRange(), true
					)
				if saveFromUnit and HIGH_USE(
								gsiPlayer, bolt, highUse,
								saveFromUnit.lastSeenHealth / saveFromUnit.maxHealth
						) then
					DebugDrawCircle(saveFromUnit.lastSeen.location, bolt:GetCastRange(), 0, 255, 0)
					USE_ABILITY(gsiPlayer, bolt, saveFromUnit, 500, nil)
					return;
				end
			elseif HIGH_USE(gsiPlayer, bolt, highUse, playerHpp) then
				local nearestEnemy, distToNearest = Set_GetSetUnitNearestToLocation(playerLoc, nearbyEnemies)
				if distToNearest < bolt:GetCastRange() then
					USE_ABILITY(gsiPlayer, bolt, nearestEnemy, 500, nil)
					return;
				end
			end
		end
	end,
}

local hero_access = function(key) return d[key] end

do
	HeroData_SetHeroData(hero_data, abilities, hero_access)
end


