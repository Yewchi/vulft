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

local Set_GetAlliedHeroesInPlayerRadius = Set_GetAlliedHeroesInPlayerRadius
local Analytics_GetKnownTheorizedEngageables
local min = math.min
local max = math.max
local sqrt = math.sqrt
local abs = math.abs

local BASIC_ONE_LEVEL_OVER_POWER = 1/5 -- On average how much more powerful a player of one level higher is than another

local function game_state_sensibility(nearbyHeroes, dangerLevel)
	
end

function Analytics_GetPowerLevel(gsiPlayer, kda) -- TODO Needs AFK core and jungler consideration
	-- TODO mana, ability types
	--[[DEV]]if TEST and not gsiPlayer.level then ERROR_print(string.format("[power_level] Hero without level T%d PT%d %s", TEAM, gsiPlayer.team or -0, gsiPlayer.shortName or "none")) Util_TablePrint(gsiPlayer) print(debug.traceback()) end
	local powerLevel = min(0.67,
			max(1.65,	
					kda or GSI_GetKDA(gsiPlayer)
				)
			) * (1+gsiPlayer.level*BASIC_ONE_LEVEL_OVER_POWER)
			* max(0.143, gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth)
			* (0.775
					+ 0.225 * (gsiPlayer.lastSeenMana and max(0, (gsiPlayer.lastSeenMana / gsiPlayer.maxMana))
							or 1
						)
				)
	if gsiPlayer.modPowerLevel then
		return gsiPlayer.modPowerLevel(gsiPlayer, powerLevel)
	end
	return powerLevel
end
local GetPowerLevel = Analytics_GetPowerLevel

local false_pub_stomper = {lastSeenHealth = 2000, maxHealth = 2000}
function Analytics_GetPerfectKDAPowerLevel(level)
	false_pub_stomper.level = level
	return GetPowerLevel(false_pub_stomper, 10)
end

function Analytics_RegisterGetKnownTheorizedEngageablesToPowerLevel(getKnownTheorizedEngageables)
	Analytics_GetKnownTheorizedEngageables = getKnownTheorizedEngageables
	Analytics_RegisterGetKnownTheorizedEngageablesToPowerLevel = nil
end

function Analytics_GetRelativePowerLevelCombined(gsiPlayer, playerList)
-- Mimics
	local powerLevel = 0
	for i=1, #playerList do
		powerLevel = powerLevel + GetPowerLevel(playerList[i])
	end
	return powerLevel / Analytics_GetPowerLevel(gsiPlayer)
end

local DEFAULT_PLUMMET_ALLOWED = 0.16667
local plummets_allowed = false
local end_plummets = 0
function Analytics_AllowDangerLevelPlummets(time)
	end_plummets = time or DEFAULT_PLUMMET_ALLOWED
	plummets_allowed = true
end

local dangerBackup = {} for i=1,TEAM_NUMBER_OF_PLAYERS do dangerBackup[i] = 0 end
function Analytics_GetTheoreticalDangerAmount(gsiPlayer, nearbyAllies, location)
-- Mimics
	local allowCache = nearbyAllies == nil and location == nil
	if allowCache and gsiPlayer.time.data.theorizedDanger then
		if DEBUG then
			DebugDrawText(450 - (TEAM_IS_RADIANT and 190 or 0), 550+(gsiPlayer.nOnTeam*15),
				string.format("%d %.2f, %.2f, %d, %d, %.2f",
					gsiPlayer.nOnTeam,
					gsiPlayer.time.data.theorizedDanger or -0,
					GetPowerLevel(gsiPlayer),
					gsiPlayer.time.data.knownEngageables and #(gsiPlayer.time.data.knownEngageables) or -0,
					gsiPlayer.time.data.theorizedEngageables and #(gsiPlayer.time.data.theorizedEngageables) or -0,
					gsiPlayer.time.data.theorizedAggressorAmount and gsiPlayer.time.data.theorizedAggressorAmount or -0
				), 255, 255, allowCache and 255 or 0)
		end
		local timeData = gsiPlayer.time.data
		return timeData.theorizedDanger, timeData.knownEngageables, timeData.theorizedEngageables
	end

	nearbyAllies = nearbyAllies or Set_GetAlliedHeroesInPlayerRadius(gsiPlayer, 4000)
	local nearbyEnemies = Set_GetEnemyHeroesInPlayerRadius(gsiPlayer, 4000)
	local playerPower = GetPowerLevel(gsiPlayer)
	local knownEngageables, theorizedEngageables, theorizedDangerAmount
			= Analytics_GetKnownTheorizedEngageables(gsiPlayer, location) -- TIMEDATA known/theorizedEngables set
	theorizedDangerAmount = theorizedDangerAmount * playerPower -- Reverse the mimic score to raw power of enemies
	if DEBUG and DEBUG_IsBotTheIntern() then
		print("THEORETICAL DANGER CHECK", theorizedDangerAmount)
	end
	--local theorizedDangerAmount = 0
	local playerLoc = gsiPlayer.lastSeen.location
	for i=1, #nearbyEnemies do
		local thisEnemy = nearbyEnemies[i]
		theorizedDangerAmount = theorizedDangerAmount + GetPowerLevel(thisEnemy)
				/ sqrt(max(1, (Vector_PointDistance2D(thisEnemy.lastSeen.location, playerLoc)-900)/900))
	end
	local nearbyEnemyTower = Set_GetNearestTeamTowerToPlayer(ENEMY_TEAM, gsiPlayer)
	local nearbyTeamTower = Set_GetNearestTeamTowerToPlayer(TEAM, gsiPlayer)
	if DEBUG and DEBUG_IsBotTheIntern() then
		print('enemy power', theorizedDangerAmount)
	end
	if nearbyEnemyTower then 
		local enemyDangerTowerFactor = 1.2 - sqrt(0.00005
			* max(0, (Vector_PointDistance2D(playerLoc, nearbyEnemyTower.lastSeen.location) - 0.035))
		)
		theorizedDangerAmount = theorizedDangerAmount * max(0.91, enemyDangerTowerFactor)
	end
	if DEBUG and DEBUG_IsBotTheIntern() then
		print(theorizedDangerAmount)
	end
	local alliedPower = 0
	for i=1, #nearbyAllies do
		local thisAllied = nearbyAllies[i]
		alliedPower = alliedPower + GetPowerLevel(thisAllied)
				/ sqrt(max(1, (Vector_PointDistance2D(thisAllied.lastSeen.location, playerLoc)-900)/900))
	end
	alliedPower = alliedPower + playerPower
	if DEBUG and DEBUG_IsBotTheIntern() then
		print("allied power", alliedPower)
	end
	alliedPower = alliedPower * max(1, sqrt(playerPower / (alliedPower / (1+#nearbyAllies))))
	if DEBUG and DEBUG_IsBotTheIntern() then
		print(alliedPower)
	end
	if nearbyTeamTower then
		local teamSafetyTowerFactor = 1.2 - sqrt(0.00005
				* max(0, (Vector_PointDistance2D(playerLoc, nearbyTeamTower.lastSeen.location) - 0.02))
			)
		alliedPower = alliedPower * max(0.9, teamSafetyTowerFactor)
	end
	if DEBUG and DEBUG_IsBotTheIntern() then
		print(alliedPower)
	end
	theorizedDangerAmount = theorizedDangerAmount - alliedPower
	if DEBUG and DEBUG_IsBotTheIntern() then
		print('pre shift', theorizedDangerAmount)
	end
	theorizedDangerAmount = theorizedDangerAmount < 0 and -sqrt(abs(theorizedDangerAmount))
			or sqrt(theorizedDangerAmount + 0.0001)
	if DEBUG and DEBUG_IsBotTheIntern() then
		print('pre shift', theorizedDangerAmount)
	end
	if allowCache then
		local backupDangerAmount = dangerBackup[gsiPlayer.nOnTeam]
		if not (backupDangerAmount < theorizedDangerAmount or plummets_allowed) then
			--print("SLOWED DANGER", theorizedDangerAmount, backupDangerAmount)
			theorizedDangerAmount = backupDangerAmount
					- (backupDangerAmount - theorizedDangerAmount)/6
			--print(theorizedDangerAmount)
			if end_plummets < GameTime() then
				-- NB bots may do a plummet allowed a different amount of times
				-- 		to another bot.
				plummets_allowed = false
			end
		end
		dangerBackup[gsiPlayer.nOnTeam] = theorizedDangerAmount
		gsiPlayer.time.data.theorizedDanger = theorizedDangerAmount
		gsiPlayer.time.data.cacheSetAllies = nearbyAllies
	end
	return theorizedDangerAmount, knownEngageables, theorizedEngageables
end

function Analytics_GetTheoreticalEncounterPower(heroList, location, startExcludeDist, fullExcludeDist)
	local totalPower = 0
	if not heroList or #heroList == 0 then return 0 end
	local middleExcludeDist = (startExcludeDist+fullExcludeDist)/2
	local range = fullExcludeDist - startExcludeDist
	local halfRange = range/2
	for i=1,#heroList do
		local thisHero = heroList[i]
		local dist = Math_PointToPointDistance2D(thisHero.lastSeen.location, location)
				/ (1 + (GameTime() - thisHero.lastSeen.timeStamp)/10)
		local factorIncluded = dist < startExcludeDist and 0.95
				or (dist < middleExcludeDist and 0.6 + 0.35*(halfRange - dist + startExcludeDist)/halfRange) 
				or 0.6*max(0, (range - dist + middleExcludeDist)/halfRange)
		--print(thisHero.shortName, "has factor for encounter power", factorIncluded)
		totalPower = totalPower + factorIncluded*Analytics_GetPowerLevel(thisHero)
	end
	return totalPower
end

local average_team_level = {}
local average_level_expires = 0
local AVERAGE_LEVEL_TIMEOUT = 5
local function update_average_team_level(team)
	local teamPlayers = GSI_GetTeamPlayers(team)
	local numTeamPlayers = #teamPlayers
	local totalLevels = 0
	for i=1,numTeamPlayers do
		totalLevels = totalLevels + teamPlayers[i].level
	end
	average_team_level[team] = totalLevels / numTeamPlayers
end
function Analytics_GetAverageTeamLevel(team)
	if GameTime() > average_level_expires then
		update_average_team_level(TEAM)
		update_average_team_level(ENEMY_TEAM)
		average_level_expires = GameTime() + AVERAGE_LEVEL_TIMEOUT
	end
	return average_team_level[team]
end

function Analytics_GetMostDangerousEnemy(gsiPlayer, enemiesTbl)
	local highestPower = 0
	local highestEnemy
	for i=1,#enemiesTbl do
		local thisPower = GetPowerLevel(enemiesTbl[i])
		if thisPower > highestPower then
			highestPower = thisPower
			highestEnemy = enemiesTbl[i]
		end
	end
	return highestEnemy
end
