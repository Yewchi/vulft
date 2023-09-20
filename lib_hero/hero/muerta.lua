local hero_data = {
	"muerta",
	{1, 2, 1, 3, 1, 4, 1, 3, 3, 3, 6, 4, 2, 2, 8, 2, 4, 10, 12},
	{
		"item_branches","item_magic_wand","item_boots","item_blades_of_attack","item_fluffy_hat","item_falcon_blade","item_gloves","item_robe","item_power_treads","item_javelin","item_maelstrom","item_fluffy_hat","item_blade_of_alacrity","item_belt_of_strength","item_dragon_lance","item_staff_of_wizardry","item_fluffy_hat","item_hurricane_pike","item_ogre_axe","item_mithril_hammer","item_black_king_bar","item_mjollnir","item_broadsword","item_blades_of_attack","item_lesser_crit","item_invis_sword","item_silver_edge","item_blink","item_swift_blink","item_aghanims_shard",
	},
	{ {1,1,1,1,1,}, {1,1,1,1,1,}, 0.1 },
	{
		"Dead Shot","The Calling","Gunslinger","Pierce the Veil","+80 Dead Shot Damage","+8 Strength","+250 Dead Shot Cast Range","+35 Damage","2 Dead Shot Charges","+20% Gunslinger chance","The Calling summons +2 additional revenants","+25% Magic Resistance",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"muerta_dead_shot", ABILITY_TYPE.NUKE + ABILITY_TYPE.STUN},
		{"muerta_the_calling", ABILITY_TYPE.NUKE + ABILITY_TYPE.SLOW + ABILITY_TYPE.DEGEN + ABILITY_TYPE.AOE},
		{"muerta_gunslinger", ABILITY_TYPE.PASSIVE},
		[5] = {"muerta_pierce_the_veil", ABILITY_TYPE.BUFF + ABILITY_TYPE.ATTACK_MODIFIER},
}

local ZEROED_VECTOR = ZEROED_VECTOR
local playerRadius = Set_GetEnemyHeroesInPlayerRadius
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
local DAMAGE_IN_TIMELINE = Analytics_GetTotalDamageInTimeline
local ACTIVITY_TYPE = ACTIVITY_TYPE
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

local ceil = math.ceil
local floor = math.floor
local abs = math.abs
local min = math.min
local max = math.max
local sqrt = math.sqrt

local t_player_abilities = {}

local ABILITY_USE_RANGE = 1200
local OUTER_RANGE = 2400
local CALLING_CAST_RANGE = 500
local CALLING_RADIUS = 500
local DEAD_SHOT_CAST_RANGE = 700
local DEAD_SHOT_RICOCHET_RANGE_MULTIPLIER = 1.5
local DEAD_SHOT_RICOCHET_WIDTH = 100

local DEAD_SHOT_MAX_CHARGES = 2

local TEST = TEST

local ALLOWED_DEAD_SHOT_TO_TARGET_DISTANCE = 1200
local FANCY_DEAD_SHOT_ADD_DISTANCE = 500

local DEAD_SHOT_TRAVEL_SPEED = 1400 -- TODO fandom
local DEAD_SHOT_TRAVEL_SPEED_SQUARED = DEAD_SHOT_TRAVEL_SPEED^2
local DEAD_SHOT_CAST_POINT_ADJUST = 0.1

local d

-- In this file 'contact' means the cast target of deadshot
-- 'target' means the intended ricocheted hero
--
-- Some code may be residual of thinking Dead Shot would vector target towards
-- - the (0,0,0) vector by default

-- This isn't necessary anymore, because shots go straight on, good code for custom location
-- - extrapolating either way
-- -- NEVERMIND trees work to zero'd vector
local function shot_contact_loc_time(shootFrom, contact, contactLoc)
	local contactMovementVec = VEC_SCALAR_MULTIPLY(
			VEC_DIRECTIONAL_MOVES_FORWARD(contact),
			contact.hUnit:GetMovementDirectionStability()
		)
			
	local contactMovementVec = contactMovementVec
	local contactLoc = contactLoc or contact.lastSeen.location

	-- brain dead approximation -- TODO try linear algebra
	-- 'A' == projectileLoc in time, 'B' == contactObject in time
	local distToThisB
	local timeGivenB = 0
	local thisBLoc = contactLoc
	--print(contactMovementVec)
	-- - TODO or even, I think this should compare the distance between the shotLoc to contactLoc
	-- -| to the contactExtrapolated and contactLoc dist on the first check with some relation
	-- -| to the time and use it to get a strong approximation on the 2nd step
	for i=1,4 do -- correct collision location as chasing B per iteratively corrected time
		distToThisB = POINT_DISTANCE_2D(shootFrom, thisBLoc)
		timeGivenB = DEAD_SHOT_CAST_POINT_ADJUST + distToThisB / DEAD_SHOT_TRAVEL_SPEED
		thisBLoc = VEC_ADDITION(contactLoc,
				VEC_SCALAR_MULTIPLY(contactMovementVec, timeGivenB)
			)
	--	print(thisBLoc, timeGivenB, distToThisB)
	end
			

	return thisBLoc, timeGivenB
end

local function find_deadshot_unit_defensive(gsiPlayer, deadShot, nearbyEnemies, threatHero)

end

-- TODO abstract, use for windrunner
local function find_deadshot_unit(gsiPlayer, deadShot, nearbyEnemies, target, allowAlternate)
	-- Find allowed skill of the shot -- does it kill? allow fancy shots
	local countEnemies = #nearbyEnemies
	if CAST_SUCCEEDS(gsiPlayer, target, deadShot) == 0 then
		if allowAlternate then
			for i=1,countEnemies do
				if not pUnit_IsNullOrDead(nearbyEnemies[i])
						and CAST_SUCCEEDS(gsiPlayer, nearbyEnemies[i], deadShot) > 0 then
					target = nearbyEnemies[i]
					break;
				end
				if i == countEnemies then
					return false, false
				end
			end
		end
	end

	-- TODO Optimize func locals

	local charges = ChargedCooldown_GetCurrentCharges(gsiPlayer, deadShot)
	local shotKills = target.lastSeenHealth < deadShot:GetSpecialValueFloat("damage")*0.67
	-- get fancy if a lot is on the line every moment, huge fight, enemy escaping, enemy near death
	
	local playerLoc = gsiPlayer.lastSeen.location
	local targetLoc = target.lastSeen.location
	local deadShotCastRange = deadShot:GetCastRange()
	local distToTarget = POINT_DISTANCE(playerLoc, targetLoc)
	local canTargetTarget = distToTarget < deadShotCastRange * 0.97
	local searchFromLoc = VEC_POINT_BETWEEN_POINTS(playerLoc, targetLoc)

	local playerHpp = (gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth)
	local urgencyAndHighUse = (2*gsiPlayer.lastSeenMana / gsiPlayer.maxMana)^2
			/ max(0.2, playerHpp)
	local careOfWaste = ( shotKills
				or (countEnemies >= (charges > 1 and 3 or 4))) and 1.5
			or (countEnemies >= (charges > 1 and 2 or 3) and 3)
			or 4
	careOfWaste = careOfWaste - urgencyAndHighUse
	careOfWaste = min(1 + careOfWaste - 3*(gsiPlayer.lastSeenMana / gsiPlayer.maxMana)^2, careOfWaste) -- high use mana
	-- Guess the extrapolated time-to-hit average, get the average extrapolated location
	local iShotIndex = 1

	local minShotTime = distToTarget / DEAD_SHOT_TRAVEL_SPEED
	local maxShotTime = ALLOWED_DEAD_SHOT_TO_TARGET_DISTANCE + (3-careOfWaste)*FANCY_DEAD_SHOT_ADD_DISTANCE
			/ DEAD_SHOT_TRAVEL_SPEED

	-- Check heroes, creeps, trees for target richochets
	local bestShot
	local bestScore = 0
	local wouldAimAtTarget = false
	local bestIsAimedAtTarget = false
	for i=1,countEnemies do
		local testContactUnit = nearbyEnemies[i]
		wouldAimAtTarget = false
		--print("huh", testContactUnit.shortName, countEnemies)
		if not pUnit_IsNullOrDead(testContactUnit) then
			local thisScore = 0
			local extrapolateContactTime = 0
			local extrapolateRicochetTime = 0
			-- Will have to check where the contact unit shot will intersect the line of the
			-- expected movement speed and direction of the target.
			local impact, airTime = shot_contact_loc_time(playerLoc, testContactUnit)
			if impact then
				local toTargetAirtime = airTime
						+ (POINT_DISTANCE(impact, target.lastSeen.location)/DEAD_SHOT_TRAVEL_SPEED) -- approx
				local extrapolated = target.hUnit:GetExtrapolatedLocation(toTargetAirtime)
				local projectedVec = VEC_UNIT_DIRECTIONAL(playerLoc, impact)
				local projectedEndLoc = VEC_ADDITION(impact, VEC_SCALAR_MULTIPLY(projectedVec, DEAD_SHOT_TRAVEL_SPEED))
				local encasedTarget = testContactUnit ~= target
						and VEC_POINT_WITHIN_STRIP(extrapolated, impact, projectedEndLoc, DEAD_SHOT_RICOCHET_WIDTH)
				thisScore = testContactUnit == target and 0.8 -- This only reduces the score when no richochet hit
						or 0.8 - 0.8*testContactUnit.lastSeenHealth / testContactUnit.maxHealth
				if encasedTarget then
					thisScore = thisScore + 1.5 + (1 - abs(0.5 - target.hUnit:GetMovementDirectionStability()))
							+ (1 - target.lastSeenHealth / target.maxHealth)
							+ (1 / max(1, toTargetAirtime*3))
					wouldAimAtTarget = true
				else
					local encased = ENCASED_IN_RECT(impact, projectedEndLoc, DEAD_SHOT_RICOCHET_WIDTH, nearbyEnemies)
					for k=1,#encased do
						if testContactUnit ~= encased[k] and not pUnit_IsNullOrDead(encased[k]) then
							thisScore = thisScore + 1 + (1 - abs(encased[k].hUnit:GetMovementDirectionStability()))
									+ (1 - testContactUnit.lastSeenHealth / testContactUnit.maxHealth)
						end
					end
					thisScore = thisScore / max(1, airTime*3)
				end
			end
			thisScore = thisScore + (wouldAimAtTarget and thisScore*0.75 or 0)
			if thisScore > bestScore then
				bestScore = thisScore
				bestShot = testContactUnit
				bestIsAimedAtTarget = true
			end

		end
	end

	-- No zero vector targeting X( Have to shoot straight per bot API / muerta default vector -- 7.32e
	-- - Prefer ability will default to vector target towards zero vector, cause it allows the bots to
	-- - play more interestingly, variant, rather than straight-on. E.g. Muerta bot can only fear
	-- - away from herself as is.
	local trees = gsiPlayer.hUnit:GetNearbyTrees(deadShotCastRange)
	local numTrees = #trees
	local distToTarget = POINT_DISTANCE(playerLoc, targetLoc)
	local iTree = RandomInt(0,min(numTrees,3))
	local iTreeAdd = 1
	local above = targetLoc.y > 0
	local right = targetLoc.x > 0
	local directionStability = target.hUnit:GetMovementDirectionStability()
	local targetScore = 
			( 0.6 + ( directionStability < 0.5 and 0.5 - directionStability or directionStability - 0.5))
			+ (1.0 - target.lastSeenHealth / target.maxHealth)
	local ricochetTravelDist = deadShotCastRange * 1.5
	local maxRangeShot = deadShotCastRange + ricochetTravelDist

	while iTree <= numTrees do -- lua
		local thisTree = trees[iTree]
		if thisTree then
			local treeLoc = GetTreeLocation(thisTree)
			if (above and treeLoc.y > targetLoc.y or treeLoc.y < targetLoc.y)
					and (right and treeLoc.x > targetLoc.x or treeLoc.x < targetLoc.x) then
		
				local distToTree = POINT_DISTANCE(playerLoc, treeLoc)
				local toTreeTime = distToTree / DEAD_SHOT_TRAVEL_SPEED
				local extrapolated = target.hUnit:GetExtrapolatedLocation(toTreeTime)
				-- fake the hero is at the location when the bullet hits the tree
				local impactLoc, addedAirTime = shot_contact_loc_time(treeLoc, target, extrapolated)
				if POINT_DISTANCE(impactLoc, treeLoc) < ricochetTravelDist-50 then
					local encased = VEC_POINT_WITHIN_STRIP(impactLoc, treeLoc, ZEROED_VECTOR, DEAD_SHOT_RICOCHET_WIDTH)

					if encased then
						local treeScore = targetScore
								+ max(0, 1-(POINT_DISTANCE(impactLoc, treeLoc)+distToTree)/maxRangeShot)
						if treeScore > bestScore then
							bestScore = treeScore
							bestShot = thisTree
							bestIsAimedAtTarget = true
			
			
			
						end
			
			
			
					end
				end
			end
		end

		iTree = iTree + floor(iTreeAdd)
		--iTreeAdd = iTreeAdd + max(0.25, careOfWaste)
	end




	if bestShot and bestScore >= careOfWaste
			and (bestIsAimedAtTarget or not shotKills or not canTargetTarget)
			and ABSCOND_SCORE("muertaDeadShot", bestScore) > sqrt(playerHpp * 0.66) then

		return bestShot
	end

	if shotKills and distToTarget < deadShot:GetCastRange() * 0.95 then

		ABSCOND_SCORE("muertaDeadShot", bestScore) -- if the abcond was checked before it will just get blocked by timer
		return target
	end

	return false
end

d = {
	["dead_shot_damage"] = {[0] = 300, 75, 150, 225, 300},
	["dead_shot_restore_time"] = {[0]=HIGH_32_BIT, 16, 14, 12, 10},
	["DeadShotDamage"] = function(gsiPlayer)
			if gsiPlayer.team == TEAM then
				local deadShot = t_player_abilities[gsiPlayer.nOnTeam][1]
				return deadShot and deadShot:GetSpecialValueFloat("damage")
			end
			local enemyLevelHighest = max(1, min(4, ceil(gsiPlayer.level/2)))
			return d.dead_shot_damage[enemyLevelHighest]
		end,
	["DeadShotChargeRestoreTime"] = function(gsiPlayer) return d.dead_shot_restore_time[t_player_abilities[gsiPlayer.nOnTeam][4]:GetLevel()] end,
	["DeadShotMaxCharges"] = function() return DEAD_SHOT_MAX_CHARGES end,
	["ReponseNeeds"] = function()
		return RESPONSE_TYPE_DISPELL, nil, nil, nil 
	end,
	["Initialize"] = function(gsiPlayer)
		AbilityLogic_CreatePlayerAbilitiesIndex(t_player_abilities, gsiPlayer, abilities)
		AbilityLogic_UpdateHighUseMana(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam])
		ChargedCooldown_RegisterCooldown(
				gsiPlayer,
				t_player_abilities[gsiPlayer.nOnTeam][1],
				d.DeadShotMaxCharges,
				d.DeadShotChargeRestoreTime
			)
		Xeta_RegisterAbscondScore("muertaDeadShot", 0, 2, 5, 0.167)
		gsiPlayer.InformLevelUpSuccess = d.InformLevelUpSuccess
	end,
	["InformLevelUpSuccess"] = function(gsiPlayer)
		AbilityLogic_UpdateHighUseMana(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam])
		AbilityLogic_UpdatePlayerAbilitiesIndex(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam], abilities)
	end,
	["AbilityThink"] = function(gsiPlayer) 
		if UseAbility_IsPlayerLocked(gsiPlayer) then
			return;
		end
		local playerAbilities = t_player_abilities[gsiPlayer.nOnTeam]
		local deadShot = playerAbilities[1]
		local calling = playerAbilities[2]
		local pierce = playerAbilities[4]

		local callingCastRange = calling and calling:GetCastRange()
		callingCastRange = callingCastRange > 0 and callingCastRnage or CALLING_CAST_RANGE
		local deadShotCastRange = deadShot and deadShot:GetCastRange()
		deadShotCastRange = deadShotCastRange > 0 and deadShotCastRange or DEAD_SHOT_CAST_RANGE

		local deadShotCanBeCast = CHARGE_CAN_BE_CAST(gsiPlayer, deadShot)

		local highUse = gsiPlayer.highUseManaSimple
		local playerHpp = gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth

		local pierceBuffOn = gsiPlayer.hUnit:HasModifier("modifier_muerta_pierce_the_veil")

		local playerLoc = gsiPlayer.lastSeen.location
		local currActivityType = currentActivityType(gsiPlayer)
		local currTask = currentTask(gsiPlayer)
		local nearbyEnemies, outerEnemies
				= Set_GetEnemyHeroesInLocRadOuter(gsiPlayer.lastSeen.location, ABILITY_USE_RANGE, OUTER_RANGE, 0.75)
		local fht = Task_GetTaskObjective(gsiPlayer, fight_harass_handle)
		local fhtReal = fht
				and fht.hUnit.IsNull and not fht.hUnit:IsNull()
		local fhtPercHp = fht
				and fht.lastSeenHealth / fht.maxHealth or 1.0
		local fhtLoc = fhtReal and fht.lastSeen.location
		local distToFht = fhtReal and POINT_DISTANCE(playerLoc, fhtLoc)

		local danger = DANGER(gsiPlayer)

		local damageInTimeline

		if fhtReal and currActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION then
			if fhtReal and CAN_BE_CAST(gsiPlayer, deadShot) then
				local shootUnit = find_deadshot_unit(gsiPlayer, deadShot, nearbyEnemies, fht, true)
				if type(shootUnit) == "number" then
					USE_ABILITY(gsiPlayer, deadShot, shootUnit, 400, nil,
							nil, nil, nil, gsiPlayer.hUnit.Action_UseAbilityOnTree
						)
					return;
				elseif shootUnit then
					USE_ABILITY(gsiPlayer, deadShot, shootUnit, 400, nil)
					return;
				end
			end
			if CAN_BE_CAST(gsiPlayer, calling)
					and Vector_PointDistance(playerLoc, fhtLoc) < callingCastRange*1.15
					and HIGH_USE(gsiPlayer, calling, highUse - calling:GetManaCost(), fhtPercHp - (#nearbyEnemies + #outerEnemies)*0.1) then
				local extrapolatedFht = fht.hUnit:GetExtrapolatedLocation(0.7)
				local crowdingCenter, crowdedRating
						= CROWDED_RATING(extrapolatedFht, SET_HERO_ENEMY, nearbyEnemies, CALLING_RADIUS+150)
	
	
				if POINT_DISTANCE(playerLoc, crowdingCenter) < callingCastRange*1.05
						and (crowdedRating > 1.15
							or HIGH_USE(gsiPlayer, calling, highUse*1.33, fhtPercHp)
						) then
					USE_ABILITY(gsiPlayer, calling, crowdingCenter, 400, nil)
					return;
				end
			end
			if fhtReal and CAN_BE_CAST(gsiPlayer, pierce)
					and HIGH_USE(gsiPlayer, pierce, highUse - pierce:GetManaCost(), fhtPercHp) then
				damageInTimeline = damageInTimeline or DAMAGE_IN_TIMELINE(gsiPlayer.hUnit)
				if (gsiPlayer.hUnit:GetAttackTarget()
							and POINT_DISTANCE(
									gsiPlayer.hUnit:GetAttackTarget():GetLocation(),
									playerLoc
								) < gsiPlayer.attackRange * 0.8
							or (danger > -0.5 and damageInTimeline / gsiPlayer.maxHealth > 0.25)
						) then
					USE_ABILITY(gsiPlayer, pierce, nil, 400, nil)
					INCENTIVISE(gsiPlayer, fight_harass_handle, 40, 8)
					return;
				end
			end
		end
		local nearestEnemy, nearestEnemyDist = NEAREST_ENEMY_HERO(playerLoc, 0.5)
		if nearestEnemy and not pUnit_IsNullOrDead(nearestEnemy) and currActivityType > ACTIVITY_TYPE.CAREFUL
				and nearestEnemyDist < 1400 then
			if gsiPlayer.hUnit:GetMovementDirectionStability() > 0.75 then
				local facingDir = VEC_UNIT_DIRECTIONAL_FACING(gsiPlayer.hUnit:GetFacing())
				local castLoc = VEC_ADDITION(playerLoc,
						VEC_SCALAR_MULTIPLY(facingDir, min(CALLING_CAST_RANGE, gsiPlayer.currentMovementSpeed))
					)
				if nearestEnemy.hUnit:GetMovementDirectionStability() > 0.3
						and VEC_UNIT_FACING_LOC(nearestEnemy, castLoc) > 0.8 then
					if CAN_BE_CAST(gsiPlayer, calling)
							and HIGH_USE(gsiPlayer, calling, highUse, playerHpp) then
						USE_ABILITY(gsiPlayer, calling, castLoc, 400, nil)
						return;
					end
					-- TODO or cast dead_shot defensively
				end
			end
			if fhtReal and CAN_BE_CAST(gsiPlayer, deadShot) then
				local shootUnit = find_deadshot_unit(gsiPlayer, deadShot, nearbyEnemies, fht, true)
				if type(shootUnit) == "number" then
					USE_ABILITY(gsiPlayer, deadShot, shootUnit, 400, nil,
							nil, nil, nil, gsiPlayer.hUnit.Action_UseAbilityOnTree
						)
					return;
				elseif shootUnit then
					USE_ABILITY(gsiPlayer, deadShot, shootUnit, 400, nil)
					return;
				end
			end
		end
		if currTask == push_handle then
			local nearestCreepSet, nearestCreepSetDist = NEAREST_CREEPS_TO_LOC(playerLoc)
			local creepUnits = nearestCreepSet and nearestCreepSet.units
			if nearestCreepSet and nearestCreepSetDist < deadShotCastRange
					and #creepUnits >= 4
					and HIGH_USE(gsiPlayer, deadShot, highUse*2 - deadShot:GetManaCost(),
							min(0.75, (1-playerHpp)) * (1+(max(-0.5, min(0, danger/4))))
						) then
				local creepUnitCount = #creepUnits
				local creep1Index = RandomInt(1,creepUnitCount)
				local creep2Index = RandomInt(1,creepUnitCount)
				creep2index = creep2Index ~= creep1Index and creep2Index
						or ((creep2Index + RandomInt(1,creepUnitCount-2)) % creepUnitCount) + 1
				local creep1 = creepUnits[creep1Index]
				local creep2 = creepUnits[creep2Index]

				-- Gets the nearer creep of two random creeps
				local nearerCreep =
						POINT_DISTANCE(creep1.lastSeen.location, ZEROED_VECTOR)
								< POINT_DISTANCE(creep2.lastSeen.location, ZEROED_VECTOR)
							and creep1 or creep2
				local nearerCreepLoc = nearerCreep.lastSeen.location

				local endShot = VEC_ADDITION(
						nearerCreepLoc,
						VEC_SCALAR_MULTIPLY(
								VEC_UNIT_DIRECTIONAL(playerLoc, nearerCreepLoc),
								deadShotCastRange*DEAD_SHOT_RICOCHET_RANGE_MULTIPLIER
							)
					)

				-- check how many units (and hand-wave equally heroes) the shot would hit
				local enemiesInRect = ENCASED_IN_RECT(
						nearerCreepLoc, endShot,
						DEAD_SHOT_RICOCHET_WIDTH,
						nearestCreepSet,
						nearbyEnemies,
						false
					)

		
		

				if nearerCreep and enemiesInRect[4] then
					USE_ABILITY(gsiPlayer, deadShot, nearerCreep, 200, nil)
					return;
				end
			end
		end
		damageInTimeline = damageInTimeline or DAMAGE_IN_TIMELINE(gsiPlayer.hUnit)
		
		if CAN_BE_CAST(gsiPlayer, pierce)
				and (nearbyEnemies[1] or 
					damageInTimeline > gsiPlayer.lastSeenHealth * 0.15)
				and playerHpp < 0.8 then
			
			if damageInTimeline > gsiPlayer.lastSeenHealth * 0.05
					and HIGH_USE(gsiPlayer, pierce, highUse - pierce:GetManaCost(),
							max( -0.35, (gsiPlayer.lastSeenHealth - damageInTimeline)/gsiPlayer.maxHealth )
						) then
				USE_ABILITY(gsiPlayer, pierce, nil, 400, nil)
				INCENTIVISE(gsiPlayer, fight_harass_handle, 60, 8)
				INCENTIVISE(gsiPlayer, increase_safety_handle, 40, 8)
				INCENTIVISE(gsiPlayer, avoid_and_hide_handle, 40, 8)
				return;
			end
		end
	end,
}

local hero_access = function(key) return d[key] end

do
	HeroData_SetHeroData(hero_data, abilities, hero_access)
end
