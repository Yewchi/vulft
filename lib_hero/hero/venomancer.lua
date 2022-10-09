local hero_data = {
	"venomancer",
	{1, 2, 2, 3, 3, 3, 3, 2, 2, 1, 4, 4, 1, 1, 8, 5, 4, 9, 12},
	{
		"item_tango","item_circlet","item_circlet","item_branches","item_branches","item_faerie_fire","item_wraith_band","item_wraith_band","item_boots","item_wind_lace","item_magic_wand","item_gloves","item_boots_of_elves","item_power_treads","item_kaya","item_kaya_and_sange","item_dragon_lance","item_force_staff","item_hurricane_pike","item_ultimate_orb","item_ultimate_orb","item_point_booster","item_skadi",
	},
	{ {3,3,3,3,3,}, {3,3,3,3,3,}, 0.1 },
	{
		"Venomous Gale","Poison Sting","Plague Ward","Poison Nova","-6s Venomous Gale CD","+175 Health","12% Spell Lifesteal","-8% Poison Sting Slow","+5.0s Poison Nova Duration","-1.5s Plague Ward Cooldown","Poison Nova reduces +100 Attack Speed","2.5x Plague Ward HP/Damage",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"venomancer_venomous_gale", ABILITY_TYPE.NUKE + ABILITY_TYPE.SLOW + ABILITY_TYPE.AOE},
		{"venomancer_poison_sting", ABILITY_TYPE.PASSIVE},
		{"venomancer_plague_ward", ABILITY_TYPE.SUMMON},
		[5] = {"venomancer_poison_nova", ABILITY_TYPE.NUKE + ABILITY_TYPE.AOE},
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

