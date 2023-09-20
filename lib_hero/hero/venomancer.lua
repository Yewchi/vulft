local hero_data = {
	"venomancer",
	{1, 2, 2, 3, 2, 5, 2, 3, 3, 3, 6, 5, 1, 1, 9, 1, 5, 11, 7},
	{
		"item_circlet","item_branches","item_tango","item_faerie_fire","item_branches","item_branches","item_faerie_fire","item_tango","item_bracer","item_boots","item_magic_wand","item_arcane_boots","item_headdress","item_wind_lace","item_chainmail","item_mekansm","item_hand_of_midas","item_guardian_greaves","item_cloak","item_ring_of_health","item_headdress","item_pipe","item_point_booster","item_ultimate_scepter","item_staff_of_wizardry","item_cyclone",
	},
	{ {1,1,1,3,3,}, {5,5,5,4,3,}, 0.1 },
	{
		"Venomous Gale","Poison Sting","Plague Ward","Poison Nova","Noxious Plague","-5s Venomous Gale CD","+15% Poison Sting Health Regen Reduction","-1.0s Plague Ward Cooldown","-8% Poison Sting Slow","1.5% Noxious Plague Max HP Damage","Gale Creates Plague Wards","Noxious Plague Aura reduces +200 Attack Speed","2.5x Plague Ward HP/Damage",
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

