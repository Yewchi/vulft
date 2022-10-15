local hero_data = {
	"snapfire",
	{1, 2, 1, 2, 1, 5, 1, 2, 2, 3, 3, 5, 3, 3, 9, 6, 5, 11, 7, 13},
	{
		"item_branches","item_tango","item_faerie_fire","item_branches","item_ward_observer","item_branches","item_bottle","item_boots","item_magic_wand","item_ogre_axe","item_mithril_hammer","item_aghanims_shard","item_black_king_bar","item_aghanims_shard","item_point_booster","item_staff_of_wizardry","item_ogre_axe","item_blade_of_alacrity","item_ultimate_scepter","item_aether_lens","item_point_booster","item_void_stone","item_octarine_core","item_blink",
	},
	{ {3,3,1,2,2,}, {4,4,5,2,2,}, 0.1 },
	{
		"Scatterblast","Firesnap Cookie","Lil' Shredder","Spit Out","Mortimer Kisses","+60 Scatterblast Damage","Firesnap Cookie Restores +125 Health","+2 Lil' Shredder attacks","-4s Firesnap Cookie Cooldown","Lil' Shredder Uses Your Attack Damage","+60 Mortimer Kisses Impact Damage","3x Lil' Shredder Multishot","+6 Mortimer Kisses Launched",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_HERO_SELECTION then return hero_data end

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


