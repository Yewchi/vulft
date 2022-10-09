-- Back to fountain until reasonably replenished
local TEAM_NUMBER_OF_PLAYERS = TEAM_NUMBER_OF_PLAYERS
local Task_SetTaskPriority = Task_SetTaskPriority
local XETA_SCORE_DO_NOT_RUN = XETA_SCORE_DO_NOT_RUN
local XETA_CERSEI_MOONWALK = XETA_CERSEI_MOONWALK
local Math_GetFastThrottledBounded = Math_GetFastThrottledBounded

local VALUE_OF_ONE_STAT = (VALUE_OF_ONE_HEALTH + VALUE_OF_ONE_MANA)/1.5

local task_handle = Task_CreateNewTask()

local leech_exp_handle
local avoid_hide_handle
local consumable_handle

local blueprint

local max = math.max
local sqrt = math.sqrt

local INCREASE_SAFETY_PRIORITY_UPDATE_THROTTLE = 0.229 -- Rotates

local mobility_in_use = {}
local defensives_in_use = {}

local team_fountain

local next_player = 1
local function estimated_time_til_completed(gsiPlayer, objective)
	return 20 -- don't care
end
local function task_init_func(taskJobDomain)
	if VERBOSE then VEBUG_print(string.format("increase_safety: Initialized with handle #%d.", task_handle)) end

	Task_RegisterTask(task_handle, PLAYERS_ALL, blueprint.run, blueprint.score, blueprint.init)

	team_fountain = Map_GetTeamFountainLocation()

	leech_exp_handle = LeechExperience_GetTaskHandle()
	avoid_hide_handle = AvoidHide_GetTaskHandle()
	consumable_handle = Consumable_GetTaskHandle()

	taskJobDomain:RegisterJob(
			function(workingSet)
				if workingSet.throttle:allowed() then
					Task_SetTaskPriority(task_handle, next_player, TASK_PRIORITY_TOP)
					next_player = Task_RotatePlayerOnTeam(next_player)
				end
			end,
			{["throttle"] = Time_CreateThrottle(INCREASE_SAFETY_PRIORITY_UPDATE_THROTTLE)},
			"JOB_TASK_SCORING_PRIORITY_INCREASE_SAFETY"
		)
	Blueprint_RegisterTaskActivityType(task_handle, ACTIVITY_TYPE["FEAR"])
	task_init_func = nil
	return task_handle, estimated_time_til_completed
end
Blueprint_RegisterTask(task_init_func)

blueprint = {
	run = function(gsiPlayer, objective, xetaScore)
		-- if not defensives_in_use[gsiPlayer.nOnTeam] then
			-- local defensive = AbilityLogic_GetBestSurvivability(gsiPlayer)
			-- if defensive then
				-- print(gsiPlayer.shortName, "defensive found", defensive)
				-- defensives_in_use[gsiPlayer.nOnTeam] = defensive
				-- gsiPlayer.hUnit:Action_UseAbility(defensive)
			-- end
			gsiPlayer.hUnit:Action_MoveDirectly(Map_GetTeamFountainLocation())
			return xetaScore
		-- else
			-- --print(gsiPlayer.shortName, "ATTEMPTING DEFENSIVE", defensives_in_use[gsiPlayer.nOnTeam]:GetName() or Util_PrintableTable(defensives_in_use[gsiPlayer.nOnTeam]))
			-- gsiPlayer.hUnit:Action_UseAbility(defensives_in_use[gsiPlayer.nOnTeam])
		-- end
	end,
	
	score = function(gsiPlayer, prevObjective, prevScore)
		-- TODO Am I dangerously low health?; Am I currently relied upon?; Am I sparring with a similar health enemy?
		-- TODO Get health after tango ends
		local healthReplenish, healthTime = Item_RAUCMitigateDelivery(gsiPlayer)
		local healthPercent = (gsiPlayer.lastSeenHealth
						+ gsiPlayer.hUnit:GetHealthRegen()
						+ healthReplenish
				) / gsiPlayer.maxHealth
		if healthPercent < 0.92 --[[and not Item_ItemOwnedAnywhere(gsiPlayer, "item_flask")]] then
			local thisWalkBackScore = Xeta_EvaluateObjectiveCompletion(
					XETA_RETURN_FOUNTAIN,
					0,
					1.0,
					gsiPlayer,
					gsiPlayer
				)
			thisWalkBackScore = Math_GetFastThrottledBounded(thisWalkBackScore, 0, 350, 2000)
			if healthReplenish > 0 then
				local replenishPercent = healthReplenish/gsiPlayer.maxHealth
				thisWalkBackScore = thisWalkBackScore*(1 - replenishPercent)
				local incentiveCareful = replenishPercent*100*(1-healthPercent)
				--DEBUG]]print(gsiPlayer.shortName, "INCENTIVISE FROM INCREASE SAFETY sees better leech/avoid", incentiveCareful, "against increase safety", thisWalkBackScore, "which lost %", (1-replenishPercent)*100)
				Task_IncentiviseTask(gsiPlayer, leech_exp_handle, incentiveCareful, healthTime)
				Task_IncentiviseTask(gsiPlayer, avoid_hide_handle, incentiveCareful, healthTime)
				Task_IncentiviseTask(gsiPlayer, consumable_handle, incentiveCareful, healthTime)
			end
			--[DEBUG]]]if DEBUG and DEBUG_IsBotTheIntern() then print("----increase_safety: moonwalk", gsiPlayer.shortName, thisWalkBackScore, Math_GetFastThrottledBounded(thisWalkBackScore, 250, 350, 800)) end
			return gsiPlayer, thisWalkBackScore
		end
		local distanceToFountain = Math_PointToPointDistance2D(gsiPlayer.lastSeen.location, team_fountain)
		if distanceToFountain < 1400 or Task_GetCurrentTaskHandle(gsiPlayer) == task_handle and distanceToFountain < 4000 then
			local missingStats = max(1, gsiPlayer.maxMana+gsiPlayer.maxHealth-gsiPlayer.lastSeenMana-gsiPlayer.lastSeenHealth)
			local valueFuncResult = 4096/(1-2^(0.01*missingStats)) + missingStats*VALUE_OF_ONE_STAT + 128
			if missingStats > 350 then
				Item_UseBottleIntelligently(gsiPlayer, true)
			end
			--[DEBUG]]]DebugDrawText(1000, 550, string.format("%.2f %.2f %.2f", (1-2^(0.01*missingStats)), 4096/(1-2^(0.01*missingStats)),  0.3867*VALUE_OF_ONE_STAT), 255, 255, 255)
			--[DEBUG]]]DebugDrawText(1000, 500, string.format("%.2f %.2f %s", valueFuncResult, Math_GetFastThrottledBounded(valueFuncResult, 250, 350, 1500), gsiPlayer.shortName), 255, 255, 255)
			--[DEBUG]]]if DEBUG and DEBUG_IsBotTheIntern() then print("----increase_safety: fountain", gsiPlayer.shortName, valueFuncResult, Math_GetFastThrottledBounded(valueFuncResult, 250, 350, 800)) end
			return gsiPlayer, Math_GetFastThrottledBounded(valueFuncResult, 250, 350, 1500)
		end
	--	print("increase_safety:", gsiPlayer.shortName, XETA_SCORE_DO_NOT_RUN)
		return false, XETA_SCORE_DO_NOT_RUN
	end,
	
	init = function(gsiPlayer, objective, extrapolatedXeta)
		gsiPlayer.vibe.aggressivity = 0.0
		UseAbility_ClearQueuedAbilities(gsiPlayer)
		return extrapolatedXeta
	end
}

function IncreaseSafety_GetTaskHandle()
	return task_handle
end
