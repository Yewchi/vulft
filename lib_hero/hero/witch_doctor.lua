local hero_data = {
	"witch_doctor",
	{1, 3, 3, 1, 3, 4, 3, 2, 1, 6, 1, 4, 2, 2, 2, 7, 4, 9, 11},
	{
		"item_magic_stick","item_tango","item_enchanted_mango","item_enchanted_mango","item_enchanted_mango","item_tango","item_ward_sentry","item_ward_sentry","item_flask","item_boots","item_energy_booster","item_arcane_boots","item_magic_wand","item_aghanims_shard","item_ghost","item_platemail","item_pers","item_lotus_orb","item_glimmer_cape","item_gem","item_ultimate_scepter","item_gem",
	},
	{ {1,1,1,3,4,}, {5,5,5,5,4,}, 0.1 },
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


