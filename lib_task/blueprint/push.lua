-- - #################################################################################### -
-- - - VUL-FT Full Takeover Bot Script for Dota 2 by yewchi // 'does stuff' on Steam
-- - - 
-- - - MIT License
-- - - 
-- - - Copyright (c) 2022 Michael, zyewchi@gmail.com, github.com/yewchi, gitlab.com/yewchi
-- - - 
-- - - Permission is hereby granted, free of charge, to any person obtaining a copy
-- - - of this software and associated documentation files (the "Software"), to deal
-- - - in the Software without restriction, including without limitation the rights
-- - - to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- - - copies of the Software, and to permit persons to whom the Software is
-- - - furnished to do so, subject to the following conditions:
-- - - 
-- - - The above copyright notice and this permission notice shall be included in all
-- - - copies or substantial portions of the Software.
-- - - 
-- - - THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- - - IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- - - FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- - - AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- - - LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- - - OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- - - SOFTWARE.
-- - #################################################################################### -

local TEST = TEST

local task_handle = Task_CreateNewTask()

local PUSH_THROTTLE = 0.23807 -- rotates

local TIME_TOWER_STILL_UNAGROABLE = 0.82 - 0.03
local LEVEL_AND_SAFETY_ALLOW_PUSH_TOWERS = 4 + (-(-2)) -- level + (-danger)

local REASONABLE_HIGH_ATTACK_RANGE = 900
local BLINK_FEAR_RANGE = 1600
local CHECK_FOR_BASE_CONNECTIONS_RANGE = 5000

local SET_BUILDING_ENEMY = SET_BUILDING_ENEMY
local max = math.max
local min = math.min
local sqrt = math.sqrt
local DEBUG = DEBUG
local VERBOSE = VERBOSE
local TEST = TEST

local ENEMY_FOUNTAIN_UNIT

local t_tower_wont_agro = {}

local farm_lane_handle
local dawdle_handle

local blueprint
function PushLane_InformUnagroablePush(hUnit)
	local towerWontAgro = bUnit_ConvertToSafeUnit(hUnit)
	-- lazily piggyback this for barracks pushing
	if towerWontAgro then
		t_tower_wont_agro[towerWontAgro] = GameTime() + TIME_TOWER_STILL_UNAGROABLE + (towerWontAgro.barracksType and 6 or 0)
	end
end

function PushLane_IsTowerFightingCreeps(gsiUnit)
	return t_tower_wont_agro[gsiUnit] and true or false, t_tower_wont_agro[gsiUnit]
end

function PushLane_RegisterHighPressureOption(building, pressure)
	
end

local next_player = 1
local function estimated_time_til_completed(gsiPlayer, objective)
	return 3 -- don't care
end
local function task_init_func(taskJobDomain)
	Blueprint_RegisterTaskName(task_handle, "push")
	if VERBOSE then VEBUG_print(string.format("push: Initialized with handle #%d.", task_handle)) end

	farm_lane_handle = FarmLane_GetTaskHandle()
	dawdle_handle = Dawdle_GetTaskHandle()

	ENEMY_FOUNTAIN_UNIT = GSI_GetTeamFountainUnit(ENEMY_TEAM)
	
	Task_RegisterTask(task_handle, PLAYERS_ALL, blueprint.run, blueprint.score, blueprint.init)

	taskJobDomain:RegisterJob(
			function(workingSet)
				if workingSet.throttle:allowed() then
					Task_SetTaskPriority(task_handle, next_player, TASK_PRIORITY_TOP)
					next_player = Task_RotatePlayerOnTeam(next_player)
				end
			end,
			{["throttle"] = Time_CreateThrottle(PUSH_THROTTLE)},
			"JOB_TASK_SCORING_PRIORITY_PUSH"
		)
	Blueprint_RegisterTaskActivityType(task_handle, ACTIVITY_TYPE["CAREFUL"])
	task_init_func = nil
	return task_handle, estimated_time_til_completed
end
Blueprint_RegisterTask(task_init_func)

blueprint = {
	run = function(gsiPlayer, objective, xetaScore)
		FarmJungle_IncentiviseJungling(gsiPlayer, objective)
		
		if objective.type == UNIT_TYPE_IMAGINARY then
			Positioning_ZSAttackRangeUnitHugAllied(gsiPlayer, objective.lastSeen.location, nil, nil, 0)
			return;
		end
		if objective.center then
			if objective.units[1] and objective.units[1].team == TEAM then
				-- Chase the allied creep set into an enemy base for pushing buildings
				Positioning_ZSAttackRangeUnitHugAllied(gsiPlayer, objective.center, nil, nil, 0)
				return;
			end
			return XETA_SCORE_DO_NOT_RUN;
		end
		if Unit_IsNullOrDead(objective) then
			return XETA_SCORE_DO_NOT_RUN
		end
		if Unit_GetTimeTilNextAttackStart(gsiPlayer) - 0.15
				< math.max(0.1,
							Vector_PointDistance2D(gsiPlayer.lastSeen.location, objective.lastSeen.location)
							- gsiPlayer.attackRange
							- 120
					) / gsiPlayer.currentMovementSpeed then
			gsiPlayer.hUnit:Action_AttackUnit(objective.hUnit, true)
			return;
		else
			Positioning_ZSAttackRangeUnitHugAllied(gsiPlayer, objective.lastSeen.location, nil, nil, 0)
			return;
		end
	end,
	
	score = function(gsiPlayer, prevObjective, prevScore)

		local playerLoc = gsiPlayer.lastSeen.location
		local theoreticalDanger, knownEngage, theorizedEngage = Analytics_GetTheoreticalDangerAmount(gsiPlayer)
		local attackTarget = gsiPlayer.hUnit:GetAttackTarget()
		local finishAttack = attackTarget and attackTarget:IsBuilding() and 50 or 0
		local underAttack = FightClimate_AnyIntentToHarm(gsiPlayer, Set_GetEnemyHeroesInPlayerRadius(gsiPlayer, 1350))
				and -150*max(0.25, 1+theoreticalDanger) or 0
		local highestRecentType, highestTaken = Analytics_GetMostDamagingUnitTypeToUnit(gsiPlayer)
		--print("highest recent in push", highestRecentType, highestTaken)
	--	if highestTaken/gsiPlayer.maxHealth > 0.15 or (highestRecentType == SET_BUILDING_ENEMY and highestTaken/gsiPlayer.maxHealth > 0.05) then -- TODO bad
	--		return false, XETA_SCORE_DO_NOT_RUN
	--	end
		--[DEBUG]]if DEBUG and DEBUG_IsBotTheIntern() then DEBUG_print(string.format("push: %s %.2f", gsiPlayer.shortName, theoreticalDanger)) end
		if gsiPlayer.level - theoreticalDanger > LEVEL_AND_SAFETY_ALLOW_PUSH_TOWERS then
			for building,attackWontAgroExpires in pairs(t_tower_wont_agro) do
				if bUnit_IsNullOrDead(building)
						or (attackWontAgroExpires < GameTime() and (building.hUnit:GetHealth() > 150
								or building.hUnit:HasModifier("modifier_backdoor_protection")
								or (building.isTower and building.tier > 1))) then
					--[DEBUG]]print("removing old tower won't agro")
					t_tower_wont_agro[building] = nil
				elseif IsLocationVisible(building.lastSeen.location) then
					if building.hUnit:HasModifier("modifier_fountain_glyph") then
						break;
					end
					--[DEBUG]]print("checking range", Math_PointToPointDistance2D(playerLoc, tower.lastSeen.location))
					if Math_PointToPointDistance2D(playerLoc, building.lastSeen.location) < 4000 then -- TODO simplistic, while enemy creeps are dead, and our creeps go into the enemy base, need to ensure lane crash is stated as our allied creep set itself 
						local nearbyCreeps = Set_GetNearestAlliedCreepSetInLane(gsiPlayer, building.lane)
						local numAlliedCreeps = nearbyCreeps and #(nearbyCreeps.units) or 0
						local increasingDanger = 0
						if building.isTower then
							local towerCageFightBot = Lhp_CageFightKillTime(building, gsiPlayer) 
							local dangerCoefficientOfCageFight = 4/(1+2^(theoreticalDanger))
							increasingDanger = max(0, (100 - 4*towerCageFightBot
										- dangerCoefficientOfCageFight*towerCageFightBot
									) / max(1, numAlliedCreeps))
						end
						if TEST then
							print(Xeta_EvaluateObjectiveCompletion(
									XETA_PUSH, 
									Math_ETA(gsiPlayer, building.lastSeen.location),
									1.0,
									gsiPlayer,
									building
								), gsiPlayer.shortName, "push 01", underAttack, finishAttack, increasingDanger)
						end
						return building, Math_GetFastThrottledBounded(Xeta_EvaluateObjectiveCompletion(
								XETA_PUSH,
								Math_ETA(gsiPlayer, building.lastSeen.location),
								1.0,
								gsiPlayer,
								building
							), 50, 250, 2000)  + underAttack + finishAttack - min(0, increasingDanger)
					end
				end
			end
		end
		local nearestTower, nearestTowerDist = Set_GetNearestTeamTowerToPlayer(ENEMY_TEAM, gsiPlayer)
		local nearbyAllies = Set_GetAlliedHeroesInPlayerRadius(gsiPlayer, 2400, false)
		if nearestTower then
			local playerAttackDmg = gsiPlayer.hUnit:GetAttackDamage()
			local towerAttackDmg = gsiPlayer.hUnit:GetAttackDamage()
			local towerHealth = nearestTower.lastSeenHealth
			
			if TEST then print("NASTY", gsiPlayer.shortName, nearestTowerDist < max(1200, gsiPlayer.attackRange*1.5),
					(nearestTower.tier == 1 or not nearestTower.hUnit:HasModifier("modifier_backdoor_protection")
						or towerHealth < playerAttackDmg*0.1125), -- TODO
					(theoreticalDanger < 0.1 or (
							(Blueprint_GetCurrentTaskActivityType(gsiPlayer) >= ACTIVITY_TYPE.FEAR or
									theoreticalDanger < 0)
							and gsiPlayer.lastSeenHealth * playerAttackDmg * 0.1475 -- TODO
									> towerAttackDmg * towerHealth
											* Unit_GetArmorPhysicalFactor(gsiPlayer))),
					towerHealth < playerAttackDmg*0.413,
					playerAttackDmg,
					towerHealth,
					nearestTower.attackRange,
					Unit_GetArmorPhysicalFactor(gsiPlayer) * nearestTower.attackDamage
						* 6 * (1+#Set_GetEnemyHeroesInPlayerRadius(gsiPlayer, 1800, 16))
				) end
			
			
			local attackNowSafety = max(0, (#nearbyAllies*0.25
					- theoreticalDanger*0.35)
				)

			if towerHealth > 0 
					and nearestTowerDist < max(1200, gsiPlayer.attackRange*1.5) 
					and (nearestTower.tier == 1 or not nearestTower.hUnit:HasModifier("modifier_backdoor_protection")
						or towerHealth < playerAttackDmg*0.1125) -- TODO
					and (theoreticalDanger < 0.1
							or (
									( Blueprint_GetCurrentTaskActivityType(gsiPlayer) >= ACTIVITY_TYPE.FEAR
											or theoreticalDanger < 0 
										)
									and gsiPlayer.lastSeenHealth * playerAttackDmg * 0.1475 -- TODO
											> towerAttackDmg * towerHealth
													* Unit_GetArmorPhysicalFactor(gsiPlayer)
								)
						)
					and towerHealth < playerAttackDmg*(0.4 + attackNowSafety) then
				if VERBOSE then print("return finish tower push") end
				return nearestTower, nearestTower.goldBounty
						* (gsiPlayer.currentMovementSpeed < gsiPlayer.hUnit:GetBaseMovementSpeed() and 1
							or 0.33 * gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth)
			elseif nearestTowerDist < nearestTower.attackRange+200
					and Unit_GetArmorPhysicalFactor(gsiPlayer) * nearestTower.attackDamage
							* 6 * (1+#Set_GetEnemyHeroesInPlayerRadius(gsiPlayer, 1800, 16))
								> gsiPlayer.lastSeenHealth then
				-- Do not run if tower is high health, dangerous and we are under it
				return false, XETA_SCORE_DO_NOT_RUN
			end
		end
		if Farm_JungleCampClearViability(gsiPlayer, JUNGLE_CAMP_MEDIUM) < 0.5 then return false, XETA_SCORE_DO_NOT_RUN end -- Early game lane eq. for good core behavior TODO ROBUST
		local baseToCheck = TEAM==TEAM_RADIANT and MAP_LOGICAL_DIRE_BASE or MAP_LOGICAL_RADIANT_BASE
		local enemy = Set_GetNearestEnemyCreepSetAtLaneLoc(
				gsiPlayer.lastSeen.location,
				Map_GetBaseOrLaneLocation(gsiPlayer.lastSeen.location)
			)
		local enemyEnemyBase = Set_GetNearestEnemyCreepSetAtLaneLoc(
				gsiPlayer.lastSeen.location,
				baseToCheck
			)
		enemy = (
				not enemy or (enemyEnemyBase and Math_PointToPointDistance2D(gsiPlayer.lastSeen.location, enemyEnemyBase.center)
					< Math_PointToPointDistance2D(gsiPlayer.lastSeen.location, enemy.center))
			) and enemyEnemyBase or enemy
		
		local checkForBaseConnections = Vector_PointDistance2D(gsiPlayer.lastSeen.location, ENEMY_FOUNTAIN)
				< CHECK_FOR_BASE_CONNECTIONS_RANGE
		local allied = checkForBaseConnections
				and Set_GetNearestAlliedCreepSetInLane(
						gsiPlayer,
						baseToCheck
				) or Set_GetNearestAlliedCreepSetInLane(
						gsiPlayer,
						enemy and Farm_GetMostSuitedLane(gsiPlayer, enemy)
								or Team_GetStrategicLane(gsiPlayer)
					)
		-- This will find a flip between base creeps and lane creeps. Whatever we're closer to is our considered current creep set.
		local farmLaneObjective = Task_GetTaskObjective(gsiPlayer, FarmLane_GetTaskHandle())
		if not enemy or not enemy.units then 
			if allied and allied.lane == baseToCheck then
				if VERBOSE then INFO_print("returning allied set during no enemy push") end
				return allied, max(-5, (GSI_GetAliveAdvantageFactor()*30))-theoreticalDanger*30 -- Allied creeps are connecting to enemy buildings
			end
			if farmLaneObjective and farmLaneObjective.type == UNIT_TYPE_IMAGINARY then
				local _, crashTime = Set_GetPredictedLaneFrontLocation(farmLaneObjective.lane)
				crashTime = GameTime() - crashTime
				crashTime = crashTime < 0 and 10 or crashTime
				local exposesToTowerDanger = nearestTower and Positioning_WillAttackCmdExposeToLocRad(
						gsiPlayer, farmLaneObjective,
						nearestTower.lastSeen.location, nearestTower.attackRange + 200
					) and -50 or 0








				return farmLaneObjective,
						min(50, max(-15, (GSI_GetAliveAdvantageFactor()*30))-theoreticalDanger*100) - Xeta_CostOfWaitingSeconds(gsiPlayer, crashTime or 5)
								+ exposesToTowerDanger
			end
			return false, XETA_SCORE_DO_NOT_RUN
		end
		--[DEBUG]]print("push returning to", gsiPlayer.shortName, (enemy.units[1] or false), 20*theoreticalDanger, Xeta_CostOfTravelToLocation(gsiPlayer, enemy.center))
		--[DEBUG]]print(20*(-theoreticalDanger), -2*Xeta_CostOfTravelToLocation(gsiPlayer, enemy.center), underAttack, finishAttack)

		nearestTower = nearestTower or ENEMY_FOUNTAIN_UNIT
		if enemy.units[1] then
			local arbitraryUnit = enemy.units[1]
			local attackStraysScore = Map_LocationIsCreepPathInLane(arbitraryUnit.lastSeen.location,
							arbitraryUnit.lane
						) and 0 or 30
			if not Positioning_WillAttackCmdExposeToLocRad(
						gsiPlayer, arbitraryUnit,
						nearestTower.lastSeen.location, nearestTower.attackRange + 100
					) or (not nearestTower.hUnit:IsNull()
						and allied and allied.units[2]
						and IsLocationVisible(nearestTower.lastSeen.location)
						and nearestTower.hUnit:GetAttackTarget() and nearestTower.hUnit:GetAttackTarget():IsCreep()
					) then
				if VERBOSE then print("returning last push") end

				-- Avoid attacking enemy creeps when you're standing next to enemy heroes
				local _, _, potentialDpsToMeIsBad = FightClimate_ImmediatelyExposedToAttack(gsiPlayer, nil, 16)
				potentialDpsToMeIsBad = potentialDpsToMeIsBad
							* Unit_GetArmorPhysicalFactor(gsiPlayer)
							/ (gsiPlayer.lastSeenHealth*0.01) -- "30 points per dps per 10th of health = 0.01"

				local farmTaskScore = Task_GetTaskScore(gsiPlayer, farm_lane_handle)
				local farmLaneLoc = farmLaneObjective and (farmLaneObjective.center or farmLaneObjective.lastSeen
						and farmLaneObjective.lastSeen.location)

				arbitraryUnit = farmLaneObjective == arbitraryUnit
						and enemy.units[2] or arbitraryUnit

				local shouldPushHard, pushHarderFactor
						= Analytics_ShouldPushHard(gsiPlayer, theoreticalDanger)

				local farmLaneDist = farmLaneLoc
						and sqrt((farmLaneLoc.x - playerLoc.x)^2 + (farmLaneLoc.y - playerLoc.y)^2)
				local farmTaskScoreGetLastHit = 0
				if not shouldPushHard then
					local creep, tta = FarmLane_AnyCreepLastHitTracked(gsiPlayer)
					if tta <= 0 and creep then
						arbitraryCreep = creep
					end
					if creep and (#knownEngage > 0 or creep.team ~= gsiPlayer.team) and tta then
						farmTaskScoreGetLastHit = tta < gsiPlayer.hUnit:GetSecondsPerAttack()
									* (gsiPlayer.isRanged and 2 or 1) + 0.35
								and farmLaneDist and max(0, farmTaskScore*2 - 40)
									/ sqrt(0.05*max(1, farmLaneDist-max(700, gsiPlayer.attackRange*1.33)))
								or 0
						farmTaskScoreGetLastHit = farmTaskScoreGetLastHit / (1 + max(0, pushHarderFactor))
					end
				end

				
				
				local dontPushWithPusherFactor = 0
				if #nearbyAllies > 0 then
					local pusher = Dawdle_GetCantJunglePushHeroNearby(gsiPlayer)
					if pusher and pusher ~= gsiPlayer then
						dontPushWithPusherFactor = - math.log(1 + Vector_PointDistance2D(
										playerLoc, arbitraryUnit.lastSeen.location
									) / gsiPlayer.currentMovementSpeed
								) * 100
					end
				end

				
				


				return arbitraryUnit,
						min(gsiPlayer.level*3,
								max(-10, (GSI_GetAliveAdvantageFactor()*50))-40*(theoreticalDanger)
							)
						- Xeta_CostOfTravelToLocation(gsiPlayer, enemy.center)
						+ underAttack + finishAttack + attackStraysScore
						- #knownEngage * 40 - #theorizedEngage * 10
						- potentialDpsToMeIsBad - farmTaskScoreGetLastHit
						+ 30*max(0, (1.25 - pushHarderFactor))
						+ dontPushWithPusherFactor
			end
		end
		--[[ But if the next creep set was there, what would you score, store for others ]]
		return false, XETA_SCORE_DO_NOT_RUN
	end,
	
	init = function(gsiPlayer, objective, extrapolatedXeta)
		return extrapolatedXeta
	end
}

function Push_GetTaskHandle()
	return task_handle
end
