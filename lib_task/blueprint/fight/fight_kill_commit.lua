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
