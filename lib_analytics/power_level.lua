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

local CRAZY_VERBOSE = VERBOSE and false

local BASIC_ONE_LEVEL_OVER_POWER = 1/5 -- On average how much more powerful a player of one level higher is than another

local highHealthFactor = 1100
function Analytics_GetPowerLevel(gsiPlayer, kda, notRelative) -- TODO Needs AFK core and jungler consideration
	-- TODO mana, ability types
	
	local healthFactor
	local physicalTaken = gsiPlayer.armor or 2 + gsiPlayer.level * 0.33
	physicalTaken = (1 - 0.035*physicalTaken/(1+0.06*physicalTaken)) -- halfed (upwards)
	local doesntEvade = gsiPlayer.evasion and (1 - gsiPlayer.evasion/2) or 0
	local magicTaken = gsiPlayer.magicTaken and 0.5 + gsiPlayer.magicTaken/2 or 0.875
	local healthPercFactor = 0.8 + 0.2*gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth
	if notRelative then
		healthFactor = healthPercFactor -- lazy incorporate hero design
				* ( gsiPlayer.lastSeenHealth/1024 -- ALL co-factors to this; 1024
					* (1 - physicalTaken * doesntEvade * magicTaken)
					/ sqrt(gsiPlayer.maxHealth)
				)^(1/2)
	else
		healthFactor = healthPercFactor -- lazy incorporate hero design
				* gsiPlayer.lastSeenHealth -- ALL co-factors to this
					* (1 - physicalTaken * doesntEvade * magicTaken)
					/ sqrt(gsiPlayer.maxHealth) -- incorporate the design of the hero, by lazy magic TODO
		highHealthFactor = highHealthFactor
				+ (healthFactor - highHealthFactor)
					* (healthFactor > highHealthFactor and 0.15 or 0.025)
		healthFactor = healthFactor / highHealthFactor + (healthFactor/1024)^(1/2) -- 1024
	end
	local powerLevel = min(0.67,
			max(1.65,	
					kda or GSI_GetKDA(gsiPlayer)
				)
			) * (1+gsiPlayer.level*BASIC_ONE_LEVEL_OVER_POWER)
			* max(0.143, healthFactor)
			* (0.775
					+ (0.125+0.1*healthPercFactor)
						* (gsiPlayer.lastSeenMana and max(0, (gsiPlayer.lastSeenMana / gsiPlayer.maxMana))
							or 1
						)
				)
	powerLevel = gsiPlayer.modPowerLevel and gsiPlayer.modPowerLevel(gsiPlayer, powerLevel)
			or powerLevel
	gsiPlayer.lastSeen.powerLevel = powerLevel
	if string.find(tostring(highHealthFactor), "nan") then highHealthFactor = 1100 if DEBUG then DEBUG_PrintUntilErroredNone(gsiPlayer) Util_ThrowError() end end
	return powerLevel
end
local GetPowerLevel = Analytics_GetPowerLevel

local false_player = {
		lastSeen = {},
		lastSeenHealth = 700,
		maxHealth = 700,
		level = 1
	}
function Analytics_GetPerfectKDAPowerLevel(level)
	false_player.level = level
	false_player.lastSeenHealth = 650 + 50 * level
	false_player.maxHealth = false_player.lastSeenHealth
	

	return GetPowerLevel(false_player, 10, true)
end

function Analytics_GetKDAPowerLevel(level, kda)
	false_player.level = level
	false_player.lastSeenHealth = 650 + 50 * level
	false_player.maxHealth = false_player.lastSeenHealth

	return GetPowerLevel(false_player, kda, true)
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
	--local lowestEhp = 1-(0.06*hUnit:GetArmor()/(1+0.06*unitArmor))
	--local lowestEhpPlayer = gsiPlayer
	local nearbyEnemies = Set_GetEnemyHeroesInPlayerRadius(gsiPlayer, 4000)
	local playerPower = GetPowerLevel(gsiPlayer)
	local knownEngageables, theorizedEngageables, theorizedDangerAmount
			= Analytics_GetKnownTheorizedEngageables(gsiPlayer, location) -- TIMEDATA known/theorizedEngables set
	theorizedDangerAmount = theorizedDangerAmount * playerPower -- Reverse the mimic score to raw power of enemies
	
	--local theorizedDangerAmount = 0
	local playerLoc = gsiPlayer.lastSeen.location
	-- TODO YOU FEEL ASLEEP HARD ON THE DESK TRYIN TO FIX THIS GOODNIGHT
	for i=1,#nearbyEnemies do
		-- Process true enemies
		local thisEnemy = nearbyEnemies[i]
		theorizedDangerAmount = theorizedDangerAmount + GetPowerLevel(thisEnemy)
				/ sqrt(max(1, (Vector_PointDistance2D(thisEnemy.lastSeen.location, playerLoc)-900)/900))
	end
	if #knownEngageables < ENEMY_TEAM_NUMBER_OF_PLAYERS and #nearbyEnemies > 0 then
		-- because 'consider known' from fow_logic
		local kIndex = 1
		while(kIndex < #knownEngageables) do
			-- get the enemies we didn't process due to fog
			local thisEnemy = knownEngageables[i]
			local i=1
			repeat
				if i>#nearbyEnemies then
					local hpp = thisEnemy.lastSeenHealth/thisEnemy.maxHealth
					theorizedDangerAmount = theorizedDangerAmount + (thisEnemy.lastSeen.powerLevel
								or 0.5+0.5*hpp+BASIC_ONE_LEVEL_OVER*thisEnemy.level*(hpp))
							/ sqrt(max(1, (Vector_PointDistance2D(thisEnemy.lastSeen.location, playerLoc)-900)/900))
				end
				if nearbyEnemies[i] == thisEnemy then break; end
				i = i + 1
			until(true)
			kIndex = kIndex + 1
		end
	end
	local nearbyEnemyTower = Set_GetNearestTeamTowerToPlayer(ENEMY_TEAM, gsiPlayer)
	local nearbyTeamTower = Set_GetNearestTeamTowerToPlayer(TEAM, gsiPlayer)
	
	if nearbyEnemyTower then 
		local enemyDangerTowerFactor = 1.2 - sqrt(0.00005
			* max(0, (Vector_PointDistance2D(playerLoc, nearbyEnemyTower.lastSeen.location) - 0.035))
		)
		theorizedDangerAmount = theorizedDangerAmount * max(0.91, enemyDangerTowerFactor)
	end
	
	local alliedPower = 0
	for i=1, #nearbyAllies do
		local thisAllied = nearbyAllies[i]
		alliedPower = alliedPower + GetPowerLevel(thisAllied)
				/ sqrt(max(1, (Vector_PointDistance2D(thisAllied.lastSeen.location, playerLoc)-900)/900))
	end
	alliedPower = alliedPower + playerPower
	
	alliedPower = alliedPower * max(1, sqrt(playerPower / (alliedPower / (1+#nearbyAllies))))
	
	if nearbyTeamTower then
		local teamSafetyTowerFactor = 1.2 - sqrt(0.00005
				* max(0, (Vector_PointDistance2D(playerLoc, nearbyTeamTower.lastSeen.location) - 0.02))
			)
		alliedPower = alliedPower * max(0.9, teamSafetyTowerFactor)
	end
	
	theorizedDangerAmount = theorizedDangerAmount - alliedPower
	
	theorizedDangerAmount = theorizedDangerAmount < 0 and -sqrt(abs(theorizedDangerAmount))
			or sqrt(theorizedDangerAmount + 0.0001)
	
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
