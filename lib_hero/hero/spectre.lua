local hero_data = {
	"spectre",
	{1, 3, 1, 3, 3, 4, 1, 1, 3, 6, 2, 4, 2, 2, 8, 2, 4, 10, 11},
	{
		"item_branches","item_slippers","item_tango","item_quelling_blade","item_branches","item_circlet","item_wraith_band","item_magic_wand","item_boots","item_gloves","item_boots_of_elves","item_power_treads","item_oblivion_staff","item_echo_sabre","item_blade_of_alacrity","item_staff_of_wizardry","item_ultimate_scepter","item_cloak","item_mage_slayer","item_yasha","item_ultimate_orb","item_manta","item_mithril_hammer","item_basher","item_butterfly","item_abyssal_blade","item_blitz_knuckles","item_claymore","item_bloodthorn","item_ultimate_scepter_2","item_moon_shard","item_refresher",
	},
	{ {1,1,1,1,1,}, {1,1,1,1,1,}, 0.1 },
	{
		"Spectral Dagger","Desolate","Dispersion","Haunt","-4s Spectral Dagger Cooldown","+5 All Stats","+12 Desolate Damage","+100 Spectral Dagger Damage","+350 Health","+12% Spectral Dagger Slow/Bonus","+32% Haunt Illusion Damage","+5% Dispersion",
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
