local hero_data = {
	"jakiro",
	{1, 3, 1, 2, 1, 4, 1, 2, 2, 6, 2, 4, 3, 3, 7, 3, 4, 10, 11},
	{
		"item_magic_stick","item_enchanted_mango","item_tango","item_ward_dispenser","item_branches","item_branches","item_ring_of_basilius","item_magic_wand","item_boots","item_crown","item_veil_of_discord","item_energy_booster","item_arcane_boots","item_void_stone","item_aether_lens","item_fluffy_hat","item_staff_of_wizardry","item_force_staff","item_vladmir","item_wraith_pact","item_gem","item_gem","item_aghanims_shard",
	},
	{ {1,1,1,1,3,}, {5,5,5,5,4,}, 0.1 },
	{
		"Dual Breath","Ice Path","Liquid Fire","Macropyre","+275 Attack Range","-10%/-10 Dual Breath Movement/Attack Speed Slow","-50 Liquid Fire Attack Speed","+325 Health","+0.5s Ice Path Duration","+30 Macropyre Damage","+100%% Dual Breath Damage and Range","-2.5s Ice Path Cooldown",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
	[0] = {"jakiro_dual_breath", ABILITY_TYPE.DEGEN + ABILITY_TYPE.AOE + ABILITY_TYPE.SLOW + ABILITY_TYPE.NUKE},
		{"jakiro_ice_path", ABILITY_TYPE.NUKE + ABILITY_TYPE.STUN + ABILITY_TYPE.AOE},
		{"jakiro_liquid_fire", ABILITY_TYPE.AOE + ABILITY_TYPE.ATTACK_MODIFIER},
		{"jakiro_liquid_ice", ABILITY_TYPE.NUKE + ABILITY_TYPE.SLOW + ABILITY_TYPE.AOE + ABILITY_TYPE.STUN + ABILITY_TYPE.ATTACK_MODIFIER},
		[5] = {"jakiro_macropyre", ABILITY_TYPE.NUKE + ABILITY_TYPE.AOE},
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
