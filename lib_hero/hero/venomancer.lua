local hero_data = {
	"venomancer",
	{2, 1, 2, 1, 2, 3, 3, 5, 3, 3, 2, 5, 6, 1, 9, 1, 5, 11, 7, 13},
	{
		"item_ring_of_protection","item_circlet","item_branches","item_branches","item_tango","item_faerie_fire","item_urn_of_shadows","item_boots","item_magic_wand","item_tranquil_boots","item_vitality_booster","item_spirit_vessel","item_cloak","item_headdress","item_hood_of_defiance","item_fluffy_hat","item_pipe","item_force_staff","item_ogre_axe","item_sange","item_kaya_and_sange","item_aghanims_shard","item_blink","item_hurricane_pike","item_boots","item_gem",
	},
	{ {3,3,3,3,3,}, {3,3,3,3,4,}, 0.1 },
	{
		"Venomous Gale","Poison Sting","Plague Ward","Latent Toxicity","Poison Nova","-5s Venomous Gale CD","+20% Poison Sting Health Regen Reduction","-1.0s Plague Ward Cooldown","-8% Poison Sting Slow","+5.0s Poison Nova Duration","Gale Creates Plague Wards","Poison Nova reduces +100 Attack Speed","2.5x Plague Ward HP/Damage",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"venomancer_venomous_gale", ABILITY_TYPE.NUKE + ABILITY_TYPE.SLOW + ABILITY_TYPE.AOE},
		{"venomancer_poison_sting", ABILITY_TYPE.PASSIVE},
		{"venomancer_plague_ward", ABILITY_TYPE.SUMMON},
		[5] = {"venomancer_poison_nova", ABILITY_TYPE.NUKE + ABILITY_TYPE.AOE},
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

