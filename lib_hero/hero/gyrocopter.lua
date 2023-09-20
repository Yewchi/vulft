local hero_data = {
	"gyrocopter",
	{2, 3, 3, 1, 3, 4, 3, 8, 11},
	{
		"item_branches","item_branches","item_magic_stick","item_branches","item_tango","item_slippers","item_wraith_band","item_blades_of_attack","item_magic_wand","item_boots","item_falcon_blade","item_gloves","item_boots_of_elves","item_power_treads","item_blade_of_alacrity","item_ogre_axe","item_staff_of_wizardry","item_point_booster","item_ultimate_scepter","item_blades_of_attack","item_broadsword","item_lesser_crit","item_blitz_knuckles","item_shadow_amulet","item_broadsword","item_silver_edge","item_lifesteal","item_claymore","item_satanic","item_ogre_axe","item_mithril_hammer","item_black_king_bar","item_butterfly","item_ultimate_scepter_2","item_skadi",
	},
	{ {1,1,1,1,1,}, {1,1,1,1,1,}, 0.1 },
	{
		"Rocket Barrage","Homing Missile","Flak Cannon","Call Down","+30 Movement Speed during Rocket Barrage","+200 Health","+0.3s Homing Missile Stun Duration","+3 Flak Cannon Attacks","+40 Flak Cannon Damage","+14 Rocket Barrage Damage","-6s Flak Cannon Cooldown","3x Call Down",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"gyrocopter_rocket_barrage", ABILITY_TYPE.NUKE},
		{"gyrocopter_homing_missile", ABILITY_TYPE.STUN + ABILITY_TYPE.NUKE},
		{"gyrocopter_flak_cannon", ABILITY_TYPE.BUFF + ABILITY_TYPE.AOE + ABILITY_TYPE.ATTACK_MODIFIER},
		[5] = {"gyrocopter_call_down", ABILITY_TYPE.NUKE + ABILITY_TYPE.AOE + ABILITY_TYPE.SLOW},
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
