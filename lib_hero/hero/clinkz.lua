local hero_data = {
	"clinkz",
	{2, 3, 2, 1, 2, 6, 2, 3, 1, 7, 3, 6, 1, 1, 9, 3, 6, 12, 14},
	{
		"item_magic_stick","item_faerie_fire","item_branches","item_tango","item_branches","item_ward_observer","item_magic_wand","item_boots","item_blight_stone","item_medallion_of_courage","item_crown","item_wind_lace","item_tranquil_boots","item_solar_crest","item_diadem","item_phylactery","item_blitz_knuckles","item_staff_of_wizardry","item_orchid","item_cloak","item_oblivion_staff","item_bloodthorn","item_blight_stone","item_mithril_hammer","item_mithril_hammer","item_desolator","item_void_stone",
	},
	{ {2,2,2,3,3,}, {2,2,2,4,4,}, 0.1 },
	{
		"Strafe","Tar Bomb","Death Pact","Burning Army","Burning Barrage","Skeleton Walk","+15 Tar Bomb Bonus Attack Damage","-4s Skeleton Walk Cooldown","+75 Attack Range","+1 Death Pact Charge","+250 Death Pact Health","+40 Strafe Attack Speed","-8s Strafe Cooldown","Tar Bomb Multishot",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"clinkz_strafe", ABILITY_TYPE.NUKE},
		{"clinkz_searing_arrows", ABILITY_TYPE.ATTACK_MODIFIER},
		{"clinkz_wind_walk", ABILITY_TYPE.INVIS + ABILITY_TYPE.MOBILITY},
		[5] = {"clinkz_death_pact", ABILITY_TYPE.UTILITY + ABILITY_TYPE.ATTACK_MODIFIER},
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
