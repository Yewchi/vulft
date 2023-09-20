local hero_data = {
	"ancient_apparition",
	{3, 2, 3, 2, 2, 4, 2, 1, 3, 5, 1, 4, 1, 3, 7, 1, 4, 9, 11},
	{
		"item_tango","item_branches","item_magic_stick","item_blood_grenade","item_enchanted_mango","item_ward_observer","item_boots","item_tranquil_boots","item_wind_lace","item_magic_wand","item_shadow_amulet","item_glimmer_cape","item_ghost","item_gem","item_aether_lens","item_gem","item_staff_of_wizardry","item_gem","item_kaya","item_gem","item_ethereal_blade","item_gem","item_gem","item_ultimate_orb","item_cornucopia","item_sphere","item_gem",
	},
	{ {3,3,3,1,1,}, {4,4,4,5,5,}, 0.1 },
	{
		"Cold Feet","Ice Vortex","Chilling Touch","Ice Blast","+300 Chilling Touch Attack Range","+40 Cold Feet Damage Per Second","-2s Ice Vortex Cooldown","+300 Cold Feet Breaking distance","+4s Ice Vortex Duration","+80 Chilling Touch Damage","+450 AoE Cold Feet","+4% Ice Blast Kill Threshold",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

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
local HIGH_USE = AbilityLogic_HighUseAllowOffensive
local USE_ABILITY = UseAbility_RegisterAbilityUseAndLockToScore
local HANDLE_AUTOCAST_GENERIC = AbilityLogic_HandleAutocastGeneric

local fight_harass_task_handle = FightHarass_GetTaskHandle()
local farm_lane_task_handle = FarmLane_GetTaskHandle()

local min = math.min
local max = math.max
local abs = math.abs

local t_player_abilities = {}
local t_ice_vortex_locations = {}
for i=1,TEAM_NUMBER_OF_PLAYERS do
	t_ice_vortex_locations[i] = {}
end

local ice_blast_parameters = {0, 0, ZEROED_VECTOR, ZEROED_VECTOR, 0} -- {timestampCast, distanceToStartTracking, originLoc, unitDirectional, closestEnemyDistSeenSinceLimit}

local function ice_blast_time_landing_with_distance(dist)
	return dist > I_B_USE_UPPER_TRAVEL_DIST and I_B_PROJECTILE_UPPER_TRAVEL_TIME or max(0, (dist-200)) / I_B_PROJECTILE_LOWER_TRAVEL_SPEED
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
					print("AA RELEASED because", extrapolatedAtExplosionDist, ice_blast_parameters[5], currTracerLoc, "also", extrapolatedAtExplosion, currTracerDist)
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

local function ice_blast_start_cast(gsiPlayer, target, useLoc)
	local ibp = ice_blast_parameters
	local distanceToPlayerNow = Math_PointToPointDistance2D(gsiPlayer.lastSeen.location, useLoc or target.lastSeen.location)
	local extrapolatedLocation = target.hUnit:GetExtrapolatedLocation(distanceToPlayerNow/I_B_TRACER_SPEED + ice_blast_time_landing_with_distance(distanceToPlayerNow))
	extrapolatedLocation = useLoc and Vector_PointBetweenPoints(extrapolatedLocation, useLoc)
				or extrapolatedLocation
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

local function remove_ice_vortex(gsiPlayer)
	local ivTbl = t_ice_vortex_locations[gsiPlayer.nOnTeam]
	local currTime = GameTime()
	local i = 1
	while(i<#ivTbl) do
		if ivTbl[i][2] < currTime then
			table.remove(ivTbl, i)
		else
			i = i + 1
		end
	end
end

local function correct_ice_vortex(gsiPlayer, iceVortex, location, radius)
	local ivTbl = t_ice_vortex_locations[gsiPlayer.nOnTeam]
	radius = radius or iceVortex:GetSpecialValueInt("radius") + 50
	for i=1,#ivTbl do
		local thisLoc = ivTbl[i][1]
		if Vector_PointDistance2D(location, thisLoc) > radius then
			return nil
		end
	end
	table.insert(ivTbl, {location, GameTime() + iceVortex:GetSpecialValueFloat("vortex_duration")})
	return location
end

-- TODO "Initialize()" needs to work for enemies, and the data is wanted anyways.
-- rubick enters the ability run func, pretends he's the hero, and hooks CAN_BE_CAST
-- so that if it asks for any spell besides his stolen spell it responds with false.
-- Means that player abilities tables need to be removed, or made to two teams.
-- they are practically useless anyways.
		SpecialBehavior_RegisterBehavior("useItemArmletOverride",
				function(gsiPlayer, hItem)
					local hUnit = gsiPlayer.hUnit
					if hUnit:HasModifier("modifier_ancient_apparition_ice_blast") then
						local modIndex = hUnit:GetModifierByName("modifier_ancient_apparition_ice_blast")
						local remainingTime = hUnit:GetModifierRemainingDuration(modIndex)
						if hItem:GetToggleState() and gsiPlayer.lastSeenHealth then
							local aa = GSI_GetPlayerByName("ancient_apparition")
							local aaIceBlastLevel = not aa and 2
									or math.max(1, math.min(3, math.floor(aa.level/6)))
							local dps = ITEM_ARMLET_HEALTH_DRAIN_PER_SECOND + d.ice_blast_dps[aaIceBlastLevel]
							if ( ( gsiPlayer.lastSeenHealth - dps * remainingTime)
											/ gsiPlayer.maxHealth
										) - d.ice_blast_kill_percent[aaIceBlastLevel]
									< 0 then
								return true
							elseif gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth > 0.5 then
								return false
							end
						else
							return false
						end
					end
					return nil
				end
			)

local d
d = {
	["Initialize"] = function(gsiPlayer)
		AbilityLogic_CreatePlayerAbilitiesIndex(t_player_abilities, gsiPlayer, abilities)
		AbilityLogic_UpdateHighUseMana(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam])
		gsiPlayer.InformLevelUpSuccess = d.InformLevelUpSuccess
	end,
	["InformLevelUpSuccess"] = function(gsiPlayer)
		AbilityLogic_UpdateHighUseMana(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam])
		AbilityLogic_UpdatePlayerAbilitiesIndex(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam], abilities)
	end,
	["cold_feet_cast_range"] = {[0] = 1000, 700, 800, 900, 1000},
	["ColdFeetCastRange"] = function(gsiPlayer) return d.cold_feet_cast_range[t_player_abilities[gsiPlayer.nOnTeam][1]:GetLevel()] end,
	["chilling_touch_bonus_range"] = {[0] = 0, 60, 120, 180, 240},
	["ChillingTouchBonusRange"] = function(gsiPlayer) return d.chilling_touch_bonus_range[t_player_abilities[gsiPlayer.nOnTeam][3]:GetLevel()] end,
	["ice_blast_dps"] = {[0] = 32, 12.5, 20, 32}, -- 7.32e
	["ice_blast_kill_percent"] = {[0] = 14, 12, 13, 14}, -- 7.32e
	["AttackRange"] = function(gsiPlayer) return gsiPlayer.hUnit:GetAttackRange() + t_player_abilities[gsiPlayer.nOnTeam][3]:GetAutoCastState() and d.ChillingTouchBonusRange(gsiPlayer) or 0 end,
	["AbilityThink"] = function(gsiPlayer)
		local thisPlayerAbilities = t_player_abilities[gsiPlayer.nOnTeam]
		local coldFeet = thisPlayerAbilities[1]
		local iceVortex = thisPlayerAbilities[2]
		local chillingTouch = thisPlayerAbilities[3]
		local iceBlast = thisPlayerAbilities[4]
		local iceBlastRelease = thisPlayerAbilities[5]
		local chillingTouchOnCd = chillingTouch:GetCooldownTimeRemaining() > 0 -- gsiPlayer.attackRange is updated when on

		remove_ice_vortex(gsiPlayer)

		local playerHealthPercent = gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth
		local abilityLocked, _, abilityQueued = UseAbility_IsPlayerLocked(gsiPlayer) 
		local currTask = currentTask(gsiPlayer)
		local currActivityType = Blueprint_GetCurrentTaskActivityType(gsiPlayer)
		if (chillingTouchOnCd or currTask == farm_lane_task_handle) and chillingTouch:GetAutoCastState() then
			chillingTouch:ToggleAutoCast() -- off
			gsiPlayer.attackRange = gsiPlayer.hUnit:GetAttackRange()
		end

		print(chillingTouch:GetDuration())

		local nearbyAllies = Set_GetAlliedHeroesInPlayerRadius(gsiPlayer, 1350, false)

		HANDLE_AUTOCAST_GENERIC(gsiPlayer, chillingTouch)

		local nearbyEnemies = Set_GetEnemyHeroesInPlayerRadius(gsiPlayer, coldFeet:GetCastRange(), 5)

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
						--print(gsiPlayer.hUnit.Action_UseAbilityOnEntity)

						USE_ABILITY(gsiPlayer, coldFeet, fightHarassTarget, 400, nil, nil, nil, nil,
								gsiPlayer.hUnit.Action_UseAbilityOnEntity)
						return
					end
				end
				local totalHeat = FightClimate_GetEnemiesTotalHeat(nearbyEnemies, true)
				if AbilityLogic_AbilityCanBeCast(gsiPlayer, iceVortex) then
					if fightHarassTarget.hUnit:HasModifier("modifier_cold_feet")
							or ( totalHeat < 0.35 or totalHeat > 0.99
							and currActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION
							and AbilityLogic_HighUseAllowOffensive(gsiPlayer, iceVortex,
									HIGH_USE_I_V_REMAINING_MANA,
									fightHarassTarget.lastSeenHealth / fightHarassTarget.maxHealth
								)
							) then
						local stability = fightHarassTarget.hUnit:GetMovementDirectionStability()
						local vortexLoc = stability == 0 and fightHarassTarget.lastSeen.location
								or Vector_Addition(fightHarassTarget.lastSeen.location,
										Vector_ScalarMultiply(
											Vector_UnitDirectionalFacingDirection(
													fightHarassTarget.hUnit:GetFacing()
												),
											stability * 200
										)
									)
						if correct_ice_vortex(gsiPlayer, iceVortex, vortexLoc, 350 + 200*stability) then
							USE_ABILITY(gsiPlayer, iceVortex, vortexLoc, 400, nil)
							return
						end
					elseif HIGH_USE(gsiPlayer, iceVortex, HIGH_USE_I_V_REMAINING_MANA, 0.75) then
		 --[[NICE]]		local escapeBez
								= SearchFog_GetNearbyBezier(gsiPlayer.lastSeen.location,
										iceVortex:GetCastRange()
									)
						if escapeBez then
							for i=1,#escapeBez do
								local escapeLoc = escapeBez[i]
								escapeLoc = escapeLoc and escapeLoc:computeForwards(0.05)
								if escapeLoc and not IsLocationVisible(escapeLoc)
										and IsLocationPassable(escapeLoc)
										and correct_ice_vortex(gsiPlayer, iceVortex, escapeLoc, 600)
										and Vector_PointDistance(escapeLoc, gsiPlayer.lastSeen.location)
											< iceVortex:GetCastRange() then
									USE_ABILITY(gsiPlayer, iceVortex, escapeBez, 400, nil)
									return;
								end
							end
						end
					end
				end
			end
			if AbilityLogic_AbilityCanBeCast(gsiPlayer, coldFeet) then
				for i=1,#nearbyEnemies do
					local thisEnemy = nearbyEnemies[i]
					if not pUnit_IsNullOrDead(thisEnemy)
							and (thisEnemy.hUnit:IsRooted() or (thisEnemy.hUnit:IsStunned())
							and Unit_GetHealthPercent(thisEnemy) > 0.15)
							and AbilityLogic_HighUseAllowOffensive(gsiPlayer, coldFeet, 
									HIGH_USE_C_F_REMAINING_MANA,
									Unit_GetHealthPercent(thisEnemy)) then
						USE_ABILITY(gsiPlayer, coldFeet, thisEnemy, 400, nil)
						return
					end
				end
			end
			if fightHarassTarget and not fightHarassTarget.typeIsNone and AbilityLogic_AbilityCanBeCast(gsiPlayer, iceVortex) and not fightHarassTarget.hUnit:HasModifier("modifier_ice_vortex")
					and AbilityLogic_HighUseAllowOffensive(gsiPlayer, iceVortex, HIGH_USE_I_V_REMAINING_MANA, Unit_GetHealthPercent(fightHarassTarget)) then
				local nearestTower = Set_GetNearestTeamTowerToPlayer(TEAM, gsiPlayer)
				local towerLoc = nearestTower and nearestTower.lastSeen.location
				if nearestTower and Vector_PointDistance2D(fightHarassTarget.lastSeen.location, towerLoc)
							< 700
						and correct_ice_vortex(gsiPlayer, iceVortex, fightHarassTarget.lastSeen.location) then
					USE_ABILITY(gsiPlayer, iceVortex, fightHarassTarget.lastSeen.location, 400, nil)
					return;
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

			local fightingHere, fightingElsewhere = Set_GetEnemyHeroesInPlayerRadiusAndOuter(gsiPlayer.lastSeen.location, 2500, 22000)
			if AbilityLogic_AbilityCanBeCast(gsiPlayer, iceBlast) and gsiPlayer.lastSeenMana - iceBlast:GetManaCost() > 0 then
				if #fightingHere > 0 or #fightingElsewhere > 0 then 
					local lowestFightingHere = Unit_LowestHealthPercentPlayer(fightingHere)
					if lowestFightingHere then
						local fightingHerePercentHealth = lowestFightingHere.lastSeenHealth / lowestFightingHere.maxHealth
						local fightingHereStability = lowestFightingHere.hUnit:GetMovementDirectionStability()
						local crowdedLoc, crowdedRating
								= Set_GetCrowdedRatingToSetTypeAtLocation(lowestFightingHere.lastSeen.location,
										SET_HERO_ENEMY, fightingHere, 250
									)

						if (fightingHerePercentHealth < 0.311+crowdedRating/3+0.15*(#nearbyAllies + Analytics_GetTheoreticalDangerAmount(gsiPlayer)) and fightingHereStability > 0.6
								and AbilityLogic_HighUseAllowOffensive(gsiPlayer, iceBlast, HIGH_USE_I_B_REMAINING_MANA, fightingHerePercentHealth)) or playerHealthPercent < 0.2 then
							ice_blast_start_cast(gsiPlayer, lowestFightingHere, #fightingHere > 1 and crowdedLoc)
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
			if fightHarassTarget and AbilityLogic_AbilityCanBeCast(gsiPlayer, coldFeet)
					and not fightHarassTarget.typeIsNone
					and currActivityType >= ACTIVITY_TYPE.FEAR
					and FightClimate_AnyIntentToHarm(gsiPlayer, nearbyEnemies)
					and playerHealthPercent < 0.3
							- 0.2*Analytics_GetTheoreticalDangerAmount(gsiPlayer)
					and AbilityLogic_HighUseAllowOffensive(gsiPlayer, coldFeet, 
							HIGH_USE_C_F_REMAINING_MANA,
							playerHealthPercent)
					and Vector_DistUnitToUnit(fightHarassTarget, gsiPlayer)
							< coldFeet:GetCastRange()*1.1 then
				USE_ABILITY(gsiPlayer, coldFeet, fightHarassTarget, 400, nil)
				return;
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
