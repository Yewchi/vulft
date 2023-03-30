local hero_data = {
	"nevermore",
	{1, 2, 1, 2, 1, 2, 1, 2, 4, 6, 3, 4, 3, 3, 7, 3, 4, 9, 12},
	{
		"item_magic_stick","item_tango","item_enchanted_mango","item_enchanted_mango","item_branches","item_branches","item_branches","item_boots","item_gloves","item_boots_of_elves","item_power_treads","item_quarterstaff","item_magic_wand","item_mask_of_madness","item_belt_of_strength","item_blade_of_alacrity","item_dragon_lance","item_mithril_hammer","item_ogre_axe","item_black_king_bar","item_invis_sword","item_lesser_crit","item_silver_edge","item_hurricane_pike","item_blink","item_arcane_blink","item_gem","item_refresher","item_moon_shard","item_aghanims_shard",
	},
	{ {2,2,2,1,1,}, {2,2,2,1,1,}, 0.1 },
	{
		"Shadowraze","Necromastery","Presence of the Dark Lord","Requiem of Souls","+25 Shadowraze Stack Damage","+25 Attack Speed","Presence Aura Affects Building","+100 Shadowraze Damage","+3.0 Damage Per Soul","+0.3s Requiem Fear per line","-5s Shadowraze Cooldown","Shadowraze Applies Attack Damage",
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
