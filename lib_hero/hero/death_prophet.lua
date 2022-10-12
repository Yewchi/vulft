local hero_data = {
	"death_prophet",
	{1, 3, 3, 1, 3, 4, 1, 1, 2, 5, 3, 4, 2, 2, 7, 2, 4, 9, 12},
	{
		"item_tango","item_circlet","item_branches","item_faerie_fire","item_branches","item_mantle","item_null_talisman","item_boots","item_magic_wand","item_gloves","item_robe","item_power_treads","item_blades_of_attack","item_falcon_blade","item_platemail","item_mystic_staff","item_shivas_guard","item_wind_lace","item_blink","item_void_stone","item_cyclone","item_aghanims_shard","item_mystic_staff","item_wind_waker","item_void_stone","item_energy_booster","item_soul_booster","item_octarine_core",
	},
	{ {3,3,3,2,1,}, {3,3,3,2,1,}, 0.1 },
	{
		"Crypt Swarm","Silence","Spirit Siphon","Exorcism","+30 Damage","+12% Magic Resistance","+30 Spirit Siphon Damage/Heal","-2.0s Crypt Swarm Cooldown","20.0% Spirit Siphon Move Speed Slow","+400 Health","-20s Spirit Siphon Replenish Time","+8 Exorcism Spirits",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"death_prophet_carrion_swarm", ABILITY_TYPE.NUKE + ABILITY_TYPE.AOE},
		{"death_prophet_silence", ABILITY_TYPE.DEGEN + ABILITY_TYPE.AOE},
		{"death_prophet_spirit_siphon", ABILITY_TYPE.NUKE + ABILITY_TYPE.DEGEN + ABILITY_TYPE.HEAL},
		[5] = {"death_prophet_exorcism", ABILITY_TYPE.BUFF},
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

local SILENCE_MAX_HIT_RANGE = 900 + 425
local SILENCE_TRAVEL_SPEED = 1000
local CRYPT_SWARM_RANGE = 1110

local push_handle = Push_GetTaskHandle()
local fight_harass_handle = FightHarass_GetTaskHandle()
local zonedef_handle = ZoneDefend_GetTaskHandle()

local t_player_abilities = {}

local SIPHON_BREAK_RANGE = 750

local function try_spirit_siphon_target(gsiPlayer, hAbility, target)
	local targetHpp = target.lastSeenHealth / target.maxHealth
	local distToTarget = VEC_POINT_DISTANCE(gsiPlayer.lastSeen.location, target.lastSeen.location)
	local easeOfMaintainingLink = max(1, target.currentMovementSpeed - gsiPlayer.currentMovementSpeed)
	local timeToGetAway = max(0,
			(SIPHON_BREAK_RANGE-distToTarget)/easeOfMaintainingLink
				+ 0.1*(1+Vector_UnitFacingUnit(gsiPlayer, target))
		)
	print("ttga siphon", max(0,
			(SIPHON_BREAK_RANGE-distToTarget)/easeOfMaintainingLink
				+ 0.1*(1+Vector_UnitFacingUnit(gsiPlayer, target))
		), (SIPHON_BREAK_RANGE-distToTarget), easeOfMaintainingLink, 0.1*(1+Vector_UnitFacingUnit(gsiPlayer, target)))
	if timeToGetAway > 0
			and HIGH_USE(gsiPlayer, hAbility, gsiPlayer.highUseManaSimple, targetHpp) then
		USE_ABILITY(gsiPlayer, hAbility, target, 400, nil)
		return true;
	end
end

local d
d = {
	["crypt_swarm_damage"] = {[0] = 300, 75, 150, 225, 300},
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
			return;
		end
		local playerAbilities = t_player_abilities[gsiPlayer.nOnTeam]
		local cryptSwarm = playerAbilities[1]
		local silence= playerAbilities[2]
		local siphon = playerAbilities[3]
		local exorcism = playerAbilities[4]

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

		local distToFht = fht and VEC_POINT_DISTANCE(playerLoc, fhtLoc)

		local nearbyEnemies, outerEnemies = NEARBY_OUTER(playerLoc, siphon:GetCastRange(),
				SILENCE_MAX_HIT_RANGE, 2
			)

		local fhtMgkDmgFactor = fhtReal and SPELL_SUCCESS(gsiPlayer, fht, cryptSwarm)

		local arbitraryEnemy = nearbyEnemies[1] or outerEnemies[1]

		if CAN_BE_CAST(gsiPlayer, silence) then
			if fhtReal and currentActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION
					and fhtMgkDmgFactor > 0
					and (distToFht > gsiPlayer.attackRange
							or fht.lastSeenHealth > playerHUnit:GetAttackDamage()
									* Unit_GetArmorPhysicalFactor(fht)
							or cryptSwarm:GetCooldownTimeRemaining() ~= 0
							or fht.lastSeenHealth > d.crypt_swarm_damage[cryptSwarm:GetLevel()]
									* fhtMgkDmgFactor
						) then
				local extrapolatedSeconds = distToFht / SILENCE_TRAVEL_SPEED
				local extrapolatedFht = fhtHUnit:GetExtrapolatedLocation(extrapolatedSeconds)
				-- Loosely uses the extended range of the circle at the cast location, may miss
				if VEC_POINT_DISTANCE(playerLoc, extrapolatedFht) < SILENCE_MAX_HIT_RANGE*0.9 then
					local crowdedCenter, crowdedRating = CROWDED_RATING(extrapolatedFht, SET_HERO_ENEMY)
					if crowdedRating > 1.5 then -- if / else, save it for more enemies, with bugs
						if VEC_POINT_DISTANCE(playerLoc, crowdedCenter) < silence:GetCastRange()
								and HIGH_USE(gsiPlayer, silence, highUse, fhtHpp/crowdedRating) then
							USE_ABILITY(gsiPlayer, silence, crowdedCenter, 400, nil)
							return;
						end
					elseif HIGH_USE(gsiPlayer, silence, highUse, fhtHpp) then
						USE_ABILITY(gsiPlayer, silence, extrapolatedFht, 400, nil)
						return;
					end
				end
			else
				-- TODO Spell immunity crowded check missed -- write set function
				if currentActivityType >= ACTIVITY_TYPE.FEAR
						and arbitraryEnemy
						and HIGH_USE(gsiPlayer, silence, highUse, playerHpp) then
					local crowdedCenter, crowdedRating = CROWDED_RATING(
							arbitraryEnemy.lastSeen.location, SET_HERO_ENEMY
						)
					if VEC_POINT_DISTANCE(playerLoc, crowdedCenter) < silence:GetCastRange() then
						USE_ABILITY(gsiPlayer, silence, crowdedCenter, 400, nil)
						return;
					end
				end
			end
		end
		if CAN_BE_CAST(gsiPlayer, siphon) then
			if currentActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION then
				if fhtReal and fhtMgkDmgFactor > 0
						and try_spirit_siphon_target(gsiPlayer, siphon, fht) then
					return;
				else
					for i=1,#nearbyEnemies do
						local thisEnemy = nearbyEnemies[i]
						if thisEnemy ~= fht and SPELL_SUCCESS(gsiPlayer, thisEnemy, siphon) > 0
								and try_spirit_siphon_target(gsiPlayer, siphon, thisEnemy) then
							return;
						end
					end
				end
			elseif arbitraryEnemy and currentActivityType >= ACTIVITY_TYPE.FEAR then
				for i=1,#nearbyEnemies do
					local thisEnemy = nearbyEnemies[i]
					if SPELL_SUCCESS(gsiPlayer, thisEnemy, siphon) > 0
							and try_spirit_siphon_target(gsiPlayer, siphon, thisEnemy) then
						return;
					end
				end
			end
		end
		if CAN_BE_CAST(gsiPlayer, cryptSwarm) then
			if fhtReal and currentActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION
					and fhtMgkDmgFactor > 0 then
				-- TODO
				local extrapolatedFht = fhtHUnit:GetExtrapolatedLocation(0.5)
				-- Loosely uses the extended range of the circle at the cast location, may miss
				if VEC_POINT_DISTANCE(playerLoc, extrapolatedFht) < CRYPT_SWARM_RANGE*0.9 then
					local crowdedCenter, crowdedRating = CROWDED_RATING(extrapolatedFht, SET_HERO_ENEMY)
					if crowdedRating > 1.5 then -- if / else, save it for more enemies, with bugs
						if VEC_POINT_DISTANCE(playerLoc, crowdedCenter) < CRYPT_SWARM_RANGE
								and HIGH_USE(gsiPlayer, cryptSwarm, highUse, fhtHpp/crowdedRating) then
							USE_ABILITY(gsiPlayer, cryptSwarm, crowdedCenter, 400, nil)
							return;
						end
					elseif HIGH_USE(gsiPlayer, cryptSwarm, highUse, fhtHpp) then
						USE_ABILITY(gsiPlayer, cryptSwarm, extrapolatedFht, 400, nil)
						return;
					end
				end
			end
			print("dp cs push", currentTask, HIGH_USE(gsiPlayer, cryptSwarm,
							0 or max(highUse, highUse*(2-Analytics_GetTheoreticalDangerAmount(gsiPlayer)*0.5)),
							1-playerHpp
						))
			if (currentTask == push_handle or currentTask == zonedef_handle)
					and HIGH_USE(gsiPlayer, cryptSwarm,
							0 or max(highUse, highUse*(2-Analytics_GetTheoreticalDangerAmount(gsiPlayer)*0.5)),
							1-playerHpp
						) then
				local nearbyEnemyCreepSet = Set_GetNearestEnemyCreepSetToLocation(playerLoc)
				if nearbyEnemyCreepSet and nearbyEnemyCreepSet.units[1] then
					local crowdedCenter, crowdedRating = CROWDED_RATING(nearbyEnemyCreepSet.center, SET_CREEP_ENEMY)
					if crowdedRating > 2 and VEC_POINT_DISTANCE(playerLoc, crowdedCenter) then
						USE_ABILITY(gsiPlayer, cryptSwarm, crowdedCenter, 400, nil)
						return;
					end
				end
			end
		end
		if CAN_BE_CAST(gsiPlayer, exorcism) then
			if (fhtReal and currentActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION
							and distToFht < 900
					) or (currentTask == push_handle and playerHUnit:GetAttackTarget()
							and playerHUnit:GetAttackTarget():IsBuilding()
					) then
				USE_ABILITY(gsiPlayer, exorcism, nil, 400, nil)
				return;
			end
		end
	end,
}

local hero_access = function(key) return d[key] end

do
	HeroData_SetHeroData(hero_data, abilities, hero_access)
end


