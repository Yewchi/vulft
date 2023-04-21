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

-- Stores per-player lane and role data and interfaces data for heroes to team, starts hero_behavior init via hero_data (to ability and item modules)

---- lib_hero constants --
--
LANE_PREFERENCE_SAFE = 		1
LANE_PREFERENCE_MID = 		2
LANE_PREFERENCE_OFF =		3
LANE_PREFERENCE_JUNGLE = 	4
LANE_PREFERENCE_ROAM =		5

MAX_LANE_TYPES = 		5
MAX_ROLE_TYPES =		5
--

---- lib_hero table indices -- 
--
HERO_PREFERENCE_I__LANE = 						1
HERO_PREFERENCE_I__ROLE = 						2
HERO_PREFERENCE_I__SOLO_POTENTIAL = 			3

ROLE_SCORES_ORDERED_I__SCORE = 	1
ROLE_SCORES_ORDERED_I__PID = 	2
--

LANE_ROLES = TEAM_IS_RADIANT and {{4,3},{2},{5,1}} or {{5,1},{2},{4,3}}

local DEFAULT_COMMON_ROLE = 4

require(GetScriptDirectory().."/lib_hero/hero_data")
require(GetScriptDirectory().."/lib_hero/hero_behavior")
local hero_requires = {}

local player_preferences = {}
local team_preferences = {}
local enemy_preferences = {}
local ordered_hero_and_score_for_role = {} -- Structure: {[pos1] = {{highestScore, highestScoringplayerID}, {2ndHighestScore, 2ndHighestScoringplayerID}, ...}, ..., [pos5] = {...}}
local hero_search_funcs = {}

-- Scoring funcs
local scoring_table = {}
do
	local laneScore = 1.0
	local laneScoreScaling = 0.75 -- {1.0, 0.75, 0.5625, 0.421875, 0.316403}
	for i=1,MAX_LANE_TYPES,1 do
		scoring_table[i] = laneScore
		laneScore = laneScore * laneScoreScaling
	end
end

local function score_lanes(lanes, additionalImportance) -- Primitive (gives an ordered scale, nils for unpreferred)
	local scoredLanes = {}
	additionalImportance = additionalImportance or 0
	for i=1,MAX_LANE_TYPES,1 do
		scoredLanes[lanes[i] or -0xFF] = scoring_table[i] + additionalImportance
	end
	scoredLanes[-0xFF] = nil
	
	return scoredLanes
end

local function score_roles(roles, additionalImportance)  -- Primitive (gives an ordered scale, nils for unpreferred)
	local scoredRoles = {}
	additionalImportance = additionalImportance or 0
	for i=1,MAX_ROLE_TYPES,1 do
		scoredRoles[roles[i] or -0xFF] = scoring_table[i] + additionalImportance
	end
	scoredRoles[-0xFF] = nil
	
	return scoredRoles
end

local function sorted_insert_ohasfr(tScore, role) -- insert in-order into ordered_hero_and_score_for_role
	local thisRoleTbl = ordered_hero_and_score_for_role[role]

	if Util_TableEmpty(thisRoleTbl) then
		thisRoleTbl[1] = tScore
		return
	end

	for i=1,#thisRoleTbl,1 do
		if tScore[ROLE_SCORES_ORDERED_I__SCORE] >= thisRoleTbl[i][ROLE_SCORES_ORDERED_I__SCORE] then
			local tmp1 = thisRoleTbl[i]
			thisRoleTbl[i] = tScore
			i = i + 1
			local tmp2 = thisRoleTbl[i]
			thisRoleTbl[i] = tmp1
			while(tmp2) do
				i = i + 1
				tmp1 = tmp2
				tmp2 = thisRoleTbl[i]
				thisRoleTbl[i] = tmp1
			end
			break
		end
	end
end

local function generate_ordered_preference_score_for_roles()
	local tPlayers = GSI_GetTeamPlayers(GetTeam())	
	
	for r=1,MAX_ROLE_TYPES,1 do
		ordered_hero_and_score_for_role[r] = {}
	end

	for p=1,#tPlayers,1 do
		local thisplayerID = tPlayers[p].playerID
		local thisHeroPreferences = player_preferences[thisplayerID]
		
		local thisHeroRolePreferences = thisHeroPreferences[HERO_PREFERENCE_I__ROLE]
		for r=1,MAX_ROLE_TYPES,1 do
			if thisHeroRolePreferences[r] then
				sorted_insert_ohasfr({thisHeroRolePreferences[r], thisplayerID}, r)
			end
		end
	end
end
--

function Hero_Initialize() -- require witch_slayer.lua's present in game.
	local tPlayers = GSI_GetTeamPlayers(TEAM)
	for i=1,#tPlayers,1 do
		local thisPlayer = tPlayers[i]
		local thisRoleData, fInitializePlayerBehavior = 
				HeroData_GetHeroRolePreferencesAndBehaviorInit(thisPlayer.shortName or GSI_GetHeroShortName(thisPlayer))
		fInitializePlayerBehavior(thisPlayer)

		Hero_RegisterPreferences(	thisPlayer, 
									thisRoleData[HERO_PREFERENCE_I__LANE], 
									thisRoleData[HERO_PREFERENCE_I__ROLE], 
									thisRoleData[HERO_PREFERENCE_I__SOLO_POTENTIAL]
			)
		if thisPlayer.isBot and HeroData_IsHeroUntested(thisPlayer.shortName) then
			Captain_ConfigIndicateNonStandardSetting(
					CAPTAIN_CONFIG_NON_STANDARD.HERO_UNTESTED_ABILITY_USE,
					thisPlayer.shortName
				)
		end
	end
	generate_ordered_preference_score_for_roles()
	Item_Initialize()
end

function Hero_EnemyInitialize(gsiPlayer)
	local thisRoleData, fInitializePlayerBehavior =
		HeroData_GetHeroRolePreferencesAndBehaviorInit(gsiPlayer.shortName)
	fInitializePlayerBehavior(gsiPlayer)
end

function Hero_RegisterPreferences(thisPlayer, lanes, roles, soloPotentialMultiplier)
	local thisplayerID = thisPlayer.playerID
	local thisPlayerNumOnTeam = thisPlayer.nOnTeam
	local onTeam = thisPlayer.team == TEAM

	if not thisPlayer or not thisplayerID or not lanes or not roles or not soloPotentialMultiplier then
		print("/VUL-FT/ <WARN> hero: nil parameter(s) found when registering hero role prefs. Hero_RegisterPreferences"..Util_ParamString(thisPlayer, lanes, roles, soloPotentialMultiplier))
		return false
	end
	if not player_preferences[thisplayerID] then
		player_preferences[thisplayerID] = {}
		if onTeam then
			team_preferences[thisPlayerNumOnTeam] = {}
		else
			enemy_preferences[thisPlayerNumOnTeam] = {}
		end
	end
--[[DEBUG]]if VERBOSE then VEBUG_print("hero: registering '"..thisPlayer.shortName.."' role preferences.") end
	local thisHeroPreferences = 
			(onTeam and team_preferences[thisPlayerNumOnTeam] or enemy_preferences[thisPlayerNumOnTeam]) or {}
	player_preferences[thisplayerID] = thisHeroPreferences

	thisHeroPreferences[HERO_PREFERENCE_I__LANE] = score_lanes(lanes, not thisPlayer.isBot and 0.1 or 0)
	thisHeroPreferences[HERO_PREFERENCE_I__ROLE] = score_roles(roles, not thisPlayer.isBot and 0.1 or 0)
	thisHeroPreferences[HERO_PREFERENCE_I__SOLO_POTENTIAL] = soloPotentialMultiplier
	thisHeroPreferences.nonCoreRoleProclivity = roles[1] and roles[2] and roles[1] + roles[2]
			or roles[3] and 0 + roles[3]
			or roles[4] and 0 + roles[4]*2
			or roles[5] and	0 + roles[5]*2 or 0 -- numbers below 8 incidate this hero will never prefer supporting. If a team has only cores, give pos 4 / 5 to those with highest nonCoreProcliv'.
end

function Hero_HardSetRole(gsiPlayer, role)
	local roleTable = player_preferences[gsiPlayer.playerID][HERO_PREFERENCE_I__ROLE] or {}
	for i=1,MAX_LANE_TYPES do
		roleTable[i] = (i==role and 1 or -10)
	end
	player_preferences[gsiPlayer.playerID][HERO_PREFERENCE_I__ROLE] = roleTable
	generate_ordered_preference_score_for_roles()
end

function Hero_HardSetLane(gsiPlayer, lane)
	local laneTable = player_preferences[gsiPlayer.playerID][HERO_PREFERENCE_I__LANE] or {}
	for i=1,MAX_LANE_TYPES do
		laneTable[i] = (i==lane and 1 or -10)
	end
	player_preferences[gsiPlayer.playerID][HERO_PREFERENCE_I__LANE] = laneTable
	generate_ordered_preference_score_for_roles()
end

function Hero_GetCommonHeroRoleInLane(gsiPlayer, lane)
	-- Any loaded role tables should be sorted
	local roleTable = player_preferences[gsiPlayer.playerID][HERO_PREFERENCE_I__ROLE]
	Util_TablePrint(player_preferences)
	local choices = LANE_ROLES[lane]
	if not roleTable or not choices or not choices[1] then
		return false, DEFAULT_COMMON_ROLE, false
	end
	local avgRole = 0
	local rolesAvgDiv = 0
	for i=1,MAX_ROLE_TYPES do
		for k=1,#choices do
			if roleTable[i] == choices[k] then
				return choices[k], nil, true
			end
		end
		if roleTable[i] then
			rolesAvgDiv = rolesAvgDiv + 1
			avgRole = avgRole + roleTable[i] / rolesAvgDiv
		end
	end
	local closestChoice = choices[1]
	local closestDiff = 0xFFFF
	for k=1,#choices do
		local diff = math.abs(choices[k] - avgRole)
		if diff < closestDiff then
			closestDiff = diff
			closestChoice = choices[k]
		end
	end
	return false, closestChoice, true
end

function Hero_GetAllHeroAssignmentScores()
	return player_preferences
end

function Hero_GetTeamHeroAssignmentScores(team) -- not often requested
	return team == TEAM and team_preferences or enemy_preferences
end

function Hero_GetHeroAssignmentScores(playerId)
	local thisHeroPreferences = player_preferences[playerId]
	return {thisHeroPreferences[HERO_PREFERENCE_I__LANE],
			thisHeroPreferences[HERO_PREFERENCE_I__ROLE],
			thisHeroPreferences[HERO_PREFERENCE_I__SOLO_POTENTIAL],
			thisHeroPreferences.nonCoreRoleProclivity}
end

function Hero_GetOrderedHeroAndScoreForRole(roleNum)
	return ordered_hero_and_score_for_role[roleNum]
end
