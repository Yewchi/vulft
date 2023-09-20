local hero_data = {
	"dawnbreaker",
	{2, 1, 2, 3, 2, 4, 2, 1, 3, 1, 5, 4, 3, 1, 7, 3, 4, 10, 11},
	{
		"item_blight_stone","item_branches","item_faerie_fire","item_tango","item_ward_observer","item_branches","item_branches","item_bottle","item_boots","item_magic_wand","item_phase_boots","item_robe","item_ogre_axe","item_quarterstaff","item_ogre_axe","item_echo_sabre","item_mithril_hammer","item_desolator","item_aghanims_shard","item_blink","item_diadem","item_harpoon","item_mithril_hammer","item_ogre_axe","item_black_king_bar","item_buckler","item_platemail","item_assault","item_basher","item_abyssal_blade",
	},
	{ {3,3,3,3,5,}, {3,3,3,3,4,}, 0.1 },
	{
		"Starbreaker","Celestial Hammer","Luminosity","Solar Guardian","+18 Starbreaker Swipe/Smash Damage","+15% Celestial Hammer Slow","+50% Luminosity Critical Strike Damage","-20s Solar Guardian Cooldown","+150 Solar Guardian Radius","-1 Luminosity Attacks Required","-6s Starbreaker Cooldown","+80%% Celestial Hammer Cast Range/Speed",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"dawnbreaker_fire_wreath", ABILITY_TYPE.NUKE + ABILITY_TYPE.SLOW + ABILITY_TYPE.AOE},
		{"dawnbreaker_celestial_hammer", ABILITY_TYPE.NUKE + ABILITY_TYPE.MOBILITY + ABILITY_TYPE.AOE},
		{"dawnbreaker_luminosity", ABILITY_TYPE.PASSIVE},
		{"dawnbreaker_converge", ABILITY_TYPE.MOBILITY + ABILITY_TYPE.MOBILITY + ABILITY_TYPE.AOE},
		[5] = {"dawnbreaker_solar_guardian", ABILITY_TYPE.HEAL},
}

local ZEROED_VECTOR = ZEROED_VECTOR
local playerRadius = Set_GetEnemyHeroesInPlayerRadius
local ENCASED_IN_RECT = Set_GetEnemiesInRectangle
local currentTask = Task_GetCurrentTaskHandle
local GSI_AbilityCanBeCast = GSI_AbilityCanBeCast
local CROWDED_RATING = Set_GetCrowdedRatingToSetTypeAtLocation
local USE_ABILITY = UseAbility_RegisterAbilityUseAndLockToScore
local INCENTIVISE = Task_IncentiviseTask
local VEC_UNIT_DIRECTIONAL = Vector_UnitDirectionalPointToPoint
local VEC_UNIT_FACING_DIRECTIONAL = Vector_UnitDirectionalFacingDirection
local ACTIVITY_TYPE = ACTIVITY_TYPE
local currentActivityType = Blueprint_GetCurrentTaskActivityType
local currentTask = Task_GetCurrentTaskHandle
local HIGH_USE = AbilityLogic_HighUseAllowOffensive
local min = math.min

local fight_harass_handle = FightHarass_GetTaskHandle()
local push_handle = Push_GetTaskHandle()

local t_player_abilities = {}

local ABILITY_USE_RANGE = 800
local OUTER_RANGE = 1600
local FIRE_WREATH_CAST_TIME = 1.1
local FIRE_WREATH_CAST_DELAY = 0.2
local FIRE_WREATH_TRAVEL_SPEED = 215
local DISTANCE_FIRE_WREATH_TRAVELLED = FIRE_WREATH_CAST_TIME * FIRE_WREATH_TRAVEL_SPEED
local APPROX_F_W_EXTRAPOLATED_TIME
		= FIRE_WREATH_CAST_TIME * FIRE_WREATH_CAST_DELAY
			+ FIRE_WREATH_CAST_TIME*(1-FIRE_WREATH_CAST_DELAY)*(100/350) -- time after cast delay*avgMvsp/minMvsp
local APPROX_SMASH_FROM_DAWNBREAKER_END = 200
local SMASH_LANDING_DIST = DISTANCE_FIRE_WREATH_TRAVELLED + APPROX_SMASH_FROM_DAWNBREAKER_END
local SMASH_RADIUS = 250
local SWIPE_RADIUS = 360
local CELESTIAL_HAMMER_THROW_SPEED = 1500
local recent_hammer_lands_time = 0
local recent_hammer_target_location

local function catch_hammer_cast(gsiPlayer, ability, cast_info)
	recent_hammer_target_location = cast_info.location
	--print("update hammer landing location", cast_info.location)
	recent_hammer_lands_time = GameTime()
			+ Math_PointToPointDistance2D(gsiPlayer.lastSeen.location, cast_info.location)
				/ CELESTIAL_HAMMER_THROW_SPEED
end

local d
d = {
	["ReponseNeeds"] = function()
		return nil, REASPONSE_TYPE_DISPEL, nil, {RESPONSE_TYPE_KNOCKBACK, 4}
	end,
	["Initialize"] = function(gsiPlayer)
		AbilityLogic_CreatePlayerAbilitiesIndex(t_player_abilities, gsiPlayer, abilities)
		AbilityLogic_UpdateHighUseMana(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam])
		UseAbility_RegisterCallbackFunc(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam][2], catch_hammer_cast)
		gsiPlayer.InformLevelUpSuccess = d.InformLevelUpSuccess
	end,
	["InformLevelUpSuccess"] = function(gsiPlayer)
		AbilityLogic_UpdateHighUseMana(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam])
		AbilityLogic_UpdatePlayerAbilitiesIndex(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam], abilities)
	end,
	["AbilityThink"] = function(gsiPlayer) 
		local playerAbilities = t_player_abilities[gsiPlayer.nOnTeam]
		local fireWreath = playerAbilities[1]
		local celestial = playerAbilities[2]
		local luminosity = playerAbilities[3]
		local converge = playerAbilities[4]
		local solarGuardian = playerAbilities[5]
		local hammerIsThrown = gsiPlayer.hUnit:GetAbilityInSlot(1) == converge
		--print("hammerIsThrown:", hammerIsThrown)
		local highUse = gsiPlayer.highUseManaSimple
		local playerHealthPercent = gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth
		local playerLoc = gsiPlayer.lastSeen.location

		local fierySoulStacks = gsiPlayer.hUnit:HasModifier("modifier_dawnbreaker_luminosity_attack_buff")

		local currActivityType = currentActivityType(gsiPlayer)
		local currTask = currentTask(gsiPlayer)
		local nearbyEnemies, outerEnemies
				= Set_GetEnemyHeroesInLocRadOuter(gsiPlayer.lastSeen.location, ABILITY_USE_RANGE,
						celestial:GetSpecialValueInt("range"), 6
					)
		local fightHarassTarget = Task_GetTaskObjective(gsiPlayer, fight_harass_handle)
		local fhtReal = fightHarassTarget
				and fightHarassTarget.hUnit.IsNull and not fightHarassTarget.hUnit:IsNull()
		local fhtPercHp = fightHarassTarget
				and fightHarassTarget.lastSeenHealth / fightHarassTarget.maxHealth or 1.0
		local crowdingCenter, crowdedRating
		if nearbyEnemies[1] then
			crowdingCenter, crowdedRating = CROWDED_RATING(nearbyEnemies[1].lastSeen.location, SET_HERO_ENEMY)
		end
		if nearbyEnemies[1] and (currActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION
					or currActivityType > ACTIVITY_TYPE.CAREFUL)
				and AbilityLogic_AbilityCanBeCast(gsiPlayer, fireWreath)
				and HIGH_USE(gsiPlayer, fireWreath, highUse - fireWreath:GetManaCost(),
						min(fhtPercHp, playerHealthPercent)
					) then
			local distancePastCrowded = Math_PointToPointDistance2D(playerLoc, crowdingCenter)
					- SMASH_LANDING_DIST
			if crowdedRating > 1.5
					and distancePastCrowded > -SMASH_RADIUS and distancePastCrowded < 0 then
				local facingApproxAdjustment = Vector(0, 0, 0)
				for i=1,#nearbyEnemies do
					local hUnitEnemy = nearbyEnemies[i].hUnit
					if hUnitEnemy.IsNull and not hUnitEnemy:IsNull() then
						facingApproxAdjustment = Vector_Addition(
								facingApproxAdjustment,
								VEC_UNIT_FACING_DIRECTIONAL(hUnitEnemy:GetFacing())
							)
					end
				end
				if facingApproxAdjustment.x ~= 0 then
if DEBUG then
					DebugDrawLine(crowdingCenter, Vector_Addition(
							crowdingCenter,
							Vector_ScalarMultiply(facingApproxAdjustment, 120)
						), 255, 0, 150)
end
					crowdingCenter = Vector_Addition(
							crowdingCenter,
							Vector_ScalarMultiply(facingApproxAdjustment, 120)
						)
				end
				USE_ABILITY(gsiPlayer, fireWreath, crowdingCenter, 400, nil)
				return;
			elseif fhtReal then
				local moveStability = fightHarassTarget.hUnit:GetMovementDirectionStability()
				if moveStability < 0.1 or moveStability > 0.6 then
					local projectedLoc
							= fightHarassTarget.hUnit:GetExtrapolatedLocation(APPROX_F_W_EXTRAPOLATED_TIME)
					if Math_PointToPointDistance2D(playerLoc, projectedLoc) < SWIPE_RADIUS then
						USE_ABILITY(gsiPlayer, fireWreath, projectedLoc, 400, nil)
						return;
					end
				end
			end
		end
		if DEBUG and  hammerIsThrown then print(GameTime(), recent_hammer_lands_time, gsiPlayer.lastSeen.location, recent_hammer_target_location) end
		if hammerIsThrown and GameTime() > recent_hammer_lands_time
				and AbilityLogic_AbilityCanBeCast(gsiPlayer, converge) then
			if fightHarassTarget and currActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION then
				local halfWay = Vector_ScalePointToPointByFactor(
						gsiPlayer.lastSeen.location, recent_hammer_target_location, 0.5
					)
				if Math_PointToPointDistance2D(gsiPlayer.lastSeen.location, fightHarassTarget.lastSeen.location)
						> Math_PointToPointDistance2D(halfWay, fightHarassTarget.lastSeen.location) then
					USE_ABILITY(gsiPlayer, converge, nil, 400, nil)
					return;
				end
			elseif currActivityType > ACTIVITY_TYPE.CAREFUL then
				if Math_PointToPointDistance2D(gsiPlayer.lastSeen.location, TEAM_FOUNTAIN)
						> Math_PointToPointDistance2D(recent_hammer_target_location, TEAM_FOUNTAIN) then
					USE_ABILITY(gsiPlayer, converge, nil, 400, nil)
					return;
				end
			elseif currActivityType < ACTIVITY_TYPE.CAREFUL then -- jungling??
				USE_ABILITY(gsiPlayer, converge, nil, 400, nil)
				return;
			end
		elseif nearbyEnemies[1] and AbilityLogic_AbilityCanBeCast(gsiPlayer, celestial)
				and HIGH_USE(gsiPlayer, celestial, highUse - celestial:GetManaCost(), fhtPercHp) then
			if crowdedRating > 2.5 and Math_PointToPointDistance2D(playerLoc, crowdingCenter)
						< celestial:GetSpecialValueInt("range") then
				USE_ABILITY(gsiPlayer, celestial, crowdingCenter, 400, nil)
				return;
			elseif fhtReal then
				local fhtStability = fightHarassTarget.hUnit:GetMovementDirectionStability()
				if fhtStability < 0.1 or fhtStability > 0.6 then
					local projectedLoc = fightHarassTarget.hUnit:GetExtrapolatedLocation(0.2)
					local castLoc, inRange = Vector_ScalePointToPointByFactor(
							playerLoc, projectedLoc, 2, celestial:GetSpecialValueInt("range")
						)
					if inRange then
						USE_ABILITY(gsiPlayer, celestial, castLoc, 400, nil)
						return;
					end
				end
			end
		end
		if currActivityType > ACTIVITY_TYPE.CAREFUL
				and nearbyEnemies[1] and AbilityLogic_AbilityCanBeCast(gsiPlayer, celestial)
				and HIGH_USE(gsiPlayer, celestial, highUse - celestial:GetManaCost(), playerHealthPercent) then
			if nearbyEnemies[1].hUnit.IsNull and not nearbyEnemies[1].hUnit:IsNull() then
				USE_ABILITY(gsiPlayer, celestial, Map_GetTeamFountainLocation(), 400, nil)
				return;
			end
		end
		if currTask == push_handle and AbilityLogic_AbilityCanBeCast(gsiPlayer, fireWreath)
				and HIGH_USE(gsiPlayer, fireWreath, (highUse - fireWreath:GetManaCost())*3, 1.67 - playerHealthPercent)
				and (gsiPlayer.time.data.theorizedDanger and gsiPlayer.time.data.theorizedDanger < 0) then
			local nearbyCreeps = Set_GetNearestEnemyCreepSetAtLaneLoc(
					gsiPlayer.lastSeen.location, Map_GetBaseOrLaneLocation(gsiPlayer.lastSeen.location)
				)
			if nearbyCreeps and Math_PointToPointDistance2D(playerLoc, nearbyCreeps.center)
					< DISTANCE_FIRE_WREATH_TRAVELLED + SMASH_RADIUS*0.67 then
				USE_ABILITY(gsiPlayer, fireWreath, nearbyCreeps.center, 400, nil)
				return;
			end
		end
		local enemyPlayers = GSI_GetTeamPlayers(ENEMY_TEAM)
		local intentsTbl = {}
		local harmIntendedToMe = FightClimate_AnyIntentToHarm(gsiPlayer, enemyPlayers, intentsTbl)
		local alliedInDangerInAirQuotes
		for i=1,#intentsTbl do
			if intentsTbl[i] and not pUnit_IsNullOrDead(intentsTbl[i]) then
				alliedInDangerInAirQuotes = intentsTbl[i]
				break;
			end
		end
		if alliedInDangerInAirQuotes and AbilityLogic_AbilityCanBeCast(gsiPlayer, solarGuardian)  
				and HIGH_USE(gsiPlayer, solarGuardian, highUse - solarGuardian:GetManaCost(),
						1-playerHealthPercent
					) then
			local crowdedLoc, crowdedRating = CROWDED_RATING(alliedInDangerInAirQuotes.lastSeen.location, SET_HERO_ENEMY, nil, 800)
			if crowdedRating > 0.5 then
				crowdedLoc = Vector_PointBetweenPoints(crowdedLoc, alliedInDangerInAirQuotes.lastSeen.location)
				USE_ABILITY(gsiPlayer, solarGuardian, crowdedLoc, 400, nil,
						false, false, nil, gsiPlayer.hUnit.Action_UseAbilityOnLocation)
				return;
			end
		end
	end,
}

local hero_access = function(key) return d[key] end

do
	HeroData_SetHeroData(hero_data, abilities, hero_access)
end
