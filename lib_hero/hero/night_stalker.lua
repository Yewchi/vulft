local hero_data = {
	"night_stalker",
	{1, 3, 1, 3, 1, 4, 1, 2, 3, 6, 3, 4, 2, 2, 7, 2, 4, 10, 12},
	{
		"item_gauntlets","item_quelling_blade","item_branches","item_magic_stick","item_tango","item_enchanted_mango","item_boots","item_bracer","item_chainmail","item_phase_boots","item_wind_lace","item_magic_wand","item_point_booster","item_staff_of_wizardry","item_ogre_axe","item_ultimate_scepter","item_aghanims_shard","item_blink","item_mithril_hammer","item_ogre_axe","item_black_king_bar","item_soul_booster","item_energy_booster","item_void_stone","item_octarine_core","item_sheepstick","item_javelin","item_blitz_knuckles","item_demon_edge","item_monkey_king_bar","item_ultimate_scepter_2","item_overwhelming_blink",
	},
	{ {3,3,3,3,3,}, {3,3,3,3,3,}, 0.1 },
	{
		"Void","Crippling Fear","Hunter in the Night","Dark Ascension","+50 Void Damage","+8s Dark Ascension Duration","+35 Dark Ascension Damage","+15% Hunter in the Night Status Resistance","-5.0s Crippling Fear Cooldown","+20 Strength","+100 Hunter In The Night Attack Speed","-50s Dark Ascension Cooldown",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"night_stalker_void", ABILITY_TYPE.NUKE + ABILITY_TYPE.STUN + ABILITY_TYPE.SLOW},
		{"night_stalker_crippling_fear", ABILITY_TYPE.DEGEN + ABILITY_TYPE.AOE},
		{"night_stalker_hunter_in_the_night", ABILITY_TYPE.PASSIVE},
		[5] = {"night_stalker_darkness", ABILITY_TYPE.BUFF + ABILITY_TYPE.MOBILITY},
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

local totalTimeTaken = 0
local runs = 0

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


