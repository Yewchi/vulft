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

-- Keep a bounty rune spawning soon safe, do not allow an enemy to steal a power rune.

local TEMP_WP_EXPIRY_TIME = 20

local task_handle = Task_CreateNewTask()

local update_priority_throttle = 2.689

local TPSCROLL_COST = GetItemCost("item_tpscroll")

local avoid_hide_handle
local avoid_hide_run
local fight_harass_handle
local fight_harass_run
local push_handle
local GET_TASK_OBJ = Task_GetTaskObjective
local GET_TASK_SCORE = Task_GetTaskScore
local MINIMUM_ALLOWED_USE_TP_INSTEAD = MINIMUM_ALLOWED_USE_TP_INSTEAD
local TPSCROLL_CD = ITEM_COOLDOWN["item_tpscroll"]
local TEAM_NUMBER_OF_PLAYERS = TEAM_NUMBER_OF_PLAYERS
local max = math.max
local min = math.min

local DEBUG = DEBUG
local VERBOSE = VERBOSE
local TEST = TEST

local any_defence_considerable = false

local t_team_players

local t_wp_stored = {}

local blueprint

local CONSIDER_ACTIVE_DEFENDER_RANGE = 1200

-- TODO LAZY DATA STRUCTURING

local function update_score_task_priority__job(workingSet)
	
end

local function estimated_time_til_completed(gsiPlayer, objective)
	return 8 -- don't care
end

function ZoneDefend_AnyBuildingDefence()
	-- TODO
	return t_wp_stored[1] and true, t_wp_stored[1]
end

-- ALL CODE BELOW IS PROOF OF WP DEFENCE CONCEPT -- COMPLETELY TRASH AND RESTRICTIVE TEST CODE

local function check_building_defence_end(building)
	local nearbyEnemies, outerEnemies = Set_GetEnemyHeroesInPlayerRadiusAndOuter(building.lastSeen.location, 900, 1600, 2.5)
	--DebugDrawText(400+building.lastSeen.location.x/200, 800+building.lastSeen.location.y/200, string.format("poster %d - %d ls: %f", #nearbyEnemies, #outerEnemies, (nearbyEnemies[1] and GameTime() - nearbyEnemies[1].lastSeen.timeStamp or outerEnemies[1] and GameTime() - outerEnemies[1].lastSeen.timeStamp or -1)), 255, 255, 255)
	if not building.wp then
		ERROR_print(true, not DEBUG, "[zone_defend] check_buildling_defence_end(%s) -- building is not being defended or building has not been updated.", Util_ParamString(building))
		for i=1,#t_wp_stored do
			local wp = t_wp_stored[i]
			if wp and wp[POSTER_I__OBJECTIVE]
					and wp[POSTER_I__OBJECTIVE].hUnit == building.hUnit then
				WP_BurnPoster(table.remove(t_wp_stored, i))
				i = i-1
			end
		end
		WP_BurnPoster(building.wp)
		return true;
	end
	if building.typeIsNone or (#nearbyEnemies == 0 and #outerEnemies*2 <= 1
			and (not building.wpExpiryTime or building.wpExpiryTime < DotaTime())) then
		for i=1,#t_wp_stored do
			if t_wp_stored[i] == building.wp then
				table.remove(t_wp_stored, i)
			end
		end
		WP_BurnPoster(building.wp)
		building.wp = nil
		building.wpExpiryTime = nil
		return true
	end
	return false
end

local function score_building_defence(gsiPlayer, objective, forTaskComparison)
	local tpScroll = gsiPlayer.hUnit:GetItemInSlot(TPSCROLL_SLOT)
	local portArriveTime = tpScroll and tpScroll:GetCooldownTimeRemaining() + 4 or TPSCROLL_CD
	local distToBuildingAtPort = Math_PointToPointDistance2D(gsiPlayer.lastSeen.location, objective.lastSeen.location)
	local portIsLikely = distToBuildingAtPort - gsiPlayer.currentMovementSpeed*portArriveTime > MINIMUM_ALLOWED_USE_TP_INSTEAD
	local costOfTravel = 2*Xeta_CostOfWaitingSeconds(
				gsiPlayer,
				portIsLikely and portArriveTime or Math_ETA(gsiPlayer, objective.lastSeen.location)
			) + (portIsLikely and TPSCROLL_COST*1.1 or 0)
	local lostTowerCost = (objective.goldBounty or 500)/3
	local freedomWhileDefending = forTaskComparison -- Decrement score when you're close, go nuts. x <= 0
			and min(-CONSIDER_ACTIVE_DEFENDER_RANGE
				+ distToBuildingAtPort*gsiPlayer.lastSeenHealth/gsiPlayer.maxHealth, 0)*3
				or 0
	local freedomWhileIntercepted = -0
	if VERBOSE then print("/VUL-FT/ <VERBOSE> [zone_defend]", gsiPlayer.shortName, "DEF", lostTowerCost - 1.5*costOfTravel + freedomWhileDefending + freedomWhileIntercepted, lostTowerCost, 1.5*costOfTravel, freedomWhileDefending, freedomWhileIntercepted) end
	--print("freedom is", freedomWhileDefending)
	return lostTowerCost - 1.5*costOfTravel + freedomWhileDefending + freedomWhileIntercepted
end

local function get_defence_required_power_level(building, pressure)
	if VERBOSE then print("/VUL-FT/ POWER LEVEL REQ: ", Analytics_GetTheoreticalEncounterPower(GSI_GetTeamPlayers(ENEMY_TEAM), building.lastSeen.location, 2000, 4000)) end
	return Analytics_GetTheoreticalEncounterPower(GSI_GetTeamPlayers(ENEMY_TEAM), building.lastSeen.location, 2000, 6000)
end

function ZoneDefend_RegisterBuildingDefenceSafe(building, pressure)
	building.wpExpiryTime = 0
	check_building_defence_end(building)
end

local DISALLOW_REAGGRO_FROM_TOWER_TIME = 6
function ZoneDefend_TakeCreepAggroTowerToHeroDownLane(gsiPlayer, objective)
	if VERBOSE then print("/VUL-FT/", gsiPlayer.shortName, "take creep agro", objective.lane) end
	if not objective.lane then return false end
	local enemyCreeps = Set_GetEnemyCreepSetLaneFront(objective.lane)
	local alliedCreeps = Set_GetAlliedCreepSetLaneFront(objective.lane)
	if not enemyCreeps or Math_PointToPointDistance(gsiPlayer.lastSeen.location, enemyCreeps.center) > 1400
			or (alliedCreeps
				and Math_PointToPointDistance(enemyCreeps.center, alliedCreeps.center) < 750
			) then
		if VERBOSE then print("/VUL-FT/ Creep setup failed deaggro from tower", gsiPlayer.shortName) end
		return false
	end
	local distToSet = Math_PointToPointDistance2D(gsiPlayer.lastSeen.location, objective.lastSeen.location)
	local currDanger = gsiPlayer.time.data.theorizedDanger or Analytics_GetTheoreticalDangerAmount(gsiPlayer)
	local attackTarget = gsiPlayer.hUnit:GetAttackTarget()
	local actionType = gsiPlayer.hUnit:GetCurrentActionType()
	if (GSI_UnitCanStartAttack(gsiPlayer)
				or (attackTarget and attackTarget:IsCreep() and attackTarget:GetTeam() ~= TEAM)
			) and distToSet < gsiPlayer.attackRange + (-currDanger*300) then
		local pullUnit = Set_GetSetUnitNearestToLocation(gsiPlayer.lastSeen.location, enemyCreeps)
		if pullUnit and pullUnit.creepType ~= CREEP_TYPE_SIEGE then
			if Analytics_AttacksWho(pullUnit.hUnit) == gsiPlayer.hUnit then
				return false
			end
			
			gsiPlayer.hUnit:Action_AttackUnit(pullUnit.hUnit, true)
			return true
		end
	end
	return false
end

function ZoneDefend_RegisterBuildingDefenceBlip(building, pressure)
	-- TODO SIMPLISTIC -- IMPROVE
	if not building.wp then
		GetBot():ActionImmediate_Ping(building.lastSeen.location.x, building.lastSeen.location.y, building.isShrine)
		--print(building, "MAKING")
		local thisWp = WP_Register(
					WP_POSTER_TYPES.BUILDING_DEFENCE,
					task_handle,
					building,
					building.lastSeen.location,
					score_building_defence,
					nil,
					get_defence_required_power_level(building, pressure),
					1.1 + 0.1*(TOTAL_BARRACKS_TEAM - NUM_BARRACKS_UP_TEAM)
							+ 0.025*(TOTAL_TOWERS_TEAM - NUM_TOWERS_UP_TEAM)
				)
		building.wpExpiryTime = DotaTime() + 12
		table.insert(t_wp_stored, thisWp)
		building.wp = thisWp
		any_defence_considerable = true
	end
end

local function task_init_func(taskJobDomain)
	Blueprint_RegisterTaskName(task_handle, "zone_defend")
	if VERBOSE then VEBUG_print(string.format("zone_defend: Initialized with handle #%d.", task_handle)) end
	avoid_hide_handle = AvoidHide_GetTaskHandle()
	avoid_hide_run = Task_GetTaskRunFunc(avoid_hide_handle)
	fight_harass_handle = FightHarass_GetTaskHandle()
	fight_harass_run = Task_GetTaskRunFunc(fight_harass_handle)
	push_handle = Push_GetTaskHandle()
	push_run = Task_GetTaskRunFunc(push_handle)

	t_team_players = GSI_GetTeamPlayers(TEAM)

	Task_RegisterTask(task_handle, PLAYERS_ALL, blueprint.run, blueprint.score, blueprint.init)
	taskJobDomain:RegisterJob(
			function(workingSet)
				if workingSet.throttle:allowed() then
					Task_SetTaskPriority(task_handle, PLAYERS_ALL, TASK_PRIORITY_TOP)
				end
			end,
			{["throttle"] = Time_CreateThrottle(update_priority_throttle)},
			"JOB_TASK_SCORING_PRIORITY_FIGHT_ZONE_CAPTURE"
		)
	Blueprint_RegisterTaskActivityType(task_handle, ACTIVITY_TYPE["COLLECTING"])
	task_init_func = nil
	return task_handle, estimated_time_til_completed
end
Blueprint_RegisterTask(task_init_func)

blueprint = {
	run = function(gsiPlayer, objective, xetaScore, forceRun)
		local wpForBotTask = not forceRun and WP_GetPlayerTaskPoster(gsiPlayer, task_handle)
		if not (forceRun or wpForBotTask) then
			Blueprint_RegisterCustomActivityType(gsiPlayer, ACTIVITY_TYPE.CONTROLLED_AGGRESSION)
			return XETA_SCORE_DO_NOT_RUN;
		end
		local wpObjective = wpForBotTask and wpForBotTask[POSTER_I.OBJECTIVE]
		local fightIncentive = -Analytics_GetTheoreticalDangerAmount(gsiPlayer, nil, objective.lastSeen.location)*20
		-- TODO zone_defend needs to be 2nd highest to ensure graceful flip, and same activity type
		-- -- better solution is probably a strong hook to FH.run().
		Task_IncentiviseTask(gsiPlayer, fight_harass_handle, fightIncentive, fightIncentive/10)
		local distToObjective = Math_PointToPointDistance2D(gsiPlayer.lastSeen.location, objective.lastSeen.location) 
		local nearbyEnemies = Set_GetEnemyHeroesInPlayerRadius(gsiPlayer, 1800)
		if distToObjective < 1400 or nearbyEnemies[1] then
			if VERBOSE then INFO_print(string.format("[zone_defend] %s sees nearbyEnemies[1] '%s'.",
							gsiPlayer.shortName,
							nearbyEnemies[1] and nearbyEnemies[1].shortName or "nil"
						)
				) end
			if not nearbyEnemies[1] then
				-- Attack nearby creeps when no nearby enemies
				local nearbyCreeps = gsiPlayer.hUnit:GetNearbyCreeps(1300, true)
				if VERBOSE then INFO_print(string.format("[zone_defend] %s sees nearbyCreeps[1] '%s'.",
								gsiPlayer.shortName,
								nearbyCreeps[1] and nearbyCreeps[1]:GetUnitName() or "nil"
							)
					) end
				if nearbyCreeps and nearbyCreeps[1] then
					Blueprint_RegisterCustomActivityType(gsiPlayer, ACTIVITY_TYPE.CAREFUL)
					push_run(gsiPlayer, cUnit_NewSafeUnit(nearbyCreeps[1]), xetaScore)
					return xetaScore;
				end
			elseif wpForBotTask then
				if FightClimate_AnyIntentToHarm(gsiPlayer, nearbyEnemies) then
					-- TODO simplistic, check fight power
					wpForBotTask.skipWaitWhileFightingExpiry = GameTime() + 3
				end
			end
			-- Pull creeps off tower if viable.
			if not forceRun and ZoneDefend_TakeCreepAggroTowerToHeroDownLane(gsiPlayer, wpObjective) then
				Blueprint_RegisterCustomActivityType(gsiPlayer, ACTIVITY_TYPE.CAREFUL)
				if VERBOSE then print("/VUL-FT/", gsiPlayer.shortName, "checking for creep aggro switch off tower") end
				return xetaScore;
			end
			local avoidHideScore = GET_TASK_SCORE(gsiPlayer, avoid_hide_handle)
			local fightHarassScore = GET_TASK_SCORE(gsiPlayer, fight_harass_handle)
			--print(gsiPlayer.shortName, avoidHideScore, fightHarassScore)
			if avoidHideScore > fightHarassScore and (not forceRun or #nearbyEnemies > 0) then
				if VERBOSE then print("/VUL-FT/", gsiPlayer.shortName, "running avoid hide in zone defend") end
				Blueprint_RegisterCustomActivityType(gsiPlayer, ACTIVITY_TYPE.CAREFUL)
				avoid_hide_run(gsiPlayer, gsiPlayer, avoidHideScore, true)
				--if DEBUG then DebugDrawText(1600, 200, string.format("ZoneDefend->AvoidHide; %s", avoidHideScore), 255, 255, 255) end
			else
				if wpForBotTask then
					-- Defend according to poster
					local commitTypes = wpForBotTask[POSTER_I.COMMIT_TYPES]
					local towerHpp = wpObjective.lastSeenHealth / wpObjective.maxHealth
					local towerNearFutureHealth = Analytics_GetNearFutureHealth(wpObjective)
					if towerNearFutureHealth / wpObjective.maxHealth > 0.33
							and (not wpForBotTask.skipWaitWhileFightingExpiry
									or GameTime() > wpForBotTask.skipWaitWhileFightingExpiry -- 'or the bot was not recently under attack'
								) then
						-- only avoid while waiting for incoming defenders unless soon destroyed
						for i=1,TEAM_NUMBER_OF_PLAYERS do
							local thisPlayer = t_team_players[i]
							if WP_CommitIsCommit(thisPlayer, wpForBotTask)
									and (Vector_UnitFacingUnit(thisPlayer, wpObjective) 
											or Unit_GetHealthPercent(thisPlayer) > 0.7
									) and Vector_PointDistance(
											thisPlayer.lastSeen.location,
											wpObjective.lastSeen.location
										) > 1600 + 4000 * towerHpp then
								if DEBUG then
									DebugDrawText(1300, 100+gsiPlayer.nOnTeam*10, 
											string.format("%5s-wait:%5s for def %.0f", gsiPlayer.shortName,
													thisPlayer.shortName,
													Vector_PointDistance(
															thisPlayer.lastSeen.location,
															wpObjective.lastSeen.location
														)
												),
											255, 255, 255
										)
								end
								Blueprint_RegisterCustomActivityType(gsiPlayer, ACTIVITY_TYPE.CAREFUL)
								-- TODO refac Dawdle_Run(gsiPlayer, objv, score, avoidEnemyVal)??
								avoid_hide_run(gsiPlayer, gsiPlayer, avoidHideScore, true)
								return xetaScore;
							end
						end
					end
				end
				if not forceRun then
					Blueprint_RegisterCustomActivityType(gsiPlayer, ACTIVITY_TYPE.CONTROLLED_AGGRESSION)
				end
				local fightHarassObj = GET_TASK_OBJ(gsiPlayer, fight_harass_handle)
				if VERBOSE then print("/VUL-FT/", gsiPlayer.shortName, "running harass in zone_defend targetting", fightHarassObj and fightHarassObj.shortName) end
				if fightHarassObj then
					Blueprint_RegisterCustomActivityType(gsiPlayer, ACTIVITY_TYPE.CONTROLLED_AGGRESSION)
					fight_harass_run(gsiPlayer, fightHarassObj, fightHarassScore)
				end
				--if DEBUG then DebugDrawText(1600, 200, string.format("ZoneDefend->FightHarass; %s", fightHarassScore), 255, 255, 255) end
			end
			return xetaScore;
		end
		--TEMP -- EVERYTHING TEMP
		if Math_PointToPointDistance2D(gsiPlayer.lastSeen.location, objective.lastSeen.location) > 1000 then
			local nearestTower, nearestTowerDist = Set_GetNearestTeamTowerToPlayer(ENEMY_TEAM, gsiPlayer)
			Positioning_ZSMoveCasual(gsiPlayer, objective.lastSeen.location,
					4.0, 
					(nearestTowerDist < 1000 and 900),
					nil,
					true -- TEST
				)
		end
	end,
	
	score = function(gsiPlayer, prevObjective, prevScore)
		local wpForBotTask = WP_GetPlayerTaskPoster(gsiPlayer, task_handle)
		any_defence_considerable = false
		for i=1,#t_wp_stored do
			local wpHandle = t_wp_stored[i]
			if wpHandle and not check_building_defence_end(wpHandle[POSTER_I.OBJECTIVE]) then
				if not wpHandle[POSTER_I.ALLOCATE_PERFORMED] then
					if not WP_InformInterest(gsiPlayer, wpHandle, WP_COMMIT_TYPES.INTEREST_SHARE, 0) then
						any_defence_considerable = true
					end
				elseif GameTime() - wpHandle[POSTER_I.LAST_ALLOCATE] > 6.0 then
					WP_AllowReinform(wpHandle)
				end
			end
		end






		if wpForBotTask and WP_CommitIsCommit(gsiPlayer, wpForBotTask) then
			local distToObj = Vector_PointDistance2D(
					gsiPlayer.lastSeen.location,
					wpForBotTask[POSTER_I.OBJECTIVE].lastSeen.location
				)
			local wpObjective = wpForBotTask[POSTER_I.OBJECTIVE]
			local harmsIntended = 0
			if distToObj > 2400 then
				local _
				_, _, harmsIntended = FightClimate_AnyIntentToHarm(
						gsiPlayer,
						Set_GetEnemyHeroesInPlayerRadius(gsiPlayer, 1400)
					)
			end
			local noSelfishScore = 0
			local pnot = gsiPlayer.nOnTeam
			local playerLoc = gsiPlayer.lastSeen.location
			local towerHpp = wpObjective.lastSeenHealth / wpObjective.maxHealth
			for i=1,TEAM_NUMBER_OF_PLAYERS do
				if i~=pnot then
					local thisPlayer = t_team_players[i]
					if WP_CommitIsCommit(gsiPlayer, wpForBotTask) then
					--		and (Vector_UnitFacingUnit(thisPlayer, wpObjective) 
					--				or Unit_GetHealthPercent(thisPlayer) > 0.45
						noSelfishScore = noSelfishScore +
								max(0, 50 - Vector_PointDistance(
										thisPlayer.lastSeen.location,
										wpObjective.lastSeen.location
									) * max(0.33, towerHpp) / 100
								)
					end
					noSelfishScore = noSelfishScore - max(0,
								45 - Vector_PointDistance(
									thisPlayer.lastSeen.location,
									playerLoc
								) / 40
							)
				end
			end
			Task_IncentiviseTask(gsiPlayer, task_handle, noSelfishScore, 10)
			local posterScore = (gsiPlayer.time.data[wpForBotTask] or WP_ScorePoster(gsiPlayer, wpForBotTask, true))
			if posterScore > Task_GetCurrentTaskScore(gsiPlayer) then
				-- TODO hack temporary while fight.lua not implmnt.
				--Task_IncentiviseTask(gsiPlayer, fight_harass_handle, 5*(#Set_GetAlliedHeroesInPlayerRadius(gsiPlayer, 2400))^2, 3)
			end
			
			return wpForBotTask[POSTER_I.OBJECTIVE], posterScore/(1+harmsIntended)
		end
		return false, XETA_SCORE_DO_NOT_RUN
	end,
	
	init = function(gsiPlayer, objective, extrapolatedXeta)
		gsiPlayer.vibe.aggressivity = 0.5 -- Not usually the type of activity to warrant aggresivity switch, but it is sometimes a long task
		return extrapolatedXeta
	end
}

function FightZone_RegisterNewCaptureZone(location, radius, rawXeta)
	
end

function ZoneDefend_GetTaskHandle()
	return task_handle
end
