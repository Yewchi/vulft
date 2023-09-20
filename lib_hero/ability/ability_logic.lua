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

require(GetScriptDirectory().."/lib_hero/ability/damage_tracker")

local B_AND = bit.band
local min = math.min
local max = math.max

ABILITY_TYPE = {
		["UNIT_TARGET"] = 		0x000001,
		["POINT_TARGET"] =		0x000002,
		["SINGLE_TARGET"] =		0x000004,
		["FRIENDLY_TARGET"] =	0x000008,
		["ENEMY_TARGET"] =		0x000010,
		["NUKE"] =				0x000020,
		["STUN"] =				0x000040, -- nb. additionalEffectIndication \/
		["SLOW"] =				0x000080, -- ''
		["ROOT"] =				0x000100, -- ''
		["DEGEN"] =				0x000200, -- nb. additionalEffectIndication ^^
		["BUFF"] =				0x000400,
		["HEAL"] =				0x000800,
		["SHIELD"] =			0x001000,
		["UTILITY"] =			0x002000,
		["MOBILITY"] =			0x004000,
		["CHAIN"] =				0x008000,
		["AOE"] =				0x010000,
		["SMITE"] =				0x020000,
		["PASSIVE"] =			0x040000,
		["SUMMON"] =			0x080000,
		["TOGGLE"] =			0x100000,
		["ATTACK_MODIFIER"] =	0x200000,
		["SECONDARY"] =			0x400000,
		["INVIS"] =				0x800000,
}

local function get_ability_vulft_flags(hAbility)
	--[[ TODO TODO TODO
	local bFlags = hAbility:GetBehavior()
	local targFlags = hAbility:GetTargetFlags()
	local damage = hAbility:GetSpecialValueFloat("damage")
	local teamFlags = hAbility:GetTargetTeam()
	damage = damage > 0 and damage or hAbility:GetSpecialValueFloat("damage_per_second")
	damage = damage > 0 and damage or hAbility:GetSpecialValueFloat("hit_damage")
	damage = damage > 0 and damage or hAbility:GetSpecialValueFloat("dps")
	damage = damage > 0 and damage or hAbility:GetSpecialValueFloat("base_damage")
	local slow = hAbility:GetSpecialValueFloat("slow")
	slow = slow > 0 and slow or hAbility:GetSpecialValueFloat("movement_slow")
	slow = slow > 0 and slow or hAbility:GetSpecialValueFloat("move_slow_pct")
	slow = slow > 0 and slow or hAbility:GetSpecialValueFloat("move_speed_slow_pct")
	slow = slow > 0 and slow or hAbility:GetSpecialValueFloat("slow_duration")
	slow = slow > 0 and slow or hAbility:GetSpecialValueFloat("slow_movement_speed_pct")
	local degen = slow > 0 and slow or hAbility:GetSpecialValueFloat("silence_duration")
	degen = degen > 0 and degen or hAbility:GetSpecialValueFloat("silence")
	degen = degen > 0 and degen or hAbility:GetSpecialValueFloat("attack_damage_reduction")
	degen = degen > 0 and degen or hAbility:GetSpecialValueFloat("armor_reduction")
	degen = degen > 0 and degen or hAbility:GetSpecialValueFloat("damage_reduction")
	degen = degen > 0 and degen or hAbility:GetSpecialValueFloat("attack_speed_reduction")
	degen = degen > 0 and degen or hAbility:GetSpecialValueFloat("attack_speed_slow")
	degen = degen > 0 and degen or hAbility:GetSpecialValueFloat("spell_resistance_reduction")
	degen = degen > 0 and degen or hAbility:GetSpecialValueFloat("magic_resistance_reduction")
	degen = degen > 0 and degen or hAbility:GetSpecialValueFloat("health_reduction")
	degen = degen > 0 and degen or hAbility:GetSpecialValueFloat("heal_reduction")
	degen = degen > 0 and degen or hAbility:GetSpecialValueFloat("regen_reduction_pct")
	degen = degen > 0 and degen or damage == 0 and heal == 0 and hAbility:GetSpecialValueFloat("duration") and 1 or 0
	local stun = hAbility:GetSpecialValueFloat("stun")
	stun = stun > 0 and stun or hAbility:GetSpecialValueFloat("stun_duration")
	blahreturn (B_AND(ABILITY_BEHAVIOR_UNIT_TARGET, behavior) > 0 and ABILITY_BEHAVIOR_UNIT_TARGET or 0)
		+ (B_AND(ABILITY_BEHAVIOR_POINT, behavior) > 0 and ABILITY_BEHAVIOR_POINT or 0)
		+ hAbility:GetSpecialValueFloat("damage") > 0 and 
	]]
end


local FINAL_ABILITY_FIELD = ABILITY_TYPE.SECONDARY

local ABILITY_I__ABILITY_NAME = ABILITY_I__ABILITY_NAME
local ABILITY_I__ABILITY_BIT_FLAGS = ABILITY_I__ABILITY_BIT_FLAGS
local ABILITY_I__H_ABILITY = ABILITY_I__H_ABILITY
local ABILITY_I__ADDITIONAL_FLAGS = ABILITY_I__ADDITIONAL_FLAGS

local FLAGS2_I__HAS_DEGEN = 1
local FLAGS2_I__PIERCES_IMMUNITY = 2
local FLAGS2_I__IGNORES_EVASION = 3

local TOTAL_TALENT_CHOICES = TOTAL_TALENT_CHOICES

local MAX_ABILITY_SLOT = MAX_ABILITY_SLOT
local MAX_ABILITY_POINTS = 19
local END_SKILL_UPS_LEVEL = 25
---- ability_logic constants --
local t_ability_index = {}

local t_nuke = {}
local t_stun = {}
local t_slow = {}
local t_root = {}
local t_degen = {}
local t_buff = {}
local t_heal = {}
local t_shield = {}
local t_mobility = {}
local t_aoe = {}
local t_smite = {}
local t_summon = {}
local t_attack_mod = {}
local t_invis = {}

local t_spammable_ranked = {}
local t_spammable_aoe_ranked = {}
local t_defensive_ranked = {}
local t_save_ranked = {} -- i.e. oracle's ult, venge swap
local t_tempo_switch_ranked = {}
local t_dps_ranked = {} -- i.e. ranked by what you'd pick first on rosh with no spell block and hero resistances

local warn_limit_ability_unknown = 5
--

local empty_func = function() end
local AMMEND_TYPE_FUNCS = {
	empty_func, -- UNIT_TARGET
	empty_func, -- POINT_TARGET
	empty_func, -- SINGLE_TARGET
	empty_func, -- FRIENDLY_TARGET
	empty_func, -- ENEMY_TARGET
	function(gsiPlayer, ability) table.insert(t_nuke[gsiPlayer.team][gsiPlayer.nOnTeam], ability) end, -- NUKE
	function(gsiPlayer, ability) table.insert(t_stun[gsiPlayer.team][gsiPlayer.nOnTeam], ability) end, -- STUN
	function(gsiPlayer, ability) table.insert(t_slow[gsiPlayer.team][gsiPlayer.nOnTeam], ability) end, -- SLOW
	function(gsiPlayer, ability) table.insert(t_root[gsiPlayer.team][gsiPlayer.nOnTeam], ability) end, -- ROOT
	function(gsiPlayer, ability) table.insert(t_degen[gsiPlayer.team][gsiPlayer.nOnTeam], ability) end, -- DEGEN
	function(gsiPlayer, ability) table.insert(t_buff[gsiPlayer.team][gsiPlayer.nOnTeam], ability) end, -- BUFF
	function(gsiPlayer, ability) table.insert(t_heal[gsiPlayer.team][gsiPlayer.nOnTeam], ability) end, -- HEAL
	function(gsiPlayer, ability) table.insert(t_shield[gsiPlayer.team][gsiPlayer.nOnTeam], ability) end, -- SHIELD
	empty_func, -- UTILITY
	function(gsiPlayer, ability) table.insert(t_mobility[gsiPlayer.team][gsiPlayer.nOnTeam], ability) end, -- MOBILITY
	empty_func, -- CHAIN
	function(gsiPlayer, ability) table.insert(t_aoe[gsiPlayer.team][gsiPlayer.nOnTeam], ability) end, -- AOE
	function(gsiPlayer, ability) table.insert(t_smite[gsiPlayer.team][gsiPlayer.nOnTeam], ability) end, -- SMITE
	empty_func, -- PASSIVE
	function(gsiPlayer, ability) table.insert(t_summon[gsiPlayer.team][gsiPlayer.nOnTeam], ability) end, -- SUMMON
	empty_func, -- TOGGLE
	function(gsiPlayer, ability) table.insert(t_attack_mod[gsiPlayer.team][gsiPlayer.nOnTeam], ability) end, -- ATTACK_MODIFIER
	empty_func, -- SECONDARY
	function(gsiPlayer, ability) table.insert(t_invis[gsiPlayer.team][gsiPlayer.nOnTeam], ability) end, -- INVIS
}


local t_skill_build_order_next = {}
local t_ability_snapshot = {}

local ability_points_total_at_level = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 16, 17, 17, 18, 18, 18, 18, 18, 19, 19, 19, 19, 19, 19}
local talent_tree_required_lowereq = {[14]=6, [19]=8, [24]=10} -- at lvl 14 you must've skilled 6|5. at lvl 19 8|7

local function try_create_valid_build_order(gsiPlayer, skillBuildsTbl) -- Ensures the build order has upgradable skill slot numbers, if able (and ever needed).
	local pUnit = gsiPlayer.hUnit
	local upgradableAbilities = {}
	for i=1,MAX_ABILITY_SLOT,1 do
		local ability = pUnit:GetAbilityInSlot(i-1)
		if not ability then
			break
		end
		print("/VUL-FT/", ability:GetName(), gsiPlayer.shortName, ability:CanAbilityBeUpgraded(), ability:GetBehavior(), ability:GetHeroLevelRequiredToUpgrade())
		if not ability:IsHidden() and not ability:IsStolen()
				and B_AND(ability:GetBehavior(), ABILITY_BEHAVIOR_NOT_LEARNABLE) == 0
				and (
					ability:GetLevel() >= 3 
					or (ability:GetHeroLevelRequiredToUpgrade() < 31 and ability:GetHeroLevelRequiredToUpgrade() > 0)
				) and ( -- MAGIC_NEVERMORE
					not gsiPlayer.name == "nevermore" 
					or not (string.find(ability:GetName(), "raze2") or string.find(ability:GetName(), "raze3"))
				) then
			if #upgradableAbilities < 4 or string.find(ability:GetName(), "special_bonus") then -- e.g. don't add "sun_strike"
				upgradableAbilities[#upgradableAbilities+1] = i-1
			end
		elseif VERBOSE then
			INFO_print("-- Skipping ability", ability:GetName(), i-1, "requires lvl#",
					ability:GetHeroLevelRequiredToUpgrade(), ability:CanAbilityBeUpgraded(), ability:GetLevel()
				)
		end
	end
	local numUpgradableAbilities = #upgradableAbilities
	local talentOrder = {
			numUpgradableAbilities-6, numUpgradableAbilities-4,
			numUpgradableAbilities-2, numUpgradableAbilities
		}
	for i=1,4 do
		if not pUnit:GetAbilityInSlot(talentOrder[i]):CanAbilityBeUpgraded() then
			print("Switching", i, " ", pUnit:GetAbilityInSlot(talentOrder[i]):GetLevel())
			talentOrder[i] = talentOrder[i]-1
		end
	end
	if #upgradableAbilities >= 11 or (gsiPlayer.shortName == "invoker" and #upgradableAbilities == 10) then -- Hard-coded here for hard-coded below
	 -- assumes upgradable abilities will be 1-4, 1-4, 1-4, 1-3, 2-talent choice*4
		skillBuildsTbl[gsiPlayer.nOnTeam] = {
				upgradableAbilities[1], upgradableAbilities[2], upgradableAbilities[3], 
				upgradableAbilities[1], upgradableAbilities[2], upgradableAbilities[4],
				upgradableAbilities[3], upgradableAbilities[1], upgradableAbilities[2],
				talentOrder[1], upgradableAbilities[3], upgradableAbilities[4],
				upgradableAbilities[1], upgradableAbilities[2], talentOrder[2],
				upgradableAbilities[3],--[[17]]upgradableAbilities[4],--[[19]]
				talentOrder[3],--[[21 - 24]] talentOrder[4] --[[26 - 30]]
			}
		INFO_print(string.format("[ability_logic]: skill build for %s is auto-generated and may be invalid.", gsiPlayer.shortName))
	elseif DEBUG then
		DEBUG_print(string.format("[ability_logic]: failed to auto-generate valid skill up build for '%s.'", gsiPlayer.shortName))
	end
	if VERBOSE then
		local thisSkillBuild = skillBuildsTbl[gsiPlayer.nOnTeam]
		for i=1,#thisSkillBuild do
			VEBUG_print(
					string.format("[ability_logic] skills %d %s at level %d",
						thisSkillBuild[i],
						pUnit:GetAbilityInSlot(thisSkillBuild[i]):GetName(),
						i
					)
				)
		end
	end
	-- Check if skill build will have impossible skill ups
end

local function create_unknown_ability_index(hAbility)
	local name = hAbility and hAbility.GetName and hAbility:GetName()
	--[[ TODO TODO TODO
	if name and abilityFlags then
		local newAbiiltyData = {name, 0, nil,
				{AbilityLogic_AbilityHasAdditionalEffect(hAbility), -- it's false atm
					B_AND(hAbility:GetTargetFlags(), ABILITY_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES) > 0,
					not (B_AND(hAbility:GetTargetFlags(), ABILITY_TARGET_FLAG_NOT_ATTACK_IMMUNE) > 0)
				}
			}
		return newAbilityData
	end
	if warn_limit_ability_index_unknown > 0 then
		WARN_print(string.format("[ability_logic] attempt to create ability data for unknown ability failed. Name: '%s'",
					type(hAbility) ~= "table" and type(hAbility) ~= "userdata" and type(hAbility)
					or not hAbility.GetName and "none"
					or hAbility:GetName()
				)
			)
		warn_limit_ability_index_unknown = warn_limit_ability_index_unknown - 1
	end
	]]
	if not name then
		return false
	end
	local newAbilityData = {name, 0, nil, {false, false, false}}
	t_ability_index[hAbility] = newAbilityData
	return newAbilityData
end

function AbilityLogic_Initialize()
	for i=TEAM_RADIANT,TEAM_DIRE,1 do
		t_nuke[i] = {}
		t_stun[i] = {}
		t_slow[i] = {}
		t_root[i] = {}
		t_degen[i] = {}
		t_buff[i] = {}
		t_heal[i] = {}
		t_shield[i] = {}
		t_mobility[i] = {}
		t_aoe[i] = {}
		t_smite[i] = {}
		t_summon[i] = {}
		t_attack_mod[i] = {}
		t_invis[i] = {}
		local numberPlayers = (i==TEAM and TEAM_NUMBER_OF_PLAYERS or ENEMY_TEAM_NUMBER_OF_PLAYERS)
		for pnot=1,numberPlayers do
			t_nuke[i][pnot] = {}
			t_stun[i][pnot] = {}
			t_slow[i][pnot] = {}
			t_root[i][pnot] = {}
			t_degen[i][pnot] = {}
			t_buff[i][pnot] = {}
			t_heal[i][pnot] = {}
			t_shield[i][pnot] = {}
			t_mobility[i][pnot] = {}
			t_aoe[i][pnot] = {}
			t_smite[i][pnot] = {}
			t_summon[i][pnot] = {}
			t_attack_mod[i][pnot] = {}
			t_invis[i][pnot] = {}
			if i==TEAM then
				t_spammable_ranked[pnot] = {}
				t_spammable_aoe_ranked[pnot] = {}
				t_defensive_ranked[pnot] = {}
				t_save_ranked[pnot] = {}
				t_tempo_switch_ranked[pnot] = {}
				t_dps_ranked[pnot] = {}
				t_ability_snapshot[pnot] = {}
			end
		end
	end

	AbilityLogic_RegisterGenericsModule()
end

function AbilityLogic_TryConfirmValidSkillBuild(gsiPlayer, skillBuildsTbl)
	local skillBuild = skillBuildsTbl[gsiPlayer.nOnTeam]
	local hUnit = gsiPlayer.hUnit
	for i=1,#skillBuild,1 do
		local thisAbility = hUnit:GetAbilityInSlot(skillBuild[i])
		--[VERBOSE]]if VERBOSE and thisAbility then VEBUG_print(string.format("Checking ability %s #%d. Requires lvl:%d %s %d %s", thisAbility:GetName(), i, thisAbility:GetHeroLevelRequiredToUpgrade(), thisAbility:CanAbilityBeUpgraded(), thisAbility:GetLevel(), thisAbility:IsHidden())) end
		if not AbilityLogic_IsLikelyAbilityPointInvestibleType(thisAbility) then
			--[[DEBUG]]if DEBUG then DEBUG_print(string.format("[ability_logic] failing on i=%d value '%s':... ", i, Util_Printable(skillBuild[i]))) DEBUG_print(string.format("ability_logic: %s skill build failed on check for %s, index %d. Trained:%s. Upgradable: %s. <31:%s. required level: %d. visible: %s. !(!Learnable): %s", gsiPlayer.shortName, thisAbility and thisAbility:GetName(), skillBuild[i], thisAbility and thisAbility:IsTrained(), thisAbility and thisAbility:CanAbilityBeUpgraded(), thisAbility and thisAbility and thisAbility:GetHeroLevelRequiredToUpgrade() < 31, thisAbility and thisAbility:GetHeroLevelRequiredToUpgrade() or -1, thisAbility and not thisAbility:IsHidden(), thisAbility and B_AND(thisAbility:GetBehavior(), ABILITY_BEHAVIOR_NOT_LEARNABLE) == 0)) end
			try_create_valid_build_order(gsiPlayer, skillBuildsTbl)
			return
		end
	end
	--[VERBOSE]]if VERBOSE then VEBUG_print(string.format("ability_logic: %s skill build looks valid.", gsiPlayer.shortName)) end
end

local squelch_after = HIGH_32_BIT
function AbilityLogic_SetCurrentSkillBuildIndex(gsiPlayer, skillBuildTbl) -- helps with reloads or restore behavior after an error
	local skillBuild = skillBuildTbl[gsiPlayer.nOnTeam]
	local nthSkillUp = 1
	local abilityPointsAllocatedTo = {}
	--print(gsiPlayer.shortName, Util_PrintableTable(skillBuild))
	if not skillBuild or not skillBuild[1] --[[or not skillBuild[MAX_ABILITY_POINTS] ]]then -- TEMP FIX
		AbilityLogic_TryConfirmValidSkillBuild(gsiPlayer, skillBuildTbl)
		if not skillBuild or not skillBuild[1] or not skillBuild[MAX_ABILITY_POINTS] then
			if RealTime() < squelch_after then 
				print("/VUL-FT/ <WARN> ability_logic: Cannot create skill up order for", gsiPlayer.shortName, gsiPlayer.playerID)
				--next_unable_to_get_skills_warn[gsiPlayer.nOnTeam] = RealTime() + 0.005
			end
			return
		end
	end
	local startingBonusIndex
	local startingBonusIsOdd
	for i=MAX_ABILITY_POINTS,0,-1 do
		local ability = gsiPlayer.hUnit:GetAbilityInSlot(i)
		if ability and string.find(ability:GetName(), "special_bonus") then
			startingBonusIndex = i - TOTAL_TALENT_CHOICES
			startingBonusIsOdd = startingBonusIndex % 2 == 1
		end
	end
	if gsiPlayer.shortName == "invoker" then Util_TablePrint(skillBuild) for i=0,23 do local a = gsiPlayer.hUnit:GetAbilityInSlot(i) if a then --[[print(a:GetName(), i)--]] end end end
	for i=1,MAX_ABILITY_POINTS,1 do
		local thisAbilitySpendSlot = skillBuild[i]
		if thisAbilitySpendSlot then
			abilityPointsAllocatedTo[thisAbilitySpendSlot] = abilityPointsAllocatedTo[thisAbilitySpendSlot] ~= nil and 
					abilityPointsAllocatedTo[thisAbilitySpendSlot] + 1 or 1
			if abilityPointsAllocatedTo[thisAbilitySpendSlot]
					> gsiPlayer.hUnit:GetAbilityInSlot(thisAbilitySpendSlot):GetLevel() then
				if i < startingBonusIndex then
					local sameRowTalent = (i % 2 == 1 and startingBonusIsOdd
							or i % 2 == 0 and not startingBonusIsOdd) and i+1 or i-1
					sameRowTalent = gsiPlayer.hUnit:GetAbilityInSlot(sameRowTalent)
					if sameRowTalent and sameRowTalent:GetLevel() > 0 then
						goto NEXT_SKILL_UP;
					end
				end
				--print(gsiPlayer.shortName, "skillUp #:", i, "is", abilityPointsAllocatedTo[thisAbilitySpendSlot], "th", gsiPlayer.hUnit:GetAbilityInSlot(thisAbilitySpendSlot):GetName())
				t_skill_build_order_next[gsiPlayer.nOnTeam] = i
				return
			end
		else
			print(string.format("/VUL-FT/ <WARN> ability_logic: did not complete 19-point skill build. Failed at index-%d", i))
		end
		::NEXT_SKILL_UP::
		--[[VERBOSE]]if VERBOSE then local vAbility = thisAbilitySpendSlot and gsiPlayer.hUnit:GetAbilityInSlot(thisAbilitySpendSlot) VEBUG_print(string.format("ability_logic: %s already leveled %s, %s.", gsiPlayer.shortName, skillBuild[i], vAbility and vAbility:GetName())) end
	end
end

function AbilityLogic_UpdateSnapshotFindLeveled(gsiPlayer, dryRun)
	local snapshot = t_ability_snapshot[gsiPlayer.nOnTeam]
	local hUnit = gsiPlayer.hUnit
	for i=0,MAX_ABILITY_SLOT do
		local thisAbility = hUnit:GetAbilityInSlot(i)
		if not thisAbility then return end
		if snapshot[i] ~= thisAbility:GetLevel() then
			snapshot[i] = thisAbility:GetLevel()
			if not dryRun then
				return i
			end
		end
	end
end

function AbilityLogic_HandleLevelAbility(gsiPlayer, skillBuild)
	local pUnit = gsiPlayer.hUnit
	local abilityPoints = pUnit:GetAbilityPoints()
	local nextAbilityIndex = t_skill_build_order_next[gsiPlayer.nOnTeam]

	if not skillBuild[nextAbilityIndex] or gsiPlayer.level == 30
			and not gsiPlayer.skillsFull then
		local ability = gsiPlayer.hUnit:GetAbilityInSlot(5) -- Could be ultimate slot
		if ability then
			pUnit:ActionImmediate_LevelAbility(ability:GetName())
		end
		for i=0,MAX_ABILITY_SLOT do
			ability = gsiPlayer.hUnit:GetAbilityInSlot(i)
			if ability and ability:CanAbilityBeUpgraded() then
				pUnit:ActionImmediate_LevelAbility(ability:GetName())
			end
		end
		gsiPlayer.skillsFull = gsiPlayer.level == 30
	end
	if abilityPoints == 0 then return end
	local level = pUnit:GetLevel()
	local nOnTeam = gsiPlayer.nOnTeam
	local abilitySlot = skillBuild[nextAbilityIndex]
	--print(gsiPlayer.shortName, Util_PrintableTable(skillBuild), Util_PrintableTable(t_skill_build_order_next[gsiPlayer.nOnTeam]))
	if abilitySlot then
		local ability = pUnit:GetAbilityInSlot(
				abilitySlot)
		if ability == nil then 
			for i=0,23 do local a = pUnit:GetAbilityInSlot(i) if a then print(a:GetName()) end end
			local skillBuildTbl = Ability_GetSkillBuildTable()
		end
		if AbilityLogic_UpdateSnapshotFindLeveled(gsiPlayer) == abilitySlot then
			ChargedCooldown_CheckChargesSetMax(gsiPlayer, ability) -- bounces back if not listed
			t_skill_build_order_next[gsiPlayer.nOnTeam] = t_skill_build_order_next[gsiPlayer.nOnTeam] + 1
			if gsiPlayer.InformLevelUpSuccess then
				gsiPlayer:InformLevelUpSuccess()
				return;
			end
		elseif ability:CanAbilityBeUpgraded() then
			local preLevel = ability:GetLevel()
			INFO_print(string.format("%s upgrades %s @ %d",
						gsiPlayer.shortName,
						ability:GetName(),
						t_skill_build_order_next[gsiPlayer.nOnTeam]
					)
				)
			pUnit:ActionImmediate_LevelAbility(ability:GetName())
			if preLevel ~= ability:GetLevel() then
				return;
			end
		end
		-- Handle failure
		if level == 1 or gsiPlayer.skillBuildFixStep == 1 then
			-- Force check
			try_create_valid_build_order(gsiPlayer, Ability_GetSkillBuildTable())
			gsiPlayer.skillBuildFixStep = 2
			return;
		end
		ALERT_print(string.format("[ability_logic] %s attempt to upgrade %s %s failed.", gsiPlayer.shortName, ability and ability:GetName() or "build#", t_skill_build_order_next[gsiPlayer.nOnTeam]))
	end
	if pUnit:GetAbilityPoints() == 0 then
		return;
	end
	ALERT_print(
			string.format("[ability_logic] Attempting skill build repair on %s...",
				gsiPlayer.shortName
			)
		)
	if not gsiPlayer.skillBuildFixStep then
		gsiPlayer.skillBuildFixStep = 1
		--print("ability is slot", 
		--	skillBuild[t_skill_build_order_next[gsiPlayer.nOnTeam]])
		AbilityLogic_TryConfirmValidSkillBuild(gsiPlayer, Ability_GetSkillBuildTable())
	elseif gsiPlayer.skillBuildFixStep == 1 then
		try_create_valid_build_order(gsiPlayer, Ability_GetSkillBuildTable())
		gsiPlayer.skillBuildFixStep = 2
		return;
	else
		-- We tried auto build, but still can't level up. The bot probably skilled
		-- 		up an ability out-of-order, so just run up the table leveling whatever is
		-- 		lower than expected at this point
		-- 	This is expected to only run once, after a fix, and then the auto build should
		-- 		be able to take over for level ups
		ALERT_print(
				string.format("[ability_logic] brute fix...")
			)
		local simulatedLevels = {}
		for i=1,#skillBuild do
			local abilityIndex = skillBuild[i]
			local ability = pUnit:GetAbilityInSlot(abilityIndex)
			local preLevel = ability:GetLevel()
			simulatedLevels[abilityIndex] = simulatedLevels[abilityIndex] or 0
			simulatedLevels[abilityIndex] = simulatedLevels[abilityIndex]+1
			if preLevel < simulatedLevels[abilityIndex] then
				pUnit:ActionImmediate_LevelAbility(ability:GetName())
				if pUnit:GetAbilityPoints() == 0 then
					return;
				end
			end
		end
		-- Finally, really make sure, just take anything allowed
		for i=0,MAX_ABILITY_SLOT do
			local ability = gsiPlayer.hUnit:GetAbilityInSlot(i)
			if ability and ability:CanAbilityBeUpgraded() and not ability:IsHidden() then
				pUnit:ActionImmediate_LevelAbility(ability:GetName())
				if pUnit:GetAbilityPoints() == 0 then
					return;
				end
			end
		end
	end
	-- AbilityLogic_SetCurrentSkillBuildIndex(gsiPlayer, Ability_GetSkillBuildTable())
end

function AbilityLogic_DeduceTargetTypeCastFunc(gsiPlayer, target)
	if target then
		if target.x then
			return gsiPlayer.hUnit.Action_UseAbilityOnLocation
		elseif type(target) == "number" then
			return  gsiPlayer.hUnit.Action_UseAbilityOnTree
		else
			return gsiPlayer.hUnit.Action_UseAbilityOnEntity
		end
	else
		return gsiPlayer.hUnit.Action_UseAbility
	end
end

function AbilityLogic_DeduceTargetTypeCastQueueFunc(gsiPlayer, target)
	if target then
		if target.x then
			return gsiPlayer.hUnit.ActionQueue_UseAbilityOnLocation
		elseif type(target) == "number" then
			return  gsiPlayer.hUnit.ActionQueue_UseAbilityOnTree
		else
			return gsiPlayer.hUnit.ActionQueue_UseAbilityOnEntity
		end
	else
		return gsiPlayer.hUnit.ActionQueue_UseAbility
	end
end

function AbilityLogic_AbilityCanBeCast(gsiPlayer, hAbility)
	if not hAbility:IsItem() then
		if gsiPlayer.hUnit:IsSilenced() then
			return false
		end
	elseif gsiPlayer.hUnit:IsMuted() then
		return false
	end
	if ChargedCooldown_IsChargedCooldown(gsiPlayer, hAbility) then return ChargedCooldown_AbilityCanBeCast(gsiPlayer, hAbility)
	else return hAbility:GetCooldownTimeRemaining() == 0 and hAbility:IsFullyCastable() end -- TODO does 'fully castable' include silenced / stunned
end

function AbilityLogic_IsLikelyAbilityPointInvestibleType(hAbility) -- I haven't noticed how to make this more robust, there's a lot of cave-ats to any aditional checks
	return hAbility and B_AND(hAbility:GetBehavior(), ABILITY_BEHAVIOR_NOT_LEARNABLE) == 0
			or false
end

function AbilityLogic_GetRiskOfReceivingStun(gsiPlayer, gsiEnemy)
	if gsiEnemy then
		
	end
end

-- TODO abstractions
function AbilityLogic_GetBestNuke(gsiPlayer, prioritizeAoe)
	local team = gsiPlayer.team
	local nOnTeam = gsiPlayer.nOnTeam
	local nukes = t_nuke[team][nOnTeam]
	local isAoe = false
	local notBestFit
	for i=1,#nukes do
		local thisAbility = gsiPlayer.hUnit:GetAbilityByName(nukes[i][1])
		if AbilityLogic_IsCastable(gsiPlayer, thisAbility) then
			if not prioritizeAoe or B_AND(thisAbility:GetBehavior(), ABILITY_BEHAVIOR_AOE) > 0 then
				return thisAbility, isAoe
			end
			notBestFit = thisAbility
		end
	end
	return notBestFit, isAoe
end

function AbilityLogic_GetBestSlow(gsiPlayer, prioritizeAoe)
	local team = gsiPlayer.team
	local nOnTeam = gsiPlayer.nOnTeam
	local slow = t_slow[team][nOnTeam]
	local isAoe = false
	local notBestFit
	for i=1,#slow do
		local thisAbility = gsiPlayer.hUnit:GetAbilityByName(slow[i][1])
		if AbilityLogic_IsCastable(gsiPlayer, thisAbility) then
			if not prioritizeAoe or B_AND(thisAbility:GetBehavior(), ABILITY_BEHAVIOR_AOE) > 0 then
				return thisAbility, isAoe
			end
			notBestFit = thisAbility
		end
	end
	return notBestFit, isAoe
end

function AbilityLogic_GetBestHeal(gsiPlayer, prioritizeAoe)
	local team = gsiPlayer.team
	local nOnTeam = gsiPlayer.nOnTeam
	local heal = t_heal[team][nOnTeam]
	local isAoe = false
	local notBestFit
	for i=1,#heal do
		local thisAbility = gsiPlayer.hUnit:GetAbilityByName(heal[i][1])
		if AbilityLogic_IsCastable(gsiPlayer, thisAbility) then
			if not prioritizeAoe or B_AND(thisAbility:GetBehavior(), ABILITY_BEHAVIOR_AOE) > 0 then
				return thisAbility, isAoe
			end
			notBestFit = thisAbility
		end
	end
	return notBestFit, isAoe
end

function AbilityLogic_GetBestDegen(gsiPlayer, prioritizeAoe)
	local team = gsiPlayer.team
	local nOnTeam = gsiPlayer.nOnTeam
	local degen = t_degen[team][nOnTeam]
	local isAoe = false
	local notBestFit
	for i=1,#degen do
		local thisAbility = gsiPlayer.hUnit:GetAbilityByName(degen[i][1])
		if AbilityLogic_IsCastable(gsiPlayer, thisAbility) then
			if not prioritizeAoe or B_AND(thisAbility:GetBehavior(), ABILITY_BEHAVIOR_AOE) > 0 then
				return thisAbility, isAoe
			end
			notBestFit = thisAbility
		end
	end
	return notBestFit, isAoe
end

function AbilityLogic_GetBestBuff(gsiPlayer, prioritizeAoe)
	local team = gsiPlayer.team
	local nOnTeam = gsiPlayer.nOnTeam
	local buff = t_buff[team][nOnTeam]
	local isAoe = false
	local notBestFit
	for i=1,#buff do
		local thisAbility = gsiPlayer.hUnit:GetAbilityByName(buff[i][1])
		if AbilityLogic_IsCastable(gsiPlayer, thisAbility) then
			if not prioritizeAoe or B_AND(thisAbility:GetBehavior(), ABILITY_BEHAVIOR_AOE) > 0 then
				return thisAbility, isAoe
			end
			notBestFit = thisAbility
		end
	end
	return notBestFit, isAoe
end

function AbilityLogic_GetBestAntiMobility(gsiPlayer, prioritizeAoe)
	local team = gsiPlayer.team
	local nOnTeam = gsiPlayer.nOnTeam
	local roots = t_root[team][nOnTeam]
	local slows = t_slow[team][nOnTeam]
	local isAoe = false
	local notBestFit
	for i=1,#roots do
		local thisAbility = gsiPlayer.hUnit:GetAbilityByName(roots[i][1])
		if AbilityLogic_IsCastable(gsiPlayer, thisAbility) then
			isAoe = B_AND(thisAbility:GetBehavior(), ABILITY_BEHAVIOR_AOE) > 0
			if not prioritizeAoe or isAoe then
				return thisAbility, isAoe
			end
			notBestFit = thisAbility
		end
	end
	for i=1,#slows do
		local thisAbility = gsiPlayer.hUnit:GetAbilityByName(slows[i][1])
		if AbilityLogic_IsCastable(gsiPlayer, thisAbility) then
			isAoe = B_AND(thisAbility:GetBehavior(), ABILITY_BEHAVIOR_AOE) > 0
			if not prioritizeAoe or isAoe then
				return thisAbility, isAoe
			end
			notBestFit = notBestFit or thisAbility
		end
	end
	return notBestFit, isAoe
end

------- Analytics_GetLaneGankResistanceScore
-- - Use to compare heroes for leaving allies alone in lane, esp early-game
-- - Can't be used for 
Analytics_GetGankResistanceScore = nil
do
	local t_slow = t_slow
	local t_stun = t_stun
	local t_mobility = t_mobility
	local t_shield = t_shield
	local t_invis = t_invis
	local abilityTypes = {t_slow, t_stun, t_mobility, t_shield, t_invis}
	local Armor = Unit_GetArmorPhysicalFactor
	Analytics_GetGankResistanceScore = function(gsiPlayer, lane)
		local timeData = gsiPlayer.time.data
		if timeData.gankResistanceScore then
			return timeData.gankResistanceScore
		end
		local manaRemaining = gsiPlayer.lastSeenMana
		local team = gsiPlayer.team
		local pnot = gsiPlayer.nOnTeam
		lane = lane or Team_GetRoleBasedLane(gsiPlayer)
		local effectiveHealth = gsiPlayer.lastSeenHealth / Armor(gsiPlayer) -- efctv. health
		local score = effectiveHealth
		for iTypes=1,#abilityTypes do
			local abilities = abilityTypes[iTypes][team][pnot]
			for i=1,#abilities do
				local ability = abilities[i]
				local thisManaCost = ability:GetManaCost()
				if ability:IsTrained() and ability:GetCooldownTimeRemaining() < 20
						and manaRemaining - thisManaCost > 0 then
					manaReamining = manaReamining - thisManaCost
					score = score + effectiveHealth * 1.15
				end
			end
		end
		timeData.gankResistanceScore = score
		return score
	end
end


function AbilityLogic_IsCastable(gsiPlayer, hAbility)
	return hAbility and hAbility:IsFullyCastable() and hAbility:GetCooldownTimeRemaining() == 0
end

function AbilityLogic_GetBestStun(gsiPlayer, prioritizeAoe)
	local team = gsiPlayer.team
	local nOnTeam = gsiPlayer.nOnTeam
	local stuns = t_stun[team][nOnTeam]
	local isAoe = false
	local notBestFit
	for i=1,#stuns do
		local thisAbility = gsiPlayer.hUnit:GetAbilityByName(stuns[i][1])
		if AbilityLogic_IsCastable(gsiPlayer, thisAbility) then
			isAoe = B_AND(thisAbility:GetBehavior(), ABILITY_BEHAVIOR_AOE) > 0
			notBestFit = thisAbility
			if not prioritizeAoe or isAoe then
				return thisAbility, isAoe
			end
		end
	end
	return notBestFit, isAoe
end

function AbilityLogic_GetBestSave(gsiPlayer, allowableCastRange)
	
end

function AbilityLogic_GetBestFightTempoShift(gsiPlayer, allowableCastRange)

end

function AbilityLogic_GetBestMobility(gsiPlayer, allowableCastRange)
	local team = gsiPlayer.team
	local nOnTeam = gsiPlayer.nOnTeam
	local mobilities = t_mobility[team][nOnTeam]
	for i=1,#mobilities do
		local thisAbility = gsiPlayer.hUnit:GetAbilityByName(mobilities[i][1])
		if AbilityLogic_IsCastable(gsiPlayer, thisAbility) then
			return thisAbility
		end
	end
	--print(gsiPlayer.shortName, "no valid heals. heals#", #heals)
end

function AbilityLogic_GetBestAttackMod(gsiPlayer)
	local attackMods = t_attack_mod[gsiPlayer.team][gsiPlayer.nOnTeam]
	for i=1,#attackMods do
		local thisAbility = gsiPlayer.hUnit:GetAbilityByName(attackMods[i][1])
		if AbilityLogic_IsCastable(gsiPlayer, thisAbility) then
			return thisAbility
		end
	end
end

function AbilityLogic_GetBestSurvivability(gsiPlayer, allowableCastRange)
	local team = gsiPlayer.team
	local nOnTeam = gsiPlayer.nOnTeam
	local shields = t_shield[team][nOnTeam]
	for i=1,#shields do
		local thisAbility = gsiPlayer.hUnit:GetAbilityByName(shields[i][1])
		if AbilityLogic_IsCastable(gsiPlayer, thisAbility) then
			return thisAbility
		end
	end
	--print(gsiPlayer.shortName, "no valid shields. shield#", #shields)
	local heals = t_heal[team][nOnTeam]
	for i=1,#heals do
		local thisAbility = gsiPlayer.hUnit:GetAbilityByName(heals[i][1])
		if AbilityLogic_IsCastable(gsiPlayer, thisAbility) then -- TODO "Fully" includes silences / currently stunned or otherwise unable to act?
			return thisAbility
		end
	end
	--print(gsiPlayer.shortName, "no valid heals. heals#", #heals)
end

function AbilityLogic_GetBestInvis(gsiPlayer)
	local invis = t_invis[gsiPlayer.team][gsiPlayer.nOnTeam]
	for i=1,#invis do
		local thisAbility = gsiPlayer.hUnit:GetAbilityByName(invis[i][1])
		if AbilityLogic_IsCastable(gsiPlayer, thisAbility) then
			return thisAbility
		end
	end
end

function AbilityLogic_GetBestDpsIncreasingAbility(gsiPlayer, allowableCastRange) -- When you and others have a single primary target
	
end

function AbilityLogic_GetBestSpammableDamage(gsiPlayer, allowableCastRange)
	--local abilities = t_player_abilities[gsiPlayer.nOnTeam]
end

function AbilityLogic_GetSmite(gsiPlayer) -- Zues Ult Now!

end

-------- AbilityLogic_AnyProjectilesImmunable()
function AbilityLogic_AnyProjectilesImmunable(gsiPlayer, onlyUndodgeable)
	local pjt = gsiPlayer.hUnit:GetIncomingTrackingProjectiles()
	for i=1,#pjt do
		local pj = pjt[i]
		
		if pj and pj.ability and pj.caster and pj.caster:GetTeam() ~= gsiPlayer.team
				and B_AND(pj.ability:GetTargetFlags(),
						ABILITY_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES
					) == 0 then
			
			if (not onlyUndodgeable or not pj.is_dodgeable)
					and GSI_DifficultyDiv(25) then
				return true, pj.ability, Unit_GetSafeUnit(pj.caster);
			end
		end
	end
	return false, nil, nil;
end

-------- AbilityLogic_AnyProjectilesDodgeable()
function AbilityLogic_AnyProjectilesDodgeable(gsiPlayer, onlyPiercesImmunity)
	local pjt = gsiPlayer.hUnit:GetIncomingTrackingProjectiles()
	for i=1,#pjt do
		local pj = pjt[i]
		
		if pj and pj.ability and pj.caster and pj.caster:GetTeam() ~= gsiPlayer.team
				and pj.is_dodgeable then
			if (not onlyPiercesImmunity
					or B_AND(pj.ability:GetTargetFlags(),
						ABILITY_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES) > 0
					) and GSI_DifficultyDiv(25) then
				return true, pj.ability, Unit_GetSafeUnit(pj.caster);
			end
		end
	end
	return false, nil, nil;
end

-------- AbilityLogic_AnyProjectiles()
function AbilityLogic_AnyProjectiles(gsiPlayer, fromAllies)
	local pjt = gsiPlayer.hUnit:GetIncomingTrackingProjectiles()
	for i=1,#pjt do
		local pj = pjt[i]
		
		if pj and pj.ability and pj.caster
				and pj.caster:GetTeam()
					== (fromAllies and gsiPlayer.team or ENEMY_TEAM) then
			if --[[(not onlyPiercesImmunity
					or B_AND(pj.ability:GetTargetFlags(),
						ABILITY_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES) > 0
					) and--]] GSI_DifficultyDiv(25) then
				return true, pj.ability, Unit_GetSafeUnit(pj.caster);
			end
		end
	end
	return false, nil, nil;
end

local INVIS_ITEMS = INVIS_ITEMS
function AbilityLogic_HasInvisAbility(gsiPlayer, checkItems)
	if checkItems and not pUnit_IsNullOrDead(gsiPlayer) then
		for i=1,#INVIS_ITEMS do
			local itemSlot = gsiPlayer.hUnit:FindItemSlot(INVIS_ITEM[i])
			if itemSlot >= 0 then
				gsiPlayer.time.data.hasInvis = true
				return true, gsiPlayer.hUnit:GetItemInSlot(itemSlot)
			end
		end
	end
	if t_invis[gsiPlayer.team][gsiPlayer.nOnTeam] then
		gsiPlayer.time.data.hasInvis = true
		return true, t_invis[gsiPlayer.team][gsiPlayer.nOnTeam]
	end
	gsiPlayer.time.data.hasInvis = false
	return false
end

function AbilityLogic_AbilityHasAdditionalEffect(hAbility)
	local abilityData = t_ability_index[hAbility]
	if not abilityData then
		if not hAbility then
			return;
		end
		abilityData = create_unknown_ability_index(hAbility)
		if not abilityData then
			return false
		end
	end
	--Util_TablePrint(abilityData)
	local abilityBitField = abilityData[2]
	abilityBitField = abilityBitField % ABILITY_TYPE.DEGEN*2
	abilityBitField = abilityBitField / ABILITY_TYPE.STUN

	if abilityBitField >= 1 then
		return true
	end -- AoE // Chain also. The reduced target will still add to the final score, should be ok for target selection without
end

function AbilityLogic_PierceTeamRelationFlagsPossible(sameTeam, targetFlags)
	if sameTeam then
		return B_AND(
				targetFlags,
				ABILITY_TARGET_FLAG_NOT_MAGIC_IMMUNE_ALLIES
			) == 0
	else
		return B_AND(
				targetFlags,
				ABILITY_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES
			) ~= 0
	end
end
local PIERCES_TEAM_RELATION_FLAGS_POSSIBLE = AbilityLogic_PierceTeamRelationFlagsPossible

-- No armor checks
-------- AbilityLogic_CastOnTargetWillSucceed()
function AbilityLogic_CastOnTargetWillSucceed(gsiCaster, target, hAbility)
	if target == nil or type(target) == "number" or target.x then return 1 end
	if not abilityData then
		if not hAbility then
			return;
		end
		abilityData = create_unknown_ability_index(hAbility)
		if not abilityData then
			return false
		end
	end
	local additionalFlags = t_ability_index[hAbility]
			and t_ability_index[hAbility][ABILITY_I__ADDITIONAL_FLAGS] or EMPTY_TABLE
	local hUnit = target.hUnit
	if target.typeIsNone or Unit_IsNullOrDead(target) or not hUnit.IsMagicImmune then
		-- Sometimes IsMagicImmune is not defined, despite a non-null hUnit
		if damageType == DAMAGE_TYPE_MAGICAL then
			return target.magicTaken or 0.67
		elseif damageType == DAMAGE_TYPE_PHYSICAL then
			return 1 - target.evasion or 1
		end
		return 0.999
	end
	local targetFlags = hAbility:GetTargetFlags()
	if hUnit:IsMagicImmune()
			and not PIERCES_TEAM_RELATION_FLAGS_POSSIBLE(
					gsiCaster.team==target.team,
					targetFlags
				) then
		return 0
	elseif hUnit:IsAttackImmune() and not additionalFlags[FLAGS2_I__IGNORES_EVASION] then
		return 0
	end
	if damageType == DAMAGE_TYPE_MAGICAL then
		local result = 1 - (hUnit:GetMagicResist())
		return additionalFlags[FLAGS2_I__HAS_DEGEN] and sqrt(result) or result -- degen makes more valuable vs resist
		-- TODO this is lying to one-shot logic due to degen
	elseif damageType == DAMAGE_TYPE_PHYSICAL then
		local result = 1 - (effectedByEvasion and hUnit:GetEvasion() or 0)
				- (Unit_GetArmorPhysicalFactor(target))
		return additionalFlags[FLAGS2_I__HAS_DEGEN] and sqrt(result) or result -- likewise for armour
	else
		return 1
	end
end
local AbilityLogic_CastOnTargetWillSucceed = AbilityLogic_CastOnTargetWillSucceed

-------- AbilityLogic_BestBlockedByAbilities()
function AbilityLogic_BestBlockedByAbilities(gsiTarget, gsiCaster, ability, ...)
	if not ability or ability:IsNull() then return false, nil end

	local blockingAbilities = {...}
	local additionalFlags = t_ability_index[hAbility]
			and t_ability_index[hAbility][ABILITY_I__ADDITIONAL_FLAGS] or EMPTY_TABLE
	local targFlags = ability:GetTargetFlags()
	local blocksByMgk = PIERCES_TEAM_RELATION_FLAGS_POSSIBLE(
			gsiTarget.team == gsiCaster.team,
			targFlags
		)
	local blocksByEvade = not additionalFlags[FLAGS2_I__IGNORES_EVASION]

	local bestBlock
	local lowestCooldown = 0xFFFF
	-- blockingAbility
	-- lowest cd blocking the dmg type wins
	return bestBlock, lowestCooldown
end

-------- AbilityLogic_SetExpendManaNow()
function AbilityLogic_SetExpendManaNow(gsiPlayer, mana, duration, softOverride)
	local expendNow = gsiPlayer.highUseManaExpendNow
	if softOverride and expendNow.mana > 0 then
		local high
		local low
		local prevExpend = expendNow.mana
		if prevExpend > mana then
			high = prevExpand
			low = mana
			duration = expendNow.c
		else
			low = expendNow.mana
			high = mana
		end
		local lowHigh = 0.67 + 0.33 * low/high
		expendNow.mana = lowHigh * high
		-- (prevMana * 0.33 / prevDuration) * 0.33 + (mana * 0.33 / duration) * 0.66
		expendNow.decrement = expendNow.decrement * 0.33 + mana * 0.222 / duration
	else
		expendNow.mana = mana
		expendNow.decrement = mana * 0.333 / duration
	end
	expendNow.next = GameTime() + 0.33
end

-- TODO NOTE THAT THE USE OF INVERSE HEALTH PERCENT IN HIGHUSE IS VERY DEGENERATE.
-- -- IT DOES NOT HELP ANYTHING EXCEPT FOR ENEMIES THAT TAKE PERCENT REMAINING HEALTH
-- -- DAMAGE. NEED TO RESOLVE IN HERO FILES WHERE THIS INSANITY WAS USED AS LAX SAFETY
-- -- IT ALSO IGNORES THE MEANING OF THE TERM, BY MAKING THE BOT USE ABILITIES WHEN
-- -- IT IS ALREADY SAFE ACCORDING TO THE SINGLE METRIC OF HEALTH. THEY MAY DRAIN
-- -- TO ZERO MANA BECAUSE OF THE ARITHMETIC WAS EXPECTING HUGE GOLD CHANGES FOR VERY
-- -- LOW HEALTH PERCENTAGE USES
-- "high use", meaning, the full use of ones mana before death, and in order to secure
-- - kills. The situational volatility.
function AbilityLogic_HighUseAllowOffensive(gsiPlayer, hAbility, highUseMana, enemyHealthPercent)
	
	
	
	enemyHealthPercent = min(enemyHealthPercent, gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth + 0.15)
	-- TODO the reason I used +0.15 player health was to mitigate just having a bad lane and like, waiting for regen on courier. But the truth is that the value to inform unloading all your mana would be an evaluation of how likely you are to die soon in the future.
	local expendNow = gsiPlayer.highUseManaExpendNow
	local highManaUse = gsiPlayer.lastSeenMana - hAbility:GetManaCost()
			+ ( expendNow.mana or 0 )
				> ( enemyHealthPercent > 0.57 and highUseMana*1.5
					or highUseMana*max(0, enemyHealthPercent-0.35)*6.67
				)
	if expendNow.mana > 0 and expendNow:allowed() then
		expendNow.mana = max(0, expendNow.mana - expendNow.decrement)
	end
	return highManaUse
end

-- See above "high use" def.
function AbilityLogic_HighUseAllowSafe(gsiPlayer, hAbility, highUseMana, safety)
	return gsiPlayer.lastSeenMana - hAbility:GetManaCost()
			+ (gsiPlayer.highUseManaExpendNow and gsiPlayer.highUseManaExpendNow.mana or 0)
				> ( safety > 0.57 and highUseMana*1.5
					or highUseMana*max(0, safety-0.35)*6.67
				)
end

local t_neutrals_ability_funcs = {
		["mud_golem_hurl_boulder"] = function(gsiUnit, ability)
				-- :| golm :| golm :| golm :| golm :| golm :| golm
				local castRange = ability:GetCastRange()
				local nearbyEnemies = Set_GetEnemyHeroesInPlayerRadius(gsiUnit, castRange*1.4)
				local bestTarget
				local bestScore = 0
				local casterLoc = gsiUnit.lastSeen.location
				local activityType = gsiUnit.type == UNIT_TYPE_HERO and Blueprint_GetCurrentTaskActivityType(gsiUnit)
				if activityType and activityType > ACTIVITY_TYPE.CONTROLLED_AGGRESSION
						and activityType < ACTIVITY_TYPE.FEAR then
					
					return;
				end
				for i=1,#nearbyEnemies do
					local thisEnemy = nearbyEnemies[i]
					local enemyHunit = thisEnemy.hUnit
					if enemyHunit and enemyHunit.IsNull and not enemyHunit:IsNull() then
						-- instagib
						if thisEnemy.lastSeenHealth < 150
								and Vector_PointDistance2D(thisEnemy.lastSeen.location, casterLoc) < castRange*0.95 then
							local magicRes = AbilityLogic_CastOnTargetWillSucceed(gsiUnit, thisEnemy, ability)
							local nearFuture = Analytics_GetNearFutureHealth(thisEnemy, 1)
							if nearFuture > 0
									and nearFuture+thisEnemy.hUnit:GetHealthRegen()*1.5 < ability:GetSpecialValueFloat("damage")*magicRes then
								print("golmdtra kill :|")
								return thisEnemy
							end
						end
						-- save for and use on channelers
						if enemyHunit:IsChanneling() then
							if Vector_PointDistance2D(thisEnemy.lastSeen.location, casterLoc) < castRange*0.95 then
								return thisEnemy
							end
							-- save it
							return;
						end
						local thisScore = Analytics_GetPowerLevel(thisEnemy) * thisEnemy.lastSeenHealth / thisEnemy.maxHealth
						if thisScore > bestScore then
							bestScore = thisScore
							bestTarget = thisEnemy
						end
					end
				end
				if bestTarget and Vector_PointDistance2D(bestTarget.lastSeen.location, casterLoc)
							< castRange*0.95 then
					print("get golm'd :|")
					return bestTarget
				end
			end,
		["polar_furbolg_ursa_warrior_thunder_clap"] = function(gsiUnit, ability)
				local nearestEnemy, dist = Set_GetNearestEnemyHeroToLocation(gsiUnit.lastSeen.location)

				
				if dist < ability:GetSpecialValueFloat("radius") * 0.85
						and nearestEnemy.hUnit:IsStunned() then
					return true
				end
			end,
		["harpy_stormcrafter_chain_lightning"] = function(gsiUnit, ability)
				local castRange = ability:GetCastRange()
				local jumpRange = ability:GetSpecialValueFloat("jump_range")
				local nearbyEnemies, outerToAllEnemies
						= Set_GetEnemyHeroesInLocRadOuter(
								gsiUnit.lastSeen.location,
								castRange*0.95,
								castRange + ability:GetSpecialValueFloat("jump_range"))
				if #nearbyEnemies >= 1 then
					local dmg = ability:GetSpecialValueFloat("initial_damage")
					local bestTarget
					local bestScore = 0
					Set_NumericalIndexUnion( nil, outerToAllEnemies,
							nearbyEnemies )
					for i=1,#nearbyEnemies do
						local thisEnemy = nearbyEnemies[i]
						local magicRes = AbilityLogic_CastOnTargetWillSucceed(gsiUnit, thisEnemy, ability)
						if thisEnemy.lastSeenHealth < dmg*magicRes then
							return thisEnemy
						end
						local _, crowdedRating = Set_GetCrowdedRatingToSetTypeAtLocation(
								thisEnemy.lastSeen.location,
								SET_HERO_ENEMY,
								outerToAllEnemies,
								jumpRange
							)
						if crowdedRating > bestScore then
							bestScore = crowdedRating
							bestTarget = thisEnemy
						end
					end
					return bestTarget
				end
			end,
		["satyr_hellcaller_shockwave"] = function(gsiUnit, ability)
				local distance = ability:GetSpecialValueFloat("distance")
				local nearbyEnemies, outerToAllEnemies
						= Set_GetEnemyHeroesInLocRadOuter(
								gsiUnit.lastSeen.location,
								distance*0.75,
								distance,
								0.5
							)
				if #nearbyEnemies >= 1 then
					local crowdedLoc, crowdedRating = Set_GetCrowdedRatingToSetTypeAtLocation(
							thisEnemy.lastSeen.location,
							SET_HERO_ENEMY,
							outerToAllEnemies,
							300
						)
					if crowdedRating > 3 then
						return crowdedLoc
					end
				end
			end,
		["fel_beast_haunt"] = function(gsiUnit, ability) -- silence
				local castRange = ability:GetCastRange()
				local nearbyEnemies = Set_GetEnemyHeroesInPlayerRadius(gsiUnit, castRange*1.4)
				local bestTarget
				local bestScore = 0
				local casterLoc = gsiUnit.lastSeen.location
				local activityType = gsiUnit.type == UNIT_TYPE_HERO and Blueprint_GetCurrentTaskActivityType(gsiUnit)
				if activityType
						and activityType > ACTIVITY_TYPE.CONTROLLED_AGGRESSION
						and activityType < ACTIVITY_TYPE.FEAR then
					return;
				end
				for i=1,#nearbyEnemies do
					local enemyHunit = thisEnemy.hUnit
					if enemyHunit and enemyHunit.IsNull and not enemyHunit:IsNull() then
						local thisEnemy = nearbyEnemies[i]
						-- [[ TODO use on enemies with mobility ability flags ]] 
						-- save for and use on channelers
						if enemyHunit:IsChanneling() then
							if Vector_PointDistance2D(thisEnemy.lastSeen.location, casterLoc) < castRange*0.95 then
								return thisEnemy
							end
							-- save it
							return;
						end
						local thisScore = Analytics_GetPowerLevel(thisEnemy) * thisEnemy.lastSeenHealth * thisEnemy.lastSeenMana / (thisEnemy.maxMana * thisEnemy.maxHealth)
						if thisScore > bestScore then
							bestScore = thisScore
							bestTarget = thisEnemy
						end
					end
				end
				if bestTarget and Vector_PointDistance2D(bestTarget.lastSeen.location, casterLoc)
							< castRange*0.95 then
					return bestTarget
				end
			end,
	}
t_neutrals_ability_funcs["warpine_raider_seed_shot"] = t_neutrals_ability_funcs["mud_golem_hurl_boulder"]
t_neutrals_ability_funcs["centaur_khan_war_stomp"] = t_neutrals_ability_funcs["polar_furbolg_ursa_warrior_thunder_clap"]
function AbilityLogic_DetectValidNeutralsAbilityUse(gsiUnit, ability)
	
	if t_neutrals_ability_funcs[ability:GetName()]
			and gsiUnit.hUnit:GetMana() > ability:GetManaCost() then
		return t_neutrals_ability_funcs[ability:GetName()](gsiUnit, ability)
	end
	return nil
end

function AbilityLogic_LoadAbilityToPlayer(gsiPlayer, abilityData)
--	print("Load Ability", gsiPlayer.team, GetTeam(), abilityData[1])
	local abilityBitField = abilityData[2]
	if not abilityBitField then return end
	--print(gsiPlayer.shortName, 'VUL-FT bitfield', abilityBitField)
	local ammendTypeIndex = 1
	while(abilityBitField>=1) do
		if abilityBitField % 2 == 1 then
			AMMEND_TYPE_FUNCS[ammendTypeIndex](gsiPlayer, abilityData)
		end
		abilityBitField = math.floor(abilityBitField / 2)
		ammendTypeIndex = ammendTypeIndex + 1
	end
end

local dontOverkillTbl = {}
function AbilityLogic_CastingOneHitCallback(gsiPlayer, target)
	-- TODO Get use_ability data to call this function when a player runs a function registered with this callback
	-- - or set up special handling for it, e.g. with raw damage registered, calculate the hit's ability to finish
	-- - off the enemy hero at the time of casting / callback ability check further use_ability and then to this
	-- - and disallow one hit kills if overkilled. something like that
end

-- does not consider player's danger, only kill-secure and mana / cooldown management
function AbilityLogic_AllowOneHitKill(gsiPlayer, target, castRange, damage, damageType, nearbyEnemies)
	local targetReal = not target.typeIsNone or Unit_IsNullOrDead(target) or not target.hUnit.GetUnitName
	local targetAggressive = targetReal and target.hUnit:GetAttackTarget() or false
	local nearbyEnemies = nearbyEnemies or Set_GetEnemyHeroesInPlayerRadius(gsiPlayer, 1300)
	targetAggressive = targetAggressive and targetAggressive:IsHero() or false
	local dangerOverkillFactor = gsiPlayer.time.data.theorizedDanger
			or Analytics_GetTheoreticalDangerAmount(gsiPlayer)
	dangerOverkillFactor = 1 / (1 + 2^(-dangerOverkillFactor))
	local resistMultiplier = damageType == DAMAGE_TYPE_PHYSICAL and target.armor or 0.75
			or damageType == DAMAGE_TYPE_MAGICAL and target.magicTaken or 0.75
			or 1.0
	local overkill = damage*resistMultiplier - target.lastSeenHealth
	if TEST then print("OHK", gsiPlayer.shortName, target.shortName, castRange, damage, damageType, overkill, #nearbyEnemies) end
	if overkill > 0	and (targetAggressive
					or (castRange > 12000
							or ( target.currentMovementSpeed > gsiPlayer.currentMovementSpeed*0.66
								and Math_PointToPointDistance2D(
										gsiPlayer.lastSeen.location,
										target.lastSeen.location
									) > min(castRange*0.75,
										gsiPlayer.attackRange * 0.66
									)
								)
					) or dangerOverkillFactor*damage > overkill
					or #nearbyEnemies > 1
			) then
		return true
	end
	return false
end

function AbilityLogic_DetectUnsafeChannels(gsiPlayer, abilityName, intense, dryRun)
	local currActiveAbility = gsiPlayer.hUnit:GetCurrentActiveAbility()
	if currActiveAbility and currActiveAbility:GetName() == abilityName then
		if Analytics_GetTotalDamageInTimeline(gsiPlayer.hUnit) > gsiPlayer.lastSeenHealth/20
				and gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth < 0.8 then
			if intense then
				-- TODO do more analytics
				-- return if fine
			end
			if dryRun then return true; end
			UseAbility_ClearQueuedAbilities(gsiPlayer)
			return true
		end
	end
	return false
end

function AbilityLogic_CreatePlayerAbilitiesIndex(abilitiesIndex, gsiPlayer, abilities)
	local iAbilityIndex = 1
	local nOnTeam = gsiPlayer.nOnTeam
	abilitiesIndex[nOnTeam] = abilitiesIndex[nOnTeam] or {}
	for iAbility=0,MAX_ABILITY_SLOT do
		local thisAbilityData = abilities[iAbility]

		do
			local ability = gsiPlayer.hUnit:GetAbilityInSlot(iAbility)
			if DEBUG and ability then
				DEBUG_print(
						string.format("[ability_logic] - %s", ability:GetName())
					)
			end
		end
		if thisAbilityData then
			--print(iAbility, ABILITY_I__ABILITY_NAME, abilities[iAbility][1])
			local thisAbility = gsiPlayer.hUnit:GetAbilityByName(abilities[iAbility][ABILITY_I__ABILITY_NAME])
			if thisAbility then -- TODO need failsafe
				--print(abilities[iAbility][ABILITY_I__ABILITY_NAME])

				-- Process for AbilityLogic
				abilitiesIndex[nOnTeam][iAbilityIndex] = thisAbility
				iAbilityIndex = iAbilityIndex + 1
				t_ability_index[thisAbility] = thisAbilityData -- nb. using index in AbilityHasAdditionalEffect
				if TEST then
					print(thisAbility:GetName(), 'tFlags', thisAbility:GetTargetFlags(), 'tTypeFlags',
						thisAbility:GetTargetType(), 'behavior flags', thisAbility:GetBehavior())
				end
				thisAbilityData[ABILITY_I__ADDITIONAL_FLAGS] = {
						AbilityLogic_AbilityHasAdditionalEffect(thisAbility),
						B_AND(thisAbility:GetTargetFlags(), ABILITY_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES) > 0,
						B_AND(thisAbility:GetTargetFlags(), ABILITY_TARGET_FLAG_NOT_ATTACK_IMMUNE) == 0,
					}
			end
		end
	end
end

function AbilityLogic_UpdatePlayerAbilitiesIndex(gsiPlayer, playerIndex, abilities)
	local iAbilityIndex = 1
	for iAbility=0,MAX_ABILITY_SLOT do
		local thisAbilityData = abilities[iAbility]
		if thisAbilityData then
			local thisAbility
					= gsiPlayer.hUnit:GetAbilityByName(abilities[iAbility][ABILITY_I__ABILITY_NAME])
			if thisAbility then
				playerIndex[iAbilityIndex] = thisAbility
				iAbilityIndex = iAbilityIndex + 1
				thisAbilityData[ABILITY_I__ADDITIONAL_FLAGS][FLAGS2_I__PIERCES_IMMUNITY]
						= B_AND(thisAbility:GetTargetFlags(),
								ABILITY_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES
							) > 0
				thisAbilityData[ABILITY_I__ADDITIONAL_FLAGS][FLAGS2_I__IGNORES_EVASION]
						= B_AND(thisAbility:GetTargetFlags(),
								ABILITY_TARGET_FLAG_NOT_ATTACK_IMMUNE
							) == 0
			end
		end
	end
end

-------- AbilityLogic_WilLChainCastHit()
---- Returns the gsiTarget as the inRangeConduit if it is in range.
---- Works often enough; function will give a false-negative when there's a semi-circle
---- - chain of at least 2 chaining units to the to/fromLoc unit around the next-step chaining unit.
---- The closest in-range unit is found to the unit at the otherside of the alternating to-and-from
---- - range checks of the loop. Starting with the castFrom location as 'from', and the target as 'to'.
local DEBUG__DRAW_WILLCHAIN_JUMPS = DEBUG and true
local function chain_unfairly_to_target(contextualFromLoc, contextualToLoc, chainingUnitTbl,
			chainDist, contextualLowestDistanceFrom, contextualLowestDistanceTo, numUnits
		)
	local thisLowestDist = 0xFFFF
	local thisLowestUnit

	local i=1
	while(i<=numUnits) do
		local thisUnit = chainingUnitTbl[i]
		--print("i =", i)
		local thisLoc = thisUnit.lastSeen.location
		local thisDist = Math_PointToPointDistance2D(contextualFromLoc, thisLoc)
		-- cut from tables if the node is now behind us since the last step to 'to'
		if thisDist > contextualLowestDistanceFrom[i] then 
			table.remove(chainingUnitTbl, i)
			table.remove(contextualLowestDistanceFrom, i)
			table.remove(contextualLowestDistanceTo, i)
			numUnits = numUnits - 1
		elseif thisLoc ~= contextualFromLoc then
			contextualLowestDistanceTo[i] = thisDist
			-- find next closest to 'to'
			if Vector_PointDistance2D(contextualFromLoc, thisLoc) < chainDist then
				thisDist = Math_PointToPointDistance2D(thisLoc, contextualToLoc)
				if thisDist < thisLowestDist then
					--print("new lowest", thisDist, "dist chain is", Vector_PointDistance2D(contextualFromLoc, thisLoc), chainDist)
					thisLowestDist = thisDist
					thisLowestUnit = thisUnit
				end
			end
			i = i + 1
		else
			i = i + 1
		end
	end
	local thisLowestLoc = thisLowestUnit and thisLowestUnit.lastSeen.location
	if DEBUG__DRAW_WILLCHAIN_JUMPS and thisLowestLoc and (lastDrawn or 0)+0.1 < RealTime() then
		lastDrawn = RealTime()
		--print("Drawing")
		--print(thisLowest == toLoc)
		DebugDrawLine(contextualFromLoc, thisLowestLoc, min(255, 100*(numUnits + 1)), min(255, 100*(numUnits + 1)), 255)
	end
	return thisLowestLoc, thisLowestUnit, numUnits
end
function AbilityLogic_WillChainCastHit(gsiCasting, gsiTarget, castRange, chainingUnitTbl,
			maxJumps, chainDist, explodeDist, willChainToTarget)
-- Table remove bench
	local t = RealTime()
	local lowestDistanceTo = {}
	local lowestDistanceFrom = {}

	if Vector_PointDistance(gsiCasting.lastSeen.location, gsiTarget.lastSeen.location) < castRange*0.95 then
		return true, gsiTarget, 0
	end

	local numUnits = #chainingUnitTbl

	--print(numUnits, castRange, maxJumps, chainDist, explodeDist)

	for i=1,numUnits do -- due to the nature of the alg', we can remove units if we step away from them
		-- comparing these each step is useful for say, finding the path of a chain through 40 broodlings
		-- the broodlings behind the next-step units from each side will be removed from the list
		lowestDistanceTo[i] = 0xFFFF
		lowestDistanceFrom[i] = 0xFFFF
	end

	local fromLoc = gsiTarget.lastSeen.location
	local toLoc = gsiCasting.lastSeen.location
	
	local totalJumps = 0

	-- synonymous with, are you dazzle?
	if explodeDist and not willChainToTarget then
		local acceptableExplosionRadius = 0.85*explodeDist
		-- find the explode unit that is closest to the cast location
		local thisLowestDist = 0xFFFF
		local thisLowest
		for i=1,numUnits do
			local thisUnit = chainingUnitTbl[i]
			if Vector_Distance2D(fromLoc, thisUnit.lastSeen.location) < acceptableExplosionRadius then
				local thisDist = Vector_Distance2D(thisUnit, toLoc)
				if thisDist < thisLowestDist then
					thisLowestDist = thisDist
					thisLowest = thisUnit.lastSeen.location
				end
			end
		end
		if not thisLowest then
			return false
		end
		fromLoc = thisLowest
		totalJumps = 1
	end

	local acceptableChainDist = chainDist*0.975
	local chainingOption

	local killMe = 1
	while(1) do -- O(n^2)
		if killMe > 100 then
			ERROR_print(true, not DEBUG,
					"[ability_logic]: AbilityLogic_WillChainCastHit UNEXPECTED INFINITE LOOP",
					totalJumps, Util_PrintableTable(chainingUnitTbl)
				)
			return false
		end
		fromLoc, fromUnit, numUnits = chain_unfairly_to_target(fromLoc, toLoc, chainingUnitTbl, acceptableChainDist,
				lowestDistanceFrom, lowestDistanceTo, numUnits
			)
		if fromLoc then
			if not chainingOption then
				chainingOption = fromUnit
			end
			--gsiCasting.hUnit:ActionImmediate_Ping(fromLoc.x, fromLoc.y, true)
			totalJumps = totalJumps + 1
			if fromLoc == toLoc then -- a chain is plausible
				return true, chainingOption, totalJumps
			end
			if totalJumps == maxJumps then
				--print("found")
				return false
			end
		else
			--print("nothing")
			return false
		end
		toLoc, _, numUnits = chain_unfairly_to_target(toLoc, fromLoc, chainingUnitTbl, acceptableChainDist,
				lowestDistanceTo, lowestDistanceFrom, numUnits
			)
		if toLoc then
			totalJumps = totalJumps + 1
			if fromLoc == toLoc then -- a chain is plausible
				--print("found")
				return true, chainingOption, totalJumps
			end
			if totalJumps == maxJumps then
				--print("too long")
				return false
			end
		else
			--print("nothing")
			return false
		end
		killMe = killMe + 1
	end
end

-- Does not check cast range, returns preferred if over acceptable dmg factor if set or over 0
-------- AbilityLogic_GetBestDmgFactorTarget()
function AbilityLogic_GetBestDmgFactorTarget(gsiPlayer, hAbility, units,
			preferredTarget, acceptableFactor
		)
	local bestDmgFactor = AbilityLogic_CastOnTargetWillSucceed(gsiPlayer, units[i], hAbility)
	local acceptableFactor = acceptableFactor or 0.01
	if bestDmgFactor > acceptablePreferredFactor then
		return preferredTarget, bestDmgFactor, true
	end
	local bestDmgTarget
	for i=1,#units do
		if not pUnit_IsNullOrDead(units[i]) then
			local dmgFactor = AbilityLogic_CastOnTargetWillSucceed(gsiPlayer, units[i], hAbility)
			if dmgFactor > bestDmgFactor then
				bestDmgTarget = units[i]
			end
		end
	end
	return bestDmgTarget, bestDmgFactor, bestDmgFactor > acceptableFactor
end

local al_gcsu_platter = {}
-- Freely causes bugs with platter
-------- AbilityLogic_GetCastSucceedsUnits()
function AbilityLogic_GetCastSucceedsUnits(gsiPlayer, units, hAbility)
	local unitsPlatter = al_gcsu_platter
	local countSucceeds = 0
	
	for i=1,#units do
		if AbilityLogic_CastOnTargetWillSucceed(gsiPlayer, units[i], hAbility) > 0 then
			countSucceeds = countSucceeds + 1
			unitsPlatter[countSucceeds] = units[i]
		end
	end
	
	unitsPlatter[countSucceeds+1] = nil
	unitsPlatter[countSucceeds+2] = nil

	return unitsPlatter
end

function AbilityLogic_HighestPowerOHK(gsiPlayer, hAbility, units, dmg, ignoreMana)
	if not ignoreMana or gsiPlayer.lastSeenMana < foD:GetManaCost() then
		return nil, 4000
	end
	local highestPowerKill = nil
	local highestPower = -0xFFFF
	for i=1,#units do
		local thisUnit = units[i]
		local thisPowerLevel = Analytics_GetPowerLevel(thisUnit)
		if not pUnit_IsNullOrDead(units)
				and thisPowerLevel > highestPower then
			if AbilityLogic_AllowOneHitKill(
						gsiPlayer,
						thisUnit,
						foD:GetCastRange(),
						dmg
					) then
				highestPowerKill = thisUnit
				highestPower = thisPowerLevel
			end
		end
	end
end

local al_gekv_platter = {}
-- Good for searching for smites, however dots and allies may be in the fight
-- -| best to be using a damage tracker to exclude units
-- Freely causes bugs with platter
-------- AbilityLogic_GetLowHealthVulnerableToAbility()
function AbilityLogic_GetEfficientKillVulnerable(gsiPlayer, hAbility, units, damage, allHeroes, killsWin)
	local unitsPlatter = units
	local countSucceeds = 0

	local dmgFactorWeight = killsWin and 0 or 1

	local bestScore = 0
	local bestFactor = 0
	local bestCouldKill = false
	local bestUnit
	
	for i=1,#units do
		local thisUnit = units[i]
		local dmgFactor = AbilityLogic_CastOnTargetWillSucceed(gsiPlayer, thisUnit, hAbility)
		if dmgFactor > 0 then
			countSucceeds = countSucceeds + 1
			unitsPlatter[countSucceeds] = thisUnit
			local remainingHealth = thisUnit.lastSeenHealth + 10 - dmgFactor*damage
-- [[METRICS]] KDA of 33 above their allies will flip to pointless vengeance at near-death rather than kill shot at a low KDA
			local couldKill = remainingHealth < 0
			local score = dmgFactor + (allHeroes and GSI_GetKDA(thisUnit)*0.03) 
					+ (couldKill and 2 or 1-(remainingHealth/thisUnit.maxHealth))
			if score > bestScore or (killsWin and couldKill and not bestCouldKill) then
				bestScore = score
				bestFactor = dmgFactor
				bestCouldKill = couldKill
				bestUnit = thisUnit
			end
		end
	end
	
	unitsPlatter[countSucceeds+1] = nil
	unitsPlatter[countSucceeds+2] = nil

	return bestUnit, bestFactor, bestCouldKill, unitsPlatter
end

-------- AbilityLogic_InformAbilityCast()
function AbilityLogic_InformAbilityCast(gsiPlayer, hAbility)
	--print("Got ability", gsiPlayer.shortName, hAbility:GetName())
	--print(gsiPlayer.team, TEAM, hAbility:GetCooldown())
	--print(hAbility:GetCooldownTimeRemaining())
	FightClimate_InformAbilityCast(gsiPlayer, hAbility)
end

-------- AbilityLogic_UpdateHighUseMana()
function AbilityLogic_UpdateHighUseMana(gsiPlayer, abilities)
	if not gsiPlayer.updateHighUseMana then
		gsiPlayer.updateHighUseMana = AbilityLogic_UpdateHighUseMana
		gsiPlayer.highUseManaExpendNow = Time_CreateThrottle(0.33)
		gsiPlayer.highUseManaExpendNow.mana = 0
		gsiPlayer.highUseManaExpendNow.decrement = 0
	end
	local totalMana = 0
	local abilityCount = 0
	for i=0,MAX_ABILITY_SLOT do
		local hAbility = abilities[i]
		if hAbility and type(hAbility) == "table" and hAbility:GetLevel() > 0 then
			totalMana = totalMana + hAbility:GetManaCost()
			abilityCount = abilityCount + 1
		end
	end
	-- 30/03/23 - Due to the bug meaning high use mana has been 0 for
	-- -| all bots, and for a while, it is decreased so that behavioral
	-- -| changes are not drastic.. untested. TODO
	gsiPlayer.highUseManaSimple = min(gsiPlayer.maxMana*0.67, totalMana * 0.67)
end
