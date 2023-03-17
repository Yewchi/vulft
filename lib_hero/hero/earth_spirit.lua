local hero_data = {
	"earth_spirit",
	{1, 2, 1, 2, 2, 4, 2, 1, 3, 3, 5, 4, 3, 3, 8, 1, 4, 9, 12},
	{
		"item_tango","item_ring_of_protection","item_circlet","item_sobi_mask","item_faerie_fire","item_ward_dispenser","item_clarity","item_urn_of_shadows","item_ring_of_basilius","item_crown","item_veil_of_discord","item_wind_lace","item_magic_wand","item_vitality_booster","item_spirit_vessel","item_platemail","item_lotus_orb","item_aether_lens","item_gem",
	},
	{ {3,3,3,3,5,}, {4,4,4,4,4,}, 0.1 },
	{
		"Boulder Smash","Rolling Boulder","Geomagnetic Grip","Magnetize","+325 Rolling Boulder Distance","+3s Magnetize Duration","+20 Magnetize Damage Per Second","+120 Rolling Boulder Damage","Geomagnetic Grip Targets Allies","+3.0s Geomagnetic Grip Silence","+25% Spell Amplification","+0.6s Rolling Boulder Stun Duration",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_HERO_SELECTION then return hero_data end

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


