local hero_data = {
	"centaur",
	{1, 2, 3, 2, 1, 5, 2, 1, 1, 3, 7, 5, 2, 3, 9, 3, 5, 11, 6, 13},
	{
		"item_tango","item_branches","item_quelling_blade","item_ring_of_protection","item_gauntlets","item_ring_of_health","item_crown","item_vanguard","item_ring_of_health","item_meteor_hammer","item_boots","item_magic_wand","item_wind_lace","item_tranquil_boots","item_blink","item_belt_of_strength","item_wind_lace","item_robe","item_ancient_janggo","item_boots_of_bearing","item_headdress","item_cloak","item_ring_of_health","item_pipe","item_crimson_guard","item_sheepstick","item_shivas_guard",
	},
	{ {3,3,3,3,4,}, {3,3,3,3,4,}, 0.1 },
	{
		"Hoof Stomp","Double Edge","Retaliate","Hitch A Ride","Stampede","+5 Health Regen","+20 Movement Speed","+15 Strength","+40% Double Edge Strength Damage","+45 Retaliate Damage","-25s Stampede Cooldown","Gains Retaliate Aura","+0.8s Hoof Stomp Duration",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"centaur_hoof_stomp", ABILITY_TYPE.NUKE + ABILITY_TYPE.STUN},
		{"centaur_double_edge", ABILITY_TYPE.NUKE},
		{"centaur_return", ABILITY_TYPE.PASSIVE},
		[5] = {"centaur_stampede", ABILITY_TYPE.MOBILITY + ABILITY_TYPE.SLOW},
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
