local hero_data = {
	"ancient_apparition",
	{3, 1, 3, 1, 1, 4, 2, 2, 2, 6, 2, 4, 1, 3, 7, 3, 4, 9, 11},
	{
		"item_tango","item_flask","item_flask","item_faerie_fire","item_faerie_fire","item_enchanted_mango","item_enchanted_mango","item_ward_sentry","item_enchanted_mango","item_boots","item_tranquil_boots","item_wind_lace","item_belt_of_strength","item_robe","item_ancient_janggo","item_boots_of_bearing","item_aghanims_shard","item_staff_of_wizardry","item_fluffy_hat","item_force_staff","item_ghost","item_kaya","item_kaya","item_ethereal_blade",
	},
	{ {1,1,1,3,5,}, {5,5,5,4,4,}, 0.1 },
	{
		"Cold Feet","Ice Vortex","Chilling Touch","Ice Blast","+200 Chilling Touch Attack Range","+40 Cold Feet Damage Per Second","-2s Ice Vortex Cooldown","+200 Cold Feet Breaking distance","-5% Ice Vortex Slow/Resistance","+80 Chilling Touch Damage","+450 AoE Cold Feet","+4% Ice Blast Kill Threshold",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_HERO_SELECTION then return hero_data end

local abilities = {
	[0] = {"ancient_apparition_cold_feet", ABILITY_TYPE.DEGEN + ABILITY_TYPE.NUKE + ABILITY_TYPE.STUN},
	{"ancient_apparition_ice_vortex", ABILITY_TYPE.SLOW + ABILITY_TYPE.DEGEN + ABILITY_TYPE.POINT_TARGET + ABILITY_TYPE.AOE},
	{"ancient_apparition_chilling_touch", ABILITY_TYPE.SLOW + ABILITY_TYPE.NUKE + ABILITY_TYPE.ATTACK_MODIFIER},
	[5] = {"ancient_apparition_ice_blast", ABILITY_TYPE.NUKE + ABILITY_TYPE.POINT_TARGET},
	[6] = {"ancient_apparition_ice_blast_release", ABILITY_TYPE.SECONDARY}
}

local I_B_TRACER_SPEED = 1500
local I_B_PROJECTILE_UPPER_TRAVEL_TIME = 1.75
local I_B_PROJECTILE_LOWER_TRAVEL_SPEED = 750
local I_B_DETECT_NON_STOP_START_DRIFT_AWAY = 1500 * 0.215 + 400
local I_B_USE_UPPER_TRAVEL_DIST = I_B_PROJECTILE_UPPER_TRAVEL_TIME * I_B_PROJECTILE_LOWER_TRAVEL_SPEED

local IBP_IN_OUT_UNSET = 0
local IBP_IN_OUT_START_IN = 1
local IBP_IN_OUT_MID = 2
local CONSIDER_INNER_MAP_DIST = 6300

local HIGH_USE_C_F_REMAINING_MANA = 60 + 175
local HIGH_USE_I_V_REMAINING_MANA = 125 + 75 + 175
local HIGH_USE_C_T_REMAINING_MANA = 125 + 175
local HIGH_USE_I_B_REMAINING_MANA = 125 + 60

local currentTask = Task_GetCurrentTaskHandle
local currentActivity = Blueprint_GetCurrentTaskActivityType
local ACTIVITY_TYPE = ACTIVITY_TYPE
local VERY_UNTHREATENING_UNIT = VERY_UNTHREATENING_UNIT
local USE_ABILITY = UseAbility_RegisterAbilityUseAndLockToScore
local HANDLE_AUTOCAST_GENERIC = AbilityLogic_HandleAutocastGeneric

local fight_harass_task_handle = FightHarass_GetTaskHandle()
local farm_lane_task_handle = FarmLane_GetTaskHandle()

local min = math.min
local max = math.max
local abs = math.abs

local t_player_abilities = {}

local ice_blast_parameters = {0, 0, ZEROED_VECTOR, ZEROED_VECTOR, 0} -- {timestampCast, distanceToStartTracking, originLoc, unitDirectional, closestEnemyDistSeenSinceLimit}

local function ice_blast_time_landing_with_distance(dist)
	return dist > I_B_USE_UPPER_TRAVEL_DIST and I_B_PROJECTILE_UPPER_TRAVEL_TIME or dist / I_B_PROJECTILE_LOWER_TRAVEL_SPEED
end

local function set_inner_to_outer(tracerLoc, sendTracerTime)
	local in_out_check = ice_blast_parameters[6]
	if max(abs(tracerLoc.x), abs(tracerLoc.y)) > CONSIDER_INNER_MAP_DIST then
		if in_out_check == IBP_IN_OUT_MID or sendTracerTime - GameTime() > 1 and tracerLoc.x > CONSIDER_INNER_MAP_DIST and tracerLoc.y > CONSIDER_INNER_MAP_DIST then
			return true
		elseif in_out_check == IBP_IN_OUT_UNSET then
			ice_blast_parameters[6] = IBP_IN_OUT_START_IN
		end
	else
		ice_blast_parameters[6] = IBP_IN_OUT_MID
	end
	return false
end

-- Will break on closest target uses blink away after limit is hit.
local function ice_blast_release_limit_loss_of_range(gsiPlayer, hAbility)
	if ice_blast_parameters[1] == 0 then return false
	elseif hAbility:IsHidden() then UseAbility_ClearQueuedAbilities(gsiPlayer) return false end
	local currTracerDist = (GameTime() - ice_blast_parameters[1]) * I_B_TRACER_SPEED
	--print("Tracking Ice Blast", currTracerDist, ice_blast_parameters[2])
	if currTracerDist > ice_blast_parameters[2] then -- tracer over limit that indicates we're near the player
		local currTracerLoc = Vector_Addition(
				ice_blast_parameters[3],
				Vector_ScalarMultiply2D(ice_blast_parameters[4], currTracerDist)
			)
		DebugDrawCircle(currTracerLoc, 150, 255,0,0)
--		if max(abs(currTraceLoc.x), abs(currTraceLoc.y)) > abs(GetWorldBounds()[1]*0.75) then -- tracer out of bounds?
--			ice_blast_parameters[1] = 0
--			if AbilityLogic_AbilityCanBeCast(gsiPlayer, hAbility) then 
--				UseAbility_RegisterAbilityUseAndLockToScore(gsiPlayer, hAbility, nil, 5000, nil, nil, true)
--			end
--			return true
--		end
		local closestHero = Set_GetNearestEnemyHeroToLocation(currTracerLoc)
		local closestHeroDist = closestHero and Math_PointToPointDistance2D(
				currTracerLoc, 
				closestHero.lastSeen.location
			) or 16000
		if set_inner_to_outer(currTracerLoc, ice_blast_parameters[1])
				or (closestHeroDist > 4000 and currTracerDist/ice_blast_parameters[2]>1.7) then
			if AbilityLogic_AbilityCanBeCast(gsiPlayer, hAbility) then --  If we see no enemies, release it near to 100% of the original extrapolated, (can be missed from 500-range vision tracer)
				ice_blast_parameters[1] = 0
				UseAbility_RegisterAbilityUseAndLockToScore(gsiPlayer, hAbility, nil, 5000, nil, nil, true)
				return true
			end
		end
		if not closestHero then return false end
		local extrapolatedAtExplosion = closestHero.hUnit:GetExtrapolatedLocation(ice_blast_time_landing_with_distance(currTracerDist)) -- May cause an early release if player changes direction suddenly. Relying on fast tracer speed for it to not be a problem
		local extrapolatedAtExplosionDist = Math_PointToPointDistance2D(currTracerLoc, extrapolatedAtExplosion)
		--print(string.format("iceblast: %.2f <= %.2f; %.2f < %.2f && %.2f < %.2f", extrapolatedAtExplosionDist, ice_blast_parameters[5], extrapolatedAtExplosionDist, 1000, abs(ice_blast_parameters[5] - extrapolatedAtExplosionDist), I_B_DETECT_NON_STOP_START_DRIFT_AWAY), 255, 255, 255)
		if extrapolatedAtExplosionDist <= ice_blast_parameters[5] then
			-- closer closer closer
			ice_blast_parameters[5] = extrapolatedAtExplosionDist
			if extrapolatedAtExplosionDist < 325 then
				if AbilityLogic_AbilityCanBeCast(gsiPlayer, hAbility) then
					print("RELEASED because", extrapolatedAtExplosionDist, ice_blast_parameters[5], currTracerLoc, "also", extrapolatedAtExplosion, currTracerDist)
					ice_blast_parameters[1] = 0
					UseAbility_RegisterAbilityUseAndLockToScore(gsiPlayer, hAbility, nil, 5000, nil, nil, true)
					return true
				end
			end
		elseif extrapolatedAtExplosionDist < 1000 and abs(ice_blast_parameters[5] - extrapolatedAtExplosionDist) < I_B_DETECT_NON_STOP_START_DRIFT_AWAY then -- release if the increase of closest found is from a player close to tracer
			-- further, and not sudden change. release!
			if AbilityLogic_AbilityCanBeCast(gsiPlayer, hAbility) then
				--print("RELEASED because", extrapolatedAtExplosionDist, ice_blast_parameters[5], currTracerDist, "also", extrapolatedAtExplosion, currTracerDist)
				ice_blast_parameters[1] = 0
				UseAbility_RegisterAbilityUseAndLockToScore(gsiPlayer, hAbility, nil, 5000, nil, nil, true)
				return true -- Releasing
			end
		end
	end
end

local function ice_blast_start_cast(gsiPlayer, target)
	local ibp = ice_blast_parameters
	local distanceToPlayerNow = Math_PointToPointDistance2D(gsiPlayer.lastSeen.location, target.lastSeen.location)
	local extrapolatedLocation = target.hUnit:GetExtrapolatedLocation(distanceToPlayerNow/I_B_TRACER_SPEED + ice_blast_time_landing_with_distance(distanceToPlayerNow))
	local unitDirectional = Vector_UnitDirectionalPointToPoint(gsiPlayer.lastSeen.location, extrapolatedLocation)
	local extrapolatedDistance = Math_PointToPointDistance2D(gsiPlayer.lastSeen.location, extrapolatedLocation)
	
	ibp[1] = GameTime() + 0.03
	ibp[2] = min(0.85, 0.0004*(extrapolatedDistance^2)/extrapolatedDistance)*extrapolatedDistance -- start tracking much earlier if they're close, do not start tracking any later than 60% of the way.
	ibp[3] = gsiPlayer.lastSeen.location
	ibp[4] = unitDirectional
	ibp[5] = ibp[5] + HIGH_32_BIT
	ibp[6] = IBP_IN_OUT_UNSET
	UseAbility_RegisterAbilityUseAndLockToScore(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam][4], extrapolatedLocation, 400)
end

local d
d = {
	["Initialize"] = function(gsiPlayer)
		AbilityLogic_CreatePlayerAbilitiesIndex(t_player_abilities, gsiPlayer, abilities)
		AbilityLogic_UpdateHighUseMana(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam])
	end,
	["InformLevelUpSuccess"] = function(gsiPlayer)
		AbilityLogic_UpdateHighUseMana(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam])
	end,
	["cold_feet_cast_range"] = {[0] = 1000, 700, 800, 900, 1000},
	["ColdFeetCastRange"] = function(gsiPlayer) return d.cold_feet_cast_range[t_player_abilities[gsiPlayer.nOnTeam][1]:GetLevel()] end,
	["chilling_touch_bonus_range"] = {[0] = 0, 60, 120, 180, 240},
	["ChillingTouchBonusRange"] = function(gsiPlayer) return d.chilling_touch_bonus_range[t_player_abilities[gsiPlayer.nOnTeam][3]:GetLevel()] end,
	["AttackRange"] = function(gsiPlayer) return gsiPlayer.hUnit:GetAttackRange() + t_player_abilities[gsiPlayer.nOnTeam][3]:GetAutoCastState() and d.ChillingTouchBonusRange(gsiPlayer) or 0 end,
	["AbilityThink"] = function(gsiPlayer)
		local thisPlayerAbilities = t_player_abilities[gsiPlayer.nOnTeam]
		local coldFeet = thisPlayerAbilities[1]
		local iceVortex = thisPlayerAbilities[2]
		local chillingTouch = thisPlayerAbilities[3]
		local iceBlast = thisPlayerAbilities[4]
		local iceBlastRelease = thisPlayerAbilities[5]
		local chillingTouchOnCd = chillingTouch:GetCooldownTimeRemaining() > 0 -- gsiPlayer.attackRange is updated when on
		local abilityLocked, _, abilityQueued = UseAbility_IsPlayerLocked(gsiPlayer) 
		local currTask = currentTask(gsiPlayer)
		local currActivityType = Blueprint_GetCurrentTaskActivityType(gsiPlayer)
		if (chillingTouchOnCd or currTask == farm_lane_task_handle) and chillingTouch:GetAutoCastState() then
			chillingTouch:ToggleAutoCast() -- off
			gsiPlayer.attackRange = gsiPlayer.hUnit:GetAttackRange()
		end

		HANDLE_AUTOCAST_GENERIC(gsiPlayer, chillingTouch)

		 -- Check if we need to release ice blast
		if abilityQueued ~= iceBlastRelease and ice_blast_release_limit_loss_of_range(gsiPlayer, iceBlastRelease) then
			return
		elseif not abilityLocked then
			local fightHarassTarget = Task_GetTaskObjective(gsiPlayer, fight_harass_task_handle)
			local playerManaPercent = gsiPlayer.lastSeenMana / gsiPlayer.maxMana

			if fightHarassTarget and not fightHarassTarget.typeIsNone then
				if currActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION then
					local targetStability = fightHarassTarget.hUnit:GetMovementDirectionStability()
					--print("aa stability cf", targetStability, fightHarassTarget.shortName)
					local targetHealthPercent = Unit_GetHealthPercent(fightHarassTarget)
					if AbilityLogic_AbilityCanBeCast(gsiPlayer, coldFeet) and targetStability < 0.2 and AbilityLogic_HighUseAllowOffensive(gsiPlayer, coldFeet, HIGH_USE_C_F_REMAINING_MANA, targetHealthPercent) then
						print(gsiPlayer.hUnit.Action_UseAbilityOnEntity)
						USE_ABILITY(gsiPlayer, coldFeet, fightHarassTarget, 400, nil, nil, nil, nil,
								gsiPlayer.hUnit.Action_UseAbilityOnEntity)
						return
					end
				end
				if fightHarassTarget and not fightHarassTarget.typeIsNone and fightHarassTarget.hUnit:HasModifier("modifier_cold_feet") and AbilityLogic_AbilityCanBeCast(gsiPlayer, iceVortex) then
					USE_ABILITY(gsiPlayer, iceVortex, fightHarassTarget.lastSeen.location, 400, nil)
					return
				end
			end
			local nearbyEnemies = Set_GetEnemyHeroesInPlayerRadius(gsiPlayer, coldFeet:GetCastRange())
			if AbilityLogic_AbilityCanBeCast(gsiPlayer, coldFeet) then
				for i=1,#nearbyEnemies do
					local thisEnemy = nearbyEnemies[i]
					if (thisEnemy.hUnit:IsRooted() or (thisEnemy.hUnit:IsStunned() and Unit_GetHealthPercent(thisEnemy) > 0.15)) and AbilityLogic_HighUseAllowOffensive(gsiPlayer, coldFeet, HIGH_USE_C_F_REMAINING_MANA, Unit_GetHealthPercent(thisEnemy)) then
						USE_ABILITY(gsiPlayer, coldFeet, thisEnemy, 400, nil)
						return
					end
				end
			end
			if fightHarassTarget and not fightHarassTarget.typeIsNone and AbilityLogic_AbilityCanBeCast(gsiPlayer, iceVortex) and not fightHarassTarget.hUnit:HasModifier("modifier_ice_vortex")
					and AbilityLogic_HighUseAllowOffensive(gsiPlayer, iceVortex, HIGH_USE_I_V_REMAINING_MANA, Unit_GetHealthPercent(fightHarassTarget)) then
				local nearestTower = Set_GetNearestTeamTowerToPlayer(TEAM, gsiPlayer)
				local towerLoc = nearestTower and nearestTower.lastSeen.location
				if nearestTower and Math_PointToPointDistance2D(fightHarassTarget.lastSeen.location, towerLoc) < 700 then
					USE_ABILITY(gsiPlayer, iceVortex, fightHarassTarget.lastSeen.location, 400, nil)
				end
				if currActivityType > ACTIVITY_TYPE.CAREFUL then
					if Set_GetEnemyHeroesInPlayerRadius(gsiPlayer, iceVortex:GetCastRange())[1] then
						if gsiPlayer.hUnit:GetMovementDirectionStability() > 0.1 then
							local infrontOfPlayer = Vector_Addition(
									gsiPlayer.lastSeen.location,
									Vector_ScalarMultiply2D(
										Vector_UnitDirectionalFacingDirection(gsiPlayer.hUnit:GetFacing()),
										175)
								)
							USE_ABILITY(gsiPlayer, iceVortex, infrontOfPlayer, 400, nil)
							return
						end
					end
				end
			end

			local playerHealthPercent = gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth
			local fightingHere, fightingElsewhere = Set_GetEnemyHeroesInPlayerRadiusAndOuter(gsiPlayer.lastSeen.location, 2500, 22000)
			if AbilityLogic_AbilityCanBeCast(gsiPlayer, iceBlast) and gsiPlayer.lastSeenMana - iceBlast:GetManaCost() > 0 then
				if #fightingHere > 0 or #fightingElsewhere > 0 then 
					local lowestFightingHere = Unit_LowestHealthPercentPlayer(fightingHere)
					if lowestFightingHere then
						local fightingHerePercentHealth = lowestFightingHere.lastSeenHealth / lowestFightingHere.maxHealth
						local fightingHereStability = lowestFightingHere.hUnit:GetMovementDirectionStability()
						if (fightingHerePercentHealth < 0.311 and fightingHereStability > 0.6
								and AbilityLogic_HighUseAllowOffensive(gsiPlayer, iceBlast, HIGH_USE_I_B_REMAINING_MANA, fightingHerePercentHealth)) or playerHealthPercent < 0.2 then
							ice_blast_start_cast(gsiPlayer, lowestFightingHere)
						end
					else
						local lowestFightingElsewhere = Unit_LowestHealthPercentPlayer(fightingElsewhere)
						local fightingElsewhereStability = lowestFightingElsewhere and lowestFightingElsewhere.hUnit:GetMovementDirectionStability() or 0
						if fightingElsewhereStability > 0.6 then
							local fightingElsewherePercentHealth = lowestFightingElsewhere.lastSeenHealth / lowestFightingElsewhere.maxHealth
							-- Shoot far players if you have the mana, you see that they're low, or you're walking back to fountain and hate someone
							if (fightingElsewherePercentHealth < 0.3 or (#fightingHere == 0 and currTask == IncreaseSafety_GetTaskHandle()))
									and lowestFightingElsewhere.hUnit:GetMovementDirectionStability() > 0.8
									and AbilityLogic_HighUseAllowOffensive(gsiPlayer, iceBlast, HIGH_USE_I_B_REMAINING_MANA, fightingElsewherePercentHealth) then
								ice_blast_start_cast(gsiPlayer, lowestFightingElsewhere)
							end
						end
					end
				end
			end
		--	if chillingTouchOnCd then return end 
		--	if (playerManaPercent > 0.95 and currActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION) or AbilityLogic_HighUseAllowOffensive(gsiPlayer, chillingTouch, HIGH_USE_C_T_REMAINING_MANA, 1.0) then -- consider using when dying
		--		if not chillingTouch:GetAutoCastState() then
		--			chillingTouch:ToggleAutoCast() -- on
		--			gsiPlayer.attackRange = gsiPlayer.hUnit:GetAttackRange() + d.chilling_touch_bonus_range[chillingTouch:GetLevel()]
		--			return
		--		end
		--	elseif fightHarassTarget and currActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION then 
		--		local fightHarassPercentHealth = fightHarassTarget.lastSeenHealth / fightHarassTarget.maxHealth
		--		local highUseAllow = AbilityLogic_HighUseAllowOffensive(gsiPlayer, chillingTouch, HIGH_USE_C_T_REMAINING_MANA, fightHarassPercentHealth)
		--		if chillingTouch:GetAutoCastState() and not highUseAllow then
		--			chillingTouch:ToggleAutoCast() -- Enemies or me high health / remaining mana, off
		--			gsiPlayer.attackRange = gsiPlayer.hUnit:GetAttackRange()
		--			return
		--		elseif not chillingTouch:GetAutoCastState() and highUseAllow then
		--			chillingTouch:ToggleAutoCast() -- on for cliffhanger game states
		--			gsiPlayer.attackRange = gsiPlayer.hUnit:GetAttackRange() + d.chilling_touch_bonus_range[chillingTouch:GetLevel()]
		--			return
		--		end
		--	elseif chillingTouch:GetAutoCastState() then
		--		chillingTouch:ToggleAutoCast() -- off
		--		gsiPlayer.attackRange = gsiPlayer.hUnit:GetAttackRange()
		--		return
		--	end	
		end
	end
}
local hero_access = function(key) return d[key] end

do
	HeroData_SetHeroData(hero_data, abilities, hero_access)
end
