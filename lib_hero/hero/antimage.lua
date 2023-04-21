local hero_data = {
	"antimage",
	{1, 2, 1, 3, 1, 4, 2, 2, 2, 1, 6, 4, 3, 3, 7, 3, 4, 10, 12},
	{
		"item_branches","item_branches","item_quelling_blade","item_tango","item_orb_of_venom","item_blight_stone","item_orb_of_corrosion","item_gloves","item_ring_of_health","item_vanguard","item_boots","item_boots_of_elves","item_power_treads","item_broadsword","item_claymore","item_void_stone","item_bfury","item_yasha","item_magic_wand","item_manta","item_vanguard","item_sphere","item_ultimate_orb","item_skadi","item_basher","item_abyssal_blade","item_black_king_bar","item_staff_of_wizardry","item_ogre_axe","item_ultimate_scepter_2",
	},
	{ {1,1,1,1,1,}, {1,1,1,1,1,}, 0.1 },
	{
		"Mana Break","Blink","Counterspell","Mana Void","+9 Strength","-1s Blink Cooldown","+0.6% Max Mana Mana Burn","+150 Mana Void Radius","+0.1 Mana Void Damage Multiplier","+250 Blink Cast Range","+20% Counterspell Magic Resistance","-50s Mana Void Cooldown",
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

