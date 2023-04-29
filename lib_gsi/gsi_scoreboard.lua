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

local swing_game_factor = 0

local average_team_level
local average_enemy_level

local t_heroes_recently_killed = {}
local function process_any_kills_for_winning(anyTeamFraggers, anyEnemyFraggers)
	local comparitiveFactor = 1 -- A multiplier of the normal value added
	-- Do net worth stuff
	local teamHeroAvgLevel = GSI_GetTeamAverageLevel(TEAM)
	local enemyHeroAvgLevel = GSI_GetTeamAverageLevel(ENEMY_TEAM)
	average_team_level = teamHeroAvgLevel
	average_enemy_level = enemyHeroAvgLevel
	local swingGameFactor = swing_game_factor
	for i=#t_heroes_recently_killed,1,-1 do
		local thisHero = table.remove(t_heroes_recently_killed)
		local thisHeroIsTeam = thisHero.team == TEAM
		-- Check net worthish TODO
		local comparesTheirTeam = (thisHeroIsTeam
				and teamHeroAvgLevel or enemyHeroAvgLevel) - thisHero.level
		comparesTheirTeam = 1 + 0.075*comparesTheirTeam
		comparesTheirTeam = min(1.5, max(0.67, comparesTheirTeam))
		local swungTeamGotAKill = swingGameFactor == 0 and true
				or swingGameFactor > 0 and not thisHeroIsTeam
				or swingGameFactor < 0 and thisHeroIsTeam
		local addSwingGameFactor = swungTeamGotAKill and 1.25/(8+8*math.abs(swingGameFactor)^3)
				or 0.3125 - 1.25/(8+8*math.abs(swingGameFactor)^3)
		swingGameFactor = swingGameFactor
				+ comparitiveFactor
					* (thisHeroIsTeam and -addSwingGameFactor or addSwingGameFactor)
	end
	if not first_blood_taken then
		swingGameFactor = swingGameFactor + (anyTeamFraggers and TEAM_IS_RADIANT and 0.05 or -0.05) -- good enough
		first_blood_taken = true
	end
	swing_game_factor = swingGameFactor
end

local function update_scoreboard_and_killstreaks__job(workingSet)
	if workingSet.throttle:allowed() then
		local anyDireKills = false
		local anyRadiantKills = false
		local heroesRecentlyKilledTbl = t_heroes_recently_killed
		for playerID,playerScoreboard in pairs(scoreboard) do -- If any kills occured in the last throttle timer, consider dead heros to have lost their killstreak. (The odds that a hero dies in the same 0.166667s is very low, the odds that death was caused by rosh, neutral or 20s without successful aggression into building killing blow are probably lower)
			playerScoreboard.prevKills = playerScoreboard.kills
			playerScoreboard.kills = GetHeroKills(playerID)
			
			local thisPlayerKillsIncreased = playerScoreboard.kills - playerScoreboard.prevKills
			if thisPlayerKillsIncreased > 0 then
				playerScoreboard.killstreak = playerScoreboard.killstreak + thisPlayerKillsIncreased
				if playerScoreboard.team == TEAM_RADIANT then
					anyRadiantKills = not anyRadiantKills and 1 or anyRadiantKills + 1
				else
					anyDireKills = not anyDireKills and 1 or anyRadiantKills + 1
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
				table.insert(heroesRecentlyKilledTbl, GSI_GetPlayerFromPlayerID(playerID))
				playerScoreboard.killstreak = 0
			end
		end
		local teamGotKills = anyRadiantKills and TEAM_IS_RADIANT
				or anyDireKills and not TEAM_IS_RADIANT
		if teamGotKills then
			Analytics_AllowDangerLevelPlummets()
		end
		if anyRadiantKills or anyDireKills then
			if TEAM_IS_RADIANT then
				process_any_kills_for_winning(anyRadiantKills, anyDireKills)
			else
				process_any_kills_for_winning(anyDireKills, anyRadiantKills)
			end
			INFO_print("[scoreboard] %s team heat: %s", TEAM_IS_RADIANT and "Radiant" or "Dire", swing_game_factor)
		end
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

local advantage_expires = 0
local ADVANTAGE_EXPIRES_TIME = 1.01
local advantage = 0
-------- GSI_GetAliveAdvantageFactor()
function GSI_GetAliveAdvantageFactor()
	-- Range -1 <> 1
	if advantage_expires > DotaTime() then
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
	advantage_expires = DotaTime() + ADVANTAGE_EXPIRES_TIME
	return advantage
end

local winning_factor
local WINNING_EXPIRES_TIME = 1.21
local winning_expires = 0
-------- GSI_GetWinningFactor()
function GSI_GetWinningFactor()
	if winning_expires > GameTime() then
		
		return winning_factor, average_team_level, average_enemy_level
	end
	local winningFactor = 0
	local teamPlayers = t_team_players
	local enemyPlayers = t_enemy_players
	local teamKDA = 0
	local enemyKDA = 0
	average_team_level = GSI_GetTeamAverageLevel(TEAM)
	average_enemy_level = GSI_GetTeamAverageLevel(ENEMY_TEAM)

--	for i=1,#teamPlayers do
--tmp
--		teamKDA = teamKDA + 
--	end
	winning_factor = swing_game_factor --[[stuff]]
	winning_expires = GameTime() + WINNING_EXPIRES_TIME
	
	return winningFactor, average_team_level, average_enemy_level
end
Analytics_GetWinningFactor = GSI_GetWinningFactor

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
