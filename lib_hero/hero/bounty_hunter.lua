local hero_data = {
	"bounty_hunter",
	{2, 1, 2, 1, 2, 4, 2, 1, 1, 6, 3, 4, 3, 3, 8, 3, 4, 9, 11},
	{
		"item_tango","item_quelling_blade","item_circlet","item_slippers","item_branches","item_branches","item_wraith_band","item_pers","item_crown","item_meteor_hammer","item_boots","item_wind_lace","item_magic_wand","item_phase_boots","item_point_booster","item_staff_of_wizardry","item_ogre_axe","item_ultimate_scepter","item_mithril_hammer","item_ogre_axe","item_black_king_bar","item_void_stone","item_energy_booster","item_aether_lens","item_octarine_core","item_ultimate_orb","item_mystic_staff","item_sheepstick","item_ultimate_scepter_2","item_wind_lace","item_staff_of_wizardry","item_cyclone","item_wind_waker",
	},
	{ {3,3,3,3,4,}, {5,3,4,3,4,}, 0.1 },
	{
		"Shuriken Toss","Jinada","Shadow Walk","Track","+10/+10% Shadow Walk Attack/Move Slow","+40 Jinada Damage","+2s Silence on Hit With Shadow Walk","Half Track Bonus Speed to Allies","Track Grants 600 Ground Vision","+50 Jinada Gold Steal","2 Shuriken Toss Charges","+250 Track Gold",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"bounty_hunter_shuriken_toss", ABILITY_TYPE.NUKE + ABILITY_TYPE.STUN},
		{"bounty_hunter_jinada", ABILITY_TYPE.ATTACK_MODIFIER},
		{"bounty_hunter_wind_walk", ABILITY_TYPE.NUKE + ABILITY_TYPE.INVIS},
		[5] = {"bounty_hunter_track", ABILITY_TYPE.DEGEN},
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


