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

-- Determine a human's ideas about what their lane and role is

local team_humans = GSI_GetTeamHumans(TEAM)

PLAYER_ROLE_AND_LANE = {}

local LANE_ROLES = LANE_ROLES

TOP_NOTICABLE = TEAM_IS_RADIANT and Vector(-6600, -4478) or Vector(4605, 5756)
MID_NOTICABLE = TEAM_IS_RADIANT and Vector(-5572, -5054) or Vector(5105, 4609)
BOT_NOTICABLE = TEAM_IS_RADIANT and Vector(-5060, -6081) or Vector(6327, 4128)

local DRAW_COLOR = {220, 200, 150}

local QSTN_LANE_ROLE_DELAY_START_GAME = 6
local QSTN_LANE_ROLE_WAIT_ANSWER = 20

local function set_human_lane_role(gsiHuman, lane, role)
	Hero_HardSetRole(gsiHuman, role)
	Hero_HardSetLane(gsiHuman, lane)
	gsiHuman.hardSetRole = role
	DeduceBestRolesAndLanes()
	GetBot():ActionImmediate_Chat(
			string.format("Set you to %s, pos %d..",
					COMM.READABLE_ROLE_LANE[lane],
					role
				),
			false
		)

	Captain_ConfigIndicateNonStandardSetting(CAPTAIN_CONFIG_NON_STANDARD.LANE_AND_ROLE)
end

PLAYER_ROLE_AND_LANE.DoLaneChoice = function(jobDomain, gsiHuman)
	WARN_print(string.format("ahh, a human! And with playerID=%d.", gsiHuman.playerID))
	local check_chat = function(event)
		
	end
	local defaultLane = Team_GetRoleBasedLane(gsiHuman)

	local laneChosen
	local roleChosen

	-- Intentionally overblown interfacing (you could just ping T2 for pos 5, T1 for pos 1 in the safelane)
	-- -| so that the player is taught about the intended communication system.
	Communication_Question(
			jobDomain, 
			gsiHuman, 
			{
				[1] = {
					nil,
					function(workingSet)
						workingSet.topPrint = Comm_RegisterMapDrawTimed("en", "TOP", TOP_NOTICABLE,
								64, DRAW_COLOR[1], DRAW_COLOR[2], DRAW_COLOR[3],
								QSTN_LANE_ROLE_WAIT_ANSWER
							)
						workingSet.midPrint = Comm_RegisterMapDrawTimed("en", "MID", MID_NOTICABLE,
								64, DRAW_COLOR[1], DRAW_COLOR[2], DRAW_COLOR[3],
								QSTN_LANE_ROLE_WAIT_ANSWER
							)
						workingSet.botPrint = Comm_RegisterMapDrawTimed("en", "BOT", BOT_NOTICABLE,
								64, DRAW_COLOR[1], DRAW_COLOR[2], DRAW_COLOR[3],
								QSTN_LANE_ROLE_WAIT_ANSWER
							)
						return 2
					end,
					nil,
					nil,
					QSTN_LANE_ROLE_DELAY_START_GAME
				},
				[2] = {
					string.format("To set your lane, ping the map, we have placed you: 'pos %d' in '%s' (%s meta). If roam/jungle, keep default.", 
							gsiHuman.role, COMM.READABLE_LANE[Team_GetRoleBasedLane(gsiHuman)],
							META_DATE
						),
					function(workingSet) 
						Util_TablePrint(gsiHuman.comms.mostRecentPing)
						if workingSet.expired then
							local talk = RandomFloat(1,33)
							GetBot():ActionImmediate_Chat(talk < 1.0 and "lets spagettit" or "roles set", false)
							return COMMUNICATION_QUESTIONNAIRE_END
						end
						local recentPing = gsiHuman.hUnit:GetMostRecentPing()

						GetBot():ActionImmediate_Ping(recentPing.location.x,
								recentPing.location.y, false)
						if not Vector_Equal(recentPing.location, workingSet.previousPing.location)
								then
							laneChosen = Map_GetLaneValueOfMapPoint(recentPing.location)
						end
						local recentChatText = gsiHuman.comms.mostRecentChatText
						if recentChatText ~= workingSet.previousChatText then
							local lane = Comm_InterpretHumanLane(recentChatText)
							if lane then
								laneChosen = lane
							end
						end
						if laneChosen then
							if laneChosen == 2 then
								roleChosen = 2
								set_human_lane_role(gsiHuman, laneChosen, roleChosen)
								workingSet.topPrint[DRAW_I__EXPIRES] = 0
								workingSet.midPrint[DRAW_I__EXPIRES] = 0
								workingSet.botPrint[DRAW_I__EXPIRES] = 0
								return COMMUNICATION_QUESTIONNAIRE_END
							end
							local roleChoice1 = LANE_ROLES[laneChosen][1]
							local roleChoice2 = LANE_ROLES[laneChosen][2]
							GetBot():ActionImmediate_Chat(
									string.format(
										"Setting you to %s.. now ping your role (top for pos%d, bot for pos%d)",
										COMM.READABLE_LANE[laneChosen],
										roleChoice1, roleChoice2
									),
									false
								)
							workingSet.topPrint[DRAW_I__STR] = ""..roleChoice1
							workingSet.topPrint[DRAW_I__EXPIRES] = GameTime() + QSTN_LANE_ROLE_WAIT_ANSWER
							workingSet.botPrint[DRAW_I__STR] = ""..roleChoice2
							workingSet.botPrint[DRAW_I__EXPIRES] = GameTime() + QSTN_LANE_ROLE_WAIT_ANSWER
							workingSet.midPrint[DRAW_I__EXPIRES] = 0
							return 3
						end
						return 2
					end,
					nil,
					nil,
					QSTN_LANE_ROLE_WAIT_ANSWER
				},
				[3] = {
					nil, 
					function(workingSet) 
						if workingSet.expired then
							roleChosen, backupChoice, isClosestToKnown
									= Hero_GetCommonHeroRoleInLane(gsiHuman, laneChosen)
							roleChosen = roleChosen or backupChoice
							Captain_Chat(string.format(":| assuming player is %s in %s: pos %d",
										isClosestToKnown and "expected role" or "default",
										COMM.READABLE_ROLE_LANE[laneChosen], roleChosen
									),
									false
								)
							set_human_lane_role(gsiHuman, laneChosen, roleChosen)
							workingSet.topPrint[DRAW_I__EXPIRES] = 0
							workingSet.midPrint[DRAW_I__EXPIRES] = 0
							workingSet.botPrint[DRAW_I__EXPIRES] = 0
							return COMMUNICATION_QUESTIONNAIRE_END
						end
						--[[DEV]]print("LC", laneChosen)
						local recentPing = gsiHuman.hUnit:GetMostRecentPing()

						GetBot():ActionImmediate_Ping(recentPing.location.x,
								recentPing.location.y, false)
						if not Vector_Equal(recentPing.location, workingSet.previousPing.location)
								then
							roleChosen = LANE_ROLES[laneChosen][
									(Comm_YesFromKnownNewPing(recentPing.location) and 1 or 2)
								]
						end
						local recentChatText = gsiHuman.comms.mostRecentChatText
						if recentChatText ~= workingSet.previousChatText then
							local role = Comm_InterpretHumanRole(recentChatText)
							if role then
								roleChosen = role
							end
						end
						if roleChosen then
							workingSet.topPrint[DRAW_I__EXPIRES] = 0
							workingSet.botPrint[DRAW_I__EXPIRES] = 0
							set_human_lane_role(gsiHuman, laneChosen, roleChosen)
							return COMMUNICATION_QUESTION_END
						end
						return 3
					end,
					nil,
					nil,
					QSTN_LANE_ROLE_WAIT_ANSWER
				},
			}
		)
	Comm_RegisterCallbackFunc("PLAYER_ROLES",
			function(event)
				if not IsPlayerBot(event.player_id) then
					gsiHuman.comms.mostRecentChatText = event.string
				end
			end
		)
end
