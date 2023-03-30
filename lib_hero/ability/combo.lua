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



local ud_string = "userdata" -- could be always indexed, don't know. Might as well avoid the garbage frame otherwise

local COMBO_I__COMBO_IDENTIFIER = 1
local COMBO_I__INSTRUCTIONS = 2
local COMBO_I__QUEUE_INDEX = 3

local t_combo = {}

local t_queued_combo = {} -- Expected size, most often only 1, 2, almost impossible for over 3 elements. 

local function remove_queued_combo(queue, combo)
	local prevQueueIndex = combo[COMBO_I__QUEUE_INDEX]
	local currQueueIndex = prevQueueIndex + 1
	combo[COMBO_I__QUEUE_INDEX] = combo[COMBO_I__QUEUE_INDEX] + HIGH_32_BIT -- sets combo to not-in-queue
	
	while(currQueueIndex<=#t_queued_combo) do -- this will usually 1 <= 2 --> EXIT_SUCCESS
		t_queued_combo[prevQueueIndex] = t_queued_combo[currQueueIndex] -- cascade
		t_queued_combo[prevQueueIndex][COMBO_I__QUEUED_INDEX] = t_queued_combo[prevQueueIndex][COMBO_I__QUEUED_INDEX] - 1
	end
end

function Combo_InformClearingCombo(gsiPlayer, comboIndex)
	local thisCombo = t_combo[gsiPlayer.nOnTeam][comboIndex]
	
	if thisCombo then
		remove_queued_combo(t_queued_combo[gsiPlayer.nOnTeam], thisCombo)
	end
end

function Combo_QueueComboAndLockToScore(gsiPlayer, comboIndex)

end

function Combo_RegisterComboList()
end