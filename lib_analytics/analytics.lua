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

require(GetScriptDirectory().."/lib_analytics/projectile")
require(GetScriptDirectory().."/lib_analytics/last_hit_projection")
require(GetScriptDirectory().."/lib_analytics/power_level")
require(GetScriptDirectory().."/lib_analytics/fow_logic")
require(GetScriptDirectory().."/lib_analytics/fight_climate")
require(GetScriptDirectory().."/lib_analytics/lane_pressure")
require(GetScriptDirectory().."/lib_analytics/enemy_intent")
require(GetScriptDirectory().."/lib_analytics/fight_moderate")
require(GetScriptDirectory().."/lib_analytics/vantage")
require(GetScriptDirectory().."/lib_analytics/tilt")
require(GetScriptDirectory().."/lib_analytics/score_location_data")

local job_domain = Job_CreateDomain("DOMAIN_ANALYTICS")

function Analytics_Initialize(captain_basic_domain)
	Analytics_RegisterAnalyticsJobDomainToLhp(job_domain)
	Analytics_RegisterAnalyticsJobDomainToFowLogic(job_domain)
	Analytics_RegisterAnalyticsJobDomainToLanePressure(job_domain)
	Analytics_RegisterAnalyticsJobDomainToEnemyIntent(job_domain)
	Analytics_RegisterAnalyticsJobDomainToFightModerate(job_domain)
	Analytics_RegisterAnalyticsJobDomainToFightClimate(job_domain)
	Analytics_RegisterGetKnownTheorizedEngageablesToPowerLevel(Analytics_GetKnownTheorizedEngageables)
	Analytics_RegisterDomainToVantage(captain_basic_domain, job_domain)
	Xeta_Initialize()
	Tilt_Initialize()
end

function Analytics_GetAnalyticsJobDomain()
	return job_domain
end

function Analytics_InformBuildingFell(gsiBuilding)
	Set_InformBuildingFell(gsiBuilding)
	VAN_InformDefensibleFell(gsiBuilding)
end
