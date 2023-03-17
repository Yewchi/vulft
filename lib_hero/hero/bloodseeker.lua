local hero_data = {
	"bloodseeker",
	{2, 3, 3, 1, 3, 5, 3, 1, 1, 1, 6, 5, 2, 2, 8, 2},
	{
		"item_tango","item_quelling_blade","item_magic_stick","item_slippers","item_branches","item_faerie_fire","item_blades_of_attack","item_boots","item_chainmail","item_phase_boots","item_javelin","item_magic_wand","item_maelstrom","item_ultimate_orb","item_ring_of_health","item_sphere","item_crown","item_crown","item_gungir","item_mithril_hammer","item_ogre_axe","item_black_king_bar","item_mithril_hammer","item_basher","item_vanguard","item_abyssal_blade","item_mystic_staff","item_void_stone","item_sheepstick",
	},
	{ {1,1,1,1,1,}, {1,1,1,1,1,}, 0.1 },
	{
		"Bloodrage","Blood Rite","Thirst","Blood Mist","Rupture","+25 Bloodrage Attack Speed","+8% Bloodrage Spell Amplification","+8% Rupture Initial Damage","+85 Blood Rite Damage","+425 Rupture Cast Range","+15% Spell Lifesteal","+2 Rupture Charges","+18% Max Thirst MS",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_HERO_SELECTION then return hero_data end

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


