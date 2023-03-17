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

local hero_search_funcs = {}

local hero_data = { -- Known heroes -> loads to hero data if in-game
	["default"] = true,
	["abaddon"] = true,
	["abyssal_underlord"] = true,
	["alchemist"] = true,
	["ancient_apparition"] = true,
	["antimage"] = true,
	["arc_warden"] = true,
	["bane"] = true,
	["bloodseeker"] = true,
	["bounty_hunter"] = true,
	["bristleback"] = true,
	["centaur"] = true,
	["chaos_knight"] = true,
	["clinkz"] = true,
	["crystal_maiden"] = true,
	["dawnbreaker"] = true,
	["dazzle"] = true,
	["death_prophet"] = true,
	["doom_bringer"] = true,
	["dragon_knight"] = true,
	["drow_ranger"] = true,
	["earth_spirit"] = true,
	["ember_spirit"] = true,
	["enchantress"] = true,
	["grimstroke"] = true,
	["gyrocopter"] = true,
	["invoker"] = true,
	["jakiro"] = true,
	["juggernaut"] = true,
	["lich"] = true,
	["life_stealer"] = true,
	["lina"] = true,
	["lion"] = true,
	["luna"] = true,
	["muerta"] = true,
	["necrolyte"] = true,
	["night_stalker"] = true,
	["nyx_assassin"] = true,
	["ogre_magi"] = true,
	["oracle"] = true,
	["omniknight"] = true,
	["queenofpain"] = true,
	["phantom_assassin"] = true,
	["rattletrap"] = true,
	["razor"] = true,
	["sand_king"] = true,
	["silencer"] = true,
	["skeleton_king"] = true,
	["slardar"] = true,
	["snapfire"] = true,
	["sniper"] = true,
	["spirit_breaker"] = true,
	["sven"] = true,
	["tidehunter"] = true,
	["treant"] = true,
	["venomancer"] = true,
	["viper"] = true,
	["void_spirit"] = true,
	["warlock"] = true,
	["weaver"] = true,
	["windrunner"] = true,
	["witch_doctor"] = true,
	["zuus"] = true,
}

local game_losing_channels = {} -- i.e. not lion's mana drain, the cut-off is probably tinker's rearm

function HeroData_SearchFuncForHero(shortName)
	local foundOrNot = hero_search_funcs[shortName]
	return foundOrNot or hero_search_funcs["default"]
end

function HeroData_SetHeroData(heroData, abilities, searchFunc)
	local thisShortName = heroData[HD_I__SHORT_NAME]
	hero_data[thisShortName] = heroData
	hero_search_funcs[thisShortName] = searchFunc
	Hero_RegisterBehaviour(thisShortName, heroData[HD_I__SKILL_BUILD], heroData[HD_I__ABILITY_NAME_INDICES], heroData[HD_I__ITEM_BUILD], abilities)
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

-- Returns hero data and function to load hero behaviour
function HeroData_GetHeroRolePreferencesAndBehaviourInit(heroShortName)
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
					function(gsiPlayer) -- i.e. hero_data's result requires defined hero_behaviour init -- something which shall not be changed in an init func above
						return Hero_InitializeBehaviour(gsiPlayer.shortName, gsiPlayer)
					end
		end
	end
	-- return default lane/role and init func
	return hero_data[DEFAULT_HERO_BEHAVIOUR_SHORT_NAME][HD_I__LANE_AND_ROLE],
				function(gsiPlayer)
					return Hero_InitializeBehaviour(DEFAULT_HERO_BEHAVIOUR_SHORT_NAME, gsiPlayer)
				end
end
