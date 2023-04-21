local hero_data = {
	"magnataur",
	{1, 3, 1, 3, 1, 4, 2, 2, 2, 2, 5, 4, 3, 3, 8, 1, 4, 10, 12},
	{
		"item_gauntlets","item_tango","item_quelling_blade","item_enchanted_mango","item_circlet","item_branches","item_wraith_band","item_boots","item_arcane_boots","item_blink","item_void_stone","item_crown","item_meteor_hammer","item_staff_of_wizardry","item_fluffy_hat","item_buckler","item_mekansm","item_guardian_greaves","item_staff_of_wizardry","item_fluffy_hat","item_force_staff","item_aghanims_shard","item_void_stone","item_ring_of_health","item_ring_of_health","item_void_stone","item_pers","item_pers","item_gem","item_refresher","item_gem","item_arcane_blink",
	},
	{ {3,3,3,3,2,}, {3,3,3,3,2,}, 0.1 },
	{
		"Shockwave","Empower","Skewer","Reverse Polarity","+10s Empower Duration","+0.5s Shockwave Slow Duration","+16 Strength per hero hit with Reverse Polarity","-7.0s Skewer Cooldown","+125 Shockwave Damage","+375 Skewer Range","+10% Empower Damage/Cleave","+1s Reverse Polarity Stun Duration",
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
