TEAM_CAPTAIN_UNIT = TEAM_CAPTAIN_UNIT or GetBot()
TEAM_CAPTAIN_UNIT.Chat = Captain_Chat

require(GetScriptDirectory().."/lib_hero/vibe")
require(GetScriptDirectory().."/lib_analytics/xeta")
require(GetScriptDirectory().."/lib_task/task")
require(GetScriptDirectory().."/lib_hero/hero")
require(GetScriptDirectory().."/lib_task/team/wanted_poster")
require(GetScriptDirectory().."/lib_task/blueprint/blueprint_main")
require(GetScriptDirectory().."/lib_hero/ability_think_main")

local max = math.max
local min = math.min
local abs = math.abs

local team_players
local role_assignments
local player_disallowed_objective_targets
local buyback_directive

local function check_human_indicating_lane_choice(hUnitHuman)
	local loc = hUnitHuman.hUnit:GetLocation()
end

function Team_CreateDeduceHumanRoleAndLane(hUnitHuman)
	local captain_job_domain = Captain_GetCaptainJobDomain()
	local hUnitHuman = hUnitHuman
	captain_job_domain:RegisterJob(
			function(workingSet)
			
			end,
			{},
			"JOB_DEDUCE_HUMAN_ROLE_AND_LANE"
		)
end

-- Called ideally once per team (called additional times if there's any reason for a role/lane switch in the early laning stage)
	-- tblsOfChoices: a table of choice tables, the first element of each is the choice. {1, 1, 2, 3, 4, 5}, .., {4, 4, 5}, {5, 5}. The next iteration of that example ends with .., {5, 4, 5}, {4, 4}. A sequenced elimination of each choice
local function brute_best_team_roles(heroPreferences)
	local CHOICE_NOT_MADE = -0xFF
	local ROLE = HERO_PREFERENCE_I__ROLE
	local highestScore = 0.0
	local highestScoreOrder = {}
	--print("Printing hero preferences...")
--	for i=1,5 do
--		print("\t"..i)
--		for j=1,5 do
--			print("\t\t"..i.." "..(heroPreferences[i][2][j] or 'nil'))
--		end
--	end
	-------------- recurse()
	local function recurse(tblsOfChoices, cumulativeScore, depth)
		-- // print //
		if TEST then
			local depth_tabs = {}
			for t=1, depth do
				depth_tabs[t] = "\t"
			end
			local depth_str = table.concat(depth_tabs)
			--print(string.format("%s%d: %d -- %.2f", depth_str, depth, tblsOfChoices[depth].chosen, heroPreferences[depth][ROLE][tblsOfChoices[depth].chosen] or 0.0))
		end
		-- // \print //
		if #heroPreferences == depth then -- Ending, checking if score was higher
			local finalChoice = tblsOfChoices[depth][1] -- Only 1 to choose at final depth
			tblsOfChoices[depth].chosen = finalChoice
			
			local thisRoleOrderScore = cumulativeScore + (heroPreferences[depth][ROLE][finalChoice] or 0.0)
			
			if thisRoleOrderScore > highestScore then 
				highestScore = thisRoleOrderScore
				--print(string.format("New High Score: %.2f", highestScore, ":"))
				for r=1,depth,1 do
					highestScoreOrder[r] = tblsOfChoices[r].chosen
					--print(string.format("\t%d: %d", r, highestScoreOrder[r]))
				end
			end
		else -- Making choice for depth'st choice, setting next sequence's choice table's choice values, stepping to f(depth+1)
			local thisDepthChoiceTable = tblsOfChoices[depth]
			for i=1,#thisDepthChoiceTable,1 do
				thisDepthChoiceTable.chosen = thisDepthChoiceTable[i]
				for j=1,#thisDepthChoiceTable,1 do
					if j ~= i then -- Copy the choices to the next table, without the value that thisDepthChoiceTable chose. (.'. the table size is reduced by one)
						tblsOfChoices[depth+1][j+(j>i and -1 or 0)] = thisDepthChoiceTable[j]
					end
				end
				recurse(tblsOfChoices, cumulativeScore+(heroPreferences[depth][ROLE][thisDepthChoiceTable.chosen] or 0.0), depth+1)
			end
		end
	end
	
	local tblsOfChoices = {}	
	for i=1,#heroPreferences,1 do -- allocate the choice tables, and create the first of the choice sequence tables
		tblsOfChoices[i] = {} -- 
		tblsOfChoices[i].chosen = CHOICE_NOT_MADE
		tblsOfChoices[1][i] = i -- The first of the choice sequence tables
	end
	recurse(tblsOfChoices, 0.0, 1) -- highestScoreOrder will be set
	return highestScoreOrder
end

local function simplistic_or_enemy_predicted_lanes()
	local tableOfRoleAssignments = {}
	local tableOfRoleAssignmentsByPID = {} -- used to check for any previous assignments
	local heroPreferences = Hero_GetAllHeroAssignementScores()

	for i=1,MAX_ROLE_TYPES,1 do
		local ordreredHeroAndScoreForRole = Hero_GetOrderedHeroAndScoreForRole(i)
		
		for j=1,#ordreredHeroAndScoreForRole,1 do
			local thisOrderedplayerID = orderedHeroAndScoreForRole[ROLE_SCORES_ORDERED_I__PID]
			if not tableOfRoleAssignmentsByPID[thisOrderedplayerID] then
				tableOfRoleAssignments[i] = orderedHeroAndScoreForRole
				tableOfRoleAssignmentsByPID[thisOrderedplayerID] = orderedHeroAndScoreForRole
			end
		end
	end
end

local function lane_shuffle_for_highest_scoring()

end

-- todo: apply a temporary basic-layout state of role and lane slots, then shuffle them into higher values
function DeduceBestRolesAndLanes()
	humanPlayers = GSI_GetTeamHumans(TEAM)
	for i=1,#humanPlayers,1 do
		check_human_indicating_lane_choice(humanPlayers[i])
	end
	
	role_assignments = brute_best_team_roles(Hero_GetTeamHeroAssignmentScores(TEAM))
	
	local teamPlayers = GSI_GetTeamPlayers(TEAM)
	for i=1, TEAM_NUMBER_OF_PLAYERS do
		local thisPlayer = teamPlayers[i]
		thisPlayer.role = role_assignments[i]
		local thisPlayerLane = Team_GetRoleBasedLane(thisPlayer) -- TODO ignores trilane
		thisPlayer.lane = thisPlayerLane
		for k=1,TEAM_NUMBER_OF_PLAYERS do
			if thisPlayerLane == teamPlayers[k].lane then
				thisPlayer.laningWith = teamPlayers[k]
				teamPlayers[k].laningWith = thisPlayer
			end
		end
	end
	
	Vibe_CreateAndAllocatePlayerVibes(GSI_GetTeamPlayers(TEAM))
end

function Team_GetRoleBasedLaneBuddy(gsiPlayer)
end

function Team_Initialize()
	team_players = GSI_GetTeamPlayers(TEAM)
	player_disallowed_objective_targets = {}
	buyback_directive = {}
	for i=1,#team_players,1 do
		player_disallowed_objective_targets[i] = {}
	end
end

function Team_AmITheCaptain(thisBot)
	if (thisBot.playerID or thisBot.hUnit:GetPlayerID()) == TEAM_CAPTAIN_UNIT:GetPlayerID() then
		return true
	end
	return false
end

function Team_GetRole(thisBot)
	return role_assignments[thisBot.nOnTeam]
end

function Team_CheckBuybackDirective(thisBot)
	if buyback_directive[thisBot.nOnTeam] then
		thisBot.hUnit:ActionImmedaite_Buyback()
	end
end

function Team_RegisterClearForLaunchHero(gsiPlayer)
	-- yes
end

-- if launch is false, but we have a hero, cast buffs, ink swell, abaddon shield, omni
-- -| protection, linken sphere, lotus orb, warlock heal, oracle pop, surge, frost
-- -| shield, tiny walk to the unit if they don't have a blink, and throw this mf in.
-- -| If the unit is a human, kindly inform them two-ability function frames before
-- -| throw (0.4s). "Godspeed, soldier." Also works whenever an ally has a force staff
-- -| Use via analytics about enemy formation, i.e. when you can't pick one target out.
-- -| "If you don't want us to do that again type '-nothrow' in chat."
-- - Maybe even "Can we throw you in as initiation?" "y / yes / sure / [ping radiant side
-- -| of the map / [ping preferred hero (this would be fun for tilted players to kill
-- -| their supports)]] / no: check if any other target is ideal"
function Team_GetClearForLaunchHero(gsiPlayer)
	-- if me check GameTime() > expire clear for launch
	-- return hero, isMe, launch
end

function Team_GetRoleBasedLane(thisPlayer) -- TODO Is there any way to determine the enemy bot names for lane predictions before they show on map? -a Yes, names are queryable.
	local thisPlayerRole = role_assignments[thisPlayer.nOnTeam]
	if thisPlayerRole == 1 or thisPlayerRole == 5 then 
		return thisPlayer.team == TEAM_RADIANT and MAP_LOGICAL_BOTTOM_LANE or MAP_LOGICAL_TOP_LANE
	elseif thisPlayerRole == 3 or thisPlayerRole == 4 then
		return thisPlayer.team == TEAM_RADIANT and MAP_LOGICAL_TOP_LANE or MAP_LOGICAL_BOTTOM_LANE
	else
		return MAP_LOGICAL_MIDDLE_LANE
	end
end

local t_present_or_committed = {} for i=1,3 do t_present_or_committed[i] = {} end
function Team_GetStrategicLane(gsiPlayer)
	local strategicLane = gsiPlayer.time.data.strategicLane
	if not strategicLane then
		local roleHelpWeight = (1 - gsiPlayer.role/5)
		local highestScore = -0xFFFF
		-- writing this bugged for core lane selection, then fixing it later after POC
		-- TODO Include game-lateness allocation, or is it a push task alone when trying to counter-push / take obj?
		-- - Should heroes locked to Push not try to achieve last hit timings? Why rely on farm lane only because
		-- - of convenience.
		for iLane=1,3 do
			local safety, helpNeededScore = Analytics_SafetyOfLaneFarm(gsiPlayer, iLane, t_present_or_committed[iLane])
			local thisScore = 1 - min(1, abs(safety)) + helpNeededScore*roleHelpWeight
			if thisScore > highestScore then
				highestScore = thisScore
				strategicLane = iLane
				-- nothing is scaled in minute detail, but the factors are correctly placed. TODO TEST STRATEGIC LANE
			end
		end
	--	DebugDrawText(370, 150+gsiPlayer.nOnTeam*8, string.format("%d-strat:%d-safe:%.1f", gsiPlayer.nOnTeam,
	--			strategicLane, gsiPlayer.time.data.safetyOfLane[strategicLane]), 255, 255, 255)
		gsiPlayer.time.data.strategicLane = strategicLane
		t_present_or_committed[strategicLane][gsiPlayer.nOnTeam] = gsiPlayer
--	else
--		DebugDrawText(370, 150+gsiPlayer.nOnTeam*8, string.format("%d-strat:%d-safe:%.1f", gsiPlayer.nOnTeam,
--				strategicLane, gsiPlayer.time.data.safetyOfLane[strategicLane]), 255, 255, 255)
	end
	return strategicLane
end

function Team_GetRoleBasedGreedRating(thisPlayer)
	return 1.0 - (role_assignments[thisPlayer.nOnTeam] and (role_assignments[thisPlayer.nOnTeam]-1) / MAX_ROLE_TYPES or 0.5)
end
--[[ MicroThink() implemented in bot_generic as Think() = MicroThink() ]]--
