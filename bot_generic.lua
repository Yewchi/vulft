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

-- Dev note: DISCLAIMER -- Comments are terrible, sometimes vague, and damn rude.

-- Very U(gly, Unrolled, Unabstracted, and Fast) Lua Full Takeover -- Dota 2 script -- Welcome to perfomance Lua, where empty tables are 64 bytes, and abstraction doesn't matter.
-- Written by zyewchi@gmail.com - Michael - github.com/Yewchi gitlab.com/yewchi

_G = nil

local FLIP_TO_DEFAULT_BOT_BEHAVIOUR_NEAR_RUNE_DIST = 150

-- Illusions:
	-- TODO Register illusions into a simulated player control module.
	-- ---- -| Allow controlling all at once, or one at a time.
	-- ---- -| Make decisions once every so often, move the illusions
	-- ---- -| separately, low health illusions away at times.
	-- ---- -| Block positioning for true heroes attacking a tower or
	-- ---- -| pushing a creep wave occasionally, and run positioning code
	-- ---- -| on a preferrably low health illusion that, if it's deemed
	-- ---- -| not over-the-top, we know hasn't taken huge damage recently
	-- ---- -| (for greater confusion), and run positioning avoid hide
	-- ---- -| movement on them. More likely to occur with enemies nearby.
	-- ---- -| Control-all more likely without.
	-- ---- -| If someone like PL and going for a clutch kill, run one
	-- ---- -| illusion out as well.
	-- ---- -| Detect spell casts on illusions that were selected for
	-- ---- -| mimicry. Dial back for difficulty.

if not GetBot():IsHero() then -- or illusion.
	INFO_print(string.format(
			"Not creating nor running a full-takeover for non-hero unit '%s'",
			GetBot():GetUnitName()
			)
		)
	return;
end

--_G = nil
--_ENV = nil

require(GetScriptDirectory().."/lib_util/util")
require(GetScriptDirectory().."/lib_job/job_manager")
require(GetScriptDirectory().."/lib_gsi/gsi_planar_gsi")
require(GetScriptDirectory().."/partial_full_handover")

local is_arc_warden_double = false

-- modifier_arc_warden_tempest_double is applied late into the unit spawning, and triggering it's instance of bot_generic.lua
-- -- Not sure of any arc-warden focused stuff still needed. Mostly it was done to find means for best control.
if GetBot():GetUnitName() == "npc_dota_hero_arc_warden" then 
	if GSI_GetZetTempestByPlayerId(GetBot():GetPlayerID()) then
		is_arc_warden_double = true
	end
	GSI_HandleZetBotGenericCreated()
end

local this_bot = {hUnit = GetBot()}
local THIS_BOT_DOMAIN_NAME
		= "DOMAIN_PLAYER"
			..Job_CreateUniqueName(
					GSI_GetPlayerNumberOnTeam(
							this_bot.hUnit:GetPlayerID()
						)..(is_arc_warden_double and "TEMPEST" or "")
				)
local job_domain = Job_CreateDomain(THIS_BOT_DOMAIN_NAME)
local while_dead_behavior_throttle = Time_CreateThrottle(0.17)

local dominated_unit_throttle = Time_CreateThrottle(0.2)

-- Think
local err_count = 0
local err_flag = 0
local dominated_print_next = 0
local function bot_microthink__job(workingSet) -- The guts of the redefined Think. Think = generic_microthink(){bot_microthink__job()}
	if this_bot.disabledAndDominatedFunc then
		if TEST then print("calling dominated", this_bot.shortName, this_bot.disabledAndDominatedFuncName) end
		this_bot:disabledAndDominatedFunc()
		return
	end

	if 1 then
		if err_flag==1 then
			err_count = err_count + 1
		end
		if err_count>0 then
			DebugDrawText(5, 5, string.format("err_c: %d", err_count), 150, 0, 0)
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
		local attackMoveToLoc = not fightHarassTarget and ENEMY_FOUNTAIN
		--print("dom", fightHarassTarget)
		while(thisDominatedUnit) do
			local nextUnit = thisDominatedUnit.nextUnit
			--print(this_bot.shortName, "commanding unit", thisDominatedUnit.shortName)
			if not pUnit_IsDominatedUnitNullOrDead(thisDominatedUnit)
					and not thisDominatedUnit.hUnit:GetAttackTarget() then
				if attackMoveToLoc then
					thisDominatedUnit.hUnit:Action_AttackMove(attackMoveToLoc)
				else
					thisDominatedUnit.hUnit:Action_AttackUnit(fightHarassTarget.hUnit, true)
				end
			end
			thisDominatedUnit = nextUnit
		end
	end



--	if this_bot.shortName == "void_spirit" or this_bot.shortName == "sven" then
--		this_bot.hUnit:Action_MoveDirectly(Vector(4600, -6000))
--	end
--if TEAM_IS_RADIANT then	this_bot.hUnit:Action_MoveDirectly(Vector_Addition(Map_GetTeamFountainLocation(), Vector(-400, 1500, 0))) end -- dominate stuck test
--if not TEAM_IS_RADIANT then	this_bot.hUnit:Action_MoveDirectly(Vector_Addition(Map_GetTeamFountainLocation(), Vector(400, -1000, 0))) end
	--[[if DRAW_EMOTES and this_bot.hUnit:GetDifficult() == 0 then
		Util_DrawActivityEmotion
	end]]
	if 1 then
		err_flag = 0
	end
end

local function bot_initialization_wait_gsi_ready__job(workingSet)
	if GSI_READY then
		this_bot = GSI_GetBot()

		this_bot.CDOTA_Action_DropItem = CDOTA_Action_DropItem

		if is_arc_warden_double then
			GSI_HandleZetBotGenericCreated()
		end

		job_domain:RegisterJob(
				not is_arc_warden_double and bot_microthink__job or HeroData_RequestHeroKeyValue(this_bot.shortName, "TempestDoubleThink"), -- ,not a forward-thinking abstraction of alternate think funcs
				nil,	
				"JOB_BOT_GENERIC_MICROTHINK"
			)
		job_domain:RegisterJob(
				Positioning_ProgressZNormalSweeper__Job,
				{["gsiPlayer"] = this_bot},
				"JOB_BOT_UPDATE_Z_NORMAL_SWEEPER"
			)
		return true -- Removes this initialization job, bot_microthink__job is taking over the guts of Think
	end
end

-- Think = ...
local function generic_microthink() -- See Think() counterparts (grander scale thinking) in team_logic.lua





	if job_domain.active then
		job_domain:DoAllJobs()
	end
end

--[[VERBOSE]]if VERBOSE then VEBUG_print("[bot_generic]: Initializing bot '"..this_bot.hUnit:GetUnitName().."'") end
local function handover()
	INFO_print(string.format("%s performing handover of control to bot_generic::Think()",
					this_bot.hUnit:GetUnitName()
				)
		)
	job_domain:RegisterJob(
			bot_initialization_wait_gsi_ready__job,
			nil,
			"JOB_BOT_INITIALIZATION_WAIT_GSI_READY"
		)

	if this_bot.hUnit == TEAM_CAPTAIN_UNIT then
		require(GetScriptDirectory().."/captain")
		if Captain_RegisterCaptain then
			Captain_RegisterCaptain(this_bot.hUnit, generic_microthink)
		end
		Think = (not DEBUG and Captain_CaptainThink or -- -- -- -- -- -- -- Think() DECLARATION
				function() 
					if not DEBUG_KILLSWITCH then 
						Captain_CaptainThink() 
					end 
				end
			)
	else
		Think = (not DEBUG and generic_microthink or  -- -- -- -- -- -- --- Think() DECLARATION
				function() 
					if not DEBUG_KILLSWITCH then -- Killswitch is debug utility, e.g. data dump on console.
						generic_microthink() 
					end 
				end
			)
	end
end
if this_bot.hUnit:IsHero() and not this_bot.hUnit:IsIllusion()
		and not is_arc_warden_double then
	-- prep for handover ability_item_usage_generic -> bot_generic
	PFH_RegisterPersonalMicrothinkTriggerOfBotGeneric(this_bot.hUnit, handover)
end
if is_arc_warden_double then
	handover()
end
-- TODO MINION THINK
--MinionThink = function(hUnit) print("hey") hUnit:Action_MoveToLocation(Vector(0, 0, 0)) end
