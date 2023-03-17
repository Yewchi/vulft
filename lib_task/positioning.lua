TEAM_FOUNTAIN_LOC = TEAM==TEAM_RADIANT and Map_GetLogicalLocation(MAP_POINT_RADIANT_FOUNTAIN_CENTER) or Map_GetLogicalLocation(MAP_POINT_DIRE_FOUNTAIN_CENTER)

---- positioning constants
GREED_FACTOR_FOR_Z_NORMAL_SWEEP = 4

MAXIMUM_CONSIDERED_MOVE_CLOSER_TIME_FRAME = 1.5
SAFE_STANDING_NEAR_ATTACK_VARIANCE_RANGED = (250 + 80) / MAXIMUM_CONSIDERED_MOVE_CLOSER_TIME_FRAME -- maximum distance away + maximum closeness
SAFE_STANDING_NEAR_ATTACK_SHIFT_TIME_RANGED = -20 / (250 + 20) * MAXIMUM_CONSIDERED_MOVE_CLOSER_TIME_FRAME  -- i.e. using this factor, at 0seconds to attack target, we shorten the vector by -80 (a reasonable standing location to cast an attack)
SAFE_STANDING_NEAR_ATTACK_VARIANCE_MELEE = (800 + 50) / MAXIMUM_CONSIDERED_MOVE_CLOSER_TIME_FRAME
SAFE_STANDING_NEAR_ATTACK_SHIFT_TIME_MELEE = (-50 / (800 + 50)) * MAXIMUM_CONSIDERED_MOVE_CLOSER_TIME_FRAME -- i.e. because the scale is lower, melee will arrive later to last hit (but, strategically, range units have some aggressive initiative)

local HELPER_VECTOR_45_DEGREE = Vector(601, 601, 0)
--

local TEAM_FOUNTAIN_LOC = TEAM_FOUNTAIN_LOC
local CREEP_AGRO_RANGE = CREEP_AGRO_RANGE
local Vector_Addition = Vector_Addition
local Vector_ScalarMultiply2D = Vector_ScalarMultiply2D
local Vector_UnitDirectionalPointToPoint = Vector_UnitDirectionalPointToPoint
local Vector_ToDirectionalUnitVector = Vector_ToDirectionalUnitVector
local Vector_CrossProduct = Vector_CrossProduct
local Vector_CrossProduct2D = Vector_CrossProduct2D
local Vector_PointToPointLine = Vector_PointToPointLine
local Math_PointToPointDistance2D = Math_PointToPointDistance2D
local Set_GetNearestTeamTowerToPlayer = Set_GetNearestTeamTowerToPlayer
local Set_GetCrowdingRatingToSetTypeAtLocation = Set_GetCrowdingRatingToSetTypeAtLocation
local max = math.max
local min = math.min
local abs = math.abs
local sqrt = math.sqrt

local LANE_CHECK_DIST_FROM_CENTER = LANE_ELL_BEND_OFFSET*0.8

local p_position_rules = {}


do
	for i=1,TEAM_NUMBER_OF_PLAYERS,1 do
		p_position_rules[i] = {}
	end
end

-- Aims:
-- Do not unneccesarily move yourself closer to the enemy because you were avoiding an ally. 
-- Have character and boldness when it's fitting.
-- Do not infinitly loop pathing.
-- Do not agrevate an enemy who is otherwise passive while having no plan of attack or definite purpose.
-- Do not path through a tower when taking defensive action unless it means you avoid pathing near a highly dangerous enemy hero.
-- Do not path under a tower while using a defensive-set-up movement function when the tower has one or less non-seige creeps left to kill.
-- Raise that you've been trapped by creeps to some TP/KillNearestCreep task
-- Make allowance for laning modules to >show intent and consideration< of the yet answered questions of the micro-game and creep target decisions.

-------- Positioning_ProgressZNormalSweeper__Job()
function Positioning_ProgressZNormalSweeper__Job(workingSet) -- Updates z-axis value to sweep bot movement (and sometimes juke) with the cross product of the direction vector towards the bot's target.
	local gsiPlayer = workingSet.gsiPlayer
	gsiPlayer.zAxisMagnitudeSweeperRadians = -- High greed bots will sweep faster because they're a pub god
			gsiPlayer.zAxisMagnitudeSweeperRadians + gsiPlayer.vibe.greedRating * gsiPlayer.time.frameElapsed * GREED_FACTOR_FOR_Z_NORMAL_SWEEP -- Move faster for greed, and at the peak of sweeper near turning direction
	
	local rand = RandomInt(0, 4194303)
	if rand % (gsiPlayer.vibe.safetyRating * 150) <= 5 then -- Juke more often if under pressure (retreat blueprints would probably not use sporadic)
		gsiPlayer.zAxisMagnitudeSweeperRadians = -- Flip z direction coordinate
				(gsiPlayer.zAxisMagnitudeSweeperRadians + MATH_PI) % MATH_2PI
	end
	-- if DEBUG and DEBUG_IsBotTheIntern() then DebugDrawLine(Vector(0, 0, 0), Vector_ScalarMultiply(gsiPlayer.zAxisMagnitudeVector, 200), 255, 255, 255) end
	gsiPlayer.zAxisMagnitudeVector.z = math.sin(gsiPlayer.zAxisMagnitudeSweeperRadians)
end

-------- Positioning_MoveToSafeAttackRange()
function Positioning_MoveToSafeAttackRange(gsiPlayer, locationOfUnit)
	
end

local lower_odd_of_low_rand = 0.0
local last_lower_odd_random_time = GameTime()
-------- Positioning_StutterStepToLocation()
function Positioning_StutterStepToLocation(gsiPlayer, location)
	local currTime = GameTime()
	lower_odd_of_low_caught = currTime-last_lower_odd_random_time > 0.1 and RandomFloat(-0.35, 0.0)
	if GameTime() % 0.7 + lower_odd_of_low_rand < 0.1 then
		gsiPlayer.hUnit:Action_MoveDirectly(
				Vector_Addition(
					gsiPlayer.lastSeen.location,
					Vector_ScalarMultiply2D(
						Vector_PointToPointLine(gsiPlayer.lastSeen.location, location),
						50
					)
				)
			)
	end
end

function Positioning_RegisterGenericAdjustmentRule(gsiPlayer, handleString, locationOrEntity, isAvoidance, timeToDrop)
	p_position_rules[gsiPlayer.nOnTeam][handleString] = {locationOrEntity, isAvoidance, timeToDrop}
end

function Positioning_DeregisterGenericAdjustmentRule(gsiPlayer, handleString)
	p_position_rules[gsiPlayer.nOnTeam][handleString] = nil
end

function Positioning_MoveToLocationSafe(gsiPlayer, location)
	-- Temp
	location = location or Map_GetTeamFountainLocation()
	Positioning_ZSMoveCasual(gsiPlayer, location, 1)
end

-------- Positioning_MovingToLocationAgrosTower()
function Positioning_MovingToLocationAgrosTower(gsiPlayer, location, tower)
	if not tower then
		tower = Set_GetNearestTeamTowerToPlayer(ENEMY_TEAM, gsiPlayer)
		if not tower then return nil end
	end
	if Math_PointToPointDistance2D(location, tower.lastSeen.location) > tower.attackRange + 50 then
		return false
	end
	local towerTarget = not bUnit_IsNullOrDead(tower) and IsLocationVisible(tower.lastSeen.location)
			and tower.hUnit:GetAttackTarget()
			or nil
	if towerTarget == gsiPlayer.hUnit then return true end
	if towerTarget ~= nil and towerTarget.IsNull and not towerTarget:IsNull() and towerTarget:IsAlive() then
		towerTarget = towerTarget:IsCreep() and cUnit_NewSafeUnit(towerTarget)
				or towerTarget:IsHero() and towerTarget.playerID and GSI_GetPlayerFromPlayerID(towerTarget.playerID)
		if not towerTarget then
			return false
		end
		if (towerTarget.creepType and towerTarget.creepType ~= CREEP_TYPE_SIEGE
				and towerTarget.lastSeenHealth < 2*BUILDING_T2_T4_ATTACK_DAMAGE) then
			return false
		end
		-- TODO Allied heroes under tower safety... Difficult because they might be
		-- -| leaving the area, this bot then gets stuck under tower if passing through
	end
	--[[DEBUG]]if DEBUG then DebugDrawLine(gsiPlayer.lastSeen.location, tower.lastSeen.location, 255, 0, 0) end
	return true
end

-------- Positioning_AdjustToAvoidCrowdingSetType()
function Positioning_AdjustToAvoidCrowdingSetType(gsiPlayer, location, setType, careFactor)
	careFactor = careFactor ~= nil and careFactor or 1.0
	--print('adjustpos', location, setType, careFactor)
	local crowdingCenter, crowdingRating = Set_GetCrowdedRatingToSetTypeAtLocation(gsiPlayer.lastSeen.location, setType)
	if crowdingRating > 0 then
		local unitDirectionFromCrowdingCenter = Vector_ToDirectionalUnitVector(Vector_PointToPointLine(crowdingCenter, gsiPlayer.lastSeen.location))
		local adjustedLocation = Vector_Addition(location,
				Vector_ScalarMultiply2D(
					unitDirectionFromCrowdingCenter,
					min(2000, careFactor*crowdingRating)
				)
			)
--[[DEV]]		if DEBUG then 
--[[DEV]]			-- DebugDrawCircle(crowdingCenter, 80, 180, 20, 255)
--[[DEV]]			-- DebugDrawLine(location, adjustedLocation, 180, 20, 255)
--[[DEV]]			--if crowdingRating > 0 and careFactor > 0 then print(GSI_GetBot().shortName, crowdingRating, careFactor, "=", min(700, 50*careFactor*crowdingRating), string.format("(%.2f, %.2f, %.2f)->(%.2f, %.2f, %.2f)", location.x, location.y, location.z, adjustedLocation.x, adjustedLocation.y, adjustedLocation.z)) end
--[[DEV]]		end

		return adjustedLocation
	else
		return location
	end
end

-- Flips the adjusting added vector if it points aggressively into enemy territory.
-------- Positioning_AdjustToAvoidLocationFlipAggressive
function Positioning_AdjustToAvoidLocationFlipAggressive(location, currLocation, avoidLocation, radius)
	local distBetweenLocations = Math_PointToPointDistance2D(location, avoidLocation)
	local avoidByDistance = max(0, radius - distBetweenLocations)
	local locationAvoiding = Vector_Addition(location,
			Vector_ScalarMultiply2D(
				Positioning_FlipAxisTeamIfAggressiveOrientationMovement(
					Vector_ToDirectionalUnitVector(
						Vector_PointToPointLine(avoidLocation, location)
					), ZEROED_VECTOR
				),
				avoidByDistance + HERO_TARGET_DIAMETER
			)
		)
	--[[DEBUG]]if DEBUG then DebugDrawLine(location, locationAvoiding, 255, 20, 20) end
	return locationAvoiding
end

-------- Positioning_AdjustToAvoidLocation()
function Positioning_AdjustToAvoidLocation(location, currLocation, avoidLocation, radius)
	local distBetweenLocations = Math_PointToPointDistance2D(location, avoidLocation)
	local avoidByDistance = max(0, radius*1.15 - distBetweenLocations)
	local locationAvoiding = Vector_Addition(location,
			Vector_ScalarMultiply2D(
				Vector_ToDirectionalUnitVector(
					Vector_PointToPointLine(avoidLocation, location)
				),
				avoidByDistance + HERO_TARGET_DIAMETER
			)
		)
	--[[DEBUG]]if DEBUG then DebugDrawLine(location, locationAvoiding, 255, 20, 20) end
	return locationAvoiding
end

-- Returns true if already out-of-agro range from location, and then performs no move
function Positioning_FindAndApproachNearestNonAgro(gsiPlayer, locationOfAgro)
	-- locationOfAgro may be an enemy creep
	local playerLoc = gsiPlayer.lastSeen.location
	local unitDirectionalFromAgro = Vector_UnitDirectionalPointToPoint(playerLoc, locationOfAgro)
	local distanceFromAgro = Math_PointToPointDistance2D(playerLoc, locationOfAgro)
	if distanceFromAgro < CREEP_AGRO_RANGE then
		local attempts = 1
		while(attempts < 4) do
			attempts = attempts+1
		end
	end
end

-- If we execute an attack command on a unit, will we be within a location-radius circle
-- - at any time.
-- TODO Return the 0% - 200% radius remaining when travelling in the attack move direction
-- - of the distance that is inside the circle.
function Positioning_WillAttackCmdExposeToLocRad(gsiPlayer, gsiUnit, location, radius)
	-- TODO improve and reduce
	local playerLoc = gsiPlayer.lastSeen.location
	local unitLoc = gsiUnit.lastSeen.location
	local directionalFromUnit = Vector_UnitDirectionalPointToPoint(unitLoc, playerLoc)
	local directionalFromPlayer = Vector_InverseVector(directionalFromUnit)
	--local movingTowardsAvoid = ( playerLoc.x < location.x and directionalFromPlayer.x > 0 )
	--		or ( playerLoc.x > location.x and directionalFromPlayer.x < 0)
	local distanceToAvoided = Math_PointToPointDistance2D(playerLoc, location)

	if distanceToAvoided < radius then
		--print(gsiPlayer.shortName, "is inside", location)
		return true
	end

	local distanceToUnit = Math_PointToPointDistance2D(unitLoc, location)
	local resultLocation = Vector_Addition(
			unitLoc,
			Vector_ScalarMultiply2D(
					directionalFromUnit,
					min(distanceToUnit, gsiPlayer.attackRange)
				)
		)

	if Vector_PointDistance2D(resultLocation, location) < radius then
		--print(gsiPlayer.shortName, "will be inside", location)
		return true
	end

	-- N.B. It's assumed going forward that the player is not inside the circle
	
	local m = directionalFromPlayer.y / Math_DivisorSafe5Dec(directionalFromPlayer.x)
	local c = playerLoc.y - m*(playerLoc.x)
	-- d = |m*circleCenterX + 1*circleCenterY + c| / sqrt(m^2 + 1^2), where 1 represents the coefficient of the y value
	local d = abs(m*location.x - location.y + c) / sqrt(m^2 + 1)

	--[VERBOSE]]if VERBOSE then print(gsiPlayer.shortName, gsiUnit.shortName, m, "is outside of CmdExpose, checking", d, "<=", radius, m, c) end
	-- convoluted I'm sure
	if d <= radius then -- i.e. we intersect the circle
		local normalToMovement
				= Vector_CrossProduct2D(directionalFromPlayer, Vector(location.x-playerLoc.x, location.y-playerLoc.y)) >= 0
					and Vector_CartesianNormal(directionalFromPlayer)
					or Vector_CartesianNormal(directionalFromUnit) -- if the line is right of the circle center, flip normal
		-- TODO Where A = the intersection of the normal of the movement-line to the circle, B = a sliding point along the normal,
		-- - C = the intersection of the movement-line to the circle. What is the general equation of the length of a line
		-- - B->C. Until then: SeemsGood
		local testPassedPoint
				= Vector_Addition(
						Vector_Addition(location,
								Vector_ScalarMultiply(normalToMovement, d)
							),
						Vector_ScalarMultiply(directionalFromUnit, radius*sqrt((radius - d)/radius)) -- sqrt SeemsGood
					)
		if DEBUG then 
			local outFromAvoid = Vector_Addition(location, Vector_ScalarMultiply(normalToMovement, d))
			if not TEAM_IS_RADIANT then DebugDrawLine(playerLoc, outFromAvoid, 180, 180, 255) end
			--DebugDrawCircle(location, radius, 50, 50, 50)
			DebugDrawCircle(testPassedPoint, 50, 255, 100, 100)
			if not TEAM_IS_RADIANT then DebugDrawLine(location, outFromAvoid, gsiPlayer.nOnTeam*50, gsiPlayer.nOnTeam*50, 255) end
			if not TEAM_IS_RADIANT then DebugDrawLine(outFromAvoid, testPassedPoint, gsiPlayer.nOnTeam*50, gsiPlayer.nOnTeam*50, 255) end
		end

		-- the kicker
		local sideBefore
				= Vector_CrossProduct2D(
						normalToMovement,
						Vector(playerLoc.x - testPassedPoint.x, playerLoc.y - testPassedPoint.y)
					)
		local sideAfter
				= Vector_CrossProduct2D(
						normalToMovement,
						Vector(resultLocation.x - testPassedPoint.x, resultLocation.y - testPassedPoint.y)
					)
		if sideBefore > 0 and sideAfter < 0
				or sideBefore < 0 and sideAfter > 0 then
			if VERBOSE then print(gsiPlayer.shortName, gsiUnit.shortName, "is a risk") end
			return true
		end
	end
	return false
end

-- Returns true if unitWins wins a race to finishLoc versus unitLoses. "If I stand here in lane for 4 seconds, do I still win a race to the bounty rune?"
function Positioning_ProjectedRace(unitWins, unitLoses, finishLoc, timeToProject, unitWinsLoc, unitLosesLoc)
	if not unitWinsLoc and (not unitWins.hUnit or unitWins.hUnit:IsNull()) then
		-- here, we do not have vision of the unit, imagine they are moving directly to the finish loc
		unitWinsLoc = unitWinsLoc or unitWins.lastSeen.location
		local dirVec = Vector_ToDirectionalUnitVector(Vector_PointToPointLine(unitWinsLoc, finishLoc))
		unitWinsLoc = Vector_Addition(unitWinsLoc, Vector_ScalarMultiply2D(dirVec*unitWins.currentMovementSpeed, timeToProject))
	else unitWinsLoc = unitWins.hUnit:GetExtrapolatedLocation(timeToProject) end
	if not unitLosesLoc and (not unitLoses.hUnit or unitLoses.hUnit:IsNull()) then
		-- ''
		unitLosesLoc = unitLosesLoc or unitLoses.lastSeen.location
		local dirVec = Vector_ToDirectionalUnitVector(Vector_PointToPointLine(unitLosesLoc, finishLoc))
		unitLosesLoc = Vector_Addition(unitLosesLoc, Vector_ScalarMultiply2D(dirVec*unitLoses.currentMovementSpeed, timeToProject))
	else unitLosesLoc = unitLoses.hUnit:GetExtrapolatedLocation(timeToProject) end
	local wonBy = Math_PointToPointDistance2D(unitLosesLoc, finishLoc)/unitLoses.currentMovementSpeed - Math_PointToPointDistance2D(unitWinsLoc, finishLoc)/unitWins.currentMovementSpeed
	return wonBy >= 0, wonBy
end

-- Sometimes we don't desire a vector to point in an aggressive direction in the lane, like when your creep target runs too far up your lane and flips the to-safe-creep-set vector
--- The function is not intended to prevent movement in a direction, but retain a logical idea about what a vector in a series of vector operations may mean. This function is very ugly.
-------- Positioning_FlipAxisTeamIfAggressiveOrientationMovement()
function Positioning_FlipAxisTeamIfAggressiveOrientationMovement(v, currLoc)
	if TEAM == TEAM_RADIANT then
		if Map_GetLaneValueOfMapPoint(currLoc) == MAP_LOGICAL_MIDDLE_LANE then
			if v.y > 0 and v.x > 0 then
				return Vector(-v.x, -v.y, v.z)
			end
		else
			if v.y > 0 and (currLoc.x > LANE_CHECK_DIST_FROM_CENTER or currLoc.x < -LANE_CHECK_DIST_FROM_CENTER) then
				return Vector(v.x, -v.y, v.z)
			elseif v.x > 0 and (currLoc.y > LANE_CHECK_DIST_FROM_CENTER and currLoc.y < -LANE_CHECK_DIST_FROM_CENTER) then
				return Vector(-v.x, v.y, v.z)
			end
		end
	else
		if Map_GetLaneValueOfMapPoint(currLoc) == MAP_LOGICAL_MIDDLE_LANE then
			if v.y < 0 and v.x < 0 then
				return Vector(-v.x, -v.y, v.z)
			end
		else
			if v.y < 0 and (currLoc.x > LANE_CHECK_DIST_FROM_CENTER or currLoc.x < -LANE_CHECK_DIST_FROM_CENTER) then
				return Vector(v.x, -v.y, v.z)
			elseif v.x < 0 and (currLoc.y > LANE_CHECK_DIST_FROM_CENTER and currLoc.y < -LANE_CHECK_DIST_FROM_CENTER) then
				return Vector(-v.x, v.y, v.z)
			end
		end
	end
	return v
end

-- Move to a location casually, as if waiting for something
-------- Positioning_ZSMoveCasual()
function Positioning_ZSMoveCasual(gsiPlayer, moveTo, careFactor, maxActionDist, walkStraight)
--[[DEV]]if VERBOSE then DebugDrawText(1400+(TEAM_IS_RADIANT and 0 or 50), gsiPlayer.nOnTeam*8, "MC", 180, 180, 180) end
	local distToDest = Math_PointToPointDistance2D(gsiPlayer.lastSeen.location, moveTo)
	local lowSweeperZ
	local circularHelp
	if not walkStraight then
		lowSweeperZ = Vector_ScalarMultiply(gsiPlayer.zAxisMagnitudeVector, 0.25)
		circularHelp = Vector_CrossProduct(
				HELPER_VECTOR_45_DEGREE,
				lowSweeperZ
			)
	end
	--circularHelp = Vector_ScalarMultiply(circularHelp, 1 - max(0.9, (distToDest / 1200)))
	moveTo = Positioning_AdjustToAvoidCrowdingSetType(gsiPlayer, moveTo, SET_HERO_ALLIED, 400)
	if maxActionDist then
		local p2p = Vector_PointToPointLine(gsiPlayer.lastSeen.location, moveTo)
		if Vector_LengthOfVector(p2p) > maxActionDist then
			moveTo = Vector_Addition(
					gsiPlayer.lastSeen.location,
					Vector_ScalarMultiply2D(
							Vector_ToDirectionalUnitVector(Vector_PointToPointLine(gsiPlayer.lastSeen.location, moveTo)),
							maxActionDist 
					)
				)
		end
	end
	if not walkStraight then
		moveTo = Vector_Addition(
				moveTo, 
				circularHelp
			)
	end
	-- if gsiPlayer.shortName == "void_spirit" then DebugDrawText(1000, 500, string.format("%f, %f, %f", plusCircularization.x, plusCircularization.y, plusCircularization.z), 255, 255, 0) end

	if careFactor and careFactor > 0 then
		moveTo = Positioning_AdjustToAvoidCrowdingSetType(gsiPlayer, moveTo, SET_HERO_ENEMY, careFactor)
		moveTo = Positioning_AdjustToAvoidCrowdingSetType(gsiPlayer, moveTo, SET_HERO_ALLIED, careFactor)
	end
	local closestTower = Set_GetNearestTeamTowerToPlayer(ENEMY_TEAM, gsiPlayer)
	if DEBUG and DEBUG_IsBotTheIntern() and not closestTower then print(gsiPlayer.shortName, "No tower found move casual.") end
	if closestTower and Positioning_MovingToLocationAgrosTower(gsiPlayer, moveTo, closestTower) then 
		moveTo = Positioning_AdjustToAvoidLocationFlipAggressive(moveTo, gsiPlayer.lastSeen.location, closestTower.lastSeen.location, closestTower.attackRange+150)
		--print(gsiPlayer.shortName, "movement vector addition performed")
	end
	if not walkStraight then
		moveTo = Vector_Addition(
				moveTo,
				Vector_CrossProduct( -- Add some motion in the directional axis, for when standing still
					circularHelp, 
					lowSweeperZ
				)
			)
	end
	--[[DEBUG]if DEBUG then DebugDrawLine(gsiPlayer.lastSeen.location, moveTo, 0, 0, 0) end --]]
	Positioning_MoveDirectlyCheckPort(gsiPlayer, moveTo) -- TODO Doesn't account for ETA of objectives
end

-------- Positioning_ZSAttackRangeUnitHugTower()
function Positioning_ZSAttackRangeUnitHugTower(gsiPlayer, locationOfUnit, timeTilAttackingTarget)
--[[DEV]]if VERBOSE then DebugDrawText(1400+(TEAM_IS_RADIANT and 0 or 50), gsiPlayer.nOnTeam*8, "ARUHT", 180, 180, 180) end
	local closestTower = gsiPlayer.hUnit:GetNearbyTowers(1600, false)
	local saferTowardsLoc = 
			closestTower and closestTower[1] and closestTower[1]:GetLocation() or
			TEAM_FOUNTAIN_LOC
	local targetToCloseTowerUnitVector = 
			Positioning_FlipAxisTeamIfAggressiveOrientationMovement(
				Vector_ToDirectionalUnitVector(
					Vector_PointToPointLine(
						locationOfUnit, saferTowardsLoc
					)
				),
				saferTowardsLoc
			)
	local safetyStandingDistance = gsiPlayer.hUnit:GetAttackRange()
			+ ( gsiPlayer.isRanged and 
					SAFE_STANDING_NEAR_ATTACK_VARIANCE_RANGED
					* ( SAFE_STANDING_NEAR_ATTACK_SHIFT_TIME_RANGED
						+ max(
							0, 
							min(
								MAXIMUM_CONSIDERED_MOVE_CLOSER_TIME_FRAME, 
								timeTilAttackingTarget
							)
						)
					)
				or
					SAFE_STANDING_NEAR_ATTACK_VARIANCE_MELEE
					* ( SAFE_STANDING_NEAR_ATTACK_SHIFT_TIME_MELEE
						+ max(
							0, 
							min(
								MAXIMUM_CONSIDERED_MOVE_CLOSER_TIME_FRAME, 
								max(0, timeTilAttackingTarget-0.25)
							)
						)
					)
			)
	local unitToCloseTowerAtAttackRange =
			Vector_Addition(locationOfUnit,
				Vector_ScalarMultiply2D(
					targetToCloseTowerUnitVector, 
					safetyStandingDistance
				)
			)
	local basicLocation = Vector_Addition(
			unitToCloseTowerAtAttackRange,
				Vector_ScalarMultiply2D(
					Vector_CrossProduct(
						targetToCloseTowerUnitVector,
						(gsiPlayer.isRanged and gsiPlayer.zAxisMagnitudeVector or Vector_ScalarMultiply2D(gsiPlayer.zAxisMagnitudeVector, math.log(1.05+timeTilAttackingTarget)/2))  -- Do not move sporadically moments before needing to attack (like under the creep wave as melee)
					),
					350
				)
			)
	if unitToCloseTowerAtAttackRange then
		Positioning_MoveDirectlyCheckPort(gsiPlayer,
				Positioning_AdjustToAvoidCrowdingSetType( gsiPlayer, basicLocation, SET_HERO_ENEMY, 0.35)
			)
	end
end

function Positioning_MoveAsVulnerable(gsiPlayer, loc)
	-- Move to location, avoiding enemies, assessing abilities, if overwhelmed, return true
end

function Positioning_MoveAsLurk(gsiPlayer, loc)
	-- Move to location, avoiding enemies if possible, assessing abilities, if another player would reach a location before you, return true
end

function Positioning_MoveAsAggressor(gsiPlayer, loc, rangeTrigger)
	-- Move to location, attacking-stepping any enemies, if they stray within rangeTrigger distance, return true
end

function Positioning_MoveAsFarming(gsiPlayer, loc, rangeTrigger, timeLimit)
	-- Move to location, farm jungle camps and creep waves that haven't crashed within rangeTrigger, if they are in the path, and will not
	--   decrease your HP pool too greatly. Aim to get to the location within a certain time. As the time nears, allowed objective scores
	--   for farming will decrease. "What is taking you so long?" "Hard camp is 20% hp"
end

-------- Positioning_ZSAttackRangeUnitHugAllied()
-- TODO Change locationOfUnit and all uses of the function to the unit itself.
-- - This is so we can check the facing direction, for aheadness, and if the unit is looking
-- - away from us, use their facing direction as the aheadness location rather than the
-- - ENEMY_FOUNTAIN_LOC, because they may be retreating to towers or groups of enemies rather
-- - than the fountain. Even if it is a group of their allies (indicating danger) we must trust
-- - the aheadness value given by the functions above us to indicate that it is safe to go deep
-- - and attack for the kill.
function Positioning_ZSAttackRangeUnitHugAllied(
			gsiPlayer, locationOfUnit, unitSetToAvoid,
			careFactor, timeTillStartAttack, forceAttackRange, aheadness
		)
	if true then gsiPlayer.hUnit:Action_MoveDirectly(locationOfUnit) end
--[[DEV]]if VERBOSE then DebugDrawText(1400+(TEAM_IS_RADIANT and 0 or 50), gsiPlayer.nOnTeam*8, "ARUHA", 180, 180, 180) end
	if Team_GetRoleBasedLane(gsiPlayer) ~= MAP_LOGICAL_MIDDLE_LANE and Map_GetLaneValueOfMapPoint(locationOfUnit) == MAP_LOGICAL_MIDDLE_LANE then
--		print(gsiPlayer.shortName, "GOING TO MID FROM :: ", debug.traceback())
	end
	
	local aheadness = aheadness or 0.0
	local closestAlliedCreepSet = Set_GetNearestAlliedCreepSetInLane(gsiPlayer, Team_GetRoleBasedLane(gsiPlayer))
	local safeOrAheadnessTargetLoc = aheadness < 0.5 and
			(closestAlliedCreepSet and closestAlliedCreepSet.center or
			TEAM_FOUNTAIN)
			or ENEMY_FOUNTAIN
	local targetToCloseAlliedCreepSetVector =
			Positioning_FlipAxisTeamIfAggressiveOrientationMovement(
				Vector_ToDirectionalUnitVector(
					Vector_PointToPointLine(
						locationOfUnit, safeOrAheadnessTargetLoc
					)
				),
				safeOrAheadnessTargetLoc
			)
	-- TODO ranged heroes use a -^- shape where carrot is stradling the enemy, to avoid
	-- - unneccesary opportunity to melee enemies. (i.e. shaped over the aheadness
	-- - 0.0 to 1.0 scale)
	local standingDistance = gsiPlayer.attackRange
			+ ( gsiPlayer.isRanged and 
					SAFE_STANDING_NEAR_ATTACK_VARIANCE_RANGED
					* ( SAFE_STANDING_NEAR_ATTACK_SHIFT_TIME_RANGED
						+ max(
							0, 
							min(
								MAXIMUM_CONSIDERED_MOVE_CLOSER_TIME_FRAME, 
								timeTillStartAttack
							)
						)
					)
				or
					SAFE_STANDING_NEAR_ATTACK_VARIANCE_MELEE
					* ( SAFE_STANDING_NEAR_ATTACK_SHIFT_TIME_MELEE
						+ max(
							0, 
							min(
								MAXIMUM_CONSIDERED_MOVE_CLOSER_TIME_FRAME, 
								max(0, timeTillStartAttack-0.5)
							)
						)
					)
			)
	standingDistance = standingDistance * abs(aheadness*2 - 1.0)
	--print(gsiPlayer.shortName, "aheadness", aheadness, safeOrAheadnessTargetLoc, standingDistance)
	--[DEBUG]]if safetyStandingDistance > 1500 then print("safety standing was ", safetyStandingDistance, gsiPlayer.shortName) end
--[[DEBUG]]-- if GSI_GetBot().shortName == "void_spirit" then
		-- print(safetyStandingDistance, timeTillStartAttack, SAFE_STANDING_NEAR_ATTACK_VARIANCE_MELEE, SAFE_STANDING_NEAR_ATTACK_SHIFT_TIME_MELEE, max(0, min(1.0, (timeTillStartAttack))))
	-- end
	local unitToCloseAlliedCreepSetAtAttackRange = 
			Vector_Addition(locationOfUnit,
				Vector_ScalarMultiply2D(
					targetToCloseAlliedCreepSetVector,
					standingDistance
				)
			)
	local location = forceAttackRange and location or Vector_Addition(
			unitToCloseAlliedCreepSetAtAttackRange,
			Vector_ScalarMultiply2D(
				Vector_CrossProduct(
					targetToCloseAlliedCreepSetVector,
					(gsiPlayer.isRanged and gsiPlayer.zAxisMagnitudeVector or Vector_ScalarMultiply2D(gsiPlayer.zAxisMagnitudeVector, math.log(1.05+timeTillStartAttack)/2))*0.25
				),
				350	
			)
		)
	location = Positioning_AdjustToAvoidCrowdingSetType( 
			gsiPlayer, location, SET_HERO_ALLIED, (gsiPlayer.isRanged and 550 or 250)*min(1, max(0.3, timeTillStartAttack))
	-- ^^ i.e. range bots may go wide in a lane at attack range, and melee should have some knowledge of bumping, but don't get pushed below the creep wave by a range hero
		)
	if unitSetToAvoid ~= UNIT_TYPE_NONE then
		careFactor = (careFactor and careFactor or 10000) * min(forceAttackRange and 0 or 1, timeTillStartAttack)
		location = Positioning_AdjustToAvoidCrowdingSetType(
				gsiPlayer, location, unitSetToAvoid ~= nil and unitSetToAvoid or SET_HERO_ENEMY, careFactor
			)
	end
	local closestTower = Set_GetNearestTeamTowerToPlayer(ENEMY_TEAM, gsiPlayer)
	if closestTower and Positioning_MovingToLocationAgrosTower(gsiPlayer, location, closestTower) then 
		location = Positioning_AdjustToAvoidLocation(location, gsiPlayer.lastSeen.location, closestTower.lastSeen.location, closestTower.attackRange+150)
		--print(gsiPlayer.shortName, "movement vector addition performed sporadic")
	end
	
	if location then
		if forceAttackRange then -- OPT We've done our best to move away / towards what's important, push it in to know we're in range
			location = Vector_Addition(
					location,
					Vector_ScalarMultiply(
							Vector_UnitDirectionalPointToPoint(
									location, 
									locationOfUnit),
							Math_PointToPointDistance2D(location, locationOfUnit) - gsiPlayer.attackRange + 50
						)
				)
		end
--[[DEV]]if DEBUG then DebugDrawLine(location, gsiPlayer.lastSeen.location, gsiPlayer.DBGColor[1], gsiPlayer.DBGColor[2], gsiPlayer.DBGColor[3]) end
		Positioning_MoveDirectlyCheckPort(gsiPlayer, location)
	end
end

function Positioning_MoveDirectlyCheckPort(gsiPlayer, location)
	location = Vector_BoundedToWorld(location)
	Port_CheckPortNeeded(gsiPlayer, location)
	gsiPlayer.hUnit:Action_MoveDirectly(location)
end

function Positioning_PanicButtonFountain(gsiPlayer)
	gsiPlayer.hUnit:Action_MoveDirectly(Map_GetLogicalLocation(TEAM==TEAM_RADIANT and MAP_POINT_RADIANT_FOUNTAIN or MAP_ZONE_DIRE_FOUNTAIN))
end
