local hero_data = {
	"alchemist",
	{3, 1, 1, 3, 1, 4, 1, 3, 3, 2, 2, 4, 2, 2, 7, 6, 4, 10, 12},
	{
		"item_tango","item_branches","item_quelling_blade","item_gauntlets","item_gauntlets","item_ward_observer","item_bottle","item_boots","item_phase_boots","item_soul_ring","item_relic","item_radiance","item_ogre_axe","item_mithril_hammer","item_black_king_bar","item_blink","item_blitz_knuckles","item_claymore","item_orchid","item_basher","item_vanguard","item_abyssal_blade","item_mage_slayer","item_bloodthorn","item_aghanims_shard","item_reaver","item_overwhelming_blink",
	},
	{ {2,2,2,2,3,}, {2,2,2,2,3,}, 0.1 },
	{
		"Acid Spray","Unstable Concoction","Greevil's Greed","Chemical Rage","+1 Acid Spray Armor Reduction","+125 Unstable Concoction Radius","Acid Spray grants armor to allies","+1 Damage per Greevil's Greed stack","-0.1s Chemical Rage Base Attack Time","+400 Unstable Concoction Max Damage","+50 Chemical Rage Movement Speed","+50 Chemical Rage Regeneration",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"alchemist_acid_spray", ABILITY_TYPE.NUKE + ABILITY_TYPE.DEGEN + ABILITY_TYPE.AOE},
		{"alchemist_unstable_concoction", ABILITY_TYPE.NUKE + ABILITY_TYPE.STUN},
		{"alchemist_goblins_greed", ABILITY_TYPE.PASSIVE},
		[5] = {"alchemist_chemical_rage", ABILITY_TYPE.ATTACK_MODIFIER + ABILITY_TYPE.HEAL},
		{"alchemist_unstable_concoction_throw", ABILITY_TYPE.NUKE + ABILITY_TYPE.STUN},
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
