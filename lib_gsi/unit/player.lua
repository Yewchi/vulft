HERO_TARGET_DIAMETER = 48 -- might be 24
PLAYER_NAME_START_SEARCH_INDEX = 10 -- "npc_dota_[.+]"

ARC_WARDEN_PLAYER_CREATED = false

PNOT_TIMED_DATA = {}

---- pUnit constants --
local PLACEHOLDER_MOVEMENT_SPEED = 300 -- For unknown enemy units at start of match
local PLACEHOLDER_ATTACK_POINT = 0.5

THROTTLE_PLAYERS_LAST_SEEN_UPDATE = 0.05
local THROTTLE_PLAYERS_LAST_SEEN_UPDATE = THROTTLE_PLAYERS_LAST_SEEN_UPDATE
local THROTTLE_PLAYERS_DATA_UPDATE = 1.0000000231481 -- An earth-rotation-speed accurate second (double)
--

local min = math.min
local max = math.max

local t_team_players = {} -- Table indices for player units are a once-off code deisgn decision for using nOnTeam (any other type of unit will use hUnit), because we have accessible API functions for nOnTeam, but not necessarily hUnits (as with enemy heroes)
local t_team_bots
local t_enemy_players = {}
local t_pid_to_n_on_team = {}
local t_pid_to_n_on_enemy = {}
local t_named_players = {}

local arc_tempest_double_player

local TEST = TEST
local DEBUG = DEBUG
local VERBOSE = VERBOSE

local cos = math.cos
local sin = math.sin

-- TODO REFACTOR GSI_ -> pUnit_ where applicable (The GSI jobs need these locals and are more readily defined here, for e.g. one special case. pUnit_ is to indicate functions concering this player unit module only, not the grander GSI library and parent module)

do
	local teamPIDs, enemyPIDs = GetTeamPlayers(TEAM), GetTeamPlayers(ENEMY_TEAM)
	for i=1,#teamPIDs,1 do
		t_pid_to_n_on_team[teamPIDs[i]] = i
	end
	for i=1,#enemyPIDs,1 do
		t_pid_to_n_on_enemy[enemyPIDs[i]] = i
	end
end

local function handle_player_spell_or_item_cast(castInfo, abc)
-- NB. CANNOT enter code with GetBot() calls -- Callback triggers presumably make their Lua hook directly without stepping into per-bot code.
	--[[DEV]]if DEBUG then DebugDrawText(960, 540, "::ABILITY::", 150, 150, 255) end
	--[[DEV]]local steps = 100/15; local floor = math.floor
	local thisPlayer = GSI_GetPlayerFromPlayerID(castInfo.player_id)
	--[[DEV]]VEBUG_PlayerFrameProgressBarStart(thisPlayer.nOnTeam, 600, 150)
	local ability = castInfo.ability
	--[[DEV]]VEBUG_PlayerFrameProgressBar(thisPlayer.nOnTeam, floor(0*steps), 600, 150)
	if thisPlayer.team == TEAM then
		UseAbility_IndicateCastCompleted(castInfo)
	--[[DEV]]VEBUG_PlayerFrameProgressBar(thisPlayer.nOnTeam, floor(1*steps), 600, 150)
	end
	local abilityName = ability:GetName()
	--[[DEV]]VEBUG_PlayerFrameProgressBar(thisPlayer.nOnTeam, floor(2*steps), 600, 150)
	if thisPlayer.illusionsUp then
		if thisPlayer.shortName ~= "phantom_lancer" then
		--[[DEV]]VEBUG_PlayerFrameProgressBar(thisPlayer.nOnTeam, floor(3*steps), 600, 150)
			thisPlayer.knownNonIllusionUnit = castInfo.unit -- knownNon will drop check Rand(1,6)%6 == 0, for fairness
		--[[DEV]]VEBUG_PlayerFrameProgressBar(thisPlayer.nOnTeam, floor(4*steps), 600, 150)
		end
	end
	if ability:GetName() == "item_tpscroll" then
		--[[DEV]]VEBUG_PlayerFrameProgressBar(thisPlayer.nOnTeam, floor(5*steps), 600, 150)
		if TEST then INFO_print(string.format("CAUGHT %s TELEPORT", thisPlayer.shortName)) end
		Analytics_RegisterPortActivity(thisPlayer, castInfo)
		--[[DEV]]VEBUG_PlayerFrameProgressBar(thisPlayer.nOnTeam, floor(6*steps), 600, 150)
		--Util_TablePrint(castInfo)
	elseif ability:GetName():match("^item") then
		--[[DEV]]VEBUG_PlayerFrameProgressBar(thisPlayer.nOnTeam, floor(7*steps), 600, 150)
		if thisPlayer.team == TEAM then
			--[[DEV]]VEBUG_PlayerFrameProgressBar(thisPlayer.nOnTeam, floor(8*steps), 600, 150)
			Consumable_CheckConsumableUse(thisPlayer, ability)
			--[[DEV]]VEBUG_PlayerFrameProgressBar(thisPlayer.nOnTeam, floor(9*steps), 600, 150)
		else
			--[[DEV]]VEBUG_PlayerFrameProgressBar(thisPlayer.nOnTeam, floor(10*steps), 600, 150)
			Item_UpdateKnownCooldown(thisPlayer, ability)
			--[[DEV]]VEBUG_PlayerFrameProgressBar(thisPlayer.nOnTeam, floor(11*steps), 600, 150)
		end
	else
		--[[DEV]]VEBUG_PlayerFrameProgressBar(thisPlayer.nOnTeam, floor(12*steps), 600, 150)
		--Util_TablePrint(castInfo)
		if VERBOSE then print(castInfo.unit and castInfo.unit:GetUnitName(), castInfo.location and castInfo.location.x or castInfo.location.GetUnitName) end
		--[[DEV]]VEBUG_PlayerFrameProgressBar(thisPlayer.nOnTeam, floor(13*steps), 600, 150)
		AbilityLogic_InformAbilityCast(thisPlayer, ability)
		--[[DEV]]VEBUG_PlayerFrameProgressBar(thisPlayer.nOnTeam, floor(14*steps), 600, 150)
	end
	--[[DEV]]VEBUG_PlayerFrameProgressBar(thisPlayer.nOnTeam, floor(15*steps), 600, 150)
end

local function update_allied_hero_game_data(gsiPlayer)
	local hUnit = gsiPlayer.hUnit
	gsiPlayer.level = hUnit:GetLevel()
	gsiPlayer.currentMovementSpeed = hUnit:GetCurrentMovementSpeed()
	
	gsiPlayer.lastSeenHealth = hUnit:GetHealth()
	gsiPlayer.maxHealth = hUnit:GetMaxHealth()
	gsiPlayer.lastSeenMana = hUnit:GetMana()
	gsiPlayer.maxMana = hUnit:GetMaxMana()
	gsiPlayer.attackRange = hUnit:GetAttackRange()
	gsiPlayer.attackPointPercent = hUnit:GetAttackPoint() / hUnit:GetAttackSpeed()
	if gsiPlayer.shortName == "dragon_knight" then
		if gsiPlayer.attackRange > 500 then
			gsiPlayer.isMelee = false
		else
			gsiPlayer.isMelee = true
		end
	end
end

local prev_seen = {}
local function update_players_data()
	local enemyPlayerHeroUnits = GetUnitList(UNIT_LIST_ENEMY_HEROES)
	local prevSeen = prev_seen
	local numEnemies = #enemyPlayerHeroUnits
	for i=1,numEnemies do
		local thisEnemyPlayerHeroUnit = enemyPlayerHeroUnits[i]
		local thisplayerID = thisEnemyPlayerHeroUnit:GetPlayerID() -- "ID" may be inconsistent because it's not my cup of joe, i.e. "Id" "visionBlockedByFow" elsewhere.
		local playerNumberOnTeam = GSI_GetPlayerNumberOnTeam(thisplayerID)
		local thisPlayer = t_enemy_players[playerNumberOnTeam]

		thisPlayer.illusionsUp = false

		if thisEnemyPlayerHeroUnit:IsNull() then DEBUG_KILLSWITCH = true end

		if thisPlayer.knownNonIllusionUnit and (thisPlayer.knownNonIllusionUnit:IsNull() or not thisPlayer.knownNonIllusionUnit:IsAlive()) then -- If the unit is dead, this implies an incorrect nonIllusion or in-between state with IsDead but still in GetUnitList
			thisPlayer.knownNonIllusionUnit = false
		end

		-- Detect illusions
		for iSeen=1,i-1 do
			-- Check duplicates
			if prevSeen[iSeen] == playerNumberOnTeam then
				thisPlayer.illusionsUp = true
				-- Allow setting of data if it's a knownNonIllusionUnit
				if VERBOSE then INFO_print(string.format("illusions up %s", thisPlayer.knownNonIllusionUnit)) end
				if thisPlayer.knownNonIllusionUnit then
					if VERBOSE then INFO_print(string.format("known illusion loc %.2f, %.2f", thisPlayer.knownNonIllusionUnit:GetLocation().x, thisEnemyPlayerHeroUnit:GetLocation().x)) end
					if thisPlayer.knownNonIllusionUnit:GetLocation().x ==
							thisEnemyPlayerHeroUnit:GetLocation().x then
						if VERBOSE then INFO_print(string.format("Setting data for known non illusion %s", thisPlayer.shortName)) end
						break;
					end
				end
				goto NEXT;
--				-- Disallow setting data if it's much lower health. Can cause realplayer->illusion switch
--				elseif thisEnemyPlayerHeroUnit:GetHealth()+300 < thisPlayer.lastSeenHealth then
--					goto NEXT;
--				end
			end
		end
		prevSeen[i] = playerNumberOnTeam
		-- Remove the knownNonData at random avg 6s after known (hand-wave number: we check 1.8 times avg for 3 units)
		-- For a semblance of fairness, not for data correctness
		if thisPlayer.knownNonIllusionUnit and RandomInt(1,11) == 1 then 
			thisPlayer.knownNonIllusionUnit = false
		end
		
		thisPlayer.hUnit = thisEnemyPlayerHeroUnit -- n.b. this unlocks none-type checking. Get the most recent pointer, incase the bot was invisible recently
		thisPlayer.level = thisEnemyPlayerHeroUnit:GetLevel()
		thisPlayer.currentMovementSpeed = thisEnemyPlayerHeroUnit:GetCurrentMovementSpeed()
		
		thisPlayer.lastSeenHealth = thisEnemyPlayerHeroUnit:GetHealth()
		thisPlayer.maxHealth = thisEnemyPlayerHeroUnit:GetMaxHealth()
		thisPlayer.lastSeenMana = thisEnemyPlayerHeroUnit:GetMana()
		thisPlayer.maxMana = thisEnemyPlayerHeroUnit:GetMaxMana()
		thisPlayer.attackRange = thisEnemyPlayerHeroUnit:GetAttackRange()
		thisPlayer.attackPointPercent = thisEnemyPlayerHeroUnit:GetAttackPoint()
				/ thisEnemyPlayerHeroUnit:GetAttackSpeed()

		if RandomInt(0, 16) == 0 then Item_UpdateKnownInventory(thisPlayer) end -- Update Inventory knowledge randomly
			
		if thisPlayer.needsVisibleData then
			thisPlayer.attackPointPercent = thisEnemyPlayerHeroUnit:GetAttackPoint() / thisEnemyPlayerHeroUnit:GetAttackSpeed()
			thisPlayer.name = GSI_GetUnitName(thisPlayer)
			thisPlayer.shortName = GSI_GetHeroShortName(thisPlayer)
			thisPlayer.needsVisibleData = false
			thisPlayer.typeIsNone = false

			t_named_players[thisPlayer.name] = thisPlayer

			Hero_EnemyInitialize(thisPlayer)
		end
		::NEXT::
	end
	
	for i=1,#t_team_players,1 do
		local thisPlayer = t_team_players[i]
		local thisPlayerHeroUnit = GetTeamMember(i)

		thisPlayer.hUnit = thisPlayerHeroUnit
		
		update_allied_hero_game_data(thisPlayer, thisPlayer.hUnit)
	end
end


-- // PORT WHILE STUCK //
local DETERMINE_STUCK_LESS_THAN_DIST = 450
local last_throttled_seen_loc = {}
local function port_while_stuck(gsiPlayer)
	if not gsiPlayer.hUnit:IsAlive() or gsiPlayer.locationVariation > DETERMINE_STUCK_LESS_THAN_DIST then
		DOMINATE_SetDominateFunc(gsiPlayer, "port_while_stuck", port_while_stuck, false)
		gsiPlayer.stuckDiagnoseBeforeTpExpiry = nil
		return
	end
	local hUnit = gsiPlayer.hUnit
	
	local forceStaff = gsiPlayer.usableItemCache.forceStaff
	local blink = gsiPlayer.usableItemCache.blink
	local hatchet = gsiPlayer.usableItemCache.hatchet
	if forceStaff and hUnit:FindItemSlot(forceStaff:GetName()) ~= 2 then
		Item_EnsureCarriedItemInInventory(gsiPlayer, forceStaff, 2)
	end
	if blink and hUnit:FindItemSlot(blink:GetName()) ~= 3 then
		Item_EnsureCarriedItemInInventory(gsiPlayer, blink, 3)
	end
	if hatchet and hUnit:FindItemSlot(hatchet:GetName()) ~= 4 then
		Item_EnsureCarriedItemInInventory(gsiPlayer, hatchet, 4)
	end

	local activeAbility = hUnit:GetCurrentActiveAbility()
	if hUnit:IsChanneling() and activeAbility and activeAbility:GetName() == "item_tpscroll" then return end
	if UseAbility_IsPlayerLocked(gsiPlayer) then
		-- an ability was registered to run by port_wile_stuck(), finish running it.
		Task_GetTaskRunFunc(UseAbility_GetTaskHandle())(gsiPlayer, gsiPlayer, 0)
		return
	end

	Port_BuyPortScrollsIfNeeded(gsiPlayer)
	if hUnit:GetItemInSlot(TPSCROLL_SLOT) then -- courier will auto send
		--print("have port")
		if gsiPlayer.stuckDiagnoseBeforeTpExpiry < GameTime()
				and AbilityLogic_AbilityCanBeCast(gsiPlayer, hUnit:GetItemInSlot(TPSCROLL_SLOT)) then
			DOMINATE_print(gsiPlayer, "Attempting port.")
			hUnit:ActionImmediate_Ping(gsiPlayer.lastSeen.location.x, gsiPlayer.lastSeen.location.y, true)
			hUnit:Action_UseAbilityOnLocation(hUnit:GetItemInSlot(TPSCROLL_SLOT), Map_GetTeamFountainLocation())
			return
		end
	elseif gsiPlayer.hCourier and GameTime() % 0.5 < 0.05 then
		if gsiPlayer.hCourier:FindItemSlot("item_tpscroll") >= 0 then
			hUnit:ActionImmediate_Courier(gsiPlayer.hCourier, COURIER_ACTION_TRANSFER_ITEMS)
		elseif gsiPlayer.hCourier:DistanceFromFountain() == 0 and gsiPlayer.hUnit:FindItemSlot("item_tpscroll") > ITEM_END_BACKPACK_INDEX then
			hUnit:ActionImmediate_Courier(gsiPlayer.hCourier, COURIER_ACTION_TAKE_AND_TRANSFER_ITEMS)
		else
			hUnit:ActionImmediate_Courier(gsiPlayer.hCourier, COURIER_ACTION_RETURN)
		end
	end
	local anyHope = hatchet or mobilityItem or mobilityAbility or false
	--print("no active")
	if hatchet and AbilityLogic_AbilityCanBeCast(gsiPlayer, hatchet) then
		DOMINATE_print(gsiPlayer, "Lumberjack solution.")
		local nearbyTrees = hUnit:GetNearbyTrees(500)
		if nearbyTrees and nearbyTrees[1] then
			hUnit:Action_UseAbilityOnTree(hatchet, nearbyTrees[1])
			return;
		end
	end
	local mobilityAbility = AbilityLogic_GetBestMobility(gsiPlayer)
	if mobilityAbility and mobilityAbility:IsCooldownReady() then
		anyHope = true
		if AbilityLogic_DeduceBestFitCastAndUse(gsiPlayer, mobilityAbility, ZEROED_VECTOR) then
			DOMINATE_print(gsiPlayer, "Using random mobility ability.")
			return;
		end
	end
	local mobilityItem = blink and AbilityLogic_AbilityCanBeCast(gsiPlayer, blink) and blink
			or forceStaff and AbilityLogic_AbilityCanBeCast(gsiPlayer, forceStaff) and forceStaff
	if mobilityItem and mobilityItem:IsCooldownReady() then
		if AbilityLogic_DeduceBestFitCastAndUse(gsiPlayer, mobilityItem, ZEROED_VECTOR) then
			DOMINATE_print(gsiPlayer, "Mobility item solution.")
			return;
		end
	end
	if not activeAbility then
		local vec = Vector(sin(DotaTime()/5.0)*400.0 - 400.0, cos(DotaTime()/5.0)*400.0 - 400.0, 0)
		hUnit:Action_MoveDirectly(vec)
	end
end
local function abscond_location_variation()
	local last_throttled_seen_loc = last_throttled_seen_loc
	if last_throttled_seen_loc[1] == nil then
		for i=1,TEAM_NUMBER_OF_BOTS do t_team_bots[i].locationVariation = 1000 last_throttled_seen_loc[i] = ZEROED_VECTOR end
	end
	for i=1,TEAM_NUMBER_OF_BOTS do
		local thisPlayer = t_team_bots[i]
		--if not thisPlayer then Util_TablePrint(t_team_bots) print(i) end
		local diff = Math_PointToPointDistance2D(last_throttled_seen_loc[i] or thisPlayer.lastSeen.location, thisPlayer.lastSeen.location)
		-- absond movement
		--print("abscond", thisPlayer.shortName, thisPlayer.locationVariation)
		if not Unit_IsImmobilized(thisPlayer) then
			local abscondedShiftFactor
			local currLocVariation = thisPlayer.locationVariation
			local isIncreasing = 5*diff > currLocVariation
			if currLocVariation < 600 then
				abscondedShiftFactor = isIncreasing and 0.2 or (0.0006*currLocVariation)^2
			elseif currLocVariation < 1400 then
				abscondedShiftFactor = 0.13
			else
				abscondedShiftFactor = isIncreasing and (1.2 - 0.0006*currLocVariation)^2 or 0.2
				--print(isIncreasing, (1.2 - 0.0006*currLocVariation)^2)
			end
			local abscondedAdd = thisPlayer.currentMovementSpeed*abscondedShiftFactor 
			abscondedAdd = isIncreasing and abscondedAdd or -abscondedAdd
			thisPlayer.locationVariation = max(0, min(2000, thisPlayer.locationVariation + abscondedAdd))
			--print(thisPlayer.shortName, thisPlayer.locationVariation, diff, abscondedShiftFactor)
		end
		last_throttled_seen_loc[i] = thisPlayer.lastSeen.location -- update loc
		-- check if we need to dominate for unstuck
		if thisPlayer.locationVariation < DETERMINE_STUCK_LESS_THAN_DIST and thisPlayer.disabledAndDominatedFunc == nil then
			DOMINATE_SetDominateFunc(thisPlayer, "port_while_stuck", port_while_stuck, true)
			thisPlayer.stuckDiagnoseBeforeTpExpiry = GameTime() + 5
		end
	end
end
-- \\ PORT WHILE STUCK \\
local function update_players_last_seen()
	for i=1,#t_enemy_players,1 do
		local thisEnemyPlayer = t_enemy_players[i]
		if not thisEnemyPlayer.typeIsNone and thisEnemyPlayer.hUnit and thisEnemyPlayer.hUnit:IsAlive() then
			thisEnemyPlayer.lastSeen:Update(thisEnemyPlayer.hUnit:GetLocation())
		end
	end
	for i=1,#t_team_players,1 do
		local thisTeamPlayer = t_team_players[i]
		thisTeamPlayer.lastSeen:Update(thisTeamPlayer.hUnit:GetLocation())
	end
end

local function update_players_data__job(workingSet)
	if workingSet.throttle:allowed() then
		abscond_location_variation()
		update_players_data()
	end
end

local function update_enemy_players_none_type__job(workingSet)
	for i=1,#t_enemy_players,1 do
		-- nb. t_enemy_players[i].hUnit is undeclared until update_player_data finds the hUnit, to make IsNull checks possible
		t_enemy_players[i].typeIsNone = not t_enemy_players[i].hUnit or t_enemy_players[i].hUnit:IsNull()
	end
	-- local enemyPlayerUnits = GetUnitList(UNIT_LIST_ENEMY_HEROES)
	-- for i=1,#enemyPlayerUnits,1 do
		-- local thisEnemyPlayerNumberOnTeam = (GSI_GetPlayerNumberOnTeam(enemyPlayerUnits[i]:GetPlayerID()))
		-- t_enemy_players[thisEnemyPlayerNumberOnTeam].hUnit = enemyPlayerUnits[i]
		-- t_enemy_players[thisEnemyPlayerNumberOnTeam].typeIsNone = false
	-- end
end

function Player_CacheTeamBots()
	t_team_bots = GSI_GetTeamBots(TEAM)
end

function Player_InformDead(gsiPlayer)
	gsiPlayer.lastSeenHealth = gsiPlayer.maxHealth
	gsiPlayer.lastSeenMana = gsiPlayer.maxMana
	gsiPlayer.locationVariation = 1000
end

local function update_players_last_seen__job(workingSet)
	if workingSet.throttle:allowed() then
		update_players_last_seen()
	end
end

local function rotating_check_stuck__job(workingSet)
	if workingSet.throttle:allowed() then
	end
end

function pUnit_IsNullOrDead(gsiPlayer)
	return not IsHeroAlive(gsiPlayer.playerID) or not gsiPlayer.hUnit or gsiPlayer.hUnit:IsNull() or not gsiPlayer.hUnit:IsAlive() -- Must know hUnit is not nil because illusion href shuffle
end

function GSI_IsHeroDead(gsiPlayer)
	return IsHeroDead(gsiPlayer.playerID)
end

function GSI_CreateUpdatePlayerDataJob()
	GSI_GetGSIJobDomain():RegisterJob(
			update_players_data__job,
			{["throttle"] = Time_CreateThrottle(THROTTLE_PLAYERS_DATA_UPDATE)},
			"JOB_UPDATE_PLAYER_DATA"
		)
end

function GSI_GetTeamAverageKnownAttackDamage(team)
	local attackTotal = 0
	local knownFound = 0
	local thisTeam = team == TEAM and t_team_players or t_enemy_players
	for i=1,#thisTeam do
		local thisHUnit = thisTeam[i].hUnit
		if not thisHUnit:IsNull() and thisHUnit:IsAlive() then
			knownFound = knownFound + 1
			attackTotal = attackTotal + thisHUnit:GetAttackDamage()
		end
	end
	return knownFound > 0, attackTotal / knownFound
end

function GSI_GetTeamAverageKnownAttackDps(team)
	local dpsTotal = 0
	local knownFound = 0
	local thisTeam = team == TEAM and t_team_players or t_enemy_players
	for i=1,#thisTeam do
		local thisHUnit = thisTeam[i].hUnit
		if not thisHUnit:IsNull() and thisHUnit:IsAlive() then
			knownFound = knownFound + 1
			dpsTotal = dpsTotal + thisHUnit:GetAttackDamage() / thisHUnit:GetSecondsPerAttack()
		end
	end
	return knownFound > 0, dpsTotal / knownFound
end

function GSI_GetTotalDpsOfUnits(tbl1, tbl2)
	local dpsTotal = 0
	local knownFound = 0
	if tbl1 then
		for i=1,#tbl1 do
			local thisHUnit = tbl1[i].hUnit
			if not thisHUnit:IsNull() and thisHUnit:IsAlive() then
				knownFound = knownFound + 1
				dpsTotal = dpsTotal + thisHUnit:GetAttackDamage() / thisHUnit:GetSecondsPerAttack()
			end
		end
	end
	if tbl2 then
		for i=1,#tbl2 do
			local thisHUnit = tbl2[i].hUnit
			if not thisHUnit:IsNull() and thisHUnit:IsAlive() then
				knownFound = knownFound + 1
				dpsTotal = dpsTotal + thisHUnit:GetAttackDamage() / thisHUnit:GetSecondsPerAttack()
			end
		end
	end
	return knownFound > 0, dpsTotal
end

-- If a hUnit known points to an enemy unit that is no longer visible, under-the-hood that bot is now a [none] type object pointer with all original function references intact, but once those functions are passed their own [none]-type owner object, they will raise an incorrect parameter error
function GSI_CreateUpdateEnemyPlayersNoneTyped() -- Synonymous with an enemy player being visible to our team
	GSI_GetGSIJobDomain():RegisterJob(
			update_enemy_players_none_type__job,
			nil,
			"JOB_UPDATE_ENEMY_PLAYERS_NONE_TYPED"
		)
end

function GSI_CreateUpdatePlayersLastSeen()
	GSI_GetGSIJobDomain():RegisterJob(
			update_players_last_seen__job,
			{["throttle"] = Time_CreateThrottle(THROTTLE_PLAYERS_LAST_SEEN_UPDATE)},
			"JOB_UPDATE_PLAYERS_LAST_SEEN"
		)
end

function pUnit_UpdatePlayersData()
	update_enemy_players_none_type__job()
	update_players_data()
	update_players_last_seen()
end

function pUnit_hCourierFindAndLoad()
	local unitList = GetUnitList(UNIT_LIST_ALLIES)
	local couriersFound = 0
	for i=1,#unitList,1 do
		if unitList[i]:IsCourier() then
			local thisCourierplayerID = unitList[i]:GetPlayerID()
			local thisCourierplayerIDPlayer = t_team_players[t_pid_to_n_on_team[thisCourierplayerID]]
			thisCourierplayerIDPlayer.hCourier = unitList[i]
			couriersFound = couriersFound + 1
			if couriersFound >= TEAM_NUMBER_OF_PLAYERS then
				return
			end
		end
	end

	if couriersFound ~= TEAM_NUMBER_OF_PLAYERS then
		print(string.format("/VUL-FT/ player: Starting job to fix missing couriers. Couriers found for %s: %d.", TEAM_READABLE, couriersFound))
		if not Captain_GetCaptainJobDomain():IsJobRegistered("JOB_RETRY_DATA_FOR_DEAD_COURIERS") then
			Captain_GetCaptainJobDomain():RegisterJob(
					function(workingSet)
						if workingSet.throttle:allowed() then
							pUnit_hCourierFindAndLoad()
						end
					end,
					{["throttle"] = Time_CreateThrottle(4.0)},
					"JOB_RETRY_DATA_FOR_DEAD_COURIERS"
				)
		end
	else
		Captain_GetCaptainJobDomain():DeregisterJob("JOB_RETRY_DATA_FOR_DEAD_COURIERS")
	end
end

function insert_player_data(thisPlayer, hUnit)
	thisPlayer.hUnit = hUnit
	thisPlayer.team = TEAM
	thisPlayer.dotaType = HERO_ALLIED
	thisPlayer.type = UNIT_TYPE_HERO
	thisPlayer.typeIsNone = false
	thisPlayer.currentMovementSpeed = hUnit:GetCurrentMovementSpeed()
	thisPlayer.lastSeen = Map_CreateLastSeenTable(hUnit:GetLocation(), true)
	thisPlayer.lastSeenHealth = hUnit:GetHealth()
	thisPlayer.maxHealth = hUnit:GetMaxHealth()
	thisPlayer.lastSeenMana = hUnit:GetMana()
	thisPlayer.maxMana = hUnit:GetMaxMana()
	thisPlayer.attackPointPercent = hUnit:GetAttackPoint() / hUnit:GetAttackSpeed()
	thisPlayer.BAT = hUnit:GetSecondsPerAttack() * hUnit:GetAttackSpeed() -- always 1.7 -- nb. GetAttackSpeed() is a percentage float
	thisPlayer.name = GSI_GetUnitName(thisPlayer)
	thisPlayer.shortName = GSI_GetHeroShortName(thisPlayer)
	thisPlayer.isCaptain = Team_AmITheCaptain(thisPlayer)
	thisPlayer.attackRange = hUnit:GetAttackRange()
--[[PRIMATIVE]]thisPlayer.isRanged = thisPlayer.attackRange > MINIMUM_RANGE_UNIT_RANGE -- Needs check table
end

local recyclable_dominated_units = {}
local function delete_dominated_unit_node(gsiPlayer, gsiDominated)
	if gsiDominated.prevUnit then
		gsiDominated.prevUnit.nextUnit = gsiDominated.nextUnit
	else
		gsiPlayer.dominatedUnitsHead = gsiDominated.nextUnit -- new head
	end
	if gsiDominated.nextUnit then
		gsiDominated.nextUnit.prevUnit = gsiDominated.prevUnit
	end
	gsiDominated.prevUnit = nil
	gsiDominated.nextUnit = nil
	table.insert(recyclable_dominated_units, gsiDominated)
	gsiPlayer.dominatedUnitsIndex[gsiDominated.hUnit] = nil
end
local function create_dominated_unit(gsiPlayer, priorGsiUnit)
	local gsiDominated = priorGsiUnit or table.remove(recyclable_dominated_units) or {}
	if gsiPlayer.dominatedUnitsHead then
		gsiDominated.nextUnit = gsiPlayer.gsiDominatedUnitsHead
		if gsiDominated.nextUnit then
			gsiDominated.nextUnit.prevUnit = gsiDominated
		end
	end
	gsiPlayer.dominatedUnitsHead = gsiDominated
	return gsiDominated
end
function pUnit_IsDominatedUnitNullOrDead(gsiDominated)
	local gsiPlayer = gsiDominated.masterUnit
	if gsiDominated.hUnit and not gsiDominated.hUnit:IsNull() and gsiDominated.hUnit:IsAlive() then
		return false
	end
	delete_dominated_unit_node(gsiPlayer, gsiDominated)
	return true
end
function pUnit_CreateDominatedUnit(playerId, unit)
	local nOnTeam = t_pid_to_n_on_team[playerId]
	local thisPlayer = t_team_players[nOnTeam]
	local hUnit = unit.hUnit and unit.hUnit or unit
	if thisPlayer.dominatedUnitsIndex[hUnit] then
		return thisPlayer.dominatedUnitsIndex[hUnit]
	end

	local thisDominatedUnit = create_dominated_unit(thisPlayer, unit ~= hUnit and unit or nil)

	thisDominatedUnit.hUnit = hUnit

	thisDominatedUnit.nOnTeam = nOnTeam
	thisDominatedUnit.playerID = playerId

	thisDominatedUnit.masterUnit = thisPlayer

	insert_player_data(thisDominatedUnit, hUnit)

	thisDominatedUnit.time = {}
	thisDominatedUnit.time.data = {}
	thisDominatedUnit.zAxisMagnitudeVector = thisPlayer.zAxisMagnitudeVector

	thisPlayer.dominatedUnitsIndex[hUnit] = thisDominatedUnit

	return thisDominatedUnit
end

local function assert_load_player_hunit(hUnit, TEAM, playerId, nOnTeam)
	if not hUnit then
		ERROR_print("[player] player was not a contiguous member of it's team.")
		Util_TablePrint(GetTeamPlayers(TEAM))
		ERROR_print(string.format("[player] confirm_load_player_hunit(%s, %d, %d, %d)",
					tostring(hUnit), TEAM, playerId, nOnTeam)
				)
		Util_ThrowError()
	end
end

function pUnit_LoadTeamPlayer(playerId, nOnTeam)	
	local thisPlayer = {}
	local hUnit = GetTeamMember(nOnTeam)

	assert_load_player_hunit(hUnit, TEAM, playerId, nOnTeam)

	thisPlayer.nOnTeam = nOnTeam
	thisPlayer.playerID = playerId

	insert_player_data(thisPlayer, hUnit)
	
	thisPlayer.zAxisMagnitudeSweeperRadians = RandomFloat(0, MATH_2PI) -- See lib_task/positioning.lua: Positioning_ProgressZNormalSweeper__Job()
	thisPlayer.zAxisMagnitudeVector = Vector(0, 0, thisPlayer.zAxisMagnitudeSweeperRadians)

	thisPlayer.dominatedUnitsIndex = {} -- 

	thisPlayer.usableItemCache = {}
	thisPlayer.purchasedUsables = {}

	t_team_players[nOnTeam] = thisPlayer
	t_named_players[thisPlayer.name] = thisPlayer

	InstallCastCallback(playerId, handle_player_spell_or_item_cast)

	return thisPlayer
end

-- Used temporarily before an enemy may be present on the map, hUnit added when visible in JOB_UPDATE_ENEMY_PLAYER_NONE_TYPED.
function pUnit_LoadEnemyPlayer(playerId, nOnTeam)
	local thisEnemyPlayer = {}
	thisEnemyPlayer.hUnit = nil -- Leave this. Stated for programmer code skimming / ally vs enemy code comparison
	thisEnemyPlayer.team = ENEMY_TEAM
	thisEnemyPlayer.playerID = playerId
	thisEnemyPlayer.nOnTeam = nOnTeam
	thisEnemyPlayer.dotatType = HERO_ENEMY
	thisEnemyPlayer.lastSeenHealth = 600
	thisEnemyPlayer.maxHealth = 600
	thisEnemyPlayer.lastSeenMana = 300
	thisEnemyPlayer.maxMana = 300
	thisEnemyPlayer.attackRange = 200
	thisEnemyPlayer.type = UNIT_TYPE_HERO
	thisEnemyPlayer.needsVisibleData = true
	thisEnemyPlayer.typeIsNone = true
	thisEnemyPlayer.attackPointPercent = PLACEHOLDER_ATTACK_POINT
	thisEnemyPlayer.currentMovementSpeed = PLACEHOLDER_MOVEMENT_SPEED
	thisEnemyPlayer.level = GetHeroLevel(playerId)
	thisEnemyPlayer.lastSeen = Map_CreateLastSeenTable(
			ENEMY_TEAM == TEAM_RADIANT
					and Map_GetLogicalLocation(MAP_POINT_RADIANT_FOUNTAIN_CENTER)
					or Map_GetLogicalLocation(MAP_POINT_DIRE_FOUNTAIN_CENTER),
			true
		)

	t_enemy_players[nOnTeam] = thisEnemyPlayer
	
	InstallCastCallback(playerId, handle_player_spell_or_item_cast)
end

-- function pUnit_ConvertListToSafeUnits(list)
	-- for i=1,#list,1 do
		-- list[i] = t_creeps[list[i]] or cUnit_NewUnit(list[i])
	-- end
	-- return list
-- end

function pUnit_GetAdjustedAttackTime(gsiUnit, attackSpeedAdjustment)
	return gsiUnit.BAT / (0.01*math.max(20, math.min(700, gsiUnit.hUnit:GetAttackSpeed() + attackSpeedAdjustment)))
end

function GSI_GetHeroShortName(thisPlayer)
	if thisPlayer then 
		return thisPlayer.shortName or
				type(GSI_GetUnitName(thisPlayer)) == "string" and GSI_GetUnitName(thisPlayer):gsub("npc_dota_hero_", "") or 
				"[Unknown Hero Name]"
	end
end

function GSI_GetPlayerNumberOnTeam(playerId)
	if not (t_pid_to_n_on_team[playerId] or t_pid_to_n_on_enemy[playerId]) then print("Found no nOnTeam for", playerId, Util_PrintableTable(t_pid_to_n_on_team[playerId])) end
	return t_pid_to_n_on_team[playerId] or t_pid_to_n_on_enemy[playerId]
end

function GSI_GetBot()
	return t_team_players[t_pid_to_n_on_team[GetBot():GetPlayerID()]] or {hUnit = GetBot()}
end

function GSI_GetPlayerFromUnit(hUnit)
	GSI_GetPlayerFromPlayerID(hUnit.playerID)
end

function GSI_GetPlayerFromPlayerID(playerId)
	if TEAM == GetTeamForPlayer(playerId) then
		return t_team_players[t_pid_to_n_on_team[playerId]]
	else
		return t_enemy_players[t_pid_to_n_on_enemy[playerId]]
	end
end

function GSI_GetPlayerByName(name)
	for i=1,TEAM_NUMBER_OF_PLAYERS do
		if t_team_players[i].shortName == name then
			return t_team_players[i]
		end
	end
	for i=1,ENEMY_TEAM_NUMBER_OF_PLAYERS do
		if t_enemy_players[i].shortName == name then
			return t_enemy_players[i]
		end
	end
end

function GSI_GetTeamPlayers(team)
	return team == TEAM and t_team_players or team == ENEMY_TEAM and t_enemy_players
end

function GSI_GetPlayersInSet()
	if set_update_throttle:allowed() then
		for i=1,#t_team_players,1 do
			
		end
	end
end

function GSI_GetTeamBots(team)
	local tBotPlayers = {}
	local thisPlayersTbl = (team == TEAM and t_team_players or t_enemy_players)
	local n = 1
	for i=1,#thisPlayersTbl,1 do
		local thisPlayer = thisPlayersTbl[i]
		if thisPlayer.needsVisibleData or IsPlayerBot(thisPlayer.playerID) then
			tBotPlayers[n] = thisPlayer
			n = n + 1
		end
	end
	
	return tBotPlayers
end

function GSI_GetTeamHumans(team)
	local tHumanPlayers = {}
	
	local n = 1
	for i=1,#t_team_players,1 do
		if not IsPlayerBot(t_team_players[i].playerID) then
			tHumanPlayers[n] = t_team_players[i]
			n = n + 1
		end
	end
	
	return tHumanPlayers
end

-- For teleportation consideration. Considers a hero "flying" towards it's teleport, in order to include it in sets, for ability usage. e.g. Earthshaker is TP-ing in with 1s left, he is seen as 2/3 of the way from his original location to his teleport location, and is now in the set, lets wait for blink > echo slam initiation. Or stun now! because our mid is completing their TP cast, and we see the enemy leaving for their side of the river.
function GSI_GetLocationFlyingIfTeleporting(playerId)
	local gsiPlayer = "temp implement"
	if gsiPlayer then
		local currLocation = gsiPlayer.lastSeen and gsiPlayer.lastSeen or nil
	end
	if false then end
end

local arc_warden_tempests = {}
function GSI_GetZetTempestByPlayerId(playerId)
	return arc_warden_tempests[playerId] 
end
function GSI_HandleZetBotGenericCreated()
	local thisPlayerId = GetBot():GetPlayerID()
	if not arc_warden_tempests[thisPlayerId] then
		arc_warden_tempests[thisPlayerId] = true -- Early testing showed tempest double always initialized it's bot_generic.lua after all other members on the team, TODO not good
		return
	end
	if GSI_READY then
		arc_tempest_double_player = pUnit_CreateDominatedUnit(thisPlayerId, GetBot())
		arc_tempest_double_player.isTempest = true
		INFO_print(string.format("Registered tempest double: %s",
				tostring(arc_tempest_double_player) )
			)
	end
end

function GSI_GetZetTempestGsiUnit()
	--local alliedHeroes = GetUnitList(UNIT_LIST_ALLIED_HEROES) --[[7.31]]
	--for i=1,#alliedHeroes do
		local thisHero = GetBot()
		if thisHero:HasModifier("modifier_arc_warden_tempest_double") then
			local thisDouble = arc_tempest_double_player
			thisDouble.hUnit = thisHero
			update_allied_hero_game_data(thisDouble)
			thisDouble.lastSeen:Update(thisDouble.hUnit:GetLocation())
			return thisDouble
		end
	--end
end

