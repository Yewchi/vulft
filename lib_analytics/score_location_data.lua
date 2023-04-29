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

-- High complexity algorithmns, store time data of results.
local garbage_tables = {}

SCORE_LOCS_INSTANT_SPEED = 0xFFFF

local min = math.min
local max = math.max
local rad = math.rad
local sin = math.sin
local cos = math.cos
local acos = math.acos
local abs = math.abs

local DEBUG = DEBUG
local VERBOSE = VERBOSE
local TEST = TEST

local UPDATE_PREVIOUS_SEEN_LOC_DELTA = UPDATE_PREVIOUS_SEEN_LOC_DELTA

local function increase_garbage_tables_size(size)
	if size > 100 then
		WARN_print(string.format("[score_location_data] %d size garbage_tables. ~~%d byte use minimum.",
					size, size*64 + 64
				)
			)
	end
	for i=#garbage_tables+1,size do
		garbage_tables[i] = {}
	end
end

local function score_units_triangle()
end
local function score_units_circle()
end
local function score_units_square()
end

-------- ScoreLocs_StripHeroes()
function ScoreLocs_StripHeroes(gsiPlayer, unitsTbl, hAbility,
			base, forwardsVec, halfDiameter, intendedTarget,
			intendedTargetFactor, lowHealthFactor, powerFactor,
			damageFactor, shotSpeed, castRange, releaseDeltaT,
			castInfrontDistance
		)

	intendedTargetFactor = intendedTargetFactor or 0.05
	lowHealthFactor = lowHealthFactor or 0.05
	powerFactor = powerFactor or 0.05
	damageFactor = damageFactor or 0.05

	releaseDeltaT = releaseDeltaT or hAbility:GetCastPoint()
	castRange = castRange or hAbility:GetCastRange()
	castInfrontDistance = castInfrontDistance or castRange*0.975

	local forwardsVecLen = (forwardsVec.x^2 + forwardsVec.y^2)^0.5
	local topLoc = Vector(base.x+forwardsVec.x, base.y+forwardsVec.y, 0)

	
	
	local currTime = GameTime()

	local totalScore = 0
	local greatestDistCcw = 0
	local greatestDistCw = 0
	for i=1,#unitsTbl do
		local thisUnit = unitsTbl[i]
		local dmgPercent = AbilityLogic_CastOnTargetWillSucceed(gsiPlayer, thisUnit, hAbility)
		if dmgPercent > 0 then
			local lastSeen = thisUnit.lastSeen
			local lastSeenLoc = lastSeen.location
			local lastSeenPrevious = lastSeen.previousLocation
			local distanceFromBase = ((lastSeenLoc.x - base.x)^2 + (lastSeenLoc.y - base.y)^2)^0.5
			local approxExtrapolateT = releaseDeltaT + distanceFromBase/shotSpeed
			local extrapolatedLoc = not pUnit_IsNullOrDead(thisUnit)
					and Vector_ProgressBetweenPoints2D(
							lastSeenLoc,
							thisUnit.hUnit:GetExtrapolatedLocation(approxExtrapolateT),
							max(0.15, thisUnit.hUnit:GetMovementDirectionStability())
						)
			if not extrapolatedLoc
					and currTime - lastSeen.previousTimeStamp < UPDATE_PREVIOUS_SEEN_LOC_DELTA then
				-- i.e. only use a normal interval previous, otherwise they were probably in fog, crazy vecs
				extrapolatedLoc = Vector_Addition(lastSeenLoc,
						Vector_ScalarMultiply(
								Vector(lastSeenPrevious.x - lastSeenLoc.x, lastSeenPrevious.y - lastSeenLoc.y, 0),
								0.925*approxExtrapolateT/(lastSeen.timeStamp - lastSeen.previousTimeStamp)
							)
						)
			end
			if extrapolatedLoc then
				-- movement seem valid and useful
				local baseToExtrapolated = Vector(extrapolatedLoc.x - base.x, extrapolatedLoc.y - base.y, 0)
				local baseToExtrapolatedLen = (baseToExtrapolated.x^2 + baseToExtrapolated.y^2)^0.5
				local distFromCenter = baseToExtrapolatedLen * sin(
						acos((forwardsVec.x*baseToExtrapolated.x + forwardsVec.y*baseToExtrapolated.y)
							/ (forwardsVecLen * baseToExtrapolatedLen)
						)
					)
				
				if distFromCenter < halfDiameter then
					local intendedSc = intendedTarget == thisUnit and intendTargetFactor or 0
					local lowHealthSc = lowHealthFactor * (1-thisUnit.lastSeenHealth / thisUnit.maxHealth)
					local powerSc = powerFactor * Analytics_GetPowerLevel(thisUnit)
					local dmgSc = damageFactor * dmgPercent

					totalScore = totalScore + (intendedSc + lowHealthSc + powerSc + dmgSc)
							* distFromCenter/halfDiameter
	
	
	
	
	
							
					-- baseToEx (X) forwardsVec sidedness
					if baseToExtrapolated.x*forwardsVec.y - baseToExtrapolated.y*forwardsVec.x > 0 then
						-- left-hand side
			
						if distFromCenter > greatestDistCcw then
							greatestDistCcw = distFromCenter
						end
					elseif distFromCenter > greatestDistCw then -- rhs
			
						greatestDistCw = distFromCenter
					end
				end
			end
		end
	end

	-- Use shift left because baked normal to the forwardsvec uses an orthogonal +ve z coordinate
	local shiftLeft = (greatestDistCcw - greatestDistCw)
	-- topLoc + ortogonal*shiftLeft
	local hitsBetter = shiftLeft > 20
			and Vector(topLoc.x + forwardsVec.y*shiftLeft/forwardsVecLen,
				topLoc.y - forwardsVec.x*shiftLeft/forwardsVecLen, 0)
			or topLoc
	
	if castInfrontDistance then
		hitsBetter = Vector_Addition(base, Vector_ScalarMultiply(
					Vector_ToDirectionalUnitVector(
							Vector_PointToPointLine(base, hitsBetter)),
					castInfrontDistance
				)
			)
	end




	return totalScore, hitsBetter
end

-------- ScoreLocs_ConeHeroes()
function ScoreLocs_ConeHeroes(gsiPlayer, unitsTbl, hAbility, height,
			halfRadiansSpread, intendedTarget, allowAlt, intendedTargetFactor,
			intendedConeFactor, lowHealthFactor, powerFactor, totalDamageFactor,
			releaseDeltaT, shotSpeed, afterShotSpeed, toZeroNotThrough, minimumHit,
			castRange
		)
	-- TODO Unabstract vector arithmetic. Check non intended hits. moreIsMoreBaseScore for >2 hit
	local playerLoc = gsiPlayer.lastSeen.location
	
	local countUnits = #unitsTbl

	intendedTargetFactor = intendedTargetFactor or 0.05
	intendedConeFactor = intendedConeFactor or intendedTargetFactor
	lowHealthFactor = lowHealthFactor or 0.05
	powerFactor = powerFactor or 0.05
	totalDamageFactor = totalDamageFactor or 0.05
	castRange = castRange or hAbility:GetCastRange()
	releaseDeltaT = releaseDeltaT or hAbility:GetCastPoint()

	local indexIntendedTarget -- if it nils, add to end of table, remove later

	local hitScores = garbage_tables -- {[i] = {is contact score, in cone score}, ...}
	if #hitScores < countUnits+1 then
		increase_garbage_tables_size(countUnits+1)
	end
	local getAlt = false
	for i=1,countUnits+1 do
		local thisUnit = unitsTbl[i] or intendedTarget -- i+1 count intended
		local thisHealthFactor
		local thisPowerFactor
		local dmgFactor
		if type(hitScores[i]) ~= "table" then
			ERROR_print(true, not DEBUG,
					"[score_location_data] Err - ScoreConeHeroes() found a nil table at i=%d from table garbage of size %d, checking %d units, indexIntendedTarget %d",
					i, #hitScores, countUnits, indexIntendedTarget or -0
				)
			Util_TablePrint({["hitScores"]=hitScores})
			Util_TablePrint({["unitsTbl"]=unitsTbl})
			return 0, nil, nil, 0
		end
		
		if thisUnit and not pUnit_IsNullOrDead(thisUnit) then
			dmgFactor = AbilityLogic_CastOnTargetWillSucceed(gsiPlayer, thisUnit, hAbility) * totalDamageFactor
			thisHealthFactor = (lowHealthFactor
					and lowHealthFactor * (1.001 - thisUnit.lastSeenHealth / thisUnit.maxHealth) or 0)
			thisPowerFactor = (powerFactor and powerFactor * Analytics_GetPowerLevel(thisUnit) or 0)
			
			if pUnit_IsNullOrDead(thisUnit) or dmgFactor == 0 then
				hitScores[i][1] = 0 
				hitScores[i][2] = 0
			else
				if Vector_PointDistance(thisUnit.lastSeen.location, playerLoc) < castRange then
					hitScores[i][1] = dmgFactor + (intendedTarget == thisUnit
						and intendedTargetFactor
						or 0) + thisHealthFactor + thisPowerFactor
				else -- only allow in-cone scoring for out fo range
					hitScores[i][1] = 0
				end
				hitScores[i][2] = dmgFactor + (intendedTarget == thisUnit
						and intendedConeFactor
						or 0) + thisHealthFactor + thisPowerFactor
			end
		else
			hitScores[i][1] = 0
			hitScores[i][2] = 0
		end
		if intendedTarget == thisUnit then
			if intendedNecessary and hitScores[i][2] == 0 then
				if allowAlt then
					getAlt = true
				else
					return 0, nil, nil
				end
			end
			indexIntendedTarget = i
		end
		if i==countUnits and indexIntendedTarget then
			break;
		end
	end

	local addedIntended = intendedTarget and not indexIntendedTarget

	if addedIntended then
		indexIntendedTarget = #unitsTbl + 1
		unitsTbl[indexIntendedTarget] = intendedTarget
		countUnits = #unitsTbl
	end

	local bestScore = 0
	if getAlt then
		-- Get an alternate target if arg set and it would be needed
		for i=1,countUnits do
			local altScore = hitScores[i][1] + hitScores[i][2]
			if altScore > bestScore then
				bestScore = altScore
				intendedTarget = unitsTbl[i]
				indexIntededTarget = i
			end
		end
		if not bestTarget then
			if addedIntended then
				unitsTbl[countUnits] = nil
			end
			return 0, nil, nil
		end
		bestScore = 0
	end

	local centerConeDist = height*1.15

	local bestTarget
	local bestHitLoc
	local bestHitCount = 0

	local countUnits = #unitsTbl -- THIS IS A HORRIBLE HOTFIX TODO

	-- Find best cast
	-- O(n) due to intendedTarget requirement
	for i=1,countUnits do
		local thisUnit = unitsTbl[i]
		if hitScores[i][1] ~= 0 then
			local hitCount = 1
			local hitsLoc, hitsDeltaT = Projectile_ExtrapolateProjectileToSeenUnit(playerLoc, thisUnit,
					releaseDeltaT, shotSpeed
				)
			
			
			if thisUnit ~= intendedTarget then
				-- Find if the intended target is in the aftershot
				local thisScore = hitScores[i][1]
				local extrapolatedTime = releaseDeltaT + hitsDeltaT -- TODO? target could be moving anywhere
				local extrapolatedLoc = intendedTarget.hUnit:GetExtrapolatedLocation(extrapolatedTime)

				
				

				local radsProjecting = Vector_PointToPointRads(playerLoc,
						toZeroNotThrough and ZEROED_VECTOR or hitsLoc
					)
				local hits, dist, radsDiff = Vector_PointWithinCone(
						extrapolatedLoc, hitsLoc, height, radsProjecting, halfRadiansSpread
					)
				
				if hits then
					hitCount = hitCount + 1
					if not hitScores[indexIntendedTarget] then
						ERROR_print(true, not DEBUG,
								"[score_location_data] Found nil hitScores entry for intended '%s', index %d, countUnits %d.",
								intendedTarget and intendedTarget.shortName or intendedTarget.name or "none",
								indexIntendedTarget or -0,
								countUnits
							)
						Util_TablePrint(unitsTbl, 2)
						Util_TablePrint(hitScores, 2)
						return 0, nil, nil, 0
					end
					thisScore = thisScore + hitScores[indexIntendedTarget][2]
					thisScore = thisScore + (1 - abs(2.3*dist-centerConeDist) / centerConeDist) + (1 - radsDiff / halfRadiansSpread)
				end
				if thisScore > bestScore and hitCount >= minimumHit then
					bestScore = thisScore
					bestTarget = thisUnit
					bestHitLoc = extrapolatedLoc
					bestHitCount = hitCount
				end
			else
				-- Find best score of units in aftershot -- ignores mutli-target hits, it is the intended target anyways, TODO fix this for moreIsMoreFactor
				for k=1,countUnits do
					local afterShotUnit = unitsTbl[k]
					local extrapolatedLoc
					local thisScore = hitScores[i][1]
					local hitCount = 1
					if k~=i and hitScores[k][2] ~= 0 then
						local extrapolateTime = releaseDeltaT + hitsDeltaT -- TODO? moving (above).. worried simplicity/approx' is needed
						extrapolatedLoc = afterShotUnit.hUnit:GetExtrapolatedLocation(extrapolateTime)
						local radsProjecting = Vector_PointToPointRads(playerLoc,
								toZeroNotThrough and ZEROED_VECTOR or hitsLoc
							)
						local hits, dist, radsDiff = Vector_PointWithinCone(
								extrapolatedLoc, hitsLoc, height, radsProjecting, halfRadiansSpread
							)
						
						if hits then
							hitCount = hitCount + 1
							thisScore = thisScore + hitScores[k][2]
							thisScore = thisScore + (1 - abs(2.3*dist-centerConeDist) / centerConeDist)
									+ (1 - radsDiff / halfRadiansSpread)
							if thisScore > bestScore and hitCount >= minimumHit then
								bestScore = thisScore
								bestTarget = intendedTarget
								bestHitLoc = extrapolatedLoc
								bestHitCount = hitCount
							end
						end
					end
				end
			end
		end
	end
	if addedIntended then
		unitsTbl[countUnits] = nil
	end
	return bestScore, bestTarget, bestHitLoc, bestHitCount
end

-- Optionally can be used for awfully for semicircles and major sectors
-------- ScoreLocs_ConeSeenUnitsHitsTarget()
function ScoreLocs_ConeSeenUnitsHitsTarget(gsiPlayer, unitsTbl, hAbility, target, height, 
			halfRadiansSpread, atZeroNotThrough, releaseDeltaT, shotSpeed, afterShotSpeed,
			isTargetReturn, isAfterShotTargetReturn, castRange, cancelAvgDist
		)
	-- Here is some imaginary money for me for my motivation [|$|][|$|][|$|][|$|][|$|][|$|][|$|] yay!
	-- Most of this this code is rarely used and could even be made mostly redundant one day.
	-- Really though, it would just be modified to just extrapolate the best aoe/two targets that an ability could
	-- -| hit, returning the extrapolated location/crowdingLoc's resulting vector for the ability
	-- Very few abilities have deterministicly angled non-symetrical cones, strips, triangles, etc. [|$|]
	
	-- TODO what if a perfect shot is possible some seconds in the future and we are running back to fountain instead
	-- -| of herding the shot, running orthogonally to the fight from our fountain and returning for the hit; or
	-- -| keeping our shot angles. This is why positioning needs a method of registering intelligent movement soon.
	-- TODO How might fighting behavior be modelled and predicted, whether stupidly quick or smartly slow.
	
	local playerLoc = gsiPlayer.lastSeen.location
	local targetLoc = target.lastSeen.location

	local countUnits = #unitsTbl

	local releaseDeltaT = releaseDeltaT or hAbility:GetCastPoint()
	
	local avgDist = 0
	local distCount = 0
	local killAvgDist = cancelAvgDist and cancelAvgDist * 0.75

	castRange = castRange or hAbility:GetCastRange()

	local centerConeDist = height*1.15 -- push it up by 0.575 of the distance to get a better odds of them not being able to step out of the cone

	local i=1
	local mostReliableTarget -- for returning a non-satisfying arg hits
	local mostReliableHitsLoc
	local mostReliableScore = 0
	
	local checkUnitInfront = true -- cancelled if all the units are too far away.
	local checkTargetInfront
	local targetHitsLoc, targetHitsDeltaT, targetExtrapolatedTime, targetRadsProjecting
	if ((playerLoc.x - targetLoc.x)^2
				+ (playerLoc.y - targetLoc.y)^2
				+ (playerLoc.z - targetLoc.z)^2
			)^0.5 < castRange then
		checkTargetInfront = true
		targetHitsLoc, targetHitsDeltaT = Projectile_ExtrapolateProjectileToSeenUnit(
				playerLoc, target, releaseDeltaT, shotSpeed
			)
		
		
		targetExtrapolatedTime = targetHitsDeltaT + releaseDeltaT
		targetRadsProjecting = Vector_PointToPointRads(
				playerLoc, toZeroNotThrough and ZEROED_VECTOR or targetHitsLoc
			)
	end

	
	-- not abstracted because CRT in gray
	while(i<=countUnits) do
		local thisUnit = unitsTbl[i]
		local unitLoc = thisUnit.lastSeen.location
		if thisUnit ~= target then
			if checkUnitInfront then
				
				local distToUnit
						= ((playerLoc.x - unitLoc.x)^2 + (playerLoc.y - unitLoc.y)^2
								+ (playerLoc.z - unitLoc.z)^2)^0.5
				if distToUnit < castRange then
					
					local hitsLoc, hitsDeltaT = Projectile_ExtrapolateProjectileToSeenUnit(playerLoc, thisUnit,
							releaseDeltaT, shotSpeed)
					
					
					local extrapolatedTime = hitsDeltaT + releaseDeltaT
					local extrapolatedLoc = target.hUnit:GetExtrapolatedLocation(extrapolatedTime)
					local radsProjecting = Vector_PointToPointRads(playerLoc,
							toZeroNotThrough and ZEROED_VECTOR or hitsLoc
						)
					local inCone, dist, radsOut = Vector_PointWithinCone(
							extrapolatedLoc, hitsLoc, height, radsProjecting, halfRadiansSpread
						)
					
					if inCone then
						
						local thisScore = (1 - abs(2.3*dist-centerConeDist) / centerConeDist)
								+ (1 - radsOut / halfRadiansSpread)
						
						
						
						if thisScore > mostReliableScore then
							mostReliableScore = thisScore
							mostReliableHitsLoc = hitsLoc
							mostReliableTarget = thisUnit
							
						end
						if isAfterShotTargetReturn then
							return thisScore, thisUnit, hitsLoc, true
						end
					end
				end
				if cancelAvgDist then
					avgDist = (avgDist*distCount + distToUnit)/(distCount+1)
					distCount = distCount + 1
					if distCount >= 2 then
						if avgDist > cancelAvgDist then
							cancelUnitInfront = true
						end
						if avgDist < killAvgDist then
							cancelAvgDist = nil
						end
					end
				end
			end
			if checkTargetInfront then
				-- Find units behind the target
				local extrapolatedLoc = thisUnit.hUnit:GetExtrapolatedLocation(targetExtrapolatedTime)
				local inCone, dist, radsOut = Vector_PointWithinCone(
						extrapolatedLoc, targetHitsLoc, height, targetRadsProjecting, halfRadiansSpread
					)
				
				if inCone then
					
					local thisScore = (1 - abs(2.3*dist-centerConeDist) / centerConeDist)
							+ (1 - radsOut / halfRadiansSpread)
					
					
					
					if thisScore > mostReliableScore then
						mostReliableScore = thisScore
						mostReliableHitsLoc = targetHitsLoc
						mostReliableTarget = target
						
					end
					if isTargetReturn then
						return thisScore, target, targetHitsLoc, true
					end
				end
			end
		end
		i = i + 1
	end

	return mostReliableScore, mostReliableTarget, mostReliableHitsLoc,
			isTargetReturn == false and isAfterShotTargetReturn == false or false
end

local function score_trees(unitsTbl, intendedTarget, targetNecessary,
		hitsSpellImmune, hitsAttackImmune, targetFactor, lowHealthFactor,
		powerFactor, shotSpeed, afterShotSpeed)
end
