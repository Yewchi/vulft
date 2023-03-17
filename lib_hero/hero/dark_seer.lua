local hero_data = {
	"dark_seer",
	{2, 1, 2, 3, 2, 4, 2, 3, 3, 3, 1, 4, 1, 1, 7, 5, 4, 9, 11},
	{
		"item_quelling_blade","item_tango","item_enchanted_mango","item_enchanted_mango","item_magic_stick","item_branches","item_enchanted_mango","item_branches","item_ring_of_health","item_arcane_boots","item_magic_wand","item_chainmail","item_buckler","item_mekansm","item_guardian_greaves","item_hood_of_defiance","item_staff_of_wizardry","item_pipe","item_point_booster","item_ogre_axe","item_staff_of_wizardry","item_ultimate_scepter","item_blink","item_ogre_axe","item_mithril_hammer","item_black_king_bar","item_ultimate_orb","item_mystic_staff","item_void_stone",
	},
	{ {3,3,3,3,3,}, {3,3,3,3,3,}, 0.1 },
	{
		"Vacuum","Ion Shell","Surge","Wall of Replica","+20% Wall of Replica Illusion Damage","+50 Ion Shell Radius","+100 Vacuum AoE","Ion Shell Provides +250 Max Health","-40.0s Wall of Replica Cooldown","+50 Ion Shell Damage","+2 Ion Shell Charges ","350 AoE Surge",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_HERO_SELECTION then return hero_data end

local abilities = {
		[0] = {"dazzle_poison_touch", ABILITY_TYPE.NUKE + ABILITY_TYPE.SLOW + ABILITY_TYPE.ATTACK_MODIFIER},
		{"dazzle_shallow_grave", ABILITY_TYPE.HEAL + ABILITY_TYPE.BUFF + ABILITY_TYPE.SHIELD},
		{"dazzle_shadow_wave", ABILITY_TYPE.HEAL + ABILITY_TYPE.NUKE},
		[5] = {"dazzle_bad_juju", ABILITY_TYPE.PASSIVE},
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


