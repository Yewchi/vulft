local hero_data = {
	"clinkz",
	{2, 1, 2, 1, 2, 4, 1, 1, 3, 2, 3, 4, 6, 3, 7, 3, 4, 10, 11},
	{
		"item_blight_stone","item_tango","item_branches","item_branches","item_branches","item_branches","item_blades_of_attack","item_falcon_blade","item_boots","item_gloves","item_boots_of_elves","item_power_treads","item_mithril_hammer","item_desolator","item_magic_wand","item_aghanims_shard","item_blade_of_alacrity","item_belt_of_strength","item_dragon_lance","item_staff_of_wizardry","item_fluffy_hat","item_hurricane_pike","item_mithril_hammer","item_ogre_axe","item_black_king_bar","item_eagle","item_butterfly","item_skadi",
	},
	{ {1,1,1,1,1,}, {1,1,1,1,1,}, 0.1 },
	{
		"Burning Barrage","Searing Arrows","Skeleton Walk","Death Pact","+20 Searing Arrows Damage","-3.0s Skeleton Walk Cooldown","+20% Death Pact Health","Death Pact Steal creep abilities","+125 Attack Range","+3.0 Burning Barrage arrows","+25% Burning Barrage Damage","Searing Arrows Multishot",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"clinkz_strafe", ABILITY_TYPE.NUKE},
		{"clinkz_searing_arrows", ABILITY_TYPE.ATTACK_MODIFIER},
		{"clinkz_wind_walk", ABILITY_TYPE.INVIS + ABILITY_TYPE.MOBILITY},
		[5] = {"clinkz_death_pact", ABILITY_TYPE.UTILITY + ABILITY_TYPE.ATTACK_MODIFIER},
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
