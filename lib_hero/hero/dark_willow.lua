local hero_data = {
	"dark_willow",
	{1, 2, 2, 1, 2, 5, 2, 1, 1, 3, 7, 5, 3, 3, 9, 3, 5, 6, 11, 13},
	{
		"item_mantle","item_faerie_fire","item_tango","item_circlet","item_ward_observer","item_branches","item_branches","item_null_talisman","item_bottle","item_magic_wand","item_boots","item_crown","item_ring_of_basilius","item_veil_of_discord","item_blink","item_aghanims_shard","item_arcane_boots","item_mystic_staff","item_aeon_disk","item_void_stone","item_aether_lens","item_platemail","item_mystic_staff","item_shivas_guard","item_kaya","item_ethereal_blade","item_octarine_core","item_moon_shard","item_lesser_crit","item_demon_edge","item_greater_crit","item_ultimate_orb","item_ultimate_orb","item_skadi",
	},
	{ {3,3,3,2,5,}, {4,4,4,4,2,}, 0.1 },
	{
		"Bramble Maze","Shadow Realm","Cursed Crown","Bedlam","Terrorize","+0.5s Cursed Crown Stun Duration","-2.0s Shadow Realm Cooldown","+30 Bedlam Damage","+160 Cursed Crown AoE","+2s Shadow Realm Duration","-7.0s Bramble Maze CD","+100 Attack Speed","Bedlam Pierces Magic Immunity",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"template_hurt1", ABILITY_TYPE.NUKE},
		{"template_ouch", ABILITY_TYPE.NUKE},
		{"template_slow", ABILITY_TYPE.NUKE},
		[5] = {"template_big_slow", ABILITY_TYPE.NUKE},

}

local ZEROED_VECTOR = ZEROED_VECTOR
local playerRadius = Set_GetEnemyHeroesInPlayerRadius
local ENCASED_IN_RECT = Set_GetEnemiesInRectangle
local currentTask = Task_GetCurrentTaskHandle
local GSI_AbilityCanBeCast = GSI_AbilityCanBeCast
local CROWDED_RATING = Set_GetCrowdedRatingToSetTypeAtLocation
local USE_ABILITY = UseAbility_RegisterAbilityUseAndLockToScore
local INCENTIVISE = Task_IncentiviseTask
local VEC_UNIT_DIRECTIONAL = Vector_UnitDirectionalPointToPoint
local VEC_UNIT_FACING_DIRECTIONAL = Vector_UnitDirectionalFacingDirection
local ACTIVITY_TYPE = ACTIVITY_TYPE
local currentActivityType = Blueprint_GetCurrentTaskActivityType
local currentTask = Task_GetCurrentTaskHandle
local HIGH_USE = AbilityLogic_HighUseAllowOffensive
local min = math.min

local fight_harass_handle = FightHarass_GetTaskHandle()
local push_handle = Push_GetTaskHandle()

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
		elseif false then

		end
	end,
}

local hero_access = function(key) return d[key] end

do
	HeroData_SetHeroData(hero_data, abilities, hero_access, true)
end
