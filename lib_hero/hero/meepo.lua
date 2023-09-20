local hero_data = {
	"meepo",
	{2, 1, 3, 4, 2, 2, 2, 3, 3, 6, 4, 3, 1, 1, 7, 1, 4, 9, 12},
	{
		"item_slippers","item_branches","item_branches","item_tango","item_quelling_blade","item_ward_observer","item_branches","item_branches","item_tango","item_boots","item_boots_of_elves","item_gloves","item_power_treads","item_wraith_band","item_wraith_band","item_blade_of_alacrity","item_ogre_axe","item_staff_of_wizardry","item_ultimate_scepter","item_aghanims_shard","item_ultimate_orb","item_ultimate_orb","item_point_booster","item_skadi","item_blink","item_diffusal_blade_2","item_ultimate_orb","item_mystic_staff","item_sheepstick","item_eagle",
	},
	{ {2,2,2,2,1,}, {2,2,2,2,1,}, 0.1 },
	{
		"Earthbind","Poof","Ransack","Divided We Stand","+7 Strength","+30 Poof Damage","+15% Evasion","-2.5s Earthbind Cooldown","Earthbind grants True Strike on Targets","+8 Ransack Health Steal","Pack Rat","+1 Divided We Stand Clone",
	}
}
--@EndAutomatedHeroData
--[[ gsiPlayer.optFunc["illusion_determination"] = function(gsiPlayer, ...)
--		/*blah*/
--		trueHunit = closestLowestHealthScoredMeepo
--	end--]]
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
