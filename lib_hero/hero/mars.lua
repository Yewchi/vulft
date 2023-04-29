local hero_data = {
	"mars",
	{2, 1, 1, 2, 1, 4, 1, 2, 2, 5, 3, 4, 3, 3, 7, 3, 4, 10, 11},
	{
		"item_gauntlets","item_quelling_blade","item_gauntlets","item_tango","item_branches","item_branches","item_bracer","item_soul_ring","item_boots","item_phase_boots","item_blight_stone","item_magic_wand","item_mithril_hammer","item_desolator","item_mithril_hammer","item_ogre_axe","item_black_king_bar","item_aghanims_shard","item_blink","item_hyperstone","item_platemail","item_buckler","item_assault","item_pers","item_point_booster","item_vitality_booster","item_octarine_core","item_cornucopia","item_refresher","item_reaver","item_overwhelming_blink",
	},
	{ {3,3,3,2,2,}, {3,3,3,2,2,}, 0.1 },
	{
		"Spear of Mars","God's Rebuke","Bulwark","Arena Of Blood","+100 God's Rebuke Distance","+30% Bulwark Active Redirect Chance","-4s God's Rebuke Cooldown","+100.0 Spear Of Mars Damage","+6%/+6% Bulwark Front/Side damage reduction","+0.6s Spear of Mars Stun","God's Rebuke +65% Crit","Arena Of Blood Grants Team +180 HP Regen",
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
