local hero_data = {
	"primal_beast",
	{2, 1, 2, 1, 2, 4, 2, 1, 1, 5, 3, 4, 3, 3, 8, 3, 4, 9, 11},
	{
		"item_magic_stick","item_faerie_fire","item_quelling_blade","item_ward_observer","item_branches","item_branches","item_bottle","item_wind_lace","item_boots","item_chainmail","item_magic_wand","item_phase_boots","item_ogre_axe","item_mithril_hammer","item_black_king_bar","item_point_booster","item_ogre_axe","item_staff_of_wizardry","item_ultimate_scepter","item_sange","item_staff_of_wizardry","item_kaya_and_sange","item_blink","item_ultimate_orb","item_sheepstick","item_overwhelming_blink","item_pers","item_pers","item_refresher","item_ultimate_scepter_2",
	},
	{ {3,3,2,2,1,}, {3,3,2,2,5,}, 0.1 },
	{
		"Onslaught","Trample","Uproar","Pulverize","+90 Onslaught Damage","+20% Magic Resistance During Trample","-5s Trample Cooldown","Beast dispels himself when activating Uproar","+25% Trample Attack Multiplier","+4 Uproar Armor Per Stack","Pulverize Pierces Magic Immunity","+100%% Pulverize Duration",
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
