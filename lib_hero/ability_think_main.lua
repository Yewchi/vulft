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

local throttle = Time_CreateThrottle(0.043) -- rotates

local NO_ADDITIONAL_FRAME_NEEDED = nil -- for reference
local WAITING_1ST_FRAME = 1
local WAITING_2ND_FRAME = 2

local next_up = 1
local t_hero_ability_think_run_flag = {}
local t_player_ability_think = {}

function AbilityThink_Initialize()
	local teamPlayers = GSI_GetTeamPlayers(TEAM)
	for pnot=1,TEAM_NUMBER_OF_PLAYERS do
		local thisPlayer = teamPlayers[pnot]
		local searchFuncs = HeroData_SearchFuncForHero(thisPlayer.shortName)
		t_player_ability_think[pnot] = searchFuncs("AbilityThink")
		local initFunc = searchFuncs("Initialize")
		if initFunc then 
			initFunc(thisPlayer)
		end
	end
end

local pnot
function AbilityThink_TryRun(gsiPlayer)
	pnot = gsiPlayer.nOnTeam
	if t_hero_ability_think_run_flag[pnot] then
		t_player_ability_think[pnot](gsiPlayer)
		t_hero_ability_think_run_flag[pnot] = false
	end
end

function AbilityThink_RotateAbilityThinkSetRun()
	if throttle:allowed() then
		t_hero_ability_think_run_flag[next_up] = true -- on run will set false
		next_up = Task_RotatePlayerOnTeam(next_up)
	end
end
