local hero_data = {
	"lich",
	{1, 2, 1, 2, 2, 4, 2, 3, 3, 3, 5, 4, 1, 3, 7, 1, 4, 10},
	{
		"item_ward_sentry","item_magic_stick","item_tango","item_clarity","item_enchanted_mango","item_boots","item_wind_lace","item_tranquil_boots","item_bracer","item_cloak","item_shadow_amulet","item_glimmer_cape","item_aghanims_shard","item_staff_of_wizardry","item_fluffy_hat","item_force_staff","item_aghanims_shard","item_ghost","item_buckler","item_ring_of_basilius","item_blades_of_attack","item_vladmir",
	},
	{ {1,1,1,1,4,}, {5,5,5,5,5,}, 0.1 },
	{
		"Frost Blast","Frost Shield","Sinister Gaze","Chain Frost","+10% Frost Shield Damage Reduction","+150 Frost Blast Radius and Damage","+0.5s Sinister Gaze Duration","-3s Frost Blast Cooldown","+100 Chain Frost Damage","+4s Frost Shield Duration","Frost Shield Provides +50 HP Regen","Chain Frost Unlimited Bounces",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_HERO_SELECTION then return hero_data end

local abilities = {
		[0] = {"lich_frost_nova", ABILITY_TYPE.NUKE + ABILITY_TYPE.SLOW + ABILITY_TYPE.AOE},
		{"lich_frost_shield", ABILITY_TYPE.BUFF + ABILITY_TYPE.SHIELD},
		{"lich_sinister_gaze", ABILITY_TYPE.STUN},
		{"lich_ice_spire", ABILITY_TYPE.SUMMON + ABILITY_TYPE.SLOW + ABILITY_TYPE.AOE},
		[5] = {"lich_chain_frost", ABILITY_TYPE.NUKE + ABILITY_TYPE.AOE},
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
local ACTIVITY_TYPE = ACTIVITY_TYPE
local currentActivityType = Blueprint_GetCurrentTaskActivityType
local currentTask = Task_GetCurrentTaskHandle
local HIGH_USE = AbilityLogic_HighUseAllowOffensive

local fight_harass_handle = FightHarass_GetTaskHandle()
local push_handle = Push_GetTaskHandle()

local t_player_abilities = {}

local ABILITY_USE_RANGE = 800
local OUTER_RANGE = 1600

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
		if UseAbility_IsPlayerLocked(gsiPlayer) then
			if not AbilityLogic_DetectUnsafeChannels(gsiPlayer, "lich_sinister_gaze") then
				return
			end
		end
		local playerAbilities = t_player_abilities[gsiPlayer.nOnTeam]
		local frostBlast = playerAbilities[1]
		local frostShield = playerAbilities[2]
		local sinisterGaze = playerAbilities[3]
		local chainFrost = playerAbilities[5]
		local highUse = gsiPlayer.highUseManaSimple
		local playerHealthPercent = gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth

		local currActivityType = currentActivityType(gsiPlayer)
		local currTask = currentTask(gsiPlayer)
		local playerLoc = gsiPlayer.lastSeen.location
		local nearbyEnemies, outerEnemies
				= Set_GetEnemyHeroesInLocRadOuter(playerLoc, chainFrost:GetCastRange(), OUTER_RANGE, 6)
		local fightHarassTarget = Task_GetTaskObjective(gsiPlayer, fight_harass_handle)
		local fhtReal = fightHarassTarget
				and fightHarassTarget.hUnit.IsNull and not fightHarassTarget.hUnit:IsNull()
		local fhtPercHp = fightHarassTarget
				and fightHarassTarget.lastSeenHealth / fightHarassTarget.maxHealth or 1.0
		local nearestEnemy = Set_GetNearestEnemyHeroToLocation(playerLoc)
		local crowdingCenter, crowdedRating
				= CROWDED_RATING(nearestEnemy and nearestEnemy.lastSeen.location or playerLoc, SET_ALL_ENEMY)
		if nearestEnemy and AbilityLogic_AbilityCanBeCast(gsiPlayer, frostShield) then
			local nearestAllied = Set_GetNearestAlliedHeroToLocation(nearestEnemy.lastSeen.location)
			local alliedPercHp = nearestAllied.lastSeenHealth / nearestAllied.maxHealth
			if HIGH_USE(gsiPlayer, frostShield, highUse - frostShield:GetManaCost(), alliedPercHp)
					and (nearestAllied.hUnit:IsFacingLocation(crowdingCenter, 135)
						and Math_PointToPointDistance2D(nearestAllied.lastSeen.location, crowdingCenter)
							< frostShield:GetSpecialValueInt("radius") + 150
						)
					or FightClimate_AnyIntentToHarm(nearestAllied, nearbyEnemies)
					or FightClimate_AnyIntentToHarm(nearestAllied, outerEnemies) then
				USE_ABILITY(gsiPlayer, frostShield, nearestAllied, 400, nil)
				Task_IncentiviseTask(nearestAllied, fight_harass_handle, 10, 2)
				return;
			end
		end
		if AbilityLogic_AbilityCanBeCast(gsiPlayer, chainFrost)
				and gsiPlayer.lastSeenMana > chainFrost:GetManaCost()
				and (currActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION
					or currActivityType > ACTIVITY_TYPE.CAREFUL
				) and nearestEnemy and crowdedRating > 1.5 + 1.5*playerHealthPercent then
			USE_ABILITY(gsiPlayer, chainFrost, nearestEnemy, 400, nil)
			return;
		end
		if currActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION and fhtReal then
			if AbilityLogic_AbilityCanBeCast(gsiPlayer, frostBlast)
					and HIGH_USE(gsiPlayer, frostBlast, highUse - frostBlast:GetManaCost(), fhtPercHp) then
				USE_ABILITY(gsiPlayer, frostBlast, fightHarassTarget, 400, nil)
				return;
			end
			if AbilityLogic_AbilityCanBeCast(gsiPlayer, sinisterGaze)
					and HIGH_USE(gsiPlayer, sinisterGaze, highUse - sinisterGaze:GetManaCost(), fhtPercHp) then
				-- TODO Should be hero with stun available > most dangerous
				local mostDangerous = Analytics_GetMostDangerousEnemy(gsiPlayer, nearbyEnemies)
				if mostDangerous and mostDangerous.hUnit.IsNull and not mostDangerous.hUnit:IsNull() then
					USE_ABILITY(gsiPlayer, sinisterGaze, mostDangerous, 400, nil)
					return;
				end
			end
		end
		if currActivityType > ACTIVITY_TYPE.CAREFUL
				and nearbyEnemies[1] and AbilityLogic_AbilityCanBeCast(gsiPlayer, frostBlast)
				and HIGH_USE(gsiPlayer, frostBlast, highUse - frostBlast:GetManaCost(), playerHealthPercent) then
			if nearbyEnemies[1].hUnit.IsNull and not nearbyEnemies[1].hUnit:IsNull() then
				USE_ABILITY(gsiPlayer, frostBlast, nearbyEnemies[1], 400, nil)
				return;
			end
		end
		if currTask == push_handle and AbilityLogic_AbilityCanBeCast(gsiPlayer, frostBlast)
				and HIGH_USE(gsiPlayer, frostBlast, (highUse - frostBlast:GetManaCost())*2.5, 1-playerHealthPercent) then 
			local nearbyCreeps = Set_GetNearestEnemyCreepSetAtLaneLoc(
					gsiPlayer.lastSeen.location, Map_GetBaseOrLaneLocation(gsiPlayer.lastSeen.location)
				)
			if nearbyCreeps then
				local thisCreep
				for i=1,#nearbyCreeps do
					-- haha, secretary problem for melee creeps / lots of range creeps found
					if thisCreep.creepType ~= CREEP_TYPE_SIEGE then
						thisCreep = nearbyCreep[i]
						break;
					end
				end
				if thisCreep then
					USE_ABILITY(gsiPlayer, frostBlast, thisCreep, 400, nil)
					return;
				end
			end
		end
	end,
}

local hero_access = function(key) return d[key] end

do
	HeroData_SetHeroData(hero_data, abilities, hero_access)
end
