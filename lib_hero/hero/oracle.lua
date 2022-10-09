local hero_data = {
	"oracle",
	{1, 3, 3, 2, 3, 5, 3, 2, 2, 2, 1, 5, 1, 1, 7, 6, 5, 10, 13},
	{
		"item_tango","item_flask","item_ward_sentry","item_magic_stick","item_branches","item_branches","item_magic_wand","item_boots","item_arcane_boots","item_shadow_amulet","item_cloak","item_glimmer_cape","item_void_stone","item_aether_lens","item_tranquil_boots","item_gem","item_blink","item_aghanims_shard","item_ghost","item_gem","item_gem","item_boots","item_gem","item_desolator",
	},
	{ {3,3,3,1,1,}, {4,4,4,5,5,}, 0.1 },
	{
		"Fortune's End","Fate's Edict","Purifying Flames","Rain of Destiny","False Promise","+0.4s Fortune's End Duration","+12 Intelligence","+15 Armor False Promise","-1.25s Purifying Flames Cooldown","-20.0s False Promise Cooldown","+30% Purifying Flames Enemy Damage","Instant Fortune's End","+1.5s False Promise Duration",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"oracle_fortunes_end", ABILITY_TYPE.NUKE + ABILITY_TYPE.DEGEN + ABILITY_TYPE.AOE},
		{"oracle_fates_edict", ABILITY_TYPE.SHIELD},
		{"oracle_purifying_flames", ABILITY_TYPE.HEAL + ABILITY_TYPE.NUKE},
		[5] = {"oracle_false_promise", ABILITY_TYPE.SHIELD + ABILITY_TYPE.HEAL},
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


