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

---- time constants --
TIMED_AVOID_RECALCULATE_THROTTLE = 0.173
--

 -- Only use timed data for data which is not worth recomputing at TIMED_AVOID_RECALCULATE_THROTTLE inverals, but is often requested many times in that time, like nearest enemy tower. This data handling is essentially a 0 to 0.127 reaction time.
local job_domain

local t_team_players

local next_player = 1
function Time_InitializePlayerTimeData()
	job_domain = Job_CreateDomain("DOMAIN_TIMED_AVOID_RECALCULATE")
	
	t_team_players = GSI_GetTeamPlayers(TEAM)
	
	local currTime = GameTime()
	local teamPlayers = GSI_GetTeamPlayers(TEAM)
	for nOnTeam=1,#teamPlayers,1 do
		local thisPlayer = teamPlayers[nOnTeam]
		local throttleOffset = TIMED_AVOID_RECALCULATE_THROTTLE * nOnTeam / TEAM_NUMBER_OF_PLAYERS
		local thisPlayerThrottle = Time_CreateThrottle(TIMED_AVOID_RECALCULATE_THROTTLE)
		 -- Make the bots roll out their recalcs: (this becomes a computational cost increase at... 8 FPS)
		thisPlayerThrottle.next = currTime + throttleOffset
		job_domain:RegisterJob(
				function(workingSet)
					if workingSet.throttle:allowed() then
						local thisPlayer = t_team_players[next_player]
						for k in pairs(thisPlayer.time.data) do
	-- This is faster if doubly indexed (i guess), but makes values-as-table (like a safeUnit) unusable
							thisPlayer.time.data[k] = nil
						end
						next_player = Task_RotatePlayerOnTeam(next_player)
					end
				end,
				{["throttle"] = thisPlayerThrottle},
				"JOB_FORCE_TIME_RECALCULATE"
			)
		
		thisPlayer.time = {}
		thisPlayer.time.prevFrame = GameTime()
		thisPlayer.time.currFrame = GameTime()
		thisPlayer.time.frameElapsed = 0.01667
		thisPlayer.time.nextFrame = GameTime() + 0.01667
		thisPlayer.time.data = {}
		PNOT_TIMED_DATA[nOnTeam] = thisPlayer.time.data
	end

	Time_InitializePlayerTimeData = nil
end

function Time_TryTimeDataReset()
	job_domain:DoJob("JOB_FORCE_TIME_RECALCULATE")
end

function Time_IndicateNewFrame(thisBot)
	thisBot.time.prevFrame = thisBot.time.currFrame
	thisBot.time.currFrame = GameTime()
	thisBot.time.frameElapsed = thisBot.time.currFrame - thisBot.time.prevFrame
	thisBot.time.nextFrame = thisBot.time.currFrame + thisBot.time.frameElapsed
end

function Time_Throttle(this)
	if this.next and GameTime() > this.next then
		this.next = GameTime() + this.c
		return true
	end
end

function Time_CreateThrottle(delta)
	local new = {}
	new.allowed = Time_Throttle
	new.delete = Time_DeleteThrottle
	new.next = GameTime() + delta + (TEAM_DIRE and delta/2 or 0.0) -- Let the throttles flip between dire and radiant, to spread load.
	new.c = delta
	return new
end

function Time_CreateModThrottle(delta, offset) -- (60, 54) triggers at x:54 Game Clock.
	local new = {}
	new.allowed = Time_ModThrottle
	new.delete = Time_DeleteThrottle
	new.offset = offset or 0.0
	new.prevIntegerDiv = math.floor( (DotaTime() + new.offset)/ delta)
	new.m = delta
	
	return new
end

function Time_ModThrottle(this)
	local thisIntegerDiv = math.floor( (DotaTime() + this.offset) / this.m)
	if thisIntegerDiv > this.prevIntegerDiv then
		this.prevIntegerDiv = thisIntegerDiv
		return true
	end
end

-- Frame Throttle: 
-- These do not use a standard parent bot, they simply take the most recent bot that hit the throttle allowed() (usually the captain) and add the previous frame-to-frame time for the bot that triggers.
-- Not to be confused with a guarenteed and reliable run-once flag.
function Time_OneFrameGoThrottle(this)
	local currTime = GameTime()
	if currTime < this.allowedUntil then
		return true
	elseif this.next and currTime > this.next then
		local thisBot = GSI_GetBot()
		this.next = currTime + this.c + thisBot.time.frameElapsed
		this.allowedUntil = currTime + thisBot.time.frameElapsed
		return true
	end
end
local Time_OneFrameGoThrottle = Time_OneFrameGoThrottle

function Time_CreateOneFrameGoThrottle(delta)
	local new = {}
	new.allowed = Time_OneFrameGoThrottle
	new.delete = Time_DeleteThrottle
	new.next = GameTime() + delta + (TEAM_DIRE and delta/2 or 0.0)
	new.allowedUntil = 0.0
	new.c = delta
	
	return new
end

function Time_DeleteThrottle(this)
	this = nil
end

function Time_CreateBench(delta)
	local bench = Time_CreateOneFrameGoThrottle(delta)
	bench.BenchStart = Time_BenchStart
	bench.BenchEnd = Time_BenchEnd
	bench.benchTime = 0
	
	return bench
end

function Time_BenchStart(bench)
	bench.prevTime = RealTime()
end

function Time_BenchEnd(bench, captainPrint, formatString, ...) -- Provide table keys in bench for format values.
	bench.benchTime = bench.benchTime + RealTime() - bench.prevTime
	if (not captainPrint or GSI_GetBot().isCaptain) and bench:allowed() then
		DEBUG_print(string.format("<BENCH> in with %s, %s, %s",
				not captainPrint and "T" or "F",
				GSI_GetBot().isCaptain and "T" or "F",
				bench:allowed() and "T" or "F" )
			)
		args = {...}
		local argsDeduced = {bench.benchTime*1000, bench.c}
		for i=3,#args,1 do
			argsDeduced[i] = bench[args[i]]
		end
		DEBUG_print(string.format("<BENCH> %.4fms/%.2fs -- "..formatString, unpack(argsDeduced)))
		
		bench.benchTime = 0
	end
end
