local hero_data = {
	"winter_wyvern",
	{1, 2, 2, 1, 2, 4, 2, 1, 1, 6, 3, 4, 3, 3, 8, 3, 4, 10, 12},
	{
		"item_ward_observer","item_circlet","item_mantle","item_tango","item_branches","item_branches","item_mantle","item_faerie_fire","item_null_talisman","item_null_talisman","item_boots","item_blitz_knuckles","item_robe","item_chainmail","item_witch_blade","item_staff_of_wizardry","item_ogre_axe","item_point_booster","item_ultimate_scepter","item_staff_of_wizardry","item_fluffy_hat","item_force_staff","item_hurricane_pike","item_revenants_brooch","item_rapier",
	},
	{ {2,2,1,3,3,}, {2,2,5,3,3,}, 0.1 },
	{
		"Arctic Burn","Splinter Blast","Cold Embrace","Winter's Curse","+25.0HP/s Cold Embrace Heal","+35 Damage","+2.0s Arctic Burn Debuff Duration","+400 Splinter Blast Shatter Radius","+12% Arctic Burn Slow","+100 Splinter Blast Damage","+1.5s Winter's Curse Duration","Splinter Blast 1.5s Stun",
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
