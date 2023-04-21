local hero_data = {
	"riki",
	{2, 1, 2, 3, 2, 4, 2, 3, 3, 3, 1, 4, 1, 1, 8, 5, 4, 10, 11},
	{
		"item_tango","item_quelling_blade","item_gauntlets","item_branches","item_branches","item_circlet","item_slippers","item_magic_wand","item_wraith_band","item_boots","item_boots_of_elves","item_power_treads","item_blade_of_alacrity","item_robe","item_diffusal_blade_2","item_blade_of_alacrity","item_yasha","item_manta","item_relic","item_nullifier","item_aghanims_shard","item_point_booster","item_ultimate_scepter","item_basher","item_abyssal_blade","item_ultimate_scepter_2","item_blink","item_swift_blink","item_greater_crit","item_rapier",
	},
	{ {1,1,1,2,3,}, {1,1,1,2,3,}, 0.1 },
	{
		"Smoke Screen","Blink Strike","Tricks of the Trade","Cloak and Dagger","+60 Smoke Screen Radius","+0.4s Blink Strike Slow","8% Cloak and Dagger Movement Speed","-4s Smoke Screen Cooldown","+0.5 Backstab Multiplier","-4s Blink Strike Replenish Time","-4 Tricks of the Trade Cooldown","Tricks of the Trade Applies a Basic Dispel",
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
