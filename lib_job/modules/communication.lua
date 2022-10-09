---- communication indices --
--
QUESTION_I__CAPTAINS_MSG = 		1
QUESTION_I__FUNC_ON_COMPLETION = 2
QUESTION_I__GOTO_IF_YES =		3
QUESTION_I__GOTO_IF_NO =			4
--

---- communication constants --
--
DEFAULT_THROTTLE_CHECK_QUESTION_ANSWERED = 		0.5
COMMUNICATION_QUESTIONNAIRE_END =				0xFFFF
COMMUNICATION_QUESTIONNAIRE_FIRST_QUESTION = 	1
--

local THIS_BOT
local job_domain_questions
local job_domain_queued_questions

local territory_dire = Map_GetLogicalLocation(MAP_ZONE_TERRITORY_DIRE)
local territory_radiant = Map_GetLogicalLocation(MAP_ZONE_TERRITORY_RADIANT)

local function queue_up_questions(tQuestions)
	
end

local function start_question_checking(jobDomain) -- 
	if not jobDomain:IsJobRegistered("JOB_COMMUNICATION_CHECK_UNTIL_ALL_ANSWERED") then
		jobDomain:RegisterJob(
				function(workingSet)
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
	local mostRecentChat = workingSet.hHumanAsked.comms.mostRecentChat
	if mostRecentChat ~= workingSet.mostRecentChat
			or Vector_Equal(workingSet.previousPing.location, mostRecentPing.location) == false then -- check for pings after question asked
		local funcOnCompletion = currentQuestion[QUESTION_I__FUNC_ON_COMPLETION]
		
		local currentQuestionIndexOverride = funcOnCompletion(workingSet)
		
		workingSet.currentQuestionIndex = 
				currentQuestionIndexOverride or (currentQuestionIndex >= #tQuestions and COMMUNICATION_QUESTIONNAIRE_END or currentQuestionIndex + 1)
		
		if workingSet.currentQuestionIndex == COMMUNICATION_QUESTIONNAIRE_END then-- End questionnaire if goto was 'END'
			return true
		else
			workingSet.previousPing = mostRecentPing
			workingSet.yesNoMsgSent = false
			workingSet.mostRecentChat = mostRecentChat
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
	end
	for i=1,#enemyHumans do
		enemyHumans[i].comms = {}
	end
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
	if not job_domain_questions.active then 
		job_domain_questions:RegisterJob(
				questionnaire__job,
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
				queued_questionnaire_to_current__job,
				{
					["hHumanAsked"] = 	hHumanAsked,
					["tQuestions"] = 	tQuestions,
				}
			)
	end
end
