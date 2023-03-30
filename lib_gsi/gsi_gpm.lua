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

local PASSIVE_GOLD_GAIN = 1 / 0.63

-- Helpful for simulating benefit of doing a high-xeta (time-wise) task. 
--- Collecting a bounty rune may be worth less than taking a pushed T3, but if you only need to make a five
--- second detour, the value of the bounty rune is 
---  (bounty rune in team gold) / (bounty rune time collecting) 
---     + (gpm * additional time completing other tasks of comparison)
--- More thought could be formulated around what this means about the support role, having low gpm at the
--- start of a game due to the nature of farming waves and roles, and cores that flop or supports that
--- accidently take over the game. i.e.: if warding is scored according to data rather than rules will we
--- see floppy spectre walk through river to deward while god-like lion farms a wave. Do we want to see this?

function GSI_GetPlayerGPM(thisPlayer)
	-- TODO PLACEHOLDER
	return 500.0 * thisPlayer.vibe.greedRating / (thisPlayer.vibe.greedRating + 0.2) -- 416, 400, 375, 333, 250
end

function GSI_GetPlayerGoldValueOfTime(thisPlayer)
	return (GSI_GetPlayerGPM(thisPlayer) / 60) - PASSIVE_GOLD_GAIN
end
