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

local TOTAL_TIME_ALLOWED_IN_DEFAULT_BOTS = 1.5
local total_time_default_bot_control = 0

local t_personal_bot_generic_triggers = {}
local t_personal_job_domain_to_delete = {}
-------- PFH_RegisterPersonalMicrothinkTriggerOfBotGeneric()
-- - - Engage the Think = func behaviour, deleting spurious default bot behaviour
-- - -- such as item slot switching against the full-takeover's will. Used after
-- - -- the otherwise unacquirable river runes are aqcuired.
local abc = 0

require(GetScriptDirectory().."/lib_util/time")

function PFH_HaveNotExceededTimeInDefaultBots(gsiPlayer)
	if total_time_default_bot_control < TOTAL_TIME_ALLOWED_IN_DEFAULT_BOTS then
		total_time_default_bot_control = total_time_default_bot_control
				+ gsiPlayer.time.frameElapsed
		return true
	end
	return false
end

function PFH_RegisterPersonalMicrothinkTriggerOfBotGeneric(hUnit, func)
	--print("check in bot generic", hUnit:GetUnitName(), func)
	abc = abc + 1
	t_personal_bot_generic_triggers[hUnit] = func
	--print("checked in #:", abc)
end

local xyz = 0
function PFH_RegisterTempPersonalJobDomain(hUnit, jobDomain)
	--print("check in ability item usage", hUnit:GetUnitName())
	xyz = xyz + 1
	t_personal_job_domain_to_delete[hUnit] = jobDomain
	--print("checked in #:", xyz)
end

function PFH_TriggerHandoverToBotGeneric()
	local botGenericReady=0
	for _,_ in pairs(t_personal_bot_generic_triggers) do
		botGenericReady = botGenericReady + 1
	end
	local abilityItemUsageGenericReady=0
	for _,_ in pairs(t_personal_job_domain_to_delete) do
		abilityItemUsageGenericReady = abilityItemUsageGenericReady + 1
	end
	if botGenericReady < TEAM_NUMBER_OF_BOTS
			or abilityItemUsageGenericReady < TEAM_NUMBER_OF_BOTS then
		ALERT_print(string.format("not all bots have registered for full-takeover handover, botGenericReadyToDefineThink: %d, misuseOfAbilityItemUsageReady: %d", botGenericReady, abilityItemUsageGenericReady))
		return
	end
	INFO_print( string.format(
				"'%s' governing PFH's handover to bot_generic::Think().",
				GetBot():GetUnitName()
			)
		)
	for hUnit,botGenericTrigger in pairs(t_personal_bot_generic_triggers) do
		botGenericTrigger()
		t_personal_job_domain_to_delete[hUnit]:DeleteDomain()
	end
	t_personal_bot_generic_triggers = nil
	t_personal_job_domain_to_delete = nil
	-- ability_item_usage_generic will shut off it's entry to the full-takeover code
end
