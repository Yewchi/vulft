local hero_data = {
	"tidehunter",
	{3, 1, 3, 2, 3, 5, 3, 2, 2, 2, 1, 5, 1, 1, 8, 6, 5, 10, 12},
	{
		"item_tango","item_quelling_blade","item_flask","item_magic_stick","item_enchanted_mango","item_boots","item_magic_wand","item_arcane_boots","item_point_booster","item_ogre_axe","item_staff_of_wizardry","item_ultimate_scepter","item_blink","item_aghanims_shard","item_ogre_axe","item_mithril_hammer","item_black_king_bar","item_pers","item_refresher","item_overwhelming_blink","item_platemail","item_shivas_guard","item_void_stone","item_soul_booster","item_octarine_core","item_ultimate_scepter_2","item_moon_shard",
	},
	{ {3,3,3,3,3,}, {3,3,3,3,3,}, 0.1 },
	{
		"Gush","Kraken Shell","Anchor Smash","Tendrils of the Deep","Ravage","+50 Anchor Smash Damage","+10.0% Gush Slow","+120 Gush Damage","-25% Anchor Smash Damage Reduction","Anchor Smash affects buildings","+40 Kraken Shell Damage Block","+1s Ravage Stun","50% chance of Anchor Smash on attack",
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


