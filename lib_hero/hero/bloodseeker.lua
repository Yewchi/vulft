local hero_data = {
	"bloodseeker",
	{2, 3, 3, 2, 3, 5, 3, 1, 1, 1, 1, 5, 6, 2, 8, 2, 5, 10, 12},
	{
		"item_branches","item_circlet","item_quelling_blade","item_tango","item_branches","item_slippers","item_orb_of_venom","item_blight_stone","item_fluffy_hat","item_orb_of_corrosion","item_boots","item_blades_of_attack","item_wraith_band","item_chainmail","item_phase_boots","item_javelin","item_maelstrom","item_ogre_axe","item_mithril_hammer","item_black_king_bar","item_mithril_hammer","item_basher","item_aghanims_shard","item_hyperstone","item_mjollnir","item_ultimate_orb","item_ultimate_orb","item_skadi","item_abyssal_blade","item_cornucopia","item_cornucopia","item_refresher","item_staff_of_wizardry","item_ogre_axe","item_blade_of_alacrity","item_ultimate_scepter_2",
	},
	{ {1,1,1,1,3,}, {1,1,1,1,3,}, 0.1 },
	{
		"Bloodrage","Blood Rite","Thirst","Blood Mist","Rupture","+25 Bloodrage Attack Speed","+8% Bloodrage Spell Amplification","+8% Rupture Initial Damage","+85 Blood Rite Damage","+425 Rupture Cast Range","+15% Spell Lifesteal","+2 Rupture Charges","+18% Max Thirst MS",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"bloodseeker_bloodrage", ABILITY_TYPE.BUFF + ABILITY_TYPE.ATTACK_MODIFIER},
		{"bloodseeker_blood_bath", ABILITY_TYPE.NUKE + ABILITY_TYPE.AOE},
		{"bloodseeker_thirst", ABILITY_TYPE.PASSIVE},
		[5] = {"bloodseeker_rupture", ABILITY_TYPE.NUKE + ABILITY_TYPE.SLOW},
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


