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

-- N.B. Naming choice aside, "confirmed denial" refers to a denial of the reservation of a last hit. I wasn't aware of Void Spirit saying it when I decided on the name. /shrug

FARM_LANE_LAST_HIT_RECHECK_THROTTLE = 0.035 -- It is still checked, probably every frame. Low FPS computers are more likely to skip a frame, but it's not likely. Depends on how many re-prios the frame got.

MAX_RANGE_SET_CONFIRMED_DENIAL_LAST_HIT = 950

VALUE_OF_LANING_STAGE_CREEP_SET = 250 -- accurate init in creep set bounty job
EXP_VALUE_OF_LANING_STAGE_CREEP_SET = 180

local BREAK_FARM_SEAL_POWER_LEVEL = Analytics_GetPerfectKDAPowerLevel(6)

---- farm_lane constants --
local DISCOURAGE_FACTOR = 50
local UNIT_TYPE_CREEP = UNIT_TYPE_CREEP
local UNIT_TYPE_IMAGINARY = UNIT_TYPE_IMAGINARY
local PLAYERS_ALL = PLAYERS_ALL
local TASK_PRIORITY_TOP = TASK_PRIORITY_TOP
local CREEP_ENEMY = CREEP_ENEMY
local HIGH_CREEP_MAX_HEALTH = HIGH_CREEP_MAX_HEALTH
local max = math.max
local min = math.min
local abs = math.abs
local remove = table.remove
local DEBUG = DEBUG
local TEST = TEST
local VERBOSE = VERBOSE
local CREEP_AGRO_RANGE = CREEP_AGRO_RANGE
local TEAM_FOUNTAIN = TEAM_FOUNTAIN
local XETA_SCORE_DO_NOT_RUN = XETA_SCORE_DO_NOT_RUN
local GAME_STATE_IN_PROGRESS = GAME_STATE_IN_PROGRESS
local CREEP_TYPE_MELEE = CREEP_TYPE_MELEE
local CREEP_TYPE_RANGED = CREEP_TYPE_RANGED
local CREEP_TYPE_SIEGE = CREEP_TYPE_SIEGE
local TEAM = TEAM
local ENEMY_TEAM = ENEMY_TEAM
--


-- ()
local Map_GetLaneValueOfMapPoint = Map_GetLaneValueOfMapPoint
local Team_GetRoleBasedLane = Team_GetRoleBasedLane
local Team_GetStrategicLane = Team_GetStrategicLane
local Set_GetEnemyCreepSetLaneFront = Set_GetEnemyCreepSetLaneFront
local Tilt_ReportSelfOutOfLane = Tilt_ReportSelfOutOfLane
local Task_GetTaskObjective = Task_GetTaskObjective
local pUnit_IsNullOrDead = pUnit_IsNullOrDead
local Set_GetNearestTeamTowerToPlayer = Set_GetNearestTeamTowerToPlayer
local Vector_PointDistance2D = Vector_PointDistance2D
local Set_GetAlliedCreepSetLaneFront = Set_GetAlliedCreepSetLaneFront
local Analytics_GetTheoreticalDangerAmount = Analytics_GetTheoreticalDangerAmount
local Vector_PointDistance = Vector_PointDistance
local Vector_PointDistance2D = Vector_PointDistance2D
local Vector_Addition = Vector_Addition
local Vector_ScalarMultiply2D = Vector_ScalarMultiply2D
local Vector_UnitDirectionalPointToPoint = Vector_UnitDirectionalPointToPoint
local Analytics_GetPowerLevel = Analytics_GetPowerLevel
local Set_LaneFrontCrashIsReal = Set_LaneFrontCrashIsReal
local Map_LimitLaneLocationToLowTierTeamTower = Map_LimitLaneLocationToLowTierTeamTower
local Analytics_GetNearFutureHealthPercent = Analytics_GetNearFutureHealthPercent
local Analytics_GetFutureDamageInTimeline = Analytics_GetFutureDamageInTimeline
local Xeta_EvaluateObjectiveCompletion = Xeta_EvaluateObjectiveCompletion
local Math_ETA = Math_ETA
local Lhp_AttackNowForBestLastHit = Lhp_AttackNowForBestLastHit
local Unit_GetArmorPhysicalFactor = Unit_GetArmorPhysicalFactor
local Set_GetSaferLaneObject = Set_GetSaferLaneObject
local Lhp_GetAnyDeniesViableSimple = Lhp_GetAnyDeniesViableSimple
local Unit_IsNullOrDead = Unit_IsNullOrDead
-- /()

local confirmed_last_hit_request_denials = {} -- Don't last hit that creep it's mine!! (Or no longer mine, I'm unable to LH two creeps on 30 HP at the same time, go for it!!)
local confirmed_lane_creep_set_request_denials = {} -- I'm pushing the wave down, don't request to come here to farm my wave!!

local FIGHTING_NO_FARMING_EXPIRY = 2
local t_fighting_no_farming_expiry = {}
local t_utilizing_lane_safety_value = {} -- is the bot still locked to a lane during the early game
local t_power_seal_throttle = {} -- Should the bot check if it can start roaming the map freely

local task_handle = Task_CreateNewTask()

local fight_harass_handle

local blueprint_farm_lane

local t_creep_time_to_attack = {}

local iobj_lane_creep_sets = {} -- Imaginary creep sets, and how long until they arrive (you will get a few last hits here, in about 40 seconds) 
local iobj_lane_creep_wave_crash_time = {} -- the time until a predicted wave crashes

local t_recycle_lhr = {}

function FarmLane_IncentiviseHardLastHit(gsiPlayer, taskHandle, maxIncentive, healthAfterHit, duration)
	local playerAttackDamage = gsiPlayer.hUnit:GetAttackDamage()
	maxIncentive = maxIncentive or 20
	local incentive = max(0, -maxIncentive/2
			+ 1.5*maxIncentive*playerAttackDamage / (1 + playerAttackDamage + healthAfterHit^4)
		)
	
	if incentive == 0 then
		return false;
	end
	Task_IncentiviseTask(gsiPlayer, taskHandle, incentive, incentive / (duration or 4.5))
	return true
end
local FarmLane_IncentiviseHardLastHit = FarmLane_IncentiviseHardLastHit

local function update_lane_creep_set_last_hit_predictions__job(workingSet)
	if workingSet.throttle:allowed() then
		local alliedCreepSets = Set_GetAlliedCreepSetsInLane()
		for i=1,#alliedCreepSets,1 do
		
		end
	end
end

local function register_last_hit_request(gsiPlayer, creep, extrapolatedXeta)
	if not confirmed_last_hit_request_denials[creep] then
		confirmed_last_hit_request_denials[creep] = remove(t_recycle_lhr) or {}
	end
	local confirmedDenial = confirmed_last_hit_request_denials[creep]
	confirmedDenial.player = gsiPlayer
	confirmedDenial.extrapolatedXeta = extrapolatedXeta
	--print("Set confirmed denial for", gsiPlayer.shortName, creep)
end

local function register_lane_creep_set_request(gsiPlayer, creepSet, extrapolatedXeta)
	if not confirmed_lane_creep_set_request_denials[creepSet] then
		confirmed_lane_creep_set_request_denials[creepSet] = remove(t_recycle_lhr) or {}
	end
	local confirmedDenial = confirmed_lane_creep_set_request_denials[creepSet]
	confirmedDenial.player = gsiPlayer
	confirmedDenial.extrapolatedXeta = extrapolatedXeta
end

local function estimated_time_til_completed(gsiPlayer, objective)
	return 0 -- TODO
end
local function task_init_func(taskJobDomain)
	Blueprint_RegisterTaskName(task_handle, "farm_lane")
	if VERBOSE then VEBUG_print(string.format("farm_lane: Initialized with handle #%d.", task_handle)) end

	fight_harass_handle = FightHarass_GetTaskHandle()

	for i=1,TEAM_NUMBER_OF_PLAYERS do
		t_utilizing_lane_safety_value[i] = true
		t_power_seal_throttle[i] = Time_CreateThrottle(8)
		t_fighting_no_farming_expiry[i] = 0
		t_creep_time_to_attack[i] = {}
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

local function set_creep_attack_time(gsiPlayer, creep, tillAttackTime, xetaScore)
	local ttaTbl = t_creep_time_to_attack[gsiPlayer.nOnTeam]
	ttaTbl[1] = creep
	ttaTbl[2] = tillAttackTime
	ttaTbl[3] = xetaScore
end

function FarmLane_AnyCreepLastHitTracked(gsiPlayer)
	local ttaTbl = t_creep_time_to_attack[gsiPlayer.nOnTeam]
	if ttaTbl[1] and not cUnit_IsNullOrDead(ttaTbl[1]) then



		return ttaTbl[1], ttaTbl[2], max(0, ttaTbl[3])
	end
	return nil, 10, max(0, ttaTbl[3] or 0) -- creepOrNil, tta, score
end
local FarmLane_AnyCreepLastHitTracked = FarmLane_AnyCreepLastHitTracked

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
local Farm_CheckTakeOverLastHitRequest = Farm_CheckTakeOverLastHitRequest

function Farm_TryLastHitRequest(gsiPlayer, creep, extrapolatedXeta)
	if Farm_CheckTakeOverLastHitRequest(gsiPlayer, creep, extrapolatedXeta) then
		Farm_SetLastHitRequest(gsiPlayer, creep, extrapolatedXeta)
	end
end
local Farm_TryLastHitRequest = Farm_TryLastHitRequest

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
local Farm_AnyOtherCoresInLane = Farm_AnyOtherCoresInLane

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
local Farm_TryCreepSetRequest = Farm_TryCreepSetRequest

function Farm_CancelConfirmedDenial(gsiPlayer, objectiveDenied)
	local denial = confirmed_last_hit_request_denials[objectiveDenied]
	if denial and denial.player == gsiPlayer then
		local recyc = t_recycle_lhr
		recyc[#recyc] = denial
		confirmed_last_hit_request_denials[objectiveDenied] = nil
	end
	denail = confirmed_lane_creep_set_request_denials[objectiveDenied]
	if denial and denial.player == gsiPlayer then
		recyc[#recyc] = denial
		confirmed_lane_creep_set_request_denials[objectiveDenied] = nil
	end
end
local Farm_CancelConfirmedDenial = Farm_CancelConfirmedDenial

function Farm_CancelAnyConfirmedDenials(gsiPlayer)
	for creep,tConfirmedDenial in next,confirmed_last_hit_request_denials do
		if tConfirmedDenial.player == gsiPlayer then 
			local recyc = t_recycle_lhr
			recyc[#recyc] = tConfirmedDenial
			confirmed_last_hit_request_denials[creep] = nil
		end
	end
end
local Farm_CancelAnyConfirmedDenials = Farm_CancelAnyConfirmedDenials

function FarmLane_IsUtilizingLaneSafety(gsiPlayer)
	return t_utilizing_lane_safety_value[gsiPlayer.nOnTeam]
end
local FarmLane_IsUtilizingLaneSafety = FarmLane_IsUtilizingLaneSafety

function Farm_GetMostSuitedLane(gsiPlayer, localCreepSet)
	local roleBasedLane = Team_GetRoleBasedLane(gsiPlayer)
	-- "return" to your assigned lane unless you're in kill mode or the only core here, before you can 
	-- farm jungle. as "return" because any single task could keep a bot in any location at any time, but if
	-- there is nothing of value to do here, consider only your role's lane.
	--print(gsiPlayer.shortName, "sees localCreepSet lane ", localCreepSet and localCreepSet.lane, Blueprint_GetCurrentTaskActivityType(gsiPlayer), ACTIVITY_TYPE.CONTROLLED_AGGRESSION, localCreepSet and Farm_AnyOtherCoresInLane(gsiPlayer, localCreepSet))
	if t_utilizing_lane_safety_value[gsiPlayer.nOnTeam] then
		if gsiPlayer.level >= 4
				and (GSI_AnyTierUnderHealthPercent(1, 0.20)
						or Analytics_GetPowerLevel(gsiPlayer, nil, true)
								> BREAK_FARM_SEAL_POWER_LEVEL)
				and Farm_JungleCampClearViability(gsiPlayer, JUNGLE_CAMP_HARD) >
					GSI_LowestTierHealthPercentWithDead(2) then
			INFO_print(string.format("[farm_lane] %s broke the power seal of lane-locking. "..
						"PLvl:%.2f. ReqLvl:%.2f", gsiPlayer.shortName,
						Analytics_GetPowerLevel(gsiPlayer, nil, true), BREAK_FARM_SEAL_POWER_LEVEL
					)
				)
			t_utilizing_lane_safety_value[gsiPlayer.nOnTeam] = false
			t_power_seal_throttle[gsiPlayer.nOnTeam] = nil
		elseif localCreepSet and not localCreepSet.isImaginary and localCreepSet.lane ~= roleBasedLane then
			if Blueprint_GetCurrentTaskActivityType(gsiPlayer) > ACTIVITY_TYPE.CONTROLLED_AGGRESSION
					and Farm_AnyOtherCoresInLane(gsiPlayer, localCreepSet)
					or Vector_PointDistance2D(gsiPlayer.lastSeen.location, localCreepSet.center) > 2100 then
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
local Farm_GetMostSuitedLane = Farm_GetMostSuitedLane

local function try_deny_creep(gsiPlayer, friendlyCreep, limitTime)
	if not friendlyCreep then
		friendlyCreep = Lhp_GetAnyDeniesViableSimple(gsiPlayer)
	end
	
	if friendlyCreep then
		denyNowForBestLastHit, timeTillStartDeny, healthThen
				= Lhp_AttackNowForBestLastHit(gsiPlayer, friendlyCreep)
		
		set_creep_attack_time(gsiPlayer, friendlyCreep, timeTillStartDeny, 20 - 10*timeTillStartDeny)
		if denyNowForBestLastHit then
			if DEBUG then DebugDrawCircle(friendlyCreep.lastSeen.location, 30, 100, 0, 255) end
			if DEBUG and DEBUG_IsBotTheIntern() then DebugDrawText(950, 484, "denyNowBest", 0, 255, 0) end
			gsiPlayer.hUnit:Action_AttackUnit(friendlyCreep.hUnit, false)
			FarmLane_IncentiviseHardLastHit(gsiPlayer, fight_harass_handle, 25, healthThen, 1)
			return true
		end
		if not limitTime or timeTillStartDeny + gsiPlayer.hUnit:GetSecondsPerAttack() < limitTime then
			if DEBUG and DEBUG_IsBotTheIntern() then DebugDrawText(950, 492, "denyMoveCloser", 0, 255, 0) end
			Positioning_ZSAttackRangeUnitHugAllied(
					gsiPlayer,
					friendlyCreep.lastSeen and friendlyCreep.lastSeen.location or friendlyCreep.center,
					SET_HEROES_ENEMY, -- Needs check if heroes attacking
					700,
					max(0, timeTillStartDeny),
					timeTillStartDeny < 0.33,
					max(0, 0.4 - timeTillStartDeny*0.5)
				)
			return true;
		end
	end
	return false;
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
				try_deny_creep(gsiPlayer, objective) -- Objective is a deny
				return xetaScore;
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
					--Task_InformObjectiveDisallow(gsiPlayer, {objective, nil})
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
					elseif timeTillStartAttack > gsiPlayer.hUnit:GetSecondsPerAttack()*1.33 or (currentAttackTarget and currentAttackTarget:GetTeam() == TEAM) then
						if try_deny_creep(gsiPlayer, nil, timeTillStartAttack) then
							return xetaScore
						end
					elseif timeTillStartAttack > 0.45
							and objective.lastSeen.location.z - 30 > gsiPlayer.lastSeen.location.z
							and Vector_DistUnitToUnit(objective, gsiPlayer) < 600 then
						if LanePressure_AgroCreepsNow(gsiPlayer) then
							return xetaScore
						end
					elseif not gsiPlayer.isRanged
							and Vector_PointDistance2D(
									gsiPlayer.lastSeen.location,
									objective.lastSeen.location
								) < CREEP_AGRO_RANGE
							and #select(2, Analytics_GetTheoreticalDangerAmount(gsiPlayer)) > 1
							and LanePressure_AgroCreepsNow(gsiPlayer) then
						return xetaScore
					end
				end
			end
		end
		--local numberUnitsAttackingThisPlayer = Analytics_GetNumberUnitsAttackingHUnit(gsiPlayer.hUnit)
		local mostDamagingType, damageTaken = Analytics_GetMostDamagingUnitTypeToUnit(gsiPlayer)
		damageTaken = damageTaken / 4
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
					Vector_ScalarMultiply2D(
						Vector_UnitDirectionalPointToPoint2D(
							gsiPlayer.lastSeen.location,
							GSI_GetLowestTierTeamLaneTower(TEAM, objective.lane).lastSeen.location
						),
						650
					)
				)
			if DEBUG and DEBUG_IsBotTheIntern() then DebugDrawText(950, 524, "attaViableWalkAway", 255, 0, 0) end
			-- TODO Test set 1300 range tower dist
			Positioning_ZSMoveCasual(gsiPlayer, moveTo,
					450 + 120*(damageTaken / gsiPlayer.lastSeenHealth)
						/ max(0.125, Unit_GetHealthPercent(gsiPlayer)^3),
					towerDist < 2200 and 1300 or nil
				)
		else
			-- if DEBUG and DEBUG_IsBotTheIntern() then DebugDrawText(1500, 800, string.format("%f", timeTillStartAttack), 255, 255, 0) end
			local nearFutureHpp = Analytics_GetNearFutureHealthPercent(objective)
					
			if DEBUG and DEBUG_IsBotTheIntern() then DebugDrawText(950, 532, "attaWaitAttaNow", 255, 0, 0) end
			Positioning_ZSAttackRangeUnitHugAllied(
					gsiPlayer,
					objective.lastSeen and objective.lastSeen.location or objective.center,
					mostDamagingType, -- Needs check if heroes attacking
					(mostDamagingType == CREEP_ENEMY and 250 or 350)
						* (damageTaken / gsiPlayer.maxHealth)
						/ math.max(0.5, Unit_GetHealthPercent(gsiPlayer)),
					max(0, timeTillStartAttack),
					timeTillStartAttack < 0.33,
					max(0, 0.2 - timeTillStartAttack*0.2)
				)
			if DEBUG and TEAM_IS_RADIANT then
				DebugDrawText(600, 220+15*gsiPlayer.nOnTeam,
						string.format("PID%d\\ttatk: %.2f. giving: %.2f",
								gsiPlayer.playerID,
								timeTillStartAttack or 0,
								timeTillStartAttack * ((nearFutureHpp > 0)
										and	(1-(objective.lastSeenHealth/objective.maxHealth
											- nearFutureHpp)
										) or 1),
								timeTillStartAttack < 0.33
							),
						255, 255, 255)
			end
		end
	end,
		
	score = function(gsiPlayer, prevObjective, prevScore)
		-- Will attempt to babysit creep-wave obssessed morons that want to dive towers
		-- -| before farm lane's lane-lock power seal is broken
		-- PROGRAMMING METHODOLOGY -- Lua functional calls are AS SLOW AS A FRIDGE -- Despite
		-- -| a local reference -- Avoid when possible in-loop.
		set_creep_attack_time(gsiPlayer, nil,
				60, 0
			)
		local currentLocationLane = Map_GetLaneValueOfMapPoint(gsiPlayer.lastSeen.location)
		local laneToFarm = currentLocationLane
		local thisPlayerRoleBasedLane = Team_GetRoleBasedLane(gsiPlayer)
		local enemyCreepSet = Set_GetEnemyCreepSetLaneFront(laneToFarm)
		if not t_utilizing_lane_safety_value[gsiPlayer.nOnTeam] or laneToFarm ~= thisPlayerRoleBasedLane then
			laneToFarm = Farm_GetMostSuitedLane(gsiPlayer, enemyCreepSet)
			if not enemyCreepSet or laneToFarm ~= enemyCreepSet.lane then
				--print("changing creep set to lane", laneToFarm, 'from', enemyCreepSet and enemyCreepSet.lane)
				enemyCreepSet = Set_GetEnemyCreepSetLaneFront(laneToFarm)
			end
		elseif t_power_seal_throttle[gsiPlayer.nOnTeam] and t_power_seal_throttle[gsiPlayer.nOnTeam]:allowed() then
			Farm_GetMostSuitedLane(gsiPlayer, nil) -- check power seal
		end
		local isOutOfBestLane = laneToFarm ~= currentLocationLane
		if isOutOfBestLane then
			Tilt_ReportSelfOutOfLane(gsiPlayer, currentLocationLane)
		end
		if t_fighting_no_farming_expiry[gsiPlayer.nOnTeam] > GameTime() then
			-- Disallow farming if fighting

			if not isOutOfBestLane then
				return prevObjective, XETA_SCORE_DO_NOT_RUN+1
			else
				-- Early game get-to-lane fight-worth fences
			
				local fht = Task_GetTaskObjective(gsiPlayer, fight_harass_handle)
				local fhtReal = fht and not fht.typeIsNone and not pUnit_IsNullOrDead(fht)
				--local danger = Analytics_GetTheoreticalDangerAmount(gsiPlayer)
				local nearestEnemyTower = Set_GetNearestTeamTowerToPlayer(ENEMY_TEAM, gsiPlayer)
				-- If the player is not in thier designated lane, greatly benefits from the XP
				-- from lane, or their laning partner is alone and it is very early in the game, and the
				-- fight is not immediately benefited by the player being present, false it, continue scoring

				if fhtReal
						and nearestEnemyTower and 1.5 + gsiPlayer.level - 9*(fht.lastSeenHealth / fht.maxHealth)
							> (gsiPlayer.attackRange*0.9
								- Vector_PointDistance2D(fht.lastSeen.location,
								nearestEnemyTower.lastSeen.location)) / 300 then
					return prevObjective, XETA_SCORE_DO_NOT_RUN+1 -- fight, or leave via leech_exp (stupid/lazy TODO TODO -- still haven't caught up to the '0.7' that I wanted)
				end
			end
		end
		
		local alliedCreepSet = Set_GetAlliedCreepSetLaneFront(laneToFarm)
		local alliedCreepSetLoc = alliedCreepSet and alliedCreepSet.center

		local danger, knownE, theoryE = Analytics_GetTheoreticalDangerAmount(
				gsiPlayer,
				nil,
				alliedCreepSet and Vector_Addition(alliedCreepSetLoc,
						Vector_ScalarMultiply2D(
								Vector_UnitDirectionalPointToPoint(
										alliedCreepSetLoc,
										TEAM_FOUNTAIN
									),
								gsiPlayer.attackRange
							)
					)
			)
		local recentDamageTakenCare = (Analytics_GetTotalDamageInTimeline(gsiPlayer.hUnit)
					/ 5 + Analytics_GetFutureDamageInTimeline(gsiPlayer.hUnit) * 0.75 -- BAD spiky, controls them
				) * min(1.25, 0.5 + 0.5*(#knownE+#theoryE)) * VALUE_OF_ONE_HEALTH
		local playerAttackDamage = gsiPlayer.hUnit:GetAttackDamage() -- nb. this is only to avoid a non-check on creeps not being damaged but very low health
		--if recentDamageTakenCare > gsiPlayer.maxHealth*0.065 then LeechExp_UpdatePriority(gsiPlayer) end DEPRECIATE

		local dangerOfLaneScore = max(0, danger * DISCOURAGE_FACTOR
					* (0.4 + (#knownE+0.7*#theoryE)*(1 - (gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth)) )
				)

		local powerLevel = Analytics_GetPowerLevel(gsiPlayer)
		local awayFromLaneCareFactor = powerLevel < 4.5
				and GetGameState() == GAME_STATE_GAME_IN_PROGRESS
				
				and max(0, min(1,
						1 / ( 5.5 - ( powerLevel
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
			
			local playerCurrentAttackDamage = max(1, gsiPlayer.hUnit:GetAttackDamage())




			-- TODO count attacks in lane. If many creeps are in lane, a low number of reg-
			-- 		-istered attacks might suggest one of the creeps suddenly get punted because
			-- 		they were at the front of the pack, .'. stand 0.5-1.5s closer
			if DEBUG and DEBUG_IsBotTheIntern() then
				INFO_print(string.format("[farm_lane] scoring farm_lane, %d", #laneFrontUnitsEnemy))
			end
			local twicePlayerAttackDamage = 2 * playerAttackDamage
			for i=1,#laneFrontUnitsEnemy,1 do
				local thisCreep = laneFrontUnitsEnemy[i]
				local thisCreepNearFutureHealthPercent = Analytics_GetNearFutureHealthPercent(thisCreep)
				local futureDamage = Analytics_GetFutureDamageInTimeline(thisCreep.hUnit)
				local thisXeta = XETA_SCORE_DO_NOT_RUN
				if not thisCreep.hUnit:IsNull() and thisCreep.hUnit:IsAlive()
						and (futureDamage > 0 or thisCreep.lastSeenHealth < playerAttackDamage
							or (thisCreep.creepType ~= CREEP_TYPE_RANGED
								and thisCreep.creepType ~= CREEP_TYPE_SIEGE
							)
						) then -- Don't score a full health range creep. (crap hotfix). Note dominated units are included if full health
					thisXeta = Xeta_EvaluateObjectiveCompletion(XETA_CREEP_KILL,
							Math_ETA(gsiPlayer, thisCreep.lastSeen.location)
									* awayFromLaneCareFactor,
							1.0, gsiPlayer, thisCreep
						)
					if thisXeta == 0 then
						ERROR_print(false, not DEBUG, "[farm_lane] 0-value creep found. %s, %.2f, %.2f",
								thisCreep.hUnit:GetUnitName(),
								thisCreep.hUnit:GetBountyGoldMax(),
								thisCreep.hUnit:GetBountyXP()
							)
					end
					--thisXeta = thisXeta/1.2
					thisXeta = thisXeta * (twicePlayerAttackDamage + futureDamage/2)/(playerCurrentAttackDamage+thisCreep.lastSeenHealth)
					thisXeta = thisXeta - max(0, recentDamageTakenCare - thisCreep.hUnit:GetBountyGoldMin())*0.5
					
					
					
					
					
				end
				if prevObjective == thisCreep then prevScore = thisXeta end
			
			
			
			
			
				if thisXeta > highestValueCreepXeta then
					local allowedTakeOver, thisPreviousPlayer = 
							Farm_CheckTakeOverLastHitRequest(gsiPlayer, thisCreep, thisXeta*0.9)
					if allowedTakeOver then
						previousPlayerForMyHighestValueCreep = thisPreviousPlayer
						highestValueCreepXeta = thisXeta
						highestValueCreep = thisCreep
						highestValueCreepTimelineDamage = futureDamage
					end
				end
			end
			local attackNowForBestLastHit, timeTillStartAttack = (highestValueCreep
					and Lhp_AttackNowForBestLastHit(gsiPlayer, highestValueCreep, true)) or nil, 4

			-- Make objective a deny if we have time before the enemy creep last hit
			local secondsPerAttack = gsiPlayer.hUnit:GetSecondsPerAttack()
			local timeTillLands = highestValueCreep and timeTillStartAttacks
					and Projectile_TimeToLandProjectile(gsiPlayer, highestValueCreep) or 0
			if not timeTillStartAttack or timeTillStartAttack > secondsPerAttack*1.5 + timeTillLands then
				-- Having time for additional attacks before last hit...
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
						return enemyCreepSet, XETA_SCORE_DO_NOT_RUN+1 -- force objective save
					end
				end
				local viableDeny = Lhp_GetAnyDeniesViableSimple(gsiPlayer)
				if viableDeny then
					local attackDenyNow, timeTillStartDeny, healthThen
							= Lhp_AttackNowForBestLastHit(gsiPlayer, viableDeny, true)
					if timeTillStartDeny
							and timeTillStartAttack - timeTillStartDeny - secondsPerAttack
								> (highestValueCreep
									and viableDeny.creepType == CREEP_TYPE_MELEE
									and viableDeny.hUnit:GetAttackTarget() == highestValueCreep.hUnit
									and 0.35 or 0.75) then
						if DEBUG and DEBUG_IsBotTheIntern() then
							
						end
						
						local denyScore = Xeta_EvaluateObjectiveCompletion(
								XETA_CREEP_DENY,
								Math_ETA(gsiPlayer, viableDeny.lastSeen.location),
								1.0, 
								gsiPlayer,
								viableDeny
							) * 1.5 - 0.5*(gsiPlayer.vibe.greedRating)

						if attackDenyNow then
							FarmLane_IncentiviseHardLastHit(gsiPlayer, fight_harass_handle, 25, healthThen, 1)
						end

						return viableDeny,
								(crashIsDeep and alliedCreepSet and 1 - 1/max(1, #(alliedCreepSet.units)) or 1)
									* denyScore - recentDamageTakenCare*0.67
									- dangerOfLaneScore / max(0, 3-timeTillStartDeny)
									-- (recent damage taken is added in thisXeta of last hits, related to
									-- -| the creeps gold bounty maxed:0.)
					end
				end
			end
			if highestValueCreep then
				local checkPrev = prevObjective and prevObjective.type == UNIT_TYPE_CREEP
						and prevObjective ~= highestValueCreep
						and not Unit_IsNullOrDead(prevObjective) and not prevObjective.team == TEAM
				local attackNow, timeTillAttack = checkPrev
						and Lhp_AttackNowForBestLastHit(gsiPlayer, prevObjective, true)
				if checkPrev and attackNow and prevScore*1.15*(gsiPlayer.hUnit:GetAttackTarget() and 1.15 or 1.0)
							> highestValueCreepXeta then
					--print(gsiPlayer.shortName, "returning prev objective", prevObjective)
					set_creep_attack_time(gsiPlayer, prevObjective,
							timeTillAttack, prevScore
						)
					if DEBUG and DEBUG_IsBotTheIntern() then
						print("farm_lane::score() returning 2")
					end
					return prevObjective, prevObjective == highestValueCreep and highestValueCreepXeta or prevScore
				end
				
				local highestValueXeta = min(100,
						highestValueCreepXeta - dangerOfLaneScore
					)
				attackNow, timeTillAttack = Lhp_AttackNowForBestLastHit(gsiPlayer, highestValueCreep, true)
				set_creep_attack_time(gsiPlayer, highestValueCreep,
						timeTillAttack, highestValueXeta
					)
				if DEBUG and DEBUG_IsBotTheIntern() then
					print("farm_lane::score() returning 3")
					DebugDrawText(300, 850, string.format("%.3s [%d]r:(%.1f; %.1f; %.1f, ++%.1f)",
								gsiPlayer.shortName, task_handle, highestValueCreepXeta,
								recentDamageTakenCare, dangerOfLaneScore,
								dangerOfLaneScore * (0.67
										- 0.67 * max(0, min(1, 1 - timeTillAttack))
									)
							),
							255, 255, 255
						)
				end
				return highestValueCreep, highestValueXeta
						+ max(0, (dangerOfLaneScore+recentDamageTakenCare
							-highestValueCreep.hUnit:GetBountyGoldMin())) * (0.67
								- 0.67 * max(0, 1 - timeTillAttack)
							) - (crashIsDeep
								and 100/(1+gsiPlayer.ehpArmor*gsiPlayer.lastSeenHealth*0.001)
								or 0
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
				iobj_lane_creep_wave_crash_time[laneToFarm] = timeUntilNextLaneCreepBattle
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
				if DEBUG and laneToFarm == MAP_LOGICAL_MIDDLE_LANE then DebugDrawCircle(locationOfNextLaneCreepBattle, 3, 255, 255, 255) end
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

function FarmLane_GetTaskHandle()
	return task_handle
end

function FarmLane_UtilizingLaneSafety(gsiPlayer)
	return t_utilizing_lane_safety_value[gsiPlayer.nOnTeam]
end

function FarmLane_InformFightingNoFarming(gsiPlayer)
	t_fighting_no_farming_expiry[gsiPlayer.nOnTeam] = GameTime() + FIGHTING_NO_FARMING_EXPIRY
end

function FarmLane_UpdateHumanLastHit(gsiPlayer)
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
	if not enemyCreepSet or enemyCreepSet.isImaginary then
		return;
	end
	local distToSet = Vector_PointDistance2D(enemyCreepSet.center, gsiPlayer.lastSeen.location)
	if distToSet > 1600 then
		return;
	end
	local playerAttackDamage = gsiPlayer.hUnit:GetAttackDamage()
	local highestValueCreepXeta = XETA_SCORE_DO_NOT_RUN
	local highestValueCreep
	local playerAttackRangeCheck = gsiPlayer.attackRange + 500 -- nb- not having a huge buffer causes flip states as supports would try to get last hits momentarily
	local playerLoc = gsiPlayer.lastSeen.location
	local highestValueCreepTimelineDamage = 0
	local previousPlayerForMyHighestValueCreep = nil
	local laneFrontUnitsEnemy = enemyCreepSet.units
	local recentDamageTakenCare = Analytics_GetTotalDamageInTimeline(gsiPlayer.hUnit)*VALUE_OF_ONE_HEALTH*2
	-- ^| rather than div bounty minimum by 2
	local playerCurrentAttackDamage = max(1, gsiPlayer.hUnit:GetAttackDamage())
	for i=1,#laneFrontUnitsEnemy,1 do
		local thisCreep = laneFrontUnitsEnemy[i]
		if Vector_PointDistance2D(playerLoc, thisCreep.lastSeen.location) < playerAttackRangeCheck then
			local thisCreepNearFutureHealthPercent = Analytics_GetNearFutureHealthPercent(thisCreep)
			local futureDamage = Analytics_GetFutureDamageInTimeline(thisCreep.hUnit)
			local thisXeta = XETA_SCORE_DO_NOT_RUN
			if not thisCreep.hUnit:IsNull() and thisCreep.hUnit:IsAlive()
					and ((thisCreep.creepType ~= CREEP_TYPE_RANGED and thisCreep.creepType ~= CREEP_TYPE_SIEGE)
						or thisCreep.lastSeenHealth ~= thisCreep.maxHealth)
					and (futureDamage > 0 or thisCreep.lastSeenHealth < playerAttackDamage) then -- Don't score a full health range creep. (hack). Note dominated units are included if full health
				thisXeta = Xeta_EvaluateObjectiveCompletion(XETA_CREEP_KILL,
						Math_ETA(gsiPlayer, thisCreep.lastSeen.location),
						1.0, gsiPlayer, thisCreep)
				if thisXeta == 0 then
					ERROR_print(false, not DEBUG, "0-value creep found. %s, %.2f, %.2f",
							thisCreep.hUnit:GetUnitName(),
							thisCreep.hUnit:GetBountyGoldMax(),
							thisCreep.hUnit:GetBountyXP()
						)
				end
				thisXeta = thisXeta/1.2
				thisXeta = thisXeta * (playerCurrentAttackDamage + futureDamage)/(playerCurrentAttackDamage+thisCreep.lastSeenHealth)
				thisXeta = thisXeta - max(0, recentDamageTakenCare - thisCreep.hUnit:GetBountyGoldMin())
			end
			if prevObjective == thisCreep then prevScore = thisXeta end
			if thisXeta > highestValueCreepXeta then
				local allowedTakeOver, thisPreviousPlayer = 
						Farm_CheckTakeOverLastHitRequest(gsiPlayer, thisCreep, thisXeta*0.9)
				if allowedTakeOver then
					previousPlayerForMyHighestValueCreep = thisPreviousPlayer
					highestValueCreepXeta = thisXeta
					highestValueCreep = thisCreep
					highestValueCreepTimelineDamage = futureDamage
				end
			end
		end
	end
	if not highestValueCreep then
		return;
	end
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
	register_last_hit_request(gsiPlayer, highestValueCreep, highestValueCreepXeta)
	--gsiPlayer.vibe.aggressivity = 0.35 --[[AGGRESIVITY OFF]] -- TODO
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
