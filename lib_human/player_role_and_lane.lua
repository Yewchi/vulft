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

local STR__ROLE_LANE_SET = "@%s: set you to %s, %s %s"
RegisterLocalize(STR__ROLE_LANE_SET,
		"zh", "@%s: 我们已将您分配到 %s，%s %s",
		"ru", "@%s: Хорошо, мы поставили вас на %s, %s %s"
	)
local STR__SET_LANE_INSTRUCTIONS = "To set your lane, ping the map, we have placed you: "..
		"'pos %s' in '%s' (%s meta). If roam/jungle, keep default."
RegisterLocalize(STR__SET_LANE_INSTRUCTIONS,
		"zh", "要设置你的车道，标记小地图烟花地图，我们已将你放置在：'%s'中的数字'角色%s' (%s)。 如果漫游/丛林，保持默认。",
		"ru", "Чтобы установить свою полосу, пропингуйте карту, мы поместили вас в: "..
				"'позиция %s' в '%s' (мета %s). Если роумер/джунгли, оставьте по умолчанию."
	)
local STR__ROLE_SET_SHORT = "Roles are set."
RegisterLocalize(STR__ROLE_SET_SHORT,
		"zh", "角色现已设定",
		"ru", "позиция установлено."
	)
local STR__PRE_SET = "Setting you to %s.. now ping your role (top for pos%s, bot for pos%s)"
RegisterLocalize(STR__PRE_SET,
		"zh", "将你设置为 %s.. 现在 ping 你的角色（顶部路径为 数字%s，底部路径为 数字%s）",
		"ru", "Установка вас на %s.. теперь пингуйте вашу роль (верхняя строка для позиция%d, нижняя "..
				"строка для позиция%d)"
	)
local STR__ASSUME_ROLE = ":| assuming player is %s in %s: pos %d"
RegisterLocalize(STR__ASSUME_ROLE,
		"zh", ":| 因为你没有回应，我会假设玩家是 %s 在 %s: 数字%s。"..
				"这是最近排名靠前的游戏最有可能的分配（这些在VULFT更新的数据文件中，不是来自互联网）",
		"ru", ":| Из-за того, что я не получил ответа, я предполагаю, что игрок %s в %s - это номер %s."..
				"Это наиболее вероятное место назначения самых последних игр с самым высоким рейтингом "..
				"из местных данных VULFT."
	)

local function set_human_lane_role(gsiHuman, lane, role)
	Hero_HardSetRole(gsiHuman, role)
	Hero_HardSetLane(gsiHuman, lane)
	gsiHuman.hardSetRole = role
	DeduceBestRolesAndLanes()
	Captain_AddChatToQueue(string.format(GetLocalize(STR__ROLE_LANE_SET),
					gsiHuman.shortName,
					GetLocalize(COMM.READABLE_ROLE_LANE[lane]),
					GetLocalize("pos"), GetLocalize(role)
				), false, 0.3
		)

	Captain_ConfigIndicateNonStandardSetting(CAPTAIN_CONFIG_NON_STANDARD.LANE_AND_ROLE)
end

Comm_RegisterCallbackFunc("PROCESS_CMD_ROLE_OR_POS",
		function(event, cmd)
			if IsPlayerBot(event.player_id) then
				return;
			end
			print("role or pos", cmd == "role", cmd == "pos", cmd == GetLocalize("role")
				, cmd == GetLocalize("pos"))
			if cmd == "role" or cmd == "pos" or cmd == GetLocalize("role")
					or cmd == GetLocalize("pos") then -- Synonymous unknown language cmd foot gun. [[TODO]]
				local gsiChattingHuman = GSI_GetPlayerFromPlayerID(event.player_id)
				local args = String_GetArgumentTable(event.string)

				Util_TablePrint(args)
				
				local role = Comm_InterpretHumanRole(args[2])
				print(role)
				if gsiChattingHuman and role then
					local lane = Team_GetLaneOfRoleNumberForTeam(role, gsiChattingHuman.team)
					print(lane)
					if lane then
						set_human_lane_role(gsiChattingHuman, lane, role)
					end
				end
				return (cmd == "role" or cmd == "pos") and "KILL" or nil -- ... shifting the foot
			end
		end,
		true
	)

local STR__PING_MAP_SELECT_NA = "Multiple humans are on your team so role selection by pinging the map is not available. This may be fixed in a future update."
RegisterLocalize(STR__PING_MAP_SELECT_NA,
		"zh", "您的团队中有多个人，因此您不能使用 ping 来选择角色类型。 这可能会在未来的更新中得到修复。",
		"ru", "В вашей команде несколько игроков-людей, поэтому выбор роли с помощью пинга недоступен. Это может быть исправлено в будущем обновлении."
	)
local STR__SELECT_ROLE_ANYTIME = "To select your role at any time, type \"!%s [1 to 5]\""
RegisterLocalize(STR__SELECT_ROLE_ANYTIME,
		"zh", "要随时选择您的角色，请键入 \"!%s [1 到 5]\"",
		"ru", "Чтобы выбрать свою позиция в любое время, введите \"!%s [от 1 до 5]\""
	)

PLAYER_ROLE_AND_LANE.DoLaneChoice = function(jobDomain, gsiHuman)
	WARN_print(string.format("ahh, a human! And with playerID=%d.", gsiHuman.playerID))
	local check_chat = function(event)
		
	end
	local defaultLane = Team_GetRoleBasedLane(gsiHuman)

	local laneChosen
	local roleChosen

	local teamHumans = GSI_GetTeamHumans(TEAM)
	if #teamHumans > 1 then
		Captain_AddChatToQueue(GetLocalize(STR__PING_MAP_SELECT_NA), false, 1)
		Captain_AddChatToQueue(
				string.format(GetLocalize(STR__SELECT_ROLE_ANYTIME),
					GetLocalize("pos")
				), false, 1
			)
		return;
	end

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

						Captain_Chat(string.format(GetLocalize(STR__SET_LANE_INSTRUCTIONS), 
									GetLocalize(gsiHuman.role),
									GetLocalize(COMM.READABLE_LANE[Team_GetRoleBasedLane(gsiHuman)]),
									META_DATE
								), false
							)
						return 2
					end,
					nil,
					nil,
					QSTN_LANE_ROLE_DELAY_START_GAME
				},
				[2] = {
					nil,
					function(workingSet) 
						Util_TablePrint(gsiHuman.comms.mostRecentPing)
						if workingSet.expired then
							local talk = RandomFloat(1,33)
							GetBot():ActionImmediate_Chat(talk < 1.0 and "lets spagettit"
									or string.format(GetLocalize(STR__ROLE_SET_SHORT)), false
								)
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
										GetLocalize(STR__PRE_SET),
										GetLocalize(COMM.READABLE_LANE[laneChosen]),
										GetLocalize(roleChoice1), GetLocalize(roleChoice2)
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
							Captain_Chat(string.format(GetLocalize(STR__ASSUME_ROLE),
										isClosestToKnown and "expected role" or "default",
										GetLocalize(COMM.READABLE_ROLE_LANE[laneChosen]),
										GetLocalize(roleChosen)
									),
									false
								)
							set_human_lane_role(gsiHuman, laneChosen, roleChosen)
							workingSet.topPrint[DRAW_I__EXPIRES] = 0
							workingSet.midPrint[DRAW_I__EXPIRES] = 0
							workingSet.botPrint[DRAW_I__EXPIRES] = 0
							return COMMUNICATION_QUESTIONNAIRE_END
						end
						
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
