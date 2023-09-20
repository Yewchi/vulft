local hero_data = {
	"kunkka",
	{2, 1, 2, 3, 2, 4, 2, 3, 3, 5, 3, 4, 1, 1, 7, 1, 4, 9, 11},
	{
		"item_quelling_blade","item_tango","item_branches","item_branches","item_faerie_fire","item_bottle","item_bracer","item_boots","item_magic_wand","item_chainmail","item_blades_of_attack","item_phase_boots","item_broadsword","item_blade_mail","item_ogre_axe","item_point_booster","item_staff_of_wizardry","item_ultimate_scepter","item_aghanims_shard","item_reaver","item_vitality_booster","item_heart","item_radiance","item_sheepstick","item_gem","item_ultimate_scepter_2","item_refresher",
	},
	{ {3,3,3,2,2,}, {3,3,3,2,2,}, 0.1 },
	{
		"Torrent","Tidebringer","X Marks the Spot","Ghostship","Tidebringer applies +1% slow for +1s","+25% X Marks the Spot Move Speed","+30%% Torrent Knock Up/Stun Duration","+45 Damage","+80 Torrent AoE","+70% Tidebringer Cleave","Ghostship Fleet","-2s Tidebringer Cooldown",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"kunkka_torrent", ABILITY_TYPE.NUKE + ABILITY_TYPE.AOE + ABILITY_TYPE.STUN + ABILITY_TYPE.SLOW},
		{"kunkka_tidebringer", ABILITY_TYPE.PASSIVE + ABILITY_TYPE.ATTACK_MODIFIER},
		{"kunkka_x_marks_the_spot", ABILITY_TYPE.UTILITY + ABILITY_TYPE.SLOW},
		{"kunkka_torrent_storm", ABILITY_TYPE.NUKE + ABILITY_TYPE.AOE},
		{"kunkka_tidal_wave", ABILITY_TYPE.NUKE + ABILITY_TYPE.AOE},
		[5] = {"kunkka_ghostship", ABILITY_TYPE.NUKE + ABILITY_TYPE.AOE + ABILITY_TYPE.STUN + ABILITY_TYPE.SHIELD},
		{"kunkka_return", ABILITY_TYPE.UTILITY}

}

local ZEROED_VECTOR = ZEROED_VECTOR
local ENEMY_PLAYER_RADIUS = Set_GetEnemyHeroesInPlayerRadius
local ENCASED_IN_RECT = Set_GetEnemiesInRectangle
local VEC_POINT_WITHIN_STRIP = Vector_PointWithinStrip
local NEAREST_ENEMY_HERO = Set_GetNearestEnemyHeroToLocation
local NEAREST_CREEPS_TO_LOC = Set_GetNearestEnemyCreepSetToLocation
local FARTHEST_SET_UNIT = Set_GetSetUnitFarthestToLocation
local CROWDED_RATING = Set_GetCrowdedRatingToSetTypeAtLocation
local LOC_RAD_OUTER = Set_GetEnemyHeroesInLocRadOuter
local USE_ABILITY = UseAbility_RegisterAbilityUseAndLockToScore
local INCENTIVISE = Task_IncentiviseTask
local VEC_UNIT_DIRECTIONAL = Vector_UnitDirectionalPointToPoint
local POINT_DISTANCE = Vector_PointDistance
local POINT_DISTANCE_2D = Vector_PointDistance2D
local VEC_ADDITION = Vector_Addition
local VEC_SCALAR_MULTIPLY = Vector_ScalarMultiply
local VEC_SCALAR_MULTIPLY_2D = Vector_ScalarMultiply2D
local VEC_SCALE_TO_FACTOR = Vector_ScalePointToPointByFactor
local VEC_POINT_TO_POINT = Vector_PointToPointLine
local VEC_UNIT_DIRECTIONAL_FACING = Vector_UnitDirectionalFacingDirection
local VEC_UNIT_FACING_LOC = Vector_UnitFacingLoc
local VEC_UNIT_FACING_UNIT = Vector_UnitFacingUnit
local VEC_POINT_BETWEEN_POINTS = Vector_PointBetweenPoints
local VEC_TO_DIRECTIONAL = Vector_ToDirectionalUnitVector
local VEC_DIRECTIONAL_MOVES_FORWARD = Vector_DirectionalUnitMovingForward
local DAMAGE_IN_TIMELINE = Analytics_GetTotalDamageInTimeline
local ACTIVITY_TYPE = ACTIVITY_TYPE
local CURR_TASK_ACTIVITY = Blueprint_GetCurrentTaskActivityType
local CURR_TASK = Task_GetCurrentTaskHandle
local CURR_TASK_OBJECTIVE = Task_GetTaskObjective
local HIGH_USE = AbilityLogic_HighUseAllowOffensive
local CAN_BE_CAST = AbilityLogic_AbilityCanBeCast
local CHARGE_CAN_BE_CAST = ChargedCooldown_AbilityCanBeCast
local CAST_SUCCEEDS = AbilityLogic_CastOnTargetWillSucceed
local CAST_SUCCEEDS_UNITS = AbilityLogic_GetCastSucceedsUnits
local EFFICIENT_KILL = AbilityLogic_GetEfficientKillVulnerable
local DANGER = Analytics_GetTheoreticalDangerAmount
local ABSCOND_SCORE = Xeta_AbscondCompareNamedScore
local GET_HEAT = FightClimate_GetEnemiesTotalHeat
local GREATEST_THREAT = FightClimate_GreatestEnemiesThreatToPlayer
local SKILL_SHOT_LOC = Projectile_SkillShotFogLocation

local fight_harass_handle = FightHarass_GetTaskHandle()
local push_handle = Push_GetTaskHandle()
local increase_safety_handle = IncreaseSafety_GetTaskHandle()
local avoid_and_hide_handle = AvoidHide_GetTaskHandle()

local t_player_abilities = {}

local min = math.min
local max = math.max
local sqrt = math.sqrt

local TORRENT_RADIUS


local function check_fht_combo(gsiPlayer, fht, torrent, xMarks, ship)
	local shouldX, shouldTorrent, shouldShip
	local torrentRadius = torrent:GetSpecialValueInt("radius")
	local torrentDelay = torrent:GetSpecialValueInt("delay")
	local healthAllowed = fht.lastSeenHealth * fht.hUnit:GetMagicReist()
	local movesOutAllowed = (DamageTracker_IsRooted(fht) - torrentDelay)
			* fht.currentMovementSpeed
	--if movesOutAllowed - 
	return shouldX, shouldTorrent, shouldShip
end

local d
d = {
	["ReponseNeeds"] = function()
		return nil, REASPONSE_TYPE_DISPEL, nil, {RESPONSE_TYPE_KNOCKBACK, 4}
	end,
	["Initialize"] = function(gsiPlayer)
		AbilityLogic_CreatePlayerAbilitiesIndex(t_player_abilities, gsiPlayer, abilities)
		AbilityLogic_UpdateHighUseMana(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam])
		Xeta_RegisterAbscondScore("kunkkaShipMultiple", 0, 2, 5, 0.167)
		Xeta_RegisterAbscondScore("kunkkaMoonshine", 0, 2, 5, 0.167)
		Xeta_RegisterAbscondScore("kunkkaWhisky", 0, 2, 5, 0.167)
		gsiPlayer.InformLevelUpSuccess = d.InformLevelUpSuccess
	end,
	["InformLevelUpSuccess"] = function(gsiPlayer)
		AbilityLogic_UpdateHighUseMana(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam])
		AbilityLogic_UpdatePlayerAbilitiesIndex(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam], abilities)
	end,
	["AbilityThink"] = function(gsiPlayer)  
		if true then return end
		local playerAbilities = t_player_abilities[gsiPlayer.nOnTeam]
		local torrent = playerAbilities[1]
		local tidebringer = playerAbilities[2]
		local xMarks = playerAbilities[3]
		local tidalWave = playerAbilities[4]
		local torrentStorm = playerAbilities[5]
		local ship = playerAbilities[6]
		local xMarksReturn = playerAbilities[7]

		repeat
			local locked, isFunc, abilityOrFunc = UseAbility_IsPlayerLocked(gsiPlayer)
			if locked then return; end
		until(true);

		local highUse = gsiPlayer.highUseManaSimple
		local playerHpp = gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth

		local playerLoc = gsiPlayer.lastSeen.location
		local currActivityType = CURR_TASK_ACTIVITY(gsiPlayer)
		local currTask = CURR_TASK(gsiPlayer)
		local fht = CURR_TASK_OBJECTIVE(gsiPlayer, fight_harass_handle)
		local fhtReal = fht
				and fht.hUnit.IsNull and not fht.hUnit:IsNull()
		local fhtPercHp = fht
				and fht.lastSeenHealth / fht.maxHealth or 1.0
		local fhtLoc = fhtReal and fht.lastSeen.location
		local distToFht = fhtReal and POINT_DISTANCE(playerLoc, fhtLoc)
		local danger, knownEnemies, theorizedEnemies = DANGER(gsiPlayer)

		
		local torrentCastToHitTime = torrent:GetSpecialValueFloat("delay") + torrent:GetCastPoint()
		local torrentRadius = torrent:GetSpecialValueInt("radius")
		local torrentCastRange = torrent:GetCastRange()
		local tidebringerDist = tidebringer:GetSpecialValueInt("cleave_distance")
		local xMarksDuration = xMarks:GetSpecialValueFloat("duration")
		local xMarksAlliedDuration = xMarks:GetSpecialValueInt("allied_duration")
		local xMarksCastRange = xMarks:GetCastRange()
		local shipRadius = ship:GetSpecialValueInt("width")
		local shipCastToHitTime = ship:GetSpecialValueFloat("tooltip_delay") + ship:GetCastPoint()
		local shipCastRange = ship:GetCastRange()
		local returnCastPoint = xMarksReturn:GetCastPoint()

		local nearbyEnemies = LOC_RAD_OUTER(playerLoc, xMarksCastRange, torrentCastRange, 1)

		if currActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION then
			
		elseif currActivityType then

		end
	end,
}

local hero_access = function(key) return d[key] end

do
	HeroData_SetHeroData(hero_data, abilities, hero_access, true)
end
