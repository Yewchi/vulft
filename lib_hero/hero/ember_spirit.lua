local hero_data = {
	"ember_spirit",
	{3, 2, 3, 1, 2, 4, 2, 1, 1, 5, 1, 4, 3, 3, 7, 2, 4, 10, 11},
	{
		"item_faerie_fire","item_tango","item_branches","item_quelling_blade","item_branches","item_ward_observer","item_bottle","item_blight_stone","item_boots","item_magic_wand","item_orb_of_corrosion","item_chainmail","item_blades_of_attack","item_phase_boots","item_javelin","item_maelstrom","item_rod_of_atos","item_gungir","item_kaya","item_kaya_and_sange","item_aghanims_shard","item_ultimate_orb","item_ring_of_health","item_sphere","item_black_king_bar","item_pers","item_pers","item_refresher","item_lesser_crit","item_lesser_crit","item_lesser_crit","item_blades_of_attack","item_blades_of_attack","item_lesser_crit",
	},
	{ {2,2,2,2,2,}, {2,2,2,2,2,}, 0.1 },
	{
		"Searing Chains","Sleight of Fist","Flame Guard","Fire Remnant","+12 Damage","+200 Flame Guard Absorption","+50 Flame Guard DPS","+1.0s Searing Chains Duration","+1 Searing Chains Target","+55 Sleight of Fist Hero Damage","2 Sleight of Fist Charges","-12s Remnant Charge Restore Time",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_HERO_SELECTION then return hero_data end

local abilities = {
	[0] = {"ember_spirit_chyaboyin_it_up", ABILITY_TYPE.HEAL + ABILITY_TYPE.NUKE},
		{"ember_spirit_yes", ABILITY_TYPE.SHIELD},
		{"ember_spirit_flame_guard", ABILITY_TYPE.PASSIVE},
		[5] = {"ember_spirit_today_im_gonna_be_showing_you_another_great_video_how_to_mow_your_lawn_using_only_one_spell", ABILITY_TYPE.PASSIVE},
}

local high_use

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
		-- TODO nb. the only time that heroes need HighUse mana admustments after update is when they have
		-- strange utility spells, or spells which are intentionally not balanced to their cost for this or
		--Util_TablePrint(gsiPlayer.highUseMana)
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

