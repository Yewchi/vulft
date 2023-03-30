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
