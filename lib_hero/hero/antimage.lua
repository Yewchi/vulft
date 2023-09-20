local hero_data = {
	"antimage",
	{1, 2, 1, 3, 2, 5, 2, 2, 1, 6, 1, 5, 3, 3, 8, 3, 9, 11, 13},
	{
		"item_quelling_blade","item_tango","item_magic_stick","item_circlet","item_branches","item_gloves","item_boots_of_elves","item_power_treads","item_broadsword","item_cornucopia","item_claymore","item_bfury","item_blade_of_alacrity","item_yasha","item_manta","item_mithril_hammer","item_belt_of_strength","item_basher","item_vanguard","item_abyssal_blade","item_quarterstaff","item_butterfly","item_skadi","item_ultimate_scepter","item_javelin","item_ultimate_scepter_2","item_gem","item_desolator",
	},
	{ {1,1,1,1,1,}, {1,1,1,1,1,}, 0.1 },
	{
		"Mana Break","Blink","Counterspell","Counterspell Ally","Mana Void","+9 Strength","+150 Mana Void Radius","+0.6% Max Mana Mana Burn","-1s Blink Cooldown","+0.15 Mana Void Damage Multiplier","+150 Blink Cast Range","+20% Counterspell Magic Resistance","-50s Mana Void Cooldown",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
	[0] = {"antimage_mana_break", ABILITY_TYPE.PASSIVE},
		{"antimage_blink", ABILITY_TYPE.MOBILITY},
		{"antimage_counterspell", ABILITY_TYPE.SHIELD},
		[5] = {"antimage_mana_void", ABILITY_TYPE.NUKE},
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

-- register cast callback
-- f(event) {
-- 		if ability == stun && ability.dmgType == mgk && thisAntiMage.hpp > 0.8 && not thisAntiMage.isStunned
-- 				&& not AbilityLogic_CouldBeBlocked(thisAntiMage, ability) && UnitFacingUnit(thisAntiMage, caster) > 0.75 && randint(1, 10 - KDA(thisAntiMage)) == 1, {
-- 			chat("Magic is an abo- *", ability.name, " hits*")
-- 		}
-- 	}

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

