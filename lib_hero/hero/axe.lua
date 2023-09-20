local hero_data = {
	"axe",
	{2, 3, 3, 1, 3, 4, 3, 1, 1, 1, 5, 4, 2, 2, 8, 2, 4, 9, 11},
	{
		"item_magic_stick","item_quelling_blade","item_branches","item_branches","item_tango","item_branches","item_boots","item_magic_wand","item_ring_of_health","item_vanguard","item_blink","item_broadsword","item_chainmail","item_blade_mail","item_aghanims_shard","item_point_booster","item_ogre_axe","item_blade_of_alacrity","item_ultimate_scepter","item_gem","item_mithril_hammer","item_ogre_axe","item_black_king_bar","item_ultimate_scepter_2","item_heart","item_shivas_guard","item_overwhelming_blink","item_mjollnir",
	},
	{ {3,3,3,3,3,}, {3,3,3,3,3,}, 0.1 },
	{
		"Berserker's Call","Battle Hunger","Counter Helix","Culling Blade","+8 Berserker's Call Armor","+12% Movement Speed per active Battle Hunger","-12% Battle Hunger Slow","+30 Counter Helix Damage","+150 Culling Blade Damage","+1 Bonus Armor per Culling Blade Stack","+100 Berserker's Call AoE","x2x Battle Hunger Armor Multiplier",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"axe_berserkers_call", ABILITY_TYPE.STUN},
		{"axe_battle_hunger", ABILITY_TYPE.SLOW + ABILITY_TYPE.NUKE},
		{"axe_counter_helix", ABILITY_TYPE.PASSIVE},
		[5] = {"axe_culling_blade", ABILITY_TYPE.UTILITY},
}

local ZEROED_VECTOR = ZEROED_VECTOR
local NEARBY_OUTER = Set_GetEnemyHeroesInPlayerRadius
local IN_PLAYER_RADIUS = Set_GetEnemyHeroesInPlayerRadius
local ENCASED_IN_RECT = Set_GetEnemiesInRectangle
local VEC_POINT_WITHIN_STRIP = Vector_PointWithinStrip
local NEAREST_ENEMY_HERO = Set_GetNearestEnemyHeroToLocation
local NEAREST_CREEPS_TO_LOC = Set_GetNearestEnemyCreepSetToLocation
local FARTHEST_SET_UNIT = Set_GetSetUnitFarthestToLocation
local currentTask = Task_GetCurrentTaskHandle
local CROWDED_RATING = Set_GetCrowdedRatingToSetTypeAtLocation
local USE_ABILITY = UseAbility_RegisterAbilityUseAndLockToScore
local INCENTIVISE = Task_IncentiviseTask
local VEC_UNIT_DIRECTIONAL = Vector_UnitDirectionalPointToPoint
local POINT_DISTANCE = Vector_PointDistance
local POINT_DISTANCE_2D = Vector_PointDistance2D
local VEC_ADDITION = Vector_Addition
local VEC_SCALAR_MULTIPLY = Vector_ScalarMultiply
local VEC_SCALAR_MULTIPLY_2D = Vector_ScalarMultiply2D
local VEC_SCALE_TO_FACTOR = Vector_ScalePointToPointByFactor
local VEC_UNIT_DIRECTIONAL_FACING = Vector_UnitDirectionalFacingDirection
local VEC_UNIT_FACING_LOC = Vector_UnitFacingLoc
local VEC_POINT_BETWEEN_POINTS = Vector_PointBetweenPoints
local VEC_DIRECTIONAL_MOVES_FORWARD = Vector_DirectionalUnitMovingForward
local AL_MAGIC_PROJECTILES = AbilityLogic_AnyProjectilesImmunable
local DAMAGE_IN_TIMELINE = Analytics_GetTotalDamageInTimeline
local FUTURE_DAMAGE_IN_TIMELINE = Analytics_GetFutureDamageInTimeline
local A_T = ACTIVITY_TYPE
local F_D = FIGHT_DIRECTIVE
local F_D_CMD = FIGHT_DIRECTIVE_COMMAND
local currentActivityType = Blueprint_GetCurrentTaskActivityType
local currentTask = Task_GetCurrentTaskHandle
local HIGH_USE = AbilityLogic_HighUseAllowOffensive
local CAN_BE_CAST = AbilityLogic_AbilityCanBeCast
local CHARGE_CAN_BE_CAST = ChargedCooldown_AbilityCanBeCast
local CAST_SUCCEEDS = AbilityLogic_CastOnTargetWillSucceed
local DANGER = Analytics_GetTheoreticalDangerAmount
local ABSCOND_SCORE = Xeta_AbscondCompareNamedScore

local fight_harass_handle = FightHarass_GetTaskHandle()
local push_handle = Push_GetTaskHandle()
local increase_safety_handle = IncreaseSafety_GetTaskHandle()
local avoid_and_hide_handle = AvoidHide_GetTaskHandle()
local zone_defend = ZoneDefend_GetTaskHandle()

local OMNISLASH_JUMP_DIST = 425

local ceil = math.ceil
local floor = math.floor
local abs = math.abs
local min = math.min
local max = math.max
local sqrt = math.sqrt

local OUTER_RANGE = 1400

local TEST = TEST

local t_player_abilities = {}

local d
d = {
	["ReponseNeeds"] = function()
		return nil, REASPONSE_TYPE_DISPEL, nil, {RESPONSE_TYPE_KNOCKBACK, 4}
	end,
	["Initialize"] = function(gsiPlayer)
		--[[
		gsiPlayer.abilities = {}
		AbilityLogic_CreatePlayerAbilitiesIndex(t_player_abilities, gsiPlayer, abilities)
		AbilityLogic_UpdateHighUseMana(gsiPlayer, gsiPlayer.abilities)
		--]]
		
		AbilityLogic_CreatePlayerAbilitiesIndex(t_player_abilities, gsiPlayer, abilities)
		AbilityLogic_UpdateHighUseMana(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam])
		gsiPlayer.InformLevelUpSuccess = d.InformLevelUpSuccess
	end,
	["InformLevelUpSuccess"] = function(gsiPlayer)
		--[[
		AbilityLogic_UpdateHighUseMana(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam])
		AbilityLogic_UpdatePlayerAbilitiesIndex(gsiPlayer, gsiPlayer.abilities, abilities)
		--]]
		AbilityLogic_UpdateHighUseMana(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam])
		AbilityLogic_UpdatePlayerAbilitiesIndex(gsiPlayer, gsiPlayer.abilities, abilities)
	end,
	["InitiateWaitThink"] = function(gsiPlayer)
		local abilities = gsiPlayer.abilities
		if abilities[1] and CAN_BE_CAST(abilities[1]) then

		end
	end,
	["AbilityThink"] = function(gsiPlayer)  
		if AbilityLogic_PlaceholderGenericAbilityUse(gsiPlayer, t_player_abilities) then
			return
		elseif true then -- TODO generic item use (probably can use same func for finished heroes)
			return;

		end
		local abilities = gsiPlayer.abilities
		local call = abilities[1]
		local rage = abilities[2]
		local cull = abilities[4]

		do
			local locked, isCombo, ability = ABILITY_LOCKED(gsiPlayer)
			if locked then
				if ability.GetName and ability:GetName() == "axe_culling_blade" then
					local target = UseAbility_GetTarget(gsiPlayer)
					if not target or target.typeIsNone or not target.lastSeenHealth
							or target.lastSeenHealth + target.hUnit:GetHealthRegen()
								> cull:GetSpecialValueInt("damage") then
						UseAbility_ClearQueuedAbilities(gsiPlayer)
					else return; end
				else return; end
			end
		end
		local highUse = gsiPlayer.highUseManaSimple
		local playerHpp = gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth

		local hUnit = gsiPlayer.hUnit
		local playerLoc = gsiPlayer.lastSeen.location
		local currActivityType = currentActivityType(gsiPlayer)
		local currTask = currentTask(gsiPlayer)
		local nearbyEnemies = NEARBY_OUTER(gsiPlayer, 300, 1600, 0.75)
		local fht = Task_GetTaskObjective(gsiPlayer, fight_harass_handle)
		local fhtReal = fht
				and fht.hUnit.IsNull and not fht.hUnit:IsNull()
		local fhtPercHp = fht
				and fht.lastSeenHealth / fht.maxHealth or 1.0
		local fhtLoc = fhtReal and fht.lastSeen.location
		local distToFht = fhtReal and POINT_DISTANCE(playerLoc, fhtLoc)

		local danger = DANGER(gsiPlayer)

		local damageInTimeline = DAMAGE_IN_TIMELINE(gsiPlayer.hUnit)

		local mgkProjectiles

		local callCanCast = CAN_BE_CAST(gsiPlayer, call)
		local rageCanCast = CAN_BE_CAST(gsiPlayer, rage)
		local cullCanCast = CAN_BE_CAST(gsiPlayer, cull)

		local futureDamage = FUTURE_DAMAGE_IN_TIMELINE(gsiPlayer.hUnit)

		local fDirective, fCmd, tti = FightClimate_GetInitiationCmd(gsiPlayer, nearbyEnemies)

		if cullCanCast then
			-- TODO
			local cullDmg = cull:GetSpecialValueInt("damage")
			local cullCastRange = cull:GetCastRange()
			for i=1,#nearbyEnemies do
				local thisEnemy = nearbyEnemies[i]
				if not thisEnemy.typeIsNone then
					if thisEnemy.lastSeenHealth + thisEnemy.hUnit:GetHealthRegen()*3 < cullDmg 
							and POINT_DISTANCE(thisEnemy.lastSeenLocation, playerLoc) < cullCastRange*2.25 then
						
					end
				end
			end
		end

		local callAllowed = callCanCast
		if callAllowed and fDirective >= F_D.INIT and fCmd < F_D_CMD.GO then
			callAllowed = false
		end
	end,
}

local hero_access = function(key) return d[key] end

do
	HeroData_SetHeroData(hero_data, abilities, hero_access, true)
end
