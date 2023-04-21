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


-- Stuns die at 0.2s
--
-- Slows are reduced from 100% value to 50% value from 0.75s to 0s remaining
--
-- Silence is removed at 0.2s
--
-- Damage falls off exponentially from 0.25s remaining til expected hit time to -0.33s remaning going 100% to 0%
-- DPS damage ticks in real time as simple (totaldmg / remainingTime)

DT_ROOTED_SLOW_AMOUNT = 1.67

DAMAGE_NODE_I__ABIILITY = 1
DAMAGE_NODE_I__AMOUNT = 2
DAMAGE_NODE_I__EXPIRES_IF_NO_MODIFIER_TIME = 3
DAMAGE_NODE_I__EXPIRES_AFTER_APPLICATION = 4
DAMAGE_NODE_I__MODIFIER = 5

local function fill_player_tracker_tables(tbl, count)
	local radiantTbl = tbl[TEAM_RADIANT]
	local direTbl = tbl[TEAM_DIRE]
	for i=1,count do
		radiantTbl[i] = {}
		direTbl[i] = {}
	end
end

local player_damage_tracker = {
		[TEAM_RADIANT] = {},
		[TEAM_DIRE] = {}
	};
fill_player_tracker_tables(player_damage_tracker, math.max(TEAM_NUMBER_OF_PLAYERS, ENEMY_TEAM_NUMBER_OF_PLAYERS))
local player_slow_tracker = {
		[TEAM_RADIANT] = {},
		[TEAM_DIRE] = {}
	}
fill_player_tracker_tables(player_slow_tracker, math.max(TEAM_NUMBER_OF_PLAYERS, ENEMY_TEAM_NUMBER_OF_PLAYERS))
local player_stun_tracker = {
		[TEAM_RADIANT] = {},
		[TEAM_DIRE] = {}
	}
fill_player_tracker_tables(player_stun_tracker, math.max(TEAM_NUMBER_OF_PLAYERS, ENEMY_TEAM_NUMBER_OF_PLAYERS))
local player_silence_tracker = {
		[TEAM_RADIANT] = {},
		[TEAM_DIRE] = {}
	}
fill_player_tracker_tables(player_silence_tracker, math.max(TEAM_NUMBER_OF_PLAYERS, ENEMY_TEAM_NUMBER_OF_PLAYERS))

function DamageTracker_AnyStunsOn(target)

	return false, 0, false
end

function DamageTracker_AnySlowsOn(target)

	return false, 0, false
end

function DamageTracker_AnySilenceOn(target)

	return false, 0, false
end

function DamageTracker_GetDamageOn(target)

	return 0, 0
end

-------- DamageTracker_IsRooted()
function DamageTracker_IsRooted(target)
	if not implemented then
		return target.hUnit:IsRooted() and 0.2
	end
	local slows = player_slow_tracker[target.team][target.nOnTeam]
	local slowForConsideration = 0
	local time = GameTime()
	local i = 1
	while(slows[i]) do
		local thisSlow = slows[i]
		local expiresIn = thisSlow[2] - time
		if expiresIn > 0.75 then
			slowForConsideration = slowForConsideration == 0 and 1 - thisSlow[1]
					or slowForConsideration * (1 - thisSlow[1])
			i = i + 1
		elseif expiresIn > 0 then
			local expiringReduction = 0.5 + 0.66 * expiresIn * thisSlow[1] -- 0.5*expiresIn*thisSlowAmnt/0.75
			slowForConsideration = slowForConsideration == 0 and 1 - expiringReduction
					or slowForConsideration * (1 - expiringReduction)
			i = i + 1
		elseif expiresIn <= 0 then
			table.remove(slows, i)
		end
	end
	slowForConsideration = 1 - slowForConsideration
	return slowForConsideration >= 1
end

function DamageTracker_RegisterDamage(target, ability, damage, duration, modifierToTrack,
			ifNoneAfter, ifNone
		)
	update_damage_tracking(target.team, target.nOnTeam)
	return true
end

function DamageTracker_RegisterStun(target, noStartExpire, duration, modifierToTrack,
			ifNoneAfter, ifNone
		)
	return true	
end

function DamageTracker_RegisterSlow(target, noStartExpire, duration, modifierToTrack,
			ifNoneAfter, ifNone, ifLowerThanPercent
		)
	return true	
end

function DamageTracker_RegisterSilence(target, noStartExpire, duration, modifierToTrack,
			ifNoneAfter, ifNone
		)
	return true	
end
