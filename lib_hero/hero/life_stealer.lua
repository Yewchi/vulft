local hero_data = {
	"life_stealer",
	{2, 3, 1, 3, 3, 4, 3, 2, 2, 2, 1, 1, 4, 1, 8, 6, 4, 10, 12},
	{
		"item_quelling_blade","item_gauntlets","item_tango","item_branches","item_branches","item_gauntlets","item_blades_of_attack","item_boots","item_phase_boots","item_gloves","item_blades_of_attack","item_helm_of_iron_will","item_armlet","item_blitz_knuckles","item_javelin","item_monkey_king_bar","item_ultimate_orb","item_cornucopia","item_sphere","item_belt_of_strength","item_mithril_hammer","item_basher","item_hyperstone","item_gem","item_assault","item_aghanims_shard","item_abyssal_blade","item_point_booster","item_staff_of_wizardry","item_ogre_axe","item_blade_of_alacrity","item_ultimate_scepter",
	},
	{ {1,1,1,1,1,}, {1,1,1,1,1,}, 0.1 },
	{
		"Rage","Feast","Ghoul Frenzy","Infest","+150 Infest Damage","+12% Rage Movement Speed","+350 Health","+30 Damage","+15%% Infest Target Movespeed/Health","+15% Ghoul Frenzy Slow","+1.2% Feast Lifesteal and Damage","+1.5s Rage Duration",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"life_stealer_rage", ABILITY_TYPE.BUFF + ABILITY_TYPE.MOBILITY + ABILITY_TYPE.SHIELD},
		{"life_stealer_feast", ABILITY_TYPE.PASSIVE},
		{"life_stealer_open_wounds", ABILITY_TYPE.SLOW + ABILITY_TYPE.PASSIVE},
		[5] = {"life_stealer_infest", ABILITY_TYPE.SUMMON + ABILITY_TYPE.SHIELD},
}

local ZEROED_VECTOR = ZEROED_VECTOR
local playerRadius = Set_GetEnemyHeroesInPlayerRadius
local ENCASED_IN_RECT = Set_GetEnemiesInRectangle
local currentTask = Task_GetCurrentTaskHandle
local GSI_AbilityCanBeCast = GSI_AbilityCanBeCast
local USE_ABILITY = UseAbility_RegisterAbilityUseAndLockToScore
local VEC_UNIT_DIRECTIONAL = Vector_UnitDirectionalPointToPoint
local ACTIVITY_TYPE = ACTIVITY_TYPE
local currentActivityType = Blueprint_GetCurrentTaskActivityType

local fight_harass_handle = FightHarass_GetTaskHandle()

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
		elseif false then -- TODO generic item use (probably can use same func for finished heroes)

		end
	end,
}

local hero_access = function(key) return d[key] end

do
	HeroData_SetHeroData(hero_data, abilities, hero_access)
end
