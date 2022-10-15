local hero_data = {
	"windrunner",
	{3, 1, 2, 1, 2, 4, 1, 3, 3, 1, 3, 4, 2, 2, 7, 6, 4, 9, 12},
	{
		"item_faerie_fire","item_branches","item_branches","item_branches","item_tango","item_bottle","item_gloves","item_robe","item_power_treads","item_javelin","item_magic_wand","item_maelstrom","item_mithril_hammer","item_ogre_axe","item_black_king_bar","item_blink","item_lesser_crit","item_demon_edge","item_greater_crit","item_boots","item_ultimate_scepter","item_ultimate_orb","item_pers","item_sphere","item_ultimate_scepter_2","item_octarine_core",
	},
	{ {2,2,2,3,3,}, {2,2,2,4,4,}, 0.1 },
	{
		"Shackleshot","Powershot","Windrun","Focus Fire","+200 Windrun Radius","-2.0s Shackleshot Cooldown","-3s Windrun Cooldown","-15% Powershot Damage Reduction","+0.8s Shackleshot Duration","-16% Focus Fire Damage Reduction","Windrun Cannot Be Dispelled","Focus Fire Kills Advance Cooldown by 20s.",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"windrunner_shackleshot", ABILITY_TYPE.STUN},
		{"windrunner_powershot", ABILITY_TYPE.NUKE},
		{"windrunner_windrun", ABILITY_TYPE.MOBILITY + ABILITY_TYPE.BUFF + ABILITY_TYPE.SHIELD},
		[5] = {"windrunner_focusfire", ABILITY_TYPE.NUKE},
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
		-- TODO nb. the only time that heroes need HighUse mana admustments after update is when they have
		-- strange utility spells, or spells which are intentionally not balanced to their cost for this or
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
