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

-- Projectiles and attack-time calculations (the tools of last_hit_projection.lua)
local MATH_PI = MATH_PI
local MATH_2PI = MATH_2PI

local TOWER_ATTACK_EST_ADDED_TIME = 0.033*5

local UPDATE_PREVIOUS_SEEN_LOC_DELTA = UPDATE_PREVIOUS_SEEN_LOC_DELTA

furthestProjectile = nil

local acos = math.acos
local rad = math.rad
local abs = math.abs
local max = math.max
local floor = math.floor
local min = math.min
local pi = math.pi
local pi2 = pi*2

local t_apx_reduced_time_from_release = {}
local t_apx_turn_rate = {}

local ATTACK_ANIM_CYCLE = 1503

local TURN_RATE_MIN = 0.6
local TURN_RATE_MAX = 0.9
TURN_RATE_BASIC = TURN_RATE_MIN / 0.03 -- higher-end (turnRate rad) / tickRate 
local TURN_RATE_BASIC = TURN_RATE_BASIC
local START_CAST_RAD = rad(11.5) -- 0.201 rad - source:dota2 gamepedia 02/14/21

local HIT_BOX = 20
local TWICE_HIT_BOX = HIT_BOX*2

local DEBUG = DEBUG
local VERBOSE = VERBOSE

local function update_apx_released_diff(unitName, time)
	time = time + 0.0083 -- small buffer for tick
	local approximation = t_apx_reduced_time_from_release[unitName]
	if not approximation then
		t_apx_reduced_time_from_release[unitName] = time
	else
		-- trend earlier, known miss vs might have room after hitable
		t_apx_reduced_time_from_release[unitName]
				= approximation + (time - approximation)
					* (time > approximation and 0.067 or 0.15)
	end
end

local function get_apx_released_diff(unitName)
	
	return t_apx_reduced_time_from_release[unitName] or 0
end
function Projectile_TimeTilFacingDirectional(facingRad, v, turnRate)
	-- TODO there's probably some simpler rule for this
	local dist = Vector_LengthOfVector(v)
	if dist == 0 then
		if DEBUG then
			WARN_print(string.format(
						"[projectile] zero-length point to point given TimeTilFacingDirectional(%s)",
						Util_ParamString(facingRad, v, turnRate)
					)
				)
			print(debug.traceback())
		end
		return MATH_PI/turnRate;
	end
	local goalDirection = acos(rad(v.x / Vector_LengthOfVector(v)))
	goalDirection = v.y < 0 and MATH_2PI-goalDirection or goalDirection
	local turnRad = abs(facingRad - goalDirection)
	turnRad = max(0, abs(turnRad > MATH_PI and MATH_2PI - turnRad or turnRad) - START_CAST_RAD)
	return turnRad / (turnRate or TURN_RATE_BASIC)
end
local Projectile_TimeTilFacingDirectional = Projectile_TimeTilFacingDirectional

-- TODO Detect gets hit Z--  should not be hard-coded in creep / building; and it's a default in player 7.32e

-- a.b = |a||b|cos(t).
-- let a = directionalVector, b = unit vector (1, 0, 0)
-- .'. [ax + 0 + 0] = |a|*1 cos(t)
-- .'. cos(t) = ax/|a|
-- .'. t = arccos(ax/|a|) :: (The abs(rotational shift) from the 0th degree of a directional vector for either rotation)

local block_repeat_projectile_diff = 0
-- This is for considering attacks, not for the time a live projectile of an attacking unit lands.
-------- Projectile_TimeToLandProjectile()
function Projectile_TimeToLandProjectile(gsiUnit, gsiTarget)
	local hUnit = gsiUnit.hUnit
	local hUnitTarget = gsiTarget.hUnit
	local attackingLoc = gsiUnit.lastSeen.location
	local attackedLoc = gsiTarget.lastSeen.location
	local attackPointPercent = gsiUnit.attackPointPercent
	local hUnitProjectileSpeed = gsiUnit.hUnit:GetAttackProjectileSpeed()
	local facingDeg = hUnit:GetFacing()
	local directionalToTarget = Vector_PointToPointLine(attackingLoc, attackedLoc)
	local distToTarget = (directionalToTarget.x^2 + directionalToTarget.y^2 + directionalToTarget.z^2)^0.5
	local rangeOfAttack = gsiUnit.attackRange + TWICE_HIT_BOX
	rangeOfAttack = rangeOfAttack < distToTarget and rangeOfAttack or distToTarget
	local timeToTurn = Projectile_TimeTilFacingDirectional(rad(facingDeg), directionalToTarget, gsiUnit.turnRate)
	local timeToArriveAtAttack = Vector_LengthOfVector(directionalToTarget)
				- gsiUnit.attackRange - HIT_BOX
	timeToArriveAtAttack = timeToArriveAtAttack < 0 and 0
			or timeToArriveAtAttack / gsiUnit.currentMovementSpeed

	local lastAttackTime = hUnit:GetLastAttackTime()
	local attackedThisFrame = GameTime() - lastAttackTime < 0.0333
	if attackedThisFrame then
		local animActivity = hUnit:GetAnimActivity()
		if animActivity >= 1503 or animActivity <= 1505 then
			local aPP = hUnit:GetAnimCycle()
			local secondsPerAttack = hUnit:GetSecondsPerAttack()
			-- CK test bot reported 0.305 animCycle lands, GetAttackPoint() gives 0.5
			aPP = floor((aPP * secondsPerAttack) / 0.033) * 0.033
			local aPP = aPP / secondsPerAttack -- reverse the frame floor, expressed in % anim.
			local prevAnim = gsiUnit.attackPointPercent
			gsiUnit.attackPointPercent = prevAnim + (aPP - prevAnim)
						* (prevAnim > aPP and 0.15 or 0.35)
		end
	end
	if block_repeat_projectile_diff < GameTime() then
		local testTarget = hUnit:GetAttackTarget()
		if gsiUnit.isRanged and attackedThisFrame
				and testTarget and not testTarget:IsNull() then
			local testTargetLoc = attackingLoc
			local projectiles = testTarget:GetIncomingTrackingProjectiles()
			local avoidTeleports = gsiUnit.attackRange * 1.2
			local furthestDart
			local furthestDist = 0
			for i=0,#projectiles do
				local thisDart = projectiles[i]
				if thisDart and thisDart.caster == hUnit then
					local thisDartLoc = thisDart.location
					local dist = ( (thisDartLoc.x - testTargetLoc.x)^2
							+ (thisDartLoc.y - testTargetLoc.y)^2
							+ (thisDartLoc.z - testTargetLoc.z)^2 )^0.5
					if dist > furthestDist and dist < avoidTeleports then
						furthestDart = thisDart.location
						furthestDist = dist
					end
				end
			end
			furthestDist = furthestDist
			if furthestDart then
				block_repeat_projectile_diff = GameTime() + 0.05
				if hUnit:CanBeSeen() and attackedThisFrame then
					
					update_apx_released_diff(gsiUnit.name,
							((furthestDist - Vector_PointDistance(attackingLoc, testTargetLoc)) / hUnitProjectileSpeed)
						)
					--print("UPDATED RELEASED DIFF", gsiUnit.name, get_apx_released_diff(gsiUnit.name))
				end
			end
		end
	end

		

	return max(0.017, 
			( gsiUnit.isRanged
					and rangeOfAttack/hUnitProjectileSpeed + get_apx_released_diff(gsiUnit.name)
					or 0
				) + attackPointPercent * hUnit:GetSecondsPerAttack() + timeToTurn + timeToArriveAtAttack
		)
end

function Projectile_GetNextAttackComplete(gsiUnit, needsProjectile)
	local hUnit = gsiUnit.hUnit
	if not hUnit:CanBeSeen() then
		return 
	end
	-- TODO turning time is time till start attack
	local attackTarget = hUnit:GetAttackTarget()
	if attackTarget then
		local attackerLoc = gsiUnit.lastSeen.location
		local attackedLoc = attackTarget:GetLocation()
		local gsiAttacked = Unit_GetSafeUnit(attackTarget)
		if not gsiAttacked then return; end

		local attackedThisFrame = GameTime() == hUnit:GetLastAttackTime()
		if attackedThisFrame then
			local animActivity = hUnit:GetAnimActivity()
			if animActivity >= 1503 or animActivity <= 1505 then
				local aPP = hUnit:GetAnimCycle()
				local secondsPerAttack = hUnit:GetSecondsPerAttack()
				-- CK test bot reported 0.305 animCycle lands, GetAttackPoint() gives 0.5
				aPP = floor((aPP * secondsPerAttack) / 0.033) * 0.033
				local aPP = aPP / secondsPerAttack -- reverse the frame floor, expressed in % anim.
				local prevAnim = gsiUnit.attackPointPercent
				gsiUnit.attackPointPercent = prevAnim + (aPP - prevAnim)
							* (prevAnim > aPP and 0.15 or 0.35)
			end
		end

		local hUnitProjectileSpeed = hUnit:GetAttackProjectileSpeed()
	
		local attackPointPercent = gsiUnit.attackPointPercent
		local animCycle = hUnit:GetAnimCycle()
		local lastAttackTime = gsiUnit.hUnit:GetLastAttackTime()
		local sinceAttack = GameTime() - lastAttackTime
		local secPerAttack = gsiUnit.hUnit:GetSecondsPerAttack()
		local thisAttackAnimHasReleased = animCycle >= attackPointPercent
				- (sinceAttack / secPerAttack < 0.05 and 0.1 or 0)
		local attackDist
		local inAttackAnim = hUnit:GetAnimActivity() == 1503 --[[ANIMATION BAKE]]
		local attackTargetGetsHit = attackedLoc
		attackTargetGetsHit.z = attackTargetGetsHit.z +
				(gsiAttacked and gsiAttacked.getsHitZ or 20)
		local isRanged = gsiUnit.isRanged
		if not needsProjectile then
			if gsiUnit.isTower then
				local towerReleaseLoc = attackerLoc
				
				
				
				return attackTarget,
						max(0, lastAttackTime - GameTime()
								+ secPerAttack
							) + ( (towerReleaseLoc.x-attackTargetGetsHit.x)^2
									+ (towerReleaseLoc.y-attackTargetGetsHit.y)^2
									+ (towerReleaseLoc.z+gsiUnit.releaseProjectileZ-attackTargetGetsHit.z)^2 )^0.5 --[[PROJECTILE BAKE]]
								/ hUnitProjectileSpeed,
						GameTime() - lastAttackTime < 0.067,
						true
			end
		elseif isRanged then
			local projectiles = attackTarget:GetIncomingTrackingProjectiles()
			local furthestProjectile
			local furthestDist = 0
			for i=0,#projectiles do
				local thisProjectile = projectiles[i]
				if thisProjectile then
					
					local projLoc = thisProjectile.location
					local projDist = ( (projLoc.x-attackedLoc.x)^2
							+ (projLoc.y-attackedLoc.y)^2 )^0.5
			--				+ (projLoc.z-attackedLoc.z)^2 )^0.5
					if thisProjectile.caster == hUnit
							and projDist > furthestDist then
						furthestDist = projDist
						furthestProjectile = thisProjectile
					end
				end
			end
			if furthestProjectile then
				local projLoc = furthestProjectile.location
				attackDist = ( (projLoc.x-attackTargetGetsHit.x)^2
						+ (projLoc.y-attackTargetGetsHit.y)^2 )^0.5
						--+ (projLoc.z-attackTargetGetsHit.z)^2 )^0.5
				if hUnit:CanBeSeen() and GameTime() - lastAttackTime < 0.0333 then
					
					update_apx_released_diff(gsiUnit.name,
							( furthestDist
								- ( (attackerLoc.x-attackedLoc.x)^2
									+ (attackerLoc.y-attackedLoc.y)^2 )^0.5
									--+ (attackerLoc.z-attackedLoc.z)^2 )^0.5
							) / hUnitProjectileSpeed
						)
				end
			end
			if attackDist then
				-- if the LHP attack node exists, LHP will update that node with the projectile timing for it's accuracy
				return attackTarget,
						attackDist / hUnitProjectileSpeed,
						false
			end
			return;
		end
		-- melee, or pre projectile ranged:
		
		attackDist = isRanged
				and ( (attackerLoc.x-attackTargetGetsHit.x)^2
					+ (attackerLoc.y-attackTargetGetsHit.y)^2 )^0.5
					--+ (attackedLoc.z-attackTargetGetsHit.z)^2 )^0.5

		
		return attackTarget,
				max(0.017, (isRanged and attackDist / hUnitProjectileSpeed or 0)
					+ (inAttackAnim and
							( attackPointPercent - animCycle -- it will also negate the after release time
								+ (thisAttackAnimHasReleased and 1 or 0)
							) * hUnit:GetSecondsPerAttack()
						or max(0, lastAttackTime + hUnit:GetSecondsPerAttack() - GameTime())
					) + (isRanged and get_apx_released_diff(gsiUnit.name) or 0)),
				isRanged
	end
end

-------- Projectile_ExtrapolateProjectileToSeenUnit()
function Projectile_ExtrapolateProjectileToSeenUnit(shootFrom, contact, castPointTime, projectileSpeed)
	local contactMovementVec = Vector_ScalarMultiply2D(
			Vector_DirectionalUnitMovingForward(contact),
			contact.hUnit:GetMovementDirectionStability()
		)

	if DEBUG then DebugDrawLine(contact.lastSeen.location, Vector_Addition(contact.lastSeen.location, contactMovementVec), 0, 255, 120) end
			
	local contactMovementVec = contactMovementVec
	local contactLoc = contactLoc or contact.lastSeen.location

	local distToThisB
	local timeGivenB = 0
	local thisBLoc = contactLoc
	for i=1,4 do -- correct collision location as chasing B per iteratively corrected time
		distToThisB = Vector_PointDistance2D(shootFrom, thisBLoc)
		timeGivenB = castPointTime + distToThisB / projectileSpeed
		thisBLoc = Vector_Addition(contactLoc,
				Vector_ScalarMultiply2D(contactMovementVec, timeGivenB)
			)
	end
			

	return thisBLoc, timeGivenB
end

function Projectile_SkillShotFogLocation(gsiPlayer, gsiEnemyHero, castPointTime, requiresTurn, shotSpeed)
	local playerLoc = gsiPlayer.lastSeen.location
	local enemyLastSeen = gsiEnemyHero.lastSeen
	local enemyLastSeenLoc = enemyLastSeen.location
	local enemyLastSeenPrevious = enemyLastSeen.previousLocation

	local releaseTime = castPointTime
			+ (not requiresTurn and 0
				or Projectile_TimeTilFacingDirectional(rad(gsiPlayer.hUnit:GetFacing()),
					Vector_PointToPointLine(playerLoc, enemyLastSeenLoc))
			)

	local approxExtrapolateT
	local extrapolatedLoc = enemyLastSeenLoc
	local timePrevToLast = enemyLastSeen.timeStamp - enemyLastSeen.previousTimeStamp
	local guessMoveVec = Vector(
			(enemyLastSeenLoc.x - enemyLastSeenPrevious.x)/timePrevToLast, 
			(enemyLastSeenLoc.y - enemyLastSeenPrevious.y)/timePrevToLast,
			0
		)
	for i=1,4 do
		approxExtrapolateT = releaseTime
				+ ((extrapolatedLoc.x-playerLoc.x)^2 + (extrapolatedLoc.y-playerLoc.y)^2)^0.5
					/ shotSpeed
		 extrapolatedLoc = Vector_Addition(
		 		enemyLastSeenLoc,
				Vector_ScalarMultiply(
					guessMoveVec,
					approxExtrapolateT
				)
			)
	end
	-- TODO Overshoots up/down stairs
	-- TODO Use previous location as an indicator of the accuracy of the facing direction -- however, a previous location value currently grows distant from the last seen over it's lifetime
	

	return extrapolatedLoc, approxExtrapolateT
end

-------- find_turn_rate()
local find_turn_rate
find_turn_rate = function(gsiPlayer)
	-- Dominate and find the turn rate in seconds
	local hUnit = gsiPlayer.hUnit
	-- TODO proper dominate prints
	local currTime = GameTime()
	local facing = hUnit:GetFacing()
	if not gsiPlayer.turnRateStartFind then
		hUnit:Action_ClearActions(true)
		gsiPlayer.turnRateStartFind = currTime + 0.099
		return;
	end
	if gsiPlayer.turnRateEndNow or currTime - gsiPlayer.turnRateStartFind > 2 then
		-- EXIT
		gsiPlayer.turnRate = gsiPlayer.turnRate or TURN_RATE_BASIC

		gsiPlayer.turnRateStartFind = nil
		gsiPlayer.turnRateStartSample = nil
		gsiPlayer.turnRateFirstSample = nil
		gsiPlayer.turnRateFirstSampleTime = nil
		gsiPlayer.turnRateEndNow = nil

		DOMINATE_print(gsiPlayer, true, "exiting", gsiPlayer.shortName)

		DOMINATE_SetDominateFunc(gsiPlayer, "projectile_find_turn_rate", find_turn_rate, false)

		return;
	end
	if not gsiPlayer.turnRateStartSampleTime then
		gsiPlayer.turnRateStartSampleTime = currTime + 0.099
	elseif gsiPlayer.turnRateStartSampleTime < currTime then
		if not gsiPlayer.turnRateFirstSample then
			if facing > 0 and facing < 45 then
				gsiPlayer.turnRateFirstSample = facing
				gsiPlayer.turnRateFirstSampleTime = currTime
			end
		elseif facing > 315 and facing < 360 then
			local rawRate = 1 + ( rad(facing) - rad(gsiPlayer.turnRateFirstSample) )
					/ (currTime - gsiPlayer.turnRateFirstSampleTime)






			gsiPlayer.turnRate = rawRate
			gsiPlayer.turnRateEndNow = true
			DOMINATE_print(gsiPlayer, true, 
					"[projectile] Turn rate is %.1f",
					gsiPlayer.turnRate
				)
			return;
		end
	end
	local moveTo = Vector_Addition(hUnit:GetLocation(),
			Vector_ScalarMultiply(
				Vector_UnitDirectionalFacingDirection((facing + 150) % 360),
				5
			)
		)
	hUnit:Action_MoveDirectly(moveTo)
end

function Projectile_Initialize()
	local teamPlayers = GSI_GetTeamPlayers(TEAM)
	for i=1,#teamPlayers do
		DOMINATE_SetDominateFunc(teamPlayers[i], "projectile_find_turn_rate", find_turn_rate, true)
	end
end
