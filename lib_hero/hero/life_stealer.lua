local hero_data = {
	"life_stealer",
	{2, 3, 1, 2, 3, 4, 2, 3, 3, 1, 1, 1, 4, 2, 7, 6, 4, 10, 12},
	{
		"item_quelling_blade","item_circlet","item_gauntlets","item_tango","item_branches","item_branches","item_blades_of_attack","item_boots","item_phase_boots","item_helm_of_iron_will","item_blades_of_attack","item_gloves","item_armlet","item_blight_stone","item_magic_wand","item_mithril_hammer","item_mithril_hammer","item_desolator","item_sange","item_heavens_halberd","item_mithril_hammer","item_basher","item_aghanims_shard","item_hyperstone","item_buckler","item_platemail","item_assault",
	},
	{ {1,1,1,1,1,}, {1,1,1,1,1,}, 0.1 },
	{
		"Rage","Feast","Ghoul Frenzy","Infest","+150 Infest Damage","+12% Rage Movement Speed","+325 Health","+25 Damage","+15%% Infest Target Movespeed/Health","+15% Ghoul Frenzy Slow","+1.2% Feast Lifesteal","+1.5s Rage Duration",
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

local d = {
	["ReponseNeeds"] = function()
		return nil, REASPONSE_TYPE_DISPEL, nil, {RESPONSE_TYPE_KNOCKBACK, 4}
	end,
	["Initialize"] = function(gsiPlayer)
		AbilityLogic_CreatePlayerAbilitiesIndex(t_player_abilities, gsiPlayer, abilities)
		AbilityLogic_UpdateHighUseMana(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam])
	end,
	["InformLevelUpSuccess"] = function(gsiPlayer)
		AbilityLogic_UpdateHighUseMana(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam])
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
