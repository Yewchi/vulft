local hero_data = {
	"juggernaut",
	{1, 3, 1, 2, 1, 5, 1, 2, 2, 6, 2, 5, 3, 8, 9},
	{
		"item_quelling_blade","item_tango","item_magic_stick","item_branches","item_branches","item_faerie_fire","item_tango","item_wraith_band","item_boots","item_blades_of_attack","item_chainmail","item_phase_boots","item_magic_wand","item_fluffy_hat","item_blades_of_attack","item_ring_of_basilius","item_javelin","item_maelstrom","item_blade_of_alacrity","item_boots_of_elves","item_yasha","item_aghanims_shard","item_blink","item_mjollnir","item_manta","item_belt_of_strength","item_basher","item_abyssal_blade","item_gem","item_butterfly",
	},
	{ {1,1,1,1,1,}, {1,1,1,1,1,}, 0.1 },
	{
		"Blade Fury","Healing Ward","Blade Dance","Swiftslash","Omnislash","+5 All Stats","+75.0 Blade Fury Radius","-20.0s Healing Ward Cooldown","+1s Blade Fury Duration","+40% Blade Dance Lifesteal","+150 Blade Fury DPS","+1s Omnislash Duration","+2 Healing Ward Hits to Kill",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_HERO_SELECTION then return hero_data end

local abilities = {
		[0] = {"juggernaut_blade_fury", ABILITY_TYPE.NUKE + ABILITY_TYPE.SHIELD + ABILITY_TYPE.AOE},
		{"juggernaut_healing_ward", ABILITY_TYPE.SUMMON + ABILITY_TYPE.HEAL + ABILITY_TYPE.AOE},
		{"juggernaut_blade_dance", ABILITY_TYPE.PASSIVE},
		[5] = {"juggernaut_omni_slash", ABILITY_TYPE.NUKE + ABILITY_TYPE.AOE + ABILITY_TYPE.SHIELD},
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
local R = RESPONSE_TYPES

local fight_harass_handle = FightHarass_GetTaskHandle()

local t_player_abilities = {}
local BLADE_FURY_DURATION = 5
local BLADE_FURY_RADIUS = 260
local HEALING_WARD_DURATION = 25

local d = {
	["ReponseNeeds"] = function()
		FightClimate_RegAvoidHeroReponse(R.RESPONSE_TYPE_AVOID_CASTER,
				nil,
				"juggernaught", "juggernaught_blade_fury",
				BLADE_FURY_DURATION, BLADE_FURY_RADIUS, 0.3,
				"modifier_juggernaught_blade_fury", false )
		FightClimate_RegSummedResponse(R.RESPONSE_TYPE_KILL_SUMMON,
				nil,
				"juggernaught", "juggernaught_healing_ward",
				HEALING_WARD_DURATION, 0.6,
				"modifier_juggernaught_healing_ward_heal", false,
				{"npc_dota_juggernaught_healing_ward"}, true
			)
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

