
local t_lane_data = {}
t_lane_data.enemy = {}
t_lane_data.allied = {}

for team_str,team_lane in pairs(t_lane_data) do
	team_lane.bot = {}
	team_lane.mid = {}
	team_lane.top = {}
	for _,lane in pairs(team_lane) do
		lane.kdr = 1
		lane.heroes = {}
		lane.presence = {}
		lane.expected_return_time = {}
		lane.expected_farm_rate = {} -- time spent farming lane unchallenged
	end
end

function 

lanes.bot = {}
lanes.mid = {}
lanes.top = {}

