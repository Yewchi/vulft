local hero_data = {
	"skywrath_mage",
	{2, 1, 1, 3, 2, 4, 2, 3, 2, 6, 3, 4, 1, 1, 7, 3, 4, 10, 12},
	{
		"item_tango","item_blood_grenade","item_enchanted_mango","item_enchanted_mango","item_branches","item_ward_sentry","item_ward_sentry","item_tango","item_clarity","item_boots","item_arcane_boots","item_medallion_of_courage","item_wind_lace","item_solar_crest","item_void_stone","item_aether_lens","item_point_booster","item_staff_of_wizardry","item_ogre_axe","item_ultimate_scepter","item_ultimate_orb",
	},
	{ {5,5,5,3,3,}, {4,4,4,4,4,}, 0.1 },
	{
		"Arcane Bolt","Concussive Shot","Ancient Seal","Mystic Flare","+200 Health","+8 Intelligence","-7s Ancient Seal Cooldown","+25% Arcane Bolt Spell Lifesteal","Global Concussive Shot","-10% Ancient Seal Increased Magic Damage","Arcane Bolt Pierces Spell Immunity","+400 Mystic Flare Damage",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"skywrath_mage_arcane_bolt", ABILITY_TYPE.NUKE},
		{"skywrath_mage_concussive_shot", ABILITY_TYPE.NUKE + ABILITY_TYPE.SLOW},
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
