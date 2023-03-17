
require(GetScriptDirectory().."/personality")

local APIGameTime = GameTime
local GameTime = GameTime

local MAX_PLAYERS = 10

local HERO_ALREADY_PICKED_FLAG = false
local HERO_UNPICKED_UNLOADED_FLAG = nil
local HERO_UNPICKED_STR = ""

local t_heroes_implemented = {
		[-1] = "default", -- used when a hero has been picked that VUL-FT doesn't have data for
		[0] = "npc_dota_hero_void_spirit",
		"npc_dota_hero_abaddon",
		"npc_dota_hero_abyssal_underlord",
		--"npc_dota_hero_alchemist",
		"npc_dota_hero_ancient_apparition",
		--"npc_dota_hero_antimage",
		"npc_dota_hero_arc_warden",
		"npc_dota_hero_bane",
		"npc_dota_hero_bloodseeker",
		"npc_dota_hero_bounty_hunter",
		"npc_dota_hero_bristleback",
		--"npc_dota_hero_centaur",
		"npc_dota_hero_chaos_knight",
		--"npc_dota_hero_crystal_maiden",
		"npc_dota_hero_dawnbreaker",
		"npc_dota_hero_death_prophet",
		"npc_dota_hero_doom_bringer",
		"npc_dota_hero_dragon_knight",
		"npc_dota_hero_drow_ranger",
		"npc_dota_hero_enchantress",
		"npc_dota_hero_grimstroke",
		"npc_dota_hero_gyrocopter",
		--"npc_dota_hero_invoker",
		--"npc_dota_hero_jakiro",
		--"npc_dota_hero_juggernaut",
		"npc_dota_hero_lich",
		--"npc_dota_hero_life_stealer",
		"npc_dota_hero_lina",
		"npc_dota_hero_lion",
		--"npc_dota_hero_luna",
		"npc_dota_hero_muerta",
		"npc_dota_hero_night_stalker",
		"npc_dota_hero_nyx_assassin",
		"npc_dota_hero_ogre_magi",
		"npc_dota_hero_phantom_assassin",
		"npc_dota_hero_queenofpain",
		--"npc_dota_hero_rattletrap",
		"npc_dota_hero_sand_king",
		"npc_dota_hero_silencer",
		"npc_dota_hero_skeleton_king",
		"npc_dota_hero_slardar",
		"npc_dota_hero_sniper",
		"npc_dota_hero_sven",
		--"npc_dota_hero_tidehunter",
		"npc_dota_hero_treant",
		"npc_dota_hero_viper",
		"npc_dota_hero_warlock",
		"npc_dota_hero_weaver",
		--"npc_dota_hero_windrunner",
		"npc_dota_hero_zuus",
		--"npc_dota_hero_clinkz",
		--"npc_dota_hero_dark_seer",
		--"npc_dota_hero_earth_spirit",
		--"npc_dota_hero_omniknight",
		--"npc_dota_hero_snapfire",
		--"npc_dota_hero_spirit_breaker",
		--"npc_dota_hero_venomancer",
  --	"npc_dota_hero_abyssal_underlord",
  --	"npc_dota_hero_ancient_apparition",
  --	"npc_dota_hero_arc_warden",
  --	"npc_dota_hero_enchantress",
  --	"npc_dota_hero_void_spirit",
}

local pick_pool = {} -- heroes will be randomly loaded and considered for picking based on their role data from 5 recent DotaBuff matches
-- TODO Include a synergy_and_counters.lua to inform picking, automating data. Increasingly random for bot difficulty levels dropped.

function GetBotNames()
	local playerNameOfBots = {}
	for i=0,MAX_PLAYERS-1,1 do
		local randomBotPersonalityN = RandomInt(1, #BOT_PERSONALITIES)
		while(BOT_PERSONALITIES[randomBotPersonalityN][BOT_PERSONALITIES_I__TAKEN]) do
			randomBotPersonalityN = RandomInt(1, #BOT_PERSONALITIES)
		end
		BOT_PERSONALITIES[randomBotPersonalityN][BOT_PERSONALITIES_I__TAKEN] = true
		playerNameOfBots[i] = BOT_PERSONALITIES[randomBotPersonalityN][BOT_PERSONALITIES_I__NAME]
	end
	--print("Player", i, "picking", TEMPORARY_PICKS[i+1])
	
	return playerNameOfBots
end

local abs = math.abs
local floor = math.floor

--TEMPORARY
local NEXT_PICK_WAIT = 7.5
local NEXT_PICK_POOL_ADDITION_WAIT = 0.75
local MAX_NEXT_PICK_WAIT_RANDOM_TIME = 7.0
local next_turn_to_pick_time
local next_pick_pool_addition
local turn_to_pick = 0
local team_members
local enemy_members
local players_to_watch = {}
local enemy_heroes_picked_count
local still_making_picks = true
local team_pick_offset = GetTeam() == TEAM_RADIANT and -1 or 4
local pick_pool = {}
local num_heroes_loaded = 0
local num_heroes_implemented = #t_heroes_implemented + 1 -- 0 index for mod rotate
local MAX_RANDOM_REJECTS = math.ceil(num_heroes_implemented * 0.33)

local ENEMY_TEAM_NUMBER_OF_PLAYERS = 5

-- lane-role and hero-data indices
local LR_I__LANE = 1
local LR_I__ROLE = 2
local LR_I__SOLO_POTENTIAL = 3
local HD_I__SHORT_NAME = 1
local HD_I__SKILL_BUILD = 2
local HD_I__ITEM_BUILD = 3
local HD_I__LANE_AND_ROLE = 4
local HD_I__ABILITY_NAME_INDICES = 5

local NUM_ROLE_DATA = 5
local MAX_ROLE_TYPES = 5
local MAX_PLAYERS = MAX_ROLE_TYPES -- to inform what is iterated
local GIVING_IT_AWAY_FACTOR = {1.0, 0.8, 0.5, 0.4, 0.3}

local MAX_ATTEMPTS_FIND_GOOD_PICK = 10

local already_taken_roles = {} -- eliminate open roles.

local roles_possible = {} -- roles a player can fill with their selected hero
local role_distribution = {0, 0, 0, 0, 0} -- how many players could pick each role

local function load_role_data_by_name(heroName, pick_index)
	-- Search for the hero if the player had already picked without being loaded
	print("/VUL-FT/ [#] [hero_selection]", GetTeam(), "loading hero", heroName)
	if not pick_index then
		--print(string.format("/VUL-FT/ searching for already picked '%s'.", heroName))
		local i=0
		while(i < num_heroes_implemented) do
			if t_heroes_implemented[i] == heroName then
				pick_index = i
				break;
			end
			i = i + 1
		end
		if i == num_heroes_implemented then
			print(string.format("/VUL-FT/ [WARN] '%s' from %d known heroes not found. loading default role data...", heroName or 'nil', num_heroes_implemented))
			heroName = "default"
			pick_index = -1
		end
	end
	-- load the hero if needed
	if not pick_pool[pick_index] then
		local heroFileStr = string.format("bots/lib_hero/hero/%s", heroName:gsub("npc_dota_hero_", ""))
		-- require it's file in-which it will set the temporary pick-data global
		pick_pool[pick_index] = require(heroFileStr)
		print("/VUL-FT/ [#] loaded pick option:", t_heroes_implemented[pick_index], pick_pool[pick_index], pick_index, "team:", GetTeam() == TEAM_RADIANT and "Radiant" or "Dire")
	end
	return pick_pool[pick_index][HD_I__LANE_AND_ROLE][LR_I__ROLE]
end
local function add_random_hero_to_pick_pool()
	local tryAddHeroIndex = RandomInt(0, num_heroes_implemented-1)
	-- find an unloaded hero
	for i=0,num_heroes_implemented do
		tryAddHeroIndex = (tryAddHeroIndex + 1) % num_heroes_implemented
		if pick_pool[tryAddHeroIndex] == HERO_UNPICKED_UNLOADED_FLAG then
			load_role_data_by_name(t_heroes_implemented[tryAddHeroIndex], tryAddHeroIndex)
			num_heroes_loaded = num_heroes_loaded + 1
			return
		end
	end
end
local enemy_heroes_picked = 0
local function get_enemy_heroes_picked_count()
	enemy_heroes_picked = 0
	for playerIndex=1,#enemy_members do
		if GetSelectedHeroName(enemy_members[playerIndex]) ~= HERO_UNPICKED_STR then
			enemy_heroes_picked = enemy_heroes_picked + 1
		end
	end
	return enemy_heroes_picked
end
local function hero_is_free(heroName, pickPoolIndex)
	for playerIndex=1,#team_members do
		if string.find(GetSelectedHeroName(team_members[playerIndex]), heroName) then
			return false
		end
	end
	for playerIndex=1,#enemy_members do 
		if string.find(GetSelectedHeroName(enemy_members[playerIndex]), heroName) then
			return false
		end
	end
	return true
end
local depth = 0
local MAX_DETECT_DEPTH = 601 -- 5!
-- Heap's algorithm, with locked-roles check at the permutation-found step. O(n!*n^2) I think, with 1 <= n <= 5
-- 		There's a reasonable chance this is ill-applied, and could be n-time. But Heap's alg' is very cool.
local function detect_taken_roles(k, permutation)
	-- End-of-combination
	-- init
	if not k then
		k = #roles_possible
		permutation = {}
		-- returning true means we've found a never-before-found hard-set role.
		-- returning nil/false means no more to find
		while(true) do
			depth = 0
			for i=1,k do
				permutation[i] = i
			end
			if not detect_taken_roles(k, permutation) then -- (not the recursive process)
				break;
			end
		end
		return
	end
	depth = depth + 1
	if depth > MAX_DETECT_DEPTH then print("/VUL-FT/ [ERR] - depth > 120, exiting...") depth = 0 return true end
	if k == 1 then
		--[[print(string.format(
						"/VUL-FT/ [#] checking permutation %d %d %d %d %d", 
						permutation[1], permutation[2] or -1, permutation[3] or -1,
						permutation[4] or -1, permutation[5] or -1
					)
			)--]]
		-- Detect locked roles
		local tblOfChoicesToConsider = {}
		local totalChoices = 0
		local totalPlayersConsidered = 0
		-- Iterate through this permutation
		for i=1,#permutation do
			local thisPlayerRoles = roles_possible[permutation[i]]
			local playerIsRelevant = false
			-- add every new role(s), increasing choice count, and find if the player is relevant for locking.
			for j=1,#thisPlayerRoles do
				local thisPossibleRole = thisPlayerRoles[j]
				-- mark off any choices we haven't seen before for this permutation
				if not already_taken_roles[thisPossibleRole] then
					--print("adding role", thisPossibleRole, "for relevant player", permutation[i])
					if not tblOfChoicesToConsider[thisPossibleRole] then
						-- add choosable roles to the list
						totalChoices = totalChoices + 1
						tblOfChoicesToConsider[thisPossibleRole] = true
					end
					playerIsRelevant = true
				end
			end
			if playerIsRelevant then -- done in-step of up this permutation, e.g. next hero might have every role
				totalPlayersConsidered = totalPlayersConsidered + 1
				-- Do these players lock each other's choices?
				-- I.e. another player chosing one of these roles will cause a missed preference?
				--print(totalPlayersConsidered, "==?", totalChoices)
				if totalPlayersConsidered == totalChoices then
					for iRole=1,MAX_ROLE_TYPES do
						--print(iRole, tblOfChoicesToConsider[iRole], already_taken_roles[iRole])
						if tblOfChoicesToConsider[iRole] and not already_taken_roles[iRole] then
							print(string.format("/VUL-FT/ [#] found hard-set role: %d.", iRole))
							already_taken_roles[iRole] = true
						end
					end
					return true -- Start recursion again, at init step, with these added taken roles
				end
			end
		end
		return false -- no role locks found for this permutation
	else
		-- B.R. Heap's algorithm (1963), find permutations
		detect_taken_roles(k-1, permutation)

		for i=0,k-2 do -- just 1-indexing stuff...
			if k % 2 == 0 then
				local tmp = permutation[i+1]
				permutation[i+1] = permutation[k]
				permutation[k] = tmp
			else
				local tmp = permutation[1]
				permutation[1] = permutation[k]
				permutation[k] = tmp
			end
			detect_taken_roles(k-1, permutation)
		end
	end
end
local function update_role_data_for_picks(roleData)
	local thisRolesPossible = {roleData[1]}
	local iRole = 1
	role_distribution[roleData[1]] = role_distribution[roleData[1]] + 1
	for i=1,NUM_ROLE_DATA do
		role_distribution[roleData[i]] = role_distribution[roleData[i]] + (MAX_ROLE_TYPES - i)*0.2
		if roleData[i] ~= thisRolesPossible[iRole] then
			iRole = iRole + 1
			thisRolesPossible[iRole] = roleData[i]
		end
	end
	table.insert(roles_possible, thisRolesPossible)
	-- not sure of a better sol'n. Knowing what is disqualified, add options to the tbl of available choices. If ever
	-- 		the number of choices == number of players processed, the roles present in the table are locked.
	-- 		if a locked role is found, restart with the new known locks.
	print("/VUL-FT/ [#] this pick's seen-played roles", thisRolesPossible[1], thisRolesPossible[2], thisRolesPossible[3], thisRolesPossible[4], thisRolesPossible[5])
	detect_taken_roles()
end
local function roles_able_based_scoring_as_role(mainRole, roleToCheck, inversePickStage, pickStageDampening)
	return (already_taken_roles[roleToCheck] and 10.0 or 0)
			+ abs(mainRole - inversePickStage)/6.67
				/ (1.5 - 0.5*GIVING_IT_AWAY_FACTOR[roleToCheck]*pickStageDampening) -- making the 1.5 more significant at later stages, thereby lowering adversity
			+ role_distribution[roleToCheck]*0.33
			+ RandomFloat(0.0, 0.125)
end
local function pick_hero(pickPoolIndex, playerId)
	-- Makes a meager attempt to avoid AM-first-pick, and edge towards Lich.
	-- Return if not a bot 
	if GetSelectedHeroName(playerId) ~= HERO_UNPICKED_STR then
		update_role_data_for_picks(load_role_data_by_name(GetSelectedHeroName(playerId)))
		return false
	end
	if not IsPlayerBot(team_members[turn_to_pick]) then
		return false -- Think() main will catch human pick
	end

	-- loop through picks to find low-enough give it away
	local lowestPickAdversity = 0xFFFF
	local lowestIndex
	local lowSafetyPick = RandomInt(0,num_heroes_implemented-1)
	local resetIndex = (pickPoolIndex + num_heroes_implemented - 1) % num_heroes_implemented
	local attempts = 1
	local inversePickStage = #team_members+1 - turn_to_pick
	local pickStageDampening = inversePickStage*0.2
	local allowedRejects = floor(MAX_RANDOM_REJECTS * (num_heroes_loaded / num_heroes_implemented))
	-- randomly reject high scoring heroes
	--		random rejects work better than random score adjustments, while the algorithm is only so robust
	--		nb. effective while the pickPoolIndex is random and rotates to n-1%size

	while(resetIndex ~= pickPoolIndex) do
		-- check the hero is not already picked
		--print(pickPoolIndex, pick_pool[pickPoolIndex], hero_is_free(t_heroes_implemented[pickPoolIndex], pickPoolIndex))
		if pick_pool[pickPoolIndex] then
			if not hero_is_free(t_heroes_implemented[pickPoolIndex], pickPoolIndex) then
				pick_pool[pickPoolIndex] = HERO_ALREADY_PICKED_FLAG
				goto NEXT_TRY_PICK;
			end
			-- calculate in basic how much we're revealing the strat
			-- factor in need for the role
			local roleData = pick_pool[pickPoolIndex][HD_I__LANE_AND_ROLE][LR_I__ROLE]
			local mainRole = roleData[1] -- roleData is ordered by most picked, heroes with 2 matches of 2 roles and 1 other role are arbitrarily selected, giving inaccuracy
			local satisfiesOneRole = not already_taken_roles[mainRole] and mainRole or false
			local pickAdversity = satisfiesOneRole
					and roles_able_based_scoring_as_role(mainRole, mainRole, inversePickStage, pickStageDampening)
					or 10.0
			for i=2,NUM_ROLE_DATA do
				-- Check the secondary roles 'viable' (a dig at the way DotaBuff recent matches lane and role have been interpretted).
				-- Decrease the pick adversity if we don't give away core role counters
				local thisSecondaryRole = roleData[i]
				if thisSecondaryRole and thisSecondaryRole ~= mainRole and not already_taken_roles[thisSecondaryRole] then
					local tmp = roles_able_based_scoring_as_role(mainRole, thisSecondaryRole, inversePickStage, pickStageDampening)
					if not already_taken_roles[thisSecondaryRole] then
						pickAdversity = pickAdversity < tmp and pickAdversity or tmp
						satisfiesOneRole = satisfiesOneRole == mainRole and mainRole or thisSecondaryRole
					end
				end
			end
			-- TODO add synergy data and synergy/counter consideration
			pickAdversity = pickAdversity + (satisfiesOneRole and not already_taken_roles[satisfiesOneRole]
					and mainRole >= inversePickStage
					and (1+role_distribution[mainRole])*0.075*pickStageDampening or 0)
					-- encourages higher position picks at later stages 
			-- if lowest, set
			print(pickPoolIndex, t_heroes_implemented[pickPoolIndex], satisfiesOneRole, pickAdversity, lowestPickAdversity, lowestIndex)
			if satisfiesOneRole and pickAdversity < lowestPickAdversity then
				if allowedRejects > 0 and RandomFloat(0,1) < 0.83 then
					allowedRejects = allowedRejects - 1
					print("/VUL-FT/ [#] Randomly rejecting ", t_heroes_implemented[pickPoolIndex], "remaining:", allowedRejects)
				else
					lowestPickAdversity = pickAdversity
					lowestIndex = pickPoolIndex
				end
				lowSafetyPick = pickPoolIndex
			end
		end
		::NEXT_TRY_PICK::
		pickPoolIndex = (pickPoolIndex + 1) % num_heroes_implemented
	end
	-- pick
	if not lowestIndex then
		-- if we couldn't find a satisfactory pick, or all were randomly rejected due to say,
		-- - the astronomical chance of only support being loaded for picking, then use a
		-- - considered-suitable but rejected pick, and further if we never found one at all,
		-- - pick randomly from the loaded heroes.
		if pick_pool[lowSafetyPick] then
			lowestIndex = lowSafetyPick
		else
			local i = lowSafetyPick
			if lowSafetyPick > num_heroes_implemented-1 or lowSafetyPick < 0 then
				print("/VUL-FT/ [WARN] -- initialized-as-random safety pick index was out-of-range.")
				i = 0
				lowSafetyPick = num_heroes_implemented - 1
			end
			print("/VUL-FT/ [WARN] No hero with a suitable role was loaded, forcing near-role.")
			while(1) do
				--print("may pick", t_heroes_implemented[i])
				if pick_pool[i] and hero_is_free(t_heroes_implemented[i]) then
					lowestIndex = i
					break; -- found a random hero, in this strange circumstance
				end
				i = i + 1
				if i == lowSafetyPick then
					print("/VUL-FT/ [ERR] -- Fatal error, no heroes were found in pick pool array at picking step. Please shoot the dev.")
					break; -- ?? wth
				elseif i >= num_heroes_implemented then -- 0-indexed
					i = 0
					killIt = true
				end
				if i < 0 or (i >= num_heroes_implemented - 1 and killIt) then
					print("/VUL-FT/ [ERR] -- Fatal error, no heroes were found in pick pool array at picking step. Please shoot the dev.")
					break;
				end
			end
		end
	end

	--print("hero is free", hero_is_free(t_heroes_implemented[lowestIndex]))
	SelectHero(team_members[turn_to_pick], t_heroes_implemented[lowestIndex])

	-- update hard-set roles
	update_role_data_for_picks(pick_pool[lowestIndex][HD_I__LANE_AND_ROLE][LR_I__ROLE])
	return true
end
function Think()
	-- Check TeamPlayers data ready and init
	if not next_turn_to_pick_time then
		InstallChatCallback(
			function(event)
				if not FAST_PICK_ON then 
					FAST_PICK_ON = true
					print(event.string)
					if event.string == "!fastpick" or event.string == "!goo" or event.string == "!..bruh" or event.string == "!skettit" or event.string == "!fast" or event.string == "!pickfast" then
						print("Picking speed increased...")
						if not event.team_only then
							print("-- Make sure to type the command like '/all !fast' to have both teams increase speed")
						end
						next_turn_to_pick_time = next_turn_to_pick_time / 4
						next_pick_pool_addition = next_pick_pool_addition / 4
						NEXT_PICK_WAIT = NEXT_PICK_WAIT / 4
						NEXT_PICK_POOL_ADDITION_WAIT = NEXT_PICK_POOL_ADDITION_WAIT / 4
						MAX_NEXT_PICK_WAIT_RANDOM_TIME = MAX_NEXT_PICK_WAIT_RANDOM_TIME / 4
					end
				end
			end
		)

		team_members = GetTeamPlayers(GetTeam())
		enemy_members = GetTeamPlayers(GetOpposingTeam())
		print(#team_members, #enemy_members, team_members[1], team_members[4], enemy_members[1], enemy_members[4], "members")
		if not team_members or not enemy_members then return end
		for i=1,#team_members do
			print("/VUL-FT/ [hero_selection] Found team member", team_members[i])
			if not IsPlayerBot(team_members[i]) then
				table.insert(players_to_watch, team_members[i])
			end
		end
		next_turn_to_pick_time = GameTime() + NEXT_PICK_WAIT + RandomFloat(0, 6)
		next_pick_pool_addition = GameTime() + NEXT_PICK_POOL_ADDITION_WAIT
		turn_to_pick = 1

--[[DEV]]		if GetTeam() == 3 then 
--[[DEV]]			SelectHero(9, "npc_dota_hero_doom_bringer")
--[[DEV]]		end

		return
	end
	-- Speed up the picks if the enemy finished picking
	if enemy_heroes_picked == ENEMY_TEAM_NUMBER_OF_PLAYERS
			and GameTime == APIGameTime then
		local startIncreaseSpeed = startIncreaseSpeed or GameTime()
		GameTime = function()
			return APIGameTime() + (APIGameTime() - startIncreaseSpeed)^1.67
		end
	end
	-- Check player picks
	if players_to_watch[1] then
		local i = 1
		while(i <= #players_to_watch) do
			if GetSelectedHeroName(players_to_watch[i]) ~= HERO_UNPICKED_STR then
				update_role_data_for_picks(
						load_role_data_by_name(
								GetSelectedHeroName(players_to_watch[i])
							)
					)
				table.remove(players_to_watch, i)
				i=i-1
				--next_pick_pool_addition = next_turn_to_pick_time + NEXT_PICK_WAIT/3 
			end
			i=i+1
		end
	end

	-- Add heroes to the pick pool for consideration intermittently
	if still_making_picks then
		if next_pick_pool_addition < GameTime() then
			get_enemy_heroes_picked_count()
			add_random_hero_to_pick_pool()
			next_pick_pool_addition = GameTime() + NEXT_PICK_POOL_ADDITION_WAIT
		end
		-- Pick a hero from the pick pool which suits a required role, or keeps our options open
		if still_making_picks and next_turn_to_pick_time < GameTime() then
			if pick_hero(RandomInt(0, num_heroes_implemented-1), team_members[turn_to_pick]) then
				next_turn_to_pick_time = GameTime() + NEXT_PICK_WAIT + RandomFloat(0.0, MAX_NEXT_PICK_WAIT_RANDOM_TIME)
			end
			if turn_to_pick == 5 then
				still_making_picks = false
				-- Clean-up the required files - we were just stealing their prepended hero-data
				-- TODO If a player picks very late, or the last to pick, will we not have a broken package.loaded?
				for k,v in pairs(package.loaded) do
					if type(v) == "table" and string.find(k, "bots/lib_hero/hero/") then
						for j,w in pairs(v) do
							v[j] = nil
						end
						package.loaded[k] = nil
					end
				end
			else
				turn_to_pick = turn_to_pick + 1
				if false and turn_to_pick == 5 then
					SelectHero(team_members[turn_to_pick], "npc_dota_hero_invoker")
				end
			end
		end
	end
end
