local XETA_SCORE_DO_NOT_RUN = XETA_SCORE_DO_NOT_RUN
local Math_PointToPointDistance2D = Math_PointToPointDistance2D
local Set_GetEnemyHeroesInPlayerRadius = Set_GetEnemyHeroesInPlayerRadius
local pUnit_GetAdjustedAttackTime = pUnit_GetAdjustedAttackTime
local Unit_GetDegenAttackModifiersOnUnit = Unit_GetDegenAttackModifiersOnUnit
local Lhp_GetActualFromUnitToUnitAttackOnce = Lhp_GetActualFromUnitToUnitAttackOnce
local FarmJungle_GetJungleCampClearViability = FarmJugnle_GetJungleCampClearViability
local Analytics_GetTotalDamageInTimeline = Analytics_GetTotalDamageInTimeline
local Analytics_GetMostDamagingUnitTypeToUnit = Analytics_GetMostDamagingUnitTypeToUnit
local VALUE_OF_ONE_HEALTH = VALUE_OF_ONE_HEALTH
local CREEP_AGRO_RANGE = CREEP_AGRO_RANGE
local Positioning_WillAttackCmdExposeToLocRad = Positioning_WillAttackCmdExposeToLocRad
local Task_GetTaskScore = Task_GetTaskScore
local max = math.max
local min = math.min
local abs = math.abs

local task_handle = Task_CreateNewTask()

local FIGHT_HARASS_THROTTLE = 0.083

local farm_lane_task_handle
local leech_exp_task_handle

local blueprint

local APPROX_SURPRISE_FACTOR_DISTANCE = 100 -- Used if we're already under the enemy's attack range and would make approach to attack

local APPROX_MJOL_STATIC_TAKEN_PER_HIT = APPROX_MJOL_STATIC_TAKEN_PER_HIT
local APPROX_COST_OF_HARASSING_UNDER_TOWER = 27*BUILDING_T2_T4_ATTACK_DAMAGE * VALUE_OF_ONE_HEALTH / 1.1

local MELEE_CREEP_HALF_VALUE = 20
local CREEP_AGRO_RESET_LIMIT = 2 - 0.15

local DEBUG = DEBUG
local VERBOSE = VERBOSE
local TEST = TEST

local CONSIDERABLE_SCORE = 20 -- Approximately, a score which may win while in lane. Used if no enemies are nearby as a factor against theoretical mimics from fog for the analytical data of FightHarass_GetHealthDiffOutnumbered()

local t_harass_scores = {}

local t_health_diff_outnumbered_factor = {}

local t_team_players

local function get_harassable_enemies(gsiPlayer)
	local harassRange = gsiPlayer.attackRange + (gsiPlayer.isRanged and 2400 or 2800)
	return harassRange, Set_GetEnemyHeroesInPlayerRadius(gsiPlayer, harassRange)
end

function FightHarass_GetHealthDiffOutnumbered(gsiPlayer)
	return t_health_diff_outnumbered_factor[gsiPlayer.nOnTeam] or 0
end

local next_player = 1
local function estimated_time_til_completed(gsiPlayer, objective)
	return 2 -- don't care
end
local function task_init_func(taskJobDomain)
	farm_lane_task_handle = FarmLane_GetTaskHandle()
	leech_exp_task_handle = LeechExperience_GetTaskHandle()
	
	if VERBOSE then VEBUG_print(string.format("fight_harass: Initialized with handle #%d.", task_handle)) end

	t_team_players = GSI_GetTeamPlayers(TEAM)

	Task_RegisterTask(task_handle, PLAYERS_ALL, blueprint.run, blueprint.score, blueprint.init)

	taskJobDomain:RegisterJob(
			function(workingSet)
				if workingSet.throttle:allowed() then
					local _, nearbyEnemies = get_harassable_enemies(t_team_players[next_player])
					if #nearbyEnemies > 0 then
						Task_SetTaskPriority(task_handle, next_player, TASK_PRIORITY_TOP)
					end
					next_player = Task_RotatePlayerOnTeam(next_player)
				end
			end,
			{["throttle"] = Time_CreateThrottle(FIGHT_HARASS_THROTTLE)},
			"JOB_TASK_SCORING_PRIORITY_FIGHT_HARASS"
		)
	taskJobDomain:RegisterJob( -- Check for value of melee creep during early game. (incentivises harassment during low-scoring farm_lane)
			function(workingSet)
				if workingSet.throttle:allowed() then
					if GameTime() > 240 then MELEE_CREEP_HALF_VALUE = 20.1 end -- n.b. % 1.0 ~= 0.0 deregister
					local exampleCreepSpawn = Set_GetAlliedCreepSetsInLane(MAP_LOGICAL_MIDDLE_LANE) and Set_GetAlliedCreepSetsInLane(MAP_LOGICAL_MIDDLE_LANE)[1]
					if exampleCreepSpawn then
						for i=1,#exampleCreepSpawn.units,1 do
							if exampleCreepSpawn.units[i].hUnit.GetUnitName and string.find(exampleCreepSpawn.units[i].hUnit:GetUnitName(), "melee") then 
								MELEE_CREEP_HALF_VALUE = 
									(	exampleCreepSpawn.units[i].hUnit:GetBountyGoldMax() 
										+ exampleCreepSpawn.units[i].hUnit:GetBountyGoldMin() ) / 2 
									+ 	Xeta_EvaluateExperienceGain(GetBot(), exampleCreepSpawn.units[i].hUnit:GetBountyXP())
							end
						end
						if MELEE_CREEP_HALF_VALUE % 1.0 ~= 0.0 then
							taskJobDomain:DeregisterJob("JOB_TASK_FIGHT_HARASS_GET_LOW_PORTION_CREEP_SCORE")
						end
					end
				end
			end,
			{["throttle"] = Time_CreateThrottle(0.0)},
			"JOB_TASK_FIGHT_HARASS_GET_LOW_PORTION_CREEP_SCORE"
		)
	Blueprint_RegisterTaskActivityType(task_handle, ACTIVITY_TYPE["CONTROLLED_AGGRESSION"])
	task_init_func = nil
	return task_handle, estimated_time_til_completed
end
Blueprint_RegisterTask(task_init_func)

local creep_agro_reset_time = {}
local disallow_deagro_time = {}
local enemy_intents = {}
local friendly_intents = {}

-- table for storing being-attacked-state, helps tit for tat teamplay
local team_player_targetted = {} for pnot=1,TEAM_NUMBER_OF_PLAYERS do team_player_targetted[pnot] = {} end
local adjust_safer_avoid_agro = (TEAM == TEAM_DIRE and Vector(-225, -225, 0) or Vector(255, 255, 0))
blueprint = {
	run = function(gsiPlayer, objective, xetaScore)
		local hPlayer = gsiPlayer.hUnit
		local pnot = gsiPlayer.nOnTeam
		local creepPressure = Analytics_CreepPressureFast(gsiPlayer)
		local attackTarget = hPlayer:GetAttackTarget() 

		if creep_agro_reset_time[pnot] and creep_agro_reset_time[pnot] < GameTime() then
			creep_agro_reset_time[pnot] = false
		end
		if DEBUG and DEBUG_IsBotTheIntern() then
			DebugDrawText(450, 860, string.format("%.1f;%.1f;%.1f;%.1f;%.1f", (creep_agro_reset_time[1] or -0.0), (creep_agro_reset_time[2] or -0.0), (creep_agro_reset_time[3] or -0.0), (creep_agro_reset_time[4] or -0.0), (creep_agro_reset_time[5] or -0.0)), 255, 255, 255)
		end
		if not creep_agro_reset_time[pnot] and creepPressure >= 0.75 then
			if DEBUG and DEBUG_IsBotTheIntern() then
				DebugDrawText(760, 860, string.format("avoid creep agro %s: %.2f", gsiPlayer.shortName, creepPressure), 255, 255, 255)
			end
			local highRecentTakenType, highRecentTaken = Analytics_GetMostDamagingUnitTypeToUnit(gsiPlayer)
			local attackDamage = hPlayer:GetAttackDamage()
			if highRecentTakenType == UNIT_TYPE_CREEP and highRecentTaken > attackDamage then
				local nearbyFriendly = Set_GetNearestAlliedCreepSetToLocation(gsiPlayer.lastSeen.location)
				if nearbyFriendly[1] and Analytics_GetNearFutureHealth(gsiPlayer, 3) < 400
						and ( not disallow_deagro_time[pnot] or disallow_deagro_time[pnot] < GameTime() ) then
					-- SUPERHUMAN deagro and return to normal behaviour next frame.
					-- Assumes server triggers a deagro to process from any friendly attack event, or checks deagros every frame.
					disallow_deagro_time[pnot] = GameTime() + 6
					hPlayer:Action_AttackUnit(nearbyFriendly[1].hUnit, false)
					return xetaScore;
				end
			end
			local nearbyEnemyCreeps = gsiPlayer.hUnit:GetNearbyCreeps(CREEP_AGRO_RANGE, false)
			if objective.lastSeenHealth > attackDamage*2
					and #nearbyEnemyCreeps > gsiPlayer.lastSeenHealth / 300 then
				local moveSafe = Vector_Addition(
						gsiPlayer.lastSeen.location,
						Positioning_AdjustToAvoidCrowdingSetType(
								gsiPlayer, adjust_safer_avoid_agro, SET_HERO_ENEMY, 500
							)
					)
				moveSafe = Positioning_AdjustToAvoidCrowdingSetType(gsiPlayer, moveSafe, SET_CREEP_ENEMY, 800)
	if abs(moveSafe.x) > 9000 or abs(moveSafe.y) > 9000 or abs(moveSafe.z) > 9000 then
		WARN_print(string.format("[fight_harass] BIG DIST: %s", debug.traceback()));
	end
				hPlayer:Action_MoveToLocation(moveSafe)
				if DEBUG then DebugDrawLine(gsiPlayer.lastSeen.location, moveSafe, 80, 255, 180) end
				return xetaScore;
			end
		end
		if GSI_UnitCanStartAttack(gsiPlayer) --[[or (attackTarget and attackTarget:IsHero())]] then
			local hEnemy = objective.hUnit
			local inAttackRange = Math_PointToPointDistance2D(gsiPlayer.lastSeen.location, objective.lastSeen.location) < gsiPlayer.attackRange + 80
			if inAttackRange or hPlayer:GetAttackTarget() then
				hPlayer:Action_AttackUnit(hEnemy, false)
				if not creep_agro_reset_time[pnot] then
					creep_agro_reset_time[pnot] = GameTime() + CREEP_AGRO_RESET_LIMIT
				end
			else
				if DEBUG and gsiPlayer.shortName == "arc_warden" then DebugDrawText(200, 200, ":3", 255, 255, 255) end
				Positioning_ZSAttackRangeUnitHugAllied(
						gsiPlayer,
						objective.lastSeen.location,
						SET_CREEP_ENEMY,
						250, 
						-1, 
						true, 
						min(1.0, 
								max(0.0, (1-Analytics_GetTheoreticalDangerAmount(gsiPlayer)) / 5)
							)
					)
			end
			if DEBUG then DebugDrawLine(gsiPlayer.lastSeen.location, objective.lastSeen.location, 255, 255, 255) end
		elseif pUnit_IsNullOrDead(objective) then
			--print(objective.name, gsiPlayer.shortName, "is dead")
			return XETA_SCORE_DO_NOT_RUN
		else
			--[DEBUG]]if DEBUG and DEBUG_IsBotTheIntern() then print(gsiPlayer.shortName, "waiting to be able to attack") end
			Positioning_ZSAttackRangeUnitHugAllied(
					gsiPlayer, objective.lastSeen.location, SET_BUILDING_ENEMY,
					2000, 0.5 + hPlayer:GetLastAttackTime() - GameTime(),
					true,
					min(1.0, 
						max(0.0,
							1-Analytics_GetTheoreticalDangerAmount(gsiPlayer) / 5
						)
					)
				)
		end
		return xetaScore
	end,
	
	score = function(gsiPlayer, prevObjective, prevScore)
		-- RULE OF USE -- Must return a hero or false, used as soft-analytical data for good targets, data is assumed
		-- -| (from outside this module) reliable and up-to-date for potential-best-target requests
		local hUnitPlayer = gsiPlayer.hUnit
		local currentTarget = hUnitPlayer:GetAttackTarget()
		if currentTarget and currentTarget:GetTeam() == TEAM then
			-- don't interrupt denies while farm_lane / fight_harass weaving
			return false, XETA_SCORE_DO_NOT_RUN
		end

		local playerIsRooted = hUnitPlayer:IsRooted()
		-- Check if we are taking damage, and from what
		local highRecentTakenType, highRecentTaken = Analytics_GetMostDamagingUnitTypeToUnit(gsiPlayer)
		if not playerIsRooted then
			if highRecentTaken*2 > 
							math.max(
									hUnitPlayer:GetAttackDamage()*2.5,
									Analytics_GetTotalDamageInTimeline(prevObjective)
								)
					and FarmLane_UtilizingLaneSafety(gsiPlayer) then
				return false, XETA_SCORE_DO_NOT_RUN
			elseif highRecentTakenType == UNIT_TYPE_CREEP and highRecentTaken > hUnitPlayer:GetAttackDamage()*0.1
					and FarmJungle_JungleCampClearViability(gsiPlayer, JUNGLE_CAMP_HARD) < 1 then
				return false, XETA_SCORE_DO_NOT_RUN
			elseif highRecentTakenType == UNIT_TYPE_BUILDING
					and (
							hUnitPlayer:GetAttackDamage()*1.5 < max(
							prevObjective and prevObjective.lastSeenHealth or 600,
							gsiPlayer.lastSeenHealth*0.5)
							or 150 + highRecentTaken*2 > (gsiPlayer.lastSeenHealth - (prevObjective and prevObjective.lastSeenHealth*0.75 or 0))
						) then
				Task_CreateUpdatePriorityDeagroJob(gsiPlayer)
				return false, XETA_SCORE_DO_NOT_RUN
			end
		end
		team_player_targetted[gsiPlayer.nOnTeam][1] = highRecentTakenType
		team_player_targetted[gsiPlayer.nOnTeam][2] = highRecentTaken

		local playerLoc = gsiPlayer.lastSeen.location
		local attackRange = gsiPlayer.attackRange
		local harassRange, nearbyEnemies = get_harassable_enemies(gsiPlayer)
		local centerOfEnemies = Set_GetCenterOfSetUnits(nearbyEnemies) or playerLoc
		local nearbyAllies = Set_GetAlliedHeroesInLocRadius(gsiPlayer, centerOfEnemies, 1700, false)
		local numNearbyEnemies = #nearbyEnemies
		local numNearbyAllies = #nearbyAllies
		local numOfTeamCenterPlayer = 1 + numNearbyAllies
		local outnumberedFactor = max(0.5, min(2, numOfTeamCenterPlayer / max(1, numNearbyEnemies)))
		local mostHarassableEnemy = false
		local mostHarassableEnemyValue = XETA_SCORE_DO_NOT_RUN
		local nearestTower = Set_GetNearestTeamTowerToPlayer(ENEMY_TEAM, gsiPlayer) or GSI_GetTeamFountainUnit(ENEMY_TEAM)
		local tLoc = nearestTower and nearestTower.lastSeen.location
		local tRange = nearestTower and nearestTower.attackRange + 150
		local enemy_intents = enemy_intents
		local friendly_intents = friendly_intents
		-- update intents (in-func)
		local underAttack = FightClimate_AnyIntentToHarm(gsiPlayer, nearbyEnemies, enemy_intents)
		FightClimate_AnyIntentToHarm(gsiPlayer, nearbyAllies, friendly_intents)
		local numEnemyIntent = #enemy_intents
		local numFriendlyIntent = #friendly_intents
		--[[DEBUG]]if DEBUG and DEBUG_IsBotTheIntern() then DebugDrawText(1600, 620, string.format("friendly_intents:%s %s", tostring(friendly_intents[1]), tostring(friendly_intents[2])), 255, 255, 255) DebugDrawText(1600, 630, string.format("enemy_intents:%s %s", tostring(enemy_intents[1]), tostring(enemy_intents[2])), 255, 255, 255) end
		local netPowerStruggle = 0 -- Used to inform the final score. If their Godlike Mid is in lane with MeatSim, we should know that attacking MeatSim might be a very bad idea.
		
		-- create data for targetting based on positioning
		local creepPressure = FightClimate_CreepPressureFast(gsiPlayer) -- used in score divisor

		local totalDistanceOfEnemiesToMe = 0
		local distanceScores = {}
		local challenge = 0
		for i=1,numNearbyEnemies do
			distanceScores[i] = Math_PointToPointDistance2D(
					playerLoc,
					nearbyEnemies[i].lastSeen.location
				)	
			totalDistanceOfEnemiesToMe = totalDistanceOfEnemiesToMe + distanceScores[i]
			if enemy_intents[i] then
				challenge = challenge + 1
			end
		end
		if challenge > 1 then
			FarmLane_InformFightingNoFarming(gsiPlayer)
		end
		local avgDistance = totalDistanceOfEnemiesToMe / numNearbyEnemies
		for i=1,numNearbyEnemies do
			distanceScores[i] = distanceScores[i] < attackRange+75 and 0
					or min(0, avgDistance - distanceScores[i])*numNearbyEnemies/30
		end
		if DEBUG and DEBUG_IsBotTheIntern() and nearbyEnemies[1] then print("ATTACK RANGE FROM AVG SCORES", nearbyEnemies[1].shortName, distanceScores[1], distanceScores[2], distanceScores[3]) end
		if DEBUG then
			DebugDrawText(160, (TEAM_IS_RADIANT and 760 or 860)+gsiPlayer.nOnTeam*8, string.sub(gsiPlayer.shortName, 1, 5), 255, 255, 255)
		end
--[[]]if numNearbyEnemies > 0 then
--[[ Deduced the best target for thisPlayer to harass right now, and the effectiveHealth/attackPower struggle in this area ]]
	-- -- Create a basis to inform how much problematic exposure is created when attacking each hero
	--	local enemyOpportunity = {}
	--	local alliedOpportunity = {}
	--	for iEnemy=1,numNearbyEnemies do
	--		local thisEnemy = nearbyEnemies[iEnemy]
	--		local thisEnemyAttackRange = thisEnemy
	--	end
	--	for iAllied=1,numNearbyAllies do

	--	end
		
	--	local retaliationIsEtiquetteFactor = gsiPlayer.lastSeenHealth / 
	
		for iEnemy=1,numNearbyEnemies,1 do
			local thisEnemy = nearbyEnemies[iEnemy]
			if DEBUG then DebugDrawText(200+thisEnemy.nOnTeam*8, TEAM_IS_RADIANT and 748 or 848, string.sub(thisEnemy.shortName, 1, 1), 255, 255, 255) end
			if thisEnemy.typeIsNone or not thisEnemy.hUnit:IsAlive() then ALERT_print("/VUL-FT/ <WARN> fight_harass: enemy listed is type none.") goto NEXT end
			local thisEnemyAttackRange = thisEnemy.attackRange or 350
			local distanceToEnemy = Math_PointToPointDistance2D(playerLoc, thisEnemy.lastSeen.location)
			local timeToGetIntoAttackRange = max(0, (distanceToEnemy - attackRange)/gsiPlayer.currentMovementSpeed)
			local mjolStaticUp, bladeMailUp, enchantressAttackSlow, abaddonBorrowedTime = Unit_GetDegenAttackModifiersOnUnit(thisEnemy) -- allowing centaur / bristle type damage-on-damage return to be calculated naturally after the fact
			
			if abaddonBorrowedTime or thisEnemy.hUnit:IsAttackImmune()
					or thisEnemy.hUnit:IsInvulnerable() then
				goto NEXT
			end
		
			local secondsToAttack = pUnit_GetAdjustedAttackTime(gsiPlayer, enchantressAttackSlow)*gsiPlayer.attackPointPercent + timeToGetIntoAttackRange -- TODO this is wrong after starting attack on ench
			local actualDamage = Lhp_GetActualFromUnitToUnitAttackOnce(gsiPlayer.hUnit, thisEnemy.hUnit)
			local actualDmgDps = actualDamage / gsiPlayer.hUnit:GetSecondsPerAttack()
			local actualDamageToMe = Lhp_GetActualFromUnitToUnitAttackOnce(thisEnemy.hUnit, gsiPlayer.hUnit) + (mjolStaticUp and APPROX_MJOL_STATIC_TAKEN_PER_HIT or 0) + (bladeMailUp and actualDamage or 0)
			local actualDmgDpsToMe = actualDamageToMe / gsiPlayer.hUnit:GetSecondsPerAttack()
			local freeDamage = 0 -- or 'freeDamageMetric'
			if min(attackRange, thisEnemyAttackRange) < distanceToEnemy then
				freeDamage = attackRange - thisEnemyAttackRange -- +ve indicates we get free attacks; -ve, enemy gets free attacks. This value used for free attack distance / lower-attack-range-player-movespeed
				if distanceToEnemy < thisEnemyAttackRange+APPROX_SURPRISE_FACTOR_DISTANCE then
					freeDamage = freeDamage + APPROX_SURPRISE_FACTOR_DISTANCE
				elseif numNearbyEnemies > 1 then
					-- consider being attacked while aquiring target
					freeDamage = freeDamage + (gsiPlayer.isMelee and 15 or 0)
							- (distanceToEnemy-attackRange)/(5*numNearbyEnemies)
				end
				-- n.b. freeDamage is currently expressed in +ve/-ve range of our/their attack range over the other who is not in attack range.
				if freeDamage > 0 then
					freeDamage = actualDamage*freeDamage / (thisEnemy.currentMovementSpeed*hUnitPlayer:GetSecondsPerAttack())-- +ve
				else
					freeDamage = max(0, 
							actualDamageToMe*freeDamage / 
								(gsiPlayer.currentMovementSpeed*thisEnemy.hUnit:GetSecondsPerAttack()*(numOfTeamCenterPlayer^2))
						) -- -ve  numOfTeamCenterPlayer^2 is in the divisor because if we have 1000vs1000 heroes, having 500 melee consider approaching the fight as low-value because of free damage is hugely detrimental. It's a ticket to team-based fighting that someone needs to pay.
					if gsiPlayer.lastSeenHealth + freeDamage > thisEnemy.lastSeenHealth then
						freeDamage = 0 -- TODO PRIMIRITVE Free pass if we're even
					end
				end
			end
			if DEBUG and DEBUG_IsBotTheIntern() then print("harass:", gsiPlayer.shortName, "to", thisEnemy.shortName, "free damage is", freeDamage) end
			local healthDiffAndOutnumbered = min(2, max(0.05, (gsiPlayer.lastSeenHealth / thisEnemy.lastSeenHealth))) * outnumberedFactor
			local thisHarassableRating = VALUE_OF_ONE_HEALTH * (actualDamage + freeDamage)*healthDiffAndOutnumbered
			if DEBUG and DEBUG_IsBotTheIntern() then print("harass:", gsiPlayer.shortName, "before health diff and outnumbered", thisHarassableRating, math.min(1.33, math.max(0.75, (gsiPlayer.lastSeenHealth / thisEnemy.lastSeenHealth))), outnumberedFactor) end
			thisHarassableRating = thisHarassableRating - (VALUE_OF_ONE_HEALTH * actualDamageToMe)/healthDiffAndOutnumbered
			--thisHarassableRating = thisHarassableRating * (thisHarassableRating>0 and healthDiffAndOutnumbered or 1/healthDiffAndOutnumbered)
			netPowerStruggle = netPowerStruggle + thisHarassableRating*((thisEnemy.hUnit:IsStunned() or thisEnemy.hUnit:IsHexed()) and 1.66 or 1)

			--[DEBUG]]if DEBUG and DEBUG_IsBotTheIntern() then print("harass:", gsiPlayer.shortName, thisHarassableRating, "tower will expose:", Positioning_WillAttackCmdExposeToLocRad(gsiPlayer, thisEnemy, tLoc, tRange), APPROX_COST_OF_HARASSING_UNDER_TOWER) end
			thisHarassableRating = thisHarassableRating
					- (nearestTower and
							(Positioning_WillAttackCmdExposeToLocRad(gsiPlayer, thisEnemy, tLoc, tRange+100)
								and (500-thisHarassableRating)*nearestTower.hUnit:GetAttackDamage()*3/gsiPlayer.lastSeenHealth or 0
							)
						or 0
					)
			if DEBUG and DEBUG_IsBotTheIntern() then print("harass:", gsiPlayer.shortName, thisEnemy.shortName, thisHarassableRating) end
			thisHarassableRating = thisHarassableRating + min(0, -Xeta_CostOfWaitingSeconds(gsiPlayer, secondsToAttack) + MELEE_CREEP_HALF_VALUE - Task_GetTaskScore(gsiPlayer, farm_lane_task_handle))
			for iIntent=1,numFriendlyIntent do
				if friendly_intents[iIntent] == thisEnemy then
					thisHarassableRating = thisHarassableRating + 15
					if DEBUG then DebugDrawText(220+iIntent*8, (TEAM_IS_RADIANT and 610 or 710)+gsiPlayer.nOnTeam*8, "*", 255, 255, 255) end
				end
			end
		--	if not underAttack then
			if enemy_intents[iEnemy] and enemy_intents[iEnemy].type == UNIT_TYPE_HERO then
				if DEBUG and DEBUG_IsBotTheIntern() then print(gsiPlayer.shortName, "increased harass score due to intent of", thisEnemy.shortName) end
				thisHarassableRating = thisHarassableRating + 10 -- retaliate for an ally under attack
				--print(gsiPlayer.shortName, "more keen to attack as not under attack and harassment occuring.")
			end
		--	end
			--print("harass: Time-based score taken was", math.min(0, -Xeta_CostOfWaitingSeconds(gsiPlayer, secondsToAttack) + MELEE_CREEP_HALF_VALUE - Task_GetTaskScore(gsiPlayer, farm_lane_task_handle)))
			if DEBUG and DEBUG_IsBotTheIntern() then DebugDrawText(300, 300+16*iEnemy, string.format("pre: %.2f cressure: %.2f dore:%.2f", thisHarassableRating, creepPressure, distanceScores[iEnemy]), 255, 255, 255) end
			thisHarassableRating = thisHarassableRating
					+ (2 - creepPressure) * max(0, (35 - thisEnemy.level)/35) * 10 + distanceScores[iEnemy]
			if DEBUG and DEBUG_IsBotTheIntern() then DebugDrawText(300, 308+16*iEnemy, string.format("post: %.2f", thisHarassableRating), 255, 255, 255) end
			-- e.g. having to walk an extra 1s to get to a target further away than some other arbitrary but assumed aggressive target, decrements the comparitive score by 10 points.
			if thisHarassableRating > mostHarassableEnemyValue then
				mostHarassableEnemyValue = thisHarassableRating
				mostHarassableEnemy = thisEnemy
				--print(gsiPlayer.shortName, "Set harass", mostHarassableEnemyValue, mostHarassableEnemy.shortName)
			end
			::NEXT::
		end
		netPowerStruggle = netPowerStruggle / numNearbyEnemies
--[[]]else
--[[ Theorize power struggle with Fog of War instead ]]
		-- TODO TRASH MAGIC
		netPowerStruggle = 50*(-Analytics_GetTheoreticalDangerAmount(gsiPlayer, nearbyAllies))
--[[]]end
		t_health_diff_outnumbered_factor[gsiPlayer.nOnTeam] = netPowerStruggle
		-- if mostHarassableEnemy then
			-- print(gsiPlayer.shortName, -netPowerStruggle, "given to leech exp")
			-- LeechExp_UpdatePriority(gsiPlayer, -netPowerStruggle) -- If we got a very low -ve score, we should probably be much more careful in lane
		-- else
			-- LeechExp_UpdatePriority(gsiPlayer, 0) -- Will rescore once for this player (to inform low score)
		-- end
		
		-- if DEBUG and DEBUG_IsBotTheIntern() then print("intern returns", mostHarassableEnemy and mostHarassableEnemy.shortName, mostHarassableEnemyValue) end
		if DEBUG and DEBUG_IsBotTheIntern() then DebugDrawText(650, 650, string.format("harass: %.2f", netPowerStruggle), 255, 255, 255) end
		if DEBUG and DEBUG_IsBotTheIntern() then
			print(gsiPlayer.shortName, "checking attack while rooted", playerIsRooted,
					mostHarassableEnemy and Vector_PointDistance(
							playerLoc,
							mostHarassableEnemy.lastSeen.location),
					gsiPlayer.attackRange
				)
		end
		return mostHarassableEnemy, mostHarassableEnemy
				and mostHarassableEnemyValue + netPowerStruggle / 2
					+ (playerIsRooted
							and Vector_PointDistance(
									playerLoc,
									mostHarassableEnemy.lastSeen.location) < gsiPlayer.attackRange
							and 300 or 0) 
				or XETA_SCORE_DO_NOT_RUN
	end,
	
	init = function(gsiPlayer, objective, extrapolatedXeta)
		-- print("init harass with", gsiPlayer.name, objective, extrapolatedXeta)
		-- print(debug.traceback())
		gsiPlayer.vibe.aggressivity = 0.6
		return extrapolatedXeta
	end
}

function FightHarass_GetTaskHandle()
	return task_handle
end
