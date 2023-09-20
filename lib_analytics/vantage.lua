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


--- Ideas (probably not implmented because I can half-arse it and move onto something else):
-- - Iterate over the map in distance steps, determine edges of the height differnces in the
-- 		map. As bots move through the map, do routine tree distance checks to build polys that
-- 		shape collections of trees that it is assumed or known to block vision by checking
-- 		past the tree poly. Probably turn these into 2D bounding volumes for "this is a good
-- 		place to stand to wait for teammates to cross the river.", or "don't go up this cliff
-- 		unless the allied roamers are here as well because it's too dangerous, and enemies have
-- 		no blocking tree volume from the vantage."
-- 		Batch these computations from tree arrays to-be-processed (we don't need to check
-- 		somewhere that has already been checked)
-- 	- Basically, automate height-based data and don't need to update after map changes.
--
-- 	Half-arse:
-- 	- Find height-1 spots well within the world bounds for ward spots. Test height changes of desired
-- 		movement and return a danger of movement factor for many modules to consider in their context.

local CLEAR_ACTION_UNEXPECTED_BEHAVIOUR_MSG = "API action queue clearing behaviour has changed or a race condition was detected"

local ward_locations = {}
local view_advantage = {--[[{loc, radius},...]]}

local world_bounds = GetWorldBounds()
for i=1,4 do
	world_bounds[i] = world_bounds[i]*0.66
end
local step_build_dist = 20.0

local edges = {--[[left-side high vec to right-side low vec]]}

local t_height_one = {--[[count_close, center_of_known]]}

local CONSIDER_SAME_HEIGHT_ONE_DIST = 900.0
local table = table

local DEFAULT_WARD_HEIGHT = 512.0
local ADJUST_VECTOR = Vector(-70, -70, 0) -- All ward pillars height returns seem slightly off. Hopefully doesn't change often TODO automate with vision when near, & move to stationary, if they don't move it's on the cliff edge

local IsPlayerBot = IsPlayerBot
local TEAM_NUMBER_OF_PLAYERS = TEAM_NUMBER_OF_PLAYERS
local max = math.max
local min = math.min
local abs = math.abs

local DEBUG = DEBUG
local VERBOSE = VERBOSE
local TEST = TEST

local FAR_AWAY_VEC = Vector(0xFFFF, 0xFFFF, 0xFFFF)

local team_players

local t_preferred_ward_index_cache = {0, 0, 0} -- NB STORE A WARD INDEX EXTERNALLY AND STICK TO IT IF BASING WARDING LOC OFF THIS
local count_preferred_ward_locations = 0
local t_is_warded = {}

local count_reserve_ward_spots = 0
local count_ward_spots = 0 -- count of wards that may be considered
local t_ward_loc = {} -- Internal data, not for use
local t_ward_score_cache = {}
local t_ward_is_corrected = {} -- Has the t_ward_correction been set? -- nil == uncorrected, true == corrected, false == removed for uncorrectable & whichever module requested the index to be used must be able to receive the false return and stop using the invalidated ward index
local t_ward_correction = {} -- Corrected for use -- Assume to either be an approximation or corrected
--		Vector(-4436.00, -976.00, 384.00),
--		Vector(-4076.00, 1624.00, 384.00),
--		Vector(-4046.00, -976.00, 384.00),
--		Vector(-2776.00, 3684.00, 384.00),
--		Vector(-716.00, 2144.00, 384.00),
--		Vector(-456.00, -3296.00, 384.00),
--		Vector(584.00, 4204.00, 384.00),
--		Vector(1364.00, -5116.00, 384.00),
--		Vector(2144.00, -716.00, 384.00),
--		Vector(2914.00, -3036.00, 384.00),
--		Vector(4854.00, 844.00, 384.00) -- this is commented out because the aim is to get the auto-generation satisfactory, they are current 7.32e
--	}

local t_ward_loc_reserved = {}

function Analytics_RegisterDomainToVantage(captain_domain, analytics_domain)
	team_players = GSI_GetTeamPlayers(TEAM)
	captain_domain:RegisterJob(
			function(workingSet) -- BatchContinueBuildMap()
				local x = workingSet.x
				local add = step_build_dist
				local bounds = world_bounds
				local t_height_one = t_height_one
				local thisConsiderVec = Vector(x, 0.0, DEFAULT_WARD_HEIGHT)
				local knownNearIndex = false

if VERBOSE then
				VEBUG_print(
						string.format(
							"[vantage]: Finding ward locations column coord: %.2f. Locations found: %d",
							x, count_reserve_ward_spots
						)
					)
end

				-- (t_height_one == tbl of ward pillars)
				-- Iterate step_build_dist steps over y for this x
				for y=bounds[2],bounds[4],add do -- (final column is here or there)
					thisConsiderVec.y = y
					-- Is it a ward pillar?
					if (GetHeightLevel(thisConsiderVec) == 1) then
						-- Was the previous check a ward pillar?
						
						if not knownNearIndex then
							for i=1,count_reserve_ward_spots do
								-- Is it close enough to a previously known height one?
								if CONSIDER_SAME_HEIGHT_ONE_DIST >
										Vector_PointDistance(
												thisConsiderVec,
												t_height_one[i][2]
											) then
									knownNearIndex = i
								end
							end
							if not knownNearIndex then
								-- Not found, create
								count_reserve_ward_spots = count_reserve_ward_spots + 1
								knownNearIndex = count_reserve_ward_spots
								table.insert(t_height_one, {0, Vector(0.0, 0.0, DEFAULT_WARD_HEIGHT)})
							end
						end
						-- knownNearIndex is evaluated...
						t_height_one[knownNearIndex][1] = t_height_one[knownNearIndex][1] + 1
						local adjustAverage = t_height_one[knownNearIndex][2]
						local pointCount = t_height_one[knownNearIndex][1]
						local thisCopy = Vector(thisConsiderVec.x+ADJUST_VECTOR.x, thisConsiderVec.y+ADJUST_VECTOR.y, thisConsiderVec.z)
						adjustAverage.x = adjustAverage.x + (thisCopy.x-adjustAverage.x)/pointCount
						adjustAverage.y = adjustAverage.y + (thisCopy.y-adjustAverage.y)/pointCount
						t_height_one[knownNearIndex][2] = adjustAverage
					else
						knownNearIndex = false
					end
				end

if DEBUG then
				for i=1,count_reserve_ward_spots do
					if VERBOSE then
						VEBUG_print(
								string.format("[vantage]: #%d, %d points centered at %s",
									i, t_height_one[i][1], tostring(t_height_one[i][2])
								)
							)
					end
					DebugDrawCircle(t_height_one[i][2], 70, 100, 150, 0)
				end
end

				workingSet.x = x + add
				if (x > bounds[3]) then
					for i=1,count_reserve_ward_spots do
						t_ward_loc_reserved[i] = t_height_one[i][2]
						if VERBOSE then print(string.format('\tVector(%.2f, %.2f, %.2f),', t_ward_loc_reserved[i].x, t_ward_loc_reserved[i].y, t_ward_loc_reserved[i].z)) end
					end
					VAN_InformDefensibleFell(nil) -- Unreserve the wards that should be more relevant given the tower front lines
					return true; -- DELETE THIS JOB
				end
				return false;
			end,
			{x = world_bounds[1]},
			"JOB_BATCH_CONTINUE_BUILD_MAP"
		)

	analytics_domain:RegisterJob(
			function(workingSet)
				-- TODO IS SIMPLISTIC -- Impl. maybe: courier travelling anyways, 2 slots free, where would bot be by delivery, tower vision, objectives
				if not t_ward_loc[1] then
					if DEBUG then
						DEBUG_print("[vantage]: JOB_UPDATE_STRATEGIZE_WARDS awaits height data...")
					end
					return;
				end
				if workingSet.throttle:allowed() then
					local t_visible_cache = t_visible_cache
					local IsLocationVisible = IsLocationVisible
					local Vector_PointDistance = Vector_PointDistance
					local min=min
					local ZEROED_VECTOR = ZEROED_VECTOR
					local wardsUp = GetUnitList(UNIT_LIST_ALLIED_WARDS)
					local wardsUpCount = #wardsUp

					for i=1,count_ward_spots do
						local wardLoc = t_ward_correction[i] -- may still be uncorrected, but selection and valid use corrects
						t_is_warded[i] = false
						if IsLocationVisible(wardLoc) then
							t_ward_score_cache[i] = 0
							t_is_warded[i] = true
						else
							local closeness = 0
							for iWard=1,wardsUpCount do
								local thisWardUp = wardsUp[iWard]
								local distWardUpToWard = Vector_PointDistance(thisWardUp:GetLocation(), wardLoc)
								closeness = max(0,
										6600 - distWardUpToWard
									)
								if distWardUpToWard < 1000 then
									t_is_warded[i] = true
								end
							end
							t_ward_score_cache[i] = closeness > 3200 and 0 or 1 -- 1 ward at 3200 dist, or two wards at 5000
						end
					end
					for i=1,count_ward_spots do -- O(n!)
						if t_ward_score_cache[i] ~= 0 then
							local iWardLoc = t_ward_correction[i]
							local ithValue = t_ward_score_cache[i]
							for k=i+1,count_ward_spots do -- n,n-1,n-2...1
								local jWardLoc = t_ward_correction[k]
								local thisValue = min(1, 0.8+(Vector_PointDistance(iWardLoc, jWardLoc) - 5500)/5500)
								if VERBOSE then print("updating ward values at %s and %s", iWardLoc, jWardLoc, thisValue) end
								-- Use the distance score between these two wards to add to their score if they are themselves not warded
								-- 		and just add 1 even if they are very close to each other, if the other ward and themselve are not
								-- 		warded
								ithValue = (t_is_warded[i] and 0 or ithValue + (t_is_warded[k] and thisValue or 1))
								t_ward_score_cache[k] = (t_is_warded[k] and 0 or t_ward_score_cache[k] + (t_is_warded[i] and thisValue or 1))
							end
							t_ward_score_cache[i] = ithValue * max(1, 1.25 - abs(iWardLoc.x + iWardLoc.y)/8000) -- favour locs closer to the river slightly TODO DEPENDS ON TOWERS
						end
					end
					local bestDisparateScores = {0.1, 0.1, 0.1} -- see "first check is true"
					local bestDisparateLocs = {FAR_AWAY_VEC, FAR_AWAY_VEC, FAR_AWAY_VEC} -- steps are taken to make them disparate, but they may step towards each other
					count_preferred_ward_locations = 0
					for i=1,3 do
						 -- NB CLEARED, REFORMULATED DATA -- Any checks for devalued ward locs needs to be
						 --		made by external modules, or specified by calling a 'VAN_*KillDevalued'
						 --		named global VAN function
						t_preferred_ward_index_cache[i] = 0
					end
					local worstBestScore = 0.000001
					local worstBestBestIndex = 1
					-- Find the three best scoring ward locations that are disparately placed
					for i=1,count_ward_spots do
						if t_ward_score_cache[i] > 0.000002 then
							--print("203vantage might", t_ward_score_cache[i], t_ward_correction[i])
							ithWardLoc = t_ward_correction[i]
							for k=1,3 do
								local distWardLocToThisBest = Vector_PointDistance(ithWardLoc, bestDisparateLocs[k])
								if distWardLocToThisBest < 4000 then -- 
									--print("203vantage dist okay")
									-- replace locs close to other locs if they were given a higher score (here is the 'may step towards each other')
									if t_ward_score_cache[i] > bestDisparateScores[k] then
										--print("203vantage score okay")
										-- found a best loc
										bestDisparateScores[k] = t_ward_score_cache[i]
										t_preferred_ward_index_cache[k] = i
										if worstBestScore > bestDisparateScores[k] then -- first check is true if {0.1, 0.1, 0.1}
											-- found current worst best loc
											--print("203vantage worst okay")
											worstBestScore = bestDisparateScores[k]
											worstBestBestIndex = k
										end 
										if k > count_preferred_ward_locations then
											count_preferred_ward_locations = k
											--print("203vantage size okay", k)
										end
									end
									break; -- .'. never enter the below code block unless ALL best wards were over 4000 units away
								elseif k==3 and (t_ward_score_cache[i] > worstBestScore
										or bestDisparateLocs[count_preferred_ward_locations+1] == FAR_AWAY_VEC) then -- ('else with dist >= 4000, if...'
									--print("203vantage filled okay")
									-- implied that t_preferred_ward_index_cache is filled with at least 3 best locs
									-- but our score was better than worst while this ward lock is also far away from
									-- all other locs. Replace the current worst best loc with this, find the new worst:
									if bestDisparateLocs[count_preferred_ward_locations+1] == FAR_AWAY_VEC then
										count_preferred_ward_locations = min(3, count_preferred_ward_locations+1)
									end
									bestDisparateScores[worstBestBestIndex] = t_ward_score_cache[i]
									bestDisparateLocs[worstBestBestIndex] = ithWardLoc
									t_preferred_ward_index_cache[worstBestBestIndex] = i
									worstBestScore = 0xFFFF
									for _k=1,min(3, count_preferred_ward_locations+1) do
										if worstBestScore > bestDisparateScores[_k] then
											worstBestScore = bestDisparateScores[_k]
											worstBestBestIndex = _k
										end
									end
								end
							end
						end
					end
					local highestBuyScore = -0xFFFF
					local highestBuyBot
					local obsStock = GetItemStockCount("item_ward_observer")
					if obsStock > 0 then
						for i=1,TEAM_NUMBER_OF_PLAYERS do
							local thisPlayer = team_players[i]
							if IsPlayerBot(thisPlayer.playerID)
									and not pUnit_IsNullOrDead(thisPlayer) and (
										Item_HaveFreeInventorySlot(thisPlayer) or
										Item_IsHoldingAnyDispenser(thisPlayer)
									) then
								local loc, index, dist = VAN_GetClosestBestWardToLoc(thisPlayer.lastSeen.location)
								if loc then
									local thisBuyScore =
											(1 + max(
													0,
													Analytics_GetTheoreticalDangerAmount(thisPlayer)
														* thisPlayer.lastSeenHealth / thisPlayer.maxHealth
												) + t_ward_score_cache[index]
											) * (1 - thisPlayer.vibe.greedRating^2 + max(0, (4000-dist)/4000)) -- because it may reduce their time to farm, generally
									if VERBOSE then
										INFO_print(
												string.format("[vantage] %s: scores buy ward (%s, %.2f): %.2f",
													thisPlayer.shortName,
													tostring(loc),
													t_ward_score_cache[index],
													thisBuyScore
												)
											)
									end
									if thisBuyScore > highestBuyScore then
										highestBuyScore = thisBuyScore
										highestBuyBot = thisPlayer
									end
								end
							end
						end
						local _, _, hItemWards = highestBuyBot and Item_IsHoldingAnyDispenser(highestBuyBot)
						if highestBuyBot and obsStock > 1
								and (not hItemWards or hItemWards:GetCurrentCharges() < 4) then
							Item_InsertItemToItemBuild(highestBuyBot, "item_ward_observer")
							if DEBUG then INFO_print(
									string.format("[vantage] %s buys observer wards with score %.2f, holds %d, %d, %d",
										highestBuyBot.shortName,
										highestBuyScore,
										hItemWards and hItemWards:GetCurrentCharges() or 0,
										hItemWards and hItemWards:GetSecondaryCharges() or 0,
										hItemWards and hItemWards:GetInitialCharges() or 0
									)
								)
							end
						end
					end
				end
			end,
			{throttle = Time_CreateThrottle(4.091)},
			"JOB_UPDATE_STRATEGIZE_WARDS"
		)
	Analytics_RegisterDomainToVantage = nil
end

function VAN_InformDefensibleFell(gsiBuilding)
	INFO_print(string.format("[vantage] VAN_InformDefensibleFell(). %s, isShrine:%s, isTower:%s",
					gsiBuilding,
					gsiBuilding and gsiBuilding.isShrine and 'y' or 'n',
					gsiBuilding and gsiBuilding.isTower and 'y' or 'n'
				)
			)
	if (gsiBuilding and gsiBuilding.isShrine)
			or not (t_ward_loc_reserved[1] or t_ward_loc[1]) then
		return;
	end
	local radiantBoundPoints = {}
	local direBoundPoints = {}
	local f_lowest_tier_defs = GSI_GetLowestTierDefensible
	for i=1,3 do
		radiantBoundPoints[i] = f_lowest_tier_defs(TEAM_RADIANT, i).lastSeen.location
		direBoundPoints[i] = f_lowest_tier_defs(TEAM_DIRE, i).lastSeen.location
		if VERBOSE then
			VEBUG_print(string.format("[vantage] reserved building locs in lane %d:", i))
			VEBUG_print(string.format("[vantage] \tRadiant --%s", radiantBoundPoints[i]))
			VEBUG_print(string.format("[vantage] \tDire    --%s", direBoundPoints[i]))
		end
	end
	local i = 1







	while (i <= count_reserve_ward_spots) do
		local thisLoc = t_ward_loc_reserved[i]
		if VERBOSE then
			VEBUG_print(
					string.format("[vantage] checking reserved due to towers up %s, bool((%s || %s)&&(%s || %s))",
						tostring(thisLoc),
						tostring(Vector_SideOfPlane(thisLoc, radiantBoundPoints[3], radiantBoundPoints[2]) < 0),
						tostring(Vector_SideOfPlane(thisLoc, radiantBoundPoints[2], radiantBoundPoints[1]) < 0),
						tostring(Vector_SideOfPlane(thisLoc, direBoundPoints[3], direBoundPoints[2]) > 0),
						tostring(Vector_SideOfPlane(thisLoc, direBoundPoints[2], direBoundPoints[1]) > 0)
					)
				)
		end
		if (Vector_SideOfPlane(thisLoc, radiantBoundPoints[3], radiantBoundPoints[2]) < 0
					or Vector_SideOfPlane(thisLoc, radiantBoundPoints[2], radiantBoundPoints[1]) < 0
				) and (Vector_SideOfPlane(thisLoc, direBoundPoints[3], direBoundPoints[2]) > 0
					or Vector_SideOfPlane(thisLoc, direBoundPoints[2], direBoundPoints[1]) > 0
				) then
			count_ward_spots = count_ward_spots + 1
			
			t_ward_loc[count_ward_spots] = thisLoc
			t_ward_correction[count_ward_spots] = thisLoc 
			t_ward_score_cache[count_ward_spots] = 0
			--((t_ward_is_corrected[count_ward_spots] = nil))
			t_is_warded[count_ward_spots] = false
			t_ward_is_corrected[count_ward_spots] = nil
			t_ward_loc_reserved[i] = t_ward_loc_reserved[count_reserve_ward_spots]
			t_ward_loc_reserved[count_reserve_ward_spots] = nil
			count_reserve_ward_spots = count_reserve_ward_spots-1
		else
			i = i + 1
		end
	end
	








end

function VAN_GetWardLocations()
	return t_ward_loc
end

function VAN_GetWardLocationsCorrected()
	return t_ward_correction
end

function VAN_GetClosestBestWardToLoc(loc)
	local shortestDist = 0xFFFF
	local shortestIndex = 0
	for k=1,count_preferred_ward_locations do
		local thisIndex = t_preferred_ward_index_cache[k]
		local thisLoc = t_ward_correction[thisIndex]
		if thisLoc then
			local thisDist = Vector_PointDistance(
					loc,
					thisLoc
				)
			if not IsLocationVisible(thisLoc) then -- TODO IsLocationWarded()
				if thisDist < shortestDist then
					shortestDist = thisDist
					shortestIndex = k
				end
			end
		end
	end
	if DEBUG then print("282vantage", shortestIndex, shortestDist, shortestIndex ~= 0 and t_ward_score_cache[t_preferred_ward_index_cache[shortestIndex]]) end
	if shortestIndex > 0 then
		local thisBestIndex = t_preferred_ward_index_cache[shortestIndex]
		return t_ward_correction[thisBestIndex],
				thisBestIndex,
				shortestDist;
	end
	return false; --nil, nil
end

local t_player_check_frame = {}
local t_player_check_index = {}
local t_player_check_limit = {}
local MINIMUM_ASSUME_ACTION_TYPE_CORRECTED = 0.1
local MIN_SUCCESS_WARD = 5
-------- VAN_GuideWardAtIndex()
function VAN_GuideWardAtIndex(gsiPlayer, wardIndex, hItem)
	local correctedVec = t_ward_correction[wardIndex]
	local isCorrected = t_ward_is_corrected[wardIndex]
	if not correctedVec or isCorrected == false then
		ALERT_print(
				string.format(
					"VAN_GuideWardAtIndex%s wardIndex is out-of-range. Was previously in range: %s. Location: %s",
					Util_ParamString( gsiPlayer, wardIndex, hItem),
					Util_Printable(isCorrected ~= nil),
					correctedVec
				)
			)
		
		
		
		
		
		return false; -- MODULE MUST CORRECT ITSELF
	end

	if isCorrected then
		if VERBOSE then
			VEBUG_print(
					string.format("[vantage] placing at confirmed okay loc: %s",
						tostring(correctedVec)
					)
				)
		end
		DebugDrawLine(t_ward_loc[wardIndex], correctedVec, 0, 255, 255)
		if Vector_PointDistance2D(gsiPlayer.lastSeen.location, correctedVec) > 1600 then
			
			Positioning_ZSMoveCasual(gsiPlayer, correctedVec, 150, 900, 1, false)
		else
			
			gsiPlayer.hUnit:Action_UseAbilityOnLocation(hItem, correctedVec)
		end
		
		

		return true;
	end
	--else isCorrected == nil... uninitialized
	-- Confirm a valid ward location
	local hUnit = gsiPlayer.hUnit
--	hUnit:Action_ClearActions(true) -- Set state idle
--	workingVec = Vector(
--			t_ward_loc[wardIndex].x - 200.0,
--			t_ward_loc[wardIndex].y - 200.0,
--			t_ward_loc[wardIndex].z
--		)
--	correctedVec = Vector(0.0, 0.0, DEFAULT_WARD_HEIGHT)
--
--	local thisSuccessCount = 0
--	for i=1,20 do
--		for j=1,20 do
--			if VERBOSE then
--				VEBUG_print(
--						string.format(
--							"[vantage] %s attempted to correct with %s, h-%d",
--							tostring(t_ward_loc[wardIndex]),
--							tostring(workingVec),
--							GetHeightLevel(workingVec)
--						)
--					)
--			end
--			if GetHeightLevel(workingVec) == 1 then
--				hUnit:Action_UseAbilityOnLocation(hItem, workingVec)
--				if hUnit:GetCurrentActionType() == BOT_ACTION_TYPE_USE_ABILITY then
--					hUnit:Action_ClearActions(true)
--					thisSuccessCount = thisSuccessCount + 1
--					correctedVec.x = correctedVec.x + (workingVec.x - correctedVec.x)/thisSuccessCount
--					correctedVec.y = correctedVec.y + (workingVec.y - correctedVec.y)/thisSuccessCount
--					if hUnit:GetCurrentActionType() ~= BOT_ACTION_TYPE_NONE and
--							hUnit:GetCurrentActionType() ~= BOT_ACTION_TYPE_IDLE then
--						Util_CauseError(CLEAR_ACTION_UNEXPECTED_BEHAVIOUR_MSG)
--					end
--				end
--			end
--			workingVec.y = workingVec.y + 20.0
--		end
--		workingVec.y = workingVec.y - 400.0
--		workingVec.x = workingVec.x + 20.0
--	end
--	if thisSuccessCount >= MIN_SUCCESS_WARD then
--		-- moment of truth, does the average location really work:
--		hUnit:Action_ClearActions(true)
--		if hUnit:GetCurrentActionType() ~= BOT_ACTION_TYPE_NONE and
--				hUnit:GetCurrentActionType() ~= BOT_ACTION_TYPE_IDLE then
--			Util_CauseError(CLEAR_ACTION_UNEXPECTED_BEHAVIOUR_MSG)
--		end
--		hUnit:Action_UseAbilityOnLocation(hItem, correctedVec)
--		if hUnit:GetCurrentActionType() ~= BOT_ACTION_TYPE_NONE and
--				hUnit:GetCurrentActionType() ~= BOT_ACTION_TYPE_IDLE then
	local pnot = gsiPlayer.nOnTeam
	local currTime = GameTime()
	if t_player_check_limit[pnot] and t_player_check_limit[pnot] > currTime
			and (t_player_check_index[pnot] or -0x80) == wardIndex then
		t_player_check_frame[pnot] = t_player_check_frame[gsiPlayer.nOnTeam] + 1
	else
		-- start validity check
		gsiPlayer.hUnit:Action_ClearActions(true)
		t_player_check_index[pnot] = wardIndex
		t_player_check_frame[pnot] = 0
		t_player_check_limit[pnot] = GameTime() + 5
		gsiPlayer.hUnit:Action_UseAbilityOnLocation(hItem, correctedVec)
		INFO_print(
				string.format("[vantage] starting ward location correction on %s...",
					correctedVec
				)
			)
		return true;
	end

	if t_player_check_frame[pnot] == 2 then
		if IsLocationVisible(correctedVec)
				or Vector_PointDistance(gsiPlayer.lastSeen.location, correctedVec) < hItem:GetCastRange()*1.1 then
			t_player_check_limit[pnot] = 0
			return false; -- Cannot confirm it works, because the location is visible || we are close enough to go idle from placing.
		elseif gsiPlayer.hUnit:GetCurrentActionType() == BOT_ACTION_TYPE_USE_ABILITY
				and hUnit:GetCurrentActiveAbility()
				and string.find(hUnit:GetCurrentActiveAbility():GetName(), "ward") then
			gsiPlayer.hUnit:Action_UseAbilityOnEntity(hItem, gsiPlayer.hUnit)
			-- We lasted two frames after ordering a use ward at location, must be fine. (may still be on low ground, terribly placed)
			t_ward_correction[wardIndex] = correctedVec
			t_ward_is_corrected[wardIndex] = true
			INFO_print(
					string.format(
						"[vantage] Automatically corrected a presumed warding pillar location indexed %s @ %s on final action %s. %s. %s",
						wardIndex,
						correctedVec,
						hUnit:GetCurrentActionType(),
						hUnit:GetCurrentActiveAbility() and hUnit:GetCurrentActiveAbility():GetName(),
						tostring(correctedVec)
					)
				)
			return true;
		end
		
		INFO_print(
				string.format(
					"[vantage] Failed to find a placeable ward location for ward index %s @ %s, %s %s",
					wardIndex,
					tostring(t_ward_loc[wardIndex]),
					hUnit:GetCurrentActionType(),
					hUnit:GetCurrentActiveAbility() and hUnit:GetCurrentActiveAbility():GetName() or "<no-active-ability>"
				)
			)








		t_ward_correction[wardIndex] = t_ward_correction[count_ward_spots]
		t_ward_correction[count_ward_spots] = nil
		t_ward_loc[wardIndex] = t_ward_loc[count_ward_spots]
		t_ward_loc[count_ward_spots] = nil
		t_is_warded[wardIndex] = t_is_warded[count_ward_spots]
		t_is_warded[count_ward_spots] = nil
		t_ward_is_corrected[wardIndex] = t_ward_is_corrected[count_ward_spots]
		t_ward_is_corrected[count_ward_spots] = nil -- this line was missing and poisiong the tables with false is_corrected
		t_ward_score_cache[wardIndex] = t_ward_score_cache[count_ward_spots]
		t_ward_score_cache[count_ward_spots] = nil
		count_ward_spots = count_ward_spots-1
		for k=1,3 do
			if t_preferred_ward_index_cache[k] == wardIndex then
				t_preferred_ward_index_cache[4] = nil
				for q=k,3 do
					t_preferred_ward_index_cache[q] = t_preferred_ward_index_cache[q+1]
				end
				count_preferred_ward_locations = count_preferred_ward_locations - 1
				break;
			end
		end









		return false;
	end
	return true; -- keep waiting
end
local F_GUIDE_WARD = VAN_GuideWardAtIndex

function VAN_GuideWardAtIndexKillDevalued(gsiPlayer, wardIndex, hItem)
	for i=1,3 do
		if t_preferred_ward_index_cache[i] == wardIndex then
			return F_GUIDE_WARD(gsiPlayer, wardIndex, hItem)
		end
	end
	if DEBUG then
		ALERT_print(
				string.format(
					"[vantage] no ward at %d. Found: %d %d %d.",
					wardIndex,
					t_preferred_ward_index_cache[1] or -0,
					t_preferred_ward_index_cache[2] or -0,
					t_preferred_ward_index_cache[3] or -0
				)
			)
	end
	return false -- The ward is no longer one of the best 3 disparate locations (ignores hero state)
end
