local hero_data = {
	"oracle",
	{1, 3, 3, 2, 3, 4, 3, 2, 2, 1, 6, 4, 1, 2, 8, 1, 4, 9, 12},
	{
		"item_tango","item_branches","item_clarity","item_branches","item_wind_lace","item_ward_observer","item_magic_wand","item_boots","item_arcane_boots","item_void_stone","item_aether_lens","item_vitality_booster","item_aeon_disk","item_fluffy_hat","item_force_staff","item_void_stone","item_staff_of_wizardry","item_cyclone","item_mystic_staff","item_wind_waker","item_octarine_core","item_dragon_lance","item_hurricane_pike","item_point_booster","item_ultimate_scepter_2",
	},
	{ {1,1,1,5,2,}, {5,5,5,4,2,}, 0.1 },
	{
		"Fortune's End","Fate's Edict","Purifying Flames","False Promise","+0.5s Fortune's End Duration","+10 Armor False Promise","+80 Fortune's End Damage","-1.0s Purifying Flames Cooldown","-20s False Promise Cooldown","+30% Purifying Flames Enemy Damage","Instant Fortune's End","+1.5s False Promise Duration",
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


