-- Declare a player nearby as worth guarding when you are not farming the lane you are in, or when the map is dark, it is not early game, and an ally has shown themself in lane.
-- Prioritizes staying close, and staying in FoW. Ideally loses some FoW priority and hugs closer/more behind/more up the lane to guarded if the map is totally dark, or enemies are not visible in the lane for a long period of time (~5 sec)
function Task_CreateUpdatePriorityGuardJob(taskJobDomain)
	task_handle = Task_CreateNewTask()

	Task_RegisterTask(task_handle, PLAYERS_ALL, blueprint.run, blueprint.score, blueprint.init)

	taskJobDomain:RegisterJob(
			function(workingSet)
				if workingSet.throttle:allowed() then
					Task_SetTaskPriority(task_handle, PLAYERS_ALL, TASK_PRIORITY_TOP)
				end
			end,
			{["throttle"] = Time_CreateThrottle(PRIORITY_UPDATE_GUARD_THROTTLE)},
			"JOB_TASK_SCORING_PRIORITY_GUARD"
		)
	Blueprint_RegisterTaskActivityType(task_handle, ACTIVITY_TYPE["CONTROLLED_AGGRESSION"]) -- Used because closeby enemy reveals while in this state often need be defended or bluffed immediately. Low mana will catch unneccessary use
	Task_CreateUpdatePriorityGuardJob = nil
end

blueprint = {
	run = function(gsiPlayer, objective, xetaScore)
		return 0
	end,
	
	score = function(gsiPlayer, prevObjective, prevScore)
		return false, 0
	end,
	
	init = function(gsiPlayer, objective, extrapolatedXeta)
		return extrapolatedXeta
	end
}
