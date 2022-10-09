local hero_data = {
	"tidehunter",
	{3, 1, 3, 1, 3, 4, 3, 2, 2, 2, 2, 4, 1, 1, 7, 5, 4, 9, 11},
	{
		"item_quelling_blade","item_tango","item_ring_of_protection","item_gauntlets","item_enchanted_mango","item_bracer","item_soul_ring","item_ring_of_health","item_hood_of_defiance","item_boots","item_magic_wand","item_headdress","item_pipe","item_platemail","item_energy_booster","item_arcane_boots","item_pers","item_lotus_orb","item_blink","item_buckler","item_ring_of_basilius","item_lifesteal","item_blades_of_attack","item_vladmir","item_point_booster","(null)","item_ultimate_orb","item_mystic_staff","item_void_stone",
	},
	{ {3,3,3,3,2,}, {3,3,3,3,2,}, 0.1 },
	{
		"Gush","Kraken Shell","Anchor Smash","Ravage","+10.0% Gush Slow","-100.0 Kraken Shell Damage Threshold","+120 Gush Damage","-20% Anchor Smash Damage Reduction","+30 Kraken Shell Damage Block","-4 Gush Armor","+1.0s Ravage Stun","50% chance of Anchor Smash on attack",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_HERO_SELECTION then return hero_data end

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


