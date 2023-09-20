local hero_data = {
	"silencer",
	{1, 2, 1, 3, 1, 4, 1, 3, 3, 5, 3, 4, 2, 2, 7, 2, 4, 10},
	{
		"item_magic_stick","item_tango","item_faerie_fire","item_circlet","item_branches","item_ward_observer","item_null_talisman","item_magic_wand","item_boots","item_fluffy_hat","item_staff_of_wizardry","item_force_staff","item_robe","item_power_treads","item_blade_of_alacrity","item_belt_of_strength","item_hurricane_pike","item_aghanims_shard","item_ultimate_orb","item_sheepstick","item_gem","item_sphere",
	},
	{ {1,1,1,3,3,}, {5,5,5,4,4,}, 0.1 },
	{
		"Arcane Curse","Glaives of Wisdom","Last Word","Global Silence","+10 Arcane Curse Damage","+20 Attack Speed","-20.0s Global Silence Cooldown","+0.8x Last Word Int Multiplier","+1 Glaives of Wisdom Bounce","Arcane Curse Undispellable","+25% Glaives of Wisdom Damage","Last Word Mutes",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"silencer_curse_of_the_silent", ABILITY_TYPE.NUKE + ABILITY_TYPE.AOE + ABILITY_TYPE.SLOW},
		{"silencer_glaives_of_wisdom", ABILITY_TYPE.ATTACK_MODIFIER},
		{"silencer_last_word", ABILITY_TYPE.NUKE + ABILITY_TYPE.DEGEN},
		[5] = {"silencer_global_silence", ABILITY_TYPE.DEGEN + ABILITY_TYPE.UTILITY},
}

local ZEROED_VECTOR = ZEROED_VECTOR
local playerRadius = Set_GetEnemyHeroesInPlayerRadius
local ENCASED_IN_RECT = Set_GetEnemiesInRectangle
local CURRENT_TASK = Task_GetCurrentTaskHandle
local CAN_BE_CAST = AbilityLogic_AbilityCanBeCast
local CHARGE_CAN_BE_CAST = ChargedCooldown_AbilityCanBeCast
local USE_ABILITY = UseAbility_RegisterAbilityUseAndLockToScore
local VEC_POINT_DISTANCE = Vector_PointDistance
local VEC_UNIT_DIRECTIONAL = Vector_UnitDirectionalPointToPoint
local ACTIVITY_TYPE = ACTIVITY_TYPE
local HANDLE_AUTOCAST_GENERIC = AbilityLogic_HandleAutocastGeneric
local AOHK = AbilityLogic_AllowOneHitKill
local ANY_HARM = FightClimate_AnyIntentToHarm
local CURRENT_ACTIVITY_TYPE = Blueprint_GetCurrentTaskActivityType
local TASK_OBJECTIVE = Task_GetTaskObjective
local HEALTH_PERCENT = Unit_GetHealthPercent
local SET_ENEMY_HERO = SET_ENEMY_HERO
local ABILITY_LOCKED = UseAbility_IsPlayerLocked
local CROWDED_RATING = Set_GetCrowdedRatingToSetTypeAtLocation
local NEARBY_OUTER = Set_GetEnemyHeroesInPlayerRadiusAndOuter
local NEARBY_ENEMY = Set_GetEnemyHeroesInPlayerRadius
local HIGH_USE = AbilityLogic_HighUseAllowOffensive
local SPELL_SUCCESS = AbilityLogic_CastOnTargetWillSucceed
local max = math.max
local min = math.min
local sqrt = math.sqrt

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
		if AbilityLogic_PlaceholderGenericAbilityUse(gsiPlayer, t_player_abilities) or true then
			return
		end
		if UseAbility_IsPlayerLocked(gsiPlayer) then
			return;
		end
		local playerAbilities = t_player_abilities[gsiPlayer.nOnTeam]
		local arcaneCurse = playerAbilities[1]
		local glaives = playerAbilities[2]
		local lastWord = playerAbilities[3]
		local silence = playerAbilities[4]

		local highUse = gsiPlayer.highUseManaSimple
		local currentTask = CURRENT_TASK(gsiPlayer)
		local currentActivityType = CURRENT_ACTIVITY_TYPE(gsiPlayer)
		local fht = TASK_OBJECTIVE(gsiPlayer, fight_harass_handle)
		local fhtReal = fht and fht.hUnit.IsNull and not fht.hUnit:IsNull()
		local fhtHUnit = fhtReal and fht.hUnit
		local fhtHpp = fht and fht.lastSeenHealth / fht.maxHealth
		local fhtLoc = fht and fht.lastSeen.location

		local playerHUnit = gsiPlayer.hUnit
		local playerLoc = gsiPlayer.lastSeen.location
		local playerHpp = HEALTH_PERCENT(gsiPlayer)

		Task_IncentiviseTask(gsiPlayer, fight_harass_handle, 300, 1)

		local distToFht = fht and VEC_POINT_DISTANCE(playerLoc, fhtLoc)

		local nearbyEnemies, outerEnemies = NEARBY_OUTER(playerLoc, rift:GetCastRange(), 1200, 2)

		local danger = Analytics_GetTheoreticalDangerAmount(gsiPlayer)

		local arbitraryEnemy = nearbyEnemies[1] or outerEnemies[1]

	end,
}

local hero_access = function(key) return d[key] end

do
	HeroData_SetHeroData(hero_data, abilities, hero_access)
end


