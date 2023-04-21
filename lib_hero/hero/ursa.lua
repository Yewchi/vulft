local hero_data = {
	"ursa",
	{3, 1, 3, 2, 3, 4, 3, 2, 2, 2, 5, 4, 1, 1, 7, 1, 4, 10, 12},
	{
		"item_branches","item_slippers","item_branches","item_tango","item_circlet","item_quelling_blade","item_wraith_band","item_boots","item_ring_of_health","item_chainmail","item_blades_of_attack","item_phase_boots","item_claymore","item_pers","item_broadsword","item_bfury","item_blink","item_mithril_hammer","item_ogre_axe","item_black_king_bar","item_mithril_hammer","item_belt_of_strength","item_basher","item_vanguard","item_abyssal_blade","item_lesser_crit","item_demon_edge","item_greater_crit","item_aghanims_shard","item_overwhelming_blink","item_moon_shard","item_blitz_knuckles",
	},
	{ {1,1,1,1,1,}, {1,1,1,1,1,}, 0.1 },
	{
		"Earthshock","Overpower","Fury Swipes","Enrage","+20s Fury Swipes Reset Time","+1.75 Mana Regen","Earthshock Applies +2 Fury Swipes","+10% Enrage Status Resistance","-2s Earthshock Cooldown","+12 Fury Swipes Damage","Enrage provides half benefits to allies in a +700 radius","+3 Overpower Attacks",
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
