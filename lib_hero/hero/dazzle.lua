local hero_data = {
	"dazzle",
	{1, 3, 1, 2, 1, 5, 1, 3, 2, 3, 3, 5, 2, 2, 8},
	{
		"item_tango","item_faerie_fire","item_branches","item_branches","item_ward_sentry","item_enchanted_mango","item_boots","item_magic_wand","item_arcane_boots","item_headdress","item_fluffy_hat","item_holy_locket","item_arcane_boots","item_aether_lens","item_aghanims_shard","item_staff_of_wizardry","item_fluffy_hat","item_force_staff",
	},
	{ {1,1,1,1,1,}, {5,5,5,5,5,}, 0.1 },
	{
		"Poison Touch","Shallow Grave","Shadow Wave","Good Juju","Bad Juju","+50 Damage","+1.75 Mana Regen","+45 Shadow Wave Heal / Damage","+350 Poison Touch Attack Range","+200 Heal On Shallow Grave End","+45 Poison Touch DPS","-40% Poison Touch Slow","+0.5 Bad Juju Armor Reduction",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"dazzle_poison_touch", ABILITY_TYPE.NUKE + ABILITY_TYPE.SLOW + ABILITY_TYPE.ATTACK_MODIFIER},
		{"dazzle_shallow_grave", ABILITY_TYPE.HEAL + ABILITY_TYPE.BUFF + ABILITY_TYPE.SHIELD},
		{"dazzle_shadow_wave", ABILITY_TYPE.HEAL + ABILITY_TYPE.NUKE},
		[5] = {"dazzle_bad_juju", ABILITY_TYPE.PASSIVE},
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


