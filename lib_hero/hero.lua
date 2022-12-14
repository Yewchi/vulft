-- Stores per-player lane and role data and interfaces data for heroes to team, starts hero_behaviour init via hero_data (to ability and item modules)

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

require(GetScriptDirectory().."/lib_hero/hero_data")
require(GetScriptDirectory().."/lib_hero/hero_behaviour")
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

local function score_lanes(lanes) -- Primitive (gives an ordered scale, nils for unpreferred)
	local scoredLanes = {}
	for i=1,MAX_LANE_TYPES,1 do
		scoredLanes[lanes[i] or -0xFF] = scoring_table[i]
	end
	scoredLanes[-0xFF] = nil
	
	return scoredLanes
end

local function score_roles(roles)  -- Primitive (gives an ordered scale, nils for unpreferred)
	local scoredRoles = {}
	for i=1,MAX_ROLE_TYPES,1 do
		scoredRoles[roles[i] or -0xFF] = scoring_table[i]
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
		local thisRoleData, fInitializePlayerBehaviour = 
				HeroData_GetHeroRolePreferencesAndBehaviourInit(thisPlayer.shortName or GSI_GetHeroShortName(thisPlayer))
		fInitializePlayerBehaviour(thisPlayer)

		Hero_RegisterPreferences(	thisPlayer, 
									thisRoleData[HERO_PREFERENCE_I__LANE], 
									thisRoleData[HERO_PREFERENCE_I__ROLE], 
									thisRoleData[HERO_PREFERENCE_I__SOLO_POTENTIAL]
			)
	end
	generate_ordered_preference_score_for_roles()
end

function Hero_EnemyInitialize(gsiPlayer)
	local thisRoleData, fInitializePlayerBehaviour =
		HeroData_GetHeroRolePreferencesAndBehaviourInit(gsiPlayer.shortName)
	fInitializePlayerBehaviour(gsiPlayer)

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

	thisHeroPreferences[HERO_PREFERENCE_I__LANE] = score_lanes(lanes)
	thisHeroPreferences[HERO_PREFERENCE_I__ROLE] = score_roles(roles)
	thisHeroPreferences[HERO_PREFERENCE_I__SOLO_POTENTIAL] = soloPotentialMultiplier
	thisHeroPreferences.nonCoreRoleProclivity = roles[1] and roles[2] and roles[1] + roles[2]
			or roles[3] and 0 + roles[3]
			or roles[4] and 0 + roles[4]*2
			or roles[5] and	0 + roles[5]*2 or 0 -- numbers below 8 incidate this hero will never prefer supporting. If a team has only cores, give pos 4 / 5 to those with highest nonCoreProcliv'.
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
