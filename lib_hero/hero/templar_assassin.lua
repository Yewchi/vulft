local hero_data = {
	"templar_assassin",
	{3, 1, 1, 3, 1, 4, 1, 3, 2, 2, 2, 4, 2, 3, 8, 5, 4, 9, 12},
	{
		"item_ward_observer","item_tango","item_branches","item_branches","item_faerie_fire","item_branches","item_slippers","item_circlet","item_bottle","item_gloves","item_boots","item_blight_stone","item_boots_of_elves","item_power_treads","item_blade_of_alacrity","item_belt_of_strength","item_dragon_lance","item_blink","item_mithril_hammer","item_desolator","item_aghanims_shard","item_black_king_bar","item_sheepstick","item_swift_blink","item_nullifier","item_blitz_knuckles","item_claymore","item_mage_slayer","item_bloodthorn","item_moon_shard",
	},
	{ {2,2,2,1,1,}, {2,2,2,1,1,}, 0.1 },
	{
		"Refraction","Meld","Psi Blades","Psionic Trap","+25 Refraction Damage","+110 Psionic Trap Damage","Refraction Can Be Cast While Disabled","+120 Psi Blades Attack and Spill Range","Meld Dispels","-3 Meld Armor Reduction","1.0s Meld Hit Bash","+7 Refraction Instances",
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
