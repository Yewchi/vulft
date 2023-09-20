local hero_data = {
	"juggernaut",
	{1, 2, 1, 3, 1, 4, 1, 2, 2, 5, 2, 4, 3, 3, 7, 3, 4, 9, 11},
	{
		"item_circlet","item_tango","item_magic_stick","item_branches","item_quelling_blade","item_boots","item_wraith_band","item_magic_wand","item_chainmail","item_blades_of_attack","item_phase_boots","item_gloves","item_wind_lace","item_mithril_hammer","item_hand_of_midas","item_mithril_hammer","item_maelstrom","item_mjollnir","item_yasha","item_belt_of_strength","item_manta","item_blade_of_alacrity","item_point_booster","item_staff_of_wizardry","item_ogre_axe","item_ultimate_scepter","item_basher","item_eagle","item_talisman_of_evasion","item_quarterstaff","item_butterfly","item_abyssal_blade",
	},
	{ {1,1,1,1,1,}, {1,1,1,1,1,}, 0.1 },
	{
		"Blade Fury","Healing Ward","Blade Dance","Omnislash","+5 All Stats","+100 Blade Fury Radius","-20.0s Healing Ward Cooldown","+100 Blade Fury DPS","+60% Blade Dance Lifesteal","-3s Blade Fury Cooldown","+1s Omnislash Duration","+2 Healing Ward Hits to Kill",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"juggernaut_blade_fury", ABILITY_TYPE.NUKE + ABILITY_TYPE.SHIELD + ABILITY_TYPE.AOE},
		{"juggernaut_healing_ward", ABILITY_TYPE.SUMMON + ABILITY_TYPE.HEAL + ABILITY_TYPE.AOE},
		{"juggernaut_blade_dance", ABILITY_TYPE.PASSIVE},
		{"juggernaut_swift_slash", ABILITY_TYPE.NUKE + ABILITY_TYPE.AOE + ABILITY_TYPE.SHIELD},
		[5] = {"juggernaut_omni_slash", ABILITY_TYPE.NUKE + ABILITY_TYPE.AOE + ABILITY_TYPE.SHIELD},
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
local AL_MAGIC_PROJECTILES = AbilityLogic_AnyProjectilesImmunable
local DAMAGE_IN_TIMELINE = Analytics_GetTotalDamageInTimeline
local FUTURE_DAMAGE_IN_TIMELINE = Analytics_GetFutureDamageInTimeline
local A_T = ACTIVITY_TYPE
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

local t_player_abilities = {}

local OUTER_RANGE = 1400

local TEST = TEST

local d
d = {
	["ReponseNeeds"] = function()
		FightClimate_RegAvoidHeroReponse(R.RESPONSE_TYPE_AVOID_CASTER,
				nil,
				"juggernaught", "juggernaught_blade_fury",
				BLADE_FURY_DURATION, BLADE_FURY_RADIUS, 0.3,
				"modifier_juggernaught_blade_fury", false )
		FightClimate_RegSummedResponse(R.RESPONSE_TYPE_KILL_SUMMON,
				nil,
				"juggernaught", "juggernaught_healing_ward",
				HEALING_WARD_DURATION, 0.6,
				"modifier_juggernaught_healing_ward_heal", false,
				{"npc_dota_juggernaught_healing_ward"}, true
			)
	end,
	["Initialize"] = function(gsiPlayer)
		AbilityLogic_CreatePlayerAbilitiesIndex(t_player_abilities, gsiPlayer, abilities)
		AbilityLogic_UpdateHighUseMana(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam])
		gsiPlayer.InformLevelUpSuccess = d.InformLevelUpSuccess
		SpecialBehavior_RegisterBehavior("fightHarassRunOverride",
				function(gsiPlayer, objective, score)
					local hUnit = gsiPlayer.hUnit
					local bladeFury = hUnit:GetAbilityByName("juggernaut_blade_fury")
					
					if not bladeFury 
							or not hUnit:HasModifier("modifier_juggernaut_blade_fury") then
						return false
					end
					local playerLoc = gsiPlayer.lastSeen.location
					local fhtLoc = objective.lastSeen.previousLocation -- slightly more realistic.. needs about 8 frames really
					local bladeFuryRadius = bladeFury:GetSpecialValueFloat("blade_fury_radius")
					bladeFuryRadius = bladeFuryRadius and bladeFuryRadius > 0 and bladeFuryRadius
							or 250
					local danger, knownE = Analytics_GetTheoreticalDangerAmount(gsiPlayer, nil, fhtLoc)
					local crowdedLoc, crowdedRating = CROWDED_RATING(fhtLoc, SET_HERO_ENEMY, nil, bladeFuryRadius)
					
					if crowdedRating > 1.1 then
						
						gsiPlayer.hUnit:Action_MoveDirectly(crowdedLoc)
						return true;
					end
					-- from 0.66 away from enemy fountain to 0.66 towards enemy fountain
					-- -| based on danger and the facing direction of the unit
					local fhtReal = not pUnit_IsNullOrDead(objective)
					local limit = fhtReal and -bladeFuryRadius * 0.33  +  bladeFuryRadius * max(1, min(-0.33,
								min(-danger-1, Vector_UnitFacingLoc(objective, ENEMY_FOUNTAIN))
							))
					local moveTo = fhtReal
							and Vector_PointToPointLimitedMin2D(fhtLoc, ENEMY_FOUNTAIN, limit)

					

					if moveTo and GSI_UnitCanStartAttack(gsiPlayer)
							and Vector_PointDistance2D(moveTo, playerLoc) < 150
							and (Vector_UnitFacingUnit(objective, gsiPlayer) > 0.67
								or objective.hUnit:IsStunned() or objective.hUnit:IsRooted()
								or objective.currentMovementSpeed / gsiPlayer.currentMovementSpeed
									< 0.45
							) then
						-- get procs if they're facing you and you're in the desired loc
						gsiPlayer.hUnit:Action_AttackUnit(fht, true)
						return true;
					end
					gsiPlayer.hUnit:Action_MoveDirectly(moveTo or fhtLoc)
					return true;
				end
			)
		SpecialBehavior_RegisterBehavior("useItemMantaStyleOverride",
				function(gsiPlayer, hItem, nearbyEnemies)
					local hUnit = gsiPlayer.hUnit
					local bladeFury = hUnit:GetAbilityInSlot(0)
					local omni = hUnit:GetAbilityInSlot(5)
					if not bladeFury or bladeFury:GetName() ~= "juggernaut_blade_fury"
							or hUnit:HasModifier("modifier_juggernaut_blade_fury")
							or hUnit:HasModifier("modifier_juggernaut_omnislash")
							or hUnit:IsSilenced() then
						-- above check immune-hits dodgeables if in BF.
						return nil;
					end
					if CAN_BE_CAST(gsiPlayer, bladeFury)
							and AbilityLogic_AnyProjectilesImmunable(gsiPlayer) then
						USE_ABILITY(gsiPlayer, bladeFury, nil, 400, nil)
						return false;
					end
					local knownE = gsiPlayer.time.data.knownEngageables
					if knownE and CAN_BE_CAST(gsiPlayer, omni) then
						local incoming, ability = AbilityLogic_AnyProjectiles(gsiPlayer, true)
						if incoming and gsiPlayer.lastSeenHealth
								< max(200+50*(#knownE)^1.25, ability:GetSpecialValueInt("damage")) then
							local nearestEnemy, nearestDist = Vector_GetNearestToUnitForUnits(
									gsiPlayer, nearbyEnemies
								)
							if nearestEnemy and nearestDist < omnislash:GetCastRange() * 1.125 then
								USE_ABILITY(gsiPlayer, omni, nil, 400, nil)
								return false;
							end
						end
					end
					return nil;
				end
			)
	end,
	["InformLevelUpSuccess"] = function(gsiPlayer)
		AbilityLogic_UpdateHighUseMana(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam])
		AbilityLogic_UpdatePlayerAbilitiesIndex(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam], abilities)
	end,
	["npc_dota_juggernaut_healing_ward"] = function(gsiSummon)
		INFO_print("TEST SUMMON", gsiSummon); Util_TablePrint(gsiSummon);
	end,
	["AbilityThink"] = function(gsiPlayer) 
		if AbilityLogic_PlaceholderGenericAbilityUse(gsiPlayer, t_player_abilities) then
			return
		elseif false then -- TODO generic item use (probably can use same func for finished heroes)
			return;
		end
		if UseAbility_IsPlayerLocked(gsiPlayer) then
			return;
		end
		local playerAbilities = t_player_abilities[gsiPlayer.nOnTeam]
		local bladeFury = playerAbilities[1]
		local healingWard = playerAbilities[2]
		local swiftSlash = playerAbilities[4]
		local omnislash = playerAbilities[5]

		local bladeFuryRange = bladeFury:GetCastRange()

		local highUse = gsiPlayer.highUseManaSimple
		local playerHpp = gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth

		local hUnit = gsiPlayer.hUnit
		local playerLoc = gsiPlayer.lastSeen.location
		local currActivityType = currentActivityType(gsiPlayer)
		local currTask = currentTask(gsiPlayer)
		local nearbyEnemies, outerEnemies
				= Set_GetEnemyHeroesInLocRadOuter(gsiPlayer.lastSeen.location, 750, 1600, 0.75)
		local fht = Task_GetTaskObjective(gsiPlayer, fight_harass_handle)
		local fhtReal = fht
				and fht.hUnit.IsNull and not fht.hUnit:IsNull()
		local fhtPercHp = fht
				and fht.lastSeenHealth / fht.maxHealth or 1.0
		local fhtLoc = fhtReal and fht.lastSeen.location
		local distToFht = fhtReal and POINT_DISTANCE(playerLoc, fhtLoc)

		local danger = DANGER(gsiPlayer)

		local allE = Set_NumericalIndexUnion(nil, nearbyEnemies, outerEnemies)

		local damageInTimeline = DAMAGE_IN_TIMELINE(gsiPlayer.hUnit)

		local mgkProjectiles

		local inBladeFury = hUnit:HasModifier("modifier_juggernaut_blade_fury")
		local bladeFuryDurationFromNow = inBladeFury
				and hUnit:GetModifierRemainingDuration(
						hUnit:GetModifierByName("modifier_juggernaut_blade_fury")
					)
				or bladeFury:GetSpecialValueFloat("duration")
		local bladeFuryDamage = bladeFuryDurationFromNow
				* bladeFury:GetSpecialValueInt("blade_fury_damage")

		local bladeFuryRadius = bladeFury:GetSpecialValueFloat("blade_fury_radius")

		

		local bladeFuryCanCast = CAN_BE_CAST(gsiPlayer, bladeFury)
		local healingWardCanCast = CAN_BE_CAST(gsiPlayer, healingWard)
		local omnislashCanCast = CAN_BE_CAST(gsiPlayer, omnislash) 
		local swiftslashCanCast = CAN_BE_CAST(gsiPlayer, swiftSlash)

		local futureDamage = FUTURE_DAMAGE_IN_TIMELINE(gsiPlayer.hUnit)

		local exposed, countCanAttackMe, dpsToMe
		if bladeFuryCanCast or omnislashCanCast then
			exposed, countCanAttackMe, dpsToMe 
					= FightClimate_ImmediatelyExposedToAttack(gsiPlayer, 
						nearbyEnemies, 2)
		end

		

		if bladeFuryCanCast and fhtReal and bladeFuryRadius+44 > distToFht
				and fht.hUnit:GetActualIncomingDamage(hUnit:GetAttackDamage(),
						DAMAGE_TYPE_PHYSICAL
					) * max(0.9, 1 + Vector_UnitFacingLoc(fht, ENEMY_FOUNTAIN)*1.05 -
						fhtPercHp/playerHpp) < fht.lastSeenHealth
				and AbilityLogic_AllowOneHitKill(gsiPlayer, fht, 16000, bladeFuryDamage,
						bladeFury:GetDamageType(), nearbyEnemies
					)
				and dpsToMe*bladeFuryDurationFromNow*(1.1+max(0, gsiPlayer.vibe.greedRating
						+ Analytics_GetWinningFactor()
					)) < fht.lastSeenHealth then
			Task_IncentiviseTask(gsiPlayer, fight_harass_handle, 100, 10)
			USE_ABILITY(gsiPlayer, bladeFury, nil, 400, nil)
			return;
		end

		local hasIncomingImmunablePj
		if not inBladeFury then
			if bladeFuryCanCast then
				hasIncomingImmunablePj = hasIncomingImmunablePj
						or AL_MAGIC_PROJECTILES(gsiPlayer)
				if hasIncomingImmunablePj then
					
					USE_ABILITY(gsiPlayer, bladeFury, nil, 400)
					return;
				end
				if #allE > 0 and (currActivityType >= A_T.FEAR and futureDamage > 0
							or currTask == fight_harass_handle
						) and ( hUnit:IsRooted()
							or gsiPlayer.currentMovementSpeed+1
									< hUnit:GetBaseMovementSpeed()
						) then
					
					USE_ABILITY(gsiPlayer, bladeFury, nil, 400)
					return;
				end
			end
			if currActivityType <= A_T.CONTROLLED_AGGRESSION
					and fhtReal then
				
				if bladeFuryRadius+44 > distToFht
						and HIGH_USE(gsiPlayer, bladeFury, highUse, fhtPercHp) then
					
					Task_IncentiviseTask(gsiPlayer, fight_harass_handle, 50, 5)
					USE_ABILITY(gsiPlayer, bladeFury, nil, 400)
					return;
				end
			end
		end
		-- TODO TEMP
		-- Healing Ward
		--[[if gsiPlayer.recentMoveTo then
			nearestEnemy, nearestDist
				= Set_GetNearestEnemyHeroToLocation(gsiPlayer.recentMoveTo)
		end--]]
		local nearbyAllies = Set_GetAlliedHeroesInPlayerRadius(gsiPlayer, 1750, true)
		local lowest, lowestHppAllied
		if #nearbyAllies > 0 then
			lowest, lowestHppAllied = Unit_LowestHealthPercentPlayer(nearbyAllies)
		else
			lowest = gsiPlayer; lowestHppAllied = playerHpp
		end
		local fightIsOn, alliesHeat, enemiesHeat
				= FightClimate_FightIsOn(gsiPlayer, nearbyAllies, allE, 2400)
		if CAN_BE_CAST(gsiPlayer, healingWard)
				and ((fightIsOn and lowestHppAllied < 0.45 + 0.085*#allE
						and gsiPlayer.lastSeenMana > highUse*1.33
					) or (#nearbyAllies > 2 or #nearbyEnemies == 0
						or enemiesHeat > 0.99)
					and HIGH_USE(gsiPlayer, healingWard, highUse*1.33, 
						(1.5*lowestHppAllied-max(0, danger)) / (1 + #nearbyEnemies + #outerEnemies))
					and ( (currTask == zone_defend_handle
						and max(fhtReal and POINT_DISTANCE_2D(playerLoc, fhtLoc) or 0,
							gsiPlayer.recentMoveTo 
								and POINT_DISTANCE_2D(playerLoc, gsiPlayer.recentMoveTo) or 0
							) < 1500
						) or (playerHpp - futureDamage*3 / gsiPlayer.maxHealth)
							< 0.35 + max(0, min(0.5, danger*0.167))
				)) then
			USE_ABILITY(gsiPlayer, healingWard,
					Vector_FacingAtLength(gsiPlayer, 100), 400, nil
				)
			return;
		end
		-- TODO TEMP
		-- Omnislash
		local omnislashTotalDmg = fhtReal and Unit_GetArmorPhysicalFactor(fht)
				* (4.5*hUnit:GetAttackDamage() + 135) / (1 / hUnit:GetAttackSpeed())
		local danger = fhtReal and Analytics_GetTheoreticalDangerAmount(gsiPlayer)
		local fightIntent

		if DEBUG and fht then INFO_print("[hero_jug] vacuum omnislash to %s: %s", fht.shortName, omnislashTotalDmg) end
		
		if (omnislashCanCast or swiftslashCanCast) and fhtReal then -- TEMP
			if futureDamage * 3 > gsiPlayer.lastSeenHealth then
				local nearestEnemy, nearestDist = Set_GetNearestEnemyHeroToLocation(playerLoc)
				if nearestEnemy and nearestDist < omnislash:GetCastRange()*1.33 then
					if omnislashCanCast then
						USE_ABILITY(gsiPlayer, omnislash, nearestEnemy, 400, nil)
					else
						-- TEMP
						USE_ABILITY(gsiPlayer, swiftslash, nearestEnemy, 400, nil)
					end
					return;
				end
			end
			local playerPower = Analytics_GetPowerLevel(gsiPlayer)
			local fhtPower = Analytics_GetPowerLevel(fht)
			local powerDiff = (fhtPower - playerPower) / playerPower
			local crowdedLoc, crowdedRating = CROWDED_RATING(fhtLoc, SET_HERO_ENEMY,
					nearbyEnemies, OMNISLASH_JUMP_DIST*0.67
				)
			if distToFht < omnislash:GetCastRange()*1.65 
						+ 0.4*Vector_UnitFacingUnit(fht, gsiPlayer)
					and (gsiPlayer.lastSeenHealth
							< fht.lastSeenHealth * (0.75 + #nearbyEnemies*0.5)
						or #nearbyEnemies + danger > 3
						or crowdedRating > 1.85
							and crowdedRating - (2 - fhtPercHp*2) < 2
						or fightIsOn
					) then
				local hasWaveClearItem = Item_HasWaveClearOn(gsiPlayer, true)
				local creeps, distCreeps
				if not hasWaveClearItem then
					creeps, distCreeps = Set_GetNearestEnemyCreepSetToLocation(
							fht.lastSeen.location
						)
				end
				local creepsAdjustDmg = creeps and creeps[1]
						and omnislashTotalDmg * max(hasWaveClearItem and 0.45 or 0.15,
								min(1, (distCreeps/300)/((#creeps)^0.5))
							)
						or omnislashTotalDmg
				INFO_print("[hero_jug] creep-adjusted omnislash to %s: %d. hasWaveClearItem: %s",
						fht.shortName, creepsAdjustDmg, hasWaveClearItem
					)
				if (creepsAdjustDmg) > fht.lastSeenHealth then
					if omnislashCanCast then
						USE_ABILITY(gsiPlayer, omnislash, fht, 400, nil)
					else
						-- TEMP
						USE_ABILITY(gsiPlayer, swiftslash, fht, 400, nil)
					end
					return;
				end
			end
		end
	end,
}

local hero_access = function(key) return d[key] end

do
	HeroData_SetHeroData(hero_data, abilities, hero_access)
end

