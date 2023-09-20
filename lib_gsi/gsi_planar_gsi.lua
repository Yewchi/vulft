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
TEAM_NUETRAL = TEAM_NEUTRAL


BOTH_TEAMS = -1

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

DOTA_TIME_GAME_INIT = 90

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

local floor = math.floor

local initialize_attempted = false
function GSI_Initialize()
--[[DEBUG]]if DEBUG then DEBUG_print("gsi: Initializing game state interface.") end		
	if initialize_attempted == true then
		DEBUG_KILLSWITCH = true
		ERROR_print(true, true, string.format("[GSI] Attempted to re-initialize GSI -- %s cannot initialize.", TEAM_READABLE))
		return
	end
	
	initialize_attempted = true
	-- Initialize Job Domain
	job_domain = Job_CreateDomain("DOMAIN_GSI")
	
	-- Allies
	TEAM_NUMBER_OF_BOTS = 0
	TEAM_NUMBER_OF_HUMANS = 0
	local teamPlayerIDs = GetTeamPlayers(TEAM)
	for k,v in pairs(teamPlayerIDs) do
		INFO_print(string.format("[gsi_planar_gsi] ** Loading team player, ID:%d, pnot:%d", v, k))
		local player = pUnit_LoadTeamPlayer(v, k)
		if player.hUnit:IsBot() then
			TEAM_NUMBER_OF_BOTS = TEAM_NUMBER_OF_BOTS + 1
		end
	end
	for i=1,#teamPlayerIDs,1 do
		INFO_print(string.format("[gsi_planar_gsi] Loading team player, ID:%d, pnot:%d", teamPlayerIDs[i], i))
		--local player = pUnit_LoadTeamPlayer(teamPlayersIDs[i], i)
		--if player.hUnit:IsBot() then
			--TEAM_NUMBER_OF_BOTS = TEAM_NUMBER_OF_BOTS + 1
		--end
	end
	TEAM_NUMBER_OF_HUMANS = TEAM_NUMBER_OF_PLAYERS - TEAM_NUMBER_OF_BOTS
	pUnit_hCourierFindAndLoad()
	
	-- Enemies
	ENEMY_TEAM_NUMBER_OF_BOTS = 0
	local enemyPlayerIDs = GetTeamPlayers(ENEMY_TEAM)
	for i=1,#enemyPlayerIDs,1 do
		INFO_print(string.format("[gsi_planar_gsi] Loading enemy player, ID:%d, pnot:%d", enemyPlayerIDs[i], i))
		pUnit_LoadEnemyPlayer(enemyPlayerIDs[i], i)
	end
	ENEMY_TEAM_NUMBER_OF_HUMANS = ENEMY_TEAM_NUMBER_OF_PLAYERS - ENEMY_TEAM_NUMBER_OF_BOTS

	Time_InitializePlayerTimeData()
	
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

	if DEBUG then DEBUG_Init() end
	
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

function GSI_DifficultyDiv(div)
	div = floor(div or 50)
	return GetBot():GetDifficulty()^2 > RandomInt(1, div)
end
