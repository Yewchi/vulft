-- When winning, increase pushing, rosh based on stealthiness, ie vision, 
-- -- Pushing and roshing decisions are abstractable --
-- 		rosh also based on enemy spread over the map, and team effectiveness for
-- 		the encounter.
-- When losing, the lower the team state, the more strategic
-- 		the pushing behaviour should be. As the team state gets lower, bots should
-- 		begin to use more extreme strategies to get ahead: Don't farm lanes or
-- 		jungle, stick together, try to catch someone out, put our heroes with high
-- 		suvivability and high escape somewhere to bait and try to get kills elsewhere
-- 		on the map; ward as a team; take river runes as a team; smoke where applicable
--
-- 	pep_talk should also track enemies that look alone, and prioritize ganking them
-- 		based on how alone and how well the team's kit suits ganking. 
--
-- Consider: a theoretical wrapper for push.lua to get bots to the right lane.
-- 		this would help a lot to separate the logic of getting bots to the right place
-- 		when pushing is desired, as well as scoring for moving to push locations.
TEAM_STATES = {
		["GGLOL"] = 3,
		["WINNING2"] = 2,
		["WINNING1"] = 1,
		["EVEN"] = 0,
		["LOSING1"] = -1,
		["LOSING2"] = -2,
		["GGEND"] = -3
	}
	
local allied_performance = 0



function analyze_team_performance__job(workingSet)
	return 0.5, false
end
