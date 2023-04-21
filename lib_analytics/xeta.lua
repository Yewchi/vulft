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

-- Unbiseptium (Xeta) or Shard of Zet -- A currency to measure the worth of a fully or partially completed objective; a reward; or a setback.
-- 1 Xeta == 1 Gold.
-- 1 Xeta ~~ 9 Experience
-- 

local VALUE_OF_LANING_STAGE_CREEP_SET = 250 -- Updated from farm_lane
local EXP_VALUE_OF_LANING_STAGE_CREEP_SET = 25

local TEAM_VALUE_OF_TOWER_KILL_T1 = 570
local TEAM_VALUE_OF_TOWER_KILL_T4 = 900

local DENY_GOLD_TAKEN_PERCENT = 0.5 -- because they might've hit the last hit
local DENY_XP_TAKEN_PERCENT = 0.5 -- because 50% xp denied

XETA_SCORE_DO_NOT_RUN = -0xFFFF
XETA_SCORE_DO_NOT_RUN_SOFT = -0x0FFF

VALUE_OF_ONE_MANA = 50*0.6 / (6 * 30) -- (50g / (clarity mana))*(depreciation for 'dont-get-hit' cave-at)
VALUE_OF_ONE_HEALTH = 110*0.8 / (40*10) -- (110g / (healing salve health))*(depreciation for 'dont-get-hit' cave-at)

local max = math.max
local min = math.min
local sqrt = math.sqrt
local abs = math.abs
local persistent = {}

local team_players
local enemy_players

local fight_harass_task_handle

local FightHarass_GetHealthDiffOutnumbered

---- xeta constants --
local WALK_BACK_TO_VALUABLE_ACTION_AFTER_DEATH = 3 + 1
--

local function get_hero_kill_experience_points(dyingHero)
	-- Placeholder -- Could be fine, a decent quadratic approximation
	--print(dyingHero.name, "gives XP:", 4.87275 * GetHeroLevel(dyingHero.playerID)^2 + 28.2855 * GetHeroLevel(dyingHero.playerID) + 80.5824 + GSI_KillstreakXP(dyingHero))
	return 4.87275 * GetHeroLevel(dyingHero.playerID)^2 + 28.2855 * GetHeroLevel(dyingHero.playerID) + 80.5824 + GSI_KillstreakXP(dyingHero)
end

local function time_till_respawn(dyingHero)
	return dyingHero.hUnit:GetLevel() * 4 + 2
end

function Xeta_PassLaneWaveValue(xetaWave, xetaWaveExp)
	VALUE_OF_LANING_STAGE_CREEP_SET = xetaWave
	EXP_VALUE_OF_LANING_STAGE_CREEP_SET = xetaWaveExp
	--print("XETA SET", xetaWave, xetaWaveExp)
	Xeta_PassLaneWaveValue = nil
end

function Xeta_Initialize() 
	fight_harass_task_handle = FightHarass_GetTaskHandle() 
	FightHarass_GetHealthDiffOutnumbered = _G.FightHarass_GetHealthDiffOutnumbered
	team_players = GSI_GetTeamPlayers(TEAM)
	enemy_players = GSI_GetTeamPlayers(ENEMY_TEAM)
	Xeta_Initialize = nil 
end

-- Determines the value of a goal in a utopia game state (Nothing ever goes wrong) -- NB this is no longer true. This code is a mess.
-- Adjustments are to be made at higher levels for danger, and uncertainty.
-------- Xeta_EvaluateObjectiveCompletion(___)
-- taskFunc as listed above
-- taskTimeEstimate == estimated time to complete; 
-- fractionCompleted == the amount(s) of the task that will be completed.
-- agentOfTask == the player that will attempt the objective. (e.g. the xeta loss of a 10% health enemy Shadowfiend grabbing a regen rune, or the xeta gain of a set of heroes assisting an objective ("Should I hang around until the support wards?"))
-- targetOfObjective == a variable type, or table. Must conform to the taskFunc's treatment of the parameter. Assertions are currently avoided.
function Xeta_EvaluateObjectiveCompletion(taskFunc, taskTimeEstimate, fractionCompleted, agentOfTask, targetOfObjective)
	if type(taskFunc) == "function" then
		return (taskFunc(agentOfTask, targetOfObjective, taskTimeEstimate) * fractionCompleted) - Xeta_CostOfWaitingSeconds(agentOfTask, taskTimeEstimate)
	end
	return XETA_TASK_TYPE_NOT_FOUND() * fractionCompleted
end

function Xeta_EvaluateExperienceGain(gsiPlayer, experience)
	-- Placeholder -- 50% of gold->xp exchange of buying a tome (ass-apple) 
	-- 55 Xeta from experience for level 1 hero kill (about half of a level for a level 1 killing)
	-- Caps at 407 Xeta from experience for lvl 25 hero kill (about 1 level for a level 25 killing; experience from hero kills grows exponentially in relation to the level of hero killed)
	-- True value of a melee creep is 42.6 Xeta (37.5g)
	return experience * 0.11
end

function Xeta_CostOfWaitingSeconds(gsiPlayer, seconds)
	return seconds * GSI_GetPlayerGoldValueOfTime(gsiPlayer)
end

function Xeta_CostOfTravelToLocation(gsiPlayer, location)
	return Xeta_CostOfWaitingSeconds(gsiPlayer, Math_ETA(gsiPlayer, location))
end

function Xeta_SelfKillStored(p)
	if not p.time.data.selfKillValue then p.time.data.selfKillValue = XETA_HERO_KILL(p, p) end
	return p.time.data.selfKillValue
end

XETA_HERO_KILL = function(p, t) 
		--print( (30 + 1.038*(120 + 8 * GetHeroLevel(t.playerID)) ), GSI_KillstreakGold(t), (not GSI_FirstBloodTaken() and 135 or 0.0) + Xeta_EvaluateExperienceGain(p, get_hero_kill_experience_points(t)))
		return (30 + 1.038*(120 + 8 * GetHeroLevel(t.playerID)) + GSI_KillstreakGold(t)) + (not GSI_FirstBloodTaken() and 135 or 0.0) + Xeta_EvaluateExperienceGain(p, get_hero_kill_experience_points(t)) + GSI_GetPlayerGoldValueOfTime(p) * (time_till_respawn(t)+WALK_BACK_TO_VALUABLE_ACTION_AFTER_DEATH)
	end
XETA_CREEP_KILL = function(p, t) 
		return ((t.hUnit:GetBountyGoldMax() + t.hUnit:GetBountyGoldMin())/2) + Xeta_EvaluateExperienceGain(p, t.hUnit:GetBountyXP()) 
	end
XETA_CREEP_DENY = function(p, t)
		return ((t.hUnit:GetBountyGoldMax() + t.hUnit:GetBountyGoldMin())/2)*DENY_GOLD_TAKEN_PERCENT + Xeta_EvaluateExperienceGain(p, t.hUnit:GetBountyXP()*DENY_XP_TAKEN_PERCENT)
	end
XETA_LANE_WAVE_FARM = function (p, t)
		local totalValue = 0.0
		for creep,_ in pairs(t) do
			totalValue = totalValue + (creep.hUnit:GetBountyGoldMax() + creep.hUnit:GetBountyGoldMin())/2 + Xeta_EvaluateExperienceGain(p, creep.hUnit:GetBountyXP())
		end
		return totalValue
	end
XETA_HEALTH_GAIN = function(p, t)
		return XETA_HERO_KILL(p, t) * (1.0 - t.lastSeenHealth / t.maxHealth)
				/ max(t.lastSeenHealth, t.maxHealth/6)
	end
XETA_HEALTH_LOSS = function(p, t)
		return XETA_HERO_KILL(p, t) * (1.33 - 0.67*t.lastSeenHealth / t.maxHealth)
				/ max(t.lastSeenHealth, t.maxHealth/6)
	end
XETA_IMAGINARY_CREEP_SET_WAIT = function(p, t)
		 return 0.2*VALUE_OF_LANING_STAGE_CREEP_SET*p.vibe.greedRating
	end
XETA_RETURN_FOUNTAIN = function(p, t)
		local tripToFountainTime = Math_ETA(p, Map_GetTeamFountainLocation())
		local tripToFountainCost = Xeta_CostOfWaitingSeconds(p, tripToFountainTime)
		local lane = Team_GetRoleBasedLane(p)
		local laneFrontStored = Set_GetEnemyCreepSetLaneFrontStored(lane)
		local tripToLaneCost = Xeta_CostOfTravelToLocation(p, (laneFrontStored and laneFrontStored.center or Set_GetPredictedLaneFrontLocation(lane)))
		local timeSinceHeroDamage = p.hUnit:TimeSinceDamagedByAnyHero()
		local nearbyEnemies = Set_GetEnemyHeroesInPlayerRadius(p, 1350, 8)
		local nNearbyEnemies = #nearbyEnemies
		local extrapolatedHealthPercent = (p.lastSeenHealth + p.hUnit:GetHealthRegen()*max(min(8, timeSinceHeroDamage), tripToFountainTime)) / p.maxHealth -- basic checks for debuffs are good here to reduce regen benefit
		local theoreticalDangerScore = Analytics_GetTheoreticalDangerAmount(p)
		--[DEBUG]]if DEBUG and DEBUG_IsBotTheIntern() then print(string.format("%.2f + %.2f*%.2f - %.2f*%.2f*%.2f/%.2f", tripToLaneCost, max(0, (1 - sqrt(extrapolatedHealthPercent))), max(0, (Xeta_SelfKillStored(p) - tripToFountainCost)), VALUE_OF_LANING_STAGE_CREEP_SET, tripToFountainTime/30, max(0.65, min(extrapolatedHealthPercent, -nNearbyEnemies + timeSinceHeroDamage/2)), max(0.85,Analytics_GetTheoreticalDangerAmount(p)))) end
		return tripToLaneCost 
				+ max(0, (1 - sqrt(extrapolatedHealthPercent))) * max(0, (Xeta_SelfKillStored(p) - tripToFountainCost))
				- VALUE_OF_LANING_STAGE_CREEP_SET*(tripToFountainTime/30)*max(0.0, min(extrapolatedHealthPercent, -nNearbyEnemies + timeSinceHeroDamage/2))/max(0.85,select(1, theoreticalDangerScore))
	end
XETA_AVOID_AND_HIDE = function(p, t)
		local danger, knownE, theoryE = Analytics_GetTheoreticalDangerAmount(p)
		local intentToHarm, intentsTbl, numIntendHarm = FightClimate_AnyIntentToHarm(p, enemy_players)
		local harmFactor = (1.33 - Unit_GetHealthPercent(p)) + numIntendHarm*0.33
		local fightHarassScore = Task_GetTaskScore(p, fight_harass_task_handle)
		local selfKill = Xeta_SelfKillStored(p)
	--[[	print("XETA_AVOID_AND_HIDE", p.shortName, selfKill, numHeroesAttacking, damageRecorded, enemyMimicWonScore, -49 + numHeroesAttacking*Math_GetFastThrottledBounded(
				selfKill*(enemyMimicWonScore < 0 and enemyMimicWonScore*2 or enemyMimicWonScore),
			0, 350, 1000))--]]
		-- This '-49 + 350' is in balance to ability use's arbitrary magic score. i.e. horrible.
		local baseScore = danger
		if danger < 0 then
			baseScore = danger * 2
		end
		--[VERBOSE]if VERBOSE then VEBUG_print("XETA_AVOID_AND_HIDE", harmFactor, selfKill, baseScore) end
		return -49 + Math_GetFastThrottledBounded(
					harmFactor*selfKill*baseScore,
				--enemyMimicWonScore < 0 and -sqrt(abs(enemyMimicWonScore)) or enemyMimicWonScore),
			0, 200, 500) -- TODO FIX
	end
-- XETA_BONTY_RUNE -- DEFINED IN lib_task/rune.lua
XETA_PUSH = function(p, t)
		local dpsToBuilding = Lhp_GetActualFromUnitToUnitAttackOnce(p.hUnit, t.hUnit) / p.hUnit:GetSecondsPerAttack()
		--print("XETA_PUSH", p.shortName, t.goldBounty, t.lastSeenHealth, dpsToBuilding)
		return max(t.goldBounty, t.goldBounty*max(0.33, (dpsToBuilding*2)/t.lastSeenHealth)) -- safety checks are upper job
	end
XETA_TASK_TYPE_NOT_FOUND = function() 
		return 0.127 
	end

local named_score_tbl = {--[[{min, avg, max, age, nextallowedabscondtime, deltaallowed}]]}
local function abscond_named_score(name, score)
	local thisScoreTbl = named_score_tbl[name]
	if score < thisScoreTbl[1] then
		thisScoreTbl[1] = thisScoreTbl[1] - min(thisScoreTbl[1] - score, (thisScoreTbl[2] - thisScoreTbl[1]))/3
	elseif score > thisScoreTbl[3] then
		thisScoreTbl[3] = thisScoreTbl[3] + min(score - thisScoreTbl[3], (thisScoreTbl[3] - thisScoreTbl[2]))/3
	end
	thisScoreTbl[1] = thisScoreTbl[1] + (thisScoreTbl[2] - thisScoreTbl[1]) / 30
	thisScoreTbl[3] = thisScoreTbl[3] - (thisScoreTbl[3] - thisScoreTbl[2]) / 30
	thisScoreTbl[2] = thisScoreTbl[2] + (score - thisScoreTbl[2])/thisScoreTbl[4]
	thisScoreTbl[4] = thisScoreTbl[4] + 2 / thisScoreTbl[4]
	thisScoreTbl[5] = DotaTime() + thisScoreTbl[6]

	if thisScoreTbl[1] > thisScoreTbl[2] then
		thisScoreTbl[1] = thisScoreTbl[1] - 1.05*(thisScoreTbl[1] - thisScoreTbl[2])
	end
	if thisScoreTbl[3] < thisScoreTbl[2] then
		thisScoreTbl[3] = thisScoreTbl[3] + 1.05*(thisScoreTbl[2] - thisScoreTbl[3])
	end

	return thisScoreTbl[2]
end

function Xeta_RegisterAbscondScore(name, reasonableMin, reasonableAvg, reasonableMax, deltaAllowedTime)
	thisScoreTbl = {reasonableMin, reasonableAvg, reasonableMax, 1, DotaTime()+(nextAbscond or 0.167), nextAbscond or 0.167}
	named_score_tbl[name] =  thisScoreTbl
end

-- Return the score divided by the average score, the minimum seen, the maximum seen
-- - NB comparison data can be poisoned by poorly written/bounded algorithms e.g. 1/x
function Xeta_AbscondCompareNamedScore(name, score)
	local thisScoreTbl = named_score_tbl[name]
	if thisScoreTbl[5] < DotaTime() then
		abscond_named_score(name, score)

	end
	return 0.5 + (score < thisScoreTbl[2]
			and -0.5*(thisScoreTbl[2] - score)/(thisScoreTbl[2]-thisScoreTbl[1])
			or 0.5*(score - thisScoreTbl[2])/(thisScoreTbl[3]-thisScoreTbl[2]))
end
