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

	-- Tasks that are only worth it when allies collaborate.

-- Register a task and it's Utopia Xeta
-- Indicate my commitment to a task if we achieve a certain resultant score, and the cost to me for helping with this task.

local TEST = TEST

WP_POSTER_TYPES = {
	["BUILDING_DEFENCE"] = 1,
	["GANK_LANE"] = 2,
	["WARD_NEARBY"] = 3,
	["CHECK_ROSH"] = 4,
	["ROSH"] = 5,
	["CAPTURE_RUNE"] = 6,
	["GUARDED_SOLO_PUSH"] = 7, -- Essentially, bait
	["HIGH_RISK_JUNGLE_WARD"] = 8, -- Multi-player push into fog for warding and/or farming dark, high-risk jungle
	["BLANK"] = nil
}
local WP_POSTER_TYPES = WP_POSTER_TYPES

WP_COMMIT_TYPES = {
	["INTEREST_BOUNTY"] = 1,
	["INTEREST_SHARE"] = 2,
	["INTEREST_ASSIST"] = 3,
	["COMMIT_BOUNTY"] = 4,
	["COMMIT_SHARE"] = 5,
	["COMMIT_ASSIST"] = 6,
	["DEAD_OR_ENGAGED"] = 7,
	["INELIGABLE"] = 8 -- Probably a human
}
local OFFSET_INTEREST_TO_COMMIT = 3
local WILL_COMMIT_LIMIT = WP_COMMIT_TYPES.COMMIT_ASSIST

WP_AGENT_STATE_TYPES = {
	["ACTIVE"] = 1, -- ACTIVE state means I am currently running the blueprint of the task.
	["NEAR"] = 2, -- NEAR state means it will take me <10s to engage the task
	["FAR"] = 3, -- FAR state means it will take me >10s to engage the task
	["WAITING"] = 4, -- WAITING state means I would engage the task if enough heroes were present. This may be hiding fog before a gank.
	["REJECTED"] = 5, -- REJECTED state means I have determined it unwise to accept or logistically impossible.
	["BAILED"] = 6, -- BAILED state means the hero is dead, or wasn't needed / high scoring.
	["UNSET"] = nil -- --- -- allow alloc / default
}
local WP_AGENT_STATE_TYPES = WP_AGENT_STATE_TYPES

local POSTER_I__TYPE = 14
local POSTER_I__TASK_HANDLE = 1 -- the task handle of the creating task that has the run func
local POSTER_I__OBJECTIVE = 2 -- imaginary or real objective gsiUnit
local POSTER_I__LOCATION = 3 -- approx location of action
local POSTER_I__SCORE_FUNC = 4 -- f(gsiPlayer, objective) returning score of action from a player's current state -- scores are stored as timed data in gsiPlayer.time.data[tableRefForWp]
local POSTER_I__REWARD = 11
local POSTER_I__OBJECTIVE_POWER_LEVEL = 5 -- Danger is assessed in registering task, discouraging leeroy commit
local POSTER_I__STATUS_TYPES = 6 -- [pnot] the state of action for this poster for each player
local POSTER_I__COMMIT_TYPES = 7 -- [pnot] the state of commitment for this poster for each player
local POSTER_I__PRE_COMMIT_TYPES = 16
local POSTER_I__CHECK_INS = 8 -- Everyone signed off?
local POSTER_I__ALLOCATE_PERFORMED = 13
local POSTER_I__NEXT_TRY_ALLOC = 12
local POSTER_I__PREV_POSTER = 9 -- prev
local POSTER_I__NEXT_POSTER = 10 -- next 
local POSTER_I__LAST_ALLOCATE = 15
local POSTER_I__PREFERRED_POWER_FACTOR = 17

POSTER_I = {
	["TYPE"] = POSTER_I__TYPE,
	["TASK_HANDLE"] = POSTER_I__TASK_HANDLE,
	["OBJECTIVE"] = POSTER_I__OBJECTIVE,
	["LOCATION"] = POSTER_I__LOCATION,
	["SCORE_FUNC"] = POSTER_I__SCORE_FUNC,
	["REWARD"] = POSTER_I__REWARD,
	["OBJECTIVE_POWER_LEVEL"] = POSTER_I__OBJECTIVE_POWER_LEVEL,
	["STATUS_TYPES"] = POSTER_I__STATUS_TYPES,
	["COMMIT_TYPES"] = POSTER_I__COMMIT_TYPES,
	["PRE_COMMIT_TYPES"] = POSTER_I__PRE_COMMIT_TYPES,
	["CHECK_INS"] = POSTER_I__CHECK_INS,
	["ALLOCATE_PERFORMED"] = POSTER_I__ALLOCATE_PERFORMED,
	["NEXT_TRY_ALLOC"] = POSTER_I__NEXT_TRY_ALLOC,
	["PREV_POSTER"] = POSTER_I__PREV_POSTER,
	["NEXT_POSTER"] = POSTER_I__NEXT_POSTER,
	["LAST_ALLOCATE"] = POSTER_I__LAST_ALLOCATE
}

local wanted_poster_head = false -- linked list of all actionable posters, unordered, only for fast permanance
local t_player_task_wanted_poster = {} -- [pnot][taskHandle] = myActivePosterThisTask

local TEAM_NUMBER_OF_BOTS = TEAM_NUMBER_OF_BOTS
local TEAM_NUMBER_OF_PLAYERS = TEAM_NUMBER_OF_PLAYERS
local STUBBORNNESS_FACTOR = FACTOR_OF_PREVIOUS_SCORE_TO_WIN_CURRENT_TASK
local Task_SetTaskPriority = Task_SetTaskPriority
local Task_GetTaskScore = Task_GetTaskScore
local Task_GetCurrentTaskHandle = Task_GetCurrentTaskHandle
local TASK_PRIORITY_TOP = TASK_PRIORITY_TOP
local Analytics_GetPowerLevel = Analytics_GetPowerLevel
local PLAYERS_ALL = PLAYERS_ALL
local PNOT_TIMED_DATA = PNOT_TIMED_DATA
local max = math.max
local min = math.min

local team_players
local human_indicies = {}

do
	for i=1,TEAM_NUMBER_OF_PLAYERS do
		t_player_task_wanted_poster[i] = {}
	end
end

local recyclable_posters = {}
local function burn_poster(poster)
	if not poster[POSTER_I__PREV_POSTER] then
		wanted_poster_head = poster[POSTER_I__NEXT_POSTER]
		if wanted_poster_head then
			wanted_poster_head[POSTER_I__PREV_POSTER] = false
		end
	else
		if poster[POSTER_I__NEXT_POSTER] then
			poster[POSTER_I__NEXT_POSTER][POSTER_I__PREV_POSTER] = poster[POSTER_I__PREV_POSTER]
		end
		poster[POSTER_I__PREV_POSTER][POSTER_I__NEXT_POSTER] = poster[POSTER_I__NEXT_POSTER]
	end
	poster[POSTER_I__PREV_POSTER] = false
	poster[POSTER_I__NEXT_POSTER] = false
	poster[POSTER_I__TYPE] = nil
	table.insert(recyclable_posters, poster)
end
local function new_blank_poster()
	local newPoster
	if recyclable_posters[1] then
		newPoster = table.remove(recyclable_posters)
		newPoster[POSTER_I__ALLOCATE_PERFORMED] = false
		newPoster[POSTER_I__LAST_ALLOCATE] = 0
	else
		newPoster = {}
		newPoster[POSTER_I__STATUS_TYPES] = {}
		newPoster[POSTER_I__COMMIT_TYPES] = {}
		newPoster[POSTER_I__PRE_COMMIT_TYPES] = {}
	end
	newPoster[POSTER_I__CHECK_INS] = 0
	local statusTypes = newPoster[POSTER_I__STATUS_TYPES]
	local commitTypes = newPoster[POSTER_I__COMMIT_TYPES]
	local preCommitTypes = newPoster[POSTER_I__PRE_COMMIT_TYPES]
	local checkIns = 0
	for i=1,TEAM_NUMBER_OF_PLAYERS do
		statusTypes[i] = nil
		if not team_players[i].hUnit:IsBot() then
			commitTypes[i] = WP_COMMIT_TYPES.INELIGABLE
			preCommitTypes[i] = WP_COMMIT_TYPES.INELIGABLE
			checkIns = checkIns + 1
		else
			commitTypes[i] = nil
			preCommitTypes[i] = nil
		end
	end
	newPoster[POSTER_I__CHECK_INS] = checkIns
	return newPoster
end

local function set_task_priority_for_poster_checks(taskHandle)
	Task_SetTaskPriority(taskHandle, PLAYERS_ALL, TASK_PRIORITY_TOP)
end

local function set_next_try_alloc_allowed(wpHandle)
	wpHandle[POSTER_I__NEXT_TRY_ALLOC] = GameTime() + RandomFloat(1.0, 2.5) -- Don't do it all at once, be more playerlike
end

function WP_Initialize()
	team_players = GSI_GetTeamPlayers(TEAM)
	for i=1,TEAM_NUMBER_OF_PLAYERS do
		if not team_players[i].hUnit:IsBot() then
			table.insert(human_indicies, i) -- TODO why did I ever do this
		end
	end
	WP_Initialize = nil
end

function WP_BurnPoster(wpHandle)
	
	
	
	
	local taskHandle = wpHandle[POSTER_I__TASK_HANDLE]
	for i=1,TEAM_NUMBER_OF_PLAYERS do
		if t_player_task_wanted_poster[i][taskHandle] == wpHandle then -- don't remove posters for other runes etc.
			t_player_task_wanted_poster[i][taskHandle] = false
		end
	end
	burn_poster(wpHandle)
end

function WP_Register(posterType, taskHandle, objective, location, scoreFunc, reward, objectivePowerLevel, preferredPowerFactor)
--	if t_wanted_posters_index[objective] then
--	end
	local newPoster = new_blank_poster()
	newPoster[POSTER_I__TYPE] = posterType
	newPoster[POSTER_I__TASK_HANDLE] = taskHandle
	newPoster[POSTER_I__OBJECTIVE] = objective
	newPoster[POSTER_I__LOCATION] = location
	newPoster[POSTER_I__SCORE_FUNC] = scoreFunc
	newPoster[POSTER_I__REWARD] = reward
	newPoster[POSTER_I__OBJECTIVE_POWER_LEVEL] = objectivePowerLevel
	newPoster[POSTER_I__NEXT_TRY_ALLOC] = GameTime() - 0.1
	newPoster[POSTER_I__PREFERRED_POWER_FACTOR] = preferredPowerFactor or 1.0

	if not wanted_poster_head then
		wanted_poster_head = newPoster
	else
		newPoster[POSTER_I__NEXT_POSTER] = wanted_poster_head 
		wanted_poster_head[POSTER_I__PREV_POSTER] = newPoster
		wanted_poster_head = newPoster
	end

	set_task_priority_for_poster_checks(taskHandle)

	return newPoster
end

function WP_CommitIsInterest(gsiPlayer, wpHandle)
	local commitType = wpHandle[POSTER_I__COMMIT_TYPES][gsiPlayer.nOnTeam]
			or wpHandle[POSTER_I__PRE_COMMIT_TYPES][gsiPlayer.nOnTeam]
	if commitType and commitType >= WP_COMMIT_TYPES.INTEREST_BOUNTY
			and commitType <= WP_COMMIT_TYPES.INTEREST_ASSIST then
		return true
	end
	return false
end

function WP_CommitIsCommit(gsiPlayer, wpHandle)
	local commitType = wpHandle[POSTER_I__COMMIT_TYPES][gsiPlayer.nOnTeam]
	if commitType and commitType >= WP_COMMIT_TYPES.COMMIT_BOUNTY
			and commitType <= WP_COMMIT_TYPES.COMMIT_ASSIST then
		return true
	end
	return false
end

function WP_ScorePoster(gsiPlayer, wpHandle, forTaskConsideration)
	if not gsiPlayer.hUnit:IsAlive() then
		return XETA_SCORE_DO_NOT_RUN
	end
	local score = PNOT_TIMED_DATA[gsiPlayer.nOnTeam][wpHandle]
	local currTaskHandle = Task_GetCurrentTaskHandle(gsiPlayer)
	--print("Scoring poster:", gsiPlayer.shortName, wpHandle, currTaskHandle)
	scoreRequired = currTaskHandle == wpHandle[POSTER_I__TASK_HANDLE] -- TODO Doesn't this mean a second poster will always win
			and XETA_SCORE_DO_NOT_RUN or Task_GetTaskScore(gsiPlayer, currTaskHandle)
	if not score then
		score = wpHandle[POSTER_I__SCORE_FUNC](gsiPlayer, wpHandle[POSTER_I__OBJECTIVE], forTaskConsideration, wpHandle)
		if not forTaskComparison then
			-- i.e. don't poison poster comparison scores with task-wise comparison scores
			PNOT_TIMED_DATA[gsiPlayer.nOnTeam][wpHandle] = score > (scoreRequired and score or XETA_SCORE_DO_NOT_RUN)
		end
	end
	return score
end

function WP_PlayerTryStart(gsiPlayer, wpHandle, blueprintIsCurrent, onlyAllActive)
	local thisPlayerCurrTask = Task_GetCurrentTaskHandle(gsiPlayer)
	local thisPlayerTaskObjective = Task_GetCurrentTaskObjective(gsiPlayer)
	local statusTypes = wpHandle[POSTER_I__STATUS_TYPES]

	local etaToTask = Blueprint_GetTaskToObjTimeRemaining(
			gsiPlayer,
			thisPlayerCurrTask,
			thisPlayerTaskObjective,
			wpHandle[POSTER_I__OBJECTIVE]
		)
	statusTypes[gsiPlayer.nOnTeam] = etaToTask > 6
			and WP_AGENT_STATE_TYPES.FAR
			or WP_AGENT_STATE_TYPES.NEAR
	if blueprintIsCurrent then
		if onlyAllActive then
			local setActive = true
			for i=1,TEAM_NUMBER_OF_PLAYERS do
				if statusTypes[i] == WP_AGENT_STATE_TYPES.FAR then
					setActive = false
					break;
				end
			end
			if setActive then
				for i=1,TEAM_NUMBER_OF_PLAYERS do
					if statusTypes[i] == WP_AGENT_STATE_TYPES.NEAR then
						statusTypes[i] = WP_AGENT_STATE_TYPES.ACTIVE
					end
				end
				return true -- all ready as requested
			end
		elseif statusTypes[gsiPlayer.nOnTeam] == WP_AGENT_STATE_TYPES.NEAR then
			statusTypes[gsiPlayer.nOnTeam] = WP_AGENT_STATE_TYPES.ACTIVE
			return true -- I'm ready as requested
		end
	end
	return false -- I'm not ready
end

function WP_InformDead(gsiPlayer)
	local thisPoster = wanted_poster_head
	local pnot = gsiPlayer.nOnTeam
	local commitType = WP_COMMIT_TYPES.DEAD_OR_ENGAGED
	local debugKill = 1 while(thisPoster) do
		local thisCommitTypes = thisPoster[POSTER_I__COMMIT_TYPES]
		local thisPreCommitTypes = thisPoster[POSTER_I__PRE_COMMIT_TYPES]

		if WP_CommitIsCommit(gsiPlayer, thisPoster) then -- needs old data
			thisCommitTypes[pnot] = commitType -- see above and below
			thisPreCommitTypes[pnot] = commitType
			t_player_task_wanted_poster[pnot][thisPoster[POSTER_I__TASK_HANDLE]] = false

			if thisPoster[POSTER_I__CHECK_INS] == TEAM_NUMBER_OF_PLAYERS then
				WP_AllocateToHighestScores(thisPoster) -- triggered by old data, needs updated data, not to be overwritten
				thisPoster[POSTER_I__LAST_ALLOCATE] = GameTime()
			end
		else
			thisCommitTypes[pnot] = commitType -- see above and if
			thisPreCommitTypes[pnot] = commitType
		end
		thisPoster = thisPoster[POSTER_I__NEXT_POSTER]
		debugKill = debugKill + 1
		if debugKill > 100 then
			ERROR_print(true, not DEBUG, "INFORM DEAD WAS CURSED BY CLEANUP CODE")
			break;
		end
	end
end

function WP_InformBail(gsiPlayer, wpHandle)
	local taskHandle = wpHandle[POSTER_I__TASK_HANDLE]
	local pnot = gsiPlayer.nOnTeam
	if t_player_task_wanted_poster[pnot][taskHandle] == wpHandle then
		t_player_task_wanted_poster[pnot][taskHandle] = false
	end

	wpHandle[POSTER_I__STATUS_TYPES][pnot] = WP_AGENT_STATE_TYPES.BAILED
	wpHandle[POSTER_I__COMMIT_TYPES][pnot] = WP_COMMIT_TYPES.DEAD_OR_ENGAGED
	WP_AllowReinform(wpHandle)
	if DEBUG then
		DEBUG_print(string.format("[wp] %s bails from '%s'",
				gsiPlayer.shortName, wpHandle[POSTER_I__OBJECTIVE].name))
	end
end

-- TODO Unused, untested. Scary, obfuscated complexity.
function WP_InformAvailable(gsiPlayer)
	local thisWp = wanted_poster_head
	local pnot = gsiPlayer.nOnTeam

	local DEBUG_FAIL = 0
	while(thisWp) do
		DEBUG_FAIL = DEBUG_FAIL + 1
		if DEBUG_FAIL > 100 then ERROR_print(false, false, "[wp] INFORM AVAIL FOUND WANTED POSTER LINKED LIST INFINITE LOOP. Dump:\n%s", Util_PrintableTable(thisWp)) DEBUG_KILLSWITCH = true break; end
		if thisWp[POSTER_I__COMMIT_TYPES][pnot] >= WP_COMMIT_TYPES.DEAD_OR_ENGAGED then
			thisWp[POSTER_I__CHECK_INS] = thisWp[POSTER_I__CHECK_INS] - 1
			thisWp[POSTER_I__COMMIT_TYPES][pnot] = nil
			thisWp[POSTER_I__PRE_COMMIT_TYPES][pnot] = nil
		end
	end
	if DEBUG then print("/VUL-FT/", gsiPlayer.shortName, "reset poster scoring") end
end

local player_score_order = {} -- {playerId, wpScoreTaskScore}
-- Used to make the next-highest-index ordered.
-- So that we can process that player for culmulative objectivePowerLevel.
-- ... then iterate over the players that are left below that for next-highest in the loop.
local function switch_index_check_power(higherI, lowerI, currObjectivePowerLevel)
	local tmp = player_score_order[lowerI]
	player_score_order[lowerI] = player_score_order[higherI]
	player_score_order[higherI] = tmp
	currObjectivePowerLevel = currObjectivePowerLevel + Analytics_GetPowerLevel(team_players[player_score_order[higherI][1]])
	return currObjectivePowerLevel
end
do for i=1,TEAM_NUMBER_OF_PLAYERS do player_score_order[i] = {i, XETA_SCORE_DO_NOT_RUN, 1} end end
function WP_AllocateToHighestScores(wpHandle, ignorePower)
	-- the way this function is utilized to determine best-fit wanted poster allocation
	-- - ... (across many wanted poster allocations, some bots being split between disparate WPs) ...
	-- - is kinda like building a fence by randomly throwing metal spikes high in the air and letting
	-- - them crash into the ground, then upon working out the spikes can't be circumvented, saying
	-- - 'we have fenced the yard'.
	local PNOT_TIMED_DATA = PNOT_TIMED_DATA
	local thisPlayer
	local highestScore = XETA_SCORE_DO_NOT_RUN
	local highestIndex = 0
	local currentPlayerTaskScores = {}
	local player_score_order = player_score_order
	local adjustedScore
	local wpTaskHandle = wpHandle[POSTER_I__TASK_HANDLE]
	local max = max
	local min = min
	-- O(n), but calls WP_ScorePoster
	for i=1,TEAM_NUMBER_OF_PLAYERS do
		thisPlayer = team_players[i]
		player_score_order[i][1] = i -- playerID, could be in any order from most recent AllocateToHighestScores()
		local currentPlayerTaskWp = t_player_task_wanted_poster[i][wpTaskHandle]
		local currentPlayerTaskWpScore = currentPlayerTaskWp
				and WP_ScorePoster(thisPlayer, currentPlayerTaskWp) or XETA_SCORE_DO_NOT_RUN
		local bailingOnOthersGreedFactor = 1
		local bailingOnOthersScoreAdded = 0
		if currentPlayerTaskWp and currentPlayerTaskWp ~= wpHandle then
			-- resist bailing on (high scoring * greed) factor allies
			local myGreedRating = thisPlayer.vibe.greedRating
			for iPnot=1,TEAM_NUMBER_OF_PLAYERS do
				if iPnot ~= thisPlayer.nOnTeam
						and WP_CommitIsCommit(team_players[iPnot], currentPlayerTaskWp) then
					bailingOnOthersGreedFactor = bailingOnOthersGreedFactor
							+ max(0, team_players[iPnot].vibe.greedRating - myGreedRating)/4
					local allyTimedScore = PNOT_TIMED_DATA[iPnot][currentPlayerTaskWp]
					if allyTimedScore
							and (currentPlayerTaskWpScore+bailingOnOthersScoreAdded
									< allyTimedScore
								) then
						bailingOnOthersScoreAdded = bailingOnOthersScoreAdded
								+ (allyTimedScore - currentPlayerTaskWpScore)/3
					end
				end
			end
		end
		if DEBUG then
			INFO_print(string.format("[wp] %s compares bailing %s,%.1f->%s,%.1f with factor, added: %.2f, %.2f",
						thisPlayer.shortName,
						currentPlayerTaskWp and currentPlayerTaskWp[POSTER_I__OBJECTIVE].name or '#',
						PNOT_TIMED_DATA[thisPlayer.nOnTeam][currentPlayerTaskWp] or -0,
						wpHandle[POSTER_I__OBJECTIVE].name,
						WP_ScorePoster(thisPlayer, wpHandle),
						bailingOnOthersGreedFactor,
						bailingOnOthersScoreAdded
					)
				)
		end
		currentPlayerTaskScores[i] = max(
				currentPlayerTaskWpScore, 
				Task_GetCurrentTaskScore(thisPlayer)
			)
		local thisPlayerStatusType = wpHandle[POSTER_I__STATUS_TYPES][thisPlayer.nOnTeam]
		if thisPlayer.hUnit:IsBot() and wpHandle[POSTER_I__COMMIT_TYPES] ~= WP_COMMIT_TYPES.DEAD_OR_ENGAGED then
			-- Find / get score
			local score = PNOT_TIMED_DATA[i][wpHandle]
			if not score then
				score = WP_ScorePoster(thisPlayer, wpHandle)
			end
			PNOT_TIMED_DATA[i][wpHandle] = score

			player_score_order[i][2] = score
			-- adjustedScore is informed by which bots get the most out of this task swtich--WP or blueprint wise
			if VERBOSE then print("/VUL-FT/", wpHandle ~= currentPlayerTaskWp, score, "<", (
							(currentPlayerTaskWpScore + bailingOnOthersScoreAdded) * bailingOnOthersGreedFactor
						) * STUBBORNNESS_FACTOR, "if not DNR:", score*max(0, min(1, score/max(1, currentPlayerTaskScores[i]))) ) end

			adjustedScore = wpHandle ~= currentPlayerTaskWp
					and score < (
							(currentPlayerTaskWpScore + bailingOnOthersScoreAdded) * bailingOnOthersGreedFactor
						) * STUBBORNNESS_FACTOR
					and XETA_SCORE_DO_NOT_RUN
					or score*max(0, min(1, score/min(1, currentPlayerTaskScores[i])))
			player_score_order[i][3] = adjustedScore
			--print(thisPlayer.shortName, "currentWpViewScore and adjusted thisAllocWp:", currentPlayerTaskScores[i], adjustedScore)
			if adjustedScore > highestScore then
				highestScore = adjustedScore
				highestIndex = i
			end
		else
			player_score_order[i][2] = XETA_SCORE_DO_NOT_RUN
		end
		--print("Score", wpHandle[POSTER_I__OBJECTIVE].name, thisPlayer.shortName, player_score_order[i][2], player_score_order[i][3])
	end
	if highestScore == XETA_SCORE_DO_NOT_RUN then
		if TEST then
			INFO_print(string.format("[wp] DNR for all bots on '%s'", wpHandle[POSTER_I__OBJECTIVE].name))
		end
		return false -- Nobody scored a commit
	end
	local currObjectivePowerLevel = 0
	local currHighIndex = 1 -- where to move the next-highest player_score_order[x] to
	local currHighUnorderedIndex = highestIndex -- where the next-highest player_score_order[x] is before ordering it.
	local objectivePowerLevel = wpHandle[POSTER_I__OBJECTIVE_POWER_LEVEL]
	local commitTypes = wpHandle[POSTER_I__COMMIT_TYPES]
	local preCommitTypes = wpHandle[POSTER_I__PRE_COMMIT_TYPES]
	local statusTypes = wpHandle[POSTER_I__STATUS_TYPES]
	local posterTotalScore = 0
	local preferredPowerFactor = wpHandle[POSTER_I__PREFERRED_POWER_FACTOR]
	if VERBOSE then print("/VUL-FT/ [wp] Preferred power factor is", preferredPowerFactor, TOTAL_TOWERS_TEAM, NUM_TOWERS_UP_TEAM, TOTAL_BARRACKS_TEAM, NUM_BARRACKS_UP_TEAM) end
	local currTaskTotalScore = 0 -- Compare scores, to confirm it's actually worth it. TODO Bugged for players with lower-score as ordered, but very low scoring task currently. Implies ordered by highest change in score is more accurate.
	local returnAllocated = false
	-- technically O(n logn) with common early end, but calls no intensive functions, faster than above with intensive task scoring
	while(true) do
		if player_score_order[currHighUnorderedIndex][2] > XETA_SCORE_DO_NOT_RUN then
			currObjectivePowerLevel = currObjectivePowerLevel +
					switch_index_check_power(
							currHighIndex,
							currHighUnorderedIndex,
							currObjectivePowerLevel
						)
			thisPlayer = team_players[player_score_order[currHighIndex][1]]
			posterTotalScore = posterTotalScore + player_score_order[currHighIndex][2]
			currTaskTotalScore = currTaskTotalScore + Task_GetCurrentTaskScore(thisPlayer)
		end
		if TEST then
			INFO_print(string.format("[wp] checking for power %.2f score %.2f satisfaction. %.2f, %.2f. Comparison score: %.2f",
							ignorePower and -0 or objectivePowerLevel, currTaskTotalScore,
							currObjectivePowerLevel, posterTotalScore,
							player_score_order[currHighIndex][3]
						)
				)
		end
		if posterTotalScore > currTaskTotalScore
				and (ignorePower or currObjectivePowerLevel > objectivePowerLevel
					* (currHighIndex < TEAM_NUMBER_OF_PLAYERS and preferredPowerFactor
							or 1
						)
				) then
			if VERBOSE then print("/VUL-FT/ objectivePowerLevel success on", wpHandle[POSTER_I__OBJECTIVE].shortName or wpHandle[POSTER_I__OBJECTIVE].name, currObjectivePowerLevel, ">", objectivePowerLevel) end
			-- Poster requirements succeeded, and increase our total score
			local taskHandle = wpHandle[POSTER_I__TASK_HANDLE]
			for i=1,currHighIndex do
				thisPlayer = team_players[player_score_order[i][1]]
				if DEBUG then
					INFO_print(string.format("[wp] assigned to poster %s->'%s'",
							thisPlayer.shortName,
							wpHandle[POSTER_I__OBJECTIVE].name)
						)
				end
				local thisPnot = thisPlayer.nOnTeam
				local currentTaskHandlePoster = t_player_task_wanted_poster[thisPnot][taskHandle]
				if WP_CommitIsInterest(thisPlayer, wpHandle) then
					commitTypes[thisPnot] = preCommitTypes[thisPnot] + OFFSET_INTEREST_TO_COMMIT
					statusTypes[thisPnot] = WP_AGENT_STATE_TYPES.WAITING -- Tentative
				end
				--print(thisPlayer.shortName, "elected for", wpHandle[POSTER_I__OBJECTIVE].name, "commit is", wpHandle[POSTER_I__COMMIT_TYPES][thisPnot])
				if currentTaskHandlePoster ~= false and currentTaskHandlePoster ~= nil
						and currentTaskHandlePoster ~= wpHandle then
					if DEBUG then
						INFO_print( string.format("[wp] %s is bailing from Alloc..() on '%s'",
									thisPlayer.shortName,
									currentTaskHandlePoster[POSTER_I__OBJECTIVE].name
										or currentTaskHandlePoster[POSTER_I__OBJECTIVE].shortName
								)
							)
					end
					WP_InformBail(thisPlayer, currentTaskHandlePoster)
				end
				t_player_task_wanted_poster[thisPlayer.nOnTeam][taskHandle] = wpHandle
			end
			for i=currHighIndex+1,TEAM_NUMBER_OF_PLAYERS do -- ensure other players are clean
				thisPlayer = team_players[player_score_order[i][1]]
				local thisPnot = thisPlayer.nOnTeam
				if WP_CommitIsCommit(thisPlayer, wpHandle) then
					commitTypes[thisPnot] = preCommitTypes[thisPnot] -- reduce to interest
					statusTypes[thisPnot] =
							WP_AGENT_STATE_TYPES.UNSET
				--			statusTypes[thisPnot] == WP_AGENT_STATE_TYPES.BAILED
				--			and statusTypes[thisPnot] or WP_AGENT_STATE_TYPES.UNSET
					if t_player_task_wanted_poster[thisPnot][taskHandle] == wpHandle then
						t_player_task_wanted_poster[thisPnot][taskHandle] = false
					end
				end
			end
			set_next_try_alloc_allowed(wpHandle)
			returnAllocated = true
			break;
			-- TODO How will waiting be implemented if at all? Won't it just be active states with a run state that include waiting behavior, should there be a generic waiting run function that includes doing menial tasks like farming nearby jungle packs and checking for good closeby wards.
			-- FAR state bots in a task could allow full task override, NEAR state bots could indicate everyone needs to make their way that was already NEAR, ACTIVE could mean the poster-and-task blueprint.run is active and we are currently doing the task, but that means that picking up runes is ACTIVE for one frame, which is odd and seems unneccesary. ACTIVE task for picking up runes could include things like drinking from bottle however, given, in almost every case the bot should've drank it already. .'. NEAR status type should engage the run function. Does the run function include moving towards the poster-and-task area, or should a WP override engage that include the bot's behavior as they make their way. How do you know that immediate and switched behavior doesn't imply that a bot is removing themself from the task. Oracle should still heal himself as he heads towards a task area, but he is not cancleing the wanted poster's engagement. Task types can indicate that a bot is out of a wanted poster, but is fight_low_health_contribution not a fear task, in which case the worst of our tasks is not disengatement. If AM happens upon a late-game triple ancient stack, should he not immediately engage the task and then continue with a high scoring wanted poster. Can this behavior be assesed for time taken and rescored to inform the wait-around-time, reducing scores. And potentially leading to cancelations, rather than always leading to cancelation. FarmJungle_TTK already exists and can be used but this means that all tasks need to be objectified further for time-taken to complete tasks. Something that players do in their heads anyways, so why not extend the capability-- but greatly increasing complexity. Essentially icing on the cake but what is reasonable for abstraction or removal? -- Or rather these things do not need to be calculated at any time scoring but an additional time-taken function must be provied in tasks in order to get the data for other functions and wanted_poster, stored in player time data. It is the right answer but I needs a day of very boring work.
		end
		currHighIndex = currHighIndex+1
		if currHighIndex > TEAM_NUMBER_OF_PLAYERS then
			
			set_next_try_alloc_allowed(wpHandle)
			break;
		end
		highestScore = XETA_SCORE_DO_NOT_RUN
		for i=currHighIndex,TEAM_NUMBER_OF_PLAYERS do
			--print("comparing", player_score_order[i][3], highestScore)
			if player_score_order[i][3] > highestScore then
				highestScore = player_score_order[i][3]
				currHighUnorderedIndex = i
			end
		end
		if highestScore == XETA_SCORE_DO_NOT_RUN then set_next_try_alloc_allowed(wpHandle) break; end
		highestScore = XETA_SCORE_DO_NOT_RUN
	end
end
-- ^^ Score required cannot be checked here unless it is stored in a table. If a poster is old and inform interest is not ran, then we hit a time-data refresh switch to all-scores allowed, allowing bots to think a task is worth undertaking due to power level when other bots will see it as greatly losing score... AM gives power level to engage SOLO_PUSH_GUARDED, but walks off to farm his next jungle camp instead of commiting to the bait, other involved bots that saw it as high scoring sit in fog next to lane doing nothing with nobody pushing.
-- score improvement as an average of bots involved previous behavior -- complexity and stubborness issues with being stuck on a WP when splitting to farm multiple jungle camps was the highest total score for all bots.


function WP_AllowReinform(wpHandle)
	if DEBUG then
		DEBUG_print(string.format("[WP] %s allowing reform %s",
				GetBot():GetUnitName(),
				Util_Printable(wpHandle[POSTER_I__OBJECTIVE]))
			)
	end
	for iPnot=1,TEAM_NUMBER_OF_PLAYERS do
		wpHandle[POSTER_I__PRE_COMMIT_TYPES][iPnot] = nil
	end
	wpHandle[POSTER_I__CHECK_INS] = 0
	wpHandle[POSTER_I__ALLOCATE_PERFORMED] = false
end

-- Checks if next player on team is alive repeatedly so we can know all players have checked in
-- Returns true if no more inform interests are needed.
function WP_InformInterest(gsiPlayer, wpHandle, commitType, scoreAdjustment, force, ignorePower)
	if not force and wpHandle[POSTER_I__NEXT_TRY_ALLOC] > GameTime() then
		return true
	end
	local allowTimedDataTimeOutRealloc = force or false
	local pnot = gsiPlayer.nOnTeam
	local score = PNOT_TIMED_DATA[pnot][wpHandle] -- This is not "redundantly set because AllocateToHighestScores does it as well", due to needing all players to [check in / cover for next-id deads]. Players may go out of timed data due to late sets / priorities, or frame-to-frame timed data clears. This shouldn't be a problem because most of the time WPs will set priority 1 for the owning&moderating task on the frame they're Registered.
	if not score then
		score = WP_ScorePoster(gsiPlayer, wpHandle)
		PNOT_TIMED_DATA[pnot][wpHandle] = score
		if DEBUG then print("DEL - ALLOC ALLOWED OVERRIDE -- Possible?:", not wpHandle[POSTER_I__ALLOCATE_PERFORMED] ) end
		allowTimedDataTimeOutRealloc = true
	end
	local currTaskHandle = Task_GetCurrentTaskHandle(gsiPlayer)
	scoreRequired = currTaskHandle == wpHandle[POSTER_I__TASK_HANDLE]
			and XETA_SCORE_DO_NOT_RUN or Task_GetTaskScore(gsiPlayer, currTaskHandle)
	local commitTypes = wpHandle[POSTER_I__COMMIT_TYPES]
	local preCommitTypes = wpHandle[POSTER_I__PRE_COMMIT_TYPES]
	local newCheckIns = preCommitTypes[pnot] and 0 or 1 -- Check in if this is first InformInterest for this bot
	-- TODO Risk of bug causing never hit check-in requirement
	--if score > scoreRequired*0.9 then 
		preCommitTypes[pnot] = commitType -- Set how we would commit
		if not commitTypes[pnot] or commitTypes[pnot] > WP_COMMIT_TYPES.COMMIT_ASSIST then -- nill check for next if
			-- switches any non-commit commit type to this interest commit type
			commitTypes[pnot] = commitType
		elseif commitTypes[pnot] >= WP_COMMIT_TYPES.COMMIT_BOUNTY then
			commitTypes[pnot] = commitType + OFFSET_INTEREST_TO_COMMIT
		end
	--end
	local rotatePnot = pnot%TEAM_NUMBER_OF_PLAYERS + 1
	local testNext = team_players[rotatePnot]
	if not wpHandle[POSTER_I__ALLOCATE_PERFORMED] then
		-- Rotate through dead bots that need someone to cover for their check in, break if we find alive bot
		while(testNext) do -- Usually 1-step
			if not testNext.hUnit:IsBot() then
				-- continue;
			elseif not testNext.hUnit:IsAlive() then
				if preCommitTypes[rotatePnot] ~= WP_COMMIT_TYPES.DEAD_OR_ENGAGED then
					preCommitTypes[rotatePnot] = WP_COMMIT_TYPES.DEAD_OR_ENGAGED
					newCheckIns = newCheckIns + 1
				end
				-- continue;
			else -- next player is a bot and alive
				break;
			end
			rotatePnot = rotatePnot%TEAM_NUMBER_OF_PLAYERS + 1
			if rotatePnot == pnot then break; end
			testNext = team_players[rotatePnot]
		end
		wpHandle[POSTER_I__CHECK_INS] = wpHandle[POSTER_I__CHECK_INS] + newCheckIns
		if wpHandle[POSTER_I__CHECK_INS] == TEAM_NUMBER_OF_PLAYERS then
			local commitTypes = wpHandle[POSTER_I__COMMIT_TYPES]
			if DEBUG then
				INFO_print( string.format("[wp] Performing allocate on '%s'",
							wpHandle[POSTER_I__OBJECTIVE].name or wpHandle[POSTER_I__OBJECTIVE].shortName
						)
					)
			end
			WP_AllocateToHighestScores(wpHandle, ignorePower)
			wpHandle[POSTER_I__ALLOCATE_PERFORMED] = true
			wpHandle[POSTER_I__LAST_ALLOCATE] = GameTime()
			return true
		end
	elseif force or allowTimedDataTimeOutRealloc and score > Task_GetCurrentTaskScore(gsiPlayer) then
		-- AllocateToHighestScores if we finished player check-ins on this run of the function, or a player had their timedData reset and re-scored but for some reason the moderating task allowed an Inform (circumstances changed, the allocations look abnormal. e.g. to collect a regen rune on 10% HP while rosh is starting).
		if DEBUG then
			INFO_print( string.format("[wp] Performing allocate on '%s'",
						wpHandle[POSTER_I__OBJECTIVE].name or wpHandle[POSTER_I__OBJECTIVE].shortName
					)
				)
		end
		WP_AllocateToHighestScores(wpHandle, ignorePower)
		wpHandle[POSTER_I__LAST_ALLOCATE] = GameTime()
		return true
	end
	if DEBUG then print("/VUL-FT/ [wp] not rescoring", wpHandle[POSTER_I__OBJECTIVE].name or wpHandle[POSTER_I__OBJECTIVE].shortName,
			"because", wpHandle[POSTER_I__CHECK_INS], wpHandle[POSTER_I__ALLOCATE_PERFORMED],
			force, allowTimedDataTimeOutRealloc, score, ">", Task_GetCurrentTaskScore(gsiPlayer)) end
	return false
end

function WP_GetPlayerTaskPoster(gsiPlayer, taskHandle)
	return t_player_task_wanted_poster[gsiPlayer.nOnTeam][taskHandle]
end

if DEBUG then
	function WP_DEBUG_Display()
		if not TEAM_IS_RADIANT then return; end
		local thisWp = wanted_poster_head
		local n = 1
		while (thisWp) do
			if n > 20 then
				WARN_print("[wanted_poster] > 20 wanted posters active")
				return;
			end
			local obj = thisWp[POSTER_I__OBJECTIVE]
			local com = thisWp[POSTER_I__COMMIT_TYPES]
			local pre = thisWp[POSTER_I__PRE_COMMIT_TYPES]
			DebugDrawText(80, 480+8*n,
					string.format("%-18.18s|%d[%d]|%d[%d]|%d[%d]|%d[%d]|%d[%d]",
						string.sub(not obj and "none"
								or (type(obj) == "table" and obj.name and obj.shortName or obj.name
									or obj.hUnit and not obj.hUnit:IsNull()
										and (obj.hUnit.GetUnitName and obj.hUnit:GetUnitName()
											or obj.hUnit.GetName and obj.hUnit:GetName())
								) or tostring(obj), -18),
					com[1] or -0,pre[1] or -0,com[2] or -0,pre[2] or -0,com[3] or -0,pre[3] or -0,
					com[4] or -0,pre[4] or -0,com[5] or -0,pre[5] or -0
				), 110, 190, 255)
			thisWp = thisWp[POSTER_I__NEXT_POSTER]
			n=n+1
		end
	end
end
