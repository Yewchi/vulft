local TEST = TEST

local task_handle = Task_CreateNewTask()

local PUSH_THROTTLE = 0.179 -- rotates

local TIME_TOWER_STILL_UNAGROABLE = 0.82 - 0.03
local LEVEL_AND_SAFETY_ALLOW_PUSH_TOWERS = 4 + (-(-2)) -- level + (-danger)

local REASONABLE_HIGH_ATTACK_RANGE = 900
local BLINK_FEAR_RANGE = 1600
local CHECK_FOR_BASE_CONNECTIONS_RANGE = 5000

local SET_BUILDING_ENEMY = SET_BUILDING_ENEMY
local max = math.max
local min = math.min
local DEBUG = DEBUG
local VERBOSE = VERBOSE
local TEST = TEST

local ENEMY_FOUNTAIN_UNIT

local t_tower_wont_agro = {}

local blueprint
function PushLane_InformUnagroablePush(hUnit)
	local towerWontAgro = bUnit_ConvertToSafeUnit(hUnit)
	-- lazily piggyback this for barracks pushing
	if towerWontAgro then
		t_tower_wont_agro[towerWontAgro] = GameTime() + TIME_TOWER_STILL_UNAGROABLE + (towerWontAgro.barracksType and 6 or 0)
	end
end

function PushLane_NextTowerAgroIsCreep(hUnit)
	return t_tower_wont_ago[hUnit] and true or false
end

function PushLane_RegisterHighPressureOption(building, pressure)
	
end

local next_player = 1
local function estimated_time_til_completed(gsiPlayer, objective)
	return 3 -- don't care
end
local function task_init_func(taskJobDomain)
	if VERBOSE then VEBUG_print(string.format("push: Initialized with handle #%d.", task_handle)) end

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
		if objective.type == UNIT_TYPE_IMAGINARY then
			Positioning_ZSAttackRangeUnitHugAllied(gsiPlayer, objective.lastSeen.location, nil, nil, 0)
			return;
		end
		if objective.center and objective.units[1].team == TEAM then
			-- Chase the allied creep set into an enemy base for pushing buildings
			Positioning_ZSAttackRangeUnitHugAllied(gsiPlayer, objective.center, nil, nil, 0)
			return;
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
		local theoreticalDanger = Analytics_GetTheoreticalDangerAmount(gsiPlayer)
		local attackTarget = gsiPlayer.hUnit:GetAttackTarget()
		local finishAttack = attackTarget and attackTarget:IsBuilding() and 50 or 0
		local underAttack = FightClimate_AnyIntentToHarm(gsiPlayer, Set_GetEnemyHeroesInPlayerRadius(gsiPlayer, 1350))
				and -50 or 0
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
				else
					if building.hUnit:HasModifier("modifier_fountain_glyph") then
						break;
					end
					--[DEBUG]]print("checking range", Math_PointToPointDistance2D(playerLoc, tower.lastSeen.location))
					if Math_PointToPointDistance2D(playerLoc, building.lastSeen.location) < 2400 then -- TODO simplistic, while enemy creeps are dead, and our creeps go into the enemy base, need to ensure lane crash is stated as our allied creep set itself 
						local nearbyCreeps = Set_GetNearestAlliedCreepSetInLane(gsiPlayer, building.lane)
						local numAlliedCreeps = nearbyCreeps and #(nearbyCreeps.units) or 0
						local increasingDanger = 0
						if building.isTower then
							local towerCageFightBot = Lhp_CageFightKillTime(building, gsiPlayer) 
							local dangerCoefficientOfCageFight = 4/(1+2^(theoreticalDanger))
							increasingDanger = (100 - 4*towerCageFightBot
										- dangerCoefficientOfCageFight*towerCageFightBot
									) / max(1, numAlliedCreeps)
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
						return building, Xeta_EvaluateObjectiveCompletion(
								XETA_PUSH,
								Math_ETA(gsiPlayer, building.lastSeen.location),
								1.0,
								gsiPlayer,
								building
							) - underAttack + finishAttack - min(0, increasingDanger)
					end
				end
			end
		end
		local nearestTower, nearestTowerDist = Set_GetNearestTeamTowerToPlayer(ENEMY_TEAM, gsiPlayer)
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
					Unit_GetArmorPhysicalFactor(gsiPlayer) * nearestTower.hUnit:GetAttackDamage()
						* 6 * (1+#Set_GetEnemyHeroesInPlayerRadius(gsiPlayer, 1800, 16))
				) end
			
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
					and towerHealth < playerAttackDmg*0.413 then
				if VERBOSE then print("return finish tower push") end
				return nearestTower, nearestTower.goldBounty
			elseif nearestTowerDist < nearestTower.attackRange+200
					and Unit_GetArmorPhysicalFactor(gsiPlayer) * nearestTower.hUnit:GetAttackDamage()
							* 6 * (1+#Set_GetEnemyHeroesInPlayerRadius(gsiPlayer, 1800, 16))
								> gsiPlayer.lastSeenHealth then
				return false, XETA_SCORE_DO_NOT_RUN
			end
		end
		if Farm_JungleCampClearViability(gsiPlayer, JUNGLE_CAMP_MEDIUM) < 0.5 then return false, XETA_SCORE_DO_NOT_RUN end -- Early game lane eq. for good core behaviour TODO ROBUST
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
		if not enemy or not enemy.units then 
			if allied and allied.lane == baseToCheck then
				if VERBOSE then INFO_print("returning allied set during no enemy push") end
				return allied, -theoreticalDanger*30 -- Allied creeps are connecting to enemy buildings
			end
			local farmLaneObjective = Task_GetTaskObjective(gsiPlayer, FarmLane_GetTaskHandle())
			if farmLaneObjective and farmLaneObjective.type == UNIT_TYPE_IMAGINARY then
				local _, crashTime = Set_GetPredictedLaneFrontLocation(farmLaneObjective.lane)
				crashTime = GameTime() - crashTime
				local exposesToTowerDanger = nearestTower and Positioning_WillAttackCmdExposeToLocRad(
						gsiPlayer, farmLaneObjective,
						nearestTower.lastSeen.location, nearestTower.attackRange + 200
					) and -50 or 0
				if TEST then INFO_print(string.format("push returning no enemy no allied imaginary %.2f", crashTime)) end
				return farmLaneObjective,
						min(50, -theoreticalDanger*100) - Xeta_CostOfWaitingSeconds(gsiPlayer, crashTime or 5)
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
						nearestTower.lastSeen.location, nearestTower.attackRange + 200
					) then
				if VERBOSE then print("returning last push") end
				return arbitraryUnit,
						min(gsiPlayer.level*2,
								-40*(theoreticalDanger)
							)
						- Xeta_CostOfTravelToLocation(gsiPlayer, enemy.center)
						+ underAttack + finishAttack + attackStraysScore
			end
		end
		return false, XETA_SCORE_DO_NOT_RUN
	end,
	
	init = function(gsiPlayer, objective, extrapolatedXeta)
		return extrapolatedXeta
	end
}

function Push_GetTaskHandle()
	return task_handle
end
