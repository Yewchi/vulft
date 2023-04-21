local hero_data = {
	"spirit_breaker",
	{3, 1, 3, 1, 3, 4, 3, 1, 1, 5, 2, 4, 2, 2, 7, 2, 4, 10, 11},
	{
		"item_quelling_blade","item_branches","item_faerie_fire","item_tango","item_branches","item_ward_observer","item_ring_of_health","item_crown","item_meteor_hammer","item_boots","item_wind_lace","item_magic_wand","item_chainmail","item_blades_of_attack","item_phase_boots","item_blitz_knuckles","item_shadow_amulet","item_broadsword","item_invis_sword","item_ogre_axe","item_black_king_bar","item_kaya","item_yasha","item_yasha_and_kaya","item_staff_of_wizardry","item_cyclone","item_mystic_staff","item_wind_waker","item_ultimate_scepter","item_aghanims_shard","item_aghanims_shard","item_gem","item_ultimate_scepter_2","item_octarine_core",
	},
	{ {5,5,2,3,2,}, {4,4,4,2,2,}, 0.1 },
	{
		"Charge of Darkness","Bulldoze","Greater Bash","Nether Strike","+500 Night Vision","+4 Armor","-4.0s Bulldoze Cooldown","+40 Damage","+10% Greater Bash Chance","+175 Charge of Darkness Move Speed","+25% Greater Bash Damage","+800 Health",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"spirit_breaker_charge_of_darkness", ABILITY_TYPE.STUN + ABILITY_TYPE.SMITE},
		{"spirit_breaker_bulldoze", ABILITY_TYPE.MOBILITY + ABILITY_TYPE.SHIELD},
		{"spirit_breaker_greater_bash", ABILITY_TYPE.PASSIVE},
		[5] = {"spirit_breaker_nether_strike", ABILITY_TYPE.STUN},
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


