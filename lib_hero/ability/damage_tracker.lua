local player_damage_tracker = {
		[TEAM_RADIANT] = {},
		[TEAM_DIRE] = {}
	}

DAMAGE_NODE_I__ABIILITY = 1
DAMAGE_NODE_I__DAMAGE_PER_SECOND = 2
DAMAGE_NODE_I__REMAINING_DAMAGE = 3
DAMAGE_NODE_I__REMAINING_TIME = 4
DAMAGE_NODE_I__MODIFIER = 5

local update_pnot = 1
local update_team = TEAM_RADIANT
local function update_damage_tracking(team, nOnTeam)
	
end

function DamageTracker_RegisterKnownDamage(target, ability, damage, duration, modifierToTrack)
	
	update_damage_tracking(target.team, target.nOnTeam)
end

function DamageTracker_GetKnownDamage(target)
	
end
