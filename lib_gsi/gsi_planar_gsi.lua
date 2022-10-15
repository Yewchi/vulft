-- (G)ame (S)tate (I)nterface -- An interface to the variables that define the state of the game--and the deductions made of those variables
--- 'Game State' includes all data that is relevant to the "game theory" of Dota.
GSI_READY = false

TEAM = 			GetTeam()
TEAM_TEXT = 	(TEAM == TEAM_RADIANT and "TEAM_RADIANT" or "TEAM_DIRE")
TEAM_READABLE = (TEAM == TEAM_RADIANT and "Radiant" or "Dire")
TEAM_NUMBER_OF_PLAYERS = #GetTeamPlayers(TEAM)
TEAM_NUMBER_OF_BOTS = 0 -- tentative
TEAM_NUMBER_OF_HUMANS = 0 -- tentative
ENEMY_TEAM =		 	GetOpposingTeam()
ENEMY_TEAM_TEXT = 		(ENEMY_TEAM == TEAM_RADIANT and "TEAM_RADIANT" or "TEAM_DIRE")
ENEMY_TEAM_READABLE = 	(ENEMY_TEAM == TEAM_RADIANT and "Radiant" or "Dire")
ENEMY_TEAM_NUMBER_OF_PLAYERS = #GetTeamPlayers(ENEMY_TEAM)
ENEMY_TEAM_NUMBER_OF_HUMANS = 0 -- tentative
RADIANT_NUMBER_OF_PLAYERS = #GetTeamPlayers(TEAM_RADIANT)
DIRE_NUMBER_OF_PLAYERS = #GetTeamPlayers(TEAM_DIRE)
TEAM_IS_RADIANT = TEAM == TEAM_RADIANT

TYPE_NONE = 				nil -- (0 and 1) == 1; u.type and u.type or "no type"
UNIT_TYPE_HERO = 			20 -- N.B. Used in Set as a less-than comparison to detect Dota UNIT_LIST_X-based set types.
UNIT_TYPE_CREEP = 			21
UNIT_TYPE_SIEGE =			22
UNIT_TYPE_NEUTRAL =			23
UNIT_TYPE_WARD = 			24
UNIT_TYPE_BUILDING = 		25
UNIT_TYPE_ALLIED_ILLUSION = 26
UNIT_TYPE_IMAGINARY =		27

PRE_GAME_END_TIME = GameTime() + (GetGameState == GAME_STATE_PRE_GAME and DotaTime() or -DotaTime())

ALL_ALLIED =		UNIT_LIST_ALLIES -- 1
HERO_ALLIED =		UNIT_LIST_ALLIED_HEROES -- 2
CREEP_ALLIED =		UNIT_LIST_ALLIED_CREEPS -- 3
WARD_ALLIED =		UNIT_LIST_ALLIED_WARDS -- 4
BUILDING_ALLIED =	UNIT_LIST_ALLIED_BUILDINGS -- 5
ALL_ENEMY =			UNIT_LIST_ENEMIES -- 7
HERO_ENEMY =		UNIT_LIST_ENEMY_HEROES -- 8
CREEP_ENEMY = 		UNIT_LIST_ENEMY_CREEPS -- 9
WARDS_ENEMY =		UNIT_LIST_ENEMY_WARDS -- 10
BUILDING_ENEMY =	UNIT_LIST_ENEMY_BUILDINGS -- 11
CREEP_NEUTRAL =		UNIT_LIST_NEUTRAL_CREEPS -- 13

require(GetScriptDirectory().."/lib_math/math")
require(GetScriptDirectory().."/lib_gsi/unit/unit")
require(GetScriptDirectory().."/lib_gsi/map")
require(GetScriptDirectory().."/lib_analytics/set")
require(GetScriptDirectory().."/lib_analytics/analytics")
require(GetScriptDirectory().."/lib_gsi/gsi_scoreboard")
require(GetScriptDirectory().."/lib_task/team/team")
---- planar_gsi constants --
--

--
local known_teleports = {}

local job_domain

local initialize_attempted = false
function GSI_Initialize()
--[[DEBUG]]if DEBUG then DEBUG_print("gsi: Initializing game state interface.") end		
	if initialize_attempted == true then
		DEBUG_KILLSWITCH = true
		return
	end
	initialize_attempted = true
	-- Initialize Job Domain
	job_domain = Job_CreateDomain("DOMAIN_GSI")
	
	-- Allies
	TEAM_NUMBER_OF_BOTS = 0
	TEAM_NUMBER_OF_HUMANS = 0
	local teamplayerIDs = GetTeamPlayers(TEAM)
	for i=1,#teamplayerIDs,1 do
		INFO_print(string.format("[gsi_planar_gsi] Loading team player, ID:%d, pnot:%d", teamplayerIDs[i], i))
		local player = pUnit_LoadTeamPlayer(teamplayerIDs[i], i)
		if player.hUnit:IsBot() then
			TEAM_NUMBER_OF_BOTS = TEAM_NUMBER_OF_BOTS + 1
		end
	end
	TEAM_NUMBER_OF_HUMANS = TEAM_NUMBER_OF_PLAYERS - TEAM_NUMBER_OF_BOTS
	Time_InitializePlayerTimeData()
	pUnit_hCourierFindAndLoad()
	
	-- Enemies
	ENEMY_TEAM_NUMBER_OF_BOTS = 0
	local enemyplayerIDs = GetTeamPlayers(ENEMY_TEAM)
	for i=1,#enemyplayerIDs,1 do
		pUnit_LoadEnemyPlayer(enemyplayerIDs[i], i)
	end
	ENEMY_TEAM_NUMBER_OF_HUMANS = ENEMY_TEAM_NUMBER_OF_PLAYERS - ENEMY_TEAM_NUMBER_OF_BOTS
	
	GSI_RegisterGSIJobDomainToScoreboard(job_domain)
	GSI_RegisterGSIJobDomainToSet(job_domain)
	GSI_RegisterGSIJobDomainToCreep(job_domain)
	GSI_RegisterGSIJobDomainToBuilding(job_domain)
	
	TaskType_Initialize()
	AbilityLogic_Initialize()
	Hero_Initialize()
	Team_Initialize()
	AbilityThink_Initialize()
	
	DeduceBestRolesAndLanes()
	
	print("initing Scoreboard")
	GSI_InitializeScoreboard()
	
	pUnit_UpdatePlayersData()

	-- Handle Humans
	Task_PopulatePlaceholdersForHumans(GSI_GetTeamPlayers(TEAM))
	Player_CacheTeamBots()
	
	GSI_READY = true
	GSI_Initialize = nil
end

function GSI_IsDayTime()
	return DotaTime() % 600 - 300 < 0
end

function GSI_GetGSIJobDomain()
	return job_domain
end

function GSI_GetTeamString(team)
	return team == TEAM_RADIANT and "TEAM_RADIANT" or team == TEAM_DIRE and "TEAM_DIRE" or "TEAM_NEUTRALS"
end

function GSI_UnitCanStartAttack(gsiUnit)
	-- TODO Depreciate into Unit_
	return Unit_GetTimeTilNextAttackStart(gsiUnit) == 0
end
