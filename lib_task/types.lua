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

-- All broadly-used types pertaining to tasks (and some functions to iterate and run each functions-of-types)

TASK_DISALLOW_OBJECTIVE_FUNCS = {}
TASK_DISALLOW_ANY_OBJECTIVE_FUNCS = {}

DENIAL_TYPE_FARM_LANE_CREEP =		0x0000
DENIAL_TYPE_FARM_LANE_CREEP_SET =	0x0001
DENIAL_TYPE_FARM_JUNGLE_SET =		0x0100


function TaskType_CancelAnyConfirmedDenialsSelf(gsiPlayer)
	for _,func in pairs(TASK_DISALLOW_ANY_OBJECTIVE_FUNCS) do
		func(gsiPlayer)
	end
end


function TaskType_Initialize()
	TASK_DISALLOW_OBJECTIVE_FUNCS[DENIAL_TYPE_FARM_LANE_CREEP] = 		Farm_CancelConfirmedDenial
	TASK_DISALLOW_OBJECTIVE_FUNCS[DENIAL_TYPE_FARM_LANE_CREEP_SET] = 	Farm_CancelConfirmedDenial
	TASK_DISALLOW_OBJECTIVE_FUNCS[DENIAL_TYPE_FARM_JUNGLE_SET] = 		Farm_CancelConfirmedDenialJungle

	TASK_DISALLOW_ANY_OBJECTIVE_FUNCS[DENIAL_TYPE_FARM_LANE_CREEP] = 		Farm_CancelAnyConfirmedDenials
	TASK_DISALLOW_ANY_OBJECTIVE_FUNCS[DENIAL_TYPE_FARM_LANE_CREEP_SET] = 	Farm_CancelAnyConfirmedDenials
	TASK_DISALLOW_ANY_OBJECTIVE_FUNCS[DENIAL_TYPE_FARM_JUNGLE_SET] = 		Farm_CancelAnyConfirmedDenialsJungle
end