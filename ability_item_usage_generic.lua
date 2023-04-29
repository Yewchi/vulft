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

--
-- NB TEMPORARY HOOK BEFORE HANDOVER TO BOT_GENERIC
-- --	This is only for picking up river runes at
-- --	minute 0:00. Bots may flip into default
-- --	Valve behavior while within 150 units of a
-- --	river rune spawn area, but only when bounties
-- --	should be present as per 7.22. That is the full
-- --	extent of Default bot usage of this script.
-- --	Each default behavior module has it's Think()
-- --	funcs overridden to spam the name of the function
-- --	in the console. This never really occurs, because
-- --	we are locked to a static priority of 1 in roam Think().
-- --	The hook to the named bot_microthink() func is called via this
-- --	item usage think, until handover occurs, and
-- --	Think() = bot_microthink() is set in bot_generic,
-- --	as well Think() is overridden
-- --	Bot are also on a time limit and must
-- --	trigger handover despite rune status after a
-- --	very short time. This is because the script records
-- --	no state about what a default bot might be trying
-- --	to do at any time, and so we can only hope they've
-- --	done the task in the short moment they are given.
--
if not GetBot():IsHero() or GetBot():IsIllusion() then
	ItemUsageThink = function() end
	return
end

if DEBUG then
	DEBUG_print(
			string.format("temporary instantiation of ability_item_usage_generic for %s",
					GetBot():GetUnitName()
				)
		)
end

local FLIP_TO_DEFAULT_BOT_BEHAVIOUR_NEAR_RUNE_DIST = 150

if DEBUG then -- (pre-defined)
	-- test benching
	if GetBot():GetPlayerID() == 8 then
	end
end

require(GetScriptDirectory().."/lib_util/util")
require(GetScriptDirectory().."/lib_job/job_manager")
require(GetScriptDirectory().."/lib_gsi/gsi_planar_gsi")
require(GetScriptDirectory().."/partial_full_handover")

local this_bot = {hUnit = GetBot()}
local THIS_BOT_DOMAIN_NAME = "TEMP_DOMAIN_PLAYER"..GSI_GetPlayerNumberOnTeam(this_bot.hUnit:GetPlayerID())
local job_domain = Job_CreateDomain(THIS_BOT_DOMAIN_NAME)
local while_dead_behavior_throttle = Time_CreateThrottle(0.17)

local dominated_unit_throttle = Time_CreateThrottle(0.2)

-- Think
local err_count = 0
local err_flag = 0
local function bot_microthink__job(workingSet) -- The guts of our redefined Think = generic_microthink -> bot_microthink__job
	if this_bot.awaitsDefaultBotsInterruptedFullTakeoverForHookHandoverToFull
			and ( (GetRuneStatus(RUNE_POWERUP_1) == RUNE_STATUS_AVAILABLE
						and Vector_PointDistance2D(GetBot():GetLocation(), GetRuneSpawnLocation(RUNE_POWERUP_1))
							< FLIP_TO_DEFAULT_BOT_BEHAVIOUR_NEAR_RUNE_DIST
					)
					or (GetRuneStatus(RUNE_POWERUP_2) == RUNE_STATUS_AVAILABLE
						and Vector_PointDistance2D(GetBot():GetLocation(), GetRuneSpawnLocation(RUNE_POWERUP_2))
							< FLIP_TO_DEFAULT_BOT_BEHAVIOUR_NEAR_RUNE_DIST
					)
			) then
		return; -- Hope that default bot acts as expected near the rune rather than run the VULFT code via this hook.
	end
	--this_bot.hUnit:Action_MoveDirectly(GetRuneSpawnLocation(RUNE_POWERUP_1))
	if this_bot.disabledAndDominatedFunc then
		-- e.g. very low location variation and interaction, bot is diagnosing if stuck and resolving, cut trees, void step to mid, or TP fountain.
		if TEST then
			print("calling dominated", this_bot.shortName, this_bot.disabledAndDominatedFuncName)
		end
		this_bot:disabledAndDominatedFunc()
		return;
	end
	if DEBUG then if err_flag==1 then
			err_count = err_count + 1
		end
		if err_count>0 then
			DebugDrawText(5, 5, string.format("err_count: %d", err_count), 255, 0, 0)
		end
		err_flag = 1
	end
	-- run this_bot
	Time_IndicateNewFrame(this_bot)
	if this_bot.hUnit:IsAlive() then
		Task_InformAliveAndRemoveObjectiveDisallows(this_bot)
		AbilityThink_TryRun(this_bot)
		Task_HighestPriorityTaskScoringContinue(this_bot)
		Task_CurrentTaskContinue(this_bot)
		Hero_InvestAbilityPointsAndManageItems(this_bot)
	else
		if while_dead_behavior_throttle:allowed() then
			Player_InformDead(this_bot) -- TODO more abstraction
			Task_InformDeadAndCancelAnyConfirmedDenial(this_bot)
			Blueprint_InformDead(this_bot)
			Team_InformDeadTryBuyback(this_bot)
		end
	end
	-- run this_bot's dominated units -- TODO global usage and redundant calls on consts indicate restructure of bot tables, or increasing this module's local-global scope; mess.
	if this_bot.dominatedUnitsHead and dominated_unit_throttle:allowed() then
		local thisDominatedUnit = this_bot.dominatedUnitsHead
		local fightHarassTarget = Task_GetTaskObjective(this_bot, FightHarass_GetTaskHandle())
		local attackMoveToLoc = not fightHarassTarget and TEAM_FOUNTAIN

		while(thisDominatedUnit) do
			local nextUnit = thisDominatedUnit.nextUnit
			print(this_bot.shortName, "commanding unit", thisDominatedUnit.shortName)
			if not pUnit_IsDominatedUnitNullOrDead(thisDominatedUnit)
					and not thisDominatedUnit.hUnit:GetAttackTarget() then
				if attackMoveToLoc then
					thisDominatedUnit.hUnit:Action_AttackMove(attackMoveToLoc)
				else
					thisDominatedUnit.hUnit:Action_AttackUnit(fightHarassTarget.hUnit, false)
				end
			end
		thisDominatedUnit = nextUnit
		end
	end
--if TEAM_IS_RADIANT then	this_bot.hUnit:Action_MoveDirectly(Vector_Addition(Map_GetTeamFountainLocation(), Vector(-400, 1500, 0))) end -- dominate stuck test
--if not TEAM_IS_RADIANT then	this_bot.hUnit:Action_MoveDirectly(Vector_Addition(Map_GetTeamFountainLocation(), Vector(400, -1000, 0))) end
	if DEBUG then err_flag = 0 end
end

local function reconfigure_stack_entry(workingSet)
	local thisBot = GSI_GetPlayerFromPlayerID(GetBot():GetPlayerID())
	
	if ( GetGameState() == GAME_STATE_GAME_IN_PROGRESS
				and DotaTime() > 60
				and Item_NumberItemsCarried(thisBot) > 6
			) then
		PFH_TriggerHandoverToBotGeneric(thisBot)
		return true
	end
end

local function bot_initialization_wait_gsi_ready__job(workingSet)
	local thisBot = GSI_GetPlayerFromPlayerID(GetBot():GetPlayerID())
	--print(GetBot():GetUnitName(), thisBot and thisBot.role, "thinggg")
	if GSI_READY then
		this_bot = GSI_GetBot()
		this_bot.awaitsDefaultBotsInterruptedFullTakeoverForHookHandoverToFull
				= true

		INFO_print(
				string.format("[ability_item_usage_generic*] Register in pre-0:00 bounty hook %s...",
					this_bot.shortName or ""
				)
			)
		job_domain:RegisterJob(
				not is_arc_warden_double and bot_microthink__job
						or HeroData_RequestHeroKeyValue(
								this_bot.shortName, "TempestDoubleThink"
							),
				nil,	
				"JOB_BOT_GENERIC_MICROTHINK"
			)
		job_domain:RegisterJob(
				Positioning_ProgressZNormalSweeper__Job,
				{["gsiPlayer"] = this_bot},
				"JOB_BOT_UPDATE_Z_NORMAL_SWEEPER"
			)

		job_domain:RegisterJob(
				reconfigure_stack_entry,
				nil,
				"JOB_RECONFIGURE_BOT_STACK_ENTRY"
			)

		return true -- Removes this initialization job, bot_microthink__job is taking over the guts of Think
	end
end

-- Think = ...
local function generic_microthink() -- See Think() counterparts (grander scale thinking) in team_logic.lua
	if job_domain then
		if job_domain.active and not job_domain.deleted then
			if VERBOSE then
				VEBUG_print(
					string.format(
						"[ability_item_usage_generic]: %s running temporary hook",
						GetBot():GetUnitName()
						)
					)
			end
			--print(GetBot():GetUnitName(), "is not deleted.")
			job_domain:DoAllJobs()
		else
			job_domain = nil
			ERROR_print(false, false, "[ability_item_usage_generic]: Manually destroying %s's flippable hook to default behavior.",
					GetBot():GetUnitName() 
				)
			ItemUsageThink = function() end
			CourierUsageThink = function() end
		end
	end
end

--[[VERBOSE]]if VERBOSE then VEBUG_print("[ability_item_usage_generic]: Temporary init to hook '"..this_bot.hUnit:GetUnitName().."'") end
do -- Preliminary Initialization
	job_domain:RegisterJob(
			bot_initialization_wait_gsi_ready__job,
			nil,
			"JOB_BOT_INITIALIZATION_WAIT_GSI_READY"
		)

	if this_bot.hUnit == TEAM_CAPTAIN_UNIT then
		require(GetScriptDirectory().."/captain")
		Captain_RegisterCaptain(this_bot.hUnit, generic_microthink)
		ItemUsageThink = (not DEBUG and Captain_CaptainThink or -- -- -- -- -- -- -- Think() DECLARATION
				function() 
					if not DEBUG_KILLSWITCH then 
						Captain_CaptainThink() 
					end 
				end
			)
	else
		ItemUsageThink = (not DEBUG and generic_microthink or  -- -- -- -- -- -- --- Think() DECLARATION
				function() 
					if not DEBUG_KILLSWITCH then -- Killswitch is debug utility, like when a large data dump is required (must easier to set-up the designated 'target dummy' to print, then kill all bots after that line of code)
						generic_microthink() 
					end 
				end
			)
	end
	CourierUsageThink = function()
		if not GetBot():IsAlive() then
			ItemUsageThink()
		end
	end
end

PFH_RegisterTempPersonalJobDomain(GetBot(), job_domain) -- we will delete the domain when we handover -- But not Pos 5.

--MinionThink = function(hUnit) print("hey") hUnit:Action_MoveToLocation(Vector(0, 0, 0)) end

-- ItemUsageThink our candidate for the full takeover function due to being called every frame.
-- -- (the alternative solution--for this, the solution to river runes--to last hitting was to make
-- -- predictions of last hits well in advance, make bots take a calculated step towards a location that was
-- -- determined to be the less-than-100ms distance-time--including predicted
-- -- facing-direction-away-to-towards--to our last hit target, then conduct the attack at a
-- -- known moment, the last .1s interval--for which the calculation of last hit timing was made in advance--
-- -- that interval it just so happened that the controlling Think() function from an arbitrary bot mode's
-- -- Think() occurred).
-- All other standard think funcs are blotted out (besides MinionThink, because it is satisfactory
-- -- until addressed, and while traditionally fully-taken-over via bot_generic.lua during development, I had
-- -- already spent much time with minions working in some automatic way which I believe was as a result of
-- -- not knowing to also manually override MinionThink() within bot_generic.lua.
--function ItemUsageThink() end -- this is again overridden, above
AbilityUsageThink = function() end
AbilityLevelUpThink = function() end
BuybackUsageThink = function() end
