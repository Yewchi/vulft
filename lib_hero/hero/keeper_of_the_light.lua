local hero_data = {
	"keeper_of_the_light",
	{1, 3, 1, 3, 1, 4, 1, 3, 3, 2, 6, 4, 2, 2, 7, 2, 4, 9, 12},
	{
		"item_circlet","item_tango","item_quelling_blade","item_faerie_fire","item_branches","item_ward_observer","item_boots","item_urn_of_shadows","item_crown","item_fluffy_hat","item_spirit_vessel","item_staff_of_wizardry","item_robe","item_kaya","item_ghost","item_ethereal_blade","item_ultimate_orb","item_mystic_staff","item_sheepstick","item_ogre_axe","item_black_king_bar","item_diadem","item_voodoo_mask","item_dagon_5","item_dagon_3L","item_dagon_5L","item_octarine_core","item_staff_of_wizardry","item_ogre_axe","item_blade_of_alacrity","item_point_booster","item_ultimate_scepter_2",
	},
	{ {2,2,2,2,3,}, {2,2,2,2,4,}, 0.1 },
	{
		"Illuminate","Blinding Light","Chakra Magic","Spirit Form","+30% Blinding Light Miss","-2s Illuminate Cooldown","-3s Chakra Magic Cooldown","2 Solar Bind Charges","+15.0s Spirit Form Duration","Chakra Magic Dispels","+1.2s Blinding Light Stun","+180 Illuminate Damage",
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
