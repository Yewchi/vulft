local hero_data = {
	"dark_willow",
	{1, 2, 1, 2, 1, 5, 2, 2, 1, 7, 3, 5, 3, 3, 4, 3, 5, 10, 12, 4, 4, 6},
	{
		"item_tango","item_circlet","item_circlet","item_branches","item_branches","item_blood_grenade","item_ward_observer","item_boots","item_magic_wand","item_tranquil_boots","item_wraith_band","item_gloves","item_hand_of_midas","item_blade_of_alacrity","item_ogre_axe","item_point_booster","item_ultimate_scepter","item_quarterstaff","item_mask_of_madness","item_hyperstone","item_moon_shard","item_gem","item_ancient_janggo","item_boots_of_bearing","item_javelin","item_blitz_knuckles","item_monkey_king_bar","item_black_king_bar","item_ultimate_scepter_2","item_reaver","item_satanic","item_gem",
	},
	{ {3,3,3,3,3,}, {4,4,4,4,3,}, 0.1 },
	{
		"Bramble Maze","Shadow Realm","Cursed Crown","Bedlam","Terrorize","+0.4s Cursed Crown Stun Duration","-2.0s Shadow Realm Cooldown","+30 Bedlam Damage","+160 Cursed Crown AoE","+2s Shadow Realm Duration","-7.0s Bramble Maze CD","+100 Attack Speed","+2 Bedlam Attack Targets",
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
