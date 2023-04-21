local hero_data = {
	"ogre_magi",
	{2, 1, 2, 1, 2, 4, 2, 3, 3, 3, 3, 4, 1, 1, 8, 5, 4, 10, 12},
	{
		"item_tango","item_magic_stick","item_enchanted_mango","item_branches","item_ward_sentry","item_ward_observer","item_ward_sentry","item_boots","item_gloves","item_hand_of_midas","item_magic_wand","item_arcane_boots","item_aether_lens","item_point_booster","item_vitality_booster","item_octarine_core","item_wind_lace","item_tranquil_boots","item_ancient_janggo",
	},
	{ {1,1,1,1,5,}, {5,5,5,5,4,}, 0.1 },
	{
		"Fireblast","Ignite","Bloodlust","Multicast","+16 Ignite DPS","-1.0s Fireblast Cooldown","+80 Damage","+250 Health","+30 Strength","+25 Bloodlust AS","17% Fireblast chance on attack","+240 Fireblast Damage",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"ogre_magi_fireblast", ABILITY_TYPE.NUKE + ABILITY_TYPE.STUN},
		{"ogre_magi_ignite", ABILITY_TYPE.NUKE + ABILITY_TYPE.SLOW},
		{"ogre_magi_bloodlust", ABILITY_TYPE.BUFF},
		{"ogre_magi_unrefined_fireblast", ABILITY_TYPE.NUKE + ABILITY_TYPE.STUN},
		{"ogre_magi_smash", ABILITY_TYPE.SHIELD},
		[5] = {"ogre_magi_multicast", ABILITY_TYPE.PASSIVE},
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
