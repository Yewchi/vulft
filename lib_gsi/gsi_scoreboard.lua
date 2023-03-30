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

local min = math.min
local max = math.max

local scoreboard = {}
local first_blood_taken = false
local job_domain

local t_team_players
local t_enemy_players

local function update_scoreboard_and_killstreaks__job(workingSet)
	if workingSet.throttle:allowed() then
		local anyDireKills = false
		local anyRadiantKills = false
		for playerID,playerScoreboard in pairs(scoreboard) do -- If any kills occured in the last throttle timer, consider dead heros to have lost their killstreak. (The odds that a hero dies in the same 0.166667s is very low, the odds that death was caused by rosh, neutral or 20s without successful aggression into building killing blow are probably lower)
			playerScoreboard.prevKills = playerScoreboard.kills
			playerScoreboard.kills = GetHeroKills(playerID)
			
			local thisPlayerKillsIncreased = playerScoreboard.kills - playerScoreboard.prevKills
			if thisPlayerKillsIncreased > 0 then
				playerScoreboard.killstreak = playerScoreboard.killstreak + thisPlayerKillsIncreased
				if playerScoreboard.team == TEAM_RADIANT then
					anyRadiantKills = true
				else
					anyDireKills = true
				end
			end
			
			playerScoreboard.assists = GetHeroAssists(playerID)
		end
		for playerID,playerScoreboard in pairs(scoreboard) do
			local playerScoreboard = scoreboard[playerID]
			playerScoreboard.prevDeaths = playerScoreboard.deaths
			playerScoreboard.deaths = GetHeroDeaths(playerID)
			if playerScoreboard.deaths > playerScoreboard.prevDeaths and (
					(playerScoreboard.team == TEAM_RADIANT and anyDireKills) or  
					(playerScoreboard.team == TEAM_DIRE and anyRadiantKills) ) then 
				playerScoreboard.killstreak = 0
			end
		end
		if anyRadiantKills and TEAM_IS_RADIANT
				or anyDireKills and not TEAM_IS_RADIANT then
			Analytics_AllowDangerLevelPlummets()
		end
		first_blood_taken = first_blood_taken or anyDireKills or anyRadiantKills
	end
end

local function initialize_team_scoreboard(playerList)
	for i=1,#playerList do
		local thisPlayerID = playerList[i]
		scoreboard[thisPlayerID] = {}
		scoreboard[thisPlayerID].kills = GetHeroKills(thisPlayerID)
		scoreboard[thisPlayerID].deaths = GetHeroDeaths(thisPlayerID)
		scoreboard[thisPlayerID].assists = GetHeroAssists(thisPlayerID)
		scoreboard[thisPlayerID].killstreak = 0 -- Yet to find a way to deduce this on load ---- moving on
		scoreboard[thisPlayerID].team = GetTeamForPlayer(playerList[i])
	end
end

function GSI_InitializeScoreboard()
	initialize_team_scoreboard(GetTeamPlayers(TEAM))
	initialize_team_scoreboard(GetTeamPlayers(ENEMY_TEAM))
end

function GSI_GetKDA(gsiPlayer)
	local playerScoreboard = scoreboard[gsiPlayer.playerID]
	if not gsiPlayer.hUnit then
		return 1;
	end
	if playerScoreboard == nil then WARN_print( string.format("[scoreboard]: ...scoreboard not initlialized. %d %s \n\t%s\n\t%s",
				gsiPlayer.playerID or -1, gsiPlayer.shortName or "",
				Util_PrintableTable(scoreboard, 3), Util_PrintableTable(gsiPlayer, 3) )
		)
		return 1;
	end
	return (playerScoreboard.kills*0.88 + 0.45*playerScoreboard.assists) / max(1, playerScoreboard.deaths) -- TODO address assist bloat into KDA metrics that expect an average KDA of 1.0
end

function GSI_FirstBloodTaken()
	return first_blood_taken
end

function GSI_KillstreakGold(thisPlayer)
	return (scoreboard[thisPlayer.playerID].killstreak >= 3 and min(scoreboard[thisPlayer.playerID].killstreak, 10.0)*35 - 5 or 0.0)
end

function GSI_KillstreakXP(thisPlayer)
	return (scoreboard[thisPlayer.playerID].killstreak >= 3 and min(scoreboard[thisPlayer.playerID].killstreak, 10.0)*10*GetHeroLevel(thisPlayer.playerID) or 0.0)
end

local next_update_advantage = 0
local advantage = 0
function GSI_GetAliveAdvantageFactor()
	-- Range -1 <> 1
	if next_update_advantage > DotaTime() then
		return advantage
	end
	local teamAlive = 0
	local enemyAlive = 0
	for i=1,#t_team_players do
		if IsHeroAlive(t_team_players[i].playerID) then
			teamAlive = teamAlive + 1
		end
	end
	for i=1,#t_enemy_players do
		if IsHeroAlive(t_enemy_players[i].playerID) then
			enemyAlive = enemyAlive + 1
		end
	end
	advantage = teamAlive >= enemyAlive and (teamAlive > 0 and 1-(enemyAlive/teamAlive) or -1)
			or (enemyAlive > 0 and -1+(teamAlive/enemyAlive) or 1)
	next_update_advantage = DotaTime()+1.01
	return advantage
end

function GSI_CreateUpdateScoreboardAndKillstreaks()
	job_domain:RegisterJob(
			update_scoreboard_and_killstreaks__job,
			{["throttle"] = Time_CreateThrottle(0.166667)},
			"JOB_UPDATE_SCOREBOARD_AND_KILLSTREAKS"
		)
end

function GSI_RegisterGSIJobDomainToScoreboard(jobDomain)
	t_team_players = GSI_GetTeamPlayers(TEAM)
	t_enemy_players = GSI_GetTeamPlayers(ENEMY_TEAM)
	job_domain = jobDomain
end
