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

-- Basic mathematical functions and trigonometry. 

local floor = math.floor
MATH_PI = math.pi
MATH_2PI = 2*MATH_PI
MATH_TAU = MATH_2PI

COSIGN_45_TO_A_OR_B_LENGTH_RATIO = math.cos(1)

require(GetScriptDirectory().."/lib_math/vector")

function B_AND(b1, b2) -- use band() instead
	local andValue = 0
	local bit = 1
	while(b1 >= 1 and b2 >= 1) do
		andValue = andValue + (b1 % 2 == 1 and b2 % 2 == 1 and bit or 0)
		bit = bit * 2
		b1 = floor(b1 / 2)
		b2 = floor(b2 / 2)
	end
	return andValue
end

function Math_DivisorSafe5Dec(val)
	if val >= 0 then
		return val < 0.00001 and 0.00001 or val
	else
		return val > -0.00001 and -0.00001 or val
	end
end

function Math_DistanceOfLine2D(v1)
	return (v1.x^2 + v1.y^2)^0.5
end

function Math_DistanceOfLine(v1)
	return (v1.x^2 + v1.y^2 + v1.z^2)^0.5
end

function Math_PointToPointDistance2D(p1, p2)
	return ((p2.x - p1.x)^2 + (p2.y - p1.y)^2)^0.5
end

function Math_PointCoordinatesDistance2D(x1, y1, x2, y2)
	return ((x2 - x1)^2 + (y2 - y1)^2)^0.5
end

-- TODO Depreciate
function Math_PointToPointDistance(p1, p2)
	return ((p2.x - p1.x)^2 + (p2.y - p1.y)^2 + (p2.z - p1.z)^2)^0.5
end

local lastWarn = 0
function Math_ETA(gsiPlayer, dest)
	return Math_PointToPointDistance2D(gsiPlayer.lastSeen.location, dest) / gsiPlayer.currentMovementSpeed
end

function Math_ETAFromLoc(gsiPlayer, start, dest)
	return Math_PointToPointDistance2D(start, dest) / gsiPlayer.currentMovementSpeed
end

function Math_ScreenCoordsToCartesianCentered(fScreenX, fScreenY, dampening)
	return fScreenX*dampening + 960, fScreenY*dampening + 540
end

--[[
local QUADRATIC_I__EXPONENTS = 1
local QUADRATIC_I__COFACTORS = 2
local QUADRATIC_I__MODIFY_FIRST = 3
local function get_quadratic_value(self, x)
	local value = 0
	if self.modify and self[3] then
		self:modify()
	end
	for i=1,#self[2] do
		value = value + self[3][i] * x^self[2][i]
	end
	if self.modify and not self[3] then
		self:modify()
	end
	self.val = value
	self.timeStamp = GameTime()
	return value
end
function Math_CreateQuadraticFunction(specialModificationFunction, modifyFirst, ...)
	local args = {...}
	local newQuadratic = {}
	local i = 1
	while(args[i]) do
		local exponent = args[i]
		local cofactor = args[i+1]
		if not cofactor then
			--FIX THISERROR_print("[math] Attempt to create a quadratic without a cofactor at even index %s.", i)
			print(debug.traceback())
		end
		newQuadratic[1][(i+1) / 2] = exponent
		newQuadratic[2][(i+1) / 2] = cofactor
		i = i + 2
	end
	newQuadratic.compute = get_quadratic_value
	newQuadratic.modify = specialModificationFunction
	newQuadratic[3] = modifyFirst
	newQuadratic.shortName = "QuadraticFunction"
	return newQuadratic
end

local function get_multivariable_value(self, t)
	local vector = self.val or Vector(0, 0, 0)
	local countValues = max(#self.x, #self.y, #self.z)
	for i=1,countValues do
		if self.x[i] then
			vector.x = vector.x 
			-- TODO ect
		end
	end
	self.val = vector
	self.timeStamp = GameTime()
	return vector
end

-- Provide x y z cofactors and x y z rate of change over 't'.
-- Very permissive with nil coordinates for additional single-coordinate computation
-- 'Linear' for the rate of change, not necessarily the shape of the line it draws
-------- Math_CreateLinearMultivariableFunctionXYZ()
function Math_CreateLinearMultivariableFunctionXYZ(...)
	local args = {...}
	local newMultivariable = {}
	local i = 1
	while(args[i] or args[i+1] or args[i+2]) do
		local productIndex = (i + 5) / 6
		if args[i] then
			newMultivariable.x = newMultivariable.x or {}
			newMultivariable.dx = newMultivariable.dx or {}
			newMultivariable.x[productIndex] = args[i]
			newMultivariable.dx[productIndex] = args[i+3] or 0
		end
		if args[i+1] then
			newMultivariable.y = newMultivariable.y or {}
			newMultivariable.dy = newMultivariable.dy or {}
			newMultivariable.y[productIndex] = args[i+1]
			newMultivariable.dy[productIndex] = args[i+4] or 0
		end
		if args[i+2] then
			newMultivariable.z = newMultivariable.z or {}
			newMultivariable.dz = newMultivariable.dz or {}
			newMultivariable.z[productIndex] = args[i+2]
			newMultivariable.dz[productIndex] = args[i+5] or 0
		end
		local i = i + 6
	end
	newMultivariable.shortName = "LinearMultivariableFunction"
	newMultivariable.compute = get_multivariable_value
end
--]]

-- (using y because the value is probably a resultant value, and this is a logical limiter, not arithmetic, or not a truely mathematically limit) Simplistic half-range flip from 1.5*d/dy + 0.5*d/dy = avg d/dy over range until trueMaximumY
-- Function is used to avoid any complicated maximums, minimums, or ammended mathematical functions with desired limits that would otherwise use heavy mathematical operations
function Math_GetFastThrottledBounded(y, startThrottling, maximumThrottledBounded, trueMaximumY)
	if y > trueMaximumY then return maximumThrottledBounded
	elseif y > startThrottling then
		local over = (y - startThrottling)
		local throttleTrueRange = trueMaximumY - startThrottling
		local throttleRange = maximumThrottledBounded - startThrottling
		local avgRateOfChange = throttleRange / throttleTrueRange
		local lowHalfRate = avgRateOfChange * 1.5
		local halfThrottleRange = throttleRange / 2
		if over > halfThrottleRange then
			local highHalfRate = avgRateOfChange * 0.5
			return startThrottling + halfThrottleRange*lowHalfRate + (over - halfThrottleRange)*highHalfRate
		else
			return startThrottling + over*lowHalfRate
		end
	else return y end
end

function Math_GetRandStandardDeviation(y, range68, range16)
	local f = RandomFloat(0, 1)
	if f > 0.16 then
		if f < 0.84 then
			local lowCenter = y - range68 / 2
			f = RandomFloat(0, 1)
			return lowCenter + range68*f
		else
			local highCenter = y + range68 / 2
			f = RandomFloat(0, 1)
			return highCenter + range16*f
		end
	else
		local lowCenter = y - range68 / 2
		return lowCenter - range16*f/0.16
	end
end
