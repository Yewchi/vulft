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

require(GetScriptDirectory().."/lib_job/modules/lang")

---- communication indices --
--
QUESTION_I__CAPTAINS_MSG = 		1
QUESTION_I__FUNC_ON_COMPLETION = 2
QUESTION_I__GOTO_IF_YES =		3
QUESTION_I__GOTO_IF_NO =			4
QUESTION_I__DELAY = 5
QUESTION_I__DELAY_END = 6

DRAW_I__LANG = 1
DRAW_I__STR = 2
DRAW_I__LOCATION = 3
DRAW_I__SCALE = 4
DRAW_I__RED = 5
DRAW_I__GREEN = 6
DRAW_I__BLUE = 7
DRAW_I__EXPIRES = 8
DRAW_I__END_CHECK = 9
--

---- communication constants --
--
DEFAULT_THROTTLE_CHECK_QUESTION_ANSWERED = 		0.5
COMMUNICATION_QUESTIONNAIRE_END =				0xFFFF
COMMUNICATION_QUESTIONNAIRE_FIRST_QUESTION = 	1
--

COMM = {}
COMM.READABLE_LANE = {"top", "mid", "bot"}
COMM.READABLE_ROLE_LANE = TEAM_IS_RADIANT and {"offlane", "middle", "safelane"}
		or {"safelane", "mid", "offlane"}
COMM.READABLE_ROLE = {"1", "2", "3", "4", "5"}

-- 
COMM_CHAT_KILL = "KILL"
COMM_CHAT_CALLBACK_FUNCS = {}
COMM_CHAT_CMD_CALLBACK_FUNCS = {}
-- Comm_RegisterCallbackFunc() RULES:
-- -| Chat commands are not allowed to be triggers in and of themself if the chat is also to interpret a "!" command.
-- -| Only one chat function per ![cmdstr].
-- -| If a command func finds it's cmd string, it should return the string "KILL" to prevent further checks
-------- Comm_RegisterCallbackFunc()
function Comm_RegisterCallbackFunc(key, func, isCmd)
	if isCmd then
		COMM_CHAT_CMD_CALLBACK_FUNCS[key] = func
	else
		COMM_CHAT_CALLBACK_FUNCS[key] = func
	end
end
InstallChatCallback(
		function(event)
			if not event.string then return; end
			local cmd = string.match(event.string, "^%s*!([^%s]*)")
			local funcsTbl = cmd
					and COMM_CHAT_CMD_CALLBACK_FUNCS
					or COMM_CHAT_CALLBACK_FUNCS
			for key,func in pairs(funcsTbl) do
				if func(event, cmd) == "KILL" then
					if DEBUG then DEBUG_print(string.format("Chat func run killed by '%s' with chat: %s", key, Util_PrintableTable(event))) end
					return;
				end
			end
		end
	)

Comm_RegisterCallbackFunc("SET_LANGUAGE",
		function(event, cmd)
			if not IsPlayerBot(event.player_id) then
				local secondArg = string.match(event.string, "^%s*[^%s]+%s*([^%s]*)")
				local isLangCmd, localeOfCmd = Lang_IsLanguageCmd(cmd)
				
				if isLangCmd then
					local localeExists, locale = Lang_CheckLocalizeExists(secondArg, localeOfCmd)
					if localeExists then
						LOCALE = locale
						Captain_AddChatToQueue(string.format("%s: %s, %s.",
									GetLocalize("lang"), GetLocaleProperName(locale), locale
								), true, 0.2
							)
					end
					return COMM_CHAT_KILL;
				end
			end
			return; 
		end,
		true
	)

local THIS_BOT
local job_domain_questions
local job_domain_queued_questions

local registered_map_draws = {}

local territory_dire
local territory_radiant

local alphabet = {
	["en"] = {
		[49]={{-0.25, 0.65,0.2,1},{0.2,1,0.2,-1},{-0.3,-1,0.5,-1}}, -- 1
		[50]={{-0.7,0.7,-0.65,0.85},{-0.65,0.85,0.4,1},{0.4,1,0.75,0.7}, -- 2
				{0.75,0.7,0.-0.7,-1},{-0.7,-1,0.7,-1}},
		[51]={{-0.7,0.7,-0.5,0.85},{-0.5,0.85,0.5,1},{0.5,1,0.7,0.0},{0.7,0.0,0,0}, -- 3
				{0.7,0,0.5,-1},{0.5,-1,-0.5,-0.85},{-0.5,-0.85,-0.7,-0.7}},
		[52]={{0,1,-0.7,0.2},{-0.7,0.2,0.7,0.2},{0.1,1,0.1,-1}}, -- 4
		[53]={{0.7,1,-0.6,0.9},{-0.6,0.9,-0.7,0.1},{-0.7,0.1,0.55,0},{0.55,0,0.45,-1}, -- 5
				{0.45,-1,-0.7,-1}},
		[65]={{-1,-1,0,1},{0,1,1,-1},{-0.5,0,0.5,0}}, -- A
		[66]={{-1,-1,-1,1},{-1,1,1,1},{1,1,0.8,0.1},{0.8,0.1,0.65,0},{0.65,0,-1,0}, -- B
				{0.65,0,0.8,-0.1},{0.8,-0.1,1,-1},{1,-1,-1,-1}},
		[68]={{-0.8,-1,-0.8,1},{-0.8,1,0.55,0.75},{0.55,0.75,0.55,-0.75},{0.55,-0.75,-0.8,-1}}, -- D
		[73]={{-0.3,-1,0.3,-1},{0,-1,0,1},{-0.3,1,0.3,1}}, -- I
		[77]={{-1,-1,-1,1},{-1,1,0,-0.6},{0,-0.6,1,1},{1,1,1,-1}}, -- M
		[79]={{-0.6,-1,-0.8,-0.7},{-0.8,-0.7,-0.8,0.8},{-0.8,0.8,-0.6,1},{-0.6,1,0.6,1}, -- O
				{0.6,1,0.8,0.7},{0.8,0.7,0.8,-0.7},{0.8,-0.7,0.6,-1},{0.6,-1,-0.6,-1}}, 
		[80]={{-0.8,-1,-0.8,1},{-0.8,1,0.8,1},{0.8,1,0.8,0.25},{0.8,0.25,0.6,0},{0.6,0,-0.95,0}}, -- P
		[84]={{-1,1,1,1},{0,1,0,-1}} -- T
	}
}

function Comm_DrawMapChar(lang, char, location, scale, cR, cG, cB)
	char = char:upper()
	local charVecs = alphabet[lang][char:byte(1)]
	for i=1,#charVecs do
		local charLine = charVecs[i]
		DebugDrawLine(Vector(location.x+charLine[1]*scale, location.y+charLine[2]*scale, 128),
				Vector(location.x+charLine[3]*scale, location.y+charLine[4]*scale, 128),
				cR, cG, cB
			)
	end
end

function Comm_DrawMapString(lang, str, location, scale, cR, cG, cB)
	str = str:upper()
	local strlen = str:len()
	local offsetLeft = strlen/2 + 1 -- Lua
	local charSpace = scale*2 + scale/8
	local yCenter = location.y
	for c=1,strlen do
		local charVecs = alphabet[lang][str:byte(c)]
		local xCenter = location.x+(c-offsetLeft)*charSpace
		if charVecs then
			for i=1,#charVecs do
				local charLine = charVecs[i]
				DebugDrawLine(Vector(xCenter + charLine[1]*scale, yCenter + charLine[2]*scale, 128),
						Vector(xCenter+charLine[3]*scale, yCenter+charLine[4]*scale, 128),
						cR, cG, cB
					)
			end
		end
	end
end

function Comm_YesFromKnownNewPing(pingLoc)
	return Map_IsAboveMiddleLine(pingLoc)
end

function Comm_YesFromKnownNewChat(str)
	return str:upper():find("Y")
end

function Comm_RegisterMapDrawTimed(lang, str, loc, scale, cR, cG, cB, delta, endCheckFunc)
	local newDraw = {lang, str, loc, scale, cR, cG, cB, GameTime() + delta, endCheckFunc}
	table.insert(registered_map_draws, newDraw)
	return newDraw
end

function Comm_InterpretHumanLane(nonsense)
	INFO_print("comm interpret '%s'", nonsense)
	nonsense = ConvertLocalizedWord(nonsense, nil, DEV_ENVIRONMENT_LOCALE) -- .'. we logically check both the locale text and the dev env locale
	INFO_print("comm interpret gave '%s'", nonsense)
	for lane,readable in pairs(COMM.READABLE_LANE) do
		print(readable)
		if nonsense:lower():find(readable) then
			INFO_print("... got it")
			return lane, readable
		end
	end
	return false, ""
end

function Comm_InterpretHumanRole(nonsense)
	nonsense = ConvertLocalizedWord(nonsense, nil, DEV_ENVIRONMENT_LOCALE)
	for role,readable in pairs(COMM.READABLE_ROLE) do
		if nonsense:lower():find(readable) then
			return role, readable
		end
	end
	return false, ""
end

-- not refactoring anything until good concurrency is theorized
-- module was clearly not finished when I had it in the 'works' state

local function queue_up_questions(tQuestions)
	
end

local function start_question_checking(jobDomain) -- 
	if not jobDomain:IsJobRegistered("JOB_COMMUNICATION_CHECK_UNTIL_ALL_ANSWERED") then
		jobDomain:RegisterJob(
				function(workingSet)
					-- Run draws if any
					if registered_map_draws[1] then
						local i=1
						while(i <= #registered_map_draws) do 
							local thisDraw = registered_map_draws[i]
							local endCheckFunc = thisDraw[DRAW_I__END_CHECK]
							if thisDraw[DRAW_I__EXPIRES] < GameTime()
									or (endCheckFunc and endCheckFunc()) then
								table.remove(registered_map_draws, i)
							else
								Comm_DrawMapString(thisDraw[1], thisDraw[2], thisDraw[3],
										thisDraw[4], thisDraw[5], thisDraw[6], thisDraw[7])
								i = i + 1
							end
						end
					end
					-- check Questions
					if workingSet.throttle:allowed() then
						Communication_UpdateCommunications()
						if not (job_domain_questions.active or job_domain_queued_questions.active) then
							return true
						end
					end
				end,
				{["throttle"] = Time_CreateThrottle(DEFAULT_THROTTLE_CHECK_QUESTION_ANSWERED)},
				"JOB_COMMUNICATION_CHECK_UNTIL_ALL_ANSWERED"
			)
	end
end

local function send_question_msg_if_unsent(workingSet, msg)
	if not workingSet.msgSent and msg then
		Captain_Chat(msg, false)
		workingSet.msgSent = true
	end
end

local function questionnaire_yes_no__job(workingSet)
	local tQuestions = workingSet.tQuestions
	local currentQuestion = tQuestions[workingSet.currentQuestionIndex]

	send_question_msg_if_unsent(workingSet, currentQuestion[QUESTION_I__CAPTAINS_MSG])
	
	local mostRecentPing = workingSet.hHumanAsked.hUnit:GetMostRecentPing()
	if Vector_Equal(workingSet.previousPing.location, mostRecentPing.location) == false then -- check for pings after question asked
		local funcOnCompletion = currentQuestion[QUESTION_I__FUNC_ON_COMPLETION]
		local currentQuestionIndexOverrride
		-- "Yes" given
		if Vector_PointWithinTriangle(mostRecentPing.location, territory_radiant[1], territory_radiant[2], territory_radiant[3]) then
			if funcOnCompletion then
				currentQuestionIndexOverrride = funcOnCompletion(workingSet, true)
			end
			workingSet.currentQuestionIndex = 
					(currentQuestionIndexOverrride or currentQuestion[QUESTION_I__GOTO_IF_YES])
		-- "No" given
		elseif Vector_PointWithinTriangle(mostRecentPing.location, territory_dire[1], territory_dire[2], territory_dire[3]) then
			if funcOnCompletion then 
				currentQuestionIndexOverrride = funcOnCompletion(workingSet, false)
			end
			workingSet.currentQuestionIndex = 
					(currentQuestionIndexOverrride or currentQuestion[QUESTION_I__GOTO_IF_NO])
		end
		
		if workingSet.currentQuestionIndex == COMMUNICATION_QUESTIONNAIRE_END then-- End questionnaire if goto was 'END'
			return true
		else
			print("updated ping", mostRecentPing.location)
			workingSet.previousPing = mostRecentPing
			workingSet.msgSent = false
		end
	end
end

local function questionnaire__job(workingSet)
	local tQuestions = workingSet.tQuestions
	local currentQuestionIndex = workingSet.currentQuestionIndex
	local currentQuestion = tQuestions[currentQuestionIndex]

	send_question_msg_if_unsent(workingSet, currentQuestion[QUESTION_I__CAPTAINS_MSG])
	
	local mostRecentPing = workingSet.hHumanAsked.hUnit:GetMostRecentPing()
	local mostRecentChatText = workingSet.hHumanAsked.comms.mostRecentChatText

	workingSet.expired = currentQuestion[QUESTION_I__DELAY_END]
			and currentQuestion[QUESTION_I__DELAY_END] < GameTime()






	if mostRecentChatText ~= workingSet.previousChatText
			or Vector_Equal(workingSet.previousPing.location, mostRecentPing.location) == false
			or workingSet.expired then
		currentQuestion[QUESTION_I__DELAY_END] = false

		local funcOnCompletion = currentQuestion[QUESTION_I__FUNC_ON_COMPLETION]
		
		local currentQuestionIndexOverride = funcOnCompletion(workingSet)
		
		workingSet.currentQuestionIndex = 
				currentQuestionIndexOverride or (currentQuestionIndex >= #tQuestions and COMMUNICATION_QUESTIONNAIRE_END or currentQuestionIndex + 1)
		
		if workingSet.currentQuestionIndex == COMMUNICATION_QUESTIONNAIRE_END then-- End questionnaire if goto was 'END'
			return true
		else
			currentQuestion = tQuestions[workingSet.currentQuestionIndex]
			if currentQuestion[QUESTION_I__DELAY] then
				currentQuestion[QUESTION_I__DELAY_END] = GameTime() + currentQuestion[QUESTION_I__DELAY]
			end
			workingSet.previousPing = mostRecentPing
			workingSet.msgSent = false
			workingSet.previousChatText = mostRecentChatText
		end
	end
end

local function queued_questionnaire_yes_no_to_current__job(workingSet)
	if not job_domain_questions.active then
		Communication_QuestionYesNo(
				workingSet.trackingJobDomain, 
				workingSet.hHumanAsked, 
				workingSet.tQuestionnaire
			)
		return true
	end
end

function Communication_InitializeCommunication(thisBot)
	THIS_BOT = thisBot
	job_domain_questions = Job_CreateDomain("DOMAIN_QUESTIONNAIRE")
	job_domain_queued_questions = Job_CreateDomain("DOMAIN_QUEUED_QUESTIONNAIRES")
	job_domain_queued_questions.numQueued = 0
	local teamHumans = GSI_GetTeamHumans(TEAM)
	local enemyHumans = GSI_GetTeamHumans(ENEMY_TEAM)
	for i=1,#teamHumans do
		teamHumans[i].comms = {}
		teamHumans[i].comms.mostRecentChatText = ""
		teamHumans[i].comms.mostRecentPing = teamHumans[i].hUnit:GetMostRecentPing()
	end
	for i=1,#enemyHumans do
		enemyHumans[i].comms = {}
		enemyHumans[i].comms.mostRecentChatText = ""
		enemyHumans[i].comms.mostRecentPing = teamHumans[i].hUnit:GetMostRecentPing()
	end
	territory_dire = Map_GetLogicalLocation(MAP_ZONE_TERRITORY_DIRE)
	territory_radiant = Map_GetLogicalLocation(MAP_ZONE_TERRITORY_RADIANT)
end

function Communication_UpdateCommunications() -- Use of this function should be throttled by it's callers
--[[VERBOSEif VERBOSE then VEBUG_print("Checking comms") end]]
	if job_domain_questions.active then
		job_domain_questions:DoAllJobs()
	end
	if not job_domain_queued_questions.DoQueuedJob then
		Util_TablePrint(job_domain_queued_questions)
	end
	if job_domain_queued_questions.active and not job_domain_questions.active then
		job_domain_queued_questions:DoQueuedJob()
	end
end

function Communication_QuestionYesNo(trackingJobDomain, hHumanAsked, tQuestions)
	if tQuestions[1][QUESTION_I__DELAY] then
		tQuestions[1][QUESTION_I__DELAY_END] = GameTime() + tQuestions[1][QUESTION_I__DELAY]
		
	end
	if not job_domain_questions.active then 
		job_domain_questions:RegisterJob(
				questionnaire_yes_no__job,
				{
					["previousPing"] = 			hHumanAsked.hUnit:GetMostRecentPing(),
					["hHumanAsked"] = 			hHumanAsked,
					["tQuestions"] = 			tQuestions,
					["currentQuestionIndex"] = 	COMMUNICATION_QUESTIONNAIRE_FIRST_QUESTION
				},
				"JOB_CURRENT_QUESTIONNAIRE"
			)
		start_question_checking(trackingJobDomain)
	else
		job_domain_queued_questions:RegisterJob(
				queued_questionnaire_yes_no_to_current__job,
				{
					["hHumanAsked"] = 	hHumanAsked,
					["tQuestions"] = 	tQuestions,
				}
			)
	end
end

function Communication_Question(trackingJobDomain, hHumanAsked, tQuestions)
	if tQuestions[1][QUESTION_I__DELAY] then
		tQuestions[1][QUESTION_I__DELAY_END] = GameTime() + tQuestions[1][QUESTION_I__DELAY]
		print("Delay is", tQuestions[1][QUESTION_I__DELAY_END], GameTime(), tQuestions[1][QUESTION_I__DELAY]) 
	end
	--if not job_domain_questions.active then 
		job_domain_questions:RegisterJob(
				questionnaire__job,
				{
					["previousPing"] = 			hHumanAsked.hUnit:GetMostRecentPing(),
					["previousChatText"] =			hHumanAsked.comms.mostRecentChatText or "",
					["hHumanAsked"] = 			hHumanAsked,
					["tQuestions"] = 			tQuestions,
					["currentQuestionIndex"] = 	COMMUNICATION_QUESTIONNAIRE_FIRST_QUESTION
				},
				"JOB_CURRENT_QUESTIONNAIRE"
			)
		start_question_checking(trackingJobDomain)
	--[[else
		job_domain_queued_questions:RegisterJob(
				queued_questionnaire_to_current__job,
				{
					["hHumanAsked"] = 	hHumanAsked,
					["tQuestions"] = 	tQuestions,
				}
			)
	end]]
end
