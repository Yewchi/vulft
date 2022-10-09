local hero_data = {
	"life_stealer",
	{2, 3, 3, 1, 3, 4, 3, 2, 1, 5, 1, 4, 1, 2, 7, 2, 4, 9, 12},
	{
		"item_quelling_blade","item_tango","item_circlet","item_gauntlets","item_branches","item_branches","item_tango","item_circlet","item_gauntlets","item_branches","item_branches","item_bracer","item_orb_of_venom","item_boots","item_chainmail","item_magic_wand","item_phase_boots","item_blades_of_attack","item_helm_of_iron_will","item_gloves","item_armlet","item_relic","item_radiance","item_reaver","item_claymore","item_satanic","item_sange","item_sange_and_yasha","item_gem",
	},
	{ {1,1,1,1,1,}, {1,1,1,1,1,}, 0.1 },
	{
		"Rage","Feast","Ghoul Frenzy","Infest","+30 Attack Speed","+10% Rage Move Speed","+25 Damage","+325 Health","16% Evasion","+10% Ghoul Frenzy Slow","+1.2% Feast Lifesteal","+1.5s Rage Duration",
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
