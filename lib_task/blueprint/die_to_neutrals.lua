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

local TEAM_NUMBER_OF_PLAYERS = TEAM_NUMBER_OF_PLAYERS
local Task_SetTaskPriority = Task_SetTaskPriority
local XETA_SCORE_DO_NOT_RUN = XETA_SCORE_DO_NOT_RUN

local task_handle = Task_CreateNewTask()

local blueprint

local min = math.min
local max = math.max
local sqrt = math.sqrt

local farm_lane_handle

local team_players

local MIN_NEUTRAL_DIE_TIME = 26
local limit_chat_expiry = {}

local ITEM_NOT_FOUND = ITEM_NOT_FOUND

local random_die_chat = {
		"Calculated.",
		"worth, I guess.",
		"brb.. -.-",
		":(",
		"ow"
	}

local level_to_time_dead = {
		12, -- 1
		15, -- 2
		18, -- 3
		21, -- 4
		24, -- 5
		26, -- 6
		28, -- 7
		30, -- 8
		32, -- 9
		34, -- 10
		36, -- 11
		44, -- 12
		46, -- 13
		48, -- 14
		50, -- 15
		52, -- 16
		54, -- 17
		65, -- 18
		70, -- 19
		75, -- 20
		80, -- 21
		85, -- 22
		90, -- 23
		95, -- 24
		100, -- 25
		100, -- 26
		100, -- 27
		100, -- 28,
		100, -- 29,
		100, -- 30
}

local function estimated_time_til_completed(gsiPlayer, objective)
	return 0
end
local function task_init_func(taskJobDomain)
	Blueprint_RegisterTaskName(task_handle, "die_to_neutrals")
	if VERBOSE then VEBUG_print(string.format("die_to_neutrals: Initialized with handle #%d.", task_handle)) end

	use_ability = UseAbility_GetTaskHandle()

	team_players = GSI_GetTeamPlayers(TEAM)

	avoid_hide_handle = AvoidHide_GetTaskHandle()
	increase_safety_handle = IncreaseSafety_GetTaskHandle()

	for i=1,TEAM_NUMBER_OF_PLAYERS do
		limit_chat_expiry[i] = 0
	end

	Task_RegisterTask(task_handle, PLAYERS_ALL, blueprint.run, blueprint.score, blueprint.init)

	taskJobDomain:RegisterJob(
			function(workingSet)
				if workingSet.throttle:allowed() then
					for i=1,TEAM_NUMBER_OF_PLAYERS do
						local thisPlayer = team_players[i]
						if thisPlayer.lastSeenHealth / thisPlayer.maxHealth < 0.3 then
							Task_SetTaskPriority(task_handle, i, TASK_PRIORITY_TOP)
						end
					end
				end
			end,
			{["throttle"] = Time_CreateThrottle(1.009)}, -- score is static
			"JOB_TASK_SCORING_PRIORITY_DIE_TO_NEUTRALS"
		)
	Blueprint_RegisterTaskActivityType(task_handle, ACTIVITY_TYPE["FEAR"])
	task_init_func = nil
	return task_handle, estimated_time_til_completed
end
Blueprint_RegisterTask(task_init_func)

blueprint = {
	run = function(gsiPlayer, objective, xetaScore)
		if not objective then return XETA_SCORE_DO_NOT_RUN end
		if objective.x then
			--print("no creeps")
			Positioning_MoveDirectly(gsiPlayer, objective)
			return xetaScore;
		elseif objective[1] then
			--print("creeps")
			for i=1,#objective do
				local thisCreep = objective[i]
				if thisCreep.IsNull and not thisCreep:IsNull() and thisCreep:IsAlive() then
					--print("attack start", Unit_GetTimeTilNextAttackStart(gsiPlayer))
					if Unit_GetTimeTilNextAttackStart(gsiPlayer) > 0.105 then
						local creepLoc = thisCreep:GetLocation()
						local moveTo = Vector_Addition(
								creepLoc,
								Vector_ScalarMultiply2D(
										Vector_UnitDirectionalPointToPoint(
												creepLoc,
												TEAM_FOUNTAIN
											),
										150
									)
							)
						Positioning_MoveDirectly(gsiPlayer, moveTo)
						return xetaScore;
					end
					gsiPlayer.hUnit:Action_AttackUnit(thisCreep, true)
					return xetaScore;
				end
			end
		end
	end,
	
	score = function(gsiPlayer, prevObjective, prevScore)
		local flaskOwned, _, flaskItemSlot = Item_ItemOwnedAnywhere(gsiPlayer, "item_flask")
		--Util_TablePrint(flaskItemSlot)
		local nearbyEnemies = Set_GetEnemyHeroesInPlayerRadius(gsiPlayer, 1100, 6)
		if gsiPlayer.dyingIsntDying -- NB. reincarn-is-up heroes must register in their ability file
				or gsiPlayer.hUnit:FindItemSlot("item_aegis") ~= ITEM_NOT_FOUND
				or gsiPlayer.hUnit:FindItemSlot("item_cheese") ~= ITEM_NOT_FOUND -- can be stashed?
				or ( gsiPlayer.hUnit:FindItemSlot("item_tranquil_boots") ~= ITEM_NOT_FOUND
					and not nearbyEnemies[1] )
				or gsiPlayer.hUnit:HasModifier("modifier_satanic") -- TODO VRF
				or gsiPlayer.hUnit:HasModifier("modifier_bloodstone") -- TODO VRF
				or ( not nearbyEnemies[1]
						and ( gsiPlayer.hUnit:HasModifier("modifier_flask_healing")
								or (flaskOwned and ( (
										flaskItemSlot >= 0 and flaskItemSlot <= ITEM_END_INVENTORY_INDEX
									) or (
										flaskItemSlot > ITEM_END_INVENTORY_INDEX
												and gsiPlayer.hCourier and gsiPlayer.hCourier:IsAlive()
												and Vector_PointDistance2D(gsiPlayer.hCourier:GetLocation(), gsiPlayer.lastSeen.location) < 5000
									)
								)
							)
						)
					)
				then 
			return false, XETA_SCORE_DO_NOT_RUN
		end
		local healthGain = Item_RAUCMitigateDelivery(gsiPlayer)
		local hpp = (gsiPlayer.lastSeenHealth + healthGain + gsiPlayer.hUnit:GetHealthRegen()*6)
				/ gsiPlayer.maxHealth
		local dieDecided = limit_chat_expiry[gsiPlayer.nOnTeam] -- temp expiry val
		local currTime = GameTime() 
		dieDecided = dieDecided and dieDecided > currTime or false
		if dieDecided and hpp < 0.3 or hpp < 0.25 + #nearbyEnemies*0.03 then
			if not dieDecided then
				repeat
					if Vector_PointDistance(
							gsiPlayer.lastSeen.location,
							TEAM_FOUNTAIN
						) / gsiPlayer.currentMovementSpeed
							> max(
									MIN_NEUTRAL_DIE_TIME,
									level_to_time_dead[gsiPlayer.level]
								) then
						break;
					end
					if nearbyEnemies[1] then
						local invis = AbilityLogic_GetBestInvis(gsiPlayer)
						local survivability = AbilityLogic_GetBestSurvivability(gsiPlayer)
						local mobility = AbilityLogic_GetBestMobility(gsiPlayer)
						if gsiPlayer.lastSeenMana
								> min(
										invis and invis:GetManaCost() or 0xFFF,
										survivability and survivability:GetManaCost() or 0xFFF,
										mobility and mobility:GetManaCost() or 0xFFF
									) then
							break;
						end
					end
					return false, XETA_SCORE_DO_NOT_RUN
				until(true)
			end
			local spawnerLoc, _, creeps = FarmJungle_GetNearestUncertainUncleared(gsiPlayer, JUNGLE_CAMP_ANCIENT)
			if spawnerLoc
					and (not nearbyEnemies
							or Vector_PointDistance(gsiPlayer.lastSeen.location, spawnerLoc) < 700
						) then
				if not dieDecided then
					limit_chat_expiry[gsiPlayer.nOnTeam] = currTime + MIN_NEUTRAL_DIE_TIME
					if Vector_PointDistance2D(gsiPlayer.lastSeen.location, spawnerLoc) < 600 then
						local chat = random_die_chat[RandomInt(1,8)]
						if chat then
							gsiPlayer.hUnit:ActionImmediate_Chat(chat, DEBUG or false)
						end
					end
				end
				return creeps and creeps[1] and creeps or spawnerLoc, max(
						Task_GetTaskScore(gsiPlayer, avoid_hide_handle),
						Task_GetTaskScore(gsiPlayer, increase_safety_handle),
						100
					) * 2
			end
		end
		return false, XETA_SCORE_DO_NOT_RUN
	end,
	
	init = function(gsiPlayer, objective, extrapolatedXeta)
		return extrapolatedXeta
	end
}

function DieToNeutrals_GetTaskHandle()
	return task_handle
end
