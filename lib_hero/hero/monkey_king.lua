local hero_data = {
	"monkey_king",
	{1, 3, 3, 2, 3, 1, 2, 3, 1, 1, 4, 4, 2, 2, 8, 6, 4, 10, 12},
	{
		"item_branches","item_quelling_blade","item_magic_stick","item_circlet","item_tango","item_orb_of_venom","item_boots","item_orb_of_corrosion","item_boots_of_elves","item_power_treads","item_quarterstaff","item_oblivion_staff","item_ogre_axe","item_echo_sabre","item_mithril_hammer","item_desolator","item_blitz_knuckles","item_broadsword","item_invis_sword","item_lesser_crit","item_silver_edge","item_mithril_hammer","item_ogre_axe","item_black_king_bar","item_harpoon","item_ultimate_orb","item_void_stone","item_sheepstick",
	},
	{ {1,1,1,1,5,}, {1,1,1,1,4,}, 0.1 },
	{
		"Boundless Strike","Tree Dance","Jingu Mastery","Wukong's Command","+0.2s Mischief Invulnerability Duration","+0.3s Boundless Strike Stun Duration","+450 Tree Dance Cast Range","+110 Jingu Mastery Damage","0 Cooldown Primal Spring","-7.0s Boundless Strike Cooldown","-1 Jingu Mastery Required Hits","Additional Wukong's Command Ring",
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
