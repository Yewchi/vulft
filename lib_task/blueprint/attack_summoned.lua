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

local TEAM_NUMBER_OF_PLAYERS = TEAM_NUMBER_OF_PLAYERS
local Task_SetTaskPriority = Task_SetTaskPriority
local XETA_SCORE_DO_NOT_RUN = XETA_SCORE_DO_NOT_RUN

local task_handle = Task_CreateNewTask()

local blueprint

local max = math.max
local sqrt = math.sqrt

local t_tracked_units = {}
local t_tracked_unit_names = {}

function AttackSummoned_AddTrackedUnit(abilityName, duration, summonedNames, usesHealthInstances)
	for i=1,#summonedNames do
		if not t_tracked_units[summonedNames[i]] then
			t_tracked_units[summonedNames[i]] = {duration, urgency, usesHealthInstances}
			table.insert(t_tracked_unit_names, summonedNames[i])
		end
	end
end

function AttackSummoned_InformCast(abilityName, target)
end

function ActtackSummoned_GetTrackedUnitNames()
	return t_tracked_units
end

local function estimated_time_til_completed(gsiPlayer, objective)
	return 0
end
local function task_init_func(taskJobDomain)
	if VERBOSE then VEBUG_print(string.format("attack_summoned: Initialized with handle #%d.", task_handle)) end

	use_ability = UseAbility_GetTaskHandle()

	Task_RegisterTask(task_handle, PLAYERS_ALL, blueprint.run, blueprint.score, blueprint.init)

	taskJobDomain:RegisterJob(
			function(workingSet)
				if workingSet.throttle:allowed() then
					Task_SetTaskPriority(task_handle, PLAYERS_ALL, TASK_PRIORITY_TOP)
				end
			end,
			{["throttle"] = Time_CreateThrottle(1.013)},
			"JOB_TASK_SCORING_PRIORITY_PICK_UP_ITEM"
		)
	Blueprint_RegisterTaskActivityType(task_handle, ACTIVITY_TYPE["NOT_APPLICABLE"])
	task_init_func = nil
	return task_handle, estimated_time_til_completed
end
Blueprint_RegisterTask(task_init_func)

blueprint = {
	run = function(gsiPlayer, objective, xetaScore)
		if objective.location
				and Vector_PointDistance2D(
						gsiPlayer.lastSeen.location,
						objective.location
					) < max(gsiPlayer.currentMovementSpeed*1.5, gsiPlayer.attackRange*1.5) then
			gsiPlayer.hUnit:Action_PickUpItem(objective.item)
			return xetaScore
		end
		return XETA_SCORE_DO_NOT_RUN
	end,
	
	score = function(gsiPlayer, prevObjective, prevScore)
		local currentActivityType = Blueprint_GetCurrentTaskActivityType(gsiPlayer)
		if currentActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION then
		elseif currentActivityType >= ACTIVITY_TYPE.CAREFUL then
			if PointDistance(playerLoc, TEAM_FOUNTAIN)
					> PointDistance(nearestItem.location, TEAM_FOUNTAIN) then
				return nearestItem, 300 - Math_ETA(gsiPlayer, nearestItem.location)*50
			end
			return false, XETA_SCORE_DO_NOT_RUN
		else
			return nearestItem, 300 - Math_ETA(gsiPlayer, nearestItem.location)*50
		end
	end,
	
	init = function(gsiPlayer, objective, extrapolatedXeta)
		return extrapolatedXeta
	end
}

function PickUpItem_GetTaskHandle()
	return task_handle
e
