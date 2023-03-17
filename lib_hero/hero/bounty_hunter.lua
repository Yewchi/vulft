local hero_data = {
	"bounty_hunter",
	{2, 1, 2, 1, 2, 4, 2, 1, 1, 6, 3, 4, 3, 3, 7, 3, 4, 9, 11},
	{
		"item_ward_observer","item_quelling_blade","item_slippers","item_circlet","item_tango","item_branches","item_branches","item_blight_stone","item_boots","item_magic_wand","item_phase_boots","item_orb_of_corrosion","item_cloak","item_ring_of_health","item_hood_of_defiance","item_black_king_bar","item_yasha","item_gem","item_manta","item_skadi","item_boots","item_nullifier","item_gem","item_gem","item_gem","item_gem","item_gem","item_gem","item_gem","item_moon_shard",
	},
	{ {3,3,3,3,2,}, {4,4,4,3,3,}, 0.1 },
	{
		"Shuriken Toss","Jinada","Shadow Walk","Track","+10% Shadow Walk Slow","+40 Jinada Damage","+2s Silence on Hit With Shadow Walk","Half Track Bonus Speed to Allies","Track Grants 600 Ground Vision","+50 Jinada Gold Steal","2 Shuriken Toss Charges","+250 Track Gold",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_HERO_SELECTION then return hero_data end

local abilities = {
		[0] = {"bounty_hunter_shuriken_toss", ABILITY_TYPE.NUKE + ABILITY_TYPE.STUN},
		{"bounty_hunter_jinada", ABILITY_TYPE.ATTACK_MODIFIER},
		{"bounty_hunter_wind_walk", ABILITY_TYPE.NUKE + ABILITY_TYPE.INVIS},
		[5] = {"bounty_hunter_track", ABILITY_TYPE.DEGEN},
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


