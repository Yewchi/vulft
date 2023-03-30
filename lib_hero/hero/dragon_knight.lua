local hero_data = {
	"dragon_knight",
	{2, 3, 3, 1, 1, 4, 1, 1, 2, 2, 2, 4, 3, 3, 8, 5, 4, 9, 11},
	{
		"item_quelling_blade","item_tango","item_enchanted_mango","item_gauntlets","item_gauntlets","item_branches","item_soul_ring","item_boots","item_gloves","item_power_treads","item_bracer","item_magic_wand","item_blink","item_aghanims_shard","item_ogre_axe","item_mithril_hammer","item_black_king_bar","item_ogre_axe","item_point_booster","item_ogre_axe","item_staff_of_wizardry","item_blade_of_alacrity","item_ultimate_scepter","item_sange","item_heavens_halberd","item_yasha","item_manta",
	},
	{ {3,3,3,3,2,}, {3,3,3,3,2,}, 0.1 },
	{
		"Breathe Fire","Dragon Tail","Dragon Blood","Elder Dragon Form","+15 Damage","-30% Breathe Fire Damage Reduction","+0.5s Dragon Tail Stun","+400 Health","+175 Elder Dragon Form Attack Range","+75% Breathe Fire Damage/Cast Range in Dragon Form","+12 Dragon Blood HP Regen/Armor","+400 AoE Dragon Tail During Elder Dragon Form",
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


