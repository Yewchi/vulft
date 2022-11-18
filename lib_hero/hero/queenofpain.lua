local hero_data = {
	"queenofpain",
	{1, 3, 1, 2, 1, 4, 3, 3, 3, 6, 2, 2, 2, 1, 8, 4, 4, 9, 11},
	{
		"item_tango","item_ward_observer","item_faerie_fire","item_branches","item_branches","item_branches","item_bottle","item_null_talisman","item_boots","item_blitz_knuckles","item_magic_wand","item_robe","item_chainmail","item_witch_blade","item_robe","item_power_treads","item_ogre_axe","item_mithril_hammer","item_black_king_bar","item_aghanims_shard","item_aether_lens","item_octarine_core","item_kaya","item_sange","item_kaya_and_sange","item_pers","item_refresher","item_mystic_staff","item_revenants_brooch","item_mystic_staff","item_ultimate_orb","item_sheepstick",
	},
	{ {2,2,2,2,2,}, {2,2,2,2,2,}, 0.1 },
	{
		"Shadow Strike","Blink","Scream Of Pain","Sonic Wave","+20 Damage","+11 Strength","-0.7s Shadow Strike Damage Interval","+30 Attack Speed","+120 Scream of Pain Damage","-60s Sonic Wave Cooldown","-2.0s Blink Cooldown","+200 Sonic Wave Damage",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"queenofpain_shadow_strike", ABILITY_TYPE.NUKE + ABILITY_TYPE.SLOW},
		{"queenofpain_blink", ABILITY_TYPE.MOBILITY},
		{"queenofpain_scream_of_pain", ABILITY_TYPE.NUKE + ABILITY_TYPE.AOE},
		[5] = {"queenofpain_sonic_wave", ABILITY_TYPE.NUKE + ABILITY_TYPE.AOE},
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


