local hero_data = {
	"luna",
	{3, 1, 3, 2, 3, 2, 3, 2, 2, 5, 1, 4, 1, 4, 7, 1, 4, 9, 12},
	{
		"item_tango","item_branches","item_circlet","item_magic_stick","item_quelling_blade","item_wraith_band","item_boots","item_gloves","item_boots_of_elves","item_magic_wand","item_power_treads","item_quarterstaff","item_mask_of_madness","item_blade_of_alacrity","item_yasha","item_manta","item_dragon_lance","item_ogre_axe","item_mithril_hammer","item_black_king_bar","item_blitz_knuckles","item_shadow_amulet","item_broadsword","item_invis_sword","item_silver_edge","item_force_staff","item_hurricane_pike","item_claymore","item_satanic","item_demon_edge","item_javelin","item_blitz_knuckles","item_monkey_king_bar",
	},
	{ {1,1,1,1,1,}, {1,1,1,1,1,}, 0.1 },
	{
		"Lucent Beam","Moon Glaives","Lunar Blessing","Eclipse","-8% Moon Glaives Damage Reduction","+0.3s Lucent Beam Ministun","-2.0s Lucent Beam Cooldown","-25.0s Eclipse Cooldown","+500 Moon Glaives fired on Lucent Beam","+100 Lucent Beam Damage","+20 Lunar Blessing Damage","+0.25s Eclipse Lucent Ministun",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"luna_lucent_beam", ABILITY_TYPE.STUN + ABILITY_TYPE.NUKE},
		{"luna_moon_glaive", ABILITY_TYPE.PASSIVE},
		{"luna_lunar_blessing", ABILITY_TYPE.PASSIVE + ABILITY_TYPE.BUFF},
		[5] = {"luna_eclipse", ABILITY_TYPE.NUKE},
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
