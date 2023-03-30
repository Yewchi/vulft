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

function Vibe_CreateVibe(thisPlayer)
	local newVibe = {}
	newVibe.greedRating = Team_GetRoleBasedGreedRating(thisPlayer) -- N.B. Intended for low-level modifiers. Use sparingly on scores from low-level code in high-level code.
	--print(thisPlayer.shortName, "have greed", newVibe.greedRating)
	newVibe.safetyRating = 1.0 -- the lean towards using attacks over mobility, heals or defensives.
	newVibe.aggressivityRating = 0.5 -- 1.0 would cause us to use all abilities and stuns per attaining a kill, 0.75 may cause us to hold a stun for attempted get-aways or key fight tempo switches and counter-plays. 0.6 is about fight_harass. 0.35 is about farm_lane. 0.0 is increase_safety, where abilities will only be used because they help us escape.
	
	return newVibe
end

function Vibe_CreateAndAllocatePlayerVibes(t_players)
	for i=1,#t_players,1 do
		t_players[i].vibe = Vibe_CreateVibe(t_players[i])
	end
end
