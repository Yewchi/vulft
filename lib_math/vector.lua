-- Vector mathematical operations and logic (trig is in math.lua)
-- Fun and redundant!

-- TODO Free optimization using API - replace basic vector operations with API for release version

ZEROED_VECTOR = Vector(0, 0, 0)
ORTHOGONAL_Z = Vector(0, 0, 1)
ORTHOGONAL_Z_DOWN = Vector(0, 0, -1)

local world_bounds = GetWorldBounds()

local cos = math.cos
local sin = math.sin
local acos = math.acos
local rad = math.rad
local max = math.max
local min = math.min
local abs = math.abs
local sqrt = math.sqrt
local MATH_PI = math.pi
local MATH_2PI = 2*MATH_PI


function Vector_PointToPointLine(p1, p2)
	return Vector((p2.x - p1.x), (p2.y - p1.y), (p2.z - p1.z))
end
local Vector_PointToPointLine = Vector_PointToPointLine

function Vector_UnitFacingUnit(u1, u2)










	local u1Facing = u1.GetFacing and u1:GetFacing() or u1.hUnit:GetFacing()
	local u1Loc = u1.GetLocation and u1:GetLocation() or u1.lastSeen.location
	local u2Loc = u2.GetLocation and u2:GetLocation() or u2.lastSeen.location
	local directionVector = Vector_PointToPointLine(u1Loc, u2Loc)
	local directlyFacing = acos(directionVector.x / Vector_LengthOfVector(directionVector))
	directlyFacing = directionVector.y < 0 and MATH_2PI-directlyFacing or directlyFacing
	local unitFacing = rad(u1Facing)
	local radToTurn = unitFacing - directlyFacing
	return cos(radToTurn)
end
local Vector_UnitFacingUnit = Vector_UnitFacingUnit

function Vector_UnitFacingLoc(unit, loc)
	local unitFacing = unit.GetFacing and unit:GetFacing() or unit.hUnit:GetFacing()
	local unitLoc = unit.GetLocation and unit:GetLocation() or unit.lastSeen.location
	local directionVector = Vector_PointToPointLine(unitLoc, loc)
	local directlyFacing = acos(directionVector.x / Vector_LengthOfVector(directionVector))
	directlyFacing = directionVector.y < 0 and MATH_2PI-directlyFacing or directlyFacing
	local unitFacing = rad(unitFacing)
	local radToTurn = unitFacing - directlyFacing
	return cos(radToTurn)
end
local Vector_UnitFacingLoc = Vector_UnitFacingLoc

function Vector_PointToPointAngle(p1, p2)
	local directionVector = Vector_PointToPointLine(p1, p2)
	local angle = acos
end
local Vector_PointToPointAngle = Vector_PointToPointAngle

function Vector_PointWithinTriangle(p, q1, q2, q3)
	local X1 = Vector_CrossProduct2D(Vector_PointToPointLine(q1, q2), Vector_PointToPointLine(q2, p))
	local X2 = Vector_CrossProduct2D(Vector_PointToPointLine(q2, q3), Vector_PointToPointLine(q3, p))
	local X3 = Vector_CrossProduct2D(Vector_PointToPointLine(q3, q1), Vector_PointToPointLine(q1, p))
	
	if (X1 <= 0 and X2 <= 0 and X3 <= 0) or 
			(X1 >= 0 and X2 >= 0 and X3 >= 0) then
		return true
	end
	return false
end
local Vector_PointWithinTriangle = Vector_PointWithinTriangle

function Vector_SideOfPlane(p, q1, q2) -- i.e. Always use counter-clock-wise encapsulation if comparing to 1
	return Vector_CrossProduct2D(Vector_PointToPointLine(q1, q2), Vector_PointToPointLine(q2, p)) > 0 and 1 or -1
end
local Vector_SideOfPlane = Vector_SideOfPlane

function Vector_PointWithinStrip(p, base, top, delta)
	local directional = Vector_PointToPointLine(base, top)
	local unitNormal = Vector_ToDirectionalUnitVector(Vector_CrossProduct(directional, ORTHOGONAL_Z))
	local leftP1 = Vector(base.x+(-delta*unitNormal.x), base.y+(-delta*unitNormal.y), 0)
	local leftP2 = Vector(leftP1.x+directional.x, leftP1.y+directional.y, 0)
	local rightP1 = Vector(base.x+delta*unitNormal.x, base.y+delta*unitNormal.y, 0)
	local rightP2 = Vector(rightP1.x+directional.x, rightP1.y+directional.y, 0)









	-- Counter clock-wise (postive) encased
	return Vector_SideOfPlane(p, leftP1, rightP1) > 0
			and Vector_SideOfPlane(p, rightP1, rightP2) > 0
			and Vector_SideOfPlane(p, rightP2, leftP2) > 0
			and Vector_SideOfPlane(p, leftP2, leftP1) > 0
end
local Vector_PointWithinStrip = Vector_PointWithinStrip

function Vector_Equal(v1, v2)
	if type(v1.x) == "number" and type(v2.x) == "number" then
		if v1.x == v2.x and v1.y == v2.y and v1.z == v2.z then
			return true
		else
			return false
		end
	else
		print("/VUL-FT/ <WARN> vector: Incorrect parameters given to Vector_Equal"..Util_ParamString(v1, v2))
	end
end
local Vector_Equal = Vector_Equal

function Vector_PointBetweenPoints(p1, p2)
	return Vector((p1.x+p2.x)/2, (p1.y+p2.y)/2, (p1.z+p2.z)/2)
end
local Vector_PointBetweenPoints = Vector_PointBetweenPoints

function Vector_CrossProduct2D(v1, v2)
	return v1.x * v2.y - v1.y * v2.x
end
local Vector_CrossProduct2D = Vector_CrossProduct2D

-- I think this should be renamed "Vector_Orthogonal"
function Vector_CartesianNormal(v)
	return Vector_CrossProduct(v, ORTHOGONAL_Z)
end
local Vector_CartesianNormal = Vector_CartesianNormal

function Vector_CrossProduct(v1, v2) 
	return Vector(v1.y*v2.z - v1.z*v2.y, v1.z*v2.x - v1.x*v2.z, v1.x*v2.y - v1.y*v2.x)
end
local Vector_CrossProduct = Vector_CrossProduct

function Vector_Addition(v1, v2)
	return Vector(v1.x + v2.x, v1.y + v2.y, v1.z + v2.z)
end
local Vector_Addition = Vector_Addition

function Vector_ScalarMultiply2D(v, s)
	return Vector(v.x*s, v.y*s, v.z)
end
local Vector_ScalarMultiply2D = Vector_ScalarMultiply2D

function Vector_ScalarMultiply(v, s)
	return Vector(v.x*s, v.y*s, v.z*s)
end
local Vector_ScalarMultiply = Vector_ScalarMultiply

function Vector_LengthOfVector(v)
	return sqrt(v.x^2 + v.y^2 + v.z^2)
end
local Vector_LengthOfVector = Vector_LengthOfVector

function Vector_InverseVector(v)
	return Vector(-v.x, -v.y, -v.z)
end
local Vector_InverseVector = Vector_InverseVector

function Vector_PointDistance2D(p1, p2)
	return sqrt((p2.x - p1.x)^2 + (p2.y - p1.y)^2)
end
local Vector_PointDistance2D = Vector_PointDistance2D

function Vector_PointDistance(p1, p2)
	return sqrt((p2.x - p1.x)^2 + (p2.y - p1.y)^2 + (p2.z - p1.z)^2)
end
local Vector_PointDistance = Vector_PointDistance

function Vector_ToDirectionalUnitVector(v)
	local lengthOfVector = Vector_LengthOfVector(v)
	return Vector(v.x/lengthOfVector, v.y/lengthOfVector, v.z/lengthOfVector)
end
local Vector_ToDirectionalUnitVector = Vector_ToDirectionalUnitVector

function Vector_UnitDirectionalPointToPoint(v1, v2)
	return Vector_ToDirectionalUnitVector(Vector_PointToPointLine(v1, v2))
end
local Vector_UnitDirectionalPointToPoint = Vector_UnitDirectionalPointToPoint

function Vector_UnitDirectionalFacingDirection(degrees)
	local radians = degrees * MATH_PI / 180
	return Vector(cos(radians), sin(radians), 0)
end
local Vector_UnitDirectionalFacingDirection = Vector_UnitDirectionalFacingDirection

function Vector_DirectionalUnitMovingForward(gsiUnit, moveSpeed)
	local radians = gsiUnit.hUnit:GetFacing() * MATH_PI / 180
	moveSpeed = moveSpeed or gsiUnit.currentMovementSpeed or gsiUnit.hUnit:GetCurrentMovementSpeed()
	return Vector(cos(radians)*moveSpeed, sin(radians)*moveSpeed, 0)
end
local Vector_DirectionalUnitMovingForward = Vector_DirectionalUnitMovingForward

function Vector_GetNearestToUnitForUnits(gsiUnit, gsiUnitsTbl)
	local closestDist = 0xFFFF
	local closestUnit
	local gsiUnitLoc = gsiUnit.lastSeen.location
	for i=1,#gsiUnitsTbl do
		local thisUnit = gsiUnitsTbl[i]
		local dist = Vector_PointDistance2D(gsiUnitLoc, thisUnit.lastSeen.location)
		if dist < closestDist then
			closestDist = dist
			closestUnit = thisUnit
		end
	end
	return closestUnit, closestDist
end

function Vector_ScalePointToPointByFactor(p1, p2, scalar, limit)
	local unitDirectional = Vector_UnitDirectionalPointToPoint(p1, p2)
	local distanceToP2 = Math_PointToPointDistance2D(p1, p2)
	local distExpected = scalar * distanceToP2
	limit = limit or 0xFFFF
	return Vector_Addition(
			p1, 
			Vector_ScalarMultiply(
					unitDirectional,
					min(distExpected, limit)
				)
		), distanceToP2 < limit, distExpected <= limit
end

function Vector_ExtrapolateProjectileToSeenUnit(shootFrom, contact, projectileSpeed)
	local contactMovementVec = VEC_DIRECTIONAL_MOVES_FORWARD(contact)
	local contactLoc = contact.lastSeen.location

	-- brain dead approximation -- TODO try linear algebra
	-- 'A' == projectileLoc in time, 'B' == contactObject in time
	local distToThisB
	local timeGivenB = 0
	local thisBLoc = contactLoc
	print(contactMovementVec)
	for i=1,4 do -- correct collision location as chasing B per iteratively corrected time
		distToThisB = POINT_DISTANCE(shootFrom, thisBLoc)
		timeGivenB = distToThisB / projectileSpeed
		thisBLoc = VEC_ADDITION(contactLoc,
				VEC_SCALAR_MULTIPLY(contactMovementVec, timeGivenB)
			)
		print(thisBLoc, timeGivenB, distToThisB)
	end
			

	return thisBLoc, timeGivenB
end

-- "Diagonal Sum".. The sum of x and y are lower for start-of-lane radiant, 
--   and higher for start-of-lane dire
function Vector_SelectLowestDiagonal(v1, v2)
	if (v1.x + v1.y)<(v2.x + v2.y) then
		return v1
	end
	return v2
end

function Vector_SelectHighestDiagonal(v1, v2)
	if (v1.x + v1.y)>(v2.x + v2.y) then
		return v1
	end
	return v2
end

function Vector_WithinWorldBounds(v, padding)
	if (
			(v.x < 0 and v.x > world_bounds[1] + padding)
				or (v.x >= 0 and v.x < world_bounds[3] - padding)
		) and (
			(v.y < 0 and v.y > world_bounds[2] + padding)
				or (v.y >= 0 and v.y < world_bounds[4] - padding)
		) then
		return true
	end
	return false
end

function Vector_BoundedToWorld(v)
	v.x = max(world_bounds[1], min(v.x, world_bounds[3]))
	v.y = max(world_bounds[2], min(v.y, world_bounds[4]))
	return v
end
