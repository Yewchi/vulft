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

local blueprint
local VEBOSE = VERBOSE
local DEBUG = DEBUG
local TEST = TEST

local min = math.min

local task_handle = Task_CreateNewTask()

local approx_building_attack_time = 0.8
local deagro_throttle = Time_CreateThrottle(approx_building_attack_time)
function Deagro_UpdatePriority(nOnTeam) -- 15/02/22 called from last_hit_projection when a tower is found and first recorded attacking friendly player
	--print("scoring deagro trigger", nOnTeam)
	Task_SetTaskPriority(task_handle, nOnTeam, TASK_PRIORITY_TOP)
end

local function estimated_time_til_completed(gsiPlayer, objective)
	return 2 -- don't care
end
local function task_init_func()
	Blueprint_RegisterTaskName(task_handle, "deagro")
	if VERBOSE then VEBUG_print(string.format("deagro: Initialized with handle #%d.", task_handle)) end
	
	Task_RegisterTask(task_handle, PLAYERS_ALL, blueprint.run, blueprint.score, blueprint.init)
	
	Blueprint_RegisterTaskActivityType(task_handle, ACTIVITY_TYPE["CAREFUL"])
	task_init_func = nil
	return task_handle, estimated_time_til_completed
end
Blueprint_RegisterTask(task_init_func)

blueprint = {
	run = function(gsiPlayer, objective, xetaScore)
		if GSI_UnitCanStartAttack(gsiPlayer) and (objective.type ~= UNIT_TYPE_BUILDING or objective.hUnit:CanBeSeen() and objective.hUnit:GetAttackTarget() == gsiPlayer.hUnit) then
			local nearbyCreeps = gsiPlayer.hUnit:GetNearbyCreeps(800, false)
			--print(gsiPlayer.shortName, "trying deagro")
			if GameTime() % 1.2 < 0.66 and nearbyCreeps and nearbyCreeps[1] then
				for i=1,#nearbyCreeps,1 do
					--if nearbyCreeps[i]:GetHealth()/nearbyCreeps[i]:GetMaxHealth() < 0.5 then
						--[DEBUG]]print(gsiPlayer.shortName, "deagro should succeed")
if DEBUG then
						DebugDrawLine(gsiPlayer.lastSeen.location, nearbyCreeps[1]:GetLocation(), 125, 0, 255)
end
						gsiPlayer.hUnit:Action_AttackUnit(nearbyCreeps[1], true)
						return xetaScore
					--end
				end
			else
				local moveTo = Vector_UnitDirectionalPointToPoint(gsiPlayer.lastSeen.location,
						TEAM_FOUNTAIN
					)
				moveTo.x = moveTo.x*0.65; moveTo.y = moveTo.y*0.65
				moveTo = Vector_Addition(
						Vector_UnitDirectionalPointToPoint(objective.lastSeen.location,
								gsiPlayer.lastSeen.location
							),
						moveTo
					)
				moveTo = Vector_ScalarMultiply2D(moveTo, 800 + min(1000, (1500 - (gsiPlayer.locationVariation or 1500))))
				gsiPlayer.hUnit:Action_MoveDirectly(moveTo)
				return xetaScore
			end
		end
		return XETA_SCORE_DO_NOT_RUN
	end,
	
	score = function(gsiPlayer, prevObjective, prevScore)
		-- TODO Implement creep deagro scoring
		--print(gsiPlayer.shortName, "scoring deagro")
		local underTower = Set_GetEnemyTowerPlayerIsUnder(gsiPlayer)
		if VERBOSE then INFO_print(string.format("%d underTower: %s, %s, %s", gsiPlayer.nOnTeam, Util_Printable(underTower), Util_Printable(Analytics_GetNearFutureHealth(gsiPlayer)), Util_Printable(gsiPlayer.lastSeenHealth))) end
		if Analytics_GetNearFutureHealth(gsiPlayer) >= gsiPlayer.lastSeenHealth then return false, XETA_SCORE_DO_NOT_RUN end
		if underTower and not underTower.hUnit:IsNull() and underTower.hUnit:CanBeSeen() then 
			local nearbyAlliedCreeps = Set_GetNearestAlliedCreepSetToLocation(gsiPlayer.lastSeen.location)
			local alliedCreepsUnderTower = Set_GetUnitsInRadiusCircle(underTower.lastSeen.location, underTower.attackRange-150, nearbyAlliedCreeps, nil)
			local numUnderTower = #alliedCreepsUnderTower
			local i = 1
			while(i <= numUnderTower) do
				if alliedCreepsUnderTower[i].creepType ~= CREEP_TYPE_SIEGE then
					break
				end
				i = i + 1
			end
if DEBUG then
			DebugDrawText(1700, 750+(gsiPlayer.nOnTeam*10), string.format("%d: %d,%s", gsiPlayer.nOnTeam, numUnderTower, i > numUnderTower), 255, 255, 255)
end
			if i > numUnderTower then return false, XETA_SCORE_DO_NOT_RUN end
			--print("creeps", gsiPlayer.hUnit:GetNearbyCreeps(1200, true), "target", underTower.hUnit:GetAttackTarget(), "can attack", GSI_UnitCanStartAttack(gsiPlayer))
			if underTower.hUnit:GetAttackTarget() == gsiPlayer.hUnit and gsiPlayer.hUnit:GetNearbyCreeps(1200, true) then
			--print("returning deagro score", 3.0, -Analytics_GetNearFutureHealthPercent(gsiPlayer), -math.min(2.0, gsiPlayer.hUnit:TimeSinceDamagedByTower()),
						--Xeta_EvaluateObjectiveCompletion(XETA_HEALTH_LOSS, 0, 2*Lhp_GetActualFromUnitToUnitAttackOnce(underTower.hUnit, gsiPlayer.hUnit), gsiPlayer, gsiPlayer))
			--print("deagro", (3.0 - Analytics_GetNearFutureHealthPercent(gsiPlayer) - math.min(2.0, gsiPlayer.hUnit:TimeSinceDamagedByTower()))
			--			* Xeta_EvaluateObjectiveCompletion(XETA_HEALTH_LOSS, 0, 2*Lhp_GetActualFromUnitToUnitAttackOnce(underTower.hUnit, gsiPlayer.hUnit), gsiPlayer, gsiPlayer))
			return underTower, (3.0 - Analytics_GetNearFutureHealthPercent(gsiPlayer) - math.min(2.0, gsiPlayer.hUnit:TimeSinceDamagedByTower()))
						* 4 * Xeta_EvaluateObjectiveCompletion(XETA_HEALTH_LOSS, 0, 2*Lhp_GetActualFromUnitToUnitAttackOnce(underTower.hUnit, gsiPlayer.hUnit), gsiPlayer, gsiPlayer)
			end
		end
		--print("returning false deagro", underTower, underTower and underTower.hUnit:GetAttackTarget() and  underTower.hUnit:GetAttackTarget():GetUnitName() or "[no target]")
		return false, XETA_SCORE_DO_NOT_RUN
	end,
	
	init = function(gsiPlayer, objective, extrapolatedXeta)
		Task_IndicateSuccessfulInitShortTask(gsiPlayer, task_handle)
		return extrapolatedXeta
	end
}

function Deagro_GetTaskHandle()
	return task_handle
end
