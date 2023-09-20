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

-- Other modules can register their data as objective locations, when an enemy
-- 		disappears from the map, use these objectives, and their difficulties along with
-- 		enemy expected capabilities to determine where they might go. Just as a player
-- 		may say "A Radiant Terrorblade was solo pushing Dire bot T2. They left the tower
-- 		and walked towards the jungle, so they went to farm jungle or left for radiant's
-- 		jungle, because they can't really farm the ancient camp. If they're dawdling,
-- 		they probably have another Radiant hero nearby."
--
local NUM_ENEMY_PLAYERS

local t_team_players
local t_enemy_players

local slow_data = {}
local fast_data = {}

local t_facts = {
		{-60, -5, 20, nil, LOCATION_TYPE_BOUNTIES, 1},
		{-60, -5, 20, nil, LOCATION_TYPE_POWERUP, 1},
		{165, 175, 190, 180, LOCATION_TYPE_BOUNTIES, 1},
		{110, 118, 125, 120, LOCATION_TYPE_POWERUP, 0.6},
	}

local t_intent_locs = {}

function Intent_RegisterObjectiveLocationType(location, typeOfLoc, value, difficulty)
	
end

local function formulate_behavior_metrics()
	for i=1,NUM_ENEMY_PLAYERS do
		local thisEnemy = t_enemy_players[i]
		-- Work out who they are attacking

		-- Work out what, if anything they make an advance on, what might be their objective (incl. fountain retreat, runes, pushing)
		
		-- Work out if they would retaliate
		
	end
	-- Work out how long it will take for attacked allies to die.
end

-- TODO must efficiently formulate metrics to understand enemy behavior, so we can easily query what is currently the known-or-likely goal of enemy heroes.
function Analytics_RegisterAnalyticsJobDomainToEnemyIntent(job_domain)
	t_team_players = GSI_GetTeamPlayers(TEAM)
	t_enemy_players = GSI_GetTeamPlayers(ENEMY_TEAM)

	NUM_ENEMY_PLAYERS = #t_enemy_players

	job_domain:RegisterJob(
			function(workingSet)
				if workingSet.throttle:allowed() then
					formulate_behavior_metrics()
				end
			end,
			{throttle = Time_CreateThrottle(0.41)},
			"JOB_ENEMY_INTENT_UPDATE"
		)

	Analytics_RegisterAnalyticsJobDomainToEnemyIntent = nil
end

-- TODO
-- Returns the probability an enemy will sit and farm a wave
function Analytics_EnemyBusyWithCreepWave(gsiPlayer)
	local nearbyAlliedCreeps = Set_GetNearestAlliedCreepToLocation(gsiPlayer.lastSeen.location)


end
