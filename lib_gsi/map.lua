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

-- 22/03/23 unextensible code is my own fault, being fixed gradually.
-- TODO Wouldn't even notice a map-changing patch.
local TEAM = TEAM
local TEAM_RADIANT = TEAM_RADIANT
local TEAM_DIRE = TEAM_DIRE
local Math_PointToPointDistance2D = Math_PointToPointDistance2D
local Vector = Vector

MAP_ZONE_RADIANT_OFFLANE = 				0x0001
MAP_ZONE_LANE_RADIANT_MID = 			0x0002
MAP_ZONE_LANE_RADIANT_BOT = 			0x0003
MAP_ZONE_LANE_DIRE_TOP =				0x0101
MAP_ZONE_LANE_DIRE_MID =				0x0102
MAP_ZONE_LANE_DIRE_BOT =				0x0103
MAP_ZONE_TERRITORY_RADIANT = 			0x0201
MAP_ZONE_TERRITORY_DIRE =				0x0202
MAP_ZONE_FOUNTAIN_RADIANT =				0x0401
MAP_ZONE_FOUNTAIN_DIRE =				0x0402
MAP_WARD_RADIANT_1 =					0x0801
MAP_WARD_RADIANT_2 =					0x0802
MAP_WARD_RADIANT_3 =					0x0803

-- Uninterrupted creep half-way lane location
MAP_POINT_TOP_NATURAL_MEET =			0x1001
MAP_POINT_MIDDLE_NATURAL_MEET =			0x1002
MAP_POINT_BOTTOM_NATURAL_MEET = 		0x1003

-- Lane creep spawners
MAP_POINT_RADIANT_TOP_SPAWNER =			0x1004
MAP_POINT_RADIANT_MIDDLE_SPAWNER =		0x1005
MAP_POINT_RADIANT_BOTTOM_SPAWNER = 		0x1006
MAP_POINT_DIRE_TOP_SPAWNER =			0x1007
MAP_POINT_DIRE_MIDDLE_SPAWNER =			0x1008 -- TODO Make these M_TOP + M_LANE + M_RADIANT_SPAWNER = MAP_ZONE_TOP_LANE_RADIANT_SPAWNER?
MAP_POINT_DIRE_BOTTOM_SPAWNER =			0x1009

-- Towers
MAP_POINT_RADIANT_TOP_T1 =				0x1101
MAP_POINT_RADIANT_TOP_T2 =				0x1102
MAP_POINT_RADIANT_TOP_T3 =				0x1103
MAP_POINT_RADIANT_MIDDLE_T1 =			0x1104
MAP_POINT_RADIANT_MIDDLE_T2 =			0x1105
MAP_POINT_RADIANT_MIDDLE_T3 =			0x1106
MAP_POINT_RADIANT_BOTTOM_T1 =			0x1107
MAP_POINT_RADIANT_BOTTOM_T2 =			0x1108
MAP_POINT_RADIANT_BOTTOM_T3 =			0x1109
MAP_POINT_RADIANT_T4 =					0x110A
MAP_POINT_DIRE_TOP_T1 =					0x110B
MAP_POINT_DIRE_TOP_T2 =					0x110C
MAP_POINT_DIRE_TOP_T3 =					0x110D
MAP_POINT_DIRE_MIDDLE_T1 =				0x110E
MAP_POINT_DIRE_MIDDLE_T2 =				0x110F
MAP_POINT_DIRE_MIDDLE_T3 =				0x1110
MAP_POINT_DIRE_BOTTOM_T1 =				0x1111
MAP_POINT_DIRE_BOTTOM_T2 =				0x1112
MAP_POINT_DIRE_BOTTOM_T3 =				0x1113				
MAP_POINT_DIRE_T4 =						0x1114
MAP_POINT_RADIANT_FOUNTAIN_CENTER =		0x1201
MAP_POINT_RADIANT_ANCIENT_ON_ROPES =	0x1202
MAP_POINT_DIRE_FOUNTAIN_CENTER =		0x1209
MAP_POINT_DIRE_ANCIENT_ON_ROPES =		0x120A

local MAP_TEAM_TOWER = 0x1100
local MAP_TEAM_TOWER_RADIANT_OFFSET = 0x0001
local MAP_TEAM_TOWER_DIRE_OFFSET = 0x000A
local MAP_TEAM_TOWER_T4_OFFSET = MAP_TEAM_TOWER_DIRE_OFFSET - MAP_TEAM_TOWER_RADIANT_OFFSET -- 9

local BASE_LIMIT_RAD_TOP_SIDE = Vector(-9000, -2443, 0)
local BASE_LIMIT_RAD_TOP = Vector(-5027, -2443, 0)
local BASE_LIMIT_RAD_BOT = Vector(-3057, -4628, 0)
local BASE_LIMIT_RAD_BOT_SIDE = Vector(-3057, -9000, 0)
local BASE_LIMIT_DIRE_TOP_SIDE = Vector(2559, 9000, 0)
local BASE_LIMIT_DIRE_TOP = Vector(2559, 3820, 0)
local BASE_LIMIT_DIRE_BOT = Vector(4682, 2029, 0)
local BASE_LIMIT_DIRE_BOT_SIDE = Vector(9000, 2029, 0)

MAP_LOGICAL_TOP_LANE =			0x0001 -- N.B. Higher code will iterate 1 -> 3
MAP_LOGICAL_MIDDLE_LANE =		0x0002
MAP_LOGICAL_BOTTOM_LANE =		0x0003
MAP_LOGICAL_RADIANT_BASE =		0x0004
MAP_LOGICAL_DIRE_BASE =			0x0005
MAP_LOGICAL_ALL =				0x0006

MAP_LOGICAL_SAFE_LANE = TEAM_IS_RADIANT and MAP_LOGICAL_BOTTOM_LANE or MAP_LOGICAL_TOP_LANE
MAP_LOGICAL_MID_LANE = MAP_LOGICAL_MIDDLE_LANE
MAP_LOGICAL_OFF_LANE = TEAM_IS_RADIANT and MAP_LOGICAL_TOP_LANE or MAP_LOGICAL_BOTTOM_LANE

MAX_DOTA_LANES = 3
MAX_LOGICAL_LANES = 5 -- + radiantBase, direBase

MID_CREEP_RACE_LENGTH = 13300
SIDE_LANE_CREEP_RACE_LENGTH = 19400 -- approx, with curve

UNITS_SPAWNER_TO_ELL_BEND = 9400
UNITS_SPAWNER_EARLY_TO_END_OFFSET = 9600
UNITS_SPAWNER_TO_MID_VIA_LANE = MID_CREEP_RACE_LENGTH / 2

LANE_ELL_BEND_OFFSET = 6100 -- Both top and bottom lanes bend around this offset
FACTOR_FOR_COORDINATES_PROGRESS = LANE_ELL_BEND_OFFSET / 2
MAP_COORDINATE_BOUND_NUMERICAL = 8000

local sin = math.sin
local cos = math.cos

local SIDE_LANE_MEET_TIME = 29.9
local MIDDLE_LANE_MEET_TIME = 18

local X_TO_Y_SIDE_LANE_FACTOR = 1.1
local Y_OF_X_MID_LINE = 0.9 -- y = x*0.895288..
local DISTANCE_TO_MID_X_LINE = 9700 / 12831
local DISTANCE_TO_MID_Y_LINE = 8400 / 12831
local NEXT_CREEPS_SPAWN_DURING_RACE_DIST = 30 * 325

local LIMIT_TO_TOWER_FRIENDLY_OFFSET = 200

local RATIO_OF_CARTESIAN_AXIS_TO_45_DEGREE_LINE = math.cos(MATH_PI/4)

local BIN_TREE_LEFT_OR_UP = 1
local BIN_TREE_RIGHT_OR_DOWN = 2
local DATA_TBL = 3

local logical_zones = {
	[MAP_ZONE_RADIANT_OFFLANE] = {
		Vector(-7923, 533, 0), Vector(-5396, 1732, 0), Vector(-1614, 7774, 0), Vector(-7401, 6466, 0)
	},
	[MAP_ZONE_TERRITORY_RADIANT] = {
		Vector(-8200, 8000, 0), Vector(8000, -8000, 0), Vector(-8000, -8000, 0)
	},
	[MAP_ZONE_TERRITORY_DIRE] = {
		Vector(-8100, 8001, 0), Vector(8001, -7900, 0), Vector(8200, 8001, 0)
	},
	[MAP_ZONE_FOUNTAIN_RADIANT] = {
		Vector(-6812, -5804, 0), Vector(-6269, -6337, 0), Vector(-6655, -7373, 0), Vector(-7870, -6193, 0)
	},
	[MAP_ZONE_FOUNTAIN_DIRE] = {
		Vector(6162, 6193, 0), Vector(6662, 5646, 0), Vector(7903, 6094, 0), Vector(6777, 7180, 0)
	},
}

local logical_points = {
	[MAP_POINT_RADIANT_FOUNTAIN_CENTER] = Vector(-6915, -6401, 0),
	[MAP_POINT_DIRE_FOUNTAIN_CENTER] = Vector(6811, 6241, 0),
	[MAP_POINT_BOTTOM_NATURAL_MEET] = Vector(5800, -5500, 0),
	[MAP_POINT_MIDDLE_NATURAL_MEET] = Vector(-533, -410, 0),
	[MAP_POINT_TOP_NATURAL_MEET] = Vector(-5550, 5550, 0),
	[MAP_POINT_RADIANT_TOP_SPAWNER] = Vector(-6400, -3650, 0), -- side to side spawner ~19400 units or 10000*2 with a right angle
	[MAP_POINT_RADIANT_MIDDLE_SPAWNER] = Vector(-5150, -4500, 0), -- mid to mid spawner ~12800 units
	[MAP_POINT_RADIANT_BOTTOM_SPAWNER] = Vector(-4450, -6150, 0),
	[MAP_POINT_DIRE_TOP_SPAWNER] = Vector(4250, 5950, 0), 
	[MAP_POINT_DIRE_MIDDLE_SPAWNER] = Vector(4550, 3900, 0),
	[MAP_POINT_DIRE_BOTTOM_SPAWNER] = Vector(6050, 3500, 0),
	[MAP_POINT_RADIANT_ANCIENT_ON_ROPES] = Vector(-6180, -5720, 0),
	[MAP_POINT_DIRE_ANCIENT_ON_ROPES] = Vector(5950, 5370, 0)
}
TEAM_FOUNTAIN = TEAM_IS_RADIANT and logical_points[MAP_POINT_RADIANT_FOUNTAIN_CENTER]
		or logical_points[MAP_POINT_DIRE_FOUNTAIN_CENTER]
ENEMY_FOUNTAIN = TEAM_IS_RADIANT and logical_points[MAP_POINT_DIRE_FOUNTAIN_CENTER]
		or logical_points[MAP_POINT_RADIANT_FOUNTAIN_CENTER]

local ward_locations = {
	[MAP_WARD_RADIANT_1] = {
		Vector(-4353, -1037, 0)
	},
	[MAP_WARD_RADIANT_2] = {
		Vector(-3249, -1393, 0)
	},
	[MAP_WARD_RADIANT_3] = {
		Vector(-3249, -1393, 0)
	},
}

local fountain_entrance_top_loc = TEAM_IS_RADIANT
		and Vector(TEAM_FOUNTAIN.x, TEAM_FOUNTAIN.y + 300, TEAM_FOUNTAIN.z)
		or Vector(TEAM_FOUNTAIN.x - 300, TEAM_FOUNTAIN.y, TEAM_FOUNTAIN.z)
local fountain_entrance_bot_loc = TEAM_IS_RADIANT
		and Vector(TEAM_FOUNTAIN.x + 300, TEAM_FOUNTAIN.y, TEAM_FOUNTAIN.z)
		or Vector(TEAM_FOUNTAIN.x, TEAM_FOUNTAIN.y - 300, TEAM_FOUNTAIN.z)

local GIVE_UP_FINDING_GOAL_POSTS = GameTime() + 80

-------------- set_fountain_search_move()
local function set_fountain_search_move(gsiPlayer, isTop, isGetOut)
	local isRadiant = TEAM_IS_RADIANT
	local startOffset = isRadiant and 1400 or -1400
	local testCoord
	if isRadiant then
		testCoord = isTop and 'y' or 'x'
	else
		testCoord = isTop and 'x' or 'y'
	end
	local addConstant = isRadiant and -50 or 50
	local testVec = Vector(TEAM_FOUNTAIN.x, TEAM_FOUNTAIN.y)
	testVec[testCoord] = testVec[testCoord] + startOffset
	local depth = GetHeightLevel(testVec)
	local i = 1
	while(true) do
		i = i + 1 if i > 50 then WARN_print("[map] set_fountain_search_move TERRAIN UNEXPECTED; BREAK") break; end
		
		
		if GetHeightLevel(testVec) < depth then
			testVec[testCoord] = testVec[testCoord] + (isGetOut and -addConstant*7 or addConstant)
			gsiPlayer.checkingFountainMove = testVec
			break;
		end
		if isRadiant and testVec[testCoord] < TEAM_FOUNTAIN[testCoord]
				or not isRadiant and testVec[testCoord] > TEAM_FOUNTAIN[testCoord] then
			GIVE_UP_FINDING_GOAL_POSTS = 0 -- end
			return;
		end
		testVec[testCoord] = testVec[testCoord] + addConstant
	end
end
-------- Map_FindFountainGoalPosts()
function Map_FindFountainGoalPosts(gsiPlayer)
	if GameTime() > GIVE_UP_FINDING_GOAL_POSTS
			or Vector_PointDistance2D(gsiPlayer.lastSeen.location,
					TEAM_FOUNTAIN
				) > 1400 then
		
		gsiPlayer.checkingFountain = nil
		gsiPlayer.checkingFountainMove = nil
		gsiPlayer.checkingFountainGetOutMove = nil
		DOMINATE_SetDominateFunc(gsiPlayer, "map_find_fountain_goal_posts", Map_FindFountainGoalPosts, false)
		Map_FindFountainGoalPosts = nil
		return;
	end
	if (not gsiPlayer.checkingFountain) then
		set_fountain_search_move(gsiPlayer, true, true)
		gsiPlayer.checkingFountain = "topGetOut"
		return;
	end
		
	local hasFountainAura = gsiPlayer.hUnit:HasModifier("modifier_fountain_aura_buff")
	local isGetOut = string.find(gsiPlayer.checkingFountain, "GetOut") and true
	local isTop = string.find(gsiPlayer.checkingFountain, "top") and true

	

	if hasFountainAura then
		if isGetOut then
			
			gsiPlayer.hUnit:Action_MoveDirectly(gsiPlayer.checkingFountainMove)
			return;
		elseif isTop then -- top not get out has fontain aura
			fountain_entrace_top_loc = gsiPlayer.lastSeen.location
			set_fountain_search_move(gsiPlayer, false, true)
			gsiPlayer.checkingFountain = "botGetOut"
			GIVE_UP_FINDING_GOAL_POSTS = GameTime() + 9
			return;
		else -- bot not get out has fountain aura
			fountain_entrance_bot_loc = gsiPlayer.lastSeen.location
			DOMINATE_print(gsiPlayer, true, "[map] Found fountain goal posts on %s, %s %s",
					TEAM_IS_RADIANT and "Radiant" or "Dire",
					tostring(fountain_entrance_top_loc),
					tostring(fountain_entrance_bot_loc)
				)
			fountain_back_estimate = Vector_Addition(
					Vector_PointBetweenPoints(
							fountain_entrance_top_loc,
							fountain_entrance_bot_loc
						),
					Vector_ScalarMultiply(Vector_CrossProduct(
								Vector_UnitDirectionalPointToPoint(
									fountain_entrance_top_loc,
									fountain_entrance_bot_loc
								),
								TEAM_IS_RADIANT and Vector(0, 0, 1) or Vector(0, 0, -1)
							),
							1300
						)
				)
			gsiPlayer.hUnit:ActionImmediate_Ping(fountain_back_estimate.x, fountain_back_estimate.y, false)
			GIVE_UP_FINDING_GOAL_POSTS = 0
			return;
		end
	else -- not aura'd
		if not isGetOut then
			gsiPlayer.hUnit:Action_MoveDirectly(gsiPlayer.checkingFountainMove)
			return;
		end
		if isTop then
			-- chance of minor top inaccuracy if the bot is reloaded just outside of fountain
			set_fountain_search_move(gsiPlayer, true)
			gsiPlayer.checkingFountain = "top"
		else
			set_fountain_search_move(gsiPlayer, false, false)
			gsiPlayer.checkingFountain = "bot"
			set_fountain_search_move = nil
		end
	end
end

function Map_LocIsInTeamFountain(location)
	return Vector_PointWithinTriangle(location, fountain_entrance_top_loc,
			fountain_entrance_bot_loc, fountain_back_estimate
		)
end

local function is_location_bottom_lane(p)
	return p.x > 4440 and p.y < 2531 + 1.33*(p.x-4440)
			or p.x <= 4440 and p.y < -10120 - 67672295/(p.x - 9761)
end

local function is_location_top_lane(p)
	return p.y > 9305 - 55392793/(9711 + p.x)
end

-- Returns a factor 0.0 - 1.0 of the amount to multiply one of either side of an equation for z-progress. e.g. as progress grows from radiant top spawner, only the y-value should increase until it hits the curve
-- Just a quick note that in hindsight, although this is very cool, it is also very retarded, and I should've used two piecewise linear function for each side lane. They are faster and also way, way easier to maintain for map changes. I knew it while doing it but I just wanted to learn curve-stuff as I'd hardly applied linear maths to programming in my time.
local function lane_curve_sigmoid_factor(progress)
	return progress < 0.4 and 0.0 or progress > 0.6 and 1.0 or 1 / (1 + (16.32878^(13 - 26*progress)))
end
function lane_value_sigmoid_early(progress) -- *load the revolver*
	local factor = lane_curve_sigmoid_factor(progress) -- *paint a target on my foot*
	--print("early say", progress, 2*UNITS_SPAWNER_TO_ELL_BEND*(1-factor)*progress + factor*UNITS_SPAWNER_TO_ELL_BEND)
	return 2*UNITS_SPAWNER_TO_ELL_BEND*((1-factor)^1.15)*progress + factor*UNITS_SPAWNER_EARLY_TO_END_OFFSET -- *pass valve the gun*
end
function lane_value_sigmoid_late(progress)
	local factor = lane_curve_sigmoid_factor(progress)
	--print("late say", progress, 2*UNITS_SPAWNER_TO_ELL_BEND*(progress)*(factor) - factor*UNITS_SPAWNER_TO_ELL_BEND)
	return 2*UNITS_SPAWNER_EARLY_TO_END_OFFSET*(factor^0.8)*progress - factor*UNITS_SPAWNER_TO_ELL_BEND 
end
-- Benchark: Using the pair of factor calculations 8000 times / frame represented a frame rate drop of 5-10 from 120 fps. This should be used about 6 times per frame. Representing a drop of ~0.0056 fps from 120 or 1/177 of a frame

local function Map_LaneProgressAtCoordinates(team, lane, x, y)
	x = x + MAP_COORDINATE_BOUND_NUMERICAL
	y = y + MAP_COORDINATE_BOUND_NUMERICAL
	if lane == MAP_LOGICAL_MIDDLE_LANE then
		return team == TEAM_RADIANT and x*235134
	elseif lane == MAP_LOGICAL_TOP_LANE or lane == MAP_LOGICAL_BOTTOM_LANE then
	
	end
	return -1.0
end

function Map_IsAboveMiddleLine(loc)
	return loc.y > 0.873489 * loc.x - 223
end

function Map_GetAncientOnRopesFightLocation(team)
	return logical_points[team == TEAM_RADIANT and MAP_POINT_RADIANT_ANCIENT_ON_ROPES or MAP_POINT_DIRE_ANCIENT_ON_ROPES]
end

function Map_GetLogicalLocation(zoneID)
	return logical_zones[zoneID] or logical_points[zoneID]
end

function Map_GetTeamFountainLocation()
	if TEAM == TEAM_RADIANT then
		return logical_points[MAP_POINT_RADIANT_FOUNTAIN_CENTER]
	else
		return logical_points[MAP_POINT_DIRE_FOUNTAIN_CENTER]
	end
end

function Map_GetFountainLocationTeam(team)
	if team == TEAM_RADIANT then
		return logical_points[MAP_POINT_RADIANT_FOUNTAIN_CENTER]
	elseif team == TEAM_DIRE then
		return logical_points[MAP_POINT_DIRE_FOUNTAIN_CENTER]
	end
	Util_CauseError()
end

function Map_LocationIsCreepPathInLane(p, lane)
	if false then

	end
end

-- Or, the lane you would say a creep was in currently. For the purposes of farming and clearing creeps, creeps
--	sieging past T3 highground are considered to be in the base they are attacking.
function Map_GetBaseOrLaneLocation(p)
	if Vector_SideOfPlane(p, BASE_LIMIT_RAD_BOT_SIDE, BASE_LIMIT_RAD_BOT) == 1
			and Vector_SideOfPlane(p, BASE_LIMIT_RAD_BOT, BASE_LIMIT_RAD_TOP) == 1
			and Vector_SideOfPlane(p, BASE_LIMIT_RAD_TOP, BASE_LIMIT_RAD_TOP_SIDE) == 1 then
		return MAP_LOGICAL_RADIANT_BASE
	elseif Vector_SideOfPlane(p, BASE_LIMIT_DIRE_TOP_SIDE, BASE_LIMIT_DIRE_TOP) == 1
			and Vector_SideOfPlane(p, BASE_LIMIT_DIRE_TOP, BASE_LIMIT_DIRE_BOT) == 1
			and Vector_SideOfPlane(p, BASE_LIMIT_DIRE_BOT, BASE_LIMIT_DIRE_BOT_SIDE) == 1 then
		return MAP_LOGICAL_DIRE_BASE
	end
	return Map_GetLaneValueOfMapPoint(p)
end

function Map_GetLaneValueOfMapPoint(p)
	return is_location_bottom_lane(p) and MAP_LOGICAL_BOTTOM_LANE or
			is_location_top_lane(p) and MAP_LOGICAL_TOP_LANE or
			MAP_LOGICAL_MIDDLE_LANE
end

function Map_BaseLogicalLocationIsTeam(logicalLocation)
	if logicalLocation == MAP_LOGICAL_RADIANT_BASE then
		return TEAM == TEAM_RADIANT
	elseif logicalLocation == MAP_LOGICAL_DIRE_BASE then
		return TEAM == TEAM_DIRE
	end
end

function Map_GetTeamBaseLogicalLane(team)
	return team == TEAM_RADIANT and MAP_LOGICAL_RADIANT_BASE
			or team == TEAM_DIRE and MAP_LOGICAL_DIRE_BASE or -1
end

function Map_LaneLogicalToNaturalMeet(lane)
	return (lane == MAP_LOGICAL_TOP_LANE and logical_points[MAP_POINT_TOP_NATURAL_MEET]) or
			lane == MAP_LOGICAL_MIDDLE_LANE and logical_points[MAP_POINT_MIDDLE_NATURAL_MEET] or
			logical_points[MAP_POINT_BOTTOM_NATURAL_MEET]
end

function Map_TeamSpawnerLoc(team, lane)
	if team == TEAM_RADIANT then
		return lane == MAP_LOGICAL_TOP_LANE and logical_points[MAP_POINT_RADIANT_TOP_SPAWNER] or lane == MAP_LOGICAL_MIDDLE_LANE and logical_points[MAP_POINT_RADIANT_MIDDLE_SPAWNER] or lane == MAP_LOGICAL_BOTTOM_LANE and logical_points[MAP_POINT_RADIANT_BOTTOM_SPAWNER] or logical_points[MAP_POINT_RADIANT_FOUNTAIN_CENTER]
	else
		return lane == MAP_LOGICAL_TOP_LANE and logical_points[MAP_POINT_DIRE_TOP_SPAWNER] or lane == MAP_LOGICAL_MIDDLE_LANE and logical_points[MAP_POINT_DIRE_MIDDLE_SPAWNER] or lane == MAP_LOGICAL_BOTTOM_LANE and logical_points[MAP_POINT_DIRE_BOTTOM_SPAWNER] or logical_points[MAP_POINT_DIRE_FOUNTAIN_CENTER]
	end
end

--[[FUNCVAL]]local GAME_STATE_PRE_GAME = GAME_STATE_PRE_GAME
-------- Map_ExtrapolatedLaneFrontWhenDeadBasic(...
function Map_ExtrapolatedLaneFrontWhenDeadBasic(teamCreepsToFind, lane, closerToSpawnerThanLoc)
	local mod30DotaTime = math.abs(DotaTime() + (TEAM~=teamCreepsToFind and 1 or -1)) % 30.0 -- This is dangerous because it causes early flips to the lower creep set (we see the enemy further away)
	if GetGameState() == GAME_STATE_PRE_GAME then mod30DotaTime = 30 - mod30DotaTime end
	if lane == MAP_LOGICAL_MIDDLE_LANE then
		if teamCreepsToFind == TEAM_RADIANT then
			local spawner = logical_points[MAP_POINT_RADIANT_MIDDLE_SPAWNER]
			-- DebugDrawCircle(spawner, 500, 255, 0, 0)
			local closerFromDist = Math_PointToPointDistance2D(closerToSpawnerThanLoc, spawner)
			-- DebugDrawLine(spawner, Vector(spawner.x + closerFromDist*DISTANCE_TO_MID_X_LINE, spawner.y + closerFromDist*DISTANCE_TO_MID_Y_LINE, 0), 255, 0, 0)
			local highestDistance = mod30DotaTime * LANE_CREEP_MOVEMENT_SPEED + (mod30DotaTime > 22 and NEXT_CREEPS_SPAWN_DURING_RACE_DIST or 0)
			while (highestDistance > closerFromDist) do
				highestDistance = highestDistance - LANE_CREEP_MOVEMENT_SPEED*30
				if highestDistance < 300 then 
					return spawner
				end
			end
			--DebugDrawLine(spawner, Vector(spawner.x + highestDistance*DISTANCE_TO_MID_X_LINE, spawner.y + highestDistance*DISTANCE_TO_MID_Y_LINE, 0), 255, 0, 0)
			return Vector(spawner.x + highestDistance*DISTANCE_TO_MID_X_LINE, spawner.y + highestDistance*DISTANCE_TO_MID_Y_LINE, 0)
		else
			local spawner = logical_points[MAP_POINT_DIRE_MIDDLE_SPAWNER]
			-- DebugDrawCircle(spawner, 500, 0, 255, 0)
			local closerFromDist = Math_PointToPointDistance2D(closerToSpawnerThanLoc, spawner)
			-- DebugDrawLine(spawner, Vector(spawner.x - closerFromDist * DISTANCE_TO_MID_X_LINE, spawner.y - closerFromDist*DISTANCE_TO_MID_Y_LINE, 0), 0, 255, 0)
			local highestDistance = mod30DotaTime * LANE_CREEP_MOVEMENT_SPEED + (mod30DotaTime > 22 and NEXT_CREEPS_SPAWN_DURING_RACE_DIST or 0)
			while (highestDistance > closerFromDist) do
				highestDistance = highestDistance - LANE_CREEP_MOVEMENT_SPEED*30
				if highestDistance < 300 then 
					return spawner
				end
			end
			--DebugDrawLine(spawner, Vector(spawner.x - highestDistance*DISTANCE_TO_MID_X_LINE, spawner.y - highestDistance*DISTANCE_TO_MID_Y_LINE, 0), 0, 255, 0)
			return Vector(spawner.x - highestDistance*DISTANCE_TO_MID_X_LINE, spawner.y - highestDistance*DISTANCE_TO_MID_Y_LINE, 0)
		end
	end
	local naturalWaveCrash = Map_LaneLogicalToNaturalMeet(lane)
	local xDiff = naturalWaveCrash.x - closerToSpawnerThanLoc.x
	local yDiff = naturalWaveCrash.y - closerToSpawnerThanLoc.y 
	local timeProgressOffset = 0.5 + mod30DotaTime * 0.5/30
	if teamCreepsToFind == TEAM_RADIANT then
		if lane == MAP_LOGICAL_TOP_LANE then
			local closerToSpawnThanProgress = -xDiff > yDiff and 0.5+(-xDiff / SIDE_LANE_CREEP_RACE_LENGTH) or 0.5+(-yDiff / SIDE_LANE_CREEP_RACE_LENGTH) 
			local spawner = logical_points[MAP_POINT_RADIANT_TOP_SPAWNER]
			local progress = (closerToSpawnThanProgress < timeProgressOffset and math.max(0, timeProgressOffset - 0.5) or timeProgressOffset)
					--+ (TEAM ~= TEAM_RADIANT and 0.1 or 0.0) -- .'. 500 unit 'squish' for each team, a safe standing location when you don't know what's beyond fog.
			-- DebugDrawText(750, 750, string.format("radiant top progress: %f, %f, %.2f>%.2f? (%.2f, %.2f)", xDiff, yDiff, closerToSpawnThanProgress, progress, (X_TO_Y_SIDE_LANE_FACTOR*lane_value_sigmoid_late(progress))+spawner.x, lane_value_sigmoid_early(progress)+spawner.y), 255, 255, 255)
			if closerToSpawnThanProgress < progress then return spawner end
			return Vector((X_TO_Y_SIDE_LANE_FACTOR*lane_value_sigmoid_late(progress))+spawner.x, lane_value_sigmoid_early(progress)+spawner.y, 0)
		elseif lane == MAP_LOGICAL_BOTTOM_LANE then
			local closerToSpawnThanProgress = xDiff > -yDiff and 0.5-(xDiff / SIDE_LANE_CREEP_RACE_LENGTH) or 0.5+(-yDiff / SIDE_LANE_CREEP_RACE_LENGTH)
			local spawner = logical_points[MAP_POINT_RADIANT_BOTTOM_SPAWNER]
			local progress = (closerToSpawnThanProgress < timeProgressOffset and math.max(0, timeProgressOffset - 0.5) or timeProgressOffset)
			-- DebugDrawText(750, 775, string.format("radiant bot progress: %f, %f, %.2f>%.2f? (%.2f, %.2f)", xDiff, yDiff, closerToSpawnThanProgress, progress, (X_TO_Y_SIDE_LANE_FACTOR*lane_value_sigmoid_early(progress))+spawner.x, lane_value_sigmoid_late(progress)+spawner.y), 255, 255, 255)
			if closerToSpawnThanProgress < progress then return spawner end
			return Vector((X_TO_Y_SIDE_LANE_FACTOR*lane_value_sigmoid_early(progress))+spawner.x, lane_value_sigmoid_late(progress)+spawner.y, 0)
		end
	else
		if lane == MAP_LOGICAL_TOP_LANE then
			local closerToSpawnThanProgress = -xDiff > yDiff and 0.5+(xDiff / SIDE_LANE_CREEP_RACE_LENGTH) or 0.5+(yDiff / SIDE_LANE_CREEP_RACE_LENGTH)
			local spawner = logical_points[MAP_POINT_DIRE_TOP_SPAWNER]
			local progress = (closerToSpawnThanProgress < timeProgressOffset and math.max(0, timeProgressOffset - 0.5) or timeProgressOffset)
			-- DebugDrawText(750, 800, string.format("dire top progress: %f, %f, %.2f>%.2f? (%.2f, %.2f)", xDiff, yDiff, closerToSpawnThanProgress, progress, -(X_TO_Y_SIDE_LANE_FACTOR*lane_value_sigmoid_early(progress))+spawner.x, -lane_value_sigmoid_late(progress)+spawner.y), 255, 255, 255)
			if closerToSpawnThanProgress < progress then return spawner end
			return Vector(-(X_TO_Y_SIDE_LANE_FACTOR*lane_value_sigmoid_early(progress))+spawner.x, -lane_value_sigmoid_late(progress)+spawner.y, 0)
		elseif lane == MAP_LOGICAL_BOTTOM_LANE then
			local closerToSpawnThanProgress = xDiff > -yDiff and 0.5+(xDiff / SIDE_LANE_CREEP_RACE_LENGTH) or 0.5-(-yDiff / SIDE_LANE_CREEP_RACE_LENGTH)
			local spawner = logical_points[MAP_POINT_DIRE_BOTTOM_SPAWNER]
			local progress = (closerToSpawnThanProgress < timeProgressOffset and math.max(0, timeProgressOffset - 0.5) or timeProgressOffset)
			-- DebugDrawText(750, 825, string.format("dire bot progress: %f, %f, %.2f>%.2f? (%.2f, %.2f)", xDiff, yDiff, closerToSpawnThanProgress, progress, -(X_TO_Y_SIDE_LANE_FACTOR*lane_value_sigmoid_late(progress))+spawner.x, -lane_value_sigmoid_early(progress)+spawner.y), 255, 255, 255)
			-- DebugDrawText(
					-- 750, 
					-- 840, 
					-- string.format(
						-- "%s, (%f, %f) from (%f, %f)", 
						-- progress, 
						-- -(X_TO_Y_SIDE_LANE_FACTOR*lane_value_sigmoid_late(progress))+spawner.x, 
						-- -lane_value_sigmoid_early(progress)+spawner.y, lane_value_sigmoid_late(progress), 
						-- lane_value_sigmoid_early(progress),
						-- -lane_value_sigmoid_early(progress)
					-- ),
					-- 255, 255, 255
				-- )
			if closerToSpawnThanProgress < progress then return spawner end			
			return Vector(-(X_TO_Y_SIDE_LANE_FACTOR*lane_value_sigmoid_late(progress))+spawner.x, -lane_value_sigmoid_early(progress)+spawner.y, 0)
		end
	end
	print("/VUL-FT/ <WARN> map: lane parameter was invalid in Map_ExtrapolatedLaneFrontWhenDeadBasic().")
	return nil
end

-- Takes the half-way point, then uses y = -x and the difference of the shorter line to the lane to determine the crash
function Map_LaneHalfwayPoint(lane, p1, p2)
	local additionalPregameTime = DotaTime() < 0 and -DotaTime() or 0 -- Good bug puts bots in lanes, for now TODO
	local pointBetweenPoints = Vector_PointBetweenPoints(p1, p2)
if DEBUG then
	DebugDrawLine(p1, p2, 180, 100, 255)
	DebugDrawCircle(pointBetweenPoints, 100, 180, 100, 255)
end
	if lane == MAP_LOGICAL_MIDDLE_LANE then
		local xMidDistanceDiff = math.abs(p1.x - p2.x) -- Does not logically resemble the xDiff/yDiff of top and bot shown below
		local yMidDistanceDiff = math.abs(p1.y - p2.y)
		return pointBetweenPoints,
				(xMidDistanceDiff + yMidDistanceDiff) / (2 * LANE_CREEP_MOVEMENT_SPEED) + additionalPregameTime
	elseif lane == MAP_LOGICAL_TOP_LANE then
		local xDiff = math.abs(-LANE_ELL_BEND_OFFSET - pointBetweenPoints.x)
		local yDiff = math.abs(LANE_ELL_BEND_OFFSET - pointBetweenPoints.y)
		if xDiff > yDiff then
			if DEBUG then DebugDrawLine(pointBetweenPoints, Vector(pointBetweenPoints.x + (TEAM==TEAM_RADIANT and -yDiff or yDiff), LANE_ELL_BEND_OFFSET, 0), 180, 100, 255) end
			return Vector(pointBetweenPoints.x + (TEAM==TEAM_RADIANT and -yDiff or yDiff), LANE_ELL_BEND_OFFSET, 0),
					(xDiff + yDiff) / (2 * LANE_CREEP_MOVEMENT_SPEED) + additionalPregameTime
		else
			if DEBUG then DebugDrawLine(pointBetweenPoints, Vector(-LANE_ELL_BEND_OFFSET, pointBetweenPoints.y + (TEAM==TEAM_RADIANT and -xDiff or xDiff), 0), 180, 100, 255) end
			return Vector(-LANE_ELL_BEND_OFFSET, pointBetweenPoints.y + (TEAM==TEAM_RADIANT and -xDiff or xDiff), 0),
					(xDiff + yDiff) / (2 * LANE_CREEP_MOVEMENT_SPEED) + additionalPregameTime
		end
	else -- lane == MAP_LOGICAL_BOTTOM_LANE
		local xDiff = math.abs(LANE_ELL_BEND_OFFSET - pointBetweenPoints.x)
		local yDiff = math.abs(-LANE_ELL_BEND_OFFSET - pointBetweenPoints.y)
		if xDiff > yDiff then
			if DEBUG then DebugDrawLine(pointBetweenPoints, Vector(pointBetweenPoints.x + (TEAM==TEAM_RADIANT and -yDiff or yDiff), -LANE_ELL_BEND_OFFSET), 180, 100, 255) end
			return Vector(pointBetweenPoints.x + (TEAM==TEAM_RADIANT and -yDiff or yDiff), -LANE_ELL_BEND_OFFSET),
					(xDiff + yDiff) / (LANE_CREEP_MOVEMENT_SPEED) + additionalPregameTime
				-- cancel out 2*diffs / 2*creeps moving
		else
			if DEBUG then DebugDrawLine(pointBetweenPoints, Vector(LANE_ELL_BEND_OFFSET, pointBetweenPoints.y + (TEAM==TEAM_RADIANT and -xDiff or xDiff)), 180, 100, 255) end
			return Vector(LANE_ELL_BEND_OFFSET, pointBetweenPoints.y + (TEAM==TEAM_RADIANT and -xDiff or xDiff)),
					(xDiff + yDiff) / (LANE_CREEP_MOVEMENT_SPEED) + additionalPregameTime
		end
	end
end

UPDATE_PREVIOUS_SEEN_LOC_DELTA = THROTTLE_PLAYERS_LAST_SEEN_UPDATE*2
local UPDATE_PREVIOUS_SEEN_LOC_DELTA = UPDATE_PREVIOUS_SEEN_LOC_DELTA
local function time_since_last_seen(this)
	return this.timeStamp and GameTime() - this.timeStamp or -1.0
end
local function update_last_seen(this, newLoc, facingDegrees)
	local currTime = GameTime()
	if this.previousLocation
			and currTime - this.previousTimeStamp > UPDATE_PREVIOUS_SEEN_LOC_DELTA then
		--GetBot():ActionImmediate_Ping(newLoc.x, newLoc.y, true)
		this.previousLocation = Vector(this.location.x, this.location.y, this.location.z)
		this.previousTimeStamp = this.timeStamp
	end
	if this.location.x ~= newLoc.x or this.location.y ~= newLoc.y then
		this.location = Vector(newLoc.x, newLoc.y, newLoc.z)
	end
	if facingDegrees then
		this.previousFacingDegrees = this.facingDegrees or 0
		this.facingDegrees = facingDegrees
	end
	this.timeStamp = currTime
end
function Map_CreateLastSeenTable(location, trackPrevious, facingDegrees)
	local currTime = GameTime()
	local t = {}
	t.GetTimeSinceLastSeen = time_since_last_seen
	t.Update = update_last_seen
	t.location = Vector(location.x, location.y, location.z)
	t.facingDegrees = facingDegrees or -0
	t.timeStamp = GameTime()
	if trackPrevious then
		t.previousLocation = location
		t.previousTimeStamp = t.timeStamp
	end
	return t
end

function Map_GetNearestPortableStructure(gsiPlayer, location)
	local laneApproximation = Map_GetLaneValueOfMapPoint(location)
	return Map_LimitLaneLocationToLowTierTeamTower(gsiPlayer.team, laneApproximation, location)
end

local lurk_pockets_tree = {}

function Map_ConfirmLurks(gsiPlayer, lurk)
	
end

function Map_CheckForLurkPockets(gsiPlayer)
	local playerLoc = gsiPlayer.lastSeen.location
	local prevVector = Vector(playerLoc.x, playerLoc.y)
	for rad=0,6.08,0.2094 do
		local currVec = Vector(playerLoc.x + sin(rad), playerLoc.y + cos(rad))
		DebugDrawLine(prevVector, currVec, 255, 255, 255)
		prevVec = currVec
	end
end

local SAFER_TP_DISTANCE = 1400
function Map_AdjustLocationForSaferPort(location, safeDist)
	local safeUnitVec = Vector_UnitDirectionalPointToPoint(
			location,
			TEAM_IS_RADIANT
					and logical_points[MAP_POINT_RADIANT_FOUNTAIN_CENTER]
					or logical_points[MAP_POINT_DIRE_FOUNTAIN_CENTER]
		)
	if TEAM_IS_RADIANT then
		safeUnitVec.x = safeUnitVec.x - 0.33
		safeUnitVec.y = safeUnitVec.y - 0.33
	else
		safeUnitVec.x = safeUnitVec.x + 0.33
		safeUnitVec.y = safeUnitVec.y + 0.33
	end
	return Vector_Addition(
			location,
			Vector_ScalarMultiply(
					safeUnitVec,
					(safeDist or SAFER_TP_DISTANCE) * 0.6818 -- 0.33 added reversed to back to unit vec
				)
		)
end

function Map_LimitLaneLocationToLowTierTeamTower(team, lane, location)
-- "Limit" is in terms of territorial safety for the team checking
	local lowestTierTower = GSI_GetLowestTierTeamLaneTower(team, lane) or Map_TeamSpawnerLoc(team, lane)
	if lowestTierTower then
		local lowestTierTowerLocation = lowestTierTower.x and lowestTierTower or lowestTierTower.lastSeen.location
		
		if lane == MAP_LOGICAL_MIDDLE_LANE then -- MID
			if TEAM == TEAM_DIRE then -- dire checks any mid tower
				local xLimit = lowestTierTowerLocation.x + LIMIT_TO_TOWER_FRIENDLY_OFFSET
				local yLimit = lowestTierTowerLocation.y + LIMIT_TO_TOWER_FRIENDLY_OFFSET
				if location.x < xLimit or location.y < yLimit then
					return Vector(xLimit, yLimit, lowestTierTowerLocation.z)
				end
			else -- radiant checks any mid tower
				local xLimit = lowestTierTowerLocation.x - LIMIT_TO_TOWER_FRIENDLY_OFFSET
				local yLimit = lowestTierTowerLocation.y - LIMIT_TO_TOWER_FRIENDLY_OFFSET
				if DEBUG then DebugDrawLine(location, lowestTierTowerLocation, 255, 255, 255) end
				if location.x > xLimit or location.y > yLimit then
					return Vector(xLimit, yLimit, lowestTierTowerLocation.z)
				end
			end
			return location
		end
		
		if team == TEAM_DIRE then -- Limit to TEAM_DIRE tower.
			if lane == MAP_LOGICAL_TOP_LANE then -- TOP
				if TEAM == TEAM_DIRE then -- dire checks dire top
					local xLimit = lowestTierTowerLocation.x + LIMIT_TO_TOWER_FRIENDLY_OFFSET
					return location.x < xLimit and Vector(xLimit, lowestTierTowerLocation.y, lowestTierTowerLocation.z) or location
				else -- radiant checks dire top
					local xLimit = lowestTierTowerLocation.x - LIMIT_TO_TOWER_FRIENDLY_OFFSET
					return location.x > xLimit and Vector(xLimit, lowestTierTowerLocation.y, lowestTierTowerLocation.z) or location
				end
			else -- BOT
				if TEAM == TEAM_DIRE then -- dire checks dire bot
					local yLimit = lowestTierTowerLocation.y + LIMIT_TO_TOWER_FRIENDLY_OFFSET
					return location.y < lowestTierTowerLocation.y and Vector(lowestTierTowerLocation.x, yLimit, lowestTierTowerLocation.z) or location
				else -- radiant checks dire bot
					local yLimit = lowestTierTowerLocation.y - LIMIT_TO_TOWER_FRIENDLY_OFFSET
					return location.y > lowestTierTowerLocation.y and Vector(lowestTierTowerLocation.x, yLimit, lowestTierTowerLocation.z) or location
				end
			end
		else -- Limit to TEAM_RADIANT tower.
			if lane == MAP_LOGICAL_TOP_LANE then -- TOP
				if TEAM == TEAM_DIRE then -- dire checks radiant top
					local yLimit = lowestTierTowerLocation.y + LIMIT_TO_TOWER_FRIENDLY_OFFSET
					return location.y < yLimit and Vector(lowestTierTowerLocation.x, yLimit, lowestTierTowerLocation.z) or location
				else -- radiant checks radiant top
					local yLimit = lowestTierTowerLocation.y - LIMIT_TO_TOWER_FRIENDLY_OFFSET
					return location.y > yLimit and Vector(lowestTierTowerLocation.x, yLimit, lowestTierTowerLocation.z) or location
				end
			else -- BOT
				if TEAM == TEAM_DIRE then -- dire checks radiant bot
					local xLimit = lowestTierTowerLocation.x + LIMIT_TO_TOWER_FRIENDLY_OFFSET
					return location.x < lowestTierTowerLocation.x and Vector(xLimit, lowestTierTowerLocation.y, lowestTierTowerLocation.z) or location
				else -- radiant checks radiant bot
					local xLimit = lowestTierTowerLocation.x - LIMIT_TO_TOWER_FRIENDLY_OFFSET
					return location.x > lowestTierTowerLocation.x and Vector(xLimit, lowestTierTowerLocation.y, lowestTierTowerLocation.z) or location
				end
			end
		end
	end
end

function Map_GetMapPointIndexForTower(team, tier, lane)
	if not lane and tier == 4 then return MAP_TEAM_TOWER + (team == TEAM_RADIANT and MAP_TEAM_TOWER_RADIANT_OFFSET or MAP_TEAM_TOWER_DIRE_OFFSET + MAP_TEAM_TOWER_T4_OFFSET) end
	return MAP_TEAM_TOWER + (team == TEAM_RADIANT and MAP_TEAM_TOWER_RADIANT_OFFSET or MAP_TEAM_TOWER_DIRE_OFFSET) + (lane - 1) * 3 + (tier - 1)
end

function Map_GetMapPointIndexFromTowerName(towerName)
	local mapNumerical = 0
	if string.find(towerName, "goodguys_tower", UNIT_SEARCH_STRING_START_INDEX) then
		mapNumerical = mapNumerical + MAP_TEAM_TOWER + MAP_TEAM_TOWER_RADIANT_OFFSET
		mapNumerical = mapNumerical + tonumber(string.sub(towerName, UNIT_SEARCH_STRING_START_INDEX+14, UNIT_SEARCH_STRING_START_INDEX+14)) - 1 -- 1 == 0 offset
	elseif string.find(towerName, "badguys_tower", UNIT_SEARCH_STRING_START_INDEX) then
		mapNumerical = mapNumerical + MAP_TEAM_TOWER + MAP_TEAM_TOWER_DIRE_OFFSET
		mapNumerical = mapNumerical + tonumber(string.sub(towerName, UNIT_SEARCH_STRING_START_INDEX+13, UNIT_SEARCH_STRING_START_INDEX+13)) -1
	end
	if mapNumerical < 1 then return nil end
	mapNumerical = mapNumerical + (
			string.find(towerName, "top", UNIT_SEARCH_STRING_START_INDEX+13) and 0 or
			string.find(towerName, "mid", UNIT_SEARCH_STRING_START_INDEX+13) and 3 or 
			string.find(towerName, "bot", UNIT_SEARCH_STRING_START_INDEX+13) and 6 	or 7
		)
	return mapNumerical
end

function Map_ReportTowerLocation(towerName, location)
	local mapNumerical = Map_GetMapPointIndexFromTowerName(towerName)
	if mapNumerical and mapNumerical > 0 then
		logical_points[mapNumerical] = location
	else
		print(string.format("/VUL-FT/ <WARN> Tower named '%s' did not formulate a valid numerical. (Is it format: 'npc_dota_[goodguys/badguys]_tower[1-4]~[_top/_mid/_bot][1-3]' ??)", type(towerName) == "string" and towerName or ""))
	end
end
