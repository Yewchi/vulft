require(GetScriptDirectory().."/lib_analytics/projectile")
require(GetScriptDirectory().."/lib_analytics/last_hit_projection")
require(GetScriptDirectory().."/lib_analytics/power_level")
require(GetScriptDirectory().."/lib_analytics/fow_logic")
require(GetScriptDirectory().."/lib_analytics/fight_climate")
require(GetScriptDirectory().."/lib_analytics/lane_pressure")
require(GetScriptDirectory().."/lib_analytics/enemy_intent")
require(GetScriptDirectory().."/lib_analytics/fight_moderate")
require(GetScriptDirectory().."/lib_analytics/vantage")

local job_domain = Job_CreateDomain("DOMAIN_ANALYTICS")

function Analytics_Initialize(captain_basic_domain)
	Analytics_RegisterAnalyticsJobDomainToLhp(job_domain)
	Analytics_RegisterAnalyticsJobDomainToFowLogic(job_domain)
	Analytics_RegisterAnalyticsJobDomainToLanePressure(job_domain)
	Analytics_RegisterAnalyticsJobDomainToEnemyIntent(job_domain)
	Analytics_RegisterAnalyticsJobDomainToFightModerate(job_domain)
	Analytics_RegisterGetKnownTheorizedEngageablesToPowerLevel(Analytics_GetKnownTheorizedEngageables)
	Analytics_RegisterDomainToVantage(captain_basic_domain, job_domain)
	Xeta_Initialize()
end

function Analytics_GetAnalyticsJobDomain()
	return job_domain
end

function Analytics_InformBuildingFell(gsiBuilding)
	Set_InformBuildingFell(gsiBuilding)
	VAN_InformDefensibleFell(gsiBuilding)
end
