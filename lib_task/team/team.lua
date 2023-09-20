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

TEAM_CAPTAIN_UNIT = TEAM_CAPTAIN_UNIT or GetBot()
TEAM_CAPTAIN_UNIT.Chat = Captain_Chat

local max = math.max
local min = math.min
local abs = math.abs
local sqrt = math.sqrt

local team_players
local enemy_players
local role_assignments
local player_disallowed_objective_targets
local buyback_directive

local t_present_or_committed = {} for i=1,3 do t_present_or_committed[i] = {} end -- state if pnot is at strategic lane

local t_prev_strategic_lane = {}

local zone_defend_handle
local fight_harass_handle

local ancient_on_ropes_fight_loc

local fort_attacked_urgency = 0

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
		thisPlayer.lane = Team_GetRoleBasedLane(thisPlayer) -- TODO ignores trilane
	end
	for i=1,TEAM_NUMBER_OF_PLAYERS do
		local thisPlayer = teamPlayers[i]
		local thisPlayerLane = thisPlayer.lane
		for k=1,TEAM_NUMBER_OF_PLAYERS do
			if teamPlayers[k] ~= thisPlayer
					and thisPlayerLane == teamPlayers[k].lane then
				thisPlayer.laningWith = teamPlayers[k]
				teamPlayers[k].laningWith = thisPlayer
			end
		end
		--print("DEDUCE", thisPlayer.shortName, thisPlayer.role, thisPlayer.lane, thisPlayer.laningWith)
	end
	
	Vibe_CreateAndAllocatePlayerVibes(GSI_GetTeamPlayers(TEAM))
end

function Team_GetRoleBasedLaneBuddy(gsiPlayer)
end

function Team_Initialize()
	team_players = GSI_GetTeamPlayers(TEAM)
	enemy_players = GSI_GetTeamPlayers(ENEMY_TEAM)
	player_disallowed_objective_targets = {}
	buyback_directive = {}
	for i=1,#team_players,1 do
		player_disallowed_objective_targets[i] = {}
	end

	zone_defend_handle = ZoneDefend_GetTaskHandle()
	fight_harass_handle = FightHarass_GetTaskHandle()

	ancient_on_ropes_fight_loc = Map_GetAncientOnRopesFightLocation(TEAM)
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

local prev_fort_health = 0
function Team_InformDeadTryBuyback(gsiPlayer)
	-- assumes dead
	for iLane=1,3 do
		t_present_or_committed[iLane][gsiPlayer.nOnTeam] = nil
	end
	local teamAncient = GSI_GetTeamAncient(TEAM)
	if not teamAncient then
		return;
	end
	local thisFortHealth = teamAncient.lastSeenHealth
	local fortHasDroppedHp = prev_fort_health > thisFortHealth
	prev_fort_health = thisFortHealth
	t_prev_strategic_lane[gsiPlayer.nOnTeam] = nil
	local team_players = team_players
	local netDanger = 0
	local aliveCount = 0
	if gsiPlayer.hUnit:HasBuyback()
			and gsiPlayer.hUnit:GetGold() > gsiPlayer.hUnit:GetBuybackCost()
			and gsiPlayer.hUnit:GetRespawnTime() > 5 then
		if buyback_directive[gsiPlayer.nOnTeam] then
			gsiPlayer.hUnit:ActionImmediate_Buyback()
			buyback_directive[gsiPlayer.nOnTeam] = false
		end
		if fortHasDroppedHp then
			local enemy_players = enemy_players
			for i=1,#enemy_players do
				local thisEnemy = enemy_players[i]
				if Vector_PointDistance(
							thisEnemy.lastSeen.location,
							teamAncient.lastSeen.location
							) < 1600
						and thisEnemy.hUnit:GetAttackTarget() == teamAncient.hUnit then
					gsiPlayer.hUnit:ActionImmediate_Buyback()
				end
			end
		end
		local stakes = false
		for i=1,#team_players do
			local thisPlayer = team_players[i]
			if thisPlayer.hUnit:IsAlive() then
				aliveCount = aliveCount + 1
				local playerTask = Task_GetCurrentTaskHandle(thisPlayer)
				stakes = (playerTask == zone_defend_handle and thisPlayer) -- simplistic, misses sometimes
						or stakes
						or playerTask == Blueprint_TaskHandleIsFighting()
				netDanger = netDanger + Analytics_GetTheoreticalDangerAmount(thisPlayer)
			end
		end
		if not stakes or (aliveCount > 0 and math.abs(netDanger) > 1.2*aliveCount) then
			return false
		end
		local defensible = stakes == true and false or select(2, ZoneDefend_AnyBuildingDefence()) -- assumes stakes is a hero if any defending
		defensible = defensible and defensible[POSTER_I.OBJECTIVE]
		if defensible and defensible.tier and defensible.tier > 1 then
			local distOfEnemy = select(2, Set_GetNearestEnemyHeroToLocation(defensible.lastSeen.location, 8))
			if distOfEnemy < 2400 then
					-- just as I write this, the fact that the bot will probably tp to any low
					-- -| danger farmable lane is an indication that that behavior needs to be
					-- -| fixed, not this working around it. TODO
				if defensible.isAncient
						and gsiPlayer.hUnit:GetRespawnTime() > 4 + distOfEnemy / 400 then
					Task_IncentiviseTask(gsiPlayer, fight_harass_handle, 80, 4)
					gsiPlayer.hUnit:ActionImmediate_Buyback() 
				end
				if not defensible.tier or not Item_TownPortalScrollCooldown(gsiPlayer) then
					ERROR_print(false, not DEBUG, "Found nils in TryBuyback (%s %s)", defensible.tier, Item_TownPortalScrollCooldown(gsiPlayer))
					return
				end
				if defensible.lastSeenHealth > 200
						and (defensible.tier >= 3 or Item_TownPortalScrollCooldown(gsiPlayer) == 0) then
					if gsiPlayer.hUnit:GetRespawnTime() > (5 - defensible.tier)*10 and RandomInt(1, max(16, (6 - defensible.tier)*100 / (gsiPlayer.hUnit:GetGold() - gsiPlayer.hUnit:GetBuybackCost()))) == 1 then
						Task_IncentiviseTask(gsiPlayer, fight_harass_handle, 80, 4)
						gsiPlayer.hUnit:ActionImmediate_Buyback()
					end
				end
			end
		end
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

function Team_GetLaneOfRoleNumberForTeam(roleNum, team)
	if roleNum == 1 or roleNum == 5 then 
		return team == TEAM_RADIANT and MAP_LOGICAL_BOTTOM_LANE or MAP_LOGICAL_TOP_LANE
	elseif roleNum == 3 or roleNum == 4 then
		return team == TEAM_RADIANT and MAP_LOGICAL_TOP_LANE or MAP_LOGICAL_BOTTOM_LANE
	else
		return MAP_LOGICAL_MIDDLE_LANE
	end
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

function Team_GetStrategicLane(gsiPlayer)
	local strategicLane = gsiPlayer.time.data.strategicLane
	if not strategicLane then
		if not IsPlayerBot(gsiPlayer.playerID) then
			if gsiPlayer.hUnit:IsAlive() then
				strategicLane = Map_GetLaneValueOfMapPoint(gsiPlayer.lastSeen.location)
			else
				strategicLane = gsiPlayer.lane
			end
		else
			local prevLane = t_prev_strategic_lane[gsiPlayer.nOnTeam]
			local roleHelpWeight = gsiPlayer.role/5
			local highestScore = -0xFFFF
			-- TODO Include game-lateness allocation, or is it a push task alone when trying to counter-push / take obj?
			-- - Should heroes locked to Push not try to achieve last hit timings? Why rely on farm lane only because
			-- - of convenience.
			local aliveAdvantage = 1 + GSI_GetAliveAdvantageFactor()
			local role = gsiPlayer.role
			for iLane=1,3 do
				local safety, helpNeededScore, pushingHasPressureScore, myFarmScore = Analytics_SafetyOfLaneFarm(gsiPlayer, iLane, t_present_or_committed[iLane])
				pushingHasPressureScore = max(1.5, min(0.75, safety/(role*0.66)))
						* pushingHasPressureScore * aliveAdvantage -- supports care more pushing when advtg
						* max(1, (6-role)-(6-role)*abs(safety)) -- cores help push if pressure is high but edging dangerous
				myFarmScore = myFarmScore / (0.452 + sqrt(0.3+aliveAdvantage)) -- cores care more solo farm when advtg
				local thisScore = (prevLane == iLane and 1.1 or 1)
						- min(1, abs(safety)) + pushingHasPressureScore + myFarmScore
				if thisScore < -0xFFFF then
					print("WOW", thisScore, min(1, abs(safety)), pushingHasPressureScore, myFarmScore)
				end
				if thisScore > highestScore then
					highestScore = thisScore
					strategicLane = iLane
					-- nothing is scaled in minute detail, but the factors are correctly placed. TODO TEST STRATEGIC LANE
				end
	
			end
		end
	--	DebugDrawText(370, 150+gsiPlayer.nOnTeam*8, string.format("%d-strat:%d-safe:%.1f", gsiPlayer.nOnTeam,
	--			strategicLane, gsiPlayer.time.data.safetyOfLane[strategicLane]), 255, 255, 255)
		gsiPlayer.time.data.strategicLane = strategicLane or prevLane or 2
		local pnot = gsiPlayer.nOnTeam
		t_present_or_committed[1][pnot] = nil
		t_present_or_committed[2][pnot] = nil
		t_present_or_committed[3][pnot] = nil
		t_present_or_committed[strategicLane][pnot] = gsiPlayer
--	else
--		DebugDrawText(370, 150+gsiPlayer.nOnTeam*8, string.format("%d-strat:%d-safe:%.1f", gsiPlayer.nOnTeam,
--				strategicLane, gsiPlayer.time.data.safetyOfLane[strategicLane]), 255, 255, 255)
		t_prev_strategic_lane[gsiPlayer.nOnTeam] = strategicLane
	end
	return strategicLane
end

function Team_GetRoleBasedGreedRating(thisPlayer)
	return 1.0 - (role_assignments[thisPlayer.nOnTeam] and (role_assignments[thisPlayer.nOnTeam]-1) / MAX_ROLE_TYPES or 0.5)
end

function Team_FortUnderAttack(gsiUnit)
	local doCheapAssBuybacks = false
	
	if GSI_CountTeamAlive(TEAM) == 0 then
		doCheapAssBuybacks = true
	else
		doCheapAssBuybacks = false
		local defenders = Set_GetAlliedHeroesInLocRad(nil, ancient_on_ropes_fight_loc, 4000)
		local attackers = Set_GetEnemyHeroesInLocRadOuter(ancient_on_ropes_fight_loc, 5000, 5000, 10)
		local defensivePower = Analytics_GetTheoreticalEncounterPower(
				defenders,
				ancient_on_ropes_fight_loc,
				2500, 4000
			)
		local offensivePower = Analytics_GetTheoreticalEncounterPower(
				attackers,
				ancient_on_ropes_fight_loc,
				3000, 5000
			)
		if offensivePower / defensivePower < 2 then
			doCheapAssBuybacks = true
		end
	end
	if doCheapAssBuybacks then
		for i=1,#team_players do
			local hUnitAllied = team_players[i].hUnit
			if hUnitAllied:IsBot() and not hUnitAllied:IsAlive()
					and hUnitAllied:HasBuyback()
					and hUnitAllied:GetBuybackCost() < hUnitAllied:GetGold() then
				if not buyback_directive[i] then
					buyback_directive[i] = true
				end
				break;
			end
		end
	end
	local fortHpp = GSI_GetTeamAncient(TEAM)
	fortHpp = fortHpp.lastSeenHealth / fortHpp.maxHealth
	local fortDefBaseScore = (1 - fortHpp^2) * 1000
	for i=1,#team_players do
		local thisAllied = team_players[i]
		local distToFort = Vector_PointDistance2D(thisAllied.lastSeen.location, ancient_on_ropes_fight_loc)
		local distScoreFactor = max(0.33, min(1, 1.99 - 0.00066*distToFort))
		local score = distScoreFactor * fortDefBaseScore
		local decrement = score / 8
		
		Task_IncentiviseTask(team_players[i], fight_harass_handle, score, decrement)
		Task_IncentiviseTask(team_players[i], UseItem_GetTaskHandle(), score, decrement)
		Task_IncentiviseTask(team_players[i], UseAbility_GetTaskHandle(), score, decrement)
	end
end

require(GetScriptDirectory().."/lib_hero/vibe")
require(GetScriptDirectory().."/lib_analytics/xeta")
require(GetScriptDirectory().."/lib_task/task")
require(GetScriptDirectory().."/lib_hero/hero")
require(GetScriptDirectory().."/lib_task/team/wanted_poster")
require(GetScriptDirectory().."/lib_task/blueprint/blueprint_main")
require(GetScriptDirectory().."/lib_hero/ability_think_main")
