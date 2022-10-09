local hero_data = {
	"dragon_knight",
	{2, 3, 3, 1, 1, 4, 1, 1, 3, 5, 3, 4, 2, 2, 2, 7, 4, 10, 12},
	{
		"item_quelling_blade","item_tango","item_gauntlets","item_branches","item_branches","item_ward_observer","item_circlet","item_bracer","item_gloves","item_boots","item_magic_wand","item_blink","item_power_treads","item_ogre_axe","item_black_king_bar","item_blitz_knuckles","item_claymore","item_orchid","item_mage_slayer","item_bloodthorn","item_ultimate_scepter","item_hyperstone",
	},
	{ {2,2,2,3,3,}, {2,2,2,3,3,}, 0.1 },
	{
		"Breathe Fire","Dragon Tail","Dragon Blood","Elder Dragon Form","+15 Damage","-30% Breathe Fire Damage Reduction","+0.5s Dragon Tail","+400 Health","+175 Elder Dragon Form Attack Range","+20 Strength","+12 Dragon Blood HP Regen/Armor","+400 AoE Dragon Tail During Elder Dragon Form",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"dragon_knight_breathe_fire", ABILITY_TYPE.DEGEN + ABILITY_TYPE.AOE + ABILITY_TYPE.NUKE},
		{"dragon_knight_dragon_tail", ABILITY_TYPE.NUKE + ABILITY_TYPE.STUN},
		{"dragon_knight_dragon_blood", ABILITY_TYPE.PASSIVE},
		[5] = {"dragon_knight_elder_dragon_form", ABILITY_TYPE.BUFF + ABILITY_TYPE.ATTACK_MODIFIER + ABILITY_TYPE.DEGEN},
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


