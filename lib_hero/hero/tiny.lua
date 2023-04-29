local hero_data = {
	"tiny",
	{3, 1, 2, 1, 1, 4, 1, 2, 2, 2, 6, 4, 3, 12, 8, 3, 4, 10},
	{
		"item_ward_observer","item_branches","item_faerie_fire","item_quelling_blade","item_tango","item_bottle","item_boots","item_chainmail","item_blades_of_attack","item_wind_lace","item_phase_boots","item_blink","item_oblivion_staff","item_echo_sabre","item_blades_of_attack","item_lesser_crit","item_point_booster","item_ultimate_scepter","item_echo_sabre","item_aghanims_shard","item_greater_crit","item_hyperstone","item_assault","item_swift_blink","item_ultimate_scepter_2","item_blitz_knuckles",
	},
	{ {3,3,2,5,2,}, {4,4,4,2,2,}, 0.1 },
	{
		"Avalanche","Toss","Tree Grab","Grow","+20 Movement Speed","+10 Strength","+10% Status Resistance","+80 Avalanche Damage","+40% Grow Bonus Damage With Tree","Toss Requires No Target","-8s Avalanche Cooldown","2 Toss Charges",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"tiny_avalanche", ABILITY_TYPE.NUKE + ABILITY_TYPE.STUN + ABILITY_TYPE.AOE},
		{"tiny_toss", ABILITY_TYPE.NUKE},
		{"tiny_tree_grab", ABILITY_TYPE.ATTACK_MODIFIER},
		--don't teach generic grab {"tiny_tree_throw", ABILITY_TYPE.NUKE + ABILITY_TYPE.SLOW + ABILITY_TYPE.AOE},
		[5] = {"tiny_grow", ABILITY_TYPE.PASSIVE},
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
		-- Any spell immune unit cannot be tossed
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
