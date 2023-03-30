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

local URN_NAME = "item_urn_of_shadows"
local SV_NAME = "item_spirit_vessel"

local URN_HEAL = 240
local URN_DMG = 200
local SV_HEAL = 320
local SV_BASE_DMG = 280
local SV_PERC_DMG = 0.2786 -- source: fandom. This is the from 100% health dmg on a unit with infinite health
-- - - and no health regen.
local SV_PERC_TICK = 0.04
local SV_REGEN_REDUCTION = 0.45
local SV_REGEN_REDUCTION_FACTOR = 1 / (1 + SV_REGEN_REDUCTION) -- TODO test

local max = math.max
local min = math.min

local CAST_SUCCESS = AbilityLogic_CastOnTargetWillSucceed
local PIERCES = AbilityLogic_PierceTeamRelationFlagsPossible

local INSTANT_CONSIDERATION = 250

local XETA_SCORE_DO_NOT_RUN = XETA_SCORE_DO_NOT_RUN
local VALUE_OF_ONE_HEALTH = VALUE_OF_ONE_HEALTH

local fight_harass_handle

function UrnLogic_Initialize()
	fight_harass_handle = FightHarass_GetTaskHandle()
end

-- TODO item indexing in item_logic or some additional indexing module would help
local function get_sv(gsiPlayer)
	local hPlayer = gsiPlayer.hUnit
	local hAbility = hPlayer:FindItemSlot(SV_NAME)
	return hAbility and hPlayer:GetItemInSlot(hAbility) or false
end

local function get_urn(gsiPlayer)
	local hPlayer = gsiPlayer.hUnit
	local hAbility = hPlayer:FindItemSlot(URN_NAME)
	return hAbility and hPlayer:GetItemInSlot(hAbility) or false
end

local function score_sv_dmg(gsiPlayer, gsiTarget, hAbility)
	-- NB.assert(notSameTeam)
	local hTarget = gsiTarget.hUnit
	if Unit_IsNullOrDead(gsiTarget) then 
		return false, 0
	end

	if hTarget:IsMagicImmune()
			and not PIERCES(
				false,
				hAbility:GetTargetFlags()
			) then
		return false, 0
	end

	-- TODO Algebraic with 0% health limited %ge damage solution?
	local health = gsiTarget.lastSeenHealth
	local dmg = 0
	local healthRegen = hTarget:GetHealthRegen()
	-- I think if the hero has increased health regen %ge, the reduction is related to
	-- - the original health regen value, meaning there is less reduction.
	-- - this would make sense with a "limited health regen mod of -%100"
	-- - Meaning, the values below for health regen are wrong, but I need more understanding
	-- - of enemy querying. 
	local healthRegenApplied = healthRegen * SV_REGEN_REDUCTION_FACTOR
	local magicResFactor = 1 - hTarget:GetMagicResist()
	for i=1,8 do
		local thisDmg = magicResFactor * (
				SV_BASE_DMG + max(1, health*SV_PERC_DMG*health/gsiTarget.maxHealth)
			)
		health = health - thisDmg + healthRegenApplied
		dmg = dmg + thisDmg
	end
	
	local score = (dmg + 8*healthRegen*SV_REGEN_REDUCTION_FACTOR) * VALUE_OF_ONE_HEALTH
			* (1.33 - 0.66*gsiTarget.lastSeenHealth / gsiTarget.maxHealth)

	return true, dmg
end
local function score_sv_heal(gsiPlayer, gsiTarget, hAbility)
	-- NB. assert(sameTeam)
	if Unit_IsNullOrDead(gsiTarget) then
		return false, 0
	end
	return gsiTarget.hUnit:IsMagicImmune()
			and not PIERCES(true, hAbility:GetTargetFlags())
			and false, 0
			or true, min(SV_HEAL, gsiTarget.maxHealth - gsiTarget.lastSeenHealth)
end

local function score_urn_dmg(gsiPlayer, gsiTarget, hAbility)
	local hTarget = gsiTarget.hUnit
	if Unit_IsNullOrDead(gsiTarget) then 
		return false, 0
	end

	if hTarget:IsMagicImmune()
			and not PIERCES(
				false,
				hAbility:GetTargetFlags()
			) then
		return false, 0
	end

	return true, (1 - hTarget:GetMagicResist())*URN_DMG*VALUE_OF_ONE_HEALTH
			* (1.33 - 0.66*gsiTarget.lastSeenHealth / gsiTarget.maxHealth)
end
local function score_urn_heal(gsiPlayer, gsiTarget, hAbility)
	if Unit_IsNullOrDead(gsiTarget) then
		return false, 0
	end
	return PIERCES(true, hAbility:GetTargetFlags())
			and true,
				min(SV_HEAL, gsiTarget.maxHealth - gsiTarget.lastSeenHealth)
			or false, 0
end

------- //  ANALYTICAL  //
function UrnLogic_ScoreUrnVessel(gsiPlayer, nearbyEnemies, nearbyAllies)
	-- TODO
	local scoreFuncDmg
	local scoreFuncHeal
	local urn = get_sv(gsiPlayer)
	if urn then
		scoreFuncDmg = score_sv_dmg
		scoreFuncHeal = score_sv_heal
	else
		urn = get_urn(gsiPlayer)
		if urn then
			scoreFuncDmg = score_urn_dmg
			scoreFuncHeal = score_sv_heal
		end
	end
	if not urn then return false, XETA_SCORE_DO_NOT_RUN end
	local castRange = urn:GetCastRange()
	nearbyEnemies = nearbyEnemies or Set_GetEnemyHeroesInPlayerRadius(gsiPlayer, castRange*1.4, 0)
	nearbyAllies = nearbyAllies or Set_GetAlliedHeroesInPlayerRadius(gsiPlayer, castRange*1.4, 0)
	-- local registeredDamageTbl = DmgReg_GetEnemies() TODO
	local highestScore = 0
	local highestTarget
	local charges = urn:GetCurrentCharges()
	local fht = Task_GetTaskObjective(gsiPlayer, fight_harass_handle)
	for i=1,#nearbyEnemies do
		local hasEffect, thisScore = scoreFuncDmg(gsiPlayer, nearbyEnemies[i], urn)
		if hasEffect and thisScore > highestScore then
			highestScore = thisScore
			highestTarget = nearbyEnemies[i]
		end
		-- if registeredDamageTbl[thisEnemy.nOnTeam] < URN_DMG*2.5 then TODO
	end
	for i=1,#nearbyAllies do

	end
	return highestTarget, highestScore + INSTANT_CONSIDERATION, urn
end
