local hero_data = {
	"alchemist",
	{2, 1, 1, 2, 1, 5, 1, 2, 2, 7, 3, 5, 3, 3, 9, 3, 5, 6, 12, 13},
	{
		"item_tango","item_magic_stick","item_quelling_blade","item_faerie_fire","item_branches","item_branches","item_belt_of_strength","item_boots","item_gloves","item_power_treads","item_cornucopia","item_broadsword","item_bfury","item_magic_wand","item_belt_of_strength","item_sange","item_sange_and_yasha","item_blink","item_invis_sword","item_reaver","item_heart","item_silver_edge","item_overwhelming_blink","item_black_king_bar","item_basher","item_vanguard","item_abyssal_blade","item_moon_shard","item_buckler","item_assault","item_ultimate_scepter","item_ultimate_scepter","item_gem",
	},
	{ {1,1,1,1,1,}, {1,1,1,1,1,}, 0.1 },
	{
		"Acid Spray","Unstable Concoction","Corrosive Weaponry","Greevil's Greed","Chemical Rage","+1 Acid Spray Armor Reduction","+125 Unstable Concoction Radius","Acid Spray grants armor to allies","+3 Damage per Greevil's Greed stack","-0.1s Chemical Rage Base Attack Time","+400 Unstable Concoction Max Damage","+50 Chemical Rage Movement Speed","+50 Chemical Rage Regeneration",
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
		elseif false then -- TODO generic item use (probably can use same func for finished heroes)

		end
	end,
}

local hero_access = function(key) return d[key] end

do
	HeroData_SetHeroData(hero_data, abilities, hero_access)
end
