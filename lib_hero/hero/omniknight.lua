local hero_data = {
	"omniknight",
	{3, 2, 1, 1, 1, 4, 1, 2, 2, 2, 5, 4, 3, 3, 8, 3, 4, 9, 11},
	{
		"item_blood_grenade","item_enchanted_mango","item_tango","item_branches","item_branches","item_magic_stick","item_ward_sentry","item_ward_sentry","item_tango","item_boots","item_magic_wand","item_arcane_boots","item_energy_booster","item_void_stone","item_aether_lens","item_cloak","item_shadow_amulet","item_glimmer_cape","item_force_staff","item_point_booster","item_ultimate_scepter","item_mekansm","item_buckler","item_guardian_greaves",
	},
	{ {3,3,5,1,1,}, {4,4,4,5,5,}, 0.1 },
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
