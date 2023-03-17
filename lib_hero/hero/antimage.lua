local hero_data = {
	"antimage",
	{1, 2, 1, 3, 1, 4, 2, 2, 2, 6, 1, 4, 3, 3, 7, 3, 4, 10, 12},
	{
		"item_quelling_blade","item_tango","item_branches","item_branches","item_orb_of_venom","item_boots","item_gloves","item_boots_of_elves","item_power_treads","item_ring_of_health","item_blight_stone","item_orb_of_corrosion","item_magic_wand","item_vanguard","item_blade_of_alacrity","item_robe","item_diffusal_blade_2","item_ultimate_orb","item_manta","item_basher","item_abyssal_blade","item_quarterstaff","item_eagle","item_butterfly","item_platemail","item_buckler","item_assault","item_helm_of_iron_will","item_nullifier",
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

