local hero_data = {
	"medusa",
	{2, 3, 2, 1, 2, 1, 2, 1, 1, 3, 4, 3, 3, 4, 7, 6, 4, 10, 12},
	{
		"item_enchanted_mango","item_sobi_mask","item_branches","item_branches","item_magic_stick","item_magic_wand","item_fluffy_hat","item_blades_of_attack","item_falcon_blade","item_gloves","item_boots","item_boots_of_elves","item_power_treads","item_blade_of_alacrity","item_yasha","item_manta","item_quarterstaff","item_eagle","item_butterfly","item_point_booster","item_ogre_axe","item_blade_of_alacrity","item_ultimate_scepter","item_aghanims_shard","item_blade_of_alacrity","item_belt_of_strength","item_dragon_lance","item_hurricane_pike","item_skadi","item_lesser_crit","item_ultimate_scepter_2","item_silver_edge","item_witch_blade","item_revenants_brooch","item_black_king_bar","item_relic","item_rapier","item_moon_shard",
	},
	{ {1,1,1,1,3,}, {1,1,1,1,3,}, 0.1 },
	{
		"Split Shot","Mystic Snake","Mana Shield","Stone Gaze","+15% Mystic Snake Turn and Movement Speed Slow","+5% Stone Gaze Bonus Physical Damage","+10% Split Shot Damage Penalty","-3s Mystic Snake Cooldown","+2 Mystic Snake Bounces","+1.5s Stone Gaze Duration","+0.9 Mana Shield Damage per Mana","Split Shot Uses Modifiers",
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
