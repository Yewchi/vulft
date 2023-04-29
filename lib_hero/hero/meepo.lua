local hero_data = {
	"meepo",
	{2, 3, 2, 4, 2, 3, 2, 1, 3, 6, 4, 1, 1, 1, 3, 7, 4, 10, 12},
	{
		"item_slippers","item_branches","item_ward_observer","item_quelling_blade","item_slippers","item_slippers","item_tango","item_circlet","item_branches","item_branches","item_quelling_blade","item_circlet","item_boots","item_boots_of_elves","item_gloves","item_power_treads","item_dragon_lance","item_ogre_axe","item_staff_of_wizardry","item_ultimate_scepter","item_dragon_lance","item_dragon_lance","item_ultimate_orb","item_aghanims_shard","item_skadi","item_sange","item_yasha","item_sange_and_yasha","item_hurricane_pike","item_lesser_crit",
	},
	{ {2,2,2,2,5,}, {2,2,2,2,4,}, 0.1 },
	{
		"Earthbind","Poof","Ransack","Divided We Stand","+6 Strength","+30 Poof Damage","+15% Evasion","Earthbind grants True Strike on Targets","-3s Earthbind Cooldown","+8 Ransack Health Steal","Pack Rat","+1 Divided We Stand Clone",
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
