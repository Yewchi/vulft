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
local MATH_PI = math.pi
local MATH_2PI = 2*MATH_PI
local RADIAN90 = MATH_PI/2
local RADIAN270 = MATH_PI*3/2
local Vector = Vector

local analytical_unit_vecs = {} -- for approx rads shifts
for i=1,60 do -- 1.5 degrees space, or about 270 unit variance at 10,000 dist.

end
function Vector_PointToPointLine(p1, p2)
	return Vector((p2.x - p1.x), (p2.y - p1.y), (p2.z - p1.z))
end
local Vector_PointToPointLine = Vector_PointToPointLine

function Vector_PointToPointLine2D(p1, p2)
	return Vector(p2.x-p1.x, p2.y-p1.y, 0)
end

function Vector_CrossProduct2D(v1, v2)
	return v1.x * v2.y - v1.y * v2.x
end
local Vector_CrossProduct2D = Vector_CrossProduct2D

function Vector_CrossProduct(v1, v2) 
	return Vector(v1.y*v2.z - v1.z*v2.y, v1.z*v2.x - v1.x*v2.z, v1.x*v2.y - v1.y*v2.x)
end
local Vector_CrossProduct = Vector_CrossProduct

function Vector_PointBetweenPoints(p1, p2)
	return Vector((p1.x+p2.x)/2, (p1.y+p2.y)/2, (p1.z+p2.z)/2)
end
local Vector_PointBetweenPoints = Vector_PointBetweenPoints

-- I think this should be renamed "Vector_Orthogonal" -- 27/03/23 -- no refactored because it should allow modifying the orthogonal-z sign
function Vector_CartesianNormal(v)
	return Vector(v.y, -v.x, 0)
end
local Vector_CartesianNormal = Vector_CartesianNormal

function Vector_DotProduct(v1, v2)
	return v1.x*v2.x + v1.y*v2.y + v1.z*v2.z
end
local Vector_DotProduct = Vector_DotProduct

function Vector_Addition(v1, v2)
	return Vector(v1.x + v2.x, v1.y + v2.y, v1.z + v2.z)
end
local Vector_Addition = Vector_Addition

-- and this would be the fix \/\/\/\/\/\/
function Vector_ScalarMultiply2D(v, s)
	--return Vector(v.x*s, v.y*s, v.z)
	return Vector(v.x*s, v.y*s, 0)
end
local Vector_ScalarMultiply2D = Vector_ScalarMultiply2D

-- Wondering if 3D scalar mutliply is the reason for off-map messages
function Vector_ScalarMultiply(v, s)
	return Vector(v.x*s, v.y*s, v.z*s)
end
local Vector_ScalarMultiply = Vector_ScalarMultiply

function Vector_LengthOfVector(v)
	return (v.x^2 + v.y^2 + v.z^2)^0.5
end
Vector_Length = Vector_LengthOfVector
local Vector_LengthOfVector = Vector_LengthOfVector

function Vector_InverseVector(v)
	return Vector(-v.x, -v.y, -v.z)
end
local Vector_InverseVector = Vector_InverseVector
Vector_Inverse = Vector_InverseVector

function Vector_PointDistance2D(p1, p2)
	return ((p2.x - p1.x)^2 + (p2.y - p1.y)^2)^0.5
end
local Vector_PointDistance2D = Vector_PointDistance2D

function Vector_PointDistance(p1, p2)
	return ((p2.x - p1.x)^2 + (p2.y - p1.y)^2 + (p2.z - p1.z)^2)^0.5
end
local Vector_PointDistance = Vector_PointDistance

-- Only use Vector_GsiDistance when the target known-seen/unseen logically.
-------- Vector_GsiDistance()
function Vector_GsiDistance(gsi1, gsi2)
	local a = gsi1.lastSeen.location
	local b = gsi2.lastSeen.location
	return ((a.x-b.x)^2 + (a.y-b.y)^2 + (a.z-b.z)^2)^0.5
end
function Vector_GsiDistance2D(gsi1, gsi2)
	local a = gsi1.lastSeen.location
	local b = gsi2.lastSeen.location
	return ((a.x-b.x)^2 + (a.y-b.y)^2)^0.5
end

local suppress_zero = 5
function Vector_ToDirectionalUnitVector(v)
	local lengthOfVector = (v.x^2 + v.y^2 + v.z^2)^0.5
	if lengthOfVector <= 0.00001 then
		if suppress_zero > 0 or DEBUG then
			
			suppress_zero = suppress_zero - 1
			WARN_print(string.format(
						"[vector] unit vec of 0-length. %s",
						(suppress_zero > 0 and "" or "-- squelching message")
					)
				)
		end
		return Vector(0, 0, 0)
	end
	return Vector(v.x/lengthOfVector, v.y/lengthOfVector, v.z/lengthOfVector)
end
local Vector_ToDirectionalUnitVector = Vector_ToDirectionalUnitVector

function Vector_ToDirectionalUnitVector2D(v)
	local len = (v.x^2 + v.y^2)^0.5
	if len <= 0.00001 then
		if suppress_zero > 0 or DEBUG then
			
			suppress_zero = suppress_zero - 1
			WARN_print(string.format(
						"[vector] unit vec of 0-length. %s",
						(suppress_zero > 0 and "" or "-- squelching message")
					)
				)
		end
		return Vector(0, 0, 0)
	end
	return Vector(v.x/len, v.y/len, 0)
end

function Vector_UnitDirectionalPointToPoint(v1, v2)
	local v1v2 = Vector(v2.x-v1.x, v2.y-v1.y, v2.z-v1.z)
	local len = (v1v2.x^2 + v1v2.y^2 + v1v2.z^2)^0.5
	v1v2.x = v1v2.x/len
	v1v2.y = v1v2.y/len
	v1v2.z = v1v2.z/len
	return v1v2
end
local Vector_UnitDirectionalPointToPoint = Vector_UnitDirectionalPointToPoint

function Vector_UnitDirectionalPointToPoint2D(v1, v2)
	local v1v2 = Vector(v2.x-v1.x, v2.y-v1.y, 0)
	local len = (v1v2.x^2 + v1v2.y^2)^0.5
	v1v2.x = v1v2.x/len
	v1v2.y = v1v2.y/len
	return v1v2
end
local Vector_UnitDirectionalPointToPoint2D = Vector_UnitDirectionalPointToPoint2D

-- poorly named TODO REFACTOR
-------- Vector_PointToPointLimited()
function Vector_PointToPointLimited(p1, p2, limit)
	return Vector_Addition(p1,
			Vector_ScalarMultiply(Vector_UnitDirectionalPointToPoint(
					p1, p2
				),
				limit
			)
		)
end

-- TODO REFACTOR to PointToPointLimited
-------- Vector_PointToPointLimitedMin2D()
function Vector_PointToPointLimitedMin2D(p1, p2, limit)
	local pt2pt = Vector(p2.x-p1.x, p2.y-p1.y, 0)
	local len = (pt2pt.x^2 + pt2pt.y^2)^0.5
	if len < limit then
		pt2pt.x = p2.x; pt2pt.y = p2.y; -- safer than p2 itself
		return pt2pt
	end
	len = limit/len
	pt2pt.x = p1.x + pt2pt.x*len; pt2pt.y = p1.y + pt2pt.y*len;
	return pt2pt
end

function Vector_ToLength(v, length)
	local vLen = (v.x^2 + v.y^2 + v.z^2)^0.5
	local factor = length/vLen
	return Vector(v.x*factor, v.y*factor, v.z*factor)
end

function Vector_ToLength2D(v, length, keepZ)
	local vLen = (v.x^2 + v.y^2)^0.5
	local factor = length/vLen
	return Vector(v.x*factor, v.y*factor, keepZ and v.z or 0)
end

function Vector_PointToPointAtDistance(p1, p2, dist)
	return Vector( p1.x + (p2.x-p1.x)*dist,
			p1.y + (p2.y-p1.y)*dist, 
			p1.z + (p2.z-p1.z)*dist )
end

function Vector_ProgressBetweenPoints2D(p1, p2, progress)
	local shift = Vector(p2.x-p1.x, p2.y-p1.y)
	local len = (shift.x^2 + shift.y^2)^0.5
	shift.x = shift.x*progress + p1.x
	shift.y = shift.y*progress + p1.y
	return shift
end

function Vector_UnitDirectionalFacingDirection(degrees) -- TODO REFACTOR DEGREES NAME OR STANDARDIZE RADS IN
	local radians = degrees * MATH_PI / 180
	return Vector(cos(radians), sin(radians), 0)
end
Vector_UnitDirectionalFacingDegrees = Vector_UnitDirectionalFacingDirection
local Vector_UnitDirectionalFacingDirection = Vector_UnitDirectionalFacingDirection

function Vector_UnitFacingUnit(u1, u2)










	local u1Facing = u1.GetFacing and u1:GetFacing() or u1.hUnit:GetFacing()
	local u1Loc = u1.GetLocation and u1:GetLocation() or u1.lastSeen.location
	local u2Loc = u2.GetLocation and u2:GetLocation() or u2.lastSeen.location
	local directionVector = Vector(u2Loc.x - u1Loc.x, u2Loc.y - u1Loc.y, 0)
	local directlyFacing = acos(directionVector.x / ((directionVector.x^2 + directionVector.y^2)^0.5))
	directlyFacing = directionVector.y < 0 and MATH_2PI-directlyFacing or directlyFacing
	local unitFacing = rad(u1Facing)
	local radToTurn = unitFacing - directlyFacing
	return cos(radToTurn)
end
local Vector_UnitFacingUnit = Vector_UnitFacingUnit

function Vector_FacingAtLength(gsiUnit, len)
	local facingVec = Vector_UnitDirectionalFacingDirection(
			gsiUnit.lastSeen.facingDegrees
		)
	local unitLoc = gsiUnit.lastSeen.location 
	facingVec.x = facingVec.x * len + unitLoc.x
	facingVec.y = facingVec.y * len + unitLoc.y
	return facingVec
end

function Vector_UnitFacingLoc(unit, loc)
	local unitFacing = unit.GetFacing and unit:GetFacing() or unit.hUnit:GetFacing()
	local unitLoc = unit.GetLocation and unit:GetLocation() or unit.lastSeen.location
	local directionVector = Vector(loc.x-unitLoc.x, loc.y-unitLoc.y)
	local directlyFacing = acos(directionVector.x / ((directionVector.x^2 + directionVector.y^2)^0.5))
	directlyFacing = directionVector.y < 0 and MATH_2PI-directlyFacing or directlyFacing
	local unitFacing = rad(unitFacing)
	local radToTurn = unitFacing - directlyFacing
	return cos(radToTurn)
end
local Vector_UnitFacingLoc = Vector_UnitFacingLoc

function Vector_UnitFacingRads(unit, rads)
	local unitFacingRads = (unit.GetFacing and unit:GetFacing() or unit.hUnit:GetFacing()) * MATH_PI / 180
	local absDifference = abs(rads - unitFacingRads)
	absDifference = absDifference > MATH_PI and MATH_2PI - absDifference or absDifference
	return cos(absDifference)
end

function Vector_GetRadsUnitToLoc(unit, loc)
	local unitLoc = unit.GetLocation and not unit:IsNull() and unit:GetLocation() or unit.lastSeen.location
	local directionVector = Vector_PointToPointLine(unitLoc, loc)
	local facingRads = acos(directionVector.x / Vector_LengthOfVector(directionVector))
	facingRads = directionVector.y < 0 and MATH_2PI-facingRads or facingRads
	return facingRads
end

function Vector_PointToPointRads(p1, p2)
	local directionVector = Vector_PointToPointLine(p1, p2)
	local radsAngle = acos(directionVector.x / (directionVector.x^2 + directionVector.y^2)^0.5)
	radsAngle = directionVector.y < 0 and MATH_2PI - radsAngle or radsAngle
	return radsAngle
end
local Vector_PointToPointRads = Vector_PointToPointRads

-------- Vector_BRads()
function Vector_BRads2D(a, b, c)
	-- using cos(th) = (|AB|^2 + |BC|^2 - |CA|^2) / (2*|AB||BC|)
	local abSq = (a.x-b.x)^2 + (a.y-b.y)^2
	local bcSq = (c.x-b.x)^2 + (c.y-b.y)^2
	local caSq = (a.x-c.x)^2 + (a.y-c.y)^2
	return acos((abSq + bcSq - caSq)/(2*(abSq*bcSq)^0.5))
end

-------- Vector_BRadsProgressToC()
function Vector_BRadsProgressToC(A, B, C, p, limitRange)
	local ABv = Vector(B.x-A.x, B.y-A.y)
	local lenAB = (ABv.x^2 + ABv.y^2)^0.5
	local ABRads = acos(ABv.x / lenAB)
	local ACx = C.x - A.x
	local ACy = C.y - A.y
	local lenAC = (ACx^2 + ACy^2)^0.5
	local ACRads = (ACx / lenAC)
end

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
	return (q2.x-q1.x)*(p.y-q2.y) - (q2.y-q1.y)*(p.x-q2.x) > 0 and 1 or -1
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

-------- Vector_PointWithinStripDirectional()
function Vector_PointWithinStripDirectional(p, base, directional, delta)
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
local Vector_PointWithinStripDirectional = Vector_PointWithinStripDirectional

-------- Vector_PointWithinCone()
function Vector_PointWithinCone(p, base, height, projectingRads, halfRadiansSpread)
	local distanceFromBase = ((p.x - base.x)^2 + (p.y - base.y)^2 + (p.z - base.z)^2)^0.5
	local baseP = Vector(p.x - base.x, p.y - base.y, 0)
	local radsDiff = abs(acos(baseP.x / distanceFromBase) - projectingRads)
	radsDiff = radsDiff > MATH_PI and MATH_2PI - radsDiff or radsDiff
	return radsDiff < halfRadiansSpread and distanceFromBase < height, distanceFromBase, radsDiff
end
local Vector_PointWithinCone = Vector_PointWithinCone

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

function Vector_DirectionalUnitMovingForward(gsiUnit, moveSpeed, moveSpeedFactor)
	local radians = gsiUnit.hUnit:GetFacing() * MATH_PI / 180
	moveSpeed = moveSpeed or gsiUnit.currentMovementSpeed or gsiUnit.hUnit:GetCurrentMovementSpeed()
			* (moveSpeedFactor or 1)
	return Vector(cos(radians)*moveSpeed, sin(radians)*moveSpeed, 0)
end
local Vector_DirectionalUnitMovingForward = Vector_DirectionalUnitMovingForward

function Vector_DirectionalUnitMovingForwardToRads(gsiUnit, moveSpeed, moveSpeedFactor, radForwards)
	moveSpeed = moveSpeed or gsiUnit.currentMovementSpeed or gsiUnit.hUnit:GetCurrentMovementSpeed()
			* (moveSpeedFactor or 1)
	return Vector(cos(radForwards)*moveSpeed, sin(radForwards)*moveSpeed, 0)
end
local Vector_DirectionalUnitMovingForward = Vector_DirectionalUnitMovingForward

function Vector_DistancePointToLine2D(P, lp1, lp2)
	local lp1Lp2 = Vector(lp2.x-lp1.x, lp2.y-lp1.y, 0)
	local lengthLp1Lp2 = (lp1Lp2.x^2 + lp1Lp2.y^2)^0.5
	local lp1P = Vector(P.x-lp1.x, P.y-lp1.y, 0)
	local lengthLp1P = (lp1P.x^2 + lp1P.y^2)^0.5
	local angle = acos(
			(lp1Lp2.x*lp1P.x + lp1Lp2.y*lp1P.y) -- lp1lp2.lp1P
				/ (lengthLp1Lp2 * lengthLp1P) -- / (|lp1lp2|*|lp1P|)
		)
	return lengthLp1P * sin(angle)
end
local Vector_DistancePointToLine2D = Vector_DistancePointToLine2D

function Vector_DistancePointToLine(P, lp1, lp2)
	local lp1Lp2 = Vector(lp2.x-lp1.x, lp2.y-lp1.y, lp2.z-lp1.z)
	local lengthLp1Lp2 = (lp1Lp2.x^2 + lp1Lp2.y^2 + lp1Lp2.z^2)^0.5
	local lp1P = Vector(P.x-lp1.x, P.y-lp1.y, P.z-lp1.z)
	local lengthLp1P = (lp1P.x^2 + lp1P.y^2 + lp1P.z^2)^0.5
	local angle = acos(
			(lp1Lp2.x*lp1P.x + lp1Lp2.y*lp1P.y + lp1Lp2.z*lp1P.z)
				/ (lengthLp1Lp2 * lenthLp1P)
		)
	return lengthLp1P * sin(angle)
end
local Vector_DistancePointToLine = Vector_DistancePointToLine

function Vector_DistUnitToUnit(unit1, unit2)
	unit1 = unit1.hUnit and unit1.lastSeen.location
			or unit1:GetLocation()
	unit2 = unit2.hUnit and unit2.lastSeen.location
			or unit2:GetLocation()
	return ((unit1.x-unit2.x)^2 + (unit1.y-unit2.y)^2 + (unit1.z-unit2.z)^2)^0.5
end

function Vector_DistUnitToUnit2D(unit1, unit2)
	unit1 = unit1.hUnit and unit1.lastSeen.location
			or unit1:GetLocation()
	unit2 = unit2.hUnit and unit2.lastSeen.location
			or unit2:GetLocation()
	print(unit1.x, unit1.y, unit2.x, unit2.y)
	return ((unit1.x-unit2.x)^2 + (unit1.y-unit2.y)^2)^0.5
end

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
	return Vector(
			max(world_bounds[1], min(v.x, world_bounds[3])),
			max(world_bounds[2], min(v.y, world_bounds[4])),
			v.z
		)
end

local function get_bezier_xy1(self, progress)
	-- Waiting for an application
end

local function get_bezier_xy2(self, progress)
	local p0 = self.p0
	local p1 = self.p1
	local p2 = self.p2
	local Ax = p0[1] + progress*(p1[1] - p0[1])
	local Ay = p0[2] + progress*(p1[2] - p0[2])
	local Bx = p1[1] + progress*(p2[1] - p1[1])
	local By = p1[2] + progress*(p2[2] - p1[2])
	local val = self.val or Vector(0, 0, 0)
	val.x = Ax + progress*(Bx-Ax)
	val.y = Ay + progress*(By-Ay)
	val.z = 0
	self.val = val
	self.progress = progress
	return self.val
end

local function get_bezier_xy3(self, progress)
	-- Waiting for an application
end

local function get_bezier_xy4(self, progress)
	-- Waiting for an application
end

local function get_bezier_forwards(self, progress, andUpdate)
	local valSave = self.val
	local progressSave = self.progress
	local forwardsVal = self:compute(progressSave+progress)
	local forwardsProgress = self.progress
	if not andUpdate then
		self.val = valSave
		self.progress = progressSave
	end
	return forwardsVal, forwardsProgress, valSave ~= nil
end

function Vector_CreateBezierFunction(p0, p1, p2, p3, p4)
	local newBezier = {}
	if not p0 or not p1 then
		ERROR_print(true, DEBUG,
				"[vector] attempt to create a bezier without a required arg. %s", 
				Util_ParamString(p0, p1, p2, p3, p4)
			)
		return nil;
	end
	newBezier.computeForwards = get_bezier_forwards
	newBezier.p0 = p0
	newBezier.p1 = p1
	if not p2 then newBezier.compute = get_bezier_xy1 return newBezier end
	newBezier.p2 = p2
	if not p3 then newBezier.compute = get_bezier_xy2 return newBezier end
	newBezier.p4 = p4
	if not p4 then newBezier.compute = get_bezier_xy3 return newBezier end
	newBezier.p5 = p5
	newBezier.compute = get_bezier_xy4

	return newBezier
end
