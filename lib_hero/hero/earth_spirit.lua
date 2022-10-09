local hero_data = {
	"earth_spirit",
	{1, 2, 1, 3, 1, 4, 1, 2, 2, 3, 5, 4, 3, 3, 8, 2, 4, 10, 12},
	{
		"item_quelling_blade","item_branches","item_branches","item_tango","item_faerie_fire","item_ward_dispenser","item_bottle","item_boots","item_bracer","item_kaya","item_kaya_and_sange","item_magic_wand","item_ogre_axe","item_mithril_hammer","item_black_king_bar","item_platemail","item_shivas_guard","item_gem","item_ultimate_orb","item_sheepstick","item_ring_of_health","item_sphere","item_desolator",
	},
	{ {3,3,3,2,5,}, {4,4,4,4,2,}, 0.1 },
	{
		"Boulder Smash","Rolling Boulder","Geomagnetic Grip","Magnetize","+325 Rolling Boulder Distance","+2.0s Magnetize Duration","+300.0 Boulder Smash Distance","+120 Rolling Boulder Damage","+18% Spell Amplification","+3.0s Geomagnetic Grip Silence","Geomagnetic Grip Targets Allies","+0.6s Rolling Boulder Stun Duration",
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


