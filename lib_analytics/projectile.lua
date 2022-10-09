-- Projectiles and attack-time calculations (the tools of last_hit_projection.lua)
local MATH_PI = MATH_PI
local MATH_2PI = MATH_2PI

local TOWER_ATTACK_EST_ADDED_TIME = 0.033*5

local acos = math.acos
local rad = math.rad
local abs = math.abs
local max = math.max

local TURN_RATE_BASIC = 0.9 / 0.03 -- higher-end (turnRate rad) / tickRate 
local START_CAST_RAD = rad(11.5) -- 0.201 rad - source:dota2 gamepedia 02/14/21

local function time_to_turn_facing_to_directional(facingRad, v)
	-- TODO there's probably some simpler rule for this
	local goalDirection = acos(rad(v.x / Vector_LengthOfVector(v)))
	goalDirection = v.y < 0 and MATH_2PI-goalDirection or goalDirection
	local turnRad = facingRad - goalDirection
	turnRad = max(0, abs(turnRad > MATH_PI and MATH_2PI - turnRad - START_CAST_RAD or turnRad - START_CAST_RAD))
	return turnRad / TURN_RATE_BASIC 
end

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
	local timeToTurn = time_to_turn_facing_to_directional(rad(facingDeg), directionalToTarget)
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
