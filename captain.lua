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

require(GetScriptDirectory().."/lib_job/modules/communication")
local player_role_and_lane_file

local THIS_BOT = {}
local job_domain = {} -- Table is collected, but a useful allocated-table check skip
local job_domain_gsi = {}
local job_domain_analytics = {}
local job_domain_task = {}
local job_domain_init = {}

local generic_microthink

local DEBUG_VERS = "vulft-"..VERSION

CAPTAIN_CONFIG_NON_STANDARD = {
		["LANE_AND_ROLE"] = "*",
		["HERO_UNTESTED_ABILITY_USE"] = "H",
	}
local CAPTAIN_CONFIG_STANDARD = ""
local captain_config_non_standard_settings = CAPTAIN_CONFIG_STANDARD

local t_unimplemented_heroes = {}

local should_draw_unimplemented_heroes_func
local function draw_unimplemented_heroes()
	if DotaTime() < 100 then
		local red = math.min(255, math.max(0, (DotaTime() - 90)*25))
		DebugDrawText(300, 300, "untested / unreleased vulft bots are running", red, 255-red, 255-red)
		DebugDrawText(300, 310, "please run vulft from the local server to allow vulft to control hero selection", red, 255-red, 255-red)
		DebugDrawText(300, 320, "this message will disappear at 1:40", red, 255-red, 255-red)
	end
	DebugDrawText(160, 5, "VUL-FT untested:", 80, 0, 0)
	if TEAM_IS_RADIANT and GameTime() % 16 < 8 or not TEAM_IS_RADIANT and GameTime() % 16 > 8 then
		for i=1,#t_unimplemented_heroes do
			DebugDrawText(160, 8+(10*i), t_unimplemented_heroes[i], 80, 0, 0)
		end
	end
end

CHAT_CALLBACK_FUNCS = {}

function Captain_ConfigIndicateNonStandardSetting(setting, ...)
	if setting == CAPTAIN_CONFIG_NON_STANDARD.HERO_UNTESTED_ABILITY_USE then
		local args = {...}
		print("args1", args[1])
		table.insert(t_unimplemented_heroes, args[1])
		Util_TableAlphabeticalSortValue(t_unimplemented_heroes)
		should_draw_unimplemented_heroes_func = draw_unimplemented_heroes
	end

	if not captain_config_non_standard_settings:find(setting) then
		captain_config_non_standard_settings = captain_config_non_standard_settings..setting
	end
end

function Captain_Chat(msg, allChat)
	if not THIS_BOT then
		ERR_print("Captain not initialized for chatting.")
	end
	THIS_BOT.hUnit:ActionImmediate_Chat("[Captain] "..(msg or "<missing message text>"), allChat)
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
													"[Captain] Waiting normally for team data.. "
														.."Missing player was N: %d, ID: %d, time: %f, clock: %f",
													i, teamplayerIDs[n] or -1, GameTime(), DotaTime() )
											or string.format(
													"[Captain] Ensure GameMode: ALL PICK; Five vs Five heroes on the standard Dota 2 map.. "
														.."Missing player was N: %d, ID: %d, time: %f, clock: %f",
													i, teamplayerIDs[n] or -1, GameTime(), DotaTime() )
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
	--[[	
		if GetBot():GetDifficulty() == 4 then
			local team_humans = GSI_GetTeam
			Communication_Question(
				job_domain, 
				1, 
				{
					[1] = {
						"Bots default to drawing emotes under them for their current state in Easy mode. Turn off with !emote off", 
						function(workingSet) 
							local t

								TEAM_CAPTAIN_UNIT.Chat("Emotes off", false)
								return 2
							end
						end
					},
				}

			InstallChatCallback(
					function(event)
						if not IsPlayerBot(event.player_id) then
							humanPlayer.comms. = event.string
							humanPlayer.comms.mostRecentChat = event
						end
					end
				)
			
		end]]
	else
		Captain_RegisterCaptain = nil
	end
end

local function register_human_processing_job()
	local teamHumans = GSI_GetTeamHumans(TEAM)
	local updateFarmLaneLastHits = FarmLane_UpdateHumanLastHit
	job_domain:RegisterJob(
			function(workingSet)
				if workingSet.throttle:allowed() then
					for i=1,#teamHumans do
						updateFarmLaneLastHits(teamHumans[i])
					end
				end
			end,
			{["throttle"] = Time_CreateThrottle(0.25)},
			"JOB_UPDATE_HUMAN_LAST_HITS"
		)
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
	GSI_CreateUpdateCreepUnits() -- Fast update null units and slow update HP/location
	GSI_CreateUpdateUnitSets() -- Update location groupings of units
	GSI_CreateUpdateBuildingUnits()
	GSI_CreateUpdateScoreboardAndKillstreaks() -- Slow check for killstreak drops -- TODO Analytics, not GSI refactor
	--
	
	-- Analytics jobs triggered from the CaptainThink()
	Analytics_CreateUpdateLastHitProjectionCurrentAttacks() -- Remove attacks that should've already occured
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
		-- TODO currently only working for 1 human
		player_lane_and_role_file = require(GetScriptDirectory().."/lib_human/player_role_and_lane")

		Communication_InitializeCommunication(THIS_BOT)
		if DEBUG then 
	--		DEBUG_QuestionPassableTerrain(job_domain, tHumans[1])
	-- 		DEBUG_QuestionSetNewIntern(job_domain, tHumans[1])
	--		DEBUG_QuestionSetDebug(job_domain, tHumans[1])
		end
		PLAYER_ROLE_AND_LANE.DoLaneChoice(job_domain, tHumans[1])
		register_human_processing_job()
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
--[[DEV]]local dev_progress = 0.0001 + 100/15--[[/DEV]]
--[[DEV]]local floor = math.floor--[[/DEV]]
function Captain_CaptainThink()	
	--[[TESTTRUE]]if DEBUG then
		if err_check == 1 then err_count = err_count + 1 end err_check = 1 if err_count > 0 then DebugDrawText(140, 30, string.format("%d", err_count), 150, 0, 0) end
		--[[DEV]]WP_DEBUG_Display()
	end

	if captain_config_non_standard_settings ~= CAPTAIN_CONFIG_STANDARD then
		DebugDrawText(1, TEAM_IS_RADIANT and 4 or 12, captain_config_non_standard_settings, 209, 176, 139)
	end

	if DEBUG or should_draw_unimplemented_heroes_func then
		DebugDrawText(960-7*string.len(DEBUG_VERS)/2,50,DEBUG_VERS,100,0,0)
		if DEBUG then
		end
	end

	if should_draw_unimplemented_heroes_func then
		should_draw_unimplemented_heroes_func()
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

		--[[DEV]]VEBUG_PlayerFrameProgressBarStart(-1)--[[/DEV]]
		--[[DEV]]VEBUG_PlayerFrameProgressBar(-1, floor(0*dev_progress))--[[/DEV]]
		job_domain_gsi:DoJob("JOB_UPDATE_ENEMY_PLAYERS_NONE_TYPED")
		DEBUG_timeTest[i] = DEBUG_timeTest[i] + RealTime() - DEBUG_fromTime 
		i = i + 1 DEBUG_fromTime = RealTime()
		--[[DEV]]VEBUG_PlayerFrameProgressBar(-1, floor(1*dev_progress))--[[/DEV]]
		job_domain_gsi:DoJob("JOB_UPDATE_PLAYER_DATA")
		DEBUG_timeTest[i] = DEBUG_timeTest[i] + RealTime() - DEBUG_fromTime 
		i = i + 1 DEBUG_fromTime = RealTime()
		--[[DEV]]VEBUG_PlayerFrameProgressBar(-1, floor(2*dev_progress))--[[/DEV]]
		job_domain_gsi:DoJob("JOB_UPDATE_PLAYERS_LAST_SEEN")
		DEBUG_timeTest[i] = DEBUG_timeTest[i] + RealTime() - DEBUG_fromTime 
		i = i + 1 DEBUG_fromTime = RealTime()
		--[[DEV]]VEBUG_PlayerFrameProgressBar(-1, floor(3*dev_progress))--[[/DEV]]
		job_domain_gsi:DoJob("JOB_UPDATE_CREEP_UNITS")
		DEBUG_timeTest[i] = DEBUG_timeTest[i] + RealTime() - DEBUG_fromTime 
		i = i + 1 DEBUG_fromTime = RealTime()
		--[[DEV]]VEBUG_PlayerFrameProgressBar(-1, floor(4*dev_progress))--[[/DEV]]
		job_domain_gsi:DoJob("JOB_UPDATE_UNIT_SETS")
		DEBUG_timeTest[i] = DEBUG_timeTest[i] + RealTime() - DEBUG_fromTime 
		i = i + 1 DEBUG_fromTime = RealTime()
		--[[DEV]]VEBUG_PlayerFrameProgressBar(-1, floor(5*dev_progress))--[[/DEV]]
		job_domain_gsi:DoJob("JOB_UPDATE_BUILDING_UNITS")
		DEBUG_timeTest[i] = DEBUG_timeTest[i] + RealTime() - DEBUG_fromTime 
		i = i + 1 DEBUG_fromTime = RealTime()
		--[[DEV]]VEBUG_PlayerFrameProgressBar(-1, floor(6*dev_progress))--[[/DEV]]
		job_domain_gsi:DoJob("JOB_UPDATE_SCOREBOARD_AND_KILLSTREAKS")
		DEBUG_timeTest[i] = DEBUG_timeTest[i] + RealTime() - DEBUG_fromTime 
		i = i + 1 DEBUG_fromTime = RealTime()
	end
	
	if job_domain_analytics.active then
		--[[DEV]]VEBUG_PlayerFrameProgressBar(-1, floor(7*dev_progress))--[[/DEV]]
		job_domain_analytics:DoJob("JOB_UPDATE_LHP_CURRENT_ATTACKS")
		DEBUG_timeTest[i] = DEBUG_timeTest[i] + RealTime() - DEBUG_fromTime 
		i = i + 1 DEBUG_fromTime = RealTime()
		--[[DEV]]VEBUG_PlayerFrameProgressBar(-1, floor(8*dev_progress))--[[/DEV]]
		job_domain_analytics:DoJob("JOB_UPDATE_LHP_FUTURE_DAMAGE_LISTS")
		DEBUG_timeTest[i] = DEBUG_timeTest[i] + RealTime() - DEBUG_fromTime 
		i = i + 1 DEBUG_fromTime = RealTime()
		--[[DEV]]VEBUG_PlayerFrameProgressBar(-1, floor(9*dev_progress))--[[/DEV]]
		job_domain_analytics:DoJob("JOB_UPDATE_FOW_PREDICTION")
		DEBUG_timeTest[i] = DEBUG_timeTest[i] + RealTime() - DEBUG_fromTime
		i = i + 1 DEBUG_fromTime = RealTime()
		--[[DEV]]VEBUG_PlayerFrameProgressBar(-1, floor(10*dev_progress))--[[/DEV]]
		job_domain_analytics:DoJob("JOB_UPDATE_LANE_PRESSURE")
		DEBUG_timeTest[i] = DEBUG_timeTest[i] + RealTime() - DEBUG_fromTime
		i = i + 1 DEBUG_fromTime = RealTime()
		--[[DEV]]VEBUG_PlayerFrameProgressBar(-1, floor(11*dev_progress))--[[/DEV]]
		job_domain_analytics:DoJob("JOB_UPDATE_STRATEGIZE_WARDS")
		DEBUG_timeTest[i] = DEBUG_timeTest[i] + RealTime() - DEBUG_fromTime
	end
	
	if job_domain_task.active then
		--[[DEV]]VEBUG_PlayerFrameProgressBar(-1, floor(12*dev_progress))--[[/DEV]]
		job_domain_task:DoAllJobs()
	end

	if job_domain.active then
		--[[DEV]]if DEBUG then VEBUG_PlayerFrameProgressBar(-1, floor(13*dev_progress))--[[/DEV]]
		--[[DEV]]	DEBUG_print("printing captin job_domain")--[[/DEV]]
		--[[DEV]]	job_domain:ListJobKeys()
		--[[DEV]]end--[[/DEV]]--[[/DEV]]--[[/DEV]]
		job_domain:DoAllJobs()
	end

--[[DEV]]	if DEBUG and TEAM == TEAM_DIRE then
--[[DEV]]		DEBUG_CreepAdventure()
--[[DEV]]	end
	if job_domain_gsi.active then
		--[[DEV]]VEBUG_PlayerFrameProgressBar(-1, floor(14*dev_progress))--[[/DEV]]
		AbilityThink_RotateAbilityThinkSetRun()
		--[[DEV]]VEBUG_PlayerFrameProgressBar(-1, floor(15*dev_progress))--[[/DEV]]
		Task_TryDecrementIncentives()
	end
	--[[TESTTRUE]]if DEBUG then
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
