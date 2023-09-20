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

-- Tasks are abstractions of a set of actions. The current (and list of recently considered) tasks to enact and re-evaluate. 
-- Tasks associate Xeta-score-functions to the entities or abstract entities that define an objective.
-- Task blueprints determine how a task may be completed, and what to consider.
-- High-scoring recently evaluated tasks are stored with their score, and their objectives.

-- Searches are throttled, and spread over frames, the bot may change decision after approximately pro-player-APM time for new considerations

-- Terminology:
-- 'Confirmed Denial': An entry made for an objective that tells other players on the team, ' I won scoring, and I claim the confirmed denial, you may not make this a primary objective unless you beat my score or I remove it as a planned task '. 
-- 'Objective Disallow': If a confirmed denial is taken-over by another player, due to higher score or special circumstances, an objective disallow is triggered. Any players with that objective must remove it as a primary or planned objective. ' I've respawned, am teleporting, and I'll be back in time to last hit thisCreep. Remove your thisCreep objective, Lion '

TASK_PRIORITY_TOP = 1
TASK_PRIORITY_FORGOTTEN = 10
PLAYERS_ALL = 0xFFFE

-- 28/03/23 Not liking this for leech_exp / avoid_hide farming switch. 
FACTOR_OF_PREVIOUS_SCORE_TO_WIN_CURRENT_TASK = 1.2 -- Stubbornness here greatly reduces analytical 'true-value-of-because' code. ... 28/03/23 Maths is generally a slider score via min/max anyways.
local FACTOR_OF_PREVIOUS_SCORE_TO_WIN_CURRENT_TASK = FACTOR_OF_PREVIOUS_SCORE_TO_WIN_CURRENT_TASK

require(GetScriptDirectory().."/lib_gsi/gsi_gpm")
require(GetScriptDirectory().."/lib_task/types")
require(GetScriptDirectory().."/lib_task/i_objective")
require(GetScriptDirectory().."/lib_task/positioning")
require(GetScriptDirectory().."/lib_analytics/last_hit_projection")

---- task constants --
local MAX_TASKS_SCORED_PER_FRAME_PER_HERO = 4 -- (task scoring funcs lose priority-- after being scored once)
--i.e.MAXIMUM_TASK_PRIORITY = 1
local MINIMUM_TASK_PRIORITY = TASK_PRIORITY_FORGOTTEN -- .'. Would only occur after each task was scored over 10 frames, with no re-ups (a potential to occur for low activity downtime and very fast FPS)

local DECREMENT_FAILURE_COUNT_THROTTLE = 4.01
local FAILURE_DETRUST_LIMIT = 4

local TEAM_NUMBER_OF_PLAYERS = TEAM_NUMBER_OF_PLAYERS
local XETA_SCORE_DO_NOT_RUN = XETA_SCORE_DO_NOT_RUN
local min = math.min
local max = math.max
local next = next
local VERBOSE = VERBOSE or DEBUG_TARGET and string.find(DEBUG_TARGET, "Dtask")
local DEBUG = VERBOSE or DEBUG
local TEST = TEST or DEBUG_TARGET and string.find(DEBUG_TARGET, "Ttask")
--

---- task table indices --
local OBJECTIVE_DISALLOW_I__OBJECTIVE = 1
local OBJECTIVE_DISALLOW_I__CANCEL_FUNCTION_TYPE = 2

local TASK_I__OBJECTIVE = 1
local TASK_I__SCORE = 2
local TASK_I__INIT_FUNC = 3
local TASK_I__RUN_FUNC = 4
local TASK_I__SCORING_FUNC = 5
local TASK_I__HANDLE = 6
local TASK_I__CURR_PRIORITY = 7
local TASK_I__NEXT_NODE = 8
local TASK_I__PREV_NODE = 9

local LIST_I__FIRST_NODE = 1
local LIST_I__LAST_NODE = 2
local LIST_I__PRIORITY_LIST_INDEX = 3 -- storing it's own index, this is for parameter simplicity in ammend_node
--

local t_player_task_current
local t_player_task_runner_up
local t_player_disallowed_objective_targets -- Check my own index regularly and remove any tasks with that objective ("Anti-Mage: Lion, I changed my farm pathing and you're farming a jungle set I want this jungle cycle, find a new task!") (Lion: Anti-Mage may be here soon, put a mutliplier on setting up a gank, and forward warding the nearest jungle area)

local t_player_tasks_failing_inits

local t_check_revert_from_short

local t_tasks
local t_priority_list

local t_task_incentives
local t_task_incentives_size

local t_task_start_time

local t_custom_activity_type -- from blueprint_main init

local job_domain = Job_CreateDomain("DOMAIN_TASK")

do
	t_player_disallowed_objective_targets = {}
	t_player_confirmed_denial_plan = {}
	t_tasks = {}
	t_priority_list = {}
	t_task_incentives = {}
	t_task_incentives_size = {}
	t_task_start_time = {}
	t_task_incentive_handle_index = {}
	t_player_task_current = {}
	t_player_task_runner_up = {}
	t_player_tasks_failing_inits = {}
	t_check_revert_from_short = {}
	for i=1,TEAM_NUMBER_OF_PLAYERS,1 do
		t_player_disallowed_objective_targets[i] = {}
		t_tasks[i] = {}
		t_priority_list[i] = {}
		t_task_incentives[i] = {}
		t_task_incentives_size[i] = 0
		t_task_start_time[i] = 0
		t_task_incentive_handle_index[i] = {}
		t_player_task_current[i] = {} -- init handling
		t_player_tasks_failing_inits[i] = {}
		for p=1,MINIMUM_TASK_PRIORITY,1 do
			t_priority_list[i][p] = {false, false, p}
		end
	end
	
	job_domain:RegisterJob(
			function(workingSet)
				if workingSet.throttle:allowed() then
					for n=1,TEAM_NUMBER_OF_PLAYERS,1 do
						for k,_ in next,t_player_tasks_failing_inits[n] do
							t_player_tasks_failing_inits[n][k] = t_player_tasks_failing_inits[n][k] - 1
							if t_player_tasks_failing_inits[n][k] == 0 then 
								t_player_tasks_failing_inits[n][k] = nil
							end
						end
					end
				end
			end,
			{["throttle"] = Time_CreateThrottle(DECREMENT_FAILURE_COUNT_THROTTLE)},
			"JOB_DECREMENT_TASK_FAILURE_COUNT"
		)
end

local DEBUG_timeScoringTask
local DEBUG_taskScoredCount
if TEST then
	DEBUG_timeScoringTask = {}
	DEBUG_taskScoredCount = {}
end

-------------- take_and_stitch_nodes()
local function take_and_stitch_nodes(priorityList, taskTaken)
	local prevNode = taskTaken[TASK_I__PREV_NODE]
	local nextNode = taskTaken[TASK_I__NEXT_NODE]
	if prevNode then
		prevNode[TASK_I__NEXT_NODE] = nextNode
		taskTaken[TASK_I__PREV_NODE] = false
	else
		priorityList[LIST_I__FIRST_NODE] = nextNode
	end
	if nextNode then
		nextNode[TASK_I__PREV_NODE] = prevNode
		taskTaken[TASK_I__NEXT_NODE] = false
	else
		priorityList[LIST_I__LAST_NODE] = prevNode
	end
end

-------------- ammend_node()
local function ammend_node(priorityList, taskAmmended)
	local lastNode = priorityList[LIST_I__LAST_NODE]
	if lastNode then
		lastNode[TASK_I__NEXT_NODE] = taskAmmended
		taskAmmended[TASK_I__PREV_NODE] = lastNode
		taskAmmended[TASK_I__NEXT_NODE] = false
	else
		priorityList[LIST_I__FIRST_NODE] = taskAmmended
		taskAmmended[TASK_I__NEXT_NODE] = false
		taskAmmended[TASK_I__PREV_NODE] = false
	end
	priorityList[LIST_I__LAST_NODE] = taskAmmended
	taskAmmended[TASK_I__CURR_PRIORITY] = priorityList[LIST_I__PRIORITY_LIST_INDEX]
end

-------------- end_current_task()
local function end_current_task(gsiPlayer)
	if t_check_revert_from_short[gsiPlayer.nOnTeam] then
		Task_SetTaskPriority(t_check_revert_from_short[gsiPlayer.nOnTeam], gsiPlayer.nOnTeam, TASK_PRIORITY_TOP)
		t_check_revert_from_short[gsiPlayer.nOnTeam] = false
	end
end

-------------- handle_failed_initialize()
local function handle_failed_initialize(gsiPlayer, initFailingTask) -- High failure disallows re-prio
	local failingTaskDetrust = t_player_tasks_failing_inits[gsiPlayer.nOnTeam][initFailingTask]
	-- print(gsiPlayer.shortName, "handling failed init", initFailingTask)
	if not failingTaskDetrust then
		t_player_tasks_failing_inits[gsiPlayer.nOnTeam][initFailingTask] = FAILURE_DETRUST_LIMIT
	else
		t_player_tasks_failing_inits[gsiPlayer.nOnTeam][initFailingTask] = failingTaskDetrust + (FAILURE_DETRUST_LIMIT*(failingTaskDetrust%FAILURE_DETRUST_LIMIT)) + FAILURE_DETRUST_LIMIT -- FAILURE_DETRUST_LIMIT==4. Fail once, you may re-prio in ~4.01s. Fail again before full trust, wait ~ 32 - 64s for reprio allowed. 
	end
end

-------------- remove_tasks_with_disallowed_objectives()
local function remove_tasks_with_disallowed_objectives(gsiPlayer, disallowedObjective)
	local tasksTbl = t_tasks[gsiPlayer.nOnTeam]
	if not tasks then return; end
	for key,task in next,tasksTbl do
		if task[TASK_I__OBJECTIVE] == disallowedObjective then
			t_tasks[gsiPlayer.nOnTeam][key][TASK_I__OBJECTIVE] = false
			t_tasks[gsiPlayer.nOnTeam][key][TASK_I__SCORE] = XETA_SCORE_DO_NOT_RUN -- Rescore please.
		end
	end
end

local score_task_prev_time = 0
-------------- score_task()
local function score_task(gsiPlayer, task)
	local prevObjective = task[TASK_I__OBJECTIVE]
	local prevToCurrScore = task[TASK_I__SCORE]
	local taskHandle = task[TASK_I__HANDLE]
	
	if TEST then
		TEBUG_print("[task] scoring %s::#%d tbls: %f", gsiPlayer.shortName, taskHandle, VERBOSE and collectgarbage("count") or -0)
		DEBUG_timeScoringTask[taskHandle] = DEBUG_timeScoringTask[taskHandle] or 0;
		DEBUG_taskScoredCount[taskHandle] = DEBUG_taskScoredCount[taskHandle] and DEBUG_taskScoredCount[taskHandle] + 1 or 1;
		score_task_prev_time = RealTime()
	end
	task[TASK_I__OBJECTIVE], prevToCurrScore = task[TASK_I__SCORING_FUNC](gsiPlayer, prevObjective, prevToCurrScore)
	if TEST then
		if VERBOSE then TEBUG_print("[task] tbls: %f", collectgarbage("count")) end
		DEBUG_timeScoringTask[taskHandle] = DEBUG_timeScoringTask[taskHandle] + RealTime() - score_task_prev_time or 0;
		if DEBUG_taskScoredCount[taskHandle] > 500 then
			TEBUG_print("[task::score_task] <BENCH> Task handle %d scoring 500 times took %.4fms", taskHandle, DEBUG_timeScoringTask[taskHandle]*1000)
			DEBUG_timeScoringTask[taskHandle] = 0
			DEBUG_taskScoredCount[taskHandle] = 0
		end
	end
	if not prevToCurrScore then DEBUG_print("\n\n           CULPRIT WAS: %d", task[TASK_I__HANDLE]) end
	task[TASK_I__SCORE] = prevToCurrScore + t_task_incentives[gsiPlayer.nOnTeam][task[TASK_I__HANDLE]][1] -- TODO Need to change prevScore return behavior for this
	return task[TASK_I__OBJECTIVE] ~= prevObjective
end

-------------- decrement_task_priority()
local function decrement_task_priority(gsiPlayer, task)
	local nOnTeam = gsiPlayer.nOnTeam
	if task then
		take_and_stitch_nodes(t_priority_list[nOnTeam][task[TASK_I__CURR_PRIORITY]], task)
		ammend_node(t_priority_list[nOnTeam][ min(MINIMUM_TASK_PRIORITY, task[TASK_I__CURR_PRIORITY] + 1) ], task) -- (perfoming a priority-index-increment is a "decrement of priority"). This instruction also rotates a task at minimum priority to the back of the list, to keep things rotating
	end
end

-------- Task_RegisterTask()
function Task_RegisterTask(taskHandle, nOnTeam, runFunc, scoringFunc, initFunc)
	if nOnTeam == PLAYERS_ALL then
		for n=1,TEAM_NUMBER_OF_PLAYERS,1 do
			Task_RegisterTask(taskHandle, n, runFunc, scoringFunc, initFunc)
		end
		return
	end
	if not t_tasks[nOnTeam][taskHandle] then
		t_tasks[nOnTeam][taskHandle] = {}
		t_tasks[nOnTeam][taskHandle][TASK_I__HANDLE] = taskHandle
	end
	local thisTask = t_tasks[nOnTeam][taskHandle]
	thisTask[TASK_I__RUN_FUNC] = runFunc
	thisTask[TASK_I__SCORING_FUNC] = scoringFunc
	thisTask[TASK_I__INIT_FUNC] = initFunc
	
	ammend_node(t_priority_list[nOnTeam][MINIMUM_TASK_PRIORITY], thisTask)
	
	local currNode = t_priority_list[nOnTeam][MINIMUM_TASK_PRIORITY][LIST_I__FIRST_NODE]
	local i = 0
	local iPrio = currNode[TASK_I__CURR_PRIORITY]
	while(currNode) do
		if i > 100 then ERROR_print(false, not DEBUG, "Reg WTF %s %s", i, iPrio) break end
		i = i + 1
		currNode = currNode[TASK_I__NEXT_NODE]
	end
end

-------- Task_SetTaskPriority()
function Task_SetTaskPriority(taskHandle, nOnTeam, priority)
	if nOnTeam == PLAYERS_ALL then
		for n=1,TEAM_NUMBER_OF_PLAYERS,1 do
			Task_SetTaskPriority(taskHandle, n, priority)
		end
		return
	end
	local thisTask = t_tasks[nOnTeam][taskHandle]
	if thisTask[TASK_I__CURR_PRIORITY] == priority then 
		return -- reprioritizing now would open very fast, top-set tasks to repeatedly top-sitting if there is too much competition. (processed nodes would be the slower nodes, and/or nodes that got in first on the frame)
	end 
	
	-- Confirm task is not repeatedly failing initialization
	if t_player_tasks_failing_inits[thisTask] and t_player_tasks_failing_inits[thisTask] >= FAILURE_DETRUST_LIMIT then
		local estWaitTime = (t_player_tasks_failing_inits[thisTask] - FAILURE_DETRUST_LIMIT - 1) * DECREMENT_FAILURE_COUNT_THROTTLE
		return estWaitTime
	end
	
	-- Stitch priority nodes leaving
	take_and_stitch_nodes(t_priority_list[nOnTeam][thisTask[TASK_I__CURR_PRIORITY]], thisTask)
	
	-- Sew onto setting priority
	ammend_node(t_priority_list[nOnTeam][priority], thisTask)

			local currNode = t_priority_list[nOnTeam][priority][LIST_I__FIRST_NODE]
			local i = 0
			local iPrio = currNode[TASK_I__CURR_PRIORITY]
			while(currNode) do
				if i > 100 then ERROR_print(false, not DEBUG, "Set WTF %s %s", i, iPrio) break end
				i = i + 1
				currNode = currNode[TASK_I__NEXT_NODE]
			end
end

-------- Task_Initialize()
function Task_Initialize()
	t_custom_activity_type = Blueprint_InitializeAllBlueprintPriorityJobs(job_domain)
	WP_Initialize()
	Task_Initialize = nil
end

--[[BENCH]]local scorePrev = 0
--[[BENCH]]local scoreElapsed = 0
--[[BENCH]]local scoreNextReport = RealTime() + 10
-------- Task_HighestPriorityTaskScoringContinue()
function Task_HighestPriorityTaskScoringContinue(gsiPlayer)
	local nOnTeam = gsiPlayer.nOnTeam
	local highestTaskScore = XETA_SCORE_DO_NOT_RUN
	local taskScoringHighest
	local taskScoringHighestHasObjectiveChange = false
	local playerPriorityLists = t_priority_list[nOnTeam]
	local tasksThisFrame = 0
	local iPriority = 1
	local prevCurrent = t_player_task_current[nOnTeam]
	local prevRunnerUp = t_player_task_runner_up[nOnTeam]
	local reinitializePrevCurrent = false
	
	--[[BENCH]]local scorePrev = RealTime()
	while(iPriority <= MINIMUM_TASK_PRIORITY) do
		local currNode = playerPriorityLists[iPriority][LIST_I__FIRST_NODE]
		while(currNode) do
			local objectiveChanged = score_task(gsiPlayer, currNode)
			--[[DEBUG]]if DEBUG and DEBUG_IsBotTheIntern() then DebugDrawText(1550, 230+20*currNode[TASK_I__HANDLE]+(TEAM_IS_RADIANT and -10 or 0), string.format("tctask h#%d: %s", currNode[TASK_I__HANDLE], currNode[TASK_I__SCORE] ~= XETA_SCORE_DO_NOT_RUN and (tostring(currNode[TASK_I__SCORE]) or "-404") or "DNR"), TEAM==TEAM_DIRE and 255 or 0, TEAM==TEAM_DIRE and 0 or 255, 255) end
			if currNode ~= prevCurrent then
				if (currNode[TASK_I__SCORE] or XETA_SCORE_DO_NOT_RUN) > highestTaskScore then
					highestTaskScore = currNode[TASK_I__SCORE]
					taskScoringHighest = currNode
					taskScoringHighestHasObjectiveChange = objectiveChanged
				end
			else
				reinitializePrevCurrent = objectiveChanged
			end
			tasksThisFrame = tasksThisFrame + 1
			if tasksThisFrame >= MAX_TASKS_SCORED_PER_FRAME_PER_HERO then
				iPriority = iPriority + 65536
				break
			end
			currNode = currNode[TASK_I__NEXT_NODE]
		end
		iPriority = iPriority + 1
	end
	local tasksThisFrame = 0
	local iPriority = 1
	local directionMoving = 1
	local currNode
	-- Decrement tasks checked, TODO Why not array of 4 decrementing tasks? Requires a lot of perspective to rethink totally
	while(iPriority <= MINIMUM_TASK_PRIORITY) do
		if directionMoving == 1 then -- Traverse down till we see 4 to decrement
			currNode = playerPriorityLists[iPriority][LIST_I__FIRST_NODE]
			while(currNode) do
				tasksThisFrame = tasksThisFrame + 1
				if tasksThisFrame >= MAX_TASKS_SCORED_PER_FRAME_PER_HERO then
					directionMoving = -1
					break
				end
				currNode = currNode[TASK_I__NEXT_NODE]
			end
		else -- Code block structure "if moving==1 then ... else ... end if moving==-1 ... end" is due to the shift from going forwards to backwards, sometimes half-way through a priority list.
			currNode = playerPriorityLists[iPriority][LIST_I__LAST_NODE]
		end
		if directionMoving == -1 then
			while(currNode) do
				local prevNode = currNode[TASK_I__PREV_NODE]
				decrement_task_priority(gsiPlayer, currNode) -- DESTRUCTIVE, needs prevNode = currNode -- Also the reason we need this weird forward-back... Alternate solution was array of previously decremented-this-frame taskHandles (but we also may leap frog 3 of them later)
				currNode = prevNode
			end
			if iPriority <= 1 then break end
		end
		iPriority = iPriority + directionMoving
	end
	--[[BENCH]]scoreElapsed = scoreElapsed + RealTime() - scorePrev
	--[[BENCH]]if TEST and RealTime() > scoreNextReport then TEBUG_print(string.format("Task_HighestPriorityTaskScoringContinue elapsed %.3f over 10s.", scoreElapsed)) scoreElapsed = 0 scoreNextReport = RealTime() + 10 end

	-- TODO TODO TODO NEEDS REFACTOR FOR NIL CHECK BLOCKS. TODO work out what this TODO means.
	if not taskScoringHighest then 
		return
	end
	-- Handle task switching and update task information
	local prevCurrentScore = prevCurrent[TASK_I__SCORE]
	local prevCurrentBeatScore = prevCurrentScore
			and (prevCurrentScore > 0 and prevCurrentScore * FACTOR_OF_PREVIOUS_SCORE_TO_WIN_CURRENT_TASK + 2.5
					or 2*prevCurrentScore - prevCurrentScore * FACTOR_OF_PREVIOUS_SCORE_TO_WIN_CURRENT_TASK + 2.5 -- score + (abs(score)*factor - abs(score)) + 2.5
			) or XETA_SCORE_DO_NOT_RUN
	if prevCurrent == taskScoringHighest and taskScoringHighestHasObjectiveChange
			or ( highestTaskScore > prevCurrentBeatScore
				and prevCurrent ~= taskScoringHighest
			) then -- we have changed objective for current task, or a new highest scoring task is present while the new highest scoring task is over some arbitrary stubbornness factorization of the current task score
	--	if prevCurrent and prevCurrent[TASK_I__SCORE] == XETA_SCORE_DO_NOT_RUN then -- the task received a cancelation... check if runner up should be the new current
	--		if prevRunnerUp and prevRunnerUp[TASK_I__SCORE] > highestTaskScore then
	--			-- not VERBOSE because it's suited for extensive, long-term testing, not focused testing (would take days)
	--			--[DEBUG]]if DEBUG then print(string.format("/VUL-FT/ <DEBUG> task: Reverting DO_NOT_SCORE returned for current task #%d to %d with %.2f for %s", prevCurrent[TASK_I__HANDLE], prevRunnerUp[TASK_I__HANDLE], prevRunnerUp[TASK_I__SCORE], gsiPlayer.shortName)) end
	--			t_player_task_runner_up[nOnTeam] = prevCurrent -- Will be innaccurate upon a previously engaged task returning DO_NOT_RUN, alternative is iterated check for 2nd best. Rather the innacuracy. Human beings are stubborn anyways. Requires two highest scoring tasks to cancel within bluprint.run() to DO_NOT_RUN in a row to cause effect.
	--			highestTaskScore = prevRunnerUp[TASK_I__SCORE]
	--			taskScoringHighest = prevRunnerUp
	--			goto END
	--		end
	--	end
		-- print(gsiPlayer.shortName, "initializing on", taskScoringHighest[TASK_I__OBJECTIVE])
		local initializationSuccessOrScore = taskScoringHighest[TASK_I__INIT_FUNC](gsiPlayer, taskScoringHighest[TASK_I__OBJECTIVE], taskScoringHighest[TASK_I__SCORE])
		if initializationSuccessOrScore == false then -- Task init failed
			
			handle_failed_initialize(gsiPlayer, taskScoringHighest)
		else -- Task init success
			if DEBUG and DEBUG_IsBotTheIntern() then print(gsiPlayer.shortName, "score switch", taskScoringHighest[TASK_I__SCORE], taskScoringHighest[TASK_I__HANDLE], ">", prevCurrentScore, prevCurrent[TASK_I__HANDLE]) end
			end_current_task(gsiPlayer)
			t_player_task_current[nOnTeam] = taskScoringHighest
			t_task_start_time[nOnTeam] = GameTime()
			taskScoringHighest[TASK_I__SCORE] = initializationSuccessOrScore
			if prevCurrent and prevRunnerUp then
				local prevCurrentScore = prevCurrentScore
				local prevRunnerUpScore = prevRunnerUp[TASK_I__SCORE]
				if prevCurrentScore and prevRunnerUpScore and prevCurrentScore > prevRunnerUpScore then
					
					t_player_task_runner_up[nOnTeam] = prevCurrent
				end
			end
		end
	elseif reinitializePrevCurrent then
		prevCurrent[TASK_I__INIT_FUNC](gsiPlayer, prevCurrent[TASK_I__OBJECTIVE], prevCurrentScore)
	end
	--print("Task scoring checking", gsiPlayer.shortName, t_player_task_current[nOnTeam], taskScoringHighest, prevRunnerUp == nil, highestTaskScore, prevRunnerUp and prevRunnerUp[TASK_I__SCORE] or "no runner up")
	if t_player_task_current[nOnTeam] ~= taskScoringHighest and (prevRunnerUp == nil or highestTaskScore > prevRunnerUp[TASK_I__SCORE]) then -- TODO Could correct and reliable scores be smothered by high, highly variant score tasks.
		if VERBOSE then VEBUG_print(gsiPlayer.shortName, "set runner up to task id:", taskScoringHighest[TASK_I__SCORE]) end
		t_player_task_runner_up[nOnTeam] = taskScoringHighest
	end
	
	::END::
	if prevCurrent ~= t_player_task_current[nOnTeam] then
		t_custom_activity_type[nOnTeam] = nil
	end
	if DEBUG and DEBUG_IsBotTheIntern() then 
		local task1, task2
		local handle1, handle2
		for i=1,10,1 do
			if t_player_task_current[nOnTeam] == t_tasks[nOnTeam][i] then
				task1 = t_tasks[nOnTeam][i]
				handle1 = i
			end
			if t_player_task_runner_up[nOnTeam] == t_tasks[nOnTeam][i] then
				task2 = t_tasks[nOnTeam][i]
				handle2 = i
			end
		end
		-- DebugDrawText(305, 940, string.format("taskwin--handle:%d; score:%.1f", handle1 or -1, task1 and task1[TASK_I__SCORE] or -1.0), 255, 255, 255)
		-- DebugDrawText(305, 955, string.format("taskwin--handle:%d; score:%.1f", handle2 or -1, task2 and task2[TASK_I__SCORE] or -1.0), 255, 255, 255)
	end
end

--[[BENCH]]local runTaskBench = Time_CreateBench(10.0)
-------- Task_CurrentTaskContinue()
function Task_CurrentTaskContinue(gsiPlayer)
	local pnot = gsiPlayer.nOnTeam
	local thisPlayersCurrentTask = t_player_task_current[pnot]
	--[TEST]]if DEBUG and DEBUG_IsBotTheIntern() then print(thisPlayersCurrentTask[TASK_I__SCORE], "run task", thisPlayersCurrentTask[TASK_I__HANDLE], thisPlayersCurrentTask[TASK_I__OBJECTIVE] and thisPlayersCurrentTask[TASK_I__OBJECTIVE].shortName) end
	if thisPlayersCurrentTask and thisPlayersCurrentTask[TASK_I__OBJECTIVE] then
		if VERBOSE then
			local runnerUp = t_player_task_runner_up[pnot]
			DebugDrawText(TEAM_IS_RADIANT and 640 or 1150, 830+pnot*15,
					string.format("%d-%.4s-I:%2d|%8.2f|%-18.18s II:%2d|%8.2f|%-18.18s", 
							Blueprint_GetCurrentTaskActivityType(gsiPlayer),
							gsiPlayer.shortName, thisPlayersCurrentTask[TASK_I__HANDLE],
							thisPlayersCurrentTask[TASK_I__SCORE],
							thisPlayersCurrentTask[TASK_I__OBJECTIVE] and string.sub((thisPlayersCurrentTask[TASK_I__OBJECTIVE].shortName
									or thisPlayersCurrentTask[TASK_I__OBJECTIVE].name or "no-name"), -18)
									or Util_Printable(thisPlayersCurrentTask[TASK_I__OBJECTIVE]),
							runnerUp and runnerUp[TASK_I__HANDLE] or -0, runnerUp and runnerUp[TASK_I__SCORE] or -0,
							runnerUp and (runnerUp[TASK_I__OBJECTIVE] and string.sub((runnerUp[TASK_I__OBJECTIVE].shortName
											or runnerUp[TASK_I__OBJECTIVE].name or "no-name"), -18)
											or Util_Printable(runnerUp[TASK_I__OBJECTIVE])
									) or "nil"
						),
					TEAM_IS_RADIANT and 170 or 250, TEAM_IS_RADIANT and 250 or 170 , 255)
			--[[CRAZY_VERBOSE]]INFO_print(string.format("[Task_CurrentTaskContinue(%s)]: task: %d, objective: %s, score: %.4f",
							gsiPlayer.shortName,
							thisPlayersCurrentTask[TASK_I__HANDLE],
							tostring(thisPlayersCurrentTask[TASK_I__OBJECTIVE]),
							thisPlayersCurrentTask[TASK_I__SCORE]
						)
				)
		end
		--[[BENCH]]if TEST then runTaskBench:BenchStart() end
		-- Run task
		thisPlayersCurrentTask[TASK_I__SCORE] = 
			thisPlayersCurrentTask[TASK_I__RUN_FUNC](
					gsiPlayer, 
					thisPlayersCurrentTask[TASK_I__OBJECTIVE], 
					thisPlayersCurrentTask[TASK_I__SCORE]
			) or thisPlayersCurrentTask[TASK_I__SCORE]
		--[[BENCH]]if TEST then runTaskBench:BenchEnd(true, "Task_CurrentTaskContinue total.") end
		if thisPlayersCurrentTask[TASK_I__SCORE] == XETA_SCORE_DO_NOT_RUN then
			thisPlayersCurrentTask[TASK_I__OBJECTIVE] = false
			end_current_task(gsiPlayer)
		end
	elseif DEBUG then
		local t = thisPlayersCurrenTask
		local t2 = t_player_task_runner_up[pnot]
		DebugDrawText(TEAM_IS_RADIANT and 640 or 1150, 830+pnot*15,
				string.format("%d-%s-I:ALL TASKS OFF|%s|%s|%s II:%s|%s|%s", 
						Blueprint_GetCurrentTaskActivityType(gsiPlayer),
						string.sub(gsiPlayer.shortName, 1, 4),
						Util_Printable(t and t[TASK_I__HANDLE]), Util_Printable(t and t[TASK_I__OBJECTIVE]), Util_Printable(t and t[TASK_I__SCORE]),
						Util_Printable(t2 and t2[TASK_I__HANDLE]), Util_Printable(t2 and t2[TASK_I__OBJECTIVE]), Util_Printable(t2 and t2[TASK_I__SCORE])
					),
				TEAM_IS_RADIANT and 170 or 250, TEAM_IS_RADIANT and 250 or 170 , 255)
	end
	if VERBOSE and DEBUG_IsBotTheIntern() then
		for i=1,MINIMUM_TASK_PRIORITY do
			local currNode = t_priority_list[gsiPlayer.nOnTeam][i][LIST_I__FIRST_NODE]
			DebugDrawText(1400, 900+i*13, tostring(i), 255, 255, 255)
			local j=1
			while(currNode) do
				DebugDrawText(1400+j*24, 900+i*13, string.format("[%d] ", currNode[TASK_I__HANDLE]), 255, 255, 255)
				currNode = currNode[TASK_I__NEXT_NODE]
				if j > 100 then ERROR_print(false, not DEBUG, "END SCORE WTF %s %s", i, j) break end
				j=j+1
			end
		end
	end
end

-------- Task_RunSecondaryTaskWithLimitations()
function Task_RunSecondaryTaskWithLimitations()
	-- This function might be impossible to write without changing every task to check limitations before using any ActionImmediate_X()
	-- Also, TODO limitation.lua. -- The idea is that this returns false if we break a limitation, the calling function then needs to
	-- 		decide what to do instead because it set the limitations itself. ('I'm waiting, standing at ward with backpack cooldown', use taunt)
end

-------- Task_InformObjectiveDisallow()
function Task_InformObjectiveDisallow(gsiPlayer, objectiveDisallow) -- Anti-Mage: "The jungle set you're headed to is in my new farming path"; or support: "I just scored highly to use refresher orb, let me stun Enigma black hole it's scored higher for me in a time-urgent task"; or Captain: "You won't finish that roshan before the enemy's push with power to take a melee rax."
	table.insert(t_player_disallowed_objective_targets[gsiPlayer.nOnTeam], objectiveDisallow)
	-- print(gsiPlayer.shortName, 
			-- "must process objectiveDisallow for", 
			-- objectiveDisallow[1].name, 
			-- "raised by\\n..")
end

-------- Task_InformAliveAndRemoveObjectiveDisallows()
function Task_InformAliveAndRemoveObjectiveDisallows(gsiPlayer) -- Did anyone tell me my objective is no longer allowed?
	if not gsiPlayer.isAlive then
		gsiPlayer.isAlive = true
	end
	local myObjectiveDisallows = t_player_disallowed_objective_targets[gsiPlayer.nOnTeam]
	if myObjectiveDisallows ~= nil then
		for key,objectiveDisallow in next,myObjectiveDisallows do
			remove_tasks_with_disallowed_objectives(gsiPlayer, objectiveDisallow[OBJECTIVE_DISALLOW_I__OBJECTIVE])
			-- Run the cancel function for each denial type and objective being disallowed:
			TASK_DISALLOW_OBJECTIVE_FUNCS[objectiveDisallow[OBJECTIVE_DISALLOW_I__CANCEL_FUNCTION_TYPE]](gsiPlayer, objectiveDisallow[OBJECTIVE_DISALLOW_I__OBJECTIVE])
			myObjectiveDisallows[key] = nil
		end
	end
end

-------- Task_InformDeadAndCancelAnyConfirmedDenial()
function Task_InformDeadAndCancelAnyConfirmedDenial(gsiPlayer)
	t_player_task_current[gsiPlayer.nOnTeam][TASK_I__SCORE] = XETA_SCORE_DO_NOT_RUN
	t_task_start_time[gsiPlayer.nOnTeam] = 0
	if gsiPlayer.isAlive then
		gsiPlayer.isAlive = false
		gsiPlayer.lastSeen:Update(Map_GetTeamFountainLocation(TEAM))
		UseAbility_ClearQueuedAbilities(gsiPlayer)
		TaskType_CancelAnyConfirmedDenialsSelf(gsiPlayer)
		WP_InformDead(gsiPlayer)
	end
end

-------------- index_incentivized_task()
local function index_incentivized_task(pnot, taskHandle)
	t_task_incentives_size[pnot] = t_task_incentives_size[pnot] + 1
	t_task_incentive_handle_index[pnot][t_task_incentives_size[pnot]] = t_task_incentives[pnot][taskHandle]
end
-------------- collapse_incentivized_list()
local function collapse_incentivized_list(incentiveList, indexToRemove, pnot)
	local temp = table.remove(incentiveList, indexToRemove)
	temp[1] = 0
	temp[2] = 0
	t_task_incentives_size[pnot] = t_task_incentives_size[pnot] - 1
end
local decrement_incentive_throttle = Time_CreateOneFrameGoThrottle(1.0)
-------- Task_TryDecrementIncentives()
function Task_TryDecrementIncentives()
	if decrement_incentive_throttle:allowed() then
		for pnot=1, TEAM_NUMBER_OF_PLAYERS do
			thisPlayerIncentives = t_task_incentive_handle_index[pnot]
			currIndex = 1
			local i=1
			while(currIndex <= t_task_incentives_size[pnot]) do
				i = i+1 if i > 100 then for i=1, 10 do ERROR_print(false, not DEBUG, "DECREMENT WTF") end local a = nil + 1 end
				local thisIncentive = thisPlayerIncentives[currIndex]
				if VERBOSE then VEBUG_print(string.format("[task] pnot#%d decrement disincentivise: %.2f, %.2f", pnot, thisIncentive[1], thisIncentive[2])) end
				thisIncentive[1] = max(0, thisIncentive[1] - thisIncentive[2])
				if thisIncentive[1] == 0 then
					collapse_incentivized_list(thisPlayerIncentives, currIndex, pnot)
				else
					currIndex = currIndex + 1
				end
			end
		end
	end
end

-------- Task_RemoveJobsWithImpermanentObjectives()
function Task_RemoveJobsWithImpermanentObjectives(gsiPlayer) -- Anti-Mage: (I still want that 3-stacked ancient camp), but you can last-hit the lane creeps that would die while I'm dead.
	
end

-------- Task_GetTaskJobDomain()
function Task_GetTaskJobDomain()
	return job_domain
end

local next_task_handle_value = 0 
-------- Task_CreateNewTask()
function Task_CreateNewTask() -- Also a t
	next_task_handle_value = next_task_handle_value + 1
	for pnot=1,TEAM_NUMBER_OF_PLAYERS do
		t_task_incentives[pnot][next_task_handle_value] = {0, 0, next_task_handle_value} -- Keep our list of incentives well-indexed
	end
	return next_task_handle_value
end

-------- Task_GetCurrrentTaskHandle()
function Task_GetCurrentTaskHandle(gsiPlayer)
	return t_player_task_current[gsiPlayer.nOnTeam][TASK_I__HANDLE]
end

-------- Task_GetCurrentTaskScore()
function Task_GetCurrentTaskScore(gsiPlayer)
	return t_player_task_current[gsiPlayer.nOnTeam][TASK_I__SCORE] or 0
end

-------- Task_IsGreaterTaskScore()
function Task_IsGreaterTaskScore(gsiPlayer, handleU, handleV)
	return (t_tasks[gsiPlayer.nOnTeam][handleU][TASK_I__SCORE] or 0) 
			> (t_tasks[gsiPlayer.nOnTeam][handleV][TASK_I__SCORE] or 0)
end

-------- Task_IndicateSuccessfulInitShortTask()
function Task_IndicateSuccessfulInitShortTask(gsiPlayer, taskHandle)
	t_check_revert_from_short[gsiPlayer.nOnTeam] = t_player_task_current[gsiPlayer.nOnTeam][TASK_I__HANDLE]
end

function Task_IncentiviseTask(gsiPlayer, taskHandle, additionalScore, decreaseIncentivePerSecond, force) -- Use this when other logic realizes that things aren't what they seem. (I'm 50% HP enchantress with full mana and 600 heal natures attendants and fight_harass is scoring low)
	local pnot = gsiPlayer.nOnTeam
	local thisTaskIncentive = t_task_incentives[pnot][taskHandle]
	
	if thisTaskIncentive[1] < additionalScore or force then
		-- index for decrements, if new
		if thisTaskIncentive[1] == 0 then
			index_incentivized_task(pnot, taskHandle)
		end
		thisTaskIncentive[1] = additionalScore
		thisTaskIncentive[2] = decreaseIncentivePerSecond
	end
end

-------- Task_GetTaskScore()
function Task_GetTaskScore(gsiPlayer, taskHandle)
	if not t_tasks[gsiPlayer.nOnTeam] or not t_tasks[gsiPlayer.nOnTeam][taskHandle] then
		return XETA_SCORE_DO_NOT_RUN -- TODO invalid current task may need to be stamped out
	end
	return t_tasks[gsiPlayer.nOnTeam][taskHandle][TASK_I__SCORE] or 0
end

-------- Task_GetCurrentTaskStartTime()
function Task_GetCurrentTaskStartTime(gsiPlayer)
	return t_task_start_time[gsiPlayer.nOnTeam]
end

-------- Task_GetCurrentTaskScore()
function Task_GetCurrentTaskScore(gsiPlayer)
	return t_player_task_current[gsiPlayer.nOnTeam][TASK_I__SCORE] or XETA_SCORE_DO_NOT_RUN
end

-------- Task_GetCurrentTaskObjective()
function Task_GetCurrentTaskObjective(gsiPlayer)
	return t_player_task_current[gsiPlayer.nOnTeam][TASK_I__OBJECTIVE] or nil
end

-------- Task_GetTaskObjective()
function Task_GetTaskObjective(gsiPlayer, taskHandle)
	return t_tasks[gsiPlayer.nOnTeam][taskHandle][TASK_I__OBJECTIVE] or nil
end

-------- Task_GetTaskRunFunc()
function Task_GetTaskRunFunc(taskHandle)
	if VERBOSE then VEBUG_print(GSI_GetBot().nOnTeam, taskHandle) end
	return t_tasks[GSI_GetBot().nOnTeam][taskHandle][TASK_I__RUN_FUNC]
end

-------- Task_RunPlayerInHighestTask()
function Task_RunPlayerInHighestTask(gsiPlayer, ...)
	local taskHandles = {...}

	for i=1,#taskHandles do
		
	end
end

-------- Task_RotatePlayerOnTeam() -- Probably for a rotating throttle
function Task_RotatePlayerOnTeam(n)
	return n >= TEAM_NUMBER_OF_PLAYERS and 1 or (n + 1) -- or (n_p+1)%tnop if tnop==0 n_p++;
end

local empty_func = function() end
-------- Task_PopulatePlaceholdersForHumans()
function Task_PopulatePlaceholdersForHumans(team)
	for pnot=1,#team do 
		if not team[pnot].hUnit:IsBot() then
			local gsiHuman = team[pnot]
			for i=1,next_task_handle_value do
				local newTaskScoreTable = {}
				newTaskScoreTable[TASK_I__OBJECTIVE] = gsiHuman
				newTaskScoreTable[TASK_I__SCORE] = 0
				newTaskScoreTable[TASK_I__INIT_FUNC] = empty_func
				newTaskScoreTable[TASK_I__RUN_FUNC] = empty_func
				newTaskScoreTable[TASK_I__SCORING_FUNC] = empty_func
				newTaskScoreTable[TASK_I__HANDLE] = i
				newTaskScoreTable[TASK_I__CURR_PRIORITY] = TASK_PRIORITY_FORGOTTEN
				t_tasks[gsiHuman.nOnTeam][i] = newTaskScoreTable
			end
			t_player_task_current[gsiHuman.nOnTeam] = t_tasks[gsiHuman.nOnTeam][1]
		end
	end
end
