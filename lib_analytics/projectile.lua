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

local acos = math.acos
local rad = math.rad
local abs = math.abs
local max = math.max
local sqrt = math.sqrt

local TURN_RATE_BASIC = 0.9 / 0.03 -- higher-end (turnRate rad) / tickRate 
local START_CAST_RAD = rad(11.5) -- 0.201 rad - source:dota2 gamepedia 02/14/21

function Projectile_TimeTilFacingDirectional(facingRad, v)
	-- TODO there's probably some simpler rule for this
	local goalDirection = acos(rad(v.x / Vector_LengthOfVector(v)))
	goalDirection = v.y < 0 and MATH_2PI-goalDirection or goalDirection
	local turnRad = abs(facingRad - goalDirection)
	turnRad = max(0, abs(turnRad > MATH_PI and MATH_2PI - turnRad - START_CAST_RAD or turnRad - START_CAST_RAD))
	return turnRad / TURN_RATE_BASIC 
end
local Projectile_TimeTilFacingDirectional = Projectile_TimeTilFacingDirectional

-- a.b = |a||b|cos(t).
-- let a = directionalVector, b = unit vector (1, 0, 0)
-- .'. [ax + 0 + 0] = |a|*1 cos(t)
-- .'. cos(t) = ax/|a|
-- .'. t = arccos(ax/|a|) :: (The abs(rotational shift) from the 0th degree of a directional vector for either rotation)

function Projectile_TimeToLandProjectile(gsiUnit, gsiTarget)
	local hUnit = gsiUnit.hUnit
	local hUnitTarget = gsiTarget.hUnit
	local attackPointPercent = gsiUnit.attackPointPercent
	local hUnitProjectileSpeed = gsiUnit.isRanged and gsiUnit.hUnit:GetAttackProjectileSpeed() or 160000
	local facingDeg = hUnit:GetFacing() -- skipping for now, don't know turning speed algorithm nor func
	local directionalToTarget = Vector_PointToPointLine(gsiUnit.lastSeen.location, gsiTarget.lastSeen.location)
	local timeToTurn = Projectile_TimeTilFacingDirectional(rad(facingDeg), directionalToTarget)
	local timeToArriveAtAttack = max(Math_PointToPointDistance2D(gsiUnit.lastSeen.location, gsiTarget.lastSeen.location)
			- gsiUnit.attackRange, 0)/gsiUnit.currentMovementSpeed
	return Vector_LengthOfVector(directionalToTarget)
			/ hUnitProjectileSpeed
			+ attackPointPercent * hUnit:GetSecondsPerAttack() + timeToTurn + timeToArriveAtAttack
end

function Projectile_GetNextAttackComplete(gsiUnit)
	local hUnit = gsiUnit.hUnit
	if not hUnit:CanBeSeen() then
		return 
	end
	-- TODO turning time is time till start attack
	local attackTarget = hUnit:GetAttackTarget()
	local hUnitProjectileSpeed = hUnit:GetAttackProjectileSpeed()
	hUnitProjectileSpeed = hUnitProjectileSpeed ~= 0 and hUnitProjectileSpeed or 800000
	
	if attackTarget then
		local attackPointPercent = gsiUnit.attackPointPercent
		local animCycle = hUnit:GetAnimCycle()
		local thisAttackYetToRelease = animCycle <= attackPointPercent
		local attackDist
		if gsiUnit.isRanged then
			if gsiUnit.isTower then
				return gsiUnit.hUnit:GetLastAttackTime()
						+ Math_PointToPointDistance(gsiUnit.lastSeen.location, attackTarget:GetLocation())
								/ hUnitProjectileSpeed
						+ TOWER_ATTACK_EST_ADDED_TIME
			end
			local projectiles = attackTarget:GetIncomingTrackingProjectiles()
			for i=1,#projectiles do
				if projectiles.caster == hUnit then
					attackDist = Math_PointToPointDistance(projectiles.location, attackTarget:GetLocation())
					break;
				end
			end
		end
		attackDist = attackDist or Math_PointToPointDistance(gsiUnit.lastSeen.location, attackTarget:GetLocation())
		if thisAttackYetToRelease then
			--if gsiUnit.type == UNIT_TYPE_BUILDING then print("building", hUnitProjectileSpeed, attackPoint, animCycle, hUnit:GetSecondsPerAttack(), Math_PointToPointDistance2D(gsiUnit.lastSeen.location, attackTarget:GetLocation()))
			--TEAM_CAPTAIN_UNIT:ActionImmediate_Chat("Building attack lands in"..(Math_PointToPointDistance2D(gsiUnit.lastSeen.location, attackTarget:GetLocation())
			--		/ hUnitProjectileSpeed
			--		+ attackPointPercent * hUnit:GetSecondsPerAttack()), true) end
			return attackTarget,
					attackDist / hUnitProjectileSpeed
						+ (attackPointPercent - animCycle) * hUnit:GetSecondsPerAttack()
		end
	end
end

-------- Projectile_TimeToLandProjectile()
function Projectile_TimeToLandProjectile(gsiUnit, gsiTarget)
	local hUnit = gsiUnit.hUnit
	local hUnitTarget = gsiTarget.hUnit
	local attackPointPercent = gsiUnit.attackPointPercent
	local hUnitProjectileSpeed = gsiUnit.isRanged and gsiUnit.hUnit:GetAttackProjectileSpeed() or 160000
	local facingDeg = hUnit:GetFacing() -- skipping for now, don't know turning speed algorithm nor func
	local directionalToTarget = Vector_PointToPointLine(gsiUnit.lastSeen.location, gsiTarget.lastSeen.location)
	local timeToTurn = Projectile_TimeTilFacingDirectional(rad(facingDeg), directionalToTarget)
	local timeToArriveAtAttack = max(Math_PointToPointDistance2D(gsiUnit.lastSeen.location, gsiTarget.lastSeen.location)
			- gsiUnit.attackRange, 0)/gsiUnit.currentMovementSpeed
	return Vector_LengthOfVector(directionalToTarget)
			/ hUnitProjectileSpeed
			+ attackPointPercent * hUnit:GetSecondsPerAttack() + timeToTurn + timeToArriveAtAttack
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
				+ sqrt((extrapolatedLoc.x+playerLoc.x)^2 + (extrapolatedLoc.y+playerLoc.y)^2)
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
