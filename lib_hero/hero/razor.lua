local hero_data = {
	"razor",
	{1, 2, 1, 2, 1, 4, 1, 3, 3, 5, 3, 4, 3, 2, 8, 2, 4, 10, 11},
	{
		"item_tango","item_branches","item_branches","item_branches","item_circlet","item_slippers","item_wraith_band","item_boots","item_boots_of_elves","item_gloves","item_power_treads","item_falcon_blade","item_ogre_axe","item_mithril_hammer","item_magic_wand","item_black_king_bar","item_blade_of_alacrity","item_ogre_axe","item_yasha","item_sange_and_yasha","item_ultimate_orb","item_sphere","item_pers","item_refresher","item_lifesteal","item_claymore",
	},
	{ {1,1,1,3,3,}, {1,1,1,3,3,}, 0.1 },
	{
		"Plasma Field","Static Link","Storm Surge","Eye of the Storm","+30 Plasma Field Damage","+12 Agility","+5 Static Link Damage Steal","+14 Strength","+21% Storm Surge Move Speed","-0.1s Eye of the Storm Strike Interval","Creates A Second Plasma Field Delayed By +0.8s","Static Link Steals Attack Speed",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"razor_plasma_field", ABILITY_TYPE.NUKE + ABILITY_TYPE.SLOW + ABILITY_TYPE.AOE},
		{"razor_static_link", ABILITY_TYPE.ATTACK_MODIFIER},
		{"razor_storm_surge", ABILITY_TYPE.PASSIVE},
		[5] = {"razor_eye_of_the_storm", ABILITY_TYPE.AOE + ABILITY_TYPE.NUKE + ABILITY_TYPE.ATTACK_MODIFIER},
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
	HeroData_SetHeroData(hero_data, abilities, hero_access, true)
end


