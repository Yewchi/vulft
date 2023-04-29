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

ACTIVITY_TYPE = { -- Ordered by reaction to additional aggressive behavior while in the activity type (i.e. the name is not the reaction itself). Examples are listed below
	["DEATH_WISH"] = 1, -- Pango with only swashbuckle up, vs Godlike Lina on 50 hp at T4.
	["KILL"] = 2, -- Mid-fight, ganking.
	["CONTROLLED_AGGRESSION"] = 3, -- Harassing during laning stage.
	["NOT_APPLICABLE"] = 4, -- Instant ability use, stop-casting spark wraith and bloodlust and on an increasing interval before 0:00 bounty rune spawns.
	["TANKING_CREEPS"] = 5, -- Jungle farming, cutting wave at higher level, dealing with Chen
	["COLLECTING"] = 6, -- Farming lane, collecting bounty rune.
	["CAREFUL"] = 7, -- Lurking jungle, low-health fight contributions.
	["USING_SPACE"] = 8, -- Pushing far into enemy territory.
	["FEAR"] = 9 -- Indiana Jones on 50 hp vs Godlike Pango on 100% HP.
}

COUNT_ACTIVITY_TYPES = ACTIVITY_TYPE.FEAR

local ACTIVITY_TYPE = ACTIVITY_TYPE

local t_task_activity_type
do
	for typeString,index in pairs(ACTIVITY_TYPE) do
		t_task_activity_type = {}
	end
end
local t_task_time_remaining_func = {}
local task_init_funcs = {}
local t_inform_dead_funcs = {}

local t_custom_activity_type = {} -- override for current task type. Cleared by task.lua on switching current task

local t_named_handles = {}

function Blueprint_RegisterTask(taskInitFunc)
	table.insert(task_init_funcs, taskInitFunc)
end

function Blueprint_RegisterTaskName(taskHandle, taskName)
	t_named_handles[taskName] = taskHandle
end

if IsNotJustAnExample then
	function estimate_time_til_completed(gsiPlayer, objective)
		return abstractedMeansOfDeterminingTimeTilCompletionTime
	end
	local function task_init_func(taskJobDomain)
		task_handle = Task_CreateNewTask()

		Task_RegisterTask(task_handle, PLAYERS_ALL, blueprint.run, blueprint.score, blueprint.init)
		if VERBOSE then VEBUG_print(string.format("task_file_name: Initialized with handle #%d.", task_handle)) end

		taskJobDomain:RegisterJob(
				function(workingSet)
					if workingSet.throttle:allowed() then
						Task_SetTaskPriority(task_handle, PLAYERS_ALL, TASK_PRIORITY_TOP)
					end
				end,
				{["throttle"] = Time_CreateThrottle(PRIORITY_UPDATE_TEMPLATE_THROTTLE)},
				"JOB_TASK_SCORING_PRIORITY_TEMPLATE"
			)
		Blueprint_RegisterTaskActivityType(task_handle, ACTIVITY_TYPE["NOT_APPLICABLE"])
		Task_CreateUpdatePriorityExampleJob = nil
		return task_handle, time_to_score_dip
	end
	Blueprint_RegisterTask(task_init_func)

	blueprint = {
		run = function(gsiPlayer, objective, xetaScore)
			process_objectives_do_task()
		end,
		
		score = function(gsiPlayer, prevObjective, prevScore)
			return highest_xeta_obj, highest_xeta_score
		end,
		
		init = function(gsiPlayer, objective, extrapolatedXeta)
			initialize_task()
		end
	}
end

function Blueprint_InitializeAllBlueprintPriorityJobs(taskJobDomain)
	for i=1,#task_init_funcs do
		local handle, timeRemainingFunc = task_init_funcs[i](taskJobDomain)
		if DEBUG then INFO_print(handle) end
		if not handle or not timeRemainingFunc then print("/VUL-FT/ ERR -- task missing init data", handle, timeRemaining) end
		t_task_time_remaining_func[handle] = timeRemainingFunc
		task_init_funcs[i] = nil
	end
	task_init_funcs = nil
	
	Blueprint_InitializeAllBlueprintPriorityJobs = nil

	return t_custom_activity_type
end

function Blueprint_InformDead(gsiPlayer)
	for i=1,#t_inform_dead_funcs do
		t_inform_dead_funcs[i](gsiPlayer)
	end
end

function Blueprint_RegisterInformDeadFunc(func)
	table.insert(t_inform_dead_funcs, func)
end

function Blueprint_GetTaskTimeRemaining(gsiPlayer, taskHandle, objective)
	return t_task_time_remaining_func[taskHandle](gsiPlayer, objective)
end

function Blueprint_GetTaskToObjTimeRemaining(gsiPlayer, taskHandle, objectiveCurrent, newObjective)
	return Blueprint_GetTaskTimeRemaining(gsiPlayer, taskHandle, objectiveCurrent)
			+ Math_PointToPointDistance2D(gsiPlayer.lastSeen.location, newObjective.lastSeen and newObjective.lastSeen.location or newObjective)
				/ gsiPlayer.currentMovementSpeed -- Assume it was a vector if not a safeObject
end

function Blueprint_TaskOfHandleIsActivityType(taskHandle, activityType)
	return t_task_activity_type[taskHandle] == activityType
end

function Blueprint_IncentiviseHighStakesTasks(gsiPlayer, incentiveAmount, decrementDelta)
	-- TODO pass the incentive kit to Blueprint
	Task_IncentiviseTask(gsiPlayer, t_named_handles.fight_harass, incentiveAmount, decrementDelta)
	Task_IncentiviseTask(gsiPlayer, t_named_handles.avoid_and_hide, incentiveAmount, decrementDelta)
	Task_IncentiviseTask(gsiPlayer, t_named_handles.increase_safety, incentiveAmount, decrementDelta)
	Task_IncentiviseTask(gsiPlayer, t_named_handles.use_ability, incentiveAmount, decrementDelta)
	Task_IncentiviseTask(gsiPlayer, t_named_handles.use_item, incentiveAmount, decrementDelta)
	Task_IncentiviseTask(gsiPlayer, t_named_handles.deagro, incentiveAmount, decrementDelta)
end

function Blueprint_GetCurrentTaskActivityType(gsiPlayer)
	return t_custom_activity_type[gsiPlayer.nOnTeam] or t_task_activity_type[Task_GetCurrentTaskHandle(gsiPlayer)] or ACTIVITY_TYPE.NOT_APPLICABLE
end

function Blueprint_TaskHandleIsFighting(taskHandle)
	-- TODO
	-- TEMP CODE
	return taskHandle == FightHarass_GetTaskHandle()
end

function Blueprint_RegisterTaskActivityType(taskHandle, activityType)
	t_task_activity_type[taskHandle] = activityType
end

function Blueprint_RegisterCustomActivityType(gsiPlayer, activityType)
	-- This will be set nil when task switching in task::ScoringCont()
	t_custom_activity_type[gsiPlayer.nOnTeam] = activityType
end

require(GetScriptDirectory().."/lib_task/blueprint/farm_lane")
require(GetScriptDirectory().."/lib_task/blueprint/farm_jungle")
require(GetScriptDirectory().."/lib_task/blueprint/fight/fight")
require(GetScriptDirectory().."/lib_task/blueprint/leech_experience")
require(GetScriptDirectory().."/lib_task/blueprint/consumable")
require(GetScriptDirectory().."/lib_task/blueprint/deagro")
require(GetScriptDirectory().."/lib_task/blueprint/avoid_and_hide")
require(GetScriptDirectory().."/lib_task/blueprint/increase_safety")
require(GetScriptDirectory().."/lib_task/blueprint/port")
require(GetScriptDirectory().."/lib_task/blueprint/use_ability")
require(GetScriptDirectory().."/lib_task/blueprint/push")
require(GetScriptDirectory().."/lib_task/blueprint/zone_defend")
require(GetScriptDirectory().."/lib_task/blueprint/rune")
require(GetScriptDirectory().."/lib_task/blueprint/dawdle")
require(GetScriptDirectory().."/lib_task/blueprint/use_item")
require(GetScriptDirectory().."/lib_task/blueprint/pick_up_item")
require(GetScriptDirectory().."/lib_task/blueprint/die_to_neutrals")
require(GetScriptDirectory().."/lib_task/blueprint/search_fog")
require(GetScriptDirectory().."/lib_task/blueprint/mortal_unit")

--task_init_funcs = { -- bad, should self-register TODO
--	Task_CreateUpdatePriorityFarmLaneJob,
--	Task_CreateUpdatePriorityFightHarassJob,
--	Task_CreateUpdatePriorityFightKillCommitJob,
--	Task_CreateUpdatePriorityLeechExperienceJob,
--	Task_CreateUpdatePriorityConsumableJob,
--	Task_CreateUpdatePriorityDeagroJob,
--	Task_CreateUpdatePriorityAvoidHideJob,
--	Task_CreateUpdatePriorityIncreaseSafetyJob,
--	Task_CreateUpdatePriorityPortJob,
--	Task_CreateUpdatePriorityUseAbilityJob,
--	Task_CreateUpdatePriorityPushJob,
--	Task_CreateUpdatePriorityRuneJob
--}
