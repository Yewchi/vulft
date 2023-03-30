local hero_data = {
	"axe",
	{2, 3, 3, 1, 3, 4, 3, 1, 1, 1, 6, 4, 2, 2, 8, 2, 4, 9, 11},
	{
		"item_ring_of_protection","item_magic_stick","item_branches","item_branches","item_tango","item_ring_of_health","item_vitality_booster","item_vanguard","item_boots","item_blink","item_magic_wand","item_wind_lace","item_staff_of_wizardry","item_void_stone","item_cyclone","item_ogre_axe","item_chainmail","item_blades_of_attack","item_phase_boots","item_mithril_hammer","item_black_king_bar","item_blade_mail","item_kaya","item_ogre_axe","item_belt_of_strength","item_kaya_and_sange",
	},
	{ {3,3,3,3,3,}, {3,3,3,3,3,}, 0.1 },
	{
		"Berserker's Call","Battle Hunger","Counter Helix","Culling Blade","+8 Berserker's Call Armor","+12% Movement Speed per active Battle Hunger","-12% Battle Hunger Slow","+30 Counter Helix Damage","+150 Culling Blade Damage","+1 Bonus Armor per Culling Blade Stack","+100 Berserker's Call AoE","x2x Battle Hunger Armor Multiplier",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"axe_berserkers_call", ABILITY_TYPE.STUN},
		{"axe_battle_hunger", ABILITY_TYPE.SLOW + ABILITY_TYPE.NUKE},
		{"axe_counter_helix", ABILITY_TYPE.PASSIVE},
		[5] = {"axe_culling_blade", ABILITY_TYPE.UTILITY},

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
