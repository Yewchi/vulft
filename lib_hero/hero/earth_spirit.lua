local hero_data = {
	"earth_spirit",
	{1, 2, 1, 3, 1, 4, 2, 2, 2, 5, 3, 4, 3, 3, 8, 1, 4, 9, 11},
	{
		"item_tango","item_ring_of_protection","item_orb_of_venom","item_branches","item_branches","item_enchanted_mango","item_ward_dispenser","item_magic_wand","item_urn_of_shadows","item_boots","item_ogre_axe","item_mithril_hammer","item_black_king_bar","item_arcane_boots","item_pers","item_lotus_orb","item_point_booster","item_staff_of_wizardry","item_ogre_axe","item_ultimate_scepter",
	},
	{ {3,3,3,3,2,}, {4,4,4,4,2,}, 0.1 },
	{
		"Boulder Smash","Rolling Boulder","Geomagnetic Grip","Magnetize","+325 Rolling Boulder Distance","+2s Magnetize Duration","+20 Magnetize Damage Per Second","+120 Rolling Boulder Damage","Geomagnetic Grip Targets Allies","+3.0s Geomagnetic Grip Silence","+25% Spell Amplification","+0.6s Rolling Boulder Stun Duration",
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


