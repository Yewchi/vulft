local hero_data = {
	"earth_spirit",
	{1, 2, 1, 2, 1, 4, 2, 2, 1, 6, 3, 4, 3, 3, 8, 3, 4, 9, 11},
	{
		"item_tango","item_quelling_blade","item_branches","item_branches","item_branches","item_faerie_fire","item_ward_observer","item_boots","item_bottle","item_magic_wand","item_gloves","item_power_treads","item_chainmail","item_broadsword","item_blade_mail","item_reaver","item_heart","item_kaya","item_kaya_and_sange","item_void_stone","item_void_stone","item_vitality_booster","item_energy_booster","item_octarine_core","item_dagon_5","item_dagon_4L",
	},
	{ {2,2,2,2,5,}, {2,2,2,2,4,}, 0.1 },
	{
		"Boulder Smash","Rolling Boulder","Geomagnetic Grip","Magnetize","+325 Rolling Boulder Distance","+10% Spell Amplification","+30%% Magnetize Damage &amp; Duration","+120 Rolling Boulder Damage","+125 Boulder Smash Damage","-2s Geomagnetic Grip Cooldown","Magnetize Undispellable","+0.5s Rolling Boulder Stun Duration",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"earth_spirit_boulder_smash", ABILITY_TYPE.STUN + ABILITY_TYPE.AOE + ABILITY_TYPE.NUKE},
		{"earth_spirit_rolling_boulder", ABILITY_TYPE.STUN + ABILITY_TYPE.NUKE + ABILITY_TYPE.AOE + ABILITY_TYPE.MOBILITY},
		{"earth_spirit_geomagnetic_grip", ABILITY_TYPE.NUKE + ABILITY_TYPE.AOE},
		{"earth_spirit_stone_caller", ABILITY_TYPE.UTILITY},
		{"earth_spirit_petrify", ABILITY_TYPE.UTILITY},
		[5] = {"earth_spirit_magnetize", ABILITY_TYPE.NUKE + ABILITY_TYPE.AOE},
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


