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

LEECH_EXP_RANGE = 1000
local LEECH_EXP_RANGE = LEECH_EXP_RANGE

local INCREASE_SAFETY_STAYING_IS_DYING_SCORE = 150

local TEST = TEST and true

local LEECH_EXP_THROTTLE = 0.139

local blueprint

local task_handle = Task_CreateNewTask()

local t_leech_exp_scores = {}

local t_team_players = {}

local max = math.max
local min = math.min
local Set_GetEnemyHeroesInPlayerRadiusAndOuterlocal = Set_GetEnemyHeroesInPlayerRadiusAndOuter
local FightHarass_GetHealthDiffOutnumbered = FightHarass_GetHealthDiffOutnumbered
local FightClimate_AnyIntentToHarm = FightClimate_AnyIntentToHarm
local UNIT_TYPE_IMAGINARY = UNIT_TYPE_IMAGINARY
local increase_safety_handle
local fight_harass_handle
local farm_lane_handle

local TEAM = GetTeam()

local next_player = 1
local function estimated_time_til_completed(gsiPlayer, objective)
	return 0 -- doing nothing anyways, also, don't care
end
local function task_init_func(taskJobDomain)
	Blueprint_RegisterTaskName(task_handle, "leech_experience")
	if VERBOSE then VEBUG_print(string.format("leech_experience: Initialized with handle #%d.", task_handle)) end
	
	t_team_players = GSI_GetTeamPlayers(TEAM)

	for i=1,TEAM_NUMBER_OF_PLAYERS,1 do
		t_leech_exp_scores[i] = 0
	end
	
	Task_RegisterTask(task_handle, PLAYERS_ALL, blueprint.run, blueprint.score, blueprint.init)

	farm_lane_handle = FarmLane_GetTaskHandle()
	increase_safety_handle = IncreaseSafety_GetTaskHandle()
	avoid_hide_handle = AvoidHide_GetTaskHandle()
	fight_harass_handle = FightHarass_GetTaskHandle()
	
	local ACTIVITY_TYPE = ACTIVITY_TYPE
	taskJobDomain:RegisterJob(
			function(workingSet)
				if workingSet.throttle:allowed() then
					local gsiPlayer = t_team_players[next_player]
					local nearbyEnemies = Set_GetEnemyHeroesInPlayerRadius(gsiPlayer, 1400, 20)
					local currentActivityType = Blueprint_GetCurrentTaskActivityType(gsiPlayer)
					if #nearbyEnemies > 0
							or currentActivityType >= ACTIVITY_TYPE.FEAR then
						Task_SetTaskPriority(task_handle, next_player, TASK_PRIORITY_TOP)
					end
					next_player = Task_RotatePlayerOnTeam(next_player)
				end
			end,
			{["throttle"] = Time_CreateThrottle(LEECH_EXP_THROTTLE)},
			"JOB_TASK_SCORING_PRIORITY_LEECH_EXP"
		)
	
	Blueprint_RegisterTaskActivityType(task_handle, ACTIVITY_TYPE["CAREFUL"])
	task_init_func = nil
	return task_handle, estimated_time_til_completed
end
Blueprint_RegisterTask(task_init_func)

local function get_lexp_standing_loc(gsiPlayer, farmLaneObj, timeTillStartAttack)
	timeTillStartAttack = timeTillStartAttack or 2
	local farmLaneObj = farmLaneObj or Task_GetTaskObjective(gsiPlayer, farm_lane_handle)
	local activeLane = Farm_GetMostSuitedLane(gsiPlayer, farmLaneObj and farmLaneObj.ofUnitSet)
	local tmp = gsiPlayer.attackRange
	-- TODO BUG SAFE, LOGICALLY RELEVANT MOVEMENT
	gsiPlayer.attackRange = LEECH_EXP_RANGE -- Spoof our attack range
	local crashedLane = farmLaneObj and farmLaneObj.lastSeen
	local moveTo = farmLaneObj and (farmLaneObj.center or farmLaneObj.lastSeen.location)
			or Set_GetPredictedLaneFrontLocation(Farm_GetMostSuitedLane(gsiPlayer))
	local careFactor = 70 / math.max(0.1, Unit_GetHealthPercent(gsiPlayer)^2)
	local moveTo = Positioning_ZSAttackRangeUnitHugAllied(
			gsiPlayer, moveTo, SET_HERO_ENEMY, -- Needs check if heroes attacking
			careFactor, min(2.5, math.max(0, timeTillStartAttack)),
			timeTillStartAttack < 0.33, -- forceAttackRange
			not crashedLane and 0.0, true, crashedLane and 1 or 0 -- aheadness, dryRun
		)
	gsiPlayer.attackRange = tmp
	local underTower = Set_GetTowerOverLocation(moveTo, ENEMY_TEAM)
	if underTower then
		moveTo = Positioning_AdjustToAvoidLocationFlipAggressive(
				moveTo, gsiPlayer.lastSeen.location,
				underTower.lastSeen.location, underTower.attackRange + 140
			)
	end
	return moveTo
		-- TODO BUG SAFE, LOGICALLY RELEVANT MOVEMENT
end
LeechExp_GetStandingLoc = get_lexp_standing_loc

blueprint = {
	run = function(gsiPlayer, objective, xetaScore)
		--print("leech_experience:", gsiPlayer.shortName, "running leech")
		local danger, knownEngage, theorizedEngage = Analytics_GetTheoreticalDangerAmount(gsiPlayer)
		if #knownEngage > 0 or #theorizedEngage > 0 then
			Task_IncentiviseTask(gsiPlayer, avoid_hide_handle, 7.5*#knownEngage + 3.5*#theorizedEngage, 3)
			Task_IncentiviseTask(gsiPlayer, increase_safety_handle, 7.5*#knownEngage + 3.5*#theorizedEngage, 0.5)
		end
		local farmLaneObj = Task_GetTaskObjective(gsiPlayer, farm_lane_handle)
		if not farmLaneObj then
			return XETA_SCORE_DO_NOT_RUN
		end
		local creep, tta = FarmLane_AnyCreepLastHitTracked(gsiPlayer)
		local moveTo = get_lexp_standing_loc(gsiPlayer, creep or farmLaneObj, tta)
		if creep and danger < 1 and Vector_GsiDistance2D(gsiPlayer, creep) < CREEP_AGRO_RANGE
				and Vector_BRads2D(gsiPlayer.lastSeen.location, creep.lastSeen.location, moveTo)
					< math.pi/2
				and LanePressure_AgroCreepsNow(gsiPlayer) then
			INFO_print("[leech_experience] %s agros creeps into leech_exp down lane.", gsiPlayer.shortName)
			return xetaScore
		end
		Positioning_MoveDirectlyCheckPort(gsiPlayer, moveTo)
		
		return xetaScore
	end,
	
	score = function(gsiPlayer, prevObjective, prevScore)
		local farmLaneObjective = Task_GetTaskObjective(gsiPlayer, farm_lane_handle)
		if not farmLaneObjective then return false, XETA_SCORE_DO_NOT_RUN end
		local theorizedDangerScore, engageables, theorizedEngageables = Analytics_GetTheoreticalDangerAmount(gsiPlayer)
		local anyIntendHarmFactor = FightClimate_AnyIntentToHarm(gsiPlayer, engageables) and 0.75 or 0
		--local safetyRatio = 0.33 + math.max(1, distToTeamTower / distToEnemyTower)
		local farmLaneScoreFactor = Task_GetTaskScore(gsiPlayer, farm_lane_handle)
				* (farmLaneObjective.maxHealth
						and (farmLaneObjective.lastSeenHealth / farmLaneObjective.maxHealth)^2
						or 0.33
					)
		
		local creep, tta, score = FarmLane_AnyCreepLastHitTracked(gsiPlayer)
		local standingLoc = get_lexp_standing_loc(gsiPlayer, farmLaneObjective, tta)
		if standingLoc then
			
			local underTower = Set_GetTowerOverLocation(standingLoc)
			local score = (0.3+anyIntendHarmFactor)*(theorizedDangerScore*15) + max(0, farmLaneScoreFactor)
					-(creep and tta and 10 - 10*min(1, max(0, tta - (Vector_PointDistance(
									gsiPlayer.lastSeen.location,
									creep.lastSeen.location
								) / (gsiPlayer.currentMovementSpeed - 30)
							))) or 0)
			local towerScore = underTower and (1-gsiPlayer.hpp)
						* ((underTower.team == TEAM
							and 25 or -35) / (1+(0.15*gsiPlayer.level)))
					or 0
						 -- TODO pretty loose
			return farmLaneObjective, score + towerScore
		end
		return false, XETA_SCORE_DO_NOT_RUN
	end,
	
	init = function(gsiPlayer, objective, extrapolatedXeta)
		gsiPlayer.vibe.aggressivity = 0.15
		return extrapolatedXeta
	end
}

function LeechExperience_GetTaskHandle()
	return task_handle
end
