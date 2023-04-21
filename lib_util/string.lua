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

function String_FindTalentBestMatch(key, hAbility1, hAbility2) -- Random / Determined return if no match
	local ability1Score = 0
	local ability2Score = 0
	ability1Score = string.find(string.match(key, "[%d+]"))
end

local special_bonus_declared_names = {
		"_hp_", "_mp_", "attack_speed", "corruption", "cleave", "hp_regen", "mp_regen", 
		"movement_speed", "all_stats", "lifesteal", "intelligence", "strength", "agility", 
		"armor", "magic_resistance", "attack_damage", "attack_range", "cast_range", "spell_amplify", 
		"cooldown_reduction", "respawn_reduction", "gold_income", "evasion", "exp_boost", "_bash_", 
		"_crit_", "spell_lifesteal", "vision", "haste", "truestrike", "spell_immunity", 
		"spell_block", "mana_break", "reincarnation"
}
local special_bonus_search_key_pair = {
		["%d Health$"] = "_hp_",
		["%d Mana$"] = "_mp_",
		["%d Attack Speed"] = "_attack_speed_",
		["%d Armor Corruption"] = "_corruption_",
		["%% Cleave"] = "_cleave_",
		["%d Health Regen"] = "hp_regen",
		["%d Mana Regen"] = "mp_regen",
		["%d Movement Speed"] = "movement_speed",
		["%d All Stat"] = "all_stats",
		["%% Lifesteal"] = "lifesteal",
		["%d Intelligence"] = "intelligence",
		["%d Strength"] = "strength",
		["%d Agility"] = "agility",
		["%d Armor"] = "_armor_",
		["%% Magic Resistance"] = "magic_resistance",
		["%d Damage"] = "attack_damage",
		["%d Attack Range"] = "attack_range",
		["%d Cast Range"] = "cast_range",
		["%% Spell Amplificiation"] = "spell_amplify",
		["%% Cooldown Reduction"] = "cooldown_reduction",
		["%ds Respawn Time"] = "respawn_reduction",
		["%d Gold/Min"] = "gold_income",
		["%% Evasion"] = "evasion",
		["%% XP Gain"] = "exp_boost",
		["%ds Bash"] = "bash",
		["%% Critical Strike"] = "crit",
		["%% Spell Lifesteal"] = "spell_lifesteal",
		["Vision"] = "vision",
		["Haste Movement"] = "haste",
		["True Strike"] = "truestrike",
		["Permanent Spell Immunity"] = "spell_immunity", -- ?? nerf
		["%ds Spell Block"] = "spell_block",
		["%d Mana Break"] = "mana_break",
		["Reincarnation"] = "reincarnation"
}
function String_CompareAbilityStringToBuiltIn(abilityString, abilityBuiltIn)
	local score = 0
	local readableComparisonString = string.gsub(abilityString, "['%-]", "")
	-- feb '21: no abilities that sit on the UI have numbers in their readable name (i.e. abilities that are not talents).
	if string.match(readableComparisonString, "[%d+]") then -- It is almost certainly a special bonus
		if string.match(abilityBuiltIn, "ecial_bo") then
			score = score + 7
		end
	end
	for k,_ in string.gmatch(abilityBuiltIn, "[^_]+") do
		if string.find(readableComparisonString:lower(), k) then
			score = score + 2
		end
	end
	--[[VERBOSE]]if VERBOSE then VEBUG_print(string.format("string: (resolve) '%s', '%s'. similarity: %d", readableComparisonString, abilityBuiltIn, score)) end
	return score
end

function String_CompareTalentStringToBuiltInTier(talentString, bonusBuiltInOne, bonusBuiltInTwo)
	for k,v in pairs(special_bonus_search_key_pair) do
		if string.match(talentString, k) then
			if string.find(bonusBuiltInOne, v) then
				--[[VERBOSE]]if VERBOSE then VEBUG_print(string.format("string: (resolve) found %s in %s giving %s from %s.", k, talentString, bonusBuiltInOne, v)) end
				return 0, bonusBuiltInOne
			elseif string.find(bonusBuiltInTwo, v) then
				--[VERBOSE]]if VERBOSE then VEBUG_print(string.format("string: (resolve) found %s in %s giving %s from %s.", k, talentString, bonusBuiltInTwo, v)) end
				return 1, bonusBuiltInTwo
			end
		end
	end
	local isOneUnique = string.find(bonusBuiltInOne, "unique")
	local isTwoUnique = string.find(bonusBuiltInTwo, "unique")
	if isOneUnique and not isTwoUnique then -- it should have matched a stat/stock talent if it's stat/stock but it didn't.
		return 0, bonusBuiltInOne
	elseif isTwoUnique and not isOneUnique then
		return 1, bonusBuiltInTwo
	end
	-- final backup: string comparison score (probably 100% match for two stock talents; 50% match for two uniques (rarest case))
	local scoreOne = String_CompareAbilityStringToBuiltIn(talentString, bonusBuiltInOne)
	local scoreTwo = String_CompareAbilityStringToBuiltIn(talentString, bonusBuiltInTwo)
	if scoreOne > scoreTwo then
		--[VERBOSE]]if VERBOSE then VEBUG_print(string.format('returning %s', bonusBuiltInOne)) end
		return 0, bonusBuiltInOne 
	else
		--[VERBOSE]]if VERBOSE then VEBUG_print(string.format('returning %s', bonusBuiltInTwo)) end
		return 1, bonusBuiltInTwo
	end
end

function String_GetArgumentTable(str)
	if type(str) ~= "string" then
		return nil
	end
	local tbl = {}
	for arg in string.gmatch(str, "[^%s]+") do
		table.insert(tbl, arg)
	end
	return tbl
end

function String_FindAbilityFromModifier(caster, str)
	-- TODO cut end, sub str search of after name word in abilities
	local strCheck = string.gsub(str, "modifier_", "")
	local caster = caster.hUnit or caster.GetAbilityInSlot
			and caster
	local ability = caster:GetAbilityByName(str)
	return ability or nil
end
