-- Frustration, or Vex_, is queried for bots overstaying their welcome for a roaming
-- - gank, or dispute solving when multiple cores want to push a lane where jungle
-- - creeps could be farmed at the same time. Also to determine that bots need ganks
-- - (the enemy in lane are making farming impossible). These could be separated into
-- - various modules, but giving it the categorization of "frustration" enables feeling,
-- - sense, and emotional emulation-driven code. It's useful as it is because each can
-- - be calculated into a 'growing frustration', indicating more drastic team-based
-- - measures will need to be taken to win the match--or 3-turtle-2-farm.

local t_exp_leeching = {}
local t_not_supported = {}
local t_lane_oppression = {}
local t_map_safety = {}
local t_allies, t_enemies
local t_lane_present_allies = {}
local t_lane_present_enemies = {}

local function create_vex_node(subject, vex) -- vex is 0.0: acceptable; to 1.0: feed mid.

end

local function update_exp_leech_frustration()
	for pnot=1,TEAM_NUMBER_OF_PLAYERS do
		local thisPlayer = t_allies[pnot]
		local thisPlayerRoleBasedLane = Team_GetRoleBasedLane(thisPlayer)
	end
end

function Vex_InitializeFrustrationAnalytics(jobDomain)
	t_allies = GSI_GetTeamPlayers(TEAM)
	t_enemies = GSI_GetTeamPlayers(ENEMY_TEAM)
	jobDomain:RegisterJob(
			update_frustration,
			{throttle = Time_CreateThrottle(0.997)},
			"JOB_VEX_UPDATE_FRUSTRATION"
		)
end

function Vex_UpdateLaneAssignments

end

function Vex_FactorLanePresence(gsiPlayer, lane)

end
