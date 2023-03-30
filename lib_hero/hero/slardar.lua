local hero_data = {
	"slardar",
	{3, 2, 3, 1, 3, 4, 3, 1, 1, 1, 5, 4, 2, 2, 2, 7, 4, 10, 12},
	{
		"item_branches","item_circlet","item_quelling_blade","item_tango","item_gauntlets","item_branches","item_bracer","item_boots","item_gloves","item_power_treads","item_magic_wand","item_quarterstaff","item_robe","item_echo_sabre","item_blink","item_aghanims_shard","item_ogre_axe","item_mithril_hammer","item_black_king_bar","item_gem","item_point_booster","item_gem","item_staff_of_wizardry","item_ogre_axe","item_ultimate_scepter","item_platemail",
	},
	{ {3,3,3,3,2,}, {3,3,3,3,4,}, 0.1 },
	{
		"Guardian Sprint","Slithereen Crush","Bash of the Deep","Corrosive Haze","-3s Guardian Sprint Cooldown","+0.2s Slithereen Crush Stun Duration","+325 Health","+50 Bash of the Deep Damage","+150.0 Slithereen Crush Damage","-4 Corrosive Haze Armor","-4.0s Slithereen Crush Cooldown","Corrosive Haze Undispellable",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"slardar_sprint", ABILITY_TYPE.MOBILITY},
		{"slardar_slithereen_crush", ABILITY_TYPE.NUKE + ABILITY_TYPE.STUN + ABILITY_TYPE.AOE},
		{"slardar_bash", ABILITY_TYPE.PASSIVE},
		[5] = {"slardar_amplify_damage", ABILITY_TYPE.DEGEN + ABILITY_TYPE.UTILITY},
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
