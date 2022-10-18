-- The cause of verbosity is due to an "AVAILABLE" rune being an unreliable status
-- - for full-takeover bots (we cannot pickup an old rune, if the minute 0:00 river
-- - bounties are not picked up before bot_generic handover, they can never be picked
-- - up). Additionally, complex task allocation and safety / contest code from wanted
-- - posters.
local PRIORITY_UPDATE_RUNES = 2.039

RUNE_LOCATIONS = {} -- TODO the indexing on this is very poorly done, needs separation logical to under-hood vals
-- .TEAM_BOUNTY
-- .ENEMY_BOUNTY
-- .NORTH_BOUNTY
-- .SOUTH_BOUNTY
-- .NORTH_POWER
-- .SOUTH_POWER

local PRE_GAME_END_TIME = PRE_GAME_END_TIME
local BOUNTY_RUNE_PREP_TIME = 30
local POWER_RUNE_PREP_TIME = 8 -- Not quite as important
local BOUNTY_SPAWN_INTERVAL = 180

local POWER_SPAWN_INTERVAL = 120

local END_DOUBLE_POWER_RUNES = 360

local SWITCH_BOUNTY_TO_WATER_TIME = 120 - BOUNTY_RUNE_PREP_TIME*1.5
local SWITCH_WATER_TO_POWER_TIME = 360 - BOUNTY_RUNE_PREP_TIME*1.5

local MAX_BOUNTY_RUNES = 2 -- TODO Fix when RUNE_BOUNTY_3 and RUNE_BOUNTY_4 are fixed for locations in API
local MAX_POWER_RUNES = 2 -- TODO internal broken?
local POWERS_MIN = 0
local POWERS_MAX = 1
local SAFE_BOUNTIES_MIN = 2
local SAFE_BOUNTIES_MAX = 3
local BOUNTIES_MIN = 2
local BOUNTIES_MAX = 5
local I_POWERS_MIN = 1
local I_POWERS_MAX = 2
local I_BOUNTIES_MIN = 3
local I_BOUNTIES_MAX = 4
local BOUNTY_RUNE_GLOBAL_OBJ_PRE = "RUNE_BOUNTY_" -- TODO Internal invalid? power and bounty share 0&1
local POWER_RUNE_GLOBAL_OBJ_PRE = "RUNE_POWERUP_"

local RUNE_T__BOUNTY = 1
local RUNE_T__POWER = 2

local START_DEFENSE_PROXIMITY = 1600

local BOUNTY_RUNE_IMAGINARY_RADIUS = 600
local POWER_RUNE_IMAGINARY_RADIUS = 600 -- TODO can't remember what this means, make sure value is right

local ABANDON_FAR_COMMIT_DIST_WHEN_SAFE = 1300
local ABANDON_FAR_COMMIT_DANGER_WHEN_SAFE = 0

local DEBUG = DEBUG
local VERBOSE = VERBOSE
local TEST = TEST

local WP_POSTER_TYPES = WP_POSTER_TYPES
local WP_COMMIT_TYPES = WP_COMMIT_TYPES
local POSTER_I = POSTER_I
local WP_CommitIsInterest = WP_CommitIsInterest
local Math_PointToPointDistance2D = Math_PointToPointDistance2D
local Item_UseBottleIntelligently = Item_UseBottleIntelligently
local HIGH_32_BIT = HIGH_32_BIT
local RUNE_STATUS_UNKNOWN = RUNE_STATUS_UNKNOWN
local RUNE_STATUS_AVAILABLE = RUNE_STATUS_AVAILABLE
local RUNE_STATUS_MISSING = RUNE_STATUS_MISSING
local RUNE_STATUS_AWAITING_INFORM = math.max(RUNE_STATUS_UNKNOWN, RUNE_STATUS_AVAILABLE, RUNE_STATUS_MISSING) + 1
local BOTTLE_CHARGE_VALUE = VALUE_OF_ONE_HEALTH * BOTTLE_BASIC_HEALTH_GAIN + VALUE_OF_ONE_MANA * BOTTLE_BASIC_MANA_GAIN
local ITEM_NOT_FOUND = ITEM_NOT_FOUND
local TEAM_FOUNTAIN = Map_GetTeamFountainLocation()
local THROTTLED_BOUNDED = Math_GetFastThrottledBounded
local GetRuneStatus = GetRuneStatus
local GetRuneSpawnLocation = GetRuneSpawnLocation
local max = math.max
local min = math.min

local RECHARGED_BOTTLE_CHARGES = 3

local RUNE_LOCATIONS = RUNE_LOCATIONS

--[[search: RUNE_I___FAST]]
local RUNE_I__LOC = 1
local RUNE_I__HANDLE = 2
local RUNE_I__STATUS = 3
local RUNE_I__WANTED_POSTER = 4
local RUNE_I__NEXT_SPAWN_TIME = 5
local RUNE_I__PRESUMED_UNOBTAINABLE = 6
local RUNE_I__WHILE_WAITING_TEST_PICKUP = 7
local RUNE_I__CLOSEST_SAFE_HERO = 8
local RUNE_I__ENEMY_MISSING_TIME = 9
local RUNE_I__ODDS_AVAILABLE = 10

local fast_data = {}

local blueprint

local t_team_members
local t_enemy_members

local task_handle = Task_CreateNewTask()

local zone_defend_run

local BOUNTY_PRE_TEAM_GOLD = 40*5
local BOUNTY_POST_TEAM_GOLD = 36*5
local BOUNTY_INTERVAL_TEAM_GOLD = 9*5
local bounty_rune_basic_value = 0
local POWER_RUNE_BASIC_VALUE = 250
local set_bounty_rune_value = function() 
		bounty_rune_basic_value = DotaTime() < BOUNTY_SPAWN_INTERVAL - BOUNTY_RUNE_PREP_TIME
			and BOUNTY_PRE_TEAM_GOLD
			or BOUNTY_POST_TEAM_GOLD + BOUNTY_INTERVAL_TEAM_GOLD*(DotaTime()/BOUNTY_SPAWN_INTERVAL)
	end
bounty_rune_basic_value = set_bounty_rune_value()

local next_bounty_rune_posters = GameTime() < PRE_GAME_END_TIME-PRIORITY_UPDATE_RUNES*2
		and PRE_GAME_END_TIME-BOUNTY_RUNE_PREP_TIME
		or GameTime() + BOUNTY_SPAWN_INTERVAL - (DotaTime() % BOUNTY_SPAWN_INTERVAL) - BOUNTY_RUNE_PREP_TIME
local next_power_rune_posters = GameTime() < PRE_GAME_END_TIME-PRIORITY_UPDATE_RUNES*2
		and PRE_GAME_END_TIME-BOUNTY_RUNE_PREP_TIME
		or GameTime() + POWER_SPAWN_INTERVAL - (DotaTime() % POWER_SPAWN_INTERVAL) - POWER_RUNE_PREP_TIME
if DEBUG and TEST then
	DEBUG_print(string.format("[rune], %.1f, %.1f, %.1f, %.1f", GameTime(), PRE_GAME_END_TIME, next_bounty_rune_posters,next_power_rune_posters))
end
-- use of bounty prep time for 0:00 runes in power runes is intentional
local future_bounty_posters_waiting = true -- Are we waiting for the next bounty rune pre-spawn?
local future_power_posters_waiting = true

local any_runes_for_consider = false
local reconsider_runes_time = 0xFFFF

local IN_PICKUP_AREA_DIST = 200
local player_pick_up_time_limit = {0xFFFF,0xFFFF,0xFFFF,0xFFFF,0xFFFF}
-------------- check_if_closer_set_rune() -- For Initialization. Each rune location provided by the API is checked against all 4 closest-two locations, eliminated to the closest.
---- E.g. rune closest to Dire fountain is Dire's south bounty. Needs a rework if bounty runes are changed to no longer be deducable by this. TODO
local function check_if_closer_set_rune(fromLoc, currDist, runeNumerical, key)
	local runeHandle = --[[_G[BOUNTY_RUNE_GLOBAL_OBJ_PRE..runeNumerical]] runeNumerical
	local toLoc = GetRuneSpawnLocation(runeHandle)
	local thisDistance = Math_PointToPointDistance2D(fromLoc, toLoc)
	if thisDistance < currDist then
		RUNE_LOCATIONS[key] = {toLoc, runeHandle, GetRuneStatus(runeHandle)}
		if DEBUG then print("rune", key, "==", runeHandle, "numerically", runeNumerical, fromLoc, toLoc, thisDistance) end
		return thisDistance
	end
	return currDist
end

function abandon_wp_quietly_if_ally_close_safe(gsiPlayer, wpHandle)
	local commitTypes = wpHandle[POSTER_I.COMMIT_TYPES]
	local t_team_members = t_team_members
	local closestDist = 0xFFFF
	local closestPlayer
	
	
	
	--[[DEB]]	DEBUG_KILLSWITCH = true
	
	
	local thisRune = RUNE_LOCATIONS[wpHandle[POSTER_I.OBJECTIVE].runeHandle+1]
	if thisRune[RUNE_I__CLOSEST_SAFE_HERO] then
		safeHero = thisRune[RUNE_I__CLOSEST_SAFE_HERO]
		if (safeHero.time.data.theorizedDanger and safeHero.time.data.theorizedDanger
					> ABANDON_FAR_COMMIT_DANGER_WHEN_SAFE + 0.5
				) then
			thisRune[RUNE_I__CLOSEST_SAFE_HERO] = false
		else
			if safeHero == gsiPlayer then
				return false
			end
			return true -- other bot has rune covered
		end
	end
	local objectiveLoc = thisRune[RUNE_I__LOC]
	for i=1,TEAM_NUMBER_OF_PLAYERS do
		if commitTypes[i] == WP_COMMIT_TYPES.COMMIT_BOUNTY then
			local thisPlayer = t_team_members[i]
			local thisDist = Vector_PointDistance2D(thisPlayer.lastSeen.location, objectiveLoc)
			if thisDist < closestDist then
				closestDist = thisDist
				closestPlayer = thisPlayer
			end
		end
	end
	if closestDist < ABANDON_FAR_COMMIT_DIST_WHEN_SAFE then
		local thisDanger = gsiPlayer.time.data.theorizedDanger or Analytics_GetTheoreticalDangerAmount(gsiPlayer)
		if thisDanger < ABANDON_FAR_COMMIT_DANGER_WHEN_SAFE then
			thisRune[RUNE_I__CLOSEST_SAFE_HERO] = closestPlayer
			if gsiPlayer == closestPlayer then
				return false
			end
			return true
		end
	end
	return false
end

local function return_worth_loc(playerLoc, runeLoc)
	local aboveDiagonal = playerLoc.x + playerLoc.y > runeLoc.x + runeLoc.y
	if aboveDiagonal and not TEAM_IS_RADIANT or not aboveDiagonal and TEAM_IS_RADIANT then
		return playerLoc
	else -- e.g. Adjust our safety checking bail location to be the intersection of our path to the fountain and the diagonal parallel to the river ("yoink, bye")
		-- find the slope and constant of the linear function from the player to the fountain
		-- y = ax + C
		local slopeCoefficient = (TEAM_FOUNTAIN.y - playerLoc.y) / (TEAM_FOUNTAIN.x - playerLoc.x)
		local playerToFountainC = playerLoc.y - slopeCoefficient*playerLoc.x
		-- diangonal line seperating teams from bounty location is y = -x + c; c = y + x
		local bountyRuneDiagonalC = runeLoc.y + runeLoc.x
		-- Find intersection -- the slope coefficient of the diagonal is -1
		-- ax + c1 = -x + c2 .'. (a + 1)x = c2 - c1 .'. x = (c2 - c1) / (a + 1)
		local xIntersection = (bountyRuneDiagonalC - playerToFountainC) / (slopeCoefficient + 1)
		--[[DEBUG]]if DEBUG then DebugDrawLine(Vector(-8000, bountyRuneDiagonalC + 8000, 0), Vector(0, bountyRuneDiagonalC, 0), 255, 255, 255) DebugDrawLine(playerLoc, Vector(xIntersection, bountyRuneDiagonalC - xIntersection, 0), 155, 255, 50) end
		return Vector(xIntersection, bountyRuneDiagonalC - xIntersection)
	end
end

local function estimate_time_til_completed(gsiPlayer, objective)
	return Math_PointToPointDistance2D(gsiPlayer.lastSeen.location, objective.lastSeen.location)
end
local function determine_suitable_rune(gsiPlayer)
	local rl = RUNE_LOCATIONS
	local closest_rune_dist = 0xFFFF
	local closest_rune_index = 1
	local bot_loc = gsiPlayer.lastSeen.location
	for i=1,I_POWERS_MAX do
		local rune_dist = Math_PointToPointDistance2D(bot_loc, rl[i][RUNE_I__LOC])
		if rune_dist < closest_rune_dist then
			closest_rune_dist = rune_dist
			closest_rune_index = i
		end
	end
	return closest_rune_index
end
-------------- get_closest_rune_possible()
-- - gets the closest rune and updates rune statuses, used by blueprint.score()
local function get_closest_rune_possible(gsiPlayer, spawnTimeAllowed)
	local closestDist = HIGH_32_BIT
	local closestRune
	local playerLoc = gsiPlayer.lastSeen.location
	local spawnTimeAllowed = spawnTimeAllowed or 14
	local currTime = GameTime()
	--[[RUNE_I___FAST]]
	for i=1,I_BOUNTIES_MAX do
		local thisRune = RUNE_LOCATIONS[i]
		local thisDist = Math_PointToPointDistance2D(thisRune[1], playerLoc)

		-- Update status
		thisRune[RUNE_I__STATUS] = GetRuneStatus(thisRune[RUNE_I__HANDLE])
		if thisRune[RUNE_I__STATUS] == RUNE_STATUS_MISSING then
			thisRune[RUNE_I__PRESUMED_UNOBTAINABLE] = true
			thisRune[RUNE_I__WHILE_WAITING_TEST_PICKUP] = false
		end

		if VERBOSE then print("/VUL-FT/", gsiPlayer.shortName, "CLOSENESS", thisRune[RUNE_I__STATUS], thisRune[RUNE_I__PRESUMED_UNOBTAINABLE], thisRune[RUNE_I__NEXT_SPAWN_TIME], thisDist) end
		if thisRune[RUNE_I__STATUS] ~= RUNE_STATUS_MISSING
				and ( not thisRune[RUNE_I__PRESUMED_UNOBTAINABLE]
					or thisRune[RUNE_I__NEXT_SPAWN_TIME] - spawnTimeAllowed < currTime
				) and thisDist < closestDist then
			closestDist = thisDist
			closestRune = thisRune
		end
	end
	return closestRune, closestDist
end

local Math_ETA = Math_ETA
local Xeta_CostOfTravelToLocation = Xeta_CostOfTravelToLocation
-- Increases the score required if it's likely to be contested. Only for bounties, because power runes aren't worth dying over.
local function get_bounty_rune_required_power_level(runeLocation)
	-- TODO simplistic
	local thisRuneLoc = runeLocation[RUNE_I__LOC]
	local closestHero, rangeToCheck = Set_GetNearestAlliedHeroToLocation(thisRuneLoc)
	local considerEnemies
	if DotaTime() < 100 then
		considerEnemies = GSI_GetTeamPlayers(ENEMY_TEAM)
		rangeToCheck = 0xFFFF
	else
		considerEnemies = Set_GetEnemyHeroesInPlayerRadiusAndOuter(thisRuneLoc, rangeToCheck, 8000, 90) --TODO mgk
		rangeToCheck = closestHero and rangeToCheck+1200 or 6000 -- TODO mgk
	end
	if VERBOSE then print("/VUL-FT/", thisRuneLoc, "BOUNTY POWER REQUIRED:", Analytics_GetTheoreticalEncounterPower(considerEnemies, thisRuneLoc, rangeToCheck/2, rangeToCheck)) end
	return Analytics_GetTheoreticalEncounterPower(considerEnemies, thisRuneLoc, rangeToCheck/2, rangeToCheck)
end
local Positioning_ProjectedRace = Positioning_ProjectedRace
local function score_bounty_rune(gsiPlayer, objective, forTaskComparison, wpHandle)
	-- TODO include scoring around roles / greed.
	-- TODO elswhere Vector_SpontaneousRaceResult(unit, unit, finishLoc, [unit1Loc, [unit2Loc]]);
	-- TODO ProjectedRace needs testing for reliability and how bots will react to enemies in fog, approaching, leaving the bounty area (when the bounty would be/is spawned by the time they get there)
	local bottleSlot = gsiPlayer.hUnit:FindItemSlot("item_bottle")
	local bottleValue = bottleSlot ~= ITEM_NOT_FOUND and max(0, (RECHARGED_BOTTLE_CHARGES - gsiPlayer.hUnit:GetItemInSlot(bottleSlot):GetCurrentCharges())) * BOTTLE_CHARGE_VALUE or 0
	local taskComparisonFactor = 1
	if forTaskComparison then
		local timeTilNextBounties = BOUNTY_SPAWN_INTERVAL - DotaTime() % BOUNTY_SPAWN_INTERVAL
		local preSpawnPeriod = timeTilNextBounties < BOUNTY_RUNE_PREP_TIME + 5
		if preSpawnPeriod then
			local extraTime = max(0, timeTilNextBounties - Math_ETA(gsiPlayer, objective.lastSeen.location))
			if extraTime > 0 then
				taskComparisonFactor = 1/(2^(extraTime/2)) -- Scales 1.0 if we get there just in time, 0.5 if we have 2 extra seconds (often still very high), 0.2 at 5 seconds
			else
				-- scale to beat other enemies to the rune.
				-- TODO there is a relation between very close enemy runners up and low won-by times for indicating highly contested runes. This could help to determine danger of rune
				local lowestTime = 0xFFFF
				local bestCompetitor
				local enemyTeam = GSI_GetTeamPlayers(ENEMY_TEAM)
				for i=1,ENEMY_TEAM_NUMBER_OF_PLAYERS do
					local _, thisWonBy = Positioning_ProjectedRace(gsiPlayer, enemyTeam[i], objective.lastSeen.location, 4) -- see if we win a race to bounty if both bots continue doing what they're doing now for 4 seconds, then race.
					if thisWonBy < lowestTime then 
						lowestTime = thisWonBy
						bestCompetitor = enemyTeam[i]
					end
				end
if DEBUG then
				DebugDrawLine(bestCompetitor.lastSeen.location, gsiPlayer.lastSeen.location, 155, 155, 150)
end
				if lowestTime > 0 then
if DEBUG then
					DebugDrawLine(bestCompetitor.lastSeen.location, gsiPlayer.lastSeen.location, 0, 0, 255)
end
					taskComparisonFactor = 2/(2^(lowestTime/4))
				elseif not Positioning_ProjectedRace(gsiPlayer, bestCompetitor, objective.lastSeen.location, 0) then
if DEBUG then
					DebugDrawLine(bestCompetitor.lastSeen.location, gsiPlayer.lastSeen.location, 255, 0, 0)
end
					-- we might just lose the race so, go if you've got nothing else important to do.
					if DEBUG then
						INFO_print( string.format("[wp] %s is bailing from rune::blueprint.run..() 2 on '%s'",
									gsiPlayer.shortName,
									wpHandle[POSTER_I.OBJECTIVE].name or wpHandle[POSTER_I.OBJECTIVE].shortName
								)
							)
					end
					WP_InformBail(gsiPlayer, wpHandle)
				elseif DEBUG then DebugDrawLine(bestCompetitor.lastSeen.location, gsiPlayer.lastSeen.location, 0, 255, 0) end
			end
		end
	end
	taskComparisonFactor = taskComparisonFactor
	local healthDiff = FightHarass_GetHealthDiffOutnumbered(gsiPlayer)
	local healthPercent = gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth
	if VERBOSE then print("/VUL-FT/", "score_bounty_rune", gsiPlayer.shortName, objective.runeHandle, taskComparisonFactor, bounty_rune_basic_value, (4*gsiPlayer.vibe.greedRating), (1+TOTAL_BARRACKS_TEAM-NUM_BARRACKS_UP_TEAM), Xeta_CostOfTravelToLocation(gsiPlayer, objective.lastSeen.location), (3*(2-healthPercent)), bottleValue, NUM_BARRACKS_UP_TEAM) end
	return taskComparisonFactor
			* RUNE_LOCATIONS[objective.runeHandle+1][RUNE_I__ODDS_AVAILABLE]
			* ( bounty_rune_basic_value
				- 4 * (1 + gsiPlayer.vibe.greedRating)
				* (1 + TOTAL_BARRACKS_TEAM - NUM_BARRACKS_UP_TEAM)
				* Xeta_CostOfTravelToLocation(gsiPlayer, objective.lastSeen.location)*(2-healthPercent)
				* (DotaTime() < 80 and 0.5 or 1)
				+ bottleValue
			)
end
local function score_power_rune(gsiPlayer, objective, forTaskComparison)
	local bottleSlot = gsiPlayer.hUnit:FindItemSlot("item_bottle")
	local bottleValue = bottleSlot ~= ITEM_NOT_FOUND and max(0, (RECHARGED_BOTTLE_CHARGES - gsiPlayer.hUnit:GetItemInSlot(bottleSlot):GetCurrentCharges())) * BOTTLE_CHARGE_VALUE or 0
	local taskComparisonFactor = 1
	if forTaskComparison then
		local timeTilNextPowers = POWER_SPAWN_INTERVAL - DotaTime() % POWER_SPAWN_INTERVAL
		local preSpawnPeriod = timeTilNextPowers-1 < POWER_RUNE_PREP_TIME + 5
		if preSpawnPeriod then
			local extraTime = max(0, timeTilNextPowers - Math_ETA(gsiPlayer, objective.lastSeen.location))
			if extraTime > 0 then
				taskComparisonFactor = 1/(2^(extraTime/2)) -- Scales 1.0 if we get there just in time, 0.5 if we have 2 extra seconds (often still very high), 0.2 at 5 seconds
			else
				-- scale to beat other enemies to the rune.
				-- TODO there is a relation between very close enemy runners up and low won-by times for indicating highly contested runes. This could help to determine danger of rune
				local lowestTime = 0xFFFF
				local bestCompetitor
				local enemyTeam = GSI_GetTeamPlayers(ENEMY_TEAM)
if DEBUG then
				DebugDrawLine(gsiPlayer.lastSeen.location, objective.lastSeen.location, 155, 155, 155)
end
				for i=1,ENEMY_TEAM_NUMBER_OF_PLAYERS do
					local _, thisWonBy = Positioning_ProjectedRace(gsiPlayer, enemyTeam[i], objective.lastSeen.location, 4) -- see if we win a race to bounty if both bots continue doing what they're doing now for 4 seconds, then race.
					if thisWonBy < lowestTime then 
						lowestTime = thisWonBy
						bestCompetitor = enemyTeam[i]
					end
				end
				if lowestTime > 0 then
if DEBUG then
					DebugDrawLine(bestCompetitor.lastSeen.location, gsiPlayer.lastSeen.location, 0, 0, 255)
end
					taskComparisonFactor = 2/(2^(lowestTime/4))
				elseif not Positioning_ProjectedRace(gsiPlayer, bestCompetitor, objective.lastSeen.location, 0) then
if DEBUG then
					DebugDrawLine(bestCompetitor.lastSeen.location, gsiPlayer.lastSeen.location, 255, 0, 0)
end
					-- we might just lose the race so, go if you've got nothing else important to do.
					taskComparisonFactor = 0.15
				elseif DEBUG then DebugDrawLine(bestCompetitor.lastSeen.location, gsiPlayer.lastSeen.location, 0, 255, 0) end
			end
		end
	end
	-- Just don't pick it up if you're too far away, unlike bounty runes which provide immediate team value. Exponential with a 1-factor limit of inverse distance to rune
	local distanceToRune = Math_PointToPointDistance2D(gsiPlayer.lastSeen.location, objective.lastSeen.location)
	if distanceToRune > 800 and distanceToRune < 2000 then
		taskComparisonFactor = taskComparisonFactor *
				(2800 - max(800, distanceToRune)) / 2000
	elseif distanceToRune >= 2000 then
		taskComparisonFactor = taskComparisonFactor *
				(0.4 - max(0.39, (4000 - distanceToRune) / 4000))
	end
	local healthPercent = gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth
	if VERBOSE then print("/VUL-FT/", "score_power_rune", gsiPlayer.shortName, objective.runeHandle, taskComparisonFactor, Xeta_CostOfTravelToLocation(gsiPlayer, objective.lastSeen.location), (1-healthPercent), (TOTAL_BARRACKS_TEAM - NUM_BARRACKS_UP_TEAM), bottleValue) end
	return taskComparisonFactor
			* RUNE_LOCATIONS[objective.runeHandle+1][RUNE_I__ODDS_AVAILABLE]
			* (POWER_RUNE_BASIC_VALUE
				- 1.5 * (TOTAL_BARRACKS_TEAM - NUM_BARRACKS_UP_TEAM)
					* Xeta_CostOfTravelToLocation(gsiPlayer, objective.lastSeen.location)
			+ bottleValue)
end

function Rune_OddsEnemyIsAttemptingRuneGet(gsiPlayer, spawnTimeAllowed)
	local closestRuneToEnemy = get_closest_rune_possible(gsiPlayer, spawnTimeAllowed)

	-- Currently asking for a specific location that is different from a player's location itself
end
local Rune_OddsEnemyIsAttemptingRuneGet = Rune_OddsEnemeyIsAttemptingRuneGet

function Rune_UpdateRuneInformation()
	local rune_locs = RUNE_LOCATIONS
	for i=I_POWERS_MIN,I_BOUNTIES_MAX do
		local thisRuneLoc = rune_locs[i]
		thisRuneLoc[RUNE_I__STATUS] = GetRuneStatus(thisRuneLoc[RUNE_I__HANDLE])
	end
	set_bounty_rune_value()
end
local Rune_UpdateRuneInformation = Rune_UpdateRuneInformation


function Rune_AnyRunesUnknownOrAvailable()
	local any = false
	local rl = RUNE_LOCATIONS
	for i=I_POWERS_MAX,I_BOUNTIES_MAX do
		local thisRuneLoc = rl[i]
		if thisRuneLoc[RUNE_I__STATUS] ~= RUNE_STATUS_MISSING then
			any = true
		end
	end
	return any
end
local Rune_AnyRunesUnknownOrAvailable = Rune_AnyRunesUnknownOrAvailable

local function update_enemy_missing_timestamps()
	local enemies = t_enemy_members
	local runes = RUNE_LOCATIONS
	for i=I_POWERS_MIN,I_BOUNTIES_MAX do
		local thisMissingTimes = runes[i][RUNE_I__ENEMY_MISSING_TIME]
		for iEnemy=1,#enemies do
			thisMissingTimes[iEnemy] = enemies[iEnemy].lastSeen.previousTimeStamp
		end
	end
end
local function update_rune_odds_available(rune)
	if rune[RUNE_I__STATUS] == RUNE_STATUS_AVAILABLE then
		rune[RUNE_I__ODDS_AVAILABLE] = 1
		return;
	end
	local addedDivisorAvailable = 0
	local missingTimes = rune[RUNE_I__ENEMY_MISSING_TIME] 
	local updateInterval = PRIORITY_UPDATE_RUNES
	local enemyPlayers = t_enemy_members
	local addedDivisor = 0
	for i=1,#enemyPlayers do
		local thisEnemy = enemyPlayers[i]
		local pickupLoc = rune[RUNE_I__LOC]
if DEBUG then
		DebugDrawText(1000+thisEnemy.nOnTeam*8, 490, "_", 255, 255, 255)
end
		if missingTimes[i] ~= thisEnemy.lastSeen.previousTimeStamp then -- but was missing in previous run through
			-- In a fresh reveal on the map, add the odds the rune was taken
			-- TODO Rare false-negative when hero flashes in and out of vision since previous run
			local durationMissing = GameTime() - thisEnemy.lastSeen.previousTimeStamp
			local approxTravelDistance = (thisEnemy.currentMovementSpeed * durationMissing)
			-- TODO Ignores movement abilities and items
			local runeIncludedInTravelFit = approxTravelDistance
					/ (Vector_PointDistance2D(thisEnemy.lastSeen.previousLocation, pickupLoc)
							+ Vector_PointDistance2D(pickupLoc, thisEnemy.lastSeen.location)
						)
			if runeIncludedInTravelFit > 0.8 then
if DEBUG then
				DebugDrawText(1000+thisEnemy.nOnTeam*8, 500, "Y", 0, 255, 0)
end
				-- Nipple / small hill in a field shape, 3 meaning 1/3 odds available if perfect fit to rune movement
				-- -| 1/6 odds for two , etc.
				addedDivisor = addedDivisor + 3 / (runeIncludedInTravelFit^2 - 2*runeIncludedInTravelFit + 2)
				if VERBOSE then print("/VUL-FT/", thisEnemy.shortName, "added total:", addedDivisor) end
			elseif DEBUG then
				DebugDrawText(1000+thisEnemy.nOnTeam, 500, "Y", 255, 0, 0)
				if VERBOSE then print("/VUL-FT/ [rune]", thisEnemy.shortName, "ignoring approx distance as low", runeIncludedInTravelFit, approxTravelDistance) end
			end
		end
	end
	rune[RUNE_I__ODDS_AVAILABLE] = 1 / (1/rune[RUNE_I__ODDS_AVAILABLE] + addedDivisor)
end

function Rune_CheckBountySpawnPre()
	local timeTilPosters = next_bounty_rune_posters - GameTime()
	local rl = RUNE_LOCATIONS
	if timeTilPosters > 0 then
		-- Update odds rune is available
		for i=I_BOUNTIES_MIN,I_BOUNTIES_MAX do
			update_rune_odds_available(rl[i])
		end
	end
	--print("Checking bounty rune spawn pre.", timeTilPosters, next_bounty_rune_posters, GameTime(), future_bounty_posters_waiting)
	if timeTilPosters < -BOUNTY_RUNE_PREP_TIME+0.017 then
		next_bounty_rune_posters = next_bounty_rune_posters + BOUNTY_SPAWN_INTERVAL - DotaTime()%BOUNTY_SPAWN_INTERVAL
		--print("Setting next bounty posters to", string.format("%.2f + %d - %.2f", next_bounty_rune_posters, BOUNTY_SPAWN_INTERVAL, DotaTime()%BOUNTY_SPAWN_INTERVAL))
		future_bounty_posters_waiting = true
		for i=I_BOUNTIES_MIN,I_BOUNTIES_MAX do
			local thisWp = rl[i][RUNE_I__WANTED_POSTER]
			if thisWp and not thisWp[POSTER_I.ALLOCATE_PERFORMED] then
				any_runes_for_consider = true
			end
			rl[i][RUNE_I__NEXT_SPAWN_TIME] = next_bounty_rune_posters + BOUNTY_RUNE_PREP_TIME
		end
	elseif future_bounty_posters_waiting and timeTilPosters < 0 then
		for i=I_BOUNTIES_MIN,I_BOUNTIES_MAX do
			local thisRune = rl[i]
			thisRune[RUNE_I__STATUS] = RUNE_STATUS_AWAITING_INFORM 
			thisRune[RUNE_I__PRESUMED_UNOBTAINABLE] = false
			thisRune[RUNE_I__WHILE_WAITING_TEST_PICKUP] = true
			thisRune[RUNE_I__CLOSEST_SAFE_HERO] = nil
			thisRune[RUNE_I__ODDS_AVAILABLE] = 1
			local imaginaryObjective = iObjective_NewImaginarySafeUnit(thisRune[RUNE_I__LOC], BOUNTY_RUNE_IMAGINARY_RADIUS, BOUNTY_RUNE_PREP_TIME+10, "bounty"..thisRune[RUNE_I__HANDLE])
			imaginaryObjective.runeHandle = thisRune[RUNE_I__HANDLE]
			imaginaryObjective.runeType = RUNE_T__BOUNTY
			thisRune[RUNE_I__WANTED_POSTER] = WP_Register(
					WP_POSTER_TYPES.CAPTURE_RUNE,
					task_handle,
					imaginaryObjective,
					imaginaryObjective.lastSeen.location,
					score_bounty_rune,
					nil,
					get_bounty_rune_required_power_level(thisRune)
							* (DotaTime() < 89
								and min(1, 0.33*(Vector_PointDistance2D(thisRune[RUNE_I__LOC], ZEROED_VECTOR)
									/ Vector_PointDistance(ZEROED_VECTOR, GetRuneSpawnLocation(RUNE_POWERUP_1)))^2) -- nb. a static
								or 1
							)
				)
			--print(thisRune[RUNE_I__WANTED_POSTER], "<<<<<<<<<<<< POSTER", i)
		end
		any_runes_for_consider = true
		future_bounty_posters_waiting = false -- returns to true when the pre-spawn period is over, to await next pre
	end
end
local Rune_CheckBountySpawnPre = Rune_CheckBountySpawnPre

function Rune_CheckPowerSpawnPre()
	local timeTilPosters = next_power_rune_posters - GameTime()
	local rl = RUNE_LOCATIONS
	if timeTilPosters > 0 then
		-- Update odds rune is available
		for i=I_POWERS_MIN,I_POWERS_MAX do
			update_rune_odds_available(rl[i])
		end
	end
	if timeTilPosters < -POWER_RUNE_PREP_TIME+0.017 then
		next_power_rune_posters = next_power_rune_posters + POWER_SPAWN_INTERVAL - DotaTime()%POWER_SPAWN_INTERVAL
		future_power_posters_waiting = true
		for i=I_POWERS_MIN,I_POWERS_MAX do
			local thisWp = rl[i][RUNE_I__WANTED_POSTER]
			if thisWp and not thisWp[POSTER_I.ALLOCATE_PERFORMED] then
				any_runes_for_consider = true
			end
			rl[i][RUNE_I__NEXT_SPAWN_TIME] = next_power_rune_posters + POWER_RUNE_PREP_TIME
		end
	elseif future_power_posters_waiting and timeTilPosters < 0 then
		for i=I_POWERS_MIN,I_POWERS_MAX do
			local thisRune = rl[i]
			thisRune[RUNE_I__STATUS] = RUNE_STATUS_AWAITING_INFORM 
			thisRune[RUNE_I__PRESUMED_UNOBTAINABLE] = false
			thisRune[RUNE_I__WHILE_WAITING_TEST_PICKUP] = true
			thisRune[RUNE_I__ODDS_AVAILABLE] = 1
			local imaginaryObjective = iObjective_NewImaginarySafeUnit(thisRune[RUNE_I__LOC], POWER_RUNE_IMAGINARY_RADIUS, POWER_RUNE_PREP_TIME+10, "power"..thisRune[RUNE_I__HANDLE])
			imaginaryObjective.runeHandle = thisRune[RUNE_I__HANDLE]
			imaginaryObjective.runeType = RUNE_T__POWER
			thisRune[RUNE_I__WANTED_POSTER] = WP_Register(
					WP_POSTER_TYPES.CAPTURE_RUNE,
					task_handle,
					imaginaryObjective,
					imaginaryObjective.lastSeen.location,
					DotaTime() > 89 and score_power_rune or score_bounty_rune,
					nil,
					DotaTime() > 89 and 0 or get_bounty_rune_required_power_level(thisRune) -- TODO
				)
			if VERBOSE then print("/VUL-FT/ [rune]", thisRune[RUNE_I__WANTED_POSTER], "<<<<<<<<<<<< POSTER", i) end
		end
		any_runes_for_consider = true
		future_power_posters_waiting = false -- returns to true when the pre-spawn period is over, to await next pre
	end
end
local Rune_CheckPowerSpawnPre = Rune_CheckPowerSpawnPre

local function estimated_time_til_completed(gsiPlayer, objective)
	return 0 -- TODO 
end

-- // Init //
local function task_init_func(taskJobDomain)
	if VERBOSE then VEBUG_print(string.format("rune: Initialized with handle #%d.", task_handle)) end

	t_team_members = GSI_GetTeamPlayers(TEAM)
	t_enemy_members = GSI_GetTeamPlayers(ENEMY_TEAM)

	zone_defend_run = Task_GetTaskRunFunc(ZoneDefend_GetTaskHandle())

	-- - Set up the rune locations dynamically - 
	local bounds = GetWorldBounds()
	local teamBountyCheck = Map_GetLogicalLocation(TEAM == TEAM_RADIANT and MAP_POINT_RADIANT_FOUNTAIN_CENTER or MAP_POINT_DIRE_FOUNTAIN_CENTER)
	local enemyBountyCheck = Map_GetLogicalLocation(TEAM == TEAM_RADIANT and MAP_POINT_DIRE_FOUNTAIN_CENTER or MAP_POINT_RADIANT_FOUNTAIN_CENTER)
	local northBountyCheck = Vector(-1000, 1000) -- Assumes river rune is closer to center-bottom and center-top than team-map-side bounties from 7.30
	local southBountyCheck = Vector(1000, -1000)
	local closestAlliedBounty = HIGH_32_BIT
	local closestEnemyBounty = HIGH_32_BIT
	local mostNorthernRune = HIGH_32_BIT
	local mostSouthernRune = HIGH_32_BIT
	-- Determine the locations of the runes 05/21 Assumes there is a close-to-team-fountain rune and two river runes.
	for i=POWERS_MIN,SAFE_BOUNTIES_MAX do
		closestAlliedBounty = check_if_closer_set_rune(teamBountyCheck, closestAlliedBounty, i, "TEAM_BOUNTY")
		closestEnemyBounty = check_if_closer_set_rune(enemyBountyCheck, closestEnemyBounty, i, "ENEMY_BOUNTY")
		mostNorthernRune = check_if_closer_set_rune(northBountyCheck, mostNorthernRune, i, "NORTH_BOUNTY")
	 	mostSouthernRune = check_if_closer_set_rune(southBountyCheck, mostSouthernRune, i, "SOUTH_BOUNTY")
	end
	local swapTable = {}
	for _,runeLoc in pairs(RUNE_LOCATIONS) do
		swapTable[runeLoc[RUNE_I__HANDLE]+1] = runeLoc -- index bounties to named 1 - 4. TODO BAD
		runeLoc[RUNE_I__NEXT_SPAWN_TIME] = 0
		runeLoc[RUNE_I__ODDS_AVAILABLE] = 0
		local newMissingTimes = {}
		for i=1,#t_enemy_members do
			newMissingTimes[i] = t_enemy_members[i].lastSeen.timeStamp
		end
		runeLoc[RUNE_I__ENEMY_MISSING_TIME] = newMissingTimes
	end
	for i=1,BOUNTIES_MAX+1 do
		RUNE_LOCATIONS[i] = swapTable[i]
	end

	-- - task.lua stuff - 
	Task_RegisterTask(task_handle, PLAYERS_ALL, blueprint.run, blueprint.score, blueprint.init)

	local next_player = 1
	taskJobDomain:RegisterJob(
			function(workingSet)
				if DEBUG then
					DebugDrawText(380, 400, string.format("BconsidT:%.2f", next_bounty_rune_posters-GameTime()), 255, 255, 255)
					DebugDrawText(380, 408, string.format("PconsidT:%.2f", next_power_rune_posters-GameTime()), 255, 255, 255)
					--DebugDrawText(500, 400, "|x,y |status |dotaStatus |wpActive", 255, 255, 255)
					for i=1,4 do
						local thisRuneLoc = RUNE_LOCATIONS[i]
						local thisWp = thisRuneLoc[RUNE_I__WANTED_POSTER]
						local thisLoc = thisRuneLoc[RUNE_I__LOC]
						DebugDrawText(486 + (TEAM_IS_RADIANT and 0 or 216), 391 + i*9,
								string.format("|%5d,%5d |%d |%d |%.1s |%.1s |oddsAvail:%.2f", thisLoc.x, thisLoc.y,
										thisRuneLoc[RUNE_I__STATUS],
										GetRuneStatus(thisRuneLoc[RUNE_I__HANDLE]),
										thisRuneLoc[RUNE_I__PRESUMED_UNOBTAINABLE] or false,
										not thisWp and '?' or thisWp[POSTER_I.ALLOCATE_PERFORMED],
										thisRuneLoc[RUNE_I__ODDS_AVAILABLE]
									),
								255, 255, 255
							)
					end
				end
				if workingSet.throttle:allowed() then
					Rune_UpdateRuneInformation()
					--print("checking bounty spawn pre")
					Rune_CheckBountySpawnPre()
					Rune_CheckPowerSpawnPre()
					update_enemy_missing_timestamps()
					if true or Rune_AnyRunesUnknownOrAvailable() then
						Task_SetTaskPriority(task_handle, PLAYERS_ALL, TASK_PRIORITY_TOP) -- All players consider runes when spawning/spawned
					else
						Task_SetTaskPriority(task_handle, next_player, TASK_PRIORITY_TOP) -- vestigial upkeep of pre-spawn checks??
						Task_RotatePlayerOnTeam(next_player)
					end
				end
			end,
			{["throttle"] = Time_CreateThrottle(PRIORITY_UPDATE_RUNES)},
			"JOB_TASK_SCORING_PRIORITY_RUNES"
		)
	Blueprint_RegisterTaskActivityType(task_handle, ACTIVITY_TYPE["COLLECTING"])
	task_init_func = nil
	check_if_closer_set_rune = nil return task_handle, estimated_time_til_completed
end

Blueprint_RegisterTask(task_init_func)
blueprint = {
	run = function(gsiPlayer, objective, xetaScore) -- TODO Deny the rune if enemy is closer, and projectile speed + attack speed means we kill it before they get to it. It would be a shame to see sniper mid miss the opportunity.
		local wpForBotTask = WP_GetPlayerTaskPoster(gsiPlayer, task_handle) 
		if not wpForBotTask then
			return XETA_SCORE_DO_NOT_RUN
		end
		
		local hasBottle = gsiPlayer.hUnit:FindItemSlot("item_bottle") ~= ITEM_NOT_FOUND -- also used to say you stand closer
		if hasBottle then
			Item_UseBottleIntelligently(gsiPlayer, true)
		end
		
		local wpObjective = wpForBotTask[POSTER_I.OBJECTIVE]
		local typeIsBounty = wpObjective.runeType == RUNE_T__BOUNTY
		local timeTilNextSpawn = typeIsBounty and BOUNTY_SPAWN_INTERVAL - ((DotaTime()-0.5) % BOUNTY_SPAWN_INTERVAL)
				or POWER_SPAWN_INTERVAL - ((DotaTime()-0.5) % POWER_SPAWN_INTERVAL)
		local notPreSpawnPeriod = timeTilNextSpawn-0.5 > (
				typeIsBounty and BOUNTY_RUNE_PREP_TIME
				or POWER_RUNE_PREP_TIME
			)
		local gameUnderway = GameTime() >= PRE_GAME_END_TIME
		local pnot = gsiPlayer.nOnTeam
		local runeAreaVisible = IsLocationVisible(wpObjective.lastSeen.location)

		local playerDistanceToRune = Math_PointToPointDistance2D(gsiPlayer.lastSeen.location, wpObjective.lastSeen.location)
		local adjustedForLossesCutLoc = return_worth_loc(gsiPlayer.lastSeen.location, objective.lastSeen.location)
		local thisRune = RUNE_LOCATIONS[objective.runeHandle+1]
		local tryWaitingAvailablePickups = thisRune[RUNE_I__WHILE_WAITING_TEST_PICKUP]
		--[[print(gsiPlayer.shortName, "checking burn", GameTime(), ">", player_pick_up_time_limit[pnot], (GetRuneStatus(objective.runeHandle) == RUNE_STATUS_MISSING and notPreSpawnPeriod), string.format("%.2f, %.2f",
				(-1 + (gsiPlayer.time.data.theorizedDanger or 0)), (-1 + max( Math_ETAFromLoc(gsiPlayer, adjustedForLossesCutLoc, objective.lastSeen.location), max(1, min(timeTilNextSpawn, BOUNTY_RUNE_PREP_TIME))))))--]]
		if gameUnderway then
			if not notPreSpawnPeriod and GameTime() > player_pick_up_time_limit[pnot]
					and tryWaitingAvailablePickups then
				-- Stop trying to pick up the singular available rune during preSpawn.
				if not alerted_unable_to_pickup_old_runes then
					gsiPlayer.hUnit:ActionImmediate_Chat("Full-takeover bots cannot pickup stacked runes. I'll try to grab the new spawn.", false)
					alerted_unable_to_pickup_old_runes = true
				end
				thisRune[RUNE_I__WHILE_WAITING_TEST_PICKUP] = false
				player_pick_up_time_limit[pnot] = 0xFFFF
			elseif (notPreSpawnPeriod or tryWaitingAvailablePickups) and playerDistanceToRune < IN_PICKUP_AREA_DIST then
				if timeTilNextSpawn < 0.2 then
					-- To avoid a false burn when it spawns
					player_pick_up_time_limit[pnot] = 0xFFFF
				elseif player_pick_up_time_limit[pnot] == 0xFFFF then
					player_pick_up_time_limit[pnot] = GameTime()+0.85
				end
			end
			--print(gsiPlayer.shortName, "game has started")
			if DEBUG then print("/VUL-FT/ [rune]", gsiPlayer.shortName, "waiting rune info", notPreSpawnPeriod, tryWaitingAvailablePickups, GetRuneStatus(objective.runeHandle), runeAreaVisible) end
			if gameUnderway and abandon_wp_quietly_if_ally_close_safe(gsiPlayer, wpForBotTask) then
				return XETA_SCORE_DO_NOT_RUN
			end
			if notPreSpawnPeriod and (
						GameTime() > player_pick_up_time_limit[pnot]
						or (runeAreaVisible and GetRuneStatus(objective.runeHandle) == RUNE_STATUS_MISSING)
					) then -- *^ wrong TODO What, why?
				-- '-1', i.e. ignore the bail if there is 1 sec till spawn, or we are in equal or less danger
				-- essentially, in the 1 danger case, where the enemy and you are equal, there is a tug of war of intent, which is guided by the volatility of the match state for each player.
				-- a late-game death is game-losing, and it shouldn't be given over a known as contested or suspected as contested bounty rune. this is not represented. TODO
				WP_BurnPoster(wpForBotTask)	
				if TEST then print(string.format("%s burns poster because %.2f > %.2f || (%s ? %d : NULL == %d && %s)", gsiPlayer.shortName, GameTime(), player_pick_up_time_limit[pnot], runeAreaVisible, GetRuneStatus(objective.runeHandle), RUNE_STATUS_MISSING, notPreSpawnPeriod)) end
				thisRune[RUNE_I__WANTED_POSTER] = nil
				thisRune[RUNE_I__PRESUMED_UNOBTAINABLE] = true
				gsiPlayer.hUnit:ActionImmediate_Ping(wpObjective.lastSeen.location.x, wpObjective.lastSeen.location.y, false)
				player_pick_up_time_limit[pnot] = 0xFFFF
				return XETA_SCORE_DO_NOT_RUN
			elseif playerDistanceToRune > 400 and ( (-1 + (gsiPlayer.time.data.theorizedDanger or 0))
								* (	-1 + max( Math_ETAFromLoc(gsiPlayer, adjustedForLossesCutLoc, objective.lastSeen.location),
										max(1, min(timeTilNextSpawn, BOUNTY_RUNE_PREP_TIME)))
									)
							> 1
					) then
				if DEBUG then
					INFO_print( string.format("[wp] %s is bailing from rune::blueprint.run..() 1 on '%s'",
								gsiPlayer.shortName,
								wpForBotTask[POSTER_I.OBJECTIVE].name or wpForBotTask[POSTER_I.OBJECTIVE].shortName
							)
						)
				end
				WP_InformBail(gsiPlayer, wpForBotTask)
			elseif (notPreSpawnPeriod or tryWaitingAvailablePickups)
						and GetRuneStatus(objective.runeHandle) == RUNE_STATUS_AVAILABLE
						and runeAreaVisible then
				if VERBOSE then print("/VUL-FT/", gsiPlayer.shortName, "tries start 1, picking up") end
				WP_PlayerTryStart(gsiPlayer, wpForBotTask, true)
				if objective.runeHandle+1 <= I_POWERS_MAX and DotaTime() > END_DOUBLE_POWER_RUNES then
					if VERBOSE then print("/VUL-FT/", gsiPlayer.shortName, "removes opposite rune") end
					local oppositeSidePowerIndex = objective.runeHandle+1 == I_POWERS_MIN and I_POWERS_MAX or I_POWERS_MIN
					local oppositeSidePower = RUNE_LOCATIONS[oppositeSidePowerIndex][RUNE_I__WANTED_POSTER]
					if oppositeSidePower then
						WP_BurnPoster(oppositeSidePower)
						RUNE_LOCATIONS[oppositeSidePowerIndex][RUNE_I__WANTED_POSTER] = nil
						RUNE_LOCATIONS[oppositeSidePowerIndex][RUNE_I__PRESUMED_UNOBTAINABLE] = true
					end
				end
if DEBUG then
				DebugDrawLine(gsiPlayer.lastSeen.location, GetRuneSpawnLocation(wpObjective.runeHandle), 255, 0, 255)
end
				if playerDistanceToRune > 120 then
if DEBUG then
					DebugDrawLine(gsiPlayer.lastSeen.location, objective.lastSeen.location, 255, 255, 0)
end
					if playerDistanceToRune < 900 then
						gsiPlayer.hUnit:Action_MoveDirectly(objective.lastSeen.location)
					else
						if VERBOSE then print("/VUL-FT/", gsiPlayer.shortName, "moving directly") end
						Positioning_ZSMoveCasual(gsiPlayer, objective.lastSeen.location, 0, 1250)
					end
				else
					if VERBOSE then print("/VUL-FT/", gsiPlayer.shortName, "picking up.") end
if DEBUG then
					DebugDrawLine(gsiPlayer.lastSeen.location, GetRuneSpawnLocation(objective.runeHandle), 255, 0, 255)
end
					gsiPlayer.hUnit:Action_PickUpRune(objective.runeHandle)
				end
				return xetaScore
			end
		end
		if WP_PlayerTryStart(gsiPlayer, wpForBotTask, true) then
			if VERBOSE then print("/VUL-FT/", gsiPlayer.shortName, "tries start 2") end
			if playerDistanceToRune/gsiPlayer.currentMovementSpeed < timeTilNextSpawn then
				local nearestEnemy, dist = Set_GetNearestEnemyHeroToLocation(objective.lastSeen.location, 4)
				if nearestEnemy and dist < START_DEFENSE_PROXIMITY then
					if GSI_UnitCanStartAttack(gsiPlayer) then
						if VERBOSE then print("/VUL-FT/", gsiPlayer.shortName, "zone defend") end
						zone_defend_run(gsiPlayer, nearestEnemy, xetaScore, true)
						return xetaScore
					end
				else
					if not notPreSpawnPeriod and FarmJungle_SimpleRunLimitTime(gsiPlayer, timeTilNextSpawn-3.5) then
						if VERBOSE then print("/VUL-FT/", gsiPlayer.shortName, "jungle farm") end
						return xetaScore
					end
				end
			end
			if VERBOSE then print("/VUL-FT/", gsiPlayer.shortName, "move to rune 1") end
			Positioning_ZSMoveCasual(gsiPlayer, objective.lastSeen.location, timeTilNextSpawn/(hasBottle and 40 or 3), 1250)
		else
			if VERBOSE then print("/VUL-FT/", gsiPlayer.shortName, "move to rune 2") end
if DEBUG then
			DebugDrawLine(gsiPlayer.lastSeen.location, wpObjective.lastSeen.location, 255, 255, 0)
end
			Positioning_ZSMoveCasual(gsiPlayer, objective.lastSeen.location, timeTilNextSpawn/(hasBottle and 40 or 3), 1250)
		end
		return xetaScore
	end,
	
	score = function(gsiPlayer, prevObjective, prevScore)
		local currTime = GameTime()
		local wpForBotTask = WP_GetPlayerTaskPoster(gsiPlayer, task_handle)
		local rl
--		if GameTime() > reconsider_runes_time then
--			rl = RUNE_LOCATIONS
--			for i=1,MAX_BOUNTY_RUNES do
--				WP_AllowReinform(rl[i][POSTER_I.WANTED_POSTER])
--			end
--			reconsider_runes_time = GameTime() + 4
--			any_runes_for_consider = true
--		end
		if true or any_runes_for_consider then
			rl = RUNE_LOCATIONS
			any_runes_for_consider = false
			local currGameTime = GameTime()
			for i=1,SAFE_BOUNTIES_MAX+1 do
				local wpHandle = rl[i][RUNE_I__WANTED_POSTER]
				if wpHandle and not rl[i][RUNE_I__PRESUMED_UNOBTAINABLE] then
					if not wpHandle[POSTER_I.ALLOCATE_PERFORMED] then
						-- force inform -- we will skip over bailed bots on reallocs
						if not WP_InformInterest(gsiPlayer, wpHandle, WP_COMMIT_TYPES.INTEREST_BOUNTY, 0, true) then
							any_runes_for_consider = true
						end
					elseif GameTime() - wpHandle[POSTER_I.LAST_ALLOCATE] > 6.0 then
						WP_AllowReinform(wpHandle)
					end
				end
			end
		end
		if DEBUG and wpForBotTask then print(gsiPlayer.shortName, "has a wp for runes - commit is", wpForBotTask[POSTER_I.COMMIT_TYPES][gsiPlayer.nOnTeam], wpForBotTask[POSTER_I.OBJECTIVE].name) end
		if wpForBotTask and WP_CommitIsCommit(gsiPlayer, wpForBotTask) then
			if GetGameState() > GAME_STATE_PRE_GAME and abandon_wp_quietly_if_ally_close_safe(gsiPlayer, wpForBotTask) then
				return false, XETA_SCORE_DO_NOT_RUN
			end
			return wpForBotTask[POSTER_I.OBJECTIVE],
					THROTTLED_BOUNDED(
							WP_ScorePoster(gsiPlayer, wpForBotTask, true),
							80, 180, 700
						)

		end
		return false, XETA_SCORE_DO_NOT_RUN
	end,
	
	init = function(gsiPlayer, objective, extrapolatedXeta)
		gsiPlayer.vibe.aggressivity = gsiPlayer.time.data.theorizedDanger
				and max(1, min(0, (4+gsiPlayer.time.data.theorizedDanger) / 4))
				or gsiPlayer.vibe.aggressivity
		return extrapolatedXeta
	end
}

function Rune_GetTaskHandle()
	return task_handle
end
