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

require(GetScriptDirectory().."/lib_math/vector")
require(GetScriptDirectory().."/partial_full_handover")

local DEBUG_KILLSWITCH_ALERT = false
local DEBUG_KILLSWITCH = false
local FLIP_TO_DEFAULT_BOT_BEHAVIOUR_NEAR_RUNE_DIST = 150
function Think() --[[annoying in the early game] print("RUNNING ROAM")--]] end
function GetDesire()
	local thisBot = GSI_GetPlayerFromPlayerID(GetBot():GetPlayerID())
	if (DotaTime() >= -1 and thisBot and thisBot.awaitsDefaultBotsInterruptedFullTakeoverForHookHandoverToFull)
			and ( (GetRuneStatus(RUNE_POWERUP_1) == RUNE_STATUS_AVAILABLE
						and Vector_PointDistance2D(GetBot():GetLocation(), GetRuneSpawnLocation(RUNE_POWERUP_1))
							< FLIP_TO_DEFAULT_BOT_BEHAVIOUR_NEAR_RUNE_DIST
					)
					or (GetRuneStatus(RUNE_POWERUP_2) == RUNE_STATUS_AVAILABLE
						and Vector_PointDistance2D(GetBot():GetLocation(), GetRuneSpawnLocation(RUNE_POWERUP_2))
							< FLIP_TO_DEFAULT_BOT_BEHAVIOUR_NEAR_RUNE_DIST
					)
					or (GetRuneStatus(RUNE_BOUNTY_1) == RUNE_STATUS_AVAILABLE
						and Vector_PointDistance2D(GetBot():GetLocation(), GetRuneSpawnLocation(RUNE_BOUNTY_1))
							< FLIP_TO_DEFAULT_BOT_BEHAVIOUR_NEAR_RUNE_DIST
					)
					or (GetRuneStatus(RUNE_BOUNTY_2) == RUNE_STATUS_AVAILABLE
						and Vector_PointDistance2D(GetBot():GetLocation(), GetRuneSpawnLocation(RUNE_BOUNTY_2))
							< FLIP_TO_DEFAULT_BOT_BEHAVIOUR_NEAR_RUNE_DIST
					)
				) then
		INFO_print("Using default bot Think() to attempt pick up runes. Handover to full-takeover will occur when holding 7 items. "..(thisBot.shortName or "no name"))
		return 0.0
	elseif DEBUG_KILLSWITCH then
		if not DEBUG_KILLSWITCH_ALERT then
			TEAM_CAPTAIN_UNIT:ActionImmediate_Chat("Fatal error in VUL-FT script. :\\This *may* be fixed with console command 'dota_bot_reload_scripts'.", true)
			DEBUG_KILLSWITCH_ALERT = true
		end
		return 0.0
	else
		return 0xFFFF -- run the full-takeover hook code via ability_item_usage_generic.lua (until it completes partial_full_handover at 7 items held, but they can't pick up water / stacked runes after it occurs and bot_generic Think function is defined)
	end
end
