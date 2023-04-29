local hero_data = {
	"tidehunter",
	{3, 2, 3, 2, 3, 5, 3, 6, 2, 2, 1, 5, 1, 1, 1, 8, 5, 10, 11},
	{
		"item_tango","item_ring_of_regen","item_ring_of_regen","item_enchanted_mango","item_faerie_fire","item_crown","item_ring_of_health","item_pers","item_crown","item_meteor_hammer","item_boots","item_mekansm","item_energy_booster","item_arcane_boots","item_mekansm","item_buckler","item_guardian_greaves","item_ogre_axe","item_point_booster","item_staff_of_wizardry","item_blade_of_alacrity","item_cloak","item_ultimate_scepter","item_headdress","item_pipe","item_sange","item_talisman_of_evasion","item_heavens_halberd",
	},
	{ {3,3,3,3,3,}, {3,3,3,3,3,}, 0.1 },
	{
		"Gush","Kraken Shell","Anchor Smash","Tendrils of the Deep","Ravage","+50 Anchor Smash Damage","+10.0% Gush Slow","+120 Gush Damage","-25% Anchor Smash Damage Reduction","Anchor Smash affects buildings","+40 Kraken Shell Damage Block","+0.8s Ravage Stun Duration","50% chance of Anchor Smash on attack",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"tidehunter_gush", ABILITY_TYPE.NUKE + ABILITY_TYPE.SLOW},
		{"tidehunter_kraken_shell", ABILITY_TYPE.PASSIVE},
		{"tidehunter_anchor_smash", ABILITY_TYPE.DEGEN + ABILITY_TYPE.NUKE},
		[5] = {"tidehunter_ravage", ABILITY_TYPE.NUKE + ABILITY_TYPE.AOE + ABILITY_TYPE.STUN},
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


