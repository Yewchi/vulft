local hero_data = {
	"medusa",
	{2, 3, 2, 1, 2, 4, 2, 1, 1, 1, 3, 3, 4, 3, 7, 6, 4, 10, 12},
	{
		"item_quelling_blade","item_tango","item_slippers","item_magic_stick","item_circlet","item_branches","item_magic_wand","item_wraith_band","item_boots","item_boots_of_elves","item_gloves","item_power_treads","item_wind_lace","item_yasha","item_ultimate_orb","item_manta","item_blade_of_alacrity","item_staff_of_wizardry","item_ogre_axe","item_ultimate_scepter","item_aghanims_shard","item_blade_of_alacrity","item_belt_of_strength","item_dragon_lance","item_force_staff","item_hurricane_pike","item_point_booster","item_skadi","item_ultimate_scepter_2","item_black_king_bar","item_javelin","item_demon_edge","item_blitz_knuckles","item_monkey_king_bar","item_sphere","item_rapier","item_moon_shard","item_moon_shard",
	},
	{ {1,1,1,1,1,}, {1,1,1,1,1,}, 0.1 },
	{
		"Split Shot","Mystic Snake","Mana Shield","Stone Gaze","+15% Mystic Snake Turn and Movement Speed Slow","+0.5 Mana Shield Damage per Mana","+10% Split Shot Damage Penalty","-3s Mystic Snake Cooldown","+2 Mystic Snake Bounces","+2s Stone Gaze Duration","+75 Intelligence","Split Shot Uses Modifiers",
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
