local hero_data = {
	"sven",
	{1, 3, 1, 2, 2, 4, 2, 2, 1, 6, 1, 4, 3, 3, 7, 3, 4, 10, 11},
	{
		"item_quelling_blade","item_magic_stick","item_tango","item_branches","item_faerie_fire","item_branches","item_belt_of_strength","item_gloves","item_power_treads","item_lifesteal","item_mask_of_madness","item_quarterstaff","item_robe","item_echo_sabre","item_blink","item_mithril_hammer","item_ogre_axe","item_black_king_bar","item_lesser_crit","item_greater_crit","item_eagle","item_swift_blink","item_claymore","item_satanic","item_helm_of_iron_will","item_nullifier","item_blitz_knuckles","item_claymore","item_cloak","item_void_stone","item_bloodthorn",
	},
	{ {1,1,1,1,3,}, {1,1,1,1,4,}, 0.1 },
	{
		"Storm Hammer","Great Cleave","Warcry","God's Strength","+3.0s Warcry Duration","+15 Attack Speed","-15s God's Strength Cooldown","+25% Great Cleave Damage","+8% Warcry Movement Speed","+10 Warcry Armor","+50% God's Strength Damage","+1.25s Storm Hammer Stun Duration",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"sven_storm_bolt", ABILITY_TYPE.NUKE + ABILITY_TYPE.STUN + ABILITY_TYPE.AOE},
		{"sven_great_cleave", ABILITY_TYPE.PASSIVE},
		{"sven_warcry", ABILITY_TYPE.MOBILITY + ABILITY_TYPE.BUFF + ABILITY_TYPE.HEAL},
		[5] = {"sven_gods_strength", ABILITY_TYPE.ATTACK_MODIFIER + ABILITY_TYPE.BUFF},
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


