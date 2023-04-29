local hero_data = {
	"snapfire",
	{1, 2, 1, 2, 1, 4, 1, 2, 2, 5, 3, 4, 3, 3, 8, 3, 4, 10, 12},
	{
		"item_enchanted_mango","item_magic_stick","item_tango","item_circlet","item_wraith_band","item_boots","item_arcane_boots","item_headdress","item_chainmail","item_mekansm","item_buckler","item_guardian_greaves","item_cloak","item_headdress","item_pipe","item_aghanims_shard","item_void_stone","item_ultimate_orb","item_sheepstick","item_blink","item_vitality_booster","item_energy_booster","item_gem","item_gem","item_reaver","item_aeon_disk","item_overwhelming_blink","item_gem","item_gem","item_cornucopia","item_cornucopia","item_refresher",
	},
	{ {3,3,3,2,1,}, {3,3,5,2,4,}, 0.1 },
	{
		"Scatterblast","Firesnap Cookie","Lil' Shredder","Mortimer Kisses","+70 Scatterblast Damage","Firesnap Cookie Restores +125 Health","+2 Lil' Shredder attacks","-4s Firesnap Cookie Cooldown","Lil' Shredder Uses Your Attack Damage","+60 Mortimer Kisses Impact Damage","3x Lil' Shredder Multishot","+6 Mortimer Kisses Launched",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"snapfire_scatterblast", ABILITY_TYPE.SLOW + ABILITY_TYPE.AOE + ABILITY_TYPE.NUKE},
		{"snapfire_firesnap_cookie", ABILITY_TYPE.NUKE + ABILITY_TYPE.HEAL + ABILITY_TYPE.MOBILITY},
		{"snapfire_lil_shredder", ABILITY_TYPE.NUKE + ABILITY_TYPE.ATTACK_MODIFIER},
		{"snapfire_gobble_up", ABILITY_TYPE.HEAL},
		[5] = {"snapfire_mortimer_kiss", ABILITY_TYPE.SLOW + ABILITY_TYPE.NUKE},
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


