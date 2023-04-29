local hero_data = {
	"shredder",
	{1, 3, 3, 2, 5, 4, 2, 2, 2, 1, 1, 4, 1, 3, 7, 3, 4, 9, 11},
	{
		"item_gauntlets","item_gauntlets","item_gauntlets","item_quelling_blade","item_branches","item_branches","item_tango","item_ring_of_health","item_boots","item_arcane_boots","item_soul_ring","item_vanguard","item_magic_wand","item_robe","item_kaya","item_belt_of_strength","item_sange","item_kaya_and_sange","item_aghanims_shard","item_point_booster","item_ogre_axe","item_staff_of_wizardry","item_ultimate_scepter","item_platemail","item_helm_of_iron_will","item_crimson_guard","item_shivas_guard","item_mekansm","item_buckler","item_guardian_greaves","item_gem","item_blink","item_octarine_core","item_ultimate_scepter_2",
	},
	{ {2,2,3,3,3,}, {2,2,1,5,3,}, 0.1 },
	{
		"Whirling Death","Timber Chain","Reactive Armor","Chakram","+200 Health","+1.5 Mana Regen","+8% Spell Amplification","+6 Reactive Armor Stacks and Duration","+20% Magic Resistance","+4% Chakram Slow","Second Chakram","+1125 Timber Chain Range",
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
