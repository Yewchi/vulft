local hero_data = {
	"antimage",
	{1, 2, 1, 3, 2, 4, 2, 2, 3, 5, 3, 4, 3, 1, 7, 1, 4, 10, 12},
	{
		"item_quelling_blade","item_tango","item_slippers","item_circlet","item_branches","item_branches","item_ring_of_health","item_gloves","item_boots","item_boots_of_elves","item_power_treads","item_broadsword","item_claymore","item_bfury","item_boots_of_elves","item_wraith_band","item_yasha","item_manta","item_ultimate_orb","item_skadi","item_mithril_hammer","item_black_king_bar","item_ultimate_orb","item_pers","item_sphere","item_butterfly","item_point_booster","item_staff_of_wizardry","item_ogre_axe","item_blade_of_alacrity","item_ultimate_scepter_2","item_moon_shard",
	},
	{ {1,1,1,1,1,}, {1,1,1,1,1,}, 0.1 },
	{
		"Mana Break","Blink","Counterspell","Mana Void","+9 Strength","-1s Blink Cooldown","+0.6% Max Mana Mana Burn","+150 Mana Void Radius","+0.1 Mana Void Damage Multiplier","+250 Blink Cast Range","+20% Counterspell Magic Resistance","-50s Mana Void Cooldown",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_HERO_SELECTION then return hero_data end

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

