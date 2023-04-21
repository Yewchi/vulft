local hero_data = {
	"hoodwink",
	{1, 2, 2, 3, 2, 4, 2, 1, 1, 6, 1, 4, 3, 3, 8, 3, 4, 9, 11},
	{
		"item_ward_observer","item_enchanted_mango","item_tango","item_branches","item_branches","item_branches","item_ward_sentry","item_bottle","item_fluffy_hat","item_blades_of_attack","item_falcon_blade","item_boots","item_magic_wand","item_javelin","item_mithril_hammer","item_maelstrom","item_staff_of_wizardry","item_crown","item_crown","item_rod_of_atos","item_gungir","item_blade_of_alacrity","item_belt_of_strength","item_dragon_lance","item_staff_of_wizardry","item_fluffy_hat","item_hurricane_pike","item_lesser_crit","item_skadi","item_greater_crit","item_desolator","item_black_king_bar",
	},
	{ {2,2,1,3,3,}, {4,4,4,2,5,}, 0.1 },
	{
		"Acorn Shot","Bushwhack","Scurry","Sharpshooter","+40% Scurry Evasion When Active","-3.0s Bushwhack Cooldown","+60.0 Bushwhack Damage","+2 Acorn Shot Bounces","25.0% Sharpshooter Faster Projectile / Charge Time","-4 Armor Corruption","2 Acorn Shot Charges","+135 Bushwhack Radius",
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
