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

local player_damage_tracker = {
		[TEAM_RADIANT] = {},
		[TEAM_DIRE] = {}
	}

DAMAGE_NODE_I__ABIILITY = 1
DAMAGE_NODE_I__DAMAGE_PER_SECOND = 2
DAMAGE_NODE_I__REMAINING_DAMAGE = 3
DAMAGE_NODE_I__REMAINING_TIME = 4
DAMAGE_NODE_I__MODIFIER = 5

local update_pnot = 1
local update_team = TEAM_RADIANT
local function update_damage_tracking(team, nOnTeam)
	
end

function DamageTracker_RegisterKnownDamage(target, ability, damage, duration, modifierToTrack)
	
	update_damage_tracking(target.team, target.nOnTeam)
end

function DamageTracker_GetKnownDamage(target)
	
end
