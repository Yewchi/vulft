local hero_data = {
	"venomancer",
	{1, 2, 2, 1, 3, 3, 3, 5, 3, 6, 2, 5, 2, 1, 9, 1, 5, 7, 13, 11},
	{
		"item_quelling_blade","item_tango","item_branches","item_branches","item_circlet","item_slippers","item_boots","item_wind_lace","item_tranquil_boots","item_wraith_band","item_headdress","item_chainmail","item_mekansm","item_magic_wand","item_vanguard","item_helm_of_iron_will","item_crimson_guard","item_staff_of_wizardry","item_fluffy_hat","item_force_staff","item_boots","item_arcane_boots","item_buckler","item_guardian_greaves","item_aghanims_shard","item_buckler","item_ring_of_basilius","item_vladmir","item_wraith_pact","item_void_stone","item_ultimate_orb","item_gem","item_mystic_staff","item_sheepstick","item_ghost","item_ethereal_blade",
	},
	{ {3,3,3,3,2,}, {3,3,3,3,2,}, 0.1 },
	{
		"Venomous Gale","Poison Sting","Plague Ward","Latent Toxicity","Poison Nova","-5s Venomous Gale CD","+20% Poison Sting Health Regen Reduction","-1.0s Plague Ward Cooldown","-8% Poison Sting Slow","+5.0s Poison Nova Duration","Gale Creates Plague Wards","Poison Nova reduces +100 Attack Speed","2.5x Plague Ward HP/Damage",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"venomancer_venomous_gale", ABILITY_TYPE.NUKE + ABILITY_TYPE.SLOW + ABILITY_TYPE.AOE},
		{"venomancer_poison_sting", ABILITY_TYPE.PASSIVE},
		{"venomancer_plague_ward", ABILITY_TYPE.SUMMON},
		[5] = {"venomancer_poison_nova", ABILITY_TYPE.NUKE + ABILITY_TYPE.AOE},
}

local ZEROED_VECTOR = ZEROED_VECTOR
local playerRadius = Set_GetEnemyHeroesInPlayerRadius
local ENCASED_IN_RECT = Set_GetEnemiesInRectangle
local currentTask = Task_GetCurrentTaskHandle
local GSI_AbilityCanBeCast = GSI_AbilityCanBeCast
local USE_ABILITY = UseAbility_RegisterAbilityUseAndLockToScore
local VEC_UNIT_DIRECTIONAL = Vector_UnitDirectionalPointToPoint
local ACTIVITY_TYPE = ACTIVITY_TYPE
local currentActivityType = Blueprint_GetCurrentTaskActivityType

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
		if AbilityLogic_PlaceholderGenericAbilityUse(gsiPlayer, t_player_abilities) then
			return
		elseif false then -- TODO generic item use (probably can use same func for finished heroes)

		end
	end,
}

local hero_access = function(key) return d[key] end

do
	HeroData_SetHeroData(hero_data, abilities, hero_access)
end

