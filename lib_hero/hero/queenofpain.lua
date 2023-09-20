local hero_data = {
	"queenofpain",
	{3, 1, 2, 2, 1, 4, 3, 3, 3, 6, 1, 4, 1, 2, 8, 2, 4, 9, 11},
	{
		"item_tango","item_faerie_fire","item_branches","item_branches","item_ward_observer","item_circlet","item_bottle","item_blades_of_attack","item_null_talisman","item_fluffy_hat","item_falcon_blade","item_gloves","item_robe","item_power_treads","item_blitz_knuckles","item_robe","item_chainmail","item_witch_blade","item_staff_of_wizardry","item_robe","item_kaya","item_ogre_axe","item_kaya_and_sange","item_staff_of_wizardry","item_ogre_axe","item_blade_of_alacrity","item_ultimate_scepter","item_ultimate_orb","item_sphere","item_aghanims_shard","item_shivas_guard","item_ultimate_scepter_2","item_orchid","item_bloodthorn",
	},
	{ {2,2,2,2,2,}, {2,2,2,2,2,}, 0.1 },
	{
		"Shadow Strike","Blink","Scream Of Pain","Sonic Wave","+15 Damage","+8 Strength","-0.7s Shadow Strike Damage Interval","+30 Attack Speed","+100 Scream of Pain Damage","-40s Sonic Wave Cooldown","-2.0s Blink Cooldown","+200 Sonic Wave Damage",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"queenofpain_shadow_strike", ABILITY_TYPE.NUKE + ABILITY_TYPE.SLOW},
		{"queenofpain_blink", ABILITY_TYPE.MOBILITY},
		{"queenofpain_scream_of_pain", ABILITY_TYPE.NUKE + ABILITY_TYPE.AOE},
		[5] = {"queenofpain_sonic_wave", ABILITY_TYPE.NUKE + ABILITY_TYPE.AOE},
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


