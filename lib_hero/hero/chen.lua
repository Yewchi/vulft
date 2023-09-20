local hero_data = {
	"chen",
	{1, 2, 2, 1, 2, 4, 2, 1, 1, 5, 3, 4, 3, 3, 7, 3, 4, 9},
	{
		"item_blood_grenade","item_circlet","item_branches","item_branches","item_branches","item_tango","item_ward_sentry","item_blight_stone","item_bracer","item_medallion_of_courage","item_magic_wand","item_diadem","item_headdress","item_holy_locket","item_belt_of_strength","item_robe","item_wind_lace","item_solar_crest","item_ancient_janggo","item_tranquil_boots","item_boots_of_bearing","item_buckler","item_ring_of_basilius","item_lifesteal","item_blades_of_attack","item_vladmir","item_gem","item_hyperstone","item_buckler","item_platemail","item_assault",
	},
	{ {1,1,1,1,3,}, {5,5,5,5,4,}, 0.1 },
	{
		"Penitence","Holy Persuasion","Divine Favor","Hand of God","Penitence Deals +225 Damage","-2s Holy Persuasion Teleport Delay","+12 Holy Persuasion Damage","-14% Penitence Slow","-30s Hand of God Cooldown","+1200 Holy Persuasion Minimum Health","Hand of God applies a Strong Dispel","+10/+10 Hand of God Heal/Heal Over Time",
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
