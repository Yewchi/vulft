local hero_data = {
	"lone_druid",
	{1, 2, 2, 1, 2, 4, 2, 1, 1, 3, 3, 4, 3, 3, 7, 5, 4, 9, 12},
	{
		"item_boots","item_magic_stick","item_quelling_blade","item_branches","item_branches","item_branches","item_tango","item_blades_of_attack","item_phase_boots","item_quarterstaff","item_lifesteal","item_mask_of_madness","item_orb_of_corrosion","item_blight_stone","item_mithril_hammer","item_mithril_hammer","item_desolator","item_aghanims_shard","item_demon_edge","item_javelin","item_blitz_knuckles","item_monkey_king_bar","item_buckler","item_wraith_band","item_wraith_band","item_magic_wand","item_lifesteal","item_blades_of_attack","item_ring_of_basilius","item_vladmir","item_boots_of_bearing","item_medallion_of_courage","item_crown","item_wind_lace","item_solar_crest",
	},
	{ {2,2,2,1,1,}, {2,2,2,1,1,}, 0.1 },
	{
		"Summon Spirit Bear","Spirit Link","Savage Roar","True Form","+200 Health","+25 Spirit Bear Movement Speed","-8s Savage Roar Cooldown","+8 Spirit Bear Armor","-50s True Form Cooldown","0 Entangling Claws Cooldown","-0.1 Spirit Bear Base Attack Time","+1000 True Form and Spirit Bear Health",
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
