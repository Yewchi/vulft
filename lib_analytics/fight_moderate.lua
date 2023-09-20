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

local UPDATE_FIGHT_MODERATE_THROTTLE = 0.307
local UPDATE_INITIATION_POWER_THROTTLE = 1.801

local job_domain

local ABILITY_TYPE = ABILITY_TYPE
local MAX_ABILITY_SLOTS = MAX_ABILITY_SLOTS
local Unit_GetArmorPhysicalFactor = Unit_GetArmorPhysicalFactor

local t_initiation_power = {}
local t_initiation_hierarchy = {}

local t_fight_delay = {}
local t_fight_incentive = {}
local t_acceptable_standing_range = {}

local BASE_INITIATION_FACTOR = 1

local t_ability_initiation_scores = {}

local B_AND = bit.band
local ABILITY_TYPE = ABILITY_TYPE

local t_item_initiation_power
local t_item_initiation_power_unindexed

function FightModerate_IfFightingGetInvolved(gsiPlayer, nearbyAllies, nearbyEnemies, alliedIntent, enemyIntent)
	if not nearbyAllies[1] or not nearbyEnemies[1] then
		return false -- There is no allied to fight / no enemy to be fought
	elseif not nearbyAllies[2] then
		return true 
	end
	if true then return waitIHaveAnIdea end
end

function Analytics_RegisterAnalyticsJobDomainToFightModerate(jobDomain)
	job_domain = jobDomain

	local usables = USABLE_ITEMS_FOR_INDEXING
	--#define initiation powers (arbitrarily, rate out of 5)
	t_item_initiation_power = {
			[usables["item_abyssal_blade"]] = 0.3,
			[usables["item_ancient_janggo"]] = 0.1,
			[usables["item_arcane_blink"]] = 0.3,
			[usables["item_black_king_bar"]] = 0.4,
			[usables["item_blade_mail"]] = 0.5,
			[usables["item_blink"]] = 0.3,
			[usables["item_bloodthorn"]] = 0.2,
			[usables["item_cheese"]] = 0.2,
			[usables["item_crimson_guard"]] = 0.3,
			[usables["item_cyclone"]] = 0.2,
			[usables["item_eternal_shroud"]] = 0.1,
			[usables["item_force_staff"]] = 0.1,
			[usables["item_glimmer_cape"]] = 0.1,
			[usables["item_gungir"]] = 0.2,
			[usables["item_heavens_halberd"]] = 0.2,
			[usables["item_hood_of_defiance"]] = 0.2,
			[usables["item_hurricane_pike"]] = 0.2,
			[usables["item_invis_sword"]] = 0.2,
--t_item_initiaton_power[usables["item_lotus_orb"]] = n/a as good on a glass cannon as it is on underlord if underlord is in range to cast on him,
			[usables["item_manta"]] = 0.2,
			[usables["item_nullifier"]] = 0.1,
			[usables["item_orchid"]] = 0.2,
			[usables["item_overwhelming_blink"]] = 0.5,
--t_item_initiaton_power[usables["item_pipe"]] = n/a same as lotus orb,
			[usables["item_sheepstick"]] = 0.2,
			[usables["item_shivas_guard"]] = 0.3,
			[usables["item_silver_edge"]] = 0.2,
--t_item_initiaton_power[usables["item_sphere"]] = n/a same as lotus orb, we are bots, not filthy humans: we cast linkens sphere intelligently,
			[usables["item_swift_blink"]] = 0.3,
			[usables["item_wind_waker"]] = 0.2
		}
	t_item_initiation_power_unindexed = {
		["item_aegis"] = 0.4,
		["item_aeon_disk"] = 0.3,
	}

	for i=1,TEAM_NUMBER_OF_PLAYERS do
		t_fight_delay[i] = 0
		t_fight_incentive[i] = 0
		t_acceptable_standing_range[i] = 0
	end

	local team_players = GSI_GetTeamPlayers(TEAM)

	job_domain:RegisterJob(function(workingSet)
				local t_initiation_hierarchy = t_initiation_hierarchy
				local TEAM_NUMBER_OF_PLAYERS = TEAM_NUMBER_OF_PLAYERS
				local t_initiation_power = t_initiation_power
				if workingSet.initiatorThrottle:allowed() then
					for i=1,TEAM_NUMBER_OF_PLAYERS do
						t_initiation_hierarchy[i] = nil
					end
					-- Update initiation power hierarchy
					local Armor = Unit_GetArmorPhysicalFactor
					local t_item_initiation_power = t_item_initiation_power
					local t_item_initiation_power_unindexed = t_item_initiation_power_unindexed
					local BASE_INITIATION_FACTOR = BASE_INITIATION_FACTOR
					for i=1,TEAM_NUMBER_OF_PLAYERS do
						local thisPlayer = team_players[i]
						local itemCache = thisPlayer.usableItemCache
						local netInitiationFactor = BASE_INITIATION_FACTOR
						for cacheKey,item in pairs(itemCache) do
							netInitiationFactor = netInitiationFactor + (t_item_initiation_power[cacheKey] or 0)
						end
						for k=1,#t_item_initiation_power_unindexed do
							netInitiationFactor = netInitiationFactor
									+ (itemCache[t_item_initiation_power_unindexed[k]] or 0)
						end
						for k=1,#t_ability_initiation_scores do
							local thisAbilityInitiationTbl = t_ability_initiation_scores[k]
							if thisAbilityInitiationTbl[1]:IsTrained() then
								netInitiationFactor = netInitiationFactor + thisAbilityInitiationTbl[2]
							end
						end
						local healthPercent = gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth
						local effectiveHealth = gsiPlayer.ehpArmor * (gsiPlayer.lastSeenHealth
								+ healthPercent*5*(gsiPlayer.hUnit:GetHealthRegen()^1.2)
							)
						local thisInitiationPower = effectiveHealth * netInitiationFactor
						t_initiation_power[i] = thisInitiationPower
						-- Insert sorted the PNOT for initiation power hierarchy
						local k=1
						local limitK = TEAM_NUMBER_OF_PLAYERS+1-i
						while(k<=limitK) do
							local comparedPnot = t_initiation_hierarchy[k]
							if comparedPnot then
								if thisInitiationPower > t_initiation_power[comparedPnot] then
									table.insert(t_initiation_hierarchy, k, i)
								end
							else
								t_initiation_hierarchy[k] = i -- ;;;
							end
							k = k + 1
						end
					end
				end
				if workingSet.throttle:allowed() then
					-- Determine group of heroes defending a tower

					-- Determine and flag heroes respawning soon that should be included.

					-- Exclude heroes from defending group if they will not arrive before
					-- -| the tower is destroyed.

					-- Determine if the fight might be favourable

					-- Update fight delays and incentives

				end
			end,
			{ ["throttle"] = Time_CreateThrottle(UPDATE_FIGHT_MODERATE_THROTTLE),
				["initiatorThrottle"] = Time_CreateThrottle(UPDATE_INITIATION_POWER_THROTTLE)},
			"JOB_FIGHT_MODERATE_UPDATE"
		)

	Analytics_RegisterAnalyticsJobDomainToFightModerate = nil
end

function FightModerate_InformAbilityForInitiationScores(gsiPlayer, abilityData)
	local playerInitiationScores = t_ability_initiation_scores[gsiPlayer.nOnTeam] or {}
	if not playerInitiationScores[1] then
		t_ability_initiation_scores[gsiPlayer.nOnTeam] = playerInitiationScores
	end
	
	-- Add the ability to the playerInitiationScores table
	local thisAbility = gsiPlayer.hUnit:GetAbilityByName(abilityData[1])
	if not thisAbility then
		playerInitiationScores[#playerInitiationScores+1] = {nil, 0}
	end
	playerInitiationScores[#playerInitiationScores+1] = {thisAbility, abilityData[3] or 0}
end
