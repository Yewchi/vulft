local hero_data = {
	"phantom_lancer",
	{1, 3, 3, 2, 3, 4, 3, 1, 1, 1, 5, 4, 2, 2, 8, 2, 4, 9, 12},
	{
		"item_slippers","item_quelling_blade","item_tango","item_circlet","item_branches","item_branches","item_wraith_band","item_boots_of_elves","item_boots","item_gloves","item_power_treads","item_blade_of_alacrity","item_ogre_axe","item_staff_of_wizardry","item_ultimate_scepter","item_blade_of_alacrity","item_diffusal_blade_2","item_yasha","item_cloak","item_robe","item_reaver","item_heart","item_helm_of_iron_will","item_nullifier","item_manta","item_disperser","item_aghanims_shard","item_skadi","item_rapier","item_ultimate_scepter_2",
	},
	{ {1,1,1,1,1,}, {1,1,1,1,1,}, 0.1 },
	{
		"Spirit Lance","Doppelganger","Phantom Rush","Juxtapose","+40 Spirit Lance Damage","+8 Strength","+2.5s Phantom Rush Bonus Agility Duration","-1.5s Spirit Lance Cooldown","+300 Phantom Rush Range","+10% Juxtapose Damage","-4s Doppelganger CD","+24.0% Critical Strike (200.0%)",
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
		SpecialBehavior_RegisterBehavior("foundIllusionCancel",
				function(gsiPlayer, hAbility)
					if hAbility:GetName() == "phantom_lancer_doppelwalk" then
						return true
					end
				end
			)
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
