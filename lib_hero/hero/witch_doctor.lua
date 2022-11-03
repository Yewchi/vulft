local hero_data = {
	"witch_doctor",
	{1, 3, 3, 1, 3, 4, 3, 1, 1, 6, 2, 4, 2, 2, 7, 2, 4, 10, 11},
	{
		"item_ward_sentry","item_branches","item_circlet","item_branches","item_tango","item_tango","item_enchanted_mango","item_boots","item_urn_of_shadows","item_magic_wand","item_energy_booster","item_arcane_boots","item_aghanims_shard","item_cloak","item_shadow_amulet","item_glimmer_cape","item_spirit_vessel","item_void_stone","item_aether_lens","item_point_booster","item_octarine_core",
	},
	{ {1,1,1,1,3,}, {5,5,5,5,4,}, 0.1 },
	{
		"Paralyzing Cask","Voodoo Restoration","Maledict","Death Ward","-25% Voodoo Restoration Mana Per Second","+75 Maledict AoE","+2 Cask Bounces","+300 Health","+100 Death Ward Attack Range","+20% Maledict Burst Damage","+1.5% Max Health Voodoo Restoration Heal/Damage","+60 Death Ward Damage",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"witch_doctor_paralyzing_cask", ABILITY_TYPE.NUKE + ABILITY_TYPE.STUN + ABILITY_TYPE.AOE},
		{"witch_doctor_voodoo_restoration", ABILITY_TYPE.HEAL + ABILITY_TYPE.AOE},
		{"witch_doctor_maledict", ABILITY_TYPE.NUKE},
		[5] = {"witch_doctor_death_ward", ABILITY_TYPE.NUKE + ABILITY_TYPE.AOE},
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


