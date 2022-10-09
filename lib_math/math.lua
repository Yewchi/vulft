-- Basic mathematical functions and trigonometry. 

local sqrt = math.sqrt
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
	return sqrt(v1.x^2 + v1.y^2)
end

function Math_DistanceOfLine(v1)
	return sqrt(v1.x^2 + v1.y^2 + v1.z^2)
end

function Math_PointToPointDistance2D(p1, p2)
	return sqrt((p2.x - p1.x)^2 + (p2.y - p1.y)^2)
end

function Math_PointCoordinatesDistance2D(x1, y1, x2, y2)
	return sqrt((x2 - x1)^2 + (y2 - y1)^2)
end

-- TODO Depreciate
function Math_PointToPointDistance(p1, p2)
	return sqrt((p2.x - p1.x)^2 + (p2.y - p1.y)^2 + (p2.z - p1.z)^2)
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
