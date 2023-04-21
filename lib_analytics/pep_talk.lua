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

-- When winning, increase pushing, rosh based on stealthiness, ie vision, 
-- -- Pushing and roshing decisions are abstractable --
-- 		rosh also based on enemy spread over the map, and team effectiveness for
-- 		the encounter.
-- When losing, the lower the team state, the more strategic
-- 		the pushing behavior should be. As the team state gets lower, bots should
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
