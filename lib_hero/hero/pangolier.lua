local hero_data = {
	"pangolier",
	{1, 3, 1, 2, 1, 4, 1, 2, 2, 2, 6, 4, 3, 3, 7, 3, 4, 9, 12},
	{
		"item_branches","item_faerie_fire","item_quelling_blade","item_tango","item_ward_observer","item_branches","item_bottle","item_blight_stone","item_orb_of_venom","item_orb_of_corrosion","item_boots","item_arcane_boots","item_blade_of_alacrity","item_diffusal_blade_2","item_point_booster","item_staff_of_wizardry","item_ultimate_scepter","item_aghanims_shard","item_blink","item_void_stone","item_octarine_core","item_vitality_booster","item_energy_booster","item_basher","item_aeon_disk","item_overwhelming_blink","item_abyssal_blade","item_javelin","item_blitz_knuckles","item_ultimate_scepter_2","item_monkey_king_bar",
	},
	{ {2,2,2,2,3,}, {2,2,2,2,3,}, 0.1 },
	{
		"Swashbuckle","Shield Crash","Lucky Shot","Rolling Thunder","+3 Lucky Shot Armor Reduction","+400 Swashbuckle Slash Range","+3.0s Shield Crash CD in Ball","+3.0s Rolling Thunder Duration","+30 Swashbuckle Damage","+5% Shield Crash Reduction Per Hero","-3.0s Swashbuckle Cooldown","-20.0s Rolling Thunder Cooldown",
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
