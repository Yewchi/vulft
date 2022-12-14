local hero_data = {
	"ogre_magi",
	{2, 1, 2, 1, 2, 4, 2, 3, 1, 5, 3, 4, 3, 3, 1, 8, 4, 10, 12},
	{
		"item_quelling_blade","item_tango","item_sobi_mask","item_circlet","item_enchanted_mango","item_urn_of_shadows","item_boots","item_arcane_boots","item_spirit_vessel","item_ring_of_basilius","item_crown","item_veil_of_discord","item_aether_lens","item_aghanims_shard","item_void_stone","item_mystic_staff","item_sheepstick","item_blink","item_vitality_booster","item_arcane_boots","item_aeon_disk","item_point_booster","item_ultimate_scepter","item_soul_booster","item_octarine_core",
	},
	{ {1,1,1,1,3,}, {5,5,5,5,3,}, 0.1 },
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
