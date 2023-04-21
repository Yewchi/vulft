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

local farm_lane_handle
local leech_exp_handle

local LEECH_EXP_RANGE

local max = math.max
local min = math.min
local sqrt = math.sqrt

local OUT_OF_LANE_TILT_REDUCTION_SEC = 6 -- this may exceed the core level cares less
local out_of_lane_tilt = {}

local out_of_lane_tilt_update_throttle = Time_CreateOneFrameGoThrottle(0.99)

function Tilt_Initialize()
	farm_lane_handle = FarmLane_GetTaskHandle()
	leech_exp_handle = LeechExperience_GetTaskHandle()
	LEECH_EXP_RANGE = _G.LEECH_EXP_RANGE
	for i=1,TEAM_NUMBER_OF_PLAYERS do
		out_of_lane_tilt[i] = {0, GameTime()}
	end
end

function Tilt_ReportSelfOutOfLane(gsiPlayer, inLane, objective)
	
	local playerLoc = gsiPlayer.lastSeen.location
	inLane = inLane or Map_GetLaneValueOfMapPoint(playerLoc)
	objective = objective or Task_GetCurrentTaskObjective(gsiPlayer)
	local objectiveLocationForComparison = type(objective) == "table" and (objective.center
			or objective.x and objective or objective.lastSeen and objective.lastSeen.location) or false
	if not objectiveLocationForComparison then






		return false;
	end
	if inLane == gsiPlayer.lane then
		
		return false;
	end

	local enemyCreeps = Set_GetNearestEnemyCreepSetAtLaneLoc(playerLoc, inLane)
	
	if not enemyCreeps
			or Vector_PointDistance2D(enemyCreeps.center, objectiveLocationForComparison) >
				1.5*Vector_PointDistance2D(enemyCreeps.center, playerLoc) then -- not often a bot will flip by getting further away
		
		return false;
	end
	--local enemyCreepLaneFront = Set_GetEnemyCreepSetLaneFrontStored(inLane)
	local anyCores, laneCore = Farm_AnyOtherCoresInLane(gsiPlayer, enemyCreeps)

	if not anyCores or laneCore.level >= 12 then -- NB. 12, 12/6, 1.414 -- see below
		
		return false;
	end
	if type(objective) == "table" and objective.isHero
			and Task_GetCurrentTaskObjective(laneCore) == objective then
		return false
	end

	local outOfLaneTilt = out_of_lane_tilt[gsiPlayer.nOnTeam]
	if out_of_lane_tilt_update_throttle:allowed()
			and laneCore and gsiPlayer.laningWith ~= laneCore then
		
		local currTime = GameTime()
		outOfLaneTilt[1] = max(0, outOfLaneTilt[1]
				- (currTime - outOfLaneTilt[2]) * OUT_OF_LANE_TILT_REDUCTION_SEC
			)
		outOfLaneTilt[2] = currTime
	
		outOfLaneTilt[1] = outOfLaneTilt[1]
				+ (Vector_DistancePointToLine2D(
						enemyCreeps.center,
						playerLoc, objectiveLocationForComparison
					) < LEECH_EXP_RANGE and 35 or 0.15)
					* (1.414 - sqrt(laneCore.level/6)) / 1.414 -- NB. 12, 12/6, 1.414 -- see above
		outOfLaneTilt[1] = min(135, outOfLaneTilt[1])
		if outOfLaneTilt[1] > 0 then
			local decrement = outOfLaneTilt[1] / (gsiPlayer.currentMovementSpeed / 15)
			Task_IncentiviseTask(gsiPlayer, farm_lane_handle, outOfLaneTilt[1], decrement)
			Task_IncentiviseTask(gsiPlayer, leech_exp_handle, outOfLaneTilt[1], decrement)
		end
	end
end
