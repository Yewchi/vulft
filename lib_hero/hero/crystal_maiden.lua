local hero_data = {
	"crystal_maiden",
	{1, 2, 3, 2, 3, 4, 2, 2, 1, 5, 1, 4, 1, 3, 7, 3, 4, 10, 11},
	{
		"item_tango","item_enchanted_mango","item_ward_sentry","item_flask","item_clarity","item_branches","item_magic_wand","item_wind_lace","item_tranquil_boots","item_aghanims_shard","item_shadow_amulet","item_glimmer_cape","item_staff_of_wizardry","item_force_staff","item_gem","item_black_king_bar","item_blink","item_ghost","item_gem",
	},
	{ {1,1,1,1,1,}, {5,5,5,5,5,}, 0.1 },
	{
		"Crystal Nova","Frostbite","Arcane Aura","Freezing Field","+250 Health","+125 Crystal Nova AoE","+125 Frostbite Cast Range","-3s Crystal Nova Cooldown","+200 Attack Speed","+50 Freezing Field Damage","+1.25s Frostbite Duration","+240 Crystal Nova Damage",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"crystal_maiden_crystal_nova", ABILITY_TYPE.SLOW + ABILITY_TYPE.NUKE + ABILITY_TYPE.AOE + ABILITY_TYPE.POINT_TARGET},
		{"crystal_maiden_frostbite", ABILITY_TYPE.STUN + ABILITY_TYPE.NUKE + ABILITY_TYPE.UNIT_TARGET},
		{"crystal_maiden_brilliance_aura", ABILITY_TYPE.PASSIVE},
		[5] = {"crystal_maiden_freezing_field", ABILITY_TYPE.NUKE + ABILITY_TYPE.AOE + ABILITY_TYPE.SLOW},
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
