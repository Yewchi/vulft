local hero_data = {
	"phantom_assassin",
	{1, 2, 1, 3, 1, 4, 2, 2, 2, 5, 1, 4, 3, 3, 8, 3, 4, 10, 12},
	{
		"item_quelling_blade","item_tango","item_magic_stick","item_circlet","item_branches","item_orb_of_venom","item_blight_stone","item_fluffy_hat","item_orb_of_corrosion","item_gloves","item_boots","item_boots_of_elves","item_power_treads","item_magic_wand","item_claymore","item_broadsword","item_bfury","item_ogre_axe","item_mithril_hammer","item_aghanims_shard","item_black_king_bar","item_aghanims_shard","item_mithril_hammer","item_basher","item_desolator","item_abyssal_blade","item_lifesteal","item_claymore","item_satanic","item_point_booster","item_boots","item_ultimate_scepter_2",
	},
	{ {1,1,1,1,1,}, {1,1,1,1,1,}, 0.1 },
	{
		"Stifling Dagger","Phantom Strike","Blur","Coup de Grace","+0.5s Phantom Strike Duration","-2.0s Stifling Dagger Cooldown","+25% Blur Evasion","+250 Phantom Strike Cast Range","+20% Stifling Dagger Damage","+60 Phantom Strike Attack Speed","+7% Coup de Grace chance","Triple Strike Stifling Dagger",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"phantom_assassin_stifling_dagger", ABILITY_TYPE.NUKE + ABILITY_TYPE.SLOW},
		{"phantom_assassin_phantom_strike", ABILITY_TYPE.MOBILITY + ABILITY_TYPE.ATTACK_MODIFIER},
		{"phantom_assassin_blur", ABILITY_TYPE.INVIS},
		[5] = {"phantom_assassin_coup_de_grace", ABILITY_TYPE.PASSIVE},
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
