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

-- Frustration, or Vex_, is queried for bots overstaying their welcome for a roaming
-- - gank, or dispute solving when multiple cores want to push a lane where jungle
-- - creeps could be farmed at the same time. Also to determine that bots need ganks
-- - (the enemy in lane are making farming impossible). These could be separated into
-- - various modules, but giving it the categorization of "frustration" enables feeling,
-- - sense, and emotional emulation-driven code. It's useful as it is because each can
-- - be calculated into a 'growing frustration', indicating more drastic team-based
-- - measures will need to be taken to win the match--or 3-turtle-2-farm.

local t_exp_leeching = {}
local t_not_supported = {}
local t_lane_oppression = {}
local t_map_safety = {}
local t_allies, t_enemies
local t_lane_present_allies = {}
local t_lane_present_enemies = {}

local function create_vex_node(subject, vex) -- vex is 0.0: acceptable; to 1.0: feed mid.

end

local function update_exp_leech_frustration()
	for pnot=1,TEAM_NUMBER_OF_PLAYERS do
		local thisPlayer = t_allies[pnot]
		local thisPlayerRoleBasedLane = Team_GetRoleBasedLane(thisPlayer)
	end
end

function Vex_InitializeFrustrationAnalytics(jobDomain)
	t_allies = GSI_GetTeamPlayers(TEAM)
	t_enemies = GSI_GetTeamPlayers(ENEMY_TEAM)
	jobDomain:RegisterJob(
			update_frustration,
			{throttle = Time_CreateThrottle(0.997)},
			"JOB_VEX_UPDATE_FRUSTRATION"
		)
end

function Vex_UpdateLaneAssignments

end

function Vex_FactorLanePresence(gsiPlayer, lane)

end
