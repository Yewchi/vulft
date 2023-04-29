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

-- Stores per-hero data for heros to load as per-player data for ability and item modules

HERO_BEHAVIOUR_I__SKILL_BUILD = 1
HERO_BEHAVIOUR_I__ABILITY_NAME_INDICES = 2
HERO_BEHAVIOUR_I__ITEM_BUILD = 3 -- item string names are converted to hItem
HERO_BEHAVIOUR_I__ABILITIES = 4
HERO_BEHAVIOUR_I__ABILITY_THOUGHT = 5

local t_hero_behavior = {}

function Hero_RegisterBehavior(shortName, skillBuild, abilitiesIndex, itemBuild, abilities)
	t_hero_behavior[shortName] = {skillBuild, abilitiesIndex, itemBuild, abilities}
end

require(GetScriptDirectory().."/lib_hero/item/item")
require(GetScriptDirectory().."/lib_hero/ability/ability")
require(GetScriptDirectory().."/lib_hero/special_behavior")

function Hero_InvestAbilityPointsAndManageItems(gsiPlayer)
	--[BENCH]]local prevFrame = RealTime()
	Ability_HandleAbilityUpgrades(gsiPlayer)
	Item_HandleItemShop(gsiPlayer)
	Item_TryOptimalInventoryOrientation(gsiPlayer)
	--[BENCH]]local elapsed = RealTime() - prevFrame
	--[BENCH]]if elapsed > 0.0001 then --02/09/21 HandleAbilityUpgrades, HandleItemShop, TryOptimalInventOrien 0.00024s
	--[BENCH]]	print(gsiPlayer.shortName, "took", RealTime() - prevFrame)
	--[BENCH]]end
end

function Hero_InitializeBehavior(shortNameOrDefault, gsiPlayer)
	local nOnTeam = gsiPlayer.nOnTeam
--[[VERBOSE]]if VERBOSE then VEBUG_print(string.format("hero_behavior: initializing behavior for '%s'.", gsiPlayer.shortName)) end
	local thisPlayerHeroBehaviorIndex
	if t_hero_behavior[shortNameOrDefault] then
		thisPlayerHeroBehaviorIndex = shortNameOrDefault
	elseif t_hero_behavior[DEFAULT_HERO_BEHAVIOUR_SHORT_NAME] then
		if shortNameOrDefault ~= DEFAULT_HERO_BEHAVIOUR_SHORT_NAME then
			print(string.format("/VUL-FT/ <WARN> hero_behavior: hero_data implied a valid hero file for '%s'", shortNameOrDefault))
		end
		thisPlayerHeroBehaviorIndex = DEFAULT_HERO_BEHAVIOUR_SHORT_NAME
	else
		print(string.format("/VUL-FT/ <WARN> hero_behavior: Loading default behavior for shortNameOrDefault: '%s'.%s", shortNameOrDefault, shortNameOrDefault ~= DEFAULT_HERO_BEHAVIOUR_SHORT_NAME and " hero_data implied a valid hero file." or ""))
		local defaultBehavior = Hero_DefaultUninitializedSafetyGetter()
		--if shortNameOrDefault then -- I can't work out why I've done this lol, removing for now... We didn't have the default, but after this we will so... probably okay to remove.
		t_hero_behavior[DEFAULT_HERO_BEHAVIOUR_SHORT_NAME] = defaultBehavior --end
		thisPlayerHeroBehaviorIndex = DEFAULT_HERO_BEHAVIOUR_SHORT_NAME
	end
	if thisPlayerHeroBehaviorIndex then
		local thisPlayerBehavior = t_hero_behavior[thisPlayerHeroBehaviorIndex]
		Item_InitializePlayer(gsiPlayer, t_hero_behavior[thisPlayerHeroBehaviorIndex][HERO_BEHAVIOUR_I__ITEM_BUILD])
		Ability_InitializePlayer(	
				gsiPlayer, 
				thisPlayerBehavior[HERO_BEHAVIOUR_I__SKILL_BUILD],
				thisPlayerBehavior[HERO_BEHAVIOUR_I__ABILITY_NAME_INDICES],
				thisPlayerBehavior[HERO_BEHAVIOUR_I__ABILITIES]
			)
		-- AbilityThink_RegisterPlayerAbilityThought(gsiPlayer, thisPlayerBehavior[HERO_BEHAVIOUR_I__ABILITY_THOUGHT])
	end
end
