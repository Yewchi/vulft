local hero_data = {
	"omniknight",
	{3, 1, 2, 1, 2, 4, 2, 2, 1, 1, 5, 4, 3, 3, 3, 8, 4, 9, 11},
	{
		"item_tango","item_flask","item_enchanted_mango","item_enchanted_mango","item_magic_stick","item_enchanted_mango","item_branches","item_boots","item_arcane_boots","item_magic_wand","item_void_stone","item_aether_lens","item_tranquil_boots","item_belt_of_strength","item_robe","item_ancient_janggo","item_headdress","item_chainmail","item_mekansm","item_boots_of_bearing","item_headdress","item_fluffy_hat","item_holy_locket","item_headdress","item_cloak","item_pipe","item_pers",
	},
	{ {1,1,1,5,5,}, {5,5,5,4,4,}, 0.1 },
	{
		"Purification","Heavenly Grace","Hammer of Purity","Guardian Angel","+4s Heavenly Grace Duration","+50 Base Damage","-2.0s Purification Cooldown","-30.0s Guardian Angel Cooldown","+3 Heavenly Grace Strength/HP Regen per Debuff","-6s Hammer of Purity Cooldown","+160 Purification Damage/Heal","+75% Hammer of Purity Damage",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"omniknight_purification", ABILITY_TYPE.NUKE + ABILITY_TYPE.HEAL},
		{"omniknight_repel", ABILITY_TYPE.SHIELD + ABILITY_TYPE.BUFF},
		{"omniknight_degen_aura", ABILITY_TYPE.PASSIVE},
		[5] = {"omniknight_guardian_angel", ABILITY_TYPE.SHIELD + ABILITY_TYPE.AOE},
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
