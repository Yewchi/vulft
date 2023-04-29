local hero_data = {
	"pangolier",
	{2, 1, 2, 1, 1, 4, 1, 2, 2, 3, 6, 4, 3, 3, 7, 3, 4, 9, 12},
	{
		"item_tango","item_faerie_fire","item_quelling_blade","item_branches","item_ward_observer","item_branches","item_bottle","item_blight_stone","item_orb_of_venom","item_orb_of_corrosion","item_boots","item_arcane_boots","item_magic_wand","item_blade_of_alacrity","item_robe","item_diffusal_blade_2","item_javelin","item_mithril_hammer","item_maelstrom","item_cornucopia","item_ultimate_orb","item_sphere","item_point_booster","item_staff_of_wizardry","item_ogre_axe","item_ultimate_scepter","item_blink","item_rod_of_atos","item_gungir","item_ultimate_scepter_2","item_pers","item_octarine_core","item_aghanims_shard",
	},
	{ {2,2,2,2,2,}, {2,2,2,2,4,}, 0.1 },
	{
		"Swashbuckle","Shield Crash","Lucky Shot","Rolling Thunder","+3 Lucky Shot Armor Reduction","+350 Swashbuckle Slash Range","+3.0s Shield Crash CD in Ball","+3.0s Rolling Thunder Duration","+25 Swashbuckle Damage","+5% Shield Crash Reduction Per Hero","-3.0s Swashbuckle Cooldown","-18.0s Rolling Thunder Cooldown",
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
