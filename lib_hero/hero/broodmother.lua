local hero_data = {
	"broodmother",
	{2, 3, 2, 1, 2, 4, 2, 3, 3, 3, 1, 4, 1, 1, 7, 6, 4, 10, 11},
	{
		"item_gauntlets","item_circlet","item_gauntlets","item_branches","item_tango","item_ward_observer","item_bracer","item_boots","item_soul_ring","item_gloves","item_belt_of_strength","item_power_treads","item_cornucopia","item_blitz_knuckles","item_orchid","item_quarterstaff","item_robe","item_ogre_axe","item_boots_of_elves","item_echo_sabre","item_blade_of_alacrity","item_yasha","item_manta","item_aghanims_shard","item_mage_slayer","item_bloodthorn","item_diadem","item_harpoon","item_helm_of_iron_will","item_nullifier","item_ultimate_orb","item_ultimate_orb","item_point_booster","item_skadi",
	},
	{ {2,2,2,2,3,}, {2,2,2,4,3,}, 0.1 },
	{
		"Insatiable Hunger","Spin Web","Silken Bola","Spawn Spiderlings","+80 Spawn Spiderlings Damage","+3 Spin Web Simultaneous Webs","-7s Spin Web Restore Time","+130 Spiderlings Health","+400 AoE Silken Bola","+35 Attack Speed","+0.3s BAT during Insatiable Hunger","+35% Silken Bola Slow/Miss Chance",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"template_hurt1", ABILITY_TYPE.NUKE},
		{"template_ouch", ABILITY_TYPE.NUKE},
		{"template_slow", ABILITY_TYPE.NUKE},
		[5] = {"template_big_slow", ABILITY_TYPE.NUKE},

}

local ZEROED_VECTOR = ZEROED_VECTOR
local playerRadius = Set_GetEnemyHeroesInPlayerRadius
local ENCASED_IN_RECT = Set_GetEnemiesInRectangle
local currentTask = Task_GetCurrentTaskHandle
local GSI_AbilityCanBeCast = GSI_AbilityCanBeCast
local CROWDED_RATING = Set_GetCrowdedRatingToSetTypeAtLocation
local USE_ABILITY = UseAbility_RegisterAbilityUseAndLockToScore
local INCENTIVISE = Task_IncentiviseTask
local VEC_UNIT_DIRECTIONAL = Vector_UnitDirectionalPointToPoint
local VEC_UNIT_FACING_DIRECTIONAL = Vector_UnitDirectionalFacingDirection
local ACTIVITY_TYPE = ACTIVITY_TYPE
local currentActivityType = Blueprint_GetCurrentTaskActivityType
local currentTask = Task_GetCurrentTaskHandle
local HIGH_USE = AbilityLogic_HighUseAllowOffensive
local min = math.min

local fight_harass_handle = FightHarass_GetTaskHandle()
local push_handle = Push_GetTaskHandle()

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
		AbilityLogic_UpdatePlayerAbilitiesIndex(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam], abilities)
	end,
	["AbilityThink"] = function(gsiPlayer)  
		if AbilityLogic_PlaceholderGenericAbilityUse(gsiPlayer, t_player_abilities) then
			return
		elseif false then

		end
	end,
}

local hero_access = function(key) return d[key] end

do
	HeroData_SetHeroData(hero_data, abilities, hero_access, true)
end
