local throttle = Time_CreateThrottle(0.043) -- rotates

local NO_ADDITIONAL_FRAME_NEEDED = nil -- for reference
local WAITING_1ST_FRAME = 1
local WAITING_2ND_FRAME = 2

local next_up = 1
local t_hero_ability_think_run_flag = {}
local t_player_ability_think = {}

function AbilityThink_Initialize()
	local teamPlayers = GSI_GetTeamPlayers(TEAM)
	for pnot=1,TEAM_NUMBER_OF_PLAYERS do
		local thisPlayer = teamPlayers[pnot]
		local searchFuncs = HeroData_SearchFuncForHero(thisPlayer.shortName)
		t_player_ability_think[pnot] = searchFuncs("AbilityThink")
		local initFunc = searchFuncs("Initialize")
		if initFunc then 
			initFunc(thisPlayer)
		end
	end
end

local pnot
function AbilityThink_TryRun(gsiPlayer)
	pnot = gsiPlayer.nOnTeam
	if t_hero_ability_think_run_flag[pnot] then
		t_player_ability_think[pnot](gsiPlayer)
		t_hero_ability_think_run_flag[pnot] = false
	end
end

function AbilityThink_RotateAbilityThinkSetRun()
	if throttle:allowed() then
		t_hero_ability_think_run_flag[next_up] = true -- on run will set false
		next_up = Task_RotatePlayerOnTeam(next_up)
	end
end
