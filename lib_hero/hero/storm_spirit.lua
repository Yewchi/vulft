local hero_data = {
	"storm_spirit",
	{1, 3, 1, 2, 1, 4, 1, 3, 3, 6, 3, 4, 2, 2, 8, 2, 4, 9, 11},
	{
		"item_faerie_fire","item_branches","item_tango","item_mantle","item_circlet","item_branches","item_ward_observer","item_bottle","item_null_talisman","item_null_talisman","item_gloves","item_boots","item_robe","item_blades_of_attack","item_power_treads","item_falcon_blade","item_blitz_knuckles","item_robe","item_chainmail","item_witch_blade","item_staff_of_wizardry","item_robe","item_kaya","item_mystic_staff","item_sheepstick","item_sange","item_kaya_and_sange","item_ultimate_orb","item_sphere","item_gem","item_ultimate_scepter_2","item_cornucopia","item_cornucopia","item_refresher","item_lesser_crit","item_greater_crit",
	},
	{ {2,2,2,2,5,}, {2,2,2,2,4,}, 0.1 },
	{
		"Static Remnant","Electric Vortex","Overload","Ball Lightning","+20 Attack Speed","+1.5 Mana Regen","+250 Health","+50 Static Remnant Damage","+0.3s Electric Vortex Duration","-1.25s Static Remnant Cooldown","2x Overload Attack Bounce","500.0 Distance Auto Remnant in Ball Lightning",
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
