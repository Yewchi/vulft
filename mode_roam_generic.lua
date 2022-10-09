require(GetScriptDirectory().."/lib_math/vector")
require(GetScriptDirectory().."/partial_full_handover")

local DEBUG_KILLSWITCH_ALERT = false
local FLIP_TO_DEFAULT_BOT_BEHAVIOUR_NEAR_RUNE_DIST = 150
function Think() --[[annoying in the early game] print("RUNNING ROAM")--]] end
function GetDesire()
	if DotaTime() >= -1 and DotaTime() < 110
			and ( (GetRuneStatus(RUNE_POWERUP_1) == RUNE_STATUS_AVAILABLE
						and Vector_PointDistance2D(GetBot():GetLocation(), GetRuneSpawnLocation(RUNE_POWERUP_1))
							< FLIP_TO_DEFAULT_BOT_BEHAVIOUR_NEAR_RUNE_DIST
					)
					or (GetRuneStatus(RUNE_POWERUP_2) == RUNE_STATUS_AVAILABLE
						and Vector_PointDistance2D(GetBot():GetLocation(), GetRuneSpawnLocation(RUNE_POWERUP_2))
							< FLIP_TO_DEFAULT_BOT_BEHAVIOUR_NEAR_RUNE_DIST
					)
				) then
		INFO_print("Using default bot Think() to attempt pick up the river bounty runes. Handover to full-takeover will occur shortly.")
		return 0.0
	elseif DEBUG_KILLSWITCH then
		if not DEBUG_KILLSWITCH_ALERT then
			TEAM_CAPTAIN_UNIT:ActionImmediate_Chat("Fatal error in VUL-FTcript. :\\This *may* be fixed with console command 'dota_bot_reload_scripts'.", true)
			DEBUG_KILLSWITCH_ALERT = true
		end
		return 0.0
	else
		return 0xFFFF -- run the full-takeover code.
	end
end
