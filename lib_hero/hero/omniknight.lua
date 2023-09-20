local hero_data = {
	"omniknight",
	{3, 1, 3, 1, 1, 3, 1, 2, 3, 6, 4, 4, 2, 2, 8, 2, 4, 10, 11},
	{
		"item_gauntlets","item_circlet","item_quelling_blade","item_tango","item_branches","item_branches","item_gauntlets","item_ring_of_health","item_soul_ring","item_boots","item_vanguard","item_magic_wand","item_blades_of_attack","item_phase_boots","item_aghanims_shard","item_helm_of_iron_will","item_crimson_guard","item_ogre_axe","item_robe","item_quarterstaff","item_echo_sabre","item_diadem","item_harpoon","item_ogre_axe","item_belt_of_strength","item_sange","item_heavens_halberd","item_basher",
	},
	{ {3,3,3,3,1,}, {3,3,3,3,5,}, 0.1 },
	{
		"Purification","Repel","Hammer of Purity","Guardian Angel","-2.0s Purification Cooldown","+50 Base Damage","+3 Repel Strength/HP Regen per Debuff","-30.0s Guardian Angel Cooldown","+2s Repel Duration","-6s Hammer of Purity Cooldown","+160 Purification Damage/Heal","+75% Hammer of Purity Damage",
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
