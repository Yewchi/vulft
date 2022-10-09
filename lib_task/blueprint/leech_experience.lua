local LEECH_EXP_RANGE = 1000

local INCREASE_SAFETY_STAYING_IS_DYING_SCORE = 150

local LEECH_EXP_THROTTLE = 0.139

local blueprint

local task_handle = Task_CreateNewTask()

local t_leech_exp_scores = {}

local t_team_players = {}

local max = math.max
local Set_GetEnemyHeroesInPlayerRadiusAndOuterlocal = Set_GetEnemyHeroesInPlayerRadiusAndOuter
local FightHarass_GetHealthDiffOutnumbered = FightHarass_GetHealthDiffOutnumbered
local FightClimate_AnyIntentToHarm = FightClimate_AnyIntentToHarm
local UNIT_TYPE_IMAGINARY = UNIT_TYPE_IMAGINARY
local increase_safety_handle
local fight_harass_handle
local farm_lane_handle

local next_player = 1
local function estimated_time_til_completed(gsiPlayer, objective)
	return 0 -- doing nothing anyways, also, don't care
end
local function task_init_func(taskJobDomain)
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
	
	taskJobDomain:RegisterJob(
			function(workingSet)
				if workingSet.throttle:allowed() then
					local nearbyEnemies = Set_GetEnemyHeroesInPlayerRadius(t_team_players[next_player], 1400)
					if #nearbyEnemies > 0 then
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

blueprint = {
	run = function(gsiPlayer, objective, xetaScore)
		--print("leech_experience:", gsiPlayer.shortName, "running leech")
		local _, knownEngage, theorizedEngage = Analytics_GetTheoreticalDangerAmount(gsiPlayer)
		if #knownEngage > 0 or #theorizedEngage > 0 then
			Task_IncentiviseTask(gsiPlayer, avoid_hide_handle, 10*#knownEngage + 7*#theorizedEngage, 5)
			Task_IncentiviseTask(gsiPlayer, increase_safety_handle, 10*#knownEngage + 7*#theorizedEngage, 0.5)
		end
		local farmLaneObj = Task_GetTaskObjective(gsiPlayer, farm_lane_handle)
		local activeLane = Farm_GetMostSuitedLane(gsiPlayer, farmLaneObj and farmLaneObj.ofUnitSet)
		if not farmLaneObj then
			return false, XETA_SCORE_DO_NOT_RUN
		end
		local tmp = gsiPlayer.attackRange
		-- TODO BUG SAFE, LOGICALLY RELEVANT MOVEMENT
		gsiPlayer.attackRange = LEECH_EXP_RANGE -- Spoof our attack range
		local nearToLowFactor = farmLaneObj.maxHealth and farmLaneObj.lastSeenHealth/farmLaneObj.maxHealth or 0.33
		Positioning_ZSAttackRangeUnitHugAllied(
				gsiPlayer,
				farmLaneObj.center or farmLaneObj.lastSeen.location,
				SET_HERO_ENEMY, -- Needs check if heroes attacking
				70 / math.max(0.1, Unit_GetHealthPercent(gsiPlayer)^2),
				2.5*nearToLowFactor
			)
		--print("leech_experience:", gsiPlayer.shortName, "leech moving", xetaScore)
		gsiPlayer.attackRange = tmp
--			local nearestTower = Set_GetNearestTeamTowerToPlayer(gsiPlayer.team, gsiPlayer)
--			Positioning_MoveToLocationSafe(gsiPlayer, nearestTower and nearestTower.lastSeen.location)
		return xetaScore
	end,
	
	score = function(gsiPlayer, prevObjective, prevScore)
		local farmLaneObjective = Task_GetTaskObjective(gsiPlayer, farm_lane_handle)
		if not farmLaneObjective then return false, XETA_SCORE_DO_NOT_RUN end
		local theorizedDangerScore, engageables, theorizedEngageables = Analytics_GetTheoreticalDangerAmount(gsiPlayer)
		local anyIntendHarmFactor = FightClimate_AnyIntentToHarm(gsiPlayer, engageables) and 0.75 or 0
		local nearestEnemyTower, distToEnemyTower = Set_GetNearestTeamTowerToPlayer(ENEMY_TEAM, gsiPlayer)
		local nearestTeamTower, distToTeamTower = Set_GetNearestTeamTowerToPlayer(TEAM, gsiPlayer)
		--local safetyRatio = 0.33 + math.max(1, distToTeamTower / distToEnemyTower)
		local farmLaneScoreFactor = Task_GetTaskScore(gsiPlayer, farm_lane_handle)
				* (farmLaneObjective.maxHealth
						and (farmLaneObjective.lastSeenHealth / farmLaneObjective.maxHealth)^2
						or 0.33
					)
		--[[DEBUG]]if DEBUG and DEBUG_IsBotTheIntern() then print("leech exp returns", gsiPlayer.shortName, (0.3+anyIntendHarmFactor),(theorizedDangerScore*15), max(0, farmLaneScoreFactor)) end
		return farmLaneObjective,
				(0.3+anyIntendHarmFactor)*(theorizedDangerScore*15) + max(0, farmLaneScoreFactor)
	end,
	
	init = function(gsiPlayer, objective, extrapolatedXeta)
		gsiPlayer.vibe.aggressivity = 0.15
		return extrapolatedXeta
	end
}

function LeechExperience_GetTaskHandle()
	return task_handle
end
