require(GetScriptDirectory().."/lib_job/modules/communication")

local THIS_BOT = {}
local job_domain = {} -- Table is collected, but a useful allocated-table check skip
local job_domain_gsi = {}
local job_domain_analytics = {}
local job_domain_task = {}
local job_domain_init = {}

local generic_microthink

function Captain_Chat(msg, allChat)
	if not THIS_BOT then
		ERR_print("Captain not initialized for chatting.")
	end
	THIS_BOT.hUnit:ActionImmediate_Chat("[TeamCaptain] "..(msg or "<missing message text>"), allChat)
end

function Captain_RegisterCaptain(thisBot, microThinkFunc, deleteThisFunc)
	THIS_BOT.hUnit = thisBot
	THIS_BOT.Chat = Captain_Chat
	
	generic_microthink = microThinkFunc
	
	if not job_domain.IsJobRegistered then
		job_domain = Job_CreateDomain("DOMAIN_CAPTAIN")
		job_domain:RegisterJob(
				function(workingSet)
					if workingSet.throttle:allowed() then
						if GetGameState() <= GAME_STATE_HERO_SELECTION then
							return;
						end
						local teamplayerIDs = GetTeamPlayers(TEAM)
						for i=#teamplayerIDs,1,-1 do
							if GetTeamMember(i) == nil then
								if workingSet.nextAdviseWaiting < GameTime() then
									workingSet.nextAdviseWaiting = GameTime() + workingSet.addAdviseWait
									workingSet.addAdviseWait = workingSet.addAdviseWait * 2
									local adviseStr = workingSet.printFuncEscalates == INFO_print
											and string.format(
													"[captain] Waiting normally for team data.. "
														+ "Missing player was N: %d, ID: %d, time: %f, clock: %f",
													n, teamplayerIDs[n], GameTime(), DotaTime() )
											or string.format(
													"[captain] Ensure GameMode: ALL PICK; Five vs Five heroes on the standard Dota 2 map.. "
														+ "Missing player was N: %d, ID: %d, time: %f, clock: %f",
													n, teamplayerIDs[n], GameTime(), DotaTime() )
									workingSet.printFuncEscalates(adviseStr)
									workingSet.printFuncEscalates = ERROR_print
									INFO_print(string.format("[captain] Num players on %s: %d.", GSI_GetTeamString(TEAM), #teamplayerIDs))
								end
								return
							end
						end
						-- We have a full team, try init
						if Captain_InitializeCaptain then
							Captain_InitializeCaptain() -- deleted if previously called (from river rune fix)
						end
						job_domain:DeregisterJob("JOB_WAIT_FOR_GAME_INIT")
					end
				end,
				{["throttle"] = Time_CreateThrottle(0.5), ["nextAdviseWaiting"] = GameTime() + 1, ["addAdviseWait"] = 2, ["printFuncEscalates"] = INFO_print},
				"JOB_WAIT_FOR_GAME_INIT"
			)
	else
		Captain_RegisterCaptain = nil
	end
end

function Captain_InitializeCaptain(thisBot) -- This is ran via job_domain:JOB_WAIT_FOR_GAME_INIT that confirms GetTeamMember(n) will correctly return a player (awaiting full game init)
	INFO_print("Calling Game State Interface init")
	GSI_Initialize()
	Analytics_Initialize(job_domain)
	job_domain_gsi = GSI_GetGSIJobDomain()
	job_domain_analytics = Analytics_GetAnalyticsJobDomain()
	job_domain_task = Task_GetTaskJobDomain()
	
	Set_Initialize()
	
	-- GSI jobs triggered from the CaptainThink()
	GSI_CreateUpdateEnemyPlayersNoneTyped() -- Fast update null enemy players.
	GSI_CreateUpdatePlayerDataJob() -- Update gsiUnit deductions about players
	GSI_CreateUpdatePlayersLastSeen() -- Update last seen location of players
	GSI_CreateUpdateScoreboardAndKillstreaks() -- Slow check for killstreak drops
	GSI_CreateUpdateCreepUnits() -- Fast update null units and slow update HP/location
	GSI_CreateUpdateUnitSets() -- Update location groupings of units
	GSI_CreateUpdateBuildingUnits()
	--
	
	-- Analytics jobs triggered from the CaptainThink()
	Analytics_CreateUpdateLastHitProjectionCurrentVantage() -- Remove attacks that should've already occured
	Analytics_CreateUpdateLastHitProjectionFutureDamageLists() -- Update unit's blow-landing list
	Analytics_CreateUpdateFowMapPrediction()
	Analytics_CreateUpdateLanePressure()
	--
	
	-- Task jobs; See task.lua for task jobs (lots) -- triggered from the CaptainThink()
	Task_Initialize()
	--
	
	-- TODO once this functionality is put to good use, it needs to allow concurrent question types..., or question-triggers, like commands said in chat
	local tHumans = GSI_GetTeamHumans(TEAM)
	if tHumans and tHumans[1] then
		Communication_InitializeCommunication(THIS_BOT)
		if DEBUG then 
	--		DEBUG_QuestionPassableTerrain(job_domain, tHumans[1])
			DEBUG_QuestionSetNewIntern(job_domain, tHumans[1])
	--		DEBUG_QuestionSetDebug(job_domain, tHumans[1])
		end
	end
	
	-- n.b. replicated from Register
	THIS_BOT = GSI_GetBot()
	THIS_BOT.Chat = Captain_Chat

	THIS_BOT.Chat("/VUL-FT/ "..VULFT_VERSION, true)

	Captain_Initialize = nil
end

local DEBUG_timeTest = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
local DEBUG_fromTime
local i = 0
local DEBUG_timeTestThrottle = Time_CreateThrottle(10.0)
local err_count = 0
local err_check = 0


function Captain_CaptainThink()	
	if 1 then
		if err_check == 1 then err_count = err_count + 1 end err_check = 1 if err_count > 0 then DebugDrawText(140, 30, string.format("%d", err_count), 150, 0, 0) end
	end
	if job_domain_gsi.active then
		Time_TryTimeDataReset()
		if DEBUG and DEBUG_timeTestThrottle:allowed() then 
			print(TEAM_READABLE, "job retort:")
			for j=1,11,1 do 
				if DEBUG_timeTest[j] then 
					print("job", j, "elapsed", DEBUG_timeTest[j] * 1000, "ms over 10s")
				end
				DEBUG_timeTest[j] = 0
			end
		end
		i = 1 DEBUG_fromTime = RealTime()
	
		
		
		job_domain_gsi:DoJob("JOB_UPDATE_ENEMY_PLAYERS_NONE_TYPED")
		DEBUG_timeTest[i] = DEBUG_timeTest[i] + RealTime() - DEBUG_fromTime 
		i = i + 1 DEBUG_fromTime = RealTime()
		
		job_domain_gsi:DoJob("JOB_UPDATE_PLAYER_DATA")
		DEBUG_timeTest[i] = DEBUG_timeTest[i] + RealTime() - DEBUG_fromTime 
		i = i + 1 DEBUG_fromTime = RealTime()
		
		job_domain_gsi:DoJob("JOB_UPDATE_PLAYERS_LAST_SEEN")
		DEBUG_timeTest[i] = DEBUG_timeTest[i] + RealTime() - DEBUG_fromTime 
		i = i + 1 DEBUG_fromTime = RealTime()
		
		job_domain_gsi:DoJob("JOB_UPDATE_SCOREBOARD_AND_KILLSTREAKS")
		DEBUG_timeTest[i] = DEBUG_timeTest[i] + RealTime() - DEBUG_fromTime 
		i = i + 1 DEBUG_fromTime = RealTime()
		
		job_domain_gsi:DoJob("JOB_UPDATE_CREEP_UNITS")
		DEBUG_timeTest[i] = DEBUG_timeTest[i] + RealTime() - DEBUG_fromTime 
		i = i + 1 DEBUG_fromTime = RealTime()
		
		job_domain_gsi:DoJob("JOB_UPDATE_UNIT_SETS")
		DEBUG_timeTest[i] = DEBUG_timeTest[i] + RealTime() - DEBUG_fromTime 
		i = i + 1 DEBUG_fromTime = RealTime()
		
		job_domain_gsi:DoJob("JOB_UPDATE_BUILDING_UNITS")
		DEBUG_timeTest[i] = DEBUG_timeTest[i] + RealTime() - DEBUG_fromTime 
		i = i + 1 DEBUG_fromTime = RealTime()
	end
	
	if job_domain_analytics.active then
		
		job_domain_analytics:DoJob("JOB_UPDATE_LHP_CURRENT_VANTAGE")
		DEBUG_timeTest[i] = DEBUG_timeTest[i] + RealTime() - DEBUG_fromTime 
		i = i + 1 DEBUG_fromTime = RealTime()
		
		job_domain_analytics:DoJob("JOB_UPDATE_LHP_FUTURE_DAMAGE_LISTS")
		DEBUG_timeTest[i] = DEBUG_timeTest[i] + RealTime() - DEBUG_fromTime 
		i = i + 1 DEBUG_fromTime = RealTime()
		
		job_domain_analytics:DoJob("JOB_UPDATE_FOW_PREDICTION")
		DEBUG_timeTest[i] = DEBUG_timeTest[i] + RealTime() - DEBUG_fromTime
		i = i + 1 DEBUG_fromTime = RealTime()
		
		job_domain_analytics:DoJob("JOB_UPDATE_LANE_PRESSURE")
		DEBUG_timeTest[i] = DEBUG_timeTest[i] + RealTime() - DEBUG_fromTime
		i = i + 1 DEBUG_fromTime = RealTime()
		
		job_domain_analytics:DoJob("JOB_UPDATE_STRATEGIZE_WARDS")
		DEBUG_timeTest[i] = DEBUG_timeTest[i] + RealTime() - DEBUG_fromTime
	end
	
	if job_domain_task.active then
		
		job_domain_task:DoAllJobs()
	end

	if job_domain.active then
		
		
		
		job_domain:DoAllJobs()
	end

	if DEBUG and TEAM == TEAM_DIRE  then
		DEBUG_CreepAdventure()
	end
	
	AbilityThink_RotateAbilityThinkSetRun()
	
	Task_TryDecrementIncentives()
	if 1 then
		err_check = 0
	end
	generic_microthink()
	if VERBOSE then 
		local locs = VAN_GetWardLocations()
		local correctedLocs = VAN_GetWardLocationsCorrected()
		if locs then
			for i=1,#locs do
				if correctedLocs[i] then
					DebugDrawCircle(correctedLocs[i], 10, 50, 255, 150)
				end
			end
		end
	end
end

function Captain_GetCaptainJobDomain()
	return job_domain
end
