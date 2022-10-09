RESPONSE_TYPES = {
	["RESPONSE_TYPE_CUSTOM_FUNC"] = 0,
	["RESPONSE_TYPE_STUN"] = 1,
	["RESPONSE_TYPE_IMMOBILE"] = 2,
	["RESPONSE_TYPE_KNOCKBACK"] = 3,
	["RESPONSE_TYPE_INTERRUPT"] = 4,
	["RESPONSE_TYPE_DISARM"] = 5,
	["RESPONSE_TYPE_DISPEL_TARGET"] = 6,
	["RESPONSE_TYPE_DISPEL_USER"] = 7,
	["RESPONSE_TYPE_IGNORE"] = 8, -- abadon ulti
	["RESPONSE_TYPE_AVOID_TARGET"] = 9,
	["RESPONSE_TYPE_DUST"] = 10,
	["RESPONSE_TYPE_KILL_TARGET"] = 11, -- lifestealer ulti
	["RESPONSE_TYPE_KILL_CASTER"] = 12,
	["RESPONSE_TYPE_KILL_STRUCTURE"] = 13,
	["RESPONSE_TYPE_ENTER_FOG"] = 14, -- furion ult
	["RESPONSE_TYPE_DO_NOT_FACE"] = 15, -- dusa
	["RESPONSE_TYPE_SEPARATE"] = 16, -- lich ult
	["RESPONSE_TYPE_GROUP"] = 17, -- flux
	["RESPONSE_TYPE_SPREAD_TO_HIGH_HEALTH"] = 18, -- jugga ult
	["RESPONSE_TYPE_KILL_SUMMON"] = 19, -- brew, homing missile
	["RESPONSE_TYPE_RESTRICT_MOVEMENT"] = 20, -- bloodseeker ult
	["RESPONSE_TYPE_AVOID_AREA"] = 21, -- macopyre
	["RESPONSE_TYPE_AVOID_PROXIMITY"] = 22, -- lesh, flame guard
	["RESPONSE_TYPE_DENY"] = 23, -- raise request to monitor deny qop Q.
	["RESPONSE_TYPE_STUN_SUMMON"] = 24, -- tempest double
	["RESPONSE_TYPE_AVOID_BOUNDS"] = 25, -- dark seer ult, mars ult, clockwerk cogs
	["RESPONSE_TYPE_AVOID_CASTER"] = 26,
}

RESPONSE_SEVERITY = {
	["AT_ALL_COSTS"] = 1, -- avoid chronosphere, do not attack abaddon
	["HIGH"] = 0.8, -- avoid or interrupt witch doctor, avoid skywrath ult
	["MID_HIGH"] = 0.65, -- immobilize battle trance, 
	["MID"] = 0.5, -- kill tombstone
	["MID_LOW"] = 0.35,	-- avoid acid spray
	["LOW"] = 0.2, -- kill homing missile
	["CUSTOM_FUNC"] = 0 -- increasing severity shadow poison, don't look at dusa unless you have the kill
}


local max = math.max
local min = math.min
local sqrt = math.sqrt
local EMPTY_TABLE = EMPTY_TABLE

local intent_throttle = Time_CreateThrottle(0.2) -- 3-state behaviour over time system .'. intents updated every 0.6s
local t_intent = {}
local t_intent_prev_location = {}
local t_intent_recent_aggression = {} -- Indexed by attcking player pnot, value is the target player's table ref 
--local t_intent_recently_targeted_by = {} -- Indexed by target player pnot, each are LuaRef arr[5]. Using arr[++i] = nil; arr[++i] = nil table resizing
--t_intent_recently_targeted_by[TEAM] = {}
--t_intent_recently_targeted_by[ENEMY_TEAM] = {} -- This is not two-team table creationelegant but it works, and isn't a big deal
--for i=1,TEAM_NUMBER_OF_PLAYERS do
--	t_intent_recently_targeted_by[TEAM][i] = {}
--end
--for i=1,ENEMY_TEAM_NUMBER_OF_PLAYERS do
--	t_intent_recently_targeted_by[ENEMY_TEAM][i] = {}
--end

local AGGRESSIVE_BEHAVIOR_EXPIRY = 2

local t_enemy_linkens_tests = {}

local t_enemy_needs_stunning = {}
local t_enemy_needs_immobile = {}
local t_enemy_needs_knockback = {}
local t_enemy_needs_interrupt = {}
local t_enemy_needs_disarm = {}

local t_response_type_tbl = { -- Helps with insertion
	t_enemy_needs_stunning,
	t_enemy_needs_immobile,
	t_enemy_needs_knockback,
	t_enemy_needs_interrupt,
	t_enemy_needs_disarm,
}

local t_ability_response_type = {}

local recycle_pairs = {}
local function create_or_recycle_pair(gsiPlayer, expiry)
	local pair = table.remove(recycle_pairs) or {}
	pair[1] = gsiPlayer
	pair[2] = expiry
	pair[3] = 1
	return pair
end

local function recycle_pair(pair)
	table.insert(recycle_pairs, pair)
end

local t_ability_response_type = {} -- indexed by spell name

-- TODO Refactor lane_pressure.lua
-- scales greatly over 1 for a high ratio of enemy creeps, scales towards 0 for high ratio of allied creeps
function FightClimate_CreepPressureFast(gsiPlayer)
	return Analytics_CreepPressureFast(gsiPlayer)	
end

-- Check if the ability has a response type associated with it, to store as a response needed in needs_response_arr[]
function FightClimate_CheckAnyResponseNeeded(gsiPlayer, hAbility)
	local abilityResponse = t_ability_response_type[hAbility:GetName()]
	if abilityResponse then
		local needs_response_arr = abilityResponse[1]
		local i=1
		local tblSize = #needs_response_arr
		while(i<=tblSize) do
			if needs_response_arr[i][1] == gsiPlayer then
				needs_response_arr[i][2] = abilityResponse[2] -- just set to expiry if we got it again
				return;
			end
			i = i + 1
		end
		needs_response_arr[i] = create_or_recycle_pair(gsiPlayer, expiry)
	end
end

function FightClimate_GetResponsesNeeded()
	
end

--[[
	function heroFileScopedHandleFunc(scriptGsiPlayer, castingGsiPlayer, knownUnitTbl)
		//code here
		-- POST_RETURN_FLAG = ATTSUM_CONSIDER_DOMINATED || *_ONLY_ATTACK_SUMMONS || *_ONLY_AVOID_AREA
		-- 		|| *_IGNORE || *_DELETE
		return POST_RETURN_FLAG, unitsToConsider, avoidUnits, avoidLoc, forceScoreValue, 
	end
--]]
function FightClimate_RegAvoidHeroReponse(responseType,
			handleFunc, heroName, abilityName,
			duration, radius, urgency,
			associatedModifier, avoidModified
		)
end
function FightClimate_RegSummonedResponse(responseType,
			handleFunc, heroName, abilityName,
			duration, urgency,
			associatedModifier, modifierOnEnemyOfCaster, 
			summonedNames, useHealthInstances
		)
	AttackSummoned_AddTrackUnit(abilityName, duration, summonedNames, useHealthInstances)
end

function FightClimate_RegPowerUpResponse(
			handleFunc, heroName, abilityName, duration, urgency,
			associatedModifier, modifierOnTarget, requireStun,
			requireImmobile, requireInterrupt, requireDisarm
		)
end

function FightClimate_RegisterResponseType(abilityResponses)
	for i=1,MAX_ABILITY_SLOT do

	end
end

function FightClimate_InformAbilityCast(gsiPlayer, hAbility)
	
end

-- Heroes register the types of responses needed upon ability casts here.
-- For a team's code, this is usually only relevant as enemy hero data. e.g.: immobilize sand king if he's ulted, this response type is recorded in sand_king.lua
function FightClimate_RegisterReponseTypes(abilities, ...)
	local responses = {...} -- Currently only uses 1-4 for regular ability slots. May be nil
	local i = 0
	local iResponse = 1
	while(i <= MAX_ABILITY_SLOT) do
		if abilities[i] then
			t_ability_response_type[abilities[i][1]] = response[iResponse]
			iResponse = iResponse + 1
			if nResponse > #responses then
				return;
			end
		end
		i = i + 1
	end
end

function FightClimate_RegisterAnalyticsJobDomainToFightClimate(gsiDomain)

end

function FightClimate_GetBestInterruptTarget(gsiCasting, hCast, peircesMagicImmune, forceCast, gsiPlayerTbl)
--	will remove the required interrupt or stun on find. Upper code is expected to be 'found' -> 'cast'.
--	if heroes fail to cast the spell due to being disabled they 'should' re-register the response themselves
	local numPlayers = #gsiPlayersTbl
	if t_enemy_needs_interrupt[1] then
		for i=1,#t_enemy_needs_interrupt do
			for iPlayer=1,numPlayers do
				if t_enemy_needs_interrupt[i][1] == gsiPlayersTbl[iPlayer] then
					recycle_pair(table.remove(t_enemy_needs_interupt[i]))
					return gsiPlayersTbl[iPlayer]
				end
			end	
		end
	elseif t_enemy_needs_stun[1] then
		for i=1,#t_enemy_needs_stun do
			for iPlayer=1,numPlayers do
				if t_enemy_needs_stun[i][1] == gsiPlayersTbl[iPlayer] then
					recycle_pair(table.remove(t_enemy_needs_stun[i]))
					return gsiPlayersTbl[iPlayer]
				end
			end	
		end
	end
end

-- Intent data update func used by LHP.
function FightClimate_RegisterRecentHeroAggression(gsiPlayer, gsiTarget, isAbilityUse)
	local playersIntent = t_intent_recent_aggression[gsiPlayer]
	if playersIntent then
		playersIntent[1] = gsiTarget
		playersIntent[2] = GameTime()
		playersIntent[3] = 1
	else
		t_intent_recent_aggression[gsiPlayer] = 
				create_or_recycle_pair(gsiTarget, GameTime() + AGGRESSIVE_BEHAVIOR_EXPIRY)
	end
end

local state = 0
local fight_harass_handle
-- Get the intent to harass / harm of the gsiPlayer. Updates per team.
function FightClimate_GetIntent(gsiPlayer)
	if VERBOSE then
		local enemies = GSI_GetTeamPlayers(ENEMY_TEAM)
		DebugDrawText(1068, 762, "intents", 255, 255, 205)
		for i=1,#enemies do
			local thisIntent = t_intent_recent_aggression[enemies[i]]
			if thisIntent then 
				DebugDrawText(1100, 770+i*8,
						string.format("%d %.4s %.2f",
								i,
								thisIntent[1] and thisIntent[1].shortName or "none",
								thisIntent[3]
							), 255, 255, 100+thisIntent[3]*155
					)
			end
		end
	end
	if intent_throttle:allowed() then
		-- TODO Poorly refactored for recent aggression index 2 -- last processed
		-- -| , and index 3 -- certainty of aggression
		fight_harass_handle = fight_harass_handle or FightHarass_GetTaskHandle()
		local allies = GSI_GetTeamPlayers(TEAM)
		local enemies = GSI_GetTeamPlayers(ENEMY_TEAM)
		local currTime = GameTime()
		local numAllies = #allies
		local numEnemies = #enemies
		local currTime = GameTime()
		for i=1,numAllies do
			local playerIntent = t_intent_recent_aggression[allies[i]]
			if playerIntent and playerIntent[3] > 0 then
				if not playerIntent[1].typeIsNone then
					playerIntent[3] = playerIntent[3]
							- 0.1 * (currTime - playerIntent[2])
									* (1-Vector_UnitFacingUnit(allies[i], playerIntent[1]))
				else
					playerIntent[3] = playerIntent[3]
							- 0.1 * (currTime - playerIntent[2])
				end
				playerIntent[2] = currTime
			end
		end
		for i=1,numEnemies do
			local thisEnemy = enemies[i]
			local playerIntent = t_intent_recent_aggression[thisEnemy]
			if playerIntent and playerIntent[3] > 0 then
				if not thisEnemy.typeIsNone then
					playerIntent[3] = playerIntent[3]
							- 0.1 * (currTime - playerIntent[2])
									* (1-Vector_UnitFacingUnit(enemies[i], playerIntent[1]))
				else
					playerIntent[3] = playerIntent[3]
							- 0.1 * (currTime - playerIntent[2])
				end
				playerIntent[2] = currTime
			end
		end
		if state == 0 then state = 1
		--	save a comparison snapshot
			for i=1,numEnemies do
				local thisEnemy = enemies[i]
				if not thisEnemy.typeIsNone then
					t_intent_prev_location[thisEnemy] = thisEnemy.lastSeen.location -- TODO Impelement deduction
				else
					t_intent_prev_location[thisEnemy] = false
				end
			end
		elseif state == 1 then state = 2;
		elseif state == 2 then state = 0
		--	determine intent, save cached
			local recentAggression
			for i=1,numAllies do
				local thisAlly = allies[i]
				local thisIntent = t_intent_recent_aggression[thisAlly]
				local inFightHarassTarget = Task_GetCurrentTaskHandle(thisAlly) == fight_harass_handle
						and Task_GetTaskObjective(thisAlly, fight_harass_handle) or false
				t_intent[thisAlly] = inFightHarassTarget
						or thisIntent and thisIntent[3] > 0.5 and thisIntent[1] or false
			end
			for i=1,numEnemies do
				local thisEnemy = enemies[i]
				-- + aggressive behaviour recent
				local thisIntent = t_intent_recent_aggression[thisEnemy]
				t_intent[thisEnemy] = thisIntent and thisIntent[3] > 0.5 and thisIntent[1] or false
				if not thisEnemy.typeIsNone then
					-- Location stuff TODO
				end
			end
		end
	end
	return t_intent[gsiPlayer]
end

local valid_garbage = {} -- see "set correct #intentsTbl" below
-- gsiPlayer == the player to return if any harm was intended to (e.g. if they are on the same team, it will never be true unless we are denying QoP Q), playerTbl == a tbl of any of the players in the game, to check their intent
-- returned table is TODO currently just a list of each hero intended to be harmed for each intent.
function FightClimate_AnyIntentToHarm(gsiPlayer, playerTbl, intentsTbl)
	--local intentsTbl = intentsTbl
	local numPlayers = #playerTbl
	local harmIntended = 0
	intentsTbl = intentsTbl and intentsTbl or valid_garbage
	if numPlayers > 0 then
		intentsTbl[1] = FightClimate_GetIntent(playerTbl[1]) -- separated from loop incase update needed
		if intentsTbl[1] == gsiPlayer then
			harmIntended = harmIntended + 1
		end
		local i = 2
		while(i <= numPlayers) do
			intentsTbl[i] = t_intent[playerTbl[i]]
			if intentsTbl[i] == gsiPlayer then
				harmIntended = harmIntended + 1
			end
			i = i + 1
		end
		-- set correct #intentsTbl
		for nils=i,i+1 do intentsTbl[nils] = nil end -- to detect correct array size
		if DEBUG and DEBUG_IsBotTheIntern() then DebugDrawText(playerTbl[1].team == gsiPlayer.team and 1600 or 1700, 610, string.format("%d %d %d", #playerTbl, #intentsTbl, numPlayers), 255, 255, 255) end
		return harmIntended > 0, intentsTbl, harmIntended
	end
	intentsTbl[1] = nil; intentsTbl[2] = nil
	return harmIntended > 0, intentsTbl, harmIntended
end

function FightClimate_HelpMeFightNow(gsiPlayer, nearbyAllies, nearbyEnemies)
	
end

local MAX_INTERVENE_CONSIDER_TIME = 4
-- Return 
-- For optimization, only checks individuals survival times of allies per enemy
function FightClimate_GetIntentCageFightSaveJIT(gsiPlayer, nearbyAllies, nearbyEnemies, interveneRange)
	local intervenableRange = interveneRange
			+ MAX_INTERVENE_CONSIDER_TIME / gsiPlayer.currentMovementSpeed
	-- Calling code must include own nearby allies if not including self
	local nearbyAllies = nearbyAllies or Set_GetAlliedHeroesInPlayerRadius(gsiPlayer, intervenableRange, true)
	local nearbyEnemies = nearbyEnemies or Set_GetEnemyHeroesInPlayerRadius(gsiPlayer, intervenableRange)
	local GetIntent = FightClimate_GetIntent
	local Armor = Unit_GetArmorPhysicalFactor
	local PointDistance = Vector_PointDistance
	local playerLoc = gsiPlayer.lastSeen.location
	local bestSave
	local bestSaveFrom
	local bestSaveTime = 0xFFFF
	--print("SaveJIT", gsiPlayer.shortName, #nearbyEnemies)
	for i=1,#nearbyEnemies do
		local enemy = nearbyEnemies[i]
		local hUnitEnemy = thisEnemy.hUnit
		--print(hUnitEnemy, hUnitEnemy and hUnitEnemy.IsNull and not hUnitEnemy:IsNull())
		if hUnitEnemy and hUnitEnemy.IsNull and not hUnitEnemy:IsNull() and hUnitEnemy:IsAlive() then
			local enemyIntent = GetIntent(enemy)
			if enemyIntent then -- bugged for hero denies
				local secondsSurviving = enemyIntent.lastSeenHealth
						/ ( Armor(enemyIntent)
								* hUnitEnemy:GetAttackDamage()
								/ hUnitEnemy:GetSecondsPerAttack()
							)
				--print("SaveJIT", gsiPlayer.shortName, enemy.shortName, secondsSurviving)
				if secondsSurviving < bestSaveTime then
					local secondsToArrive = max(0,
							PointDistance(playerLoc, enemyIntent.lastSeen.location)
								- intervenableRange
						)
					--print("\tarrive", secondsToArrive)
					if secondsSurviving > secondsToArrive then
						bestSave = enemyIntent
						bestSaveFrom = enemy
						bestSaveTime = secondsSurviving
					end
				end
			end
		end
	end
	return bestSaveFrom, bestSave, bestSaveTime
end

-- returns if any player is attacking another players in the area
function FightClimate_AnyCombatNearPlayer(gsiPlayer, radius)
	local nearbyEnemies =
			Set_GetEnemyHeroesInPlayerRadius(gsiPlayer, radius, AGGRESSIVE_BEHAVIOR_EXPIRY)
	local nearbyAllies =
			Set_GetAlliedHeroesInPlayerRadius(gsiPlayer, radius, AGGRESSIVE_BEHAVIOR_EXPIRY)
	for i=1,#nearbyEnemies do
		local thisIntent = t_recent_intent_aggression[nearbyEnemies[i]]
		if thisIntent and thisIntent[2] < GameTime() then
			return true
		end
	end
	for i=1,#nearbyAllies do
		local thisIntent = t_recent_intent_aggression[nearbyAllies[i]]
		if thisIntent and thisIntent[2] < GameTime() then
			return true
		end
	end
end

FIGHT_DIRECTIVES = {
		["TERMINATOR"] = 1, -- kill wrecklessly, flip into this mode when self-annihilation is assured
		["SWOOP"] = 2, -- commit to fighting, with an understanding that becoming the main target is a deterant.
		["CONTRIBUTE"] = 3, -- stay out-of-range, be willing to assist
		["INITIATE"] = 4, -- immediately take best initation
		["HEAT_UP"] = 5, -- Long range harass, pre-initiation
		["BAIT"] = 6, -- assumes another bot is tasked with init, or stay just out of reach during fight
		["LURK"] = 7, -- pre-initiation, but do not reveal
		["FLEE"] = 8, -- you have an out, you're not to return to the fight
		["UNALLOCATED"] = 9, -- not present
	}
-- Essentially the fight-desire
local UPDATE_DIRECTIVES_INTERVAL = 0.16
local directives = {} -- [nOnTeam]'s directive
local directives_score = {} -- dependance on [nOnTeam] for task success
local directives_expire = 0
local function evaluate_directives()
	-- this looks like it would need a twice-iterated approach, looking at what was determined and then
	--	working from the importance of various directives to inform each other and override.
	local currTime = GameTime()
	if directives_expire < currTime then
		directives_expire = currTime + UPDATE_DIRECTIVES_INTERVAL
	end
end

function FightClimate_GetMyAggression(gsiPlayer)
	-- Calculate the directive if needed.
	-- Calculate the best target.
end
