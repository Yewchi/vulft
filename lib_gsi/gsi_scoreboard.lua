local min = math.min

local max = math.max

local scoreboard = {}
local first_blood_taken = false
local job_domain

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
	if playerScoreboard == nil then WARN_print( string.format("[scoreboard]: ...scoreboard not initlialized. %d %s \n\t%s\n\t%s",
				gsiPlayer.playerID or -1, gsiPlayer.shortName or "",
				Util_PrintableTable(scoreboard), Util_TablePrint(gsiPlayer) )
		)
	end
	return (playerScoreboard.kills + 0.88*playerScoreboard.assists) / max(1, playerScoreboard.deaths)
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

function GSI_CreateUpdateScoreboardAndKillstreaks()
	job_domain:RegisterJob(
			update_scoreboard_and_killstreaks__job,
			{["throttle"] = Time_CreateThrottle(0.166667)},
			"JOB_UPDATE_SCOREBOARD_AND_KILLSTREAKS"
		)
end

function GSI_RegisterGSIJobDomainToScoreboard(jobDomain)
	job_domain = jobDomain
end
