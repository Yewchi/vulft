local hero_data = {
	"windrunner",
	{2, 3, 2, 3, 2, 4, 2, 1, 3, 3, 1, 4, 1, 1, 7, 6, 4, 10, 12},
	{
		"item_tango","item_branches","item_branches","item_circlet","item_circlet","item_branches","item_bracer","item_bracer","item_gloves","item_boots","item_magic_wand","item_power_treads","item_javelin","item_maelstrom","item_blade_of_alacrity","item_yasha","item_ultimate_orb","item_manta","item_point_booster","item_ultimate_scepter","item_dragon_lance","item_cornucopia","item_ultimate_orb","item_sphere","item_lesser_crit","item_ultimate_scepter_2","item_demon_edge","item_javelin","item_blitz_knuckles","item_monkey_king_bar","item_greater_crit",
	},
	{ {2,2,2,2,3,}, {2,2,2,2,3,}, 0.1 },
	{
		"Shackleshot","Powershot","Windrun","Focus Fire","+225 Windrun Radius","-2.0s Shackleshot Cooldown","-2.5s Windrun Cooldown","-15% Powershot Damage Reduction","+0.75s Shackleshot Duration","-12% Focus Fire Damage Reduction","Windrun Cannot Be Dispelled","Focus Fire Kills Advance Cooldown by 18s",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"windrunner_shackleshot", ABILITY_TYPE.STUN},
		{"windrunner_powershot", ABILITY_TYPE.NUKE + ABILITY_TYPE.AOE},
		{"windrunner_windrun", ABILITY_TYPE.MOBILITY + ABILITY_TYPE.BUFF + ABILITY_TYPE.SHIELD},
		{"windrunner_gale_force", ABILITY_TYPE.SLOW + ABILITY_TYPE.AOE},
		[5] = {"windrunner_focusfire", ABILITY_TYPE.NUKE},
}

local ZEROED_VECTOR = ZEROED_VECTOR
local playerRadius = Set_GetEnemyHeroesInPlayerRadius
local ENCASED_IN_RECT = Set_GetEnemiesInRectangle
local VEC_POINT_WITHIN_STRIP = Vector_PointWithinStrip
local NEAREST_ENEMY_HERO = Set_GetNearestEnemyHeroToLocation
local NEAREST_CREEPS_TO_LOC = Set_GetNearestEnemyCreepSetToLocation
local FARTHEST_SET_UNIT = Set_GetSetUnitFarthestToLocation
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
local SCORE_CONE_HEROES = ScoreLocs_ConeHeroes
local SCORE_CONE_TARGET = ScoreLocs_ConeSeenUnitsHitsTarget

local fight_harass_handle = FightHarass_GetTaskHandle()
local push_handle = Push_GetTaskHandle()
local increase_safety_handle = IncreaseSafety_GetTaskHandle()
local avoid_and_hide_handle = AvoidHide_GetTaskHandle()

local SHACKLE_CAST_RANGE = 800
local SHACKLE_CONE_RANGE = 575
local SHACKLE_LIMIT_RANGE_LINKED = SHACKLE_CAST_RANGE + SHACKLE_CONE_RANGE
local SHACKLE_CONE_ANGLE = math.rad(12.25) -- I think it's 25.5 dgrees based on fandom. unsure.
local SHACKLE_TRAVEL_SPEED = 1650
local SHACKLE_USE_EXPIRY = 0.15

local POWERSHOT_MAX_CHANNEL = 1
local POWERSHOT_TRAVEL_SPEED = 3000
local POWERSHOT_HALF_WIDTH = 125
local POWERSHOT_USE_EXPIRY = 0.15

local ABILITY_USE_RANGE = SHACKLE_LIMIT_RANGE_LINKED + 150

local t_shackle_expire_before_cast = {}
local t_powershot_expire_before_cast = {}

local t_player_abilities = {}

local min = math.min
local max = math.max
local sqrt = math.sqrt

local d
d = {
	["ReponseNeeds"] = function()
		return nil, REASPONSE_TYPE_DISPEL, nil, {RESPONSE_TYPE_KNOCKBACK, 4}
	end,
	["Initialize"] = function(gsiPlayer)
		AbilityLogic_CreatePlayerAbilitiesIndex(t_player_abilities, gsiPlayer, abilities)
		AbilityLogic_UpdateHighUseMana(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam])
		Xeta_RegisterAbscondScore("windrunnerShackleShotCreepTree", 0, 1, 2, 0.167)
		Xeta_RegisterAbscondScore("windrunnerShackleShotMultiple", 0, 2, 5, 0.167)
		Xeta_RegisterAbscondScore("windrunnerPowerShotCrowded", 0, 2, 5, 0.167)
		gsiPlayer.InformLevelUpSuccess = d.InformLevelUpSuccess
		SpecialBehavior_RegisterBehavior("fightHarassRunOverride",
				function(gsiPlayer, objective, score)
					local hUnit = gsiPlayer.hUnit
					if not hUnit:HasModifier("modifier_windrunner_focusfire")
							or objective.hUnit:IsNull() then
						return false;
					end
					local playerLoc = gsiPlayer.lastSeen.location
					local fhtLoc = objective.lastSeen.location
					local danger = Analytics_GetTheoreticalDangerAmount(gsiPlayer)
					if GameTime() - gsiPlayer.hUnit:GetLastAttackTime()
								< gsiPlayer.hUnit:GetSecondsPerAttack()+0.1
							or gsiPlayer.hUnit:GetAttackTarget() then
						Positioning_ZSAttackRangeUnitHugAllied(
								gsiPlayer, objective.lastSeen.location, SET_HERO_ENEMY,
								min(gsiPlayer.attackRange*0.85, 250 + gsiPlayer.attackRange * (danger+1)),
								0, true, 0.4 + max(0, (-danger-1))
							)
					else
						gsiPlayer.hUnit:Action_AttackUnit(objective.hUnit, false)
					end
					return true;
				end
			)

		gsiPlayer.modPowerLevel = function(gsiPlayer, powerLevel)
			if gsiPlayer.hUnit:HasModifier("modifier_windrunner_focusfire") then
				local enemiesToWind = Set_GetTeamHeroesInLocRad(gsiPlayer.team == TEAM
						and ENEMY_TEAM or TEAM, gsiPlayer.lastSeen.location, 1250
					)
				return powerLevel*(1 + 0.67^(1+#enemiesToWind))
			end
		end
	end,
	["InformLevelUpSuccess"] = function(gsiPlayer)
		AbilityLogic_UpdateHighUseMana(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam])
		AbilityLogic_UpdatePlayerAbilitiesIndex(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam], abilities)
	end,
	["AbilityThink"] = function(gsiPlayer) 
		local playerAbilities = t_player_abilities[gsiPlayer.nOnTeam]
		local shackleShot = playerAbilities[1]
		local powerShot = playerAbilities[2]
		local windrun = playerAbilities[3]
		local gale = playerAbilities[4]
		local focusFire = playerAbilities[5]

		repeat
			local locked, isFunc, abilityOrFunc = UseAbility_IsPlayerLocked(gsiPlayer)
			if locked and not isFunc then
				local lastPowerShot = t_powershot_expire_before_cast[gsiPlayer.nOnTeam]
				if powerShot and lastPowerShot
						and abilityOrFunc:GetName() == powerShot:GetName()
						and lastPowerShot < GameTime()
						and not gsiPlayer.hUnit:IsChanneling() then
					UseAbility_ClearQueuedAbilities(gsiPlayer)
					break;
				end
				local lastShackle = t_shackle_expire_before_cast[gsiPlayer.nOnTeam]
				if shackle and lastShackle
						and abilityOrFunc:GetName() == shackle:GetName()
						and lastShackle < GameTime() then
					UseAbility_ClearQueuedAbilities(gsiPlayer)
					break;
				end
				return;
			end
		until(true);

		t_shackle_expire_before_cast[gsiPlayer.nOnTeam] = 0
		t_powershot_expire_before_cast[gsiPlayer.nOnTeam] = 0

		local powerShotRange = powerShot:GetCastRange()
		

		local attackRange = gsiPlayer.hUnit:GetAttackRange()

		if gsiPlayer.attackRange ~= attackRange then
			pUnit_SetFalsifyAttackRange(gsiPlayer, false)
		end

		local highUse = gsiPlayer.highUseManaSimple
		local playerHpp = gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth

		local playerLoc = gsiPlayer.lastSeen.location
		local currActivityType = CURR_TASK_ACTIVITY(gsiPlayer)
		local currTask = CURR_TASK(gsiPlayer)
		local nearbyEnemies, outerEnemies
				= Set_GetEnemyHeroesInLocRadOuter(gsiPlayer.lastSeen.location, ABILITY_USE_RANGE, powerShotRange, 4)
		local fht = CURR_TASK_OBJECTIVE(gsiPlayer, fight_harass_handle)
		local fhtReal = fht
				and fht.hUnit.IsNull and not fht.hUnit:IsNull()
		local fhtPercHp = fht
				and fht.lastSeenHealth / fht.maxHealth or 1.0
		local fhtLoc = fhtReal and fht.lastSeen.location
		local distToFht = fhtReal and POINT_DISTANCE(playerLoc, fhtLoc)
		local danger, knownEnemies, theorizedEnemies = DANGER(gsiPlayer)

		local powerShotDamage = powerShot:GetSpecialValueFloat("powershot_damage")
		local shackleCastRange = shackleShot:GetCastRange()

		local enemyCreepSetNearby
		local neutralsNearby

		

		-- falsify attack range in focusfire
		
		local allEnemies = Set_NumericalIndexUnion(nil, nearbyEnemies, outerEnemies)

		

		-- Power shot for a kill
		if allEnemies[1] and CAN_BE_CAST(gsiPlayer, powerShot) then
			local target, dmgFactor, isKill, allCastSucceedsUnits
					= EFFICIENT_KILL(gsiPlayer, powerShot, allEnemies,
							powerShotDamage, true, true
						)
			
			if target and isKill and powerShot:GetManaCost() < gsiPlayer.hUnit:GetMana()
					and (pUnit_IsNullOrDead(target)
						or POINT_DISTANCE_2D(target.lastSeen.location, playerLoc) > attackRange*0.85
					) then
				-- Check the shot is possible
				
				local hitGuess, timeToHit = SKILL_SHOT_LOC(gsiPlayer, target,
						POWERSHOT_MAX_CHANNEL + powerShot:GetCastPoint(),
						true, POWERSHOT_TRAVEL_SPEED
					)
				
				if not IsLocationVisible(hitGuess)
						and POINT_DISTANCE_2D(hitGuess, playerLoc) < powerShotRange then
					
					t_powershot_expire_before_cast[gsiPlayer.nOnTeam] = GameTime() + POWERSHOT_USE_EXPIRY
					USE_ABILITY(gsiPlayer, powerShot, hitGuess, 400, nil)
					return;
				end
			end
		end

		local castSucceedsUnitsNearby = nearbyEnemies[1]
				and CAST_SUCCEEDS_UNITS(gsiPlayer, nearbyEnemies, shackleShot)
		
		
		if fht == nil and currActivityType > ACTIVITY_TYPE.CAREFUL and nearbyEnemies[1] then
			fht = GREATEST_THREAT(gsiPlayer, castSucceedsUnitsNearby)
			fhtReal = fht and fht.hUnit.IsNull and not fht.hUnit:IsNull()
			fhtPercHp = fht and fht.lastSeenHealth / fht.maxHealth or 1.0
			fhtLoc = fhtReal and fht.lastSeen.location
			distToFht = fhtReal and POINT_DISTANCE(playerLoc, fhtLoc)
		end

		

		local bestScoreShackle, bestTarget, bestHitLoc, bestHitCount
		local bestPossibleShackleFound = false
		if fhtReal and CAN_BE_CAST(gsiPlayer, shackleShot) and castSucceedsUnitsNearby
				and castSucceedsUnitsNearby[1]
				and gsiPlayer.lastSeenMana > shackleShot:GetManaCost() then
			
			if castSucceedsUnitsNearby[2] then
				bestScoreShackle, bestTarget, bestHitLoc, bestHitCount = SCORE_CONE_HEROES(
						gsiPlayer, castSucceedsUnitsNearby, shackleShot, SHACKLE_CONE_RANGE,
						SHACKLE_CONE_ANGLE, fht, true, 1.3,
						1.0, 0.2, 1.0, 0.01,
						shackleShot:GetCastPoint()+0.03, SHACKLE_TRAVEL_SPEED, -0, false, 1
					)
			end
			if bestTarget and bestHitCount >= 2 then
				local abscondScore = Xeta_AbscondCompareNamedScore("windrunnerShackleShotMultiple", bestScoreShackle)
				local heat, heatPerc = GET_HEAT(nearbyEnemies) 
				
				-- Prefer good shots, and when the enemy is heated.
				if abscondScore > 0.45 - heatPerc*0.2
						and HIGH_USE(gsiPlayer, shackleShot, highUse,
								(1-abscondScore*0.576)*(0.66 + (1-heatPerc)*0.66)
							) then
					
					t_shackle_expire_before_cast[gsiPlayer.nOnTeam] = GameTime() + SHACKLE_USE_EXPIRY
					USE_ABILITY(gsiPlayer, shackleShot, bestTarget, 400, nil)
					return;
				end
				bestPossibleShackleFound = true
			else
				
				-- Check a few trees in the right sector, adjust score, abscond
				
				-- Check units infront / behind, adjust score, abscond
			end
		end

		if castSucceedsUnitsNearby and castSucceedsUnitsNearby[1] then
			if shackleShot:GetCooldownTimeRemaining() < 0.15
					and focusFire:GetCooldownTimeRemaining() < 0.3
					and windrun:GetCooldownTimeRemaining() < 8 + 2*(-danger) then
				-- Feel more aggressive when safe, high health and near a low amount of enemies with all cds up.
				local soloKillFactor = (playerHpp * 1.1 - danger*0.66) - #knownEnemies - #theorizedEnemies
				if soloKillFactor > 0 then
					Task_IncentiviseTask(gsiPlayer, fight_harass_handle, min(75, soloKillFactor*30), 15)
				end
			end
			if currActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION then
				
				if gsiPlayer.hUnit:HasModifier("modifier_windrunner_windrun") then
					Blueprint_IncentiviseHighStakesTasks(gsiPlayer, 15, 3)
					local windrunDebuffRadius = windrun:GetSpecialValueInt("radius")
					if fhtReal and not fht.hUnit:HasModifier("modifier_windrunner_windrun_slow") then
						
						pUnit_SetFalsifyAttackRange(gsiPlayer, windrunDebuffRadius-20)
					end
				end
						
				-- Shackle targets intended to combo
				
				if fhtReal and CAN_BE_CAST(gsiPlayer, shackleShot) 
						and not bestPossibleShackleFound and distToFht < shackleCastRange + SHACKLE_CONE_RANGE
						and CAST_SUCCEEDS(gsiPlayer, fht, shackleShot) > 0
						and HIGH_USE(gsiPlayer, shackleShot, highUse, fhtPercHp) then
					local enemyCreepSetNearby = Set_GetNearestEnemyCreepSetToLocation(playerLoc)
					
					local score, target, hitsLoc, satisifiesArgs
					if enemyCreepSetNearby then
						score, target, hitsLoc, satisfiesArgs = SCORE_CONE_TARGET(
									gsiPlayer, enemyCreepSetNearby.units, shackleShot, fht, SHACKLE_CONE_RANGE,
									SHACKLE_CONE_ANGLE, false, shackleShot:GetCastPoint(), SHACKLE_TRAVEL_SPEED,
									nil, false,
									false, shackleCastRange, SHACKLE_CONE_RANGE*3
								)
					end
					
					if target then
						local abscondScore = Xeta_AbscondCompareNamedScore("windrunnerShackleShotCreepTree", score)
						if abscondScore > 0.4 and HIGH_USE(gsiPlayer, shackleShot, highUse, (1-abscondScore*0.576)*(0.66 + fhtPercHp*0.33)) then
							
							t_shackle_expire_before_cast[gsiPlayer.nOnTeam] = GameTime() + SHACKLE_USE_EXPIRY
							USE_ABILITY(gsiPlayer, shackleShot, target, 400, nil)
							return;
						end
					else
						
						--USE_ABILITY(gsiPlayer, shackleShot, fht, 400, nil, nil, nil, SHACKLE_USE_EXPIRY)
						--return;
					end
				end

				-- Shackle absond during teamfights
				
				-- Wind run if enemies are running away from fighting and allies are
				-- -| nearby or #nearbyEnemies <= 1 + (0.5-danger)*playerHpp and
				-- -| fht is not stunned and fht.mvspeed > 0.66 windrunner's movespeed
				if fhtReal and (distToFht + fht.currentMovementSpeed*10 - gsiPlayer.currentMovementSpeed*10)
							> attackRange
						and HIGH_USE(gsiPlayer, windrun, highUse, fhtPercHp)
						and VEC_UNIT_FACING_UNIT(fht, gsiPlayer) < -0.33
						and fht.hUnit:GetMovementDirectionStability() > 0.8
						and not fht.hUnit:IsStunned()
						and CAN_BE_CAST(gsiPlayer, windrun)
						and HIGH_USE(gsiPlayer, windrun, highUse, fhtPercHp) then
					USE_ABILITY(gsiPlayer, windrun, nil, 400, nil)
					return;
				end
				-- Focusfire FHT over powershot damage hp abscond +shackled -nearEnemyTower +inmultiherofight +safety +lowhpself
				if fhtReal and CAN_BE_CAST(gsiPlayer, focusFire) and distToFht < attackRange * 1.03
						and HIGH_USE(gsiPlayer, focusFire, highUse,
								1-max(0.15, ((fht.hUnit:IsStunned() and 1.3 or 1)
										* fht.lastSeenHealth / gsiPlayer.lastSeenHealth)
								)
							) then
					local nearbyAllies = Set_GetAlliedHeroesInPlayerRadius(fht, 600)
					if fht.lastSeenHealth > (2.5+#nearbyAllies*2)
							* gsiPlayer.hUnit:GetAttackDamage()*Unit_GetArmorPhysicalFactor(fht) then
						Task_IncentiviseTask(gsiPlayer, fight_harass_handle, 75, 15)
						Task_IncentiviseTask(gsiPlayer, avoid_and_hide_handle, 75, 15)
						Task_IncentiviseTask(gsiPlayer, increase_safety_handle, 75, 15)
						USE_ABILITY(gsiPlayer, focusFire, fht, 400, nil)
						return;
					end
				end
			end

			-- Power shot abscond line of enemies
			-- +highmana ---oldLoc ++lowhealth +++multitarget
			if allEnemies[1] and CAN_BE_CAST(gsiPlayer, powerShot)
					and gsiPlayer.lastSeenMana > powerShot:GetManaCost()
					and (currActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION
						or (fhtReal and distToFht > 1300) -- TODO And seen by the enemy
					) then
				local crowdedLoc, crowdedRating = CROWDED_RATING(playerLoc, SET_HERO_ENEMY,
						allEnemies, powerShotRange
					)
				local score, hitsBetter = ScoreLocs_StripHeroes(gsiPlayer, allEnemies, powerShot,
						playerLoc,
						VEC_SCALAR_MULTIPLY_2D(VEC_UNIT_DIRECTIONAL(playerLoc, crowdedLoc),
								powerShotRange),
						POWERSHOT_HALF_WIDTH, fht,
						0.35, 1, 0.1,
						1, POWERSHOT_TRAVEL_SPEED, powerShotRange,
						powerShot:GetCastPoint() + POWERSHOT_MAX_CHANNEL,
						1000
					)
				score = score / sqrt(#allEnemies)
				local abscondScore = Xeta_AbscondCompareNamedScore("windrunnerPowerShotCrowded", score)
				if abscondScore > 0.3 + (playerHpp*0.5) - 0.15*gsiPlayer.lastSeenMana / gsiPlayer.maxMana
						and HIGH_USE(gsiPlayer, powerShot, highUse,
								(1-abscondScore*0.576)*(0.66+fhtPercHp*0.3)) then
					INFO_print(string.format("[windrunner] Sees high relative scoring Powershot: %.4f. Original crowding: %s. Score func says hits better: %s",
								abscondScore, tostring(crowdedLoc), tostring(hitsBetter)
							)
						)
					t_powershot_expire_before_cast[gsiPlayer.nOnTeam] = GameTime() + POWERSHOT_USE_EXPIRY
					USE_ABILITY(gsiPlayer, powerShot, hitsBetter, 400, nil)
					return;
				end
			end
			if currActivityType > ACTIVITY_TYPE.CAREFUL then
				-- Focusfire avoidhide in front of self to fountain, or close by
				if fhtReal and CAN_BE_CAST(gsiPlayer, focusFire)
						and (windrun:GetCooldownTimeRemaining() > 4*playerHpp
							or HIGH_USE(gsiPlayer, focusFire, highUse, playerHpp*2)
						) and distToFht < attackRange and danger > -0.5 + playerHpp then
					-- TODO misses nearby zoning
					Task_IncentiviseTask(gsiPlayer, fight_harass_handle, 75, 15)
					Task_IncentiviseTask(gsiPlayer, avoid_and_hide_handle, 75, 15)
					Task_IncentiviseTask(gsiPlayer, increase_safety_handle, 75, 15)
					USE_ABILITY(gsiPlayer, focusFire, fht, 400, nil)
					return;
				end
			end
		end
		-- Windrun if under attack
		local dam = DAMAGE_IN_TIMELINE(gsiPlayer.hUnit)
		local high = HIGH_USE(gsiPlayer, windrun, highUse, playerHpp)
		
		if CAN_BE_CAST(gsiPlayer, windrun)
				and DAMAGE_IN_TIMELINE(gsiPlayer.hUnit) > gsiPlayer.lastSeenHealth/15
				and HIGH_USE(gsiPlayer, windrun, highUse, playerHpp) then
			USE_ABILITY(gsiPlayer, windrun, nil, 400, nil)
			return;
		end

		-- Windrun if moving to fountain
		if not allEnemies[1] and danger < -1 and currTask == increase_safety_handle
				and CAN_BE_CAST(gsiPlayer, windrun)
				and GameTime() - Task_GetCurrentTaskStartTime(gsiPlayer) > 8
				and POINT_DISTANCE_2D(TEAM_FOUNTAIN, playerLoc) > 600 then
			USE_ABILITY(gsiPlayer, windrun, nil, 400, nil)
			return;
		end
		
		enemyCreepSetNearby = enemyCreepSetNearby or Set_GetNearestEnemyCreepSetToLocation(playerLoc)

		if TEST then print("wind high use", highUse) end
		
		if enemyCreepSetNearby and currTask == push_handle and #knownEnemies*3 + #theorizedEnemies < 4
				and POINT_DISTANCE_2D(playerLoc, enemyCreepSetNearby.center) < powerShotRange
				and HIGH_USE(gsiPlayer, powerShot, highUse*8, 1) then
			USE_ABILITY(gsiPlayer, powerShot, enemyCreepSetNearby.center, 400, nil)
			return;
		end

		-- Low chance of a tough fight, in push, Focusfire building objective over 2*attackDamage HP.
	end,
}

local hero_access = function(key) return d[key] end

do
	HeroData_SetHeroData(hero_data, abilities, hero_access)
end
