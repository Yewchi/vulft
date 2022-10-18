-- how threatened am I by fog of war?
-- how threatened should I feel upon seeing an enemy exit fog of war into my radius?
-- who is a regular in my lane?
-- i.e. who is an unexpected guest?
-- via:
---- how long an enemy hero has been out of fog of war
---- active, visible teleports.																>>>> Cast Callback teleport to me.
---- the speed of an enemy + timemissing/blinkcd*1200 from their last seen. 				>>>> (implementation order) Item tracking is very helpful for this. Avoids t_blink_dagger_carriers. 
-- two metrics, possible TPs; walk-ins; Either or both can be used for analytical scoring
--- Accumulation or mathematical deduction?: 												>>>> Accumulation.
------ Accumulation allows e.g. unit-value addition of the ammended value (1 second)
-- Because the "spook" factor is analytical, the analytics should be scored here.
--- i.e. it could simply be an incentive trigger upon a long-since updated lastSeen update.
---- the incentives would be for 

-- As it has all the logic, also tracks team-player incoming ports

local job_domain_analytics

local max = math.max
local min = math.min
local sqrt = math.sqrt

local TIME_TO_PORT_FROM_START_CAST = 3
local TIME_TO_PORT_CONSIDER_CANCELLED = TIME_TO_PORT_FROM_START_CAST + 4
local MOVE_TO_FOG_TO_TP_BUFFER = 2
local UPDATE_INTERVAL = 1
local CONSIDER_THEORETICAL_KNOWN = 1800

local ENGAGEABLE_DIST = 2200
local IGNORE_CUSTOM_LOC_DIST = 600

local DANGER_DEATH_INFORM_FLAG = -0xFFFF

local ENEMY_TEAM_NUMBER_OF_PLAYERS = ENEMY_TEAM_NUMBER_OF_PLAYERS
local Math_PointToPointDistance2D = Math_PointToPointDistance2D

local ENEMY_FOUNTAIN_LOC = Map_GetLogicalLocation(
		TEAM_IS_RADIANT and MAP_POINT_DIRE_FOUNTAIN_CENTER or MAP_POINT_RADIANT_FOUNTAIN_CENTER
	)

t_current_port_location = {}
t_spread_port_percent = {} -- -ve unless the enemy has been fog for MOVE_TO_FOG_TO_TP_BUFFER
t_spread_footrace = {}
t_blink_daggers = {}

t_visible_to_enemy = {}
t_visible_to_enemy_expires = {}

do
	for pnot=1,ENEMY_TEAM_NUMBER_OF_PLAYERS do
		t_spread_footrace[pnot] = 0
	end
end

local function update_fow_logic() -- Addition of unit time / 1 second values.
	local currTime = GameTime()
	local enemies = GSI_GetTeamPlayers(ENEMY_TEAM)
	for pnot=1,ENEMY_TEAM_NUMBER_OF_PLAYERS do
		local thisEnemy = enemies[pnot]
		local timeSinceSeen = max(0, thisEnemy.lastSeen.timeStamp + 1)
		t_spread_port_percent[pnot] = (currTime - timeSinceSeen - MOVE_TO_FOG_TO_TP_BUFFER) / TIME_TO_PORT_FROM_START_CAST -- 2 sec buffer in fog, 3 sec cast.
		t_spread_footrace[pnot] = currTime - timeSinceSeen < 1.5 and CONSIDER_THEORETICAL_KNOWN
				or ( t_spread_footrace[pnot] + thisEnemy.currentMovementSpeed
						+ (IMPLEMENTitemandabilitymovementstuff or CONSIDER_THEORETICAL_KNOWN)
					) * ( thisEnemy.lastSeen.location == ENEMY_FOUNTAIN_LOC and 0.15 or 1) -- slow spread pre-game
		if t_current_port_location[thisEnemy.playerID] and t_current_port_location[thisEnemy.playerID][2] > TIME_TO_PORT_CONSIDER_CANCELLED then
			t_current_port_location[thisEnemy.playerID] = nil
		end
	end

	local t_visible = t_visible_to_enemy
	local t_visible_expires = t_visible_to_enemy_expires
	for pnot=1,TEAM_NUMBER_OF_PLAYERS do
		if t_visible[pnot] and t_visible_expires[pnot] < currTime then
			t_visible[pnot] = false
		end
	end
end

function Analytics_RegisterPortActivity(gsiPlayer, castInfo)
	if castInfo.channel_start then
		t_current_port_location[gsiPlayer.playerID] = {castInfo.location, GameTime()}
	else
		t_current_port_location[gsiPlayer.playerID] = nil
	end
end

function Analytics_GetEnemyFootraceDistance(gsiPlayer)
	return t_spread_footrace[gsiPlayer.playerID] or 0
end

-- A front-liner seemingly alone can cast an initating ability and lockdown allies, so we interpret theoretically
-- 		engageable enemies as gravitatiously spreading the map towards other enemies, then through, and past
-- 		allied locaitons. The more theoretical the dataset the more we must allow the known enemies to have
-- 		dangerous gravity.
local function incorporate_teamplay_gravity(gsiPlayer, enemiesTbl)
end

function FOW_ExplainConfidence(gsiEnemy, fearFunc)
	local expectedDanger = fearFunc()
	for i=1,ENEMY_TEAM_NUMBER_OF_PLAYERS do
		
	end
end

-- theorizedAggressorAmount ranges from 0.44
-- TODO Currently, providing a location (if even implemented) would've set incorrect data temporarily
function Analytics_GetKnownTheorizedEngageables(gsiPlayer, location)
	local allowCache = location -- don't cache if we're not using the player's location
			and Math_PointToPointDistance2D(gsiPlayer.lastSeen.location, location) < IGNORE_CUSTOM_LOC_DIST
				and false or true
	if not gsiPlayer.time.data.knownEngageables or not allowCache then
		local playerLoc = allowCache and gsiPlayer.lastSeen.location or location
		local enemies = GSI_GetTeamPlayers(ENEMY_TEAM)
		local iKnown=1
		local iTheorized=1
		local knownEng = {}
		local theorizedEng = {}
		local theorizedAggressorAmount = 0 -- uses 1 unit mimic of the player. Allows pretending it's an outnumbered multiplier
		local visionScore = sqrt( gsiPlayer.hUnit:GetDayTimeVisionRange()
				/ gsiPlayer.hUnit:GetCurrentVisionRange() ) / 1.414
		local gameSpeedToSelf = 0
		local myPowerRating = Analytics_GetPowerLevel(gsiPlayer)
		for pnot=1, ENEMY_TEAM_NUMBER_OF_PLAYERS do
			thisEnemy = enemies[pnot]
			gameSpeedToSelf = thisEnemy.currentMovementSpeed
			if IsHeroAlive(thisEnemy.playerID) then
				local thisEnemyFootrace = t_spread_footrace[pnot]
				local distToEnemy = Math_PointToPointDistance2D(playerLoc, thisEnemy.lastSeen.location)
				if thisEnemyFootrace == CONSIDER_THEORETICAL_KNOWN then
					if distToEnemy < ENGAGEABLE_DIST then
						knownEng[iKnown] = thisEnemy
						iKnown = iKnown + 1
					end
				else
					if distToEnemy - thisEnemyFootrace - ENGAGEABLE_DIST > 0 then
						theorizedEng[iTheorized] = thisEnemy
						iTheorized = iTheorized + 1
					end
				end
				if thisEnemy.hUnit and thisEnemy.hUnit:IsNull() then 
					local percentOfWayPossibleTravelled = thisEnemyFootrace/distToEnemy
					local spreadFactor = percentOfWayPossibleTravelled < 2.428
							and (-sqrt(1.5*percentOfWayPossibleTravelled))^3
								+ percentOfWayPossibleTravelled*3
	-- for (possibleDistance, aggressorAmount) curves high into (0.67, 1), to (1, 1.16), (1.16, 1.18), (2.43, 0.33)
							or 0.33
					theorizedAggressorAmount = theorizedAggressorAmount 
							+ spreadFactor*Analytics_GetPowerLevel(thisEnemy) / myPowerRating
				end
			end
		end
		gameSpeedToSelf = min(1.15, (gameSpeedToSelf / ENEMY_TEAM_NUMBER_OF_PLAYERS)
				/ gsiPlayer.currentMovementSpeed)
		theorizedAggressorAmount = theorizedAggressorAmount * gameSpeedToSelf * visionScore
		if allowCache then
			gsiPlayer.time.data.knownEngageables = knownEng
			gsiPlayer.time.data.theorizedEngageables = theorizedEng
			gsiPlayer.time.data.theorizedAggressorAmount = theorizedAggressorAmount -- i.e. not a factor, score, nor ratio; it's the number of "mimics" in power level that could potentially engage the player
		end
		-- DebugDrawText(1650, 620, string.format("%s %.2f", type(theorizedAggressorAmount), theorizedAggressorAmount), 255, 255, 255)
		return knownEng, theorizedEng, theorizedAggressorAmount
	end
	-- if DEBUG and DEBUG_IsBotTheIntern() then 
		-- DebugDrawText(1600, 600, tostring(#(gsiPlayer.time.data.knownEngageables)), 255, 255, 255)
		-- DebugDrawText(1625, 600, tostring(#(gsiPlayer.time.data.theorizedEngageables)), 255, 255, 255)
		-- DebugDrawText(1650, 600, type(gsiPlayer.time.data.theorizedAggressorAmount)..tostring(gsiPlayer.time.data.theorizedAggressorAmount), 255, 255, 255)
	-- end
	
	return gsiPlayer.time.data.knownEngageables, gsiPlayer.time.data.theorizedEngageables, gsiPlayer.time.data.theorizedAggressorAmount
end
local known_theorized = Analytics_GetKnownTheorizedEngageables

function Analytics_GetTheorizedAggressorAmount(gsiPlayer)
	local aggressorAmount = gsiPlayer.time.data.aggressorAmount
	return aggressorAmount or known_theorized(gsiPlayer)
end

function Analytics_GetLocationFlyingPort(gsiPlayer)
	
end

function Analytics_RegisterAnalyticsJobDomainToFowLogic(analyticsJobDomain)
	job_domain_analytics = analyticsJobDomain
	Analytics_RegisterAnalyticsJobDomainToFowLogic = nil
end

function Analytics_CreateUpdateFowMapPrediction()
	job_domain_analytics:RegisterJob(
			function(workingSet)
				if workingSet.throttle:allowed() then
					update_fow_logic()
				end
			end,
			{["throttle"] = Time_CreateThrottle(UPDATE_INTERVAL)}, -- n.b. update_fow_logc relies on unit-time addition of movement
			"JOB_UPDATE_FOW_PREDICTION"
		)
	Analytics_CreateUpdateFowMapPrediction = nil
end
