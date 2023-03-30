local hero_data = {
	"clinkz",
	{2, 1, 2, 3, 1, 4, 1, 1, 3, 3, 3, 4, 6, 2, 7, 2, 4, 10, 11},
	{
		"item_blades_of_attack","item_branches","item_branches","item_sobi_mask","item_quelling_blade","item_branches","item_branches","item_tango","item_gloves","item_boots","item_boots_of_elves","item_javelin","item_power_treads","item_mithril_hammer","item_maelstrom","item_crown","item_crown","item_staff_of_wizardry","item_gungir","item_blade_of_alacrity","item_belt_of_strength","item_dragon_lance","item_blades_of_attack","item_broadsword","item_lesser_crit","item_greater_crit","item_void_stone","item_ultimate_orb","item_pers","item_ultimate_orb","item_hurricane_pike","item_sphere","item_black_king_bar",
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

local d
d = {
	["ReponseNeeds"] = function()
		return nil, REASPONSE_TYPE_DISPEL, nil, {RESPONSE_TYPE_KNOCKBACK, 4}
	end,
	["Initialize"] = function(gsiPlayer)
		AbilityLogic_CreatePlayerAbilitiesIndex(t_player_abilities, gsiPlayer, abilities)
		AbilityLogic_UpdateHighUseMana(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam])
		gsiPlayer.InformLevelUpSuccess = d.InformLevelUpSuccess
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
