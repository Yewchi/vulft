-- Use slows, stuns and nukes with the outlook of disengaging afterwards, as when chasing two full-health heroes down, 
--- but not knowing if more enemy heroes are nearby and the enemy may make a turn. Different from chase because the 
--- fight may be challenged. A brutal heist on a knife's edge state, rather than a careful hunt, or farming lane kills.

local task_handle = Task_CreateNewTask()

function Task_CreateUpdatePriorityFightKillCommitJob(taskJobDomain)
	if VERBOSE then VEBUG_print(string.format("fight_kill_commit: Initialized with handle #%d.", task_handle)) end
	
	Blueprint_RegisterTaskActivityType(task_handle, ACTIVITY_TYPE["KILL"])
	Task_CreateUpdatePriorityFightKillCommitJob = nil
	return task_handle, function() return 0 end
end

function FightKillCommit_GetTaskHandle()
	return task_handle
end
