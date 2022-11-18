local hero_data = {
	"necrolyte",
	{1, 3, 1, 3, 1, 4, 1, 3, 2, 3, 5, 4, 2, 2, 7, 2, 4, 10, 11},
	{
		"item_magic_stick","item_tango","item_faerie_fire","item_circlet","item_branches","item_magic_wand","item_boots","item_urn_of_shadows","item_cloak","item_ring_of_health","item_hood_of_defiance","item_vitality_booster","item_wind_lace","item_spirit_vessel","item_void_stone","item_cyclone","item_blink","item_reaver","item_overwhelming_blink","item_mystic_staff","item_wind_waker","item_sange","item_staff_of_wizardry","item_kaya","item_kaya_and_sange","item_aghanims_shard",
	},
	{ {2,2,2,3,1,}, {2,2,2,3,1,}, 0.1 },
	{
		"Death Pulse","Ghost Shroud","Heartstopper Aura","Reaper's Scythe","+100 Reaper's Scythe Cast Range","+2s Heartstopper Aura Stack Duration","+24% Ghost Shroud Slow","+32 Death Pulse Heal","+15% Ghost Shroud Self Restoration Amp","+32% Heartstopper Regen Reduction","+0.5% Heartstopper Aura Damage","-2.5s Death Pulse Cooldown",
	}
}
--@EndAutomatedHeroData
THIS_INCLUDED_PICK_STAGE_DATA = hero_data

local abilities = {
	[0] = {"necrolyte_death_pulse", ABILITY_TYPE.NUKE + ABILITY_TYPE.AOE + ABILITY_TYPE.HEAL},
		{"necrolyte_sadist", ABILITY_TYPE.MOBILITY + ABILITY_TYPE.BUFF},
		{"necrolyte_heartstopper_aura", ABILITY_TYPE.PASSIVE},
		{"necrolyte_death_seeker", ABILITY_TYPE.NUKE + ABILITY_TYPE.AOE + ABILITY_TYPE.HEAL},
		[5] = {"necrolyte_reapers_scythe", ABILITY_TYPE.STUN + ABILITY_TYPE.NUKE}
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

