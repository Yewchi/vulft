local hero_data = {
	"rubick",
	{2, 1, 2, 3, 2, 4, 2, 3, 3, 3, 1, 4, 1, 1, 7, 5, 4, 10, 11},
	{
		"item_tango","item_circlet","item_circlet","item_faerie_fire","item_enchanted_mango","item_boots","item_diadem","item_phylactery","item_null_talisman","item_null_talisman","item_arcane_boots","item_blink","item_aether_lens","item_staff_of_wizardry","item_ogre_axe","item_blade_of_alacrity","item_ultimate_scepter","item_kaya","item_ethereal_blade","item_aghanims_shard","item_void_stone","item_ultimate_scepter_2","item_sheepstick","item_arcane_blink","item_octarine_core",
	},
	{ {3,3,3,3,1,}, {4,4,4,3,5,}, 0.1 },
	{
		"Telekinesis","Fade Bolt","Arcane Supremacy","Spell Steal","+150 Telekinesis Landing Damage","-12% Fade Bolt Damage Reduction","-25% Stolen Spells Cooldown","+0.4s Telekinesis Lift Duration","-5s Fade Bolt Cooldown","+240 Telekinesis Land Distance","-12s Telekinesis Cooldown","+40% Spell Amp For Stolen Spells",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"template_hurt1", ABILITY_TYPE.NUKE},
		{"template_ouch", ABILITY_TYPE.NUKE},
		{"template_slow", ABILITY_TYPE.NUKE},
		[5] = {"template_big_slow", ABILITY_TYPE.NUKE},

}

local ZEROED_VECTOR = ZEROED_VECTOR
local playerRadius = Set_GetEnemyHeroesInPlayerRadius
local ENCASED_IN_RECT = Set_GetEnemiesInRectangle
local currentTask = Task_GetCurrentTaskHandle
local GSI_AbilityCanBeCast = GSI_AbilityCanBeCast
local CROWDED_RATING = Set_GetCrowdedRatingToSetTypeAtLocation
local USE_ABILITY = UseAbility_RegisterAbilityUseAndLockToScore
local INCENTIVISE = Task_IncentiviseTask
local VEC_UNIT_DIRECTIONAL = Vector_UnitDirectionalPointToPoint
local VEC_UNIT_FACING_DIRECTIONAL = Vector_UnitDirectionalFacingDirection
local ACTIVITY_TYPE = ACTIVITY_TYPE
local currentActivityType = Blueprint_GetCurrentTaskActivityType
local currentTask = Task_GetCurrentTaskHandle
local HIGH_USE = AbilityLogic_HighUseAllowOffensive
local min = math.min

local fight_harass_handle = FightHarass_GetTaskHandle()
local push_handle = Push_GetTaskHandle()

local t_player_abilities = {}

local recent_nonsense
local recent_nonsense_is_enemy
Comm_RegisterCallbackFunc("RUBICK_RESPOND",
		function(event)
			if not IsPlayerBot(event.player_id) then
				recent_nonsense = event.string
				
				recent_nonsense_is_enemy = IsTeamPlayer(event.player_id)
			end
		end
	)
local function respond_rubickly(gsiPlayer)
	local chatLength = recent_nonsense and string.len(recent_nonsense)
	if recent_nonsense and string.len(recent_nonsense) >= 9
			and string.sub(recent_nonsense, 1, 7) == "rubick " then
		local _, afterYou = string.find(recent_nonsense, "you")
		afterYou = afterYou and afterYou < 12 and afterYou + 1 or 8
		gsiPlayer.hUnit:ActionImmediate_Chat("no you"..string.sub(recent_nonsense, afterYou, chatLength).."!",
				recent_nonsense_is_enemy or false)
		recent_nonsense = nil
	end
end

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
		if recent_nonsense then
			local roll = RandomInt(1,20)
			if roll == 6 then
				respond_rubickly(gsiPlayer)
			elseif roll == 1 then
				recent_nonsense = nil
			end
		end
		if AbilityLogic_PlaceholderGenericAbilityUse(gsiPlayer, t_player_abilities) then
			return
		elseif false then

		end
	end,
}

local hero_access = function(key) return d[key] end

do
	HeroData_SetHeroData(hero_data, abilities, hero_access, true)
end
