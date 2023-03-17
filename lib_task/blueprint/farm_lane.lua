-- N.B. Naming choice aside, "confirmed denial" refers to a denial of the reservation of a last hit. I wasn't aware of Void Spirit saying it when I decided on the name. /shrug

FARM_LANE_LAST_HIT_RECHECK_THROTTLE = 0.035 -- It is still checked, probably every frame. Low FPS computers are more likely to skip a frame, but it's not likely. Depends on how many re-prios the frame got.

MAX_RANGE_SET_CONFIRMED_DENIAL_LAST_HIT = 950

VALUE_OF_LANING_STAGE_CREEP_SET = 250 -- accurate init in creep set bounty job
EXP_VALUE_OF_LANING_STAGE_CREEP_SET = 180

local BREAK_FARM_SEAL_POWER_LEVEL = Analytics_GetPerfectKDAPowerLevel(6)

---- farm_lane constants --
local DISCOURAGE_FACTOR = 80
local UNIT_TYPE_CREEP = UNIT_TYPE_CREEP
local UNIT_TYPE_IMAGINARY = UNIT_TYPE_IMAGINARY
local PLAYERS_ALL = PLAYERS_ALL
local TASK_PRIORITY_TOP = TASK_PRIORITY_TOP
local CREEP_ENEMY = CREEP_ENEMY
local HIGH_CREEP_MAX_HEALTH = HIGH_CREEP_MAX_HEALTH
local max = math.max
local min = math.min
local abs = math.abs
local DEBUG = DEBUG
local TEST = TEST
local VERBOSE = VERBOSE
--

local confirmed_last_hit_request_denials = {} -- Don't last hit that creep it's mine!! (Or no longer mine, I'm unable to LH two creeps on 30 HP at the same time, go for it!!)
local confirmed_lane_creep_set_request_denials = {} -- I'm pushing the wave down, don't request to come here to farm my wave!!

local FIGHTING_NO_FARMING_EXPIRY = 2
local t_fighting_no_farming_expiry = {}
local t_utilizing_lane_safety_value = {} -- is the bot still locked to a lane during the early game
local t_power_seal_throttle = {} -- Should the bot check if it can start roaming the map freely

local task_handle = Task_CreateNewTask()

local blueprint_farm_lane

local iobj_lane_creep_sets = {} -- Imaginary creep sets, and how long until they arrive (you will get a few last hits here, in about 40 seconds) 
local iobj_lane_creep_wave_crash_time = {} -- the time until a predicted wave crashes

local function update_lane_creep_set_last_hit_predictions__job(workingSet)
	if workingSet.throttle:allowed() then
		local alliedCreepSets = Set_GetAlliedCreepSetsInLane()
		for i=1,#alliedCreepSets,1 do
		
		end
	end
end

local function register_last_hit_request(gsiPlayer, creep, extrapolatedXeta)
	if not confirmed_last_hit_request_denials[creep] then
		confirmed_last_hit_request_denials[creep] = {}
	end
	local confirmedDenial = confirmed_last_hit_request_denials[creep]
	confirmedDenial.player = gsiPlayer
	confirmedDenial.extrapolatedXeta = extrapolatedXeta
	--print("Set confirmed denial for", gsiPlayer.shortName, creep)
end

local function register_lane_creep_set_request(gsiPlayer, creepSet, extrapolatedXeta)
	if not confirmed_lane_creep_set_request_denials[creepSet] then
		confirmed_lane_creep_set_request_denials[creepSet] = {}
	end
	local confirmedDenial = confirmed_lane_creep_set_request_denials[creepSet]
	confirmedDenial.player = gsiPlayer
	confirmedDenial.extrapolatedXeta = extrapolatedXeta
end

local function estimated_time_til_completed(gsiPlayer, objective)
	return 0 -- TODO
end
local function task_init_func(taskJobDomain)
	if VERBOSE then VEBUG_print(string.format("farm_lane: Initialized with handle #%d.", task_handle)) end
	
	for i=1,TEAM_NUMBER_OF_PLAYERS do
		t_utilizing_lane_safety_value[i] = true
		t_power_seal_throttle[i] = Time_CreateThrottle(8)
		t_fighting_no_farming_expiry[i] = 0
	end
	
	Task_RegisterTask(task_handle, PLAYERS_ALL, blueprint_farm_lane.run, blueprint_farm_lane.score, blueprint_farm_lane.init)
	
	taskJobDomain:RegisterJob( -- Task Score Priority Update
			function(workingSet)
				if workingSet.throttle:allowed() then
					Task_SetTaskPriority(task_handle, PLAYERS_ALL, TASK_PRIORITY_TOP)
				end
			end,
			{["throttle"] = Time_CreateThrottle(FARM_LANE_LAST_HIT_RECHECK_THROTTLE)}, 
			"JOB_TASK_SCORING_PRIORITY_FARM_LANE"
		)
	taskJobDomain:RegisterJob( -- Check for true gold and XP worth of 1 early-game lane creeps wave, then deregister
			function(workingSet)
				if workingSet.throttle:allowed() then
					if GameTime() > 240.33 then taskJobDomain:DeregisterJob("JOB_TASK_FARM_LANE_GET_LANING_STAGE_CREEP_SET_BOUNTY") return end  -- n.b. % 1.0 ~= 0.0 deregister
					-- TODO Bugged if some smart-arse precasts a wave wiping nuke before it spawns
					local exampleCreepSpawn = Set_GetAlliedCreepSetsInLane(MAP_LOGICAL_MIDDLE_LANE) and Set_GetAlliedCreepSetsInLane(MAP_LOGICAL_MIDDLE_LANE)[1]
					if exampleCreepSpawn then
						VALUE_OF_LANING_STAGE_CREEP_SET = 0
						EXP_VALUE_OF_LANING_STAGE_CREEP_SET = 0
						for i=1,#exampleCreepSpawn.units,1 do
							if exampleCreepSpawn.units[i].hUnit.GetBountyGoldMax then
								VALUE_OF_LANING_STAGE_CREEP_SET = VALUE_OF_LANING_STAGE_CREEP_SET 
										+ ( 
											(exampleCreepSpawn.units[i].hUnit:GetBountyGoldMax() 
											+ exampleCreepSpawn.units[i].hUnit:GetBountyGoldMin() ) / 2 ) 
										+ Xeta_EvaluateExperienceGain(GetBot(), exampleCreepSpawn.units[i].hUnit:GetBountyXP())
								EXP_VALUE_OF_LANING_STAGE_CREEP_SET = EXP_VALUE_OF_LANING_STAGE_CREEP_SET + Xeta_EvaluateExperienceGain(GetBot(), exampleCreepSpawn.units[i].hUnit:GetBountyXP())
							end
						end
						if VALUE_OF_LANING_STAGE_CREEP_SET % 1.0 ~= 0 then
							Xeta_PassLaneWaveValue(VALUE_OF_LANING_STAGE_CREEP_SET, EXP_VALUE_OF_LANING_STAGE_CREEP_SET)
							INFO_print(string.format("Value of laning stage creep wave: %.2f, %.2f", VALUE_OF_LANING_STAGE_CREEP_SET, EXP_VALUE_OF_LANING_STAGE_CREEP_SET))
							taskJobDomain:DeregisterJob("JOB_TASK_FARM_LANE_GET_LANING_STAGE_CREEP_SET_BOUNTY")
						end
					end
				end
			end,
			{["throttle"] = Time_CreateThrottle(0.0)},
			"JOB_TASK_FARM_LANE_GET_LANING_STAGE_CREEP_SET_BOUNTY"
		)

	FarmJungle_Initialize()
		
	Blueprint_RegisterTaskActivityType(task_handle, ACTIVITY_TYPE["COLLECTING"])
	task_init_func = nil
	return task_handle, estimated_time_til_completed
end
Blueprint_RegisterTask(task_init_func)



function Farm_GetMostSuitedLane(gsiPlayer, localCreepSet)
	local roleBasedLane = Team_GetRoleBasedLane(gsiPlayer)
	-- "return" to your assigned lane unless you're in kill mode or the only core here, before you can 
	-- farm jungle. as "return" because any single task could keep a bot in any location at any time, but if
	-- there is nothing of value to do here, consider only your role's lane.
	--print(gsiPlayer.shortName, "sees localCreepSet lane ", localCreepSet and localCreepSet.lane, Blueprint_GetCurrentTaskActivityType(gsiPlayer), ACTIVITY_TYPE.CONTROLLED_AGGRESSION, localCreepSet and Farm_AnyOtherCoresInLane(gsiPlayer, localCreepSet))
	if t_utilizing_lane_safety_value[gsiPlayer.nOnTeam] then
		if gsiPlayer.level >= 4
				and (GSI_AnyTierUnderHealthPercent(1, 0.15)
						or Analytics_GetPowerLevel(gsiPlayer) > BREAK_FARM_SEAL_POWER_LEVEL)
				and Farm_JungleCampClearViability(gsiPlayer, JUNGLE_CAMP_HARD) > 1 then
			INFO_print(string.format("[farm_lane] %s broke the power seal of lane-locking. "..
						"PLvl:%.2f. ReqLvl:%.2f", gsiPlayer.shortName,
						Analytics_GetPowerLevel(gsiPlayer), BREAK_FARM_SEAL_POWER_LEVEL
					)
				)
			t_utilizing_lane_safety_value[gsiPlayer.nOnTeam] = false
			t_power_seal_throttle[gsiPlayer.nOnTeam] = nil
		elseif localCreepSet and localCreepSet.lane ~= roleBasedLane then
			if Blueprint_GetCurrentTaskActivityType(gsiPlayer) > ACTIVITY_TYPE.CONTROLLED_AGGRESSION
					and Farm_AnyOtherCoresInLane(gsiPlayer, localCreepSet) then
				return roleBasedLane
			end
			return localCreepSet.lane
		else
			return roleBasedLane
		end
	end
	if Blueprint_GetCurrentTaskActivityType(gsiPlayer) >= ACTIVITY_TYPE.CONTROLLED_AGGRESSION
			and (
				localCreepSet and Farm_AnyOtherCoresInLane(gsiPlayer, localCreepSet)
			) then
		-- hindsight: If you are... assisting a core, while in any role yourself, then
		-- -| stay in lane if you are being aggressive... If it is a support then you're
		-- -| quite welcome to TP away
		return localCreepSet.lane
	end

	return Team_GetStrategicLane(gsiPlayer)
end

local function try_deny_creep(gsiPlayer, friendlyCreep)
	if not friendlyCreep then
		friendlyCreep = Lhp_GetAnyDeniesViableSimple(gsiPlayer)
	end
	--print(gsiPlayer.shortName, "deny is ", currentAttackTarget, viableDeny and viableDeny.lastSeenHealth)
	if friendlyCreep then
		denyNowForBestLastHit, timeTillStartDeny = Lhp_AttackNowForBestLastHit(gsiPlayer, friendlyCreep)
		--print(gsiPlayer.shortName, "deny now:", denyNowForBestLastHit, "deny start attack:", timeTillStartDeny)
		if denyNowForBestLastHit then
			if DEBUG then DebugDrawCircle(friendlyCreep.lastSeen.location, 150, 255, 255, 100) end
			if DEBUG and DEBUG_IsBotTheIntern() then DebugDrawText(950, 484, "denyNowBest", 0, 255, 0) end
			gsiPlayer.hUnit:Action_AttackUnit(friendlyCreep.hUnit, false)
			return true
		end
			if DEBUG and DEBUG_IsBotTheIntern() then DebugDrawText(950, 492, "denyMoveCloser", 0, 255, 0) end
			Positioning_ZSAttackRangeUnitHugAllied(
					gsiPlayer,
					friendlyCreep.lastSeen and friendlyCreep.lastSeen.location or friendlyCreep.center,
					SET_HEROES_ENEMY, -- Needs check if heroes attacking
					Unit_GetHealthPercent(gsiPlayer)*5, -- TODO lazily scaled
					max(0, timeTillStartDeny),
					true
				)
	end
	return false
end

local tickRateOneFrameGo = Time_CreateOneFrameGoThrottle(0.031)
---- Blueprint --
blueprint_farm_lane = {
	run = function(gsiPlayer, objective, xetaScore)
		if Unit_IsNullOrDead(objective) then tickRateOneFrameGo.next = 0 --[[print(gsiPlayer.shortName, "returning dead farm_lane")--]] return XETA_DO_NOT_SCORE end -- Creep died on the millisecond, or we're back from a different task that dropped score, rescore.
		local attackNowForBestLastHit = false
		local timeTillStartAttack = 0
		--print(GameTime(), gsiPlayer.shortName, "trying farm lane")
		if not t_utilizing_lane_safety_value[gsiPlayer.nOnTeam] then
			FarmJungle_IncentiviseJungling(gsiPlayer, objective)
		end
		if objective.type == UNIT_TYPE_CREEP and GSI_UnitCanStartAttack(gsiPlayer) then
			if objective.team == TEAM then
				if try_deny_creep(gsiPlayer, objective) then -- Objective is a deny
					return xetaScore
				end
			else -- Objective is a high-scoring low-health enemy creep
				if not confirmed_last_hit_request_denials[objective] or confirmed_last_hit_request_denials[objective].player ~= gsiPlayer then
					if DEBUG then 
						print(gsiPlayer.shortName, "informing end farm_lane task with objective and playername-in-confirmed-denial:", objective, confirmed_last_hit_request_denials[objective] and confirmed_last_hit_request_denials[objective].player.shortName)
						DebugDrawLine(gsiPlayer.lastSeen.location, objective.lastSeen.location, 255, 0, 0)
					end
					Farm_CancelAnyConfirmedDenials(gsiPlayer)
					return XETA_SCORE_DO_NOT_RUN
				end
				if DEBUG then DebugDrawLine(gsiPlayer.lastSeen.location, objective.lastSeen.location, 0, 255, 0) end
				if cUnit_IsNullOrDead(objective) then
					aRemovedObjective = objective
					confirmed_last_hit_request_denials[objective] = nil
					Task_InformObjectiveDisallow(gsiPlayer, {objective, nil})
				else
					cUnit_UpdateHealthAndLocation(objective)
					attackNowForBestLastHit, timeTillStartAttack = Lhp_AttackNowForBestLastHit(gsiPlayer, objective)
					local currentTarget = gsiPlayer.hUnit:GetAttackTarget()
					if DEBUG and DEBUG_IsBotTheIntern() then DebugDrawText(0, 242, string.format("%s, %.2f", attackNowForBestLastHit and "now" or "...", timeTillStartAttack), attackNowForBestLastHit and 0 or 255, 255, 255) end
					if attackNowForBestLastHit then
						if DEBUG and currentTarget and currentTarget:GetTeam() == TEAM then print(gsiPlayer.shortName, "is cancelling deny") end
						if DEBUG then DebugDrawLine(gsiPlayer.lastSeen.location, objective.lastSeen.location, 0, 126, 126) end

						if DEBUG and DEBUG_IsBotTheIntern() then DebugDrawText(950, 500, "attaNowBest", 255, 0, 0) end
						gsiPlayer.hUnit:Action_AttackUnit(objective.hUnit, false)
						return xetaScore
					elseif timeTillStartAttack > gsiPlayer.hUnit:GetSecondsPerAttack() or (currentAttackTarget and currentAttackTarget:GetTeam() == TEAM) then
						if try_deny_creep(gsiPlayer) then
							return xetaScore
						end
					end
				end
			end
		end
		--local numberUnitsAttackingThisPlayer = Analytics_GetNumberUnitsAttackingHUnit(gsiPlayer.hUnit)
		local mostDamagingType, damageTaken = Analytics_GetMostDamagingUnitTypeToUnit(gsiPlayer)
		if objective.type == UNIT_TYPE_IMAGINARY or objective.center then -- Make sure to last hit any low health creeps from the creep wave battle that just ended.
			-- TODO If creep set is real and friendly, body block to before tower based on state of the game
			local viableLastHitWhileWalkingAway = Lhp_GetAnyLastHitsViableSimple(gsiPlayer)
			if viableLastHitWhileWalkingAway then
				if DEBUG and DEBUG_IsBotTheIntern() then DebugDrawText(950, 508, "attaViableWalkAway", 255, 0, 0) end
				gsiPlayer.hUnit:Action_AttackUnit(viableLastHitWhileWalkingAway.hUnit, false)
				return xetaScore
			end
			local viableDenyBeforeWalkingAway = Lhp_GetAnyDeniesViableSimple(gsiPlayer)
			if viableDenyBeforeWalkingAway then
				if DEBUG and DEBUG_IsBotTheIntern() then DebugDrawText(950, 516, "denyViableWalkAway", 0, 255, 0) end
				gsiPlayer.hUnit:Action_AttackUnit(viableDenyBeforeWalkingAway.hUnit, false)
				return xetaScore
			end
			
			local targetLocation = objective.center or objective.lastSeen.location
			local maxActionDist = nil
			if Math_PointToPointDistance2D(gsiPlayer.lastSeen.location, targetLocation) < MINIMUM_ALLOWED_USE_TP_INSTEAD then
				maxActionDist = 600
			end
			local _, towerDist = Set_GetNearestTeamTowerToPlayer(ENEMY_TEAM, gsiPlayer)
			local moveTo = objective.lastSeen and objective.lastSeen.location or objective.center
			moveTo = Vector_Addition(
					moveTo,
					Vector_ScalarMultiply(
						Vector_UnitDirectionalPointToPoint(
							gsiPlayer.lastSeen.location,
							GSI_GetLowestTierTeamLaneTower(TEAM, objective.lane).lastSeen.location
						),
						450
					)
				)
			if DEBUG and DEBUG_IsBotTheIntern() then DebugDrawText(950, 524, "attaViableWalkAway", 255, 0, 0) end
			-- TODO Test set 1300 range tower dist
			Positioning_ZSMoveCasual(gsiPlayer, moveTo, 120*(damageTaken / gsiPlayer.lastSeenHealth) / Unit_GetHealthPercent(gsiPlayer)^3, towerDist < 2200 and 1300 or nil)
		else
			-- if DEBUG and DEBUG_IsBotTheIntern() then DebugDrawText(1500, 800, string.format("%f", timeTillStartAttack), 255, 255, 0) end
			local nearFutureHealth = Analytics_GetNearFutureHealthPercent(objective)
					
			if DEBUG and DEBUG_IsBotTheIntern() then DebugDrawText(950, 532, "attaWaitAttaNow", 255, 0, 0) end
			Positioning_ZSAttackRangeUnitHugAllied(
					gsiPlayer,
					objective.lastSeen and objective.lastSeen.location or objective.center,
					mostDamagingType, -- Needs check if heroes attacking
					(mostDamagingType == CREEP_ENEMY and 70 or 200)*(damageTaken / gsiPlayer.maxHealth) / math.min(0.1, Unit_GetHealthPercent(gsiPlayer)^2),
					max(0, timeTillStartAttack)
				)
			if DEBUG and TEAM_IS_RADIANT then
				DebugDrawText(600, 200+15*gsiPlayer.nOnTeam,
						string.format("PID%d\\ttatk: %.2f. giving: %.2f",
								gsiPlayer.playerID,
								timeTillStartAttack or 0,
								timeTillStartAttack * (nearFutureHealth > 0
									and	1-(objective.lastSeenHealth - nearFutureHealth)/objective.maxHealth or 1)
							),
						255, 255, 255)
			end
		end
	end,
		
	score = function(gsiPlayer, prevObjective, prevScore)
		if t_fighting_no_farming_expiry[gsiPlayer.nOnTeam] > GameTime() then
			return prevObjective, XETA_SCORE_DO_NOT_RUN
		end
		-- Will attempt to babysit creep-wave obssessed morons that want to dive towers
		-- -| before farm lane's lane-lock power seal is broken
		-- PROGRAMMING METHODOLOGY -- Lua functional calls are AS SLOW AS A FRIDGE -- Despite
		-- -| a local reference -- Avoid when possible in-loop.
		local laneToFarm = Map_GetLaneValueOfMapPoint(gsiPlayer.lastSeen.location)
		local thisPlayerRoleBasedLane = Team_GetRoleBasedLane(gsiPlayer)
		local enemyCreepSet = Set_GetEnemyCreepSetLaneFront(laneToFarm)
		if not t_utilizing_lane_safety_value[gsiPlayer.nOnTeam] or laneToFarm ~= thisPlayerRoleBasedLane then
			laneToFarm = Farm_GetMostSuitedLane(gsiPlayer, enemyCreepSet)
			if not enemyCreepSet or laneToFarm ~= enemyCreepSet.lane then
				--print("changing creep set to lane", laneToFarm, 'from', enemyCreepSet and enemyCreepSet.lane)
				enemyCreepSet = Set_GetEnemyCreepSetLaneFront(laneToFarm)
			end
		elseif t_power_seal_throttle[gsiPlayer.nOnTeam] and t_power_seal_throttle[gsiPlayer.nOnTeam]:allowed() then
			Farm_GetMostSuitedLane(gsiPlayer, nil)
		end
		--[[DEV]]if DEBUG and not TEAM_IS_RADIANT then DebugDrawText(2, 500+gsiPlayer.nOnTeam*8, string.format("%s-%d-%d-%d", string.sub(gsiPlayer.shortName,1,4), laneToFarm, Team_GetRoleBasedLane(gsiPlayer), Farm_GetMostSuitedLane(gsiPlayer, enemyCreepSet)), 255, 255, 255) end
		local alliedCreepSet = Set_GetAlliedCreepSetLaneFront(thisPlayerRoleBasedLane)
		local recentDamageTakenCare = Analytics_GetTotalDamageInTimeline(gsiPlayer.hUnit)*VALUE_OF_ONE_HEALTH
		local playerAttackDamage = gsiPlayer.hUnit:GetAttackDamage() -- nb. this is only to avoid a non-check on creeps not being damaged but very low health
		--if recentDamageTakenCare > gsiPlayer.maxHealth*0.065 then LeechExp_UpdatePriority(gsiPlayer) end DEPRECIATE

		local alliedCreepSetLoc = alliedCreepSet and alliedCreepSet.center
		local danger = Analytics_GetTheoreticalDangerAmount(
				gsiPlayer,
				nil,
				alliedCreepSet and Vector_Addition(alliedCreepSetLoc,
						Vector_ScalarMultiply(
								Vector_UnitDirectionalPointToPoint(
										alliedCreepSetLoc,
										TEAM_FOUNTAIN
									),
								gsiPlayer.attackRange
							)
					)
			)
		local dangerOfLaneScore = max(0, danger * DISCOURAGE_FACTOR
					* (1 + 2.5*(1 - (gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth)) )
				)

		local powerLevel = Analytics_GetPowerLevel(gsiPlayer)
		local awayFromLaneCareFactor = powerLevel < 4.5
				and GetGameState() == GAME_STATE_GAME_IN_PROGRESS
				and max(0, min(1,
						1 / ( 5.5 - ( Analytics_GetPowerLevel(gsiPlayer)
								* (3-gsiPlayer.vibe.greedRating)
									)
							)
						)
					)
				or 1

		 -- Find a good creep to be your next last hit objective, if there is a friendly creep set nearby (imaginary creep set objective tasks still seek and last hit any creeps that are 1-shot)
		if enemyCreepSet and alliedCreepSet and Set_LaneFrontCrashIsReal(laneToFarm)
				and Vector_PointDistance2D(gsiPlayer.lastSeen.location, enemyCreepSet.center) < 2000 then
			-- Check if the creep wave is deep past an enemy tower
			local crashIsDeep = false
			if Map_LimitLaneLocationToLowTierTeamTower(ENEMY_TEAM, laneToFarm, alliedCreepSet.center)
						~= alliedCreepSet.center then
				if DEBUG then DebugDrawText(650, 150+gsiPlayer.nOnTeam*8, string.format("%s bailing farm, %d crash too deep", gsiPlayer.shortName, laneToFarm), 255, 255, 255) end
				crashIsDeep = true
			end
			-- Return best creep and value
			local highestValueCreepXeta = XETA_SCORE_DO_NOT_RUN
			local highestValueCreep
			local highestValueCreepTimelineDamage = 0
			local previousPlayerForMyHighestValueCreep = nil
			local laneFrontUnitsEnemy = enemyCreepSet.units
			--[[DEV]]if DEBUG then DebugDrawCircle(enemyCreepSet.center, 100, 80, 0, 80) end
			local playerCurrentAttackDamage = max(1, gsiPlayer.hUnit:GetAttackDamage())
			if TEST and DEBUG_IsBotTheIntern() then
				print(gsiPlayer.shortName, "away from lane care factor", awayFromLaneCareFactor, powerLevel)
			end
			-- TODO count attacks in lane. If many creeps are in lane, a low number of reg-
			-- 		-istered attacks might suggest one of the creeps suddenly get punted because
			-- 		they were at the front of the pack, .'. stand 0.5-1.5s closer
			if DEBUG and DEBUG_IsBotTheIntern() then
				INFO_print(string.format("[farm_lane] INTERN scoring farm_lane, %d", #laneFrontUnitsEnemy))
			end
			for i=1,#laneFrontUnitsEnemy,1 do
				local thisCreep = laneFrontUnitsEnemy[i]
				local thisCreepNearFutureHealthPercent = Analytics_GetNearFutureHealthPercent(thisCreep)
				local totalDamageInTimeline = Analytics_GetTotalDamageInTimeline(thisCreep.hUnit)
				local thisXeta = XETA_SCORE_DO_NOT_RUN
				if not thisCreep.hUnit:IsNull() and thisCreep.hUnit:IsAlive()
						and ((thisCreep.creepType ~= CREEP_TYPE_RANGED and thisCreep.creepType ~= CREEP_TYPE_SIEGE)
							or thisCreep.lastSeenHealth ~= thisCreep.maxHealth)
						and (totalDamageInTimeline > 0 or thisCreep.lastSeenHealth < playerAttackDamage) then -- Don't score a full health range creep. (hack). Note dominated units are included if full health
					thisXeta = Xeta_EvaluateObjectiveCompletion(XETA_CREEP_KILL,
							Math_ETA(gsiPlayer, thisCreep.lastSeen.location)
									* awayFromLaneCareFactor,
							1.0, gsiPlayer, thisCreep)
					if thisXeta == 0 then
						ERROR_print(string.format("0-value creep found. %s, %.2f, %.2f",
									thisCreep.hUnit:GetUnitName(),
									thisCreep.hUnit:GetBountyGoldMax(),
									thisCreep.hUnit:GetBountyXP()
								)
							)
					end
					thisXeta = thisXeta/1.2
					thisXeta = thisXeta * (playerCurrentAttackDamage + totalDamageInTimeline)/(playerCurrentAttackDamage+thisCreep.lastSeenHealth)
					thisXeta = thisXeta - recentDamageTakenCare
				end
				if prevObjective == thisCreep then prevScore = thisXeta end
			--[[DEV]]	if VERBOSE and DEBUG_IsBotTheIntern() then
			--[[DEV]]		local x, y = Math_ScreenCoordsToCartesianCentered(thisCreep.lastSeen.location.x - gsiPlayer.hUnit:GetLocation().x, gsiPlayer.hUnit:GetLocation().y - thisCreep.lastSeen.location.y, 0.6)
			--[[DEV]]		local _, player = Farm_CheckTakeOverLastHitRequest(gsiPlayer, thisCreep, thisXeta*0.9)
			--[[DEV]]		DebugDrawText(x, y, string.format("%d:%.1f:%s", thisCreep.lastSeenHealth, thisXeta, player and string.sub(player.shortName,1,4) or ""), TEAM==TEAM_DIRE and 30 or 255, TEAM==TEAM_RADIANT and 30 or 255, 30)
			--[[DEV]]	end
				if thisXeta > highestValueCreepXeta then
					local allowedTakeOver, thisPreviousPlayer = 
							Farm_CheckTakeOverLastHitRequest(gsiPlayer, thisCreep, thisXeta*0.9)
					if allowedTakeOver then
						previousPlayerForMyHighestValueCreep = thisPreviousPlayer
						highestValueCreepXeta = thisXeta
						highestValueCreep = thisCreep
						highestValueCreepTimelineDamage = totalDamageInTimeline
					end
				end
			end
			local attackNowForBestLastHit, timeTillStartAttack = highestValueCreep
					and Lhp_AttackNowForBestLastHit(gsiPlayer, highestValueCreep) or false, 0xFFFF

			-- Make objective a deny if we have time before the enemy creep last hit
			if not timeTillStartAttack or timeTillStartAttack > gsiPlayer.hUnit:GetSecondsPerAttack() then
				if crashIsDeep then
					local goBackToPreviousAlliedCheck = Unit_GetArmorPhysicalFactor(gsiPlayer)
							* (4+danger) * max(0.33, 5 - gsiPlayer.level)
					--[DEBUG]]if DEBUG then print("go back check: ", goBackToPreviousAlliedCheck) end
					if goBackToPreviousAlliedCheck > 1 then
						if DEBUG then
							DebugDrawLine(gsiPlayer.lastSeen.location, alliedCreepSet.center, 255, 0, 0)
							if DEBUG_IsBotTheIntern() then
								print("farm_lane::score() returning 7")
							end
						end
						local saferUnit = Set_GetSaferLaneObject(alliedCreepSet)
						local saferUnitLoc = saferUnit.center or saferUnit.lastSeen.location
						return enemyCreepSet, XETA_SCORE_DO_NOT_RUN+1 -- have objective hack (leech exp)
					end
				end
				local viableDeny = Lhp_GetAnyDeniesViableSimple(gsiPlayer)
				if viableDeny and max(viableDeny.lastSeenHealth, playerCurrentAttackDamage)
						< (highestValueCreep and highestValueCreep.lastSeenHealth-highestValueCreepTimelineDamage or 0xFFFF) then
					if DEBUG and DEBUG_IsBotTheIntern() then
						print("farm_lane::score() returning 1")
					end
					return viableDeny,
							(crashIsDeep and alliedCreepSet and 1 - 1/max(1, #(alliedCreepSet.units)) or 1)
								* 0.66 * Xeta_EvaluateObjectiveCompletion(
										XETA_CREEP_DENY,
										Math_ETA(gsiPlayer, viableDeny.lastSeen.location),
										1.0, 
										gsiPlayer,
										viableDeny
									)
								- recentDamageTakenCare - dangerOfLaneScore
				end
			end
			if highestValueCreep then
				if prevObjective and prevObjective.type == UNIT_TYPE_CREEP and not Unit_IsNullOrDead(prevObjective) and not prevObjective.team == TEAM and Lhp_AttackNowForBestLastHit(gsiPlayer, prevObjective) and prevScore*1.15*(gsiPlayer.hUnit:GetAttackTarget() and 1.15 or 1.0) > highestValueCreepXeta then
					--print(gsiPlayer.shortName, "returning prev objective", prevObjective)
					if DEBUG and DEBUG_IsBotTheIntern() then
						print("farm_lane::score() returning 2")
					end
					return prevObjective, prevScore
				end
				
				if DEBUG and DEBUG_IsBotTheIntern() then
					print("farm_lane::score() returning 3")
					DebugDrawText(250, 800, string.format("%.3s [%d]r:(%.1f - %.1f - %.1f)",
									gsiPlayer.shortName, task_handle, highestValueCreepXeta,
									recentDamageTakenCare, dangerOfLaneScore
								),
							255, 255, 255
						)
				end
				return highestValueCreep, min(100,
						highestValueCreepXeta - recentDamageTakenCare - dangerOfLaneScore
					)
			end
			if DEBUG and DEBUG_IsBotTheIntern() then
				print("farm_lane::score() returning 4")
			end
			return alliedCreepSet, -recentDamageTakenCare - dangerOfLaneScore + 10 -- We have a creep set, but cores are denying all last hits (most probably there is only one creep). Implicit is lower greed rating
		end
		local iThisLaneToFarmObj = iobj_lane_creep_sets[laneToFarm]
		-- NO SUITABLE CREEP -- RETURN IMAGINARY CREEP SET
		-- print("Saw break in wave, lane", laneToFarm, "on team", TEAM, ".", enemyCreepSet,alliedCreepSet,Set_LaneFrontCrashIsReal(laneToFarm) )
		--print(iobj_lane_creep_sets[laneToFarm] and string.format("lane exists, expires %f", iobj_lane_creep_sets[laneToFarm].expires - GameTime()) or string.format("%s has no lane obj", gsiPlayer.shortName))
		if not iThisLaneToFarmObj
				or iThisLaneToFarmObj.expires < GameTime() then--( iobj_lane_creep_sets[laneToFarm] and iobj_lane_creep_sets[laneToFarm].expires < GameTime() ) then
			local locationOfNextLaneCreepBattle, timeUntilNextLaneCreepBattle = 
					Set_GetPredictedLaneFrontLocation(laneToFarm)
			if DEBUG then print("setting new imaginary for lane#: ", laneToFarm, locationOfNextLaneCreepBattle, timeUntilNextLaneCreepBattle) end
			if locationOfNextLaneCreepBattle then
				-- print("Setting new imaginary creep set xeta score object, lane", laneToFarm, "on team", TEAM)
				iobj_lane_creep_wave_crash_time[laneToFarm] = GameTime() + timeUntilNextLaneCreepBattle
				-- DebugDrawText(-1400+TEAM*800, 500+laneToFarm*20, string.format("%s, %s", locationOfNextLaneCreepBattle, Util_Printable(Map_LimitLaneLocationToLowTierTeamTower(
							-- ENEMY_TEAM,
							-- laneToFarm, 
							-- locationOfNextLaneCreepBattle
						-- ))), 255, 255, 255)
				-- DebugDrawLine(locationOfNextLaneCreepBattle, Map_LimitLaneLocationToLowTierTeamTower(
							-- ENEMY_TEAM,
							-- laneToFarm, 
							-- locationOfNextLaneCreepBattle
						-- ), 255, 128, 0)
				iThisLaneToFarmObj = iObjective_NewImaginarySafeUnit(
						Map_LimitLaneLocationToLowTierTeamTower(
							ENEMY_TEAM,
							laneToFarm, 
							locationOfNextLaneCreepBattle
						), ALLOWABLE_CREEP_SET_DIAMETER, iobj_lane_creep_wave_crash_time[laneToFarm]
					) -- TODO Primative expires time
				iThisLaneToFarmObj.lane = laneToFarm
				iobj_lane_creep_sets[laneToFarm] = iThisLaneToFarmObj
				if DEBUG and laneToFarm == MAP_LOGICAL_MIDDLE_LANE then DebugDrawCircle(locationOfNextLaneCreepBattle, 255, 255, 255, 255) end
			end
		end
		if iThisLaneToFarmObj then 
			-- Update the predicted crash loc
			local updatedPredictedLaneFront = Set_GetPredictedLaneFrontLocation(laneToFarm)
			if updatedPredictedLaneFront then
				iobj_lane_creep_sets[laneToFarm].lastSeen.location = updatedPredictedLaneFront
			end
			if DEBUG and DEBUG_IsBotTheIntern() then
				print("farm_lane::score() returning 5", crashIsDeep, laneToFarm)
				print(Math_ETA(gsiPlayer, iobj_lane_creep_sets[laneToFarm].lastSeen.location), 
									iobj_lane_creep_wave_crash_time[laneToFarm] - GameTime()
								, awayFromLaneCareFactor)
			end
			return iobj_lane_creep_sets[laneToFarm], 
					Xeta_EvaluateObjectiveCompletion(
						XETA_IMAGINARY_CREEP_SET_WAIT, 
						max(Math_ETA(gsiPlayer, iobj_lane_creep_sets[laneToFarm].lastSeen.location), 
								iobj_lane_creep_wave_crash_time[laneToFarm] - GameTime()
							) * awayFromLaneCareFactor, 
						0.75, -- at least, XP, also the value of not letting an enmy free farm, i.e. when the player is not doing well in lane. Perfect play is greater than x1 value due to the same things.
						gsiPlayer, 
						iobj_lane_creep_sets[laneToFarm]
					) - recentDamageTakenCare
		else
			if DEBUG and DEBUG_IsBotTheIntern() then
				print("farm_lane::score() returning 6")
			end
			return false, XETA_SCORE_DO_NOT_RUN
		end
	end,
	
	init = function(gsiPlayer, creep, extrapolatedXeta) -- 'my last hit, dont' -- TODO needs run or score func trigger
		if creep.type ~= UNIT_TYPE_CREEP or creep.team == TEAM then return extrapolatedXeta end
		local confirmedDenial = confirmed_last_hit_request_denials[creep]
		if confirmedDenial then
			if confirmedDenial.player == gsiPlayer then
				gsiPlayer.vibe.aggressivity = 0.35
				return extrapolatedXeta
			end
			
			--print(gsiPlayer.shortName, "sending objective disallow to", confirmedDenial.player.shortName, creep)
			Task_InformObjectiveDisallow(confirmedDenial.player, {creep, DENIAL_TYPE_FARM_LANE_CREEP})
		end
		Farm_CancelAnyConfirmedDenials(gsiPlayer)
		register_last_hit_request(gsiPlayer, creep, extrapolatedXeta)
		gsiPlayer.vibe.aggressivity = 0.35
		return extrapolatedXeta
	end
}
-- 

function Farm_CheckTakeOverLastHitRequest(gsiPlayer, creep, extrapolatedXeta) -- Returns [true if we are not the current confirmedDenial and allowed], [the previous player]
	local confirmedDenial = confirmed_last_hit_request_denials[creep]
	if confirmedDenial then
		local allowedSetConfirmedDenial = gsiPlayer == confirmedDenial.player or
					gsiPlayer.vibe.greedRating * extrapolatedXeta > 
					confirmedDenial.player.vibe.greedRating * confirmedDenial.extrapolatedXeta
		--print(gsiPlayer.shortName, allowedSetConfirmedDenial and "will" or "wont", "try to take"..(gsiPlayer.vibe.greedRating * extrapolatedXeta)..">"..(confirmedDenial.player.vibe.greedRating * confirmedDenial.extrapolatedXeta).." from "..confirmedDenial.player.shortName)
		return allowedSetConfirmedDenial, confirmedDenial.player
	end
	return true, nil
end

function Farm_TryLastHitRequest(gsiPlayer, creep, extrapolatedXeta)
	if Farm_CheckTakeOverLastHitRequest(gsiPlayer, creep, extrapolatedXeta) then
		Farm_SetLastHitRequest(gsiPlayer, creep, extrapolatedXeta)
	end
end

function Farm_AnyOtherCoresInLane(gsiPlayer, creepSet)
	local units = creepSet.units
	for i=1,#units do
		local confirmedDenial = confirmed_last_hit_request_denials[units[i]]
		if confirmedDenial and confirmedDenial.player ~= gsiPlayer and confirmedDenial.player.role <= 3 then
			--if DEBUG then print("I should leave lane for other cores", creepSet.lane, gsiPlayer.shortName) end -- what? no
			return true, confirmedDenial.player
		end
	end
	return false, nil
end

function Farm_TryCreepSetRequest(gsiPlayer, creepSet, extrapolatedXeta) -- Includes greedRating
	local confirmedDenial = confirmed_lane_creep_set_request_denials[creepSet]
	if confirmedDenial then
		if confirmedDenial.player == gsiPlayer then
			return true
		end
		if gsiPlayer.vibe.greedRating * extrapolatedXeta > 
				confirmedDenial.player.vibe.greedRating * confirmedDenial.extrapolatedXeta then
			Task_InformObjectiveDisallow(confirmedDenial.player, {creepSet, DENIAL_TYPE_FARM_LANE_CREEP_SET})
			register_jungle_set_farm_request(gsiPlayer, creepSet, extrapolatedXeta)
			return true
		end
		return false
	end
	register_creep_set_request(gsiPlayer, creep, extrapolatedXeta)
end

function Farm_CancelConfirmedDenial(gsiPlayer, objectiveDenied)
	if confirmed_last_hit_request_denials[objectiveDenied] then
		if confirmed_last_hit_request_denials[objectiveDenied].player == gsiPlayer then
			confirmed_last_hit_request_denials[objectiveDenied] = nil
			--gsiPlayer.hUnit:Action_ClearActions(true)
			--gsiPlayer.hUnit:Action_MoveToLocation(gsiPlayer.hUnit:GetLocation())
		end
	end
	if confirmed_lane_creep_set_request_denials[objectiveDenied] then
		if confirmed_lane_creep_set_request_denials[objectiveDenied].player == gsiPlayer then
			confirmed_lane_creep_set_request_denials[objectiveDenied] = nil
			--gsiPlayer.hUnit:Action_ClearActions(true)
			--gsiPlayer.hUnit:Action_MoveToLocation(gsiPlayer.hUnit:GetLocation())
		end
	end
end

function Farm_CancelAnyConfirmedDenials(gsiPlayer)
	for creep,tConfirmedDenial in pairs(confirmed_last_hit_request_denials) do
		if tConfirmedDenial.player == gsiPlayer then 
			confirmed_last_hit_request_denials[creep] = nil
			--gsiPlayer.hUnit:Action_ClearActions(true)
			--gsiPlayer.hUnit:Action_MoveToLocation(gsiPlayer.hUnit:GetLocation())
		end
	end
end

function FarmLane_GetTaskHandle()
	return task_handle
end

function FarmLane_UtilizingLaneSafety(gsiPlayer)
	return t_utilizing_lane_safety_value[gsiPlayer.nOnTeam]
end

function FarmLane_InformFightingNoFarming(gsiPlayer)
	t_fighting_no_farming_expiry[gsiPlayer.nOnTeam] = GameTime() + FIGHTING_NO_FARMING_EXPIRY
end

function FarmLane_AlternateTaskAllowance(gsiPlayer)
	local laningWith = gsiPlayer.laningWith
	if laningWith then
		local myScore = gsiPlayer.time.data.gankResistanceScore
		myScore = myScore or AbilityLogic_GetGankResistanceScore(gsiPlayer)
		local laningWithScore = laningWith.time.data.gankResistanceScore
		laningWithScore = laningWithScore or AbilityLogic_GetGankResistanceScore(laningWith)
		return sqrt(laningWithScore/myScore)
	else
		Map_GetLaneValueOfMapPoint(gsiPlayer.lastSeen.location)
	end
	return 0
end
