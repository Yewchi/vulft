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


local t_lane_data = {}
t_lane_data.enemy = {}
t_lane_data.allied = {}

farm_lane_handle = FarmLane_GetTaskHandle()
leech_exp_handle = LeechExperience_GetTaskHandle()
push_handle = Push_GetTaskHandle()
avoid_hide_handle = AvoidHide_GetTaskHandle()

local t_team
local t_enemy
local t_pnot_update_time = {}

function LanePerformance_Initialize()
	t_team, t_enemy = GSI_GetTeamPlayers(BOTH_TEAMS)
	for i=1,#t_team do
		t_pnot_update_time[i] = 0
	end

	for team_str,team_data in pairs(t_lane_data) do
		team_data.bot = {}
		team_data.mid = {}
		team_data.top = {}
		for _,lane in pairs(team_data) do
			lane.kdr = 1
			lane.heroes = {}
			lane.presence = {}
			lane.expected_return_time = {}
			lane.expected_farm_rate = {} -- time spent farming lane unchallenged
		end
	end
end

function LanePerformance_GetLaningModifier(gsiPlayer, task)
	
end

lanes.bot = {}
lanes.mid = {}
lanes.top = {}
