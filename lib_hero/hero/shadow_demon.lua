local hero_data = {
	"shadow_demon",
	{1, 3, 3, 1, 3, 4, 3, 1, 1, 5, 2, 4, 2, 2, 8, 2, 4, 10},
	{
		"item_sobi_mask","item_branches","item_branches","item_tango","item_branches","item_clarity","item_ward_dispenser","item_wind_lace","item_magic_wand","item_tranquil_boots","item_void_stone","item_energy_booster","item_aether_lens","item_aghanims_shard","item_fluffy_hat","item_staff_of_wizardry","item_force_staff","item_mystic_staff","item_ultimate_orb","item_void_stone","item_sheepstick",
	},
	{ {3,3,3,3,3,}, {4,4,4,4,4,}, 0.1 },
	{
		"Disruption","Disseminate","Shadow Poison","Demonic Purge","+15.0% Shadow Poison Damage","+12 Strength","+25 Movement Speed","+200 Demonic Purge Damage","+10% Disseminate Shared Damage","-1.25s Shadow Poison Cooldown","-30.0s Demonic Purge Cooldown","2 Charges of Disruption",
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
