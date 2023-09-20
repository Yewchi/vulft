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

-- Registers and creates data initialization functions (for hero.lua) for heroes per what is stored in (existing or non-existing, unimplemented) hero modules (ancient_apparition.lua ... zues.lua)

HERO_ABILITY_THINK_THROTTLE = 0.223 -- .'. heroes will think of using any of their abilities, or initiating a combo just over 4 times a second.

LANE_ROLE_I__LANE = 1
LANE_ROLE_I__ROLE = 2
LANE_ROLE_I__SOLO_POTENTIAL = 3

HD_I__SHORT_NAME = 1
HD_I__SKILL_BUILD = 2
HD_I__ITEM_BUILD = 3
HD_I__LANE_AND_ROLE = 4
HD_I__ABILITY_NAME_INDICES = 5

local t_untested_and_loaded_heroes = {}

local hero_search_funcs = {}

local hero_data = { -- Known heroes -> loads to hero data if in-game -- doesn't mean tested/implemented
	["default"] = true,
	["abaddon"] = true,
	["abyssal_underlord"] = true,
	["alchemist"] = true,
	["ancient_apparition"] = true,
	["antimage"] = true,
	["arc_warden"] = true,
	["axe"] = true,
	["bane"] = true,
	["batrider"] = true,
	["beastmaster"] = true,
	["bloodseeker"] = true,
	["bounty_hunter"] = true,
	["brewmaster"] = true,
	["bristleback"] = true,
	["broodmother"] = true,
	["centaur"] = true,
	["chaos_knight"] = true,
	["chen"] = true,
	["clinkz"] = true,
	["crystal_maiden"] = true,
	["dark_seer"] = true,
	["dark_willow"] = true,
	["dawnbreaker"] = true,
	["dazzle"] = true,
	["death_prophet"] = true,
	["disruptor"] = true,
	["doom_bringer"] = true,
	["dragon_knight"] = true,
	["drow_ranger"] = true,
	["earthshaker"] = true,
	["earth_spirit"] = true,
	["elder_titan"] = true,
	["ember_spirit"] = true,
	["enchantress"] = true,
	["enigma"] = true,
	["faceless_void"] = true,
	["furion"] = true,
	["grimstroke"] = true,
	["gyrocopter"] = true,
	["hoodwink"] = true,
	["huskar"] = true,
	["invoker"] = true,
	["jakiro"] = true,
	["juggernaut"] = true,
	["keeper_of_the_light"] = true,
	["kunkka"] = true,
	["legion_commander"] = true,
	["leshrac"] = true,
	["lich"] = true,
	["life_stealer"] = true,
	["lina"] = true,
	["lion"] = true,
	["lone_druid"] = true,
	["luna"] = true,
	["lycan"] = true,
	["magnataur"] = true,
	["marci"] = true,
	["mars"] = true,
	["medusa"] = true,
	["meepo"] = true,
	["mirana"] = true,
	["monkey_king"] = true,
	["morphling"] = true,
	["muerta"] = true,
	["naga_siren"] = true,
	["necrolyte"] = true,
	["nevermore"] = true,
	["night_stalker"] = true,
	["nyx_assassin"] = true,
	["obsidian_destroyer"] = true,
	["ogre_magi"] = true,
	["omniknight"] = true,
	["oracle"] = true,
	["pangolier"] = true,
	["phantom_assassin"] = true,
	["phantom_lancer"] = true,
	["phoenix"] = true,
	["primal_beast"] = true,
	["puck"] = true,
	["pudge"] = true,
	["pugna"] = true,
	["queenofpain"] = true,
	["rattletrap"] = true,
	["razor"] = true,
	["riki"] = true,
	["rubick"] = true,
	["sand_king"] = true,
	["shadow_demon"] = true,
	["shadow_shaman"] = true,
	["shredder"] = true,
	["silencer"] = true,
	["skeleton_king"] = true,
	["skywrath_mage"] = true,
	["slardar"] = true,
	["slark"] = true,
	["snapfire"] = true,
	["sniper"] = true,
	["spectre"] = true,
	["spirit_breaker"] = true,
	["storm_spirit"] = true,
	["sven"] = true,
	["techies"] = true,
	["templar_assassin"] = true,
	["terrorblade"] = true,
	["tidehunter"] = true,
	["tinker"] = true,
	["tiny"] = true,
	["treant"] = true,
	["troll_warlord"] = true,
	["tusk"] = true,
	["undying"] = true,
	["ursa"] = true,
	["vengefulspirit"] = true,
	["venomancer"] = true,
	["viper"] = true,
	["visage"] = true,
	["void_spirit"] = true,
	["warlock"] = true,
	["weaver"] = true,
	["windrunner"] = true,
	["winter_wyvern"] = true,
	["wisp"] = true,
	["witch_doctor"] = true,
	["zuus"] = true,
}

local game_losing_channels = {} -- i.e. not lion's mana drain, the cut-off is probably tinker's rearm

function HeroData_SearchFuncForHero(shortName)
	local foundOrNot = hero_search_funcs[shortName]
	return foundOrNot or hero_search_funcs["default"]
end

function HeroData_SetHeroData(heroData, abilities, searchFunc, untested)
	local thisShortName = heroData[HD_I__SHORT_NAME]
	hero_data[thisShortName] = heroData
	hero_search_funcs[thisShortName] = searchFunc
	Hero_RegisterBehavior(thisShortName, heroData[HD_I__SKILL_BUILD], heroData[HD_I__ABILITY_NAME_INDICES], heroData[HD_I__ITEM_BUILD], abilities)
	t_untested_and_loaded_heroes[thisShortName] = untested
end

function HeroData_IsHeroUntested(shortName)
	return t_untested_and_loaded_heroes[shortName]
end

function HeroData_RequestHeroKeyValue(shortName, dataKey)
	local search = hero_search_funcs[shortName]
	if not search then 
		--print(string.format("/VUL-FT/ hero_data: %s loading %s data.", TEAM_READABLE, shortName)) 
		--require(string.format(GetScriptDirectory().."/lib_hero/hero/%s",(shortName)))
		if not hero_search_funcs[shortName] then
			if not hero_search_funcs["default"] then
				require("bots/lib_hero/hero/default")
			end
			INFO_print(string.format("Using default hero search data for %s", shortName or "nil"))
			search = hero_search_funcs["default"]
		else
			search = hero_search_funcs[shortName]
		end
	end
	return search(dataKey)
end

function Hero_RegisterGameLosingChannel(heroName, abilityName)
	if not game_losing_channel[heroName] then
		game_losing_channel[heroName] = {}
	end
	game_losing_channel[heroName][abilityName] = true
end

function Hero_CheckGameLosingChannelFactor(gsiPlayer)
	local hero_channels = game_losing_channels[gsiPlayer.shortName]
	if hero_channels and gsiPlayer.hUnit:IsChanneling() then
		local currAbility = gsiPlayer.hUnit:GetCurrentActiveAbility()
		if currAbility and hero_channels[currAbility:GetName()] then
			return 1
		end
	end
	return 0
end

-- Returns hero data and function to load hero behavior
function HeroData_GetHeroRolePreferencesAndBehaviorInit(heroShortName)
	if hero_data[heroShortName] == nil then -- load default if the hero is not found
		if not DEFAULT_HERO_BEHAVIOUR_SHORT_NAME or hero_data[DEFAULT_HERO_BEHAVIOUR_SHORT_NAME] == true then 
			require(GetScriptDirectory().."/lib_hero/hero/default")
		end
		print("/VUL-FT/ <WARN> hero_data: returning placeholder role data for hero missing role preferences '"..heroShortName.."'. Is the hero new / unsupported?")
	elseif hero_data[heroShortName] then
		if type(hero_data[heroShortName]) ~= "table" then
			INFO_print(string.format("loading %s", heroShortName or ""))
			hero_data[heroShortName] = nil -- If we fail, allow default usage on a second try
			require(string.format(GetScriptDirectory().."/lib_hero/hero/%s", heroShortName))
		end
		if type(hero_data[heroShortName]) == "table"  then
			INFO_print(string.format("found hero loaded %s", heroShortName))
			-- return hero lane/role and init func
			return hero_data[heroShortName][HD_I__LANE_AND_ROLE],
					function(gsiPlayer) -- i.e. hero_data's result requires defined hero_behavior init -- something which shall not be changed in an init func above
						return Hero_InitializeBehavior(gsiPlayer.shortName, gsiPlayer)
					end
		end
	end
	-- return default lane/role and init func
	return hero_data[DEFAULT_HERO_BEHAVIOUR_SHORT_NAME][HD_I__LANE_AND_ROLE],
				function(gsiPlayer)
					return Hero_InitializeBehavior(DEFAULT_HERO_BEHAVIOUR_SHORT_NAME, gsiPlayer)
				end
end
