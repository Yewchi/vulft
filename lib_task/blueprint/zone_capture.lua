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

-- Aggressive positioning into enemy heroes defending an objective zone like a power rune, roshan or zoning out a tower deny if enemy defense is lacking, but they do not appear catchable (trigger baiting and killing instead if they look catchable)

-- Capture zone is often a module vacant of a valid area. Once given a zone, it will activate it's throttle
--- to consider scores for capturing any zone in it's  list ( and in that sense, as I'm realizing,
--- zones should probably be allowed to be alotted into sets, to net their value under some logarithm in
--- order to prevent sporadic This-Then-Thats )
--- Zones store each bot that has decided to assault an area, so that other bots may see the net-team
--- benefit of staying in the area to help--especially when they have a high greed rating.

---- fight_zone_capture constants
local FIGHT_ZONE_CAPTURE_UPDATE_PRIORITY_ACTIVE_THROTTLE = 0.73

local task_handle = Task_CreateNewTask()

local t_zone_list = {}

local update_priority_throttle = Time_CreateThrottle(8.39)

local function update_score_task_priority__job(workingSet)
	
end

function estimated_time_til_completed(gsiPlayer, objective)
	return 8 -- don't care
end

local function task_init_func(taskJobDomain)
	taskJobDomain:RegisterJob(
			function(workingSet)
				if workingSet.throttle:allowed() then
					
				end
			end,
			["throttle"] = update_priority_throttle,
			"JOB_TASK_SCORING_PRIORITY_FIGHT_ZONE_CAPTURE"
		)
	task_init_func = nil
	return task_handle, estimated_time_til_completed
end
Blueprint_RegisterTask(task_init_func)

local blueprint_fight_zone_capture = {
	run = function(gsiPlayer, objective, xetaScore)
	
	end,
	
	score = function(gsiPlayer, prevObjective, prevScore)
	
	end,
	
	init = function(gsiPlayer, objective, xetaScore)
		gsiPlayer.vibe.aggressivity = 0.65 -- Rough 'em up, but save key abilities if we see a kill
	end
}

function FightZone_RegisterNewCaptureZone(location, radius, rawXeta)
	
end
