local hero_data = {
	"void_spirit",
	{3, 1, 3, 1, 3, 4, 3, 2, 1, 1, 2, 4, 2, 2, 8, 5, 9, 4, 11},
	{
		"item_ward_observer","item_tango","item_circlet","item_branches","item_branches","item_branches","item_branches","item_bottle","item_magic_wand","item_bracer","item_boots","item_power_treads","item_quarterstaff","item_robe","item_echo_sabre","item_blade_of_alacrity","item_boots_of_elves","item_yasha","item_manta","item_staff_of_wizardry","item_blade_of_alacrity","item_ultimate_scepter","item_cloak","item_mage_slayer","item_black_king_bar","item_bloodthorn","item_invis_sword","item_lesser_crit","item_silver_edge","item_aghanims_shard",
	},
	{ {2,2,2,2,1,}, {2,2,2,2,1,}, 0.1 },
	{
		"Aether Remnant","Dissimilate","Resonant Pulse","Astral Step","+1.5 Mana Regen","+50 Aether Remnant Damage","Remnant Provides 475 True Sight","+70 Resonant Pulse Damage","Outer Dissimilate Ring","-4s Astral Step Charge Restore Time","140% Astral Step Crit","Dissimilate Roots for 2.0s",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"void_spirit_aether_remnant", ABILITY_TYPE.NUKE + ABILITY_TYPE.STUN + ABILITY_TYPE.POINT_TARGET},
		{"void_spirit_dissimilate", ABILITY_TYPE.AOE + ABILITY_TYPE.POINT_TARGET + ABILITY_TYPE.SHIELD},
		{"void_spirit_resonant_pulse", ABILITY_TYPE.SHIELD + ABILITY_TYPE.BUFF + ABILITY_TYPE.NUKE},
		[5] = {"void_spirit_astral_step", ABILITY_TYPE.SLOW + ABILITY_TYPE.NUKE + ABILITY_TYPE.MOBILITY + ABILITY_TYPE.AOE}
}

local RESONANT_PULSE_RADIUS_HITS = 455
local A_R_RADIUS_SAFE = 180
local EXTRAPOLATE_A_R_CAST_TIME = 1.0
local A_S_DETONATE_TIME = 1.75
local HIGH_USE_A_R_MANA = 130 + 130 + 100
local HIGH_USE_A_S_MANA = 100 + 130 + 130
local HIGH_USE_R_P_MANA = 100 + 130 + 100
local HIGH_USE_DISSIMILATE_MANA = 100 + 130 + 100

local ASTRAL_STEP_CHARGES = 2

local ZEROED_VECTOR = ZEROED_VECTOR
local nearbyOuter = Set_GetEnemyHeroesInPlayerRadiusAndOuter
local ENCASED_IN_RECT = Set_GetEnemiesInRectangle
local currentTask = Task_GetCurrentTaskHandle
local AbilityLogic_AbilityCanBeCast = AbilityLogic_AbilityCanBeCast
local USE_ABILITY = UseAbility_RegisterAbilityUseAndLockToScore
local VEC_UNIT_DIRECTIONAL = Vector_UnitDirectionalPointToPoint
local NEAREST_CREEPS_TO_LOC = Set_GetNearestEnemyCreepSetToLocation
local LOWEST_CREEP_HEALTH = Set_GetLowestCreepHealthInSet
local ACTIVITY_TYPE = ACTIVITY_TYPE
local currentActivityType = Blueprint_GetCurrentTaskActivityType

local fight_harass_task_handle = FightHarass_GetTaskHandle()
local push_task_handle = Push_GetTaskHandle()

local next_allowed_astral_step = {}

do
	for i=1,TEAM_NUMBER_OF_PLAYERS do
		next_allowed_astral_step[i] = 0
	end
end

local combos = {
	["dissimilate_back"] = {
			abilities[1][3], 
			function(gsiPlayer) 
				gsiPlayer.hUnit:Action_MoveDirectly(
						Vector_ScalarMultiply(
							Vector_UnitDirectionalPointToPoint(
								gsiPlayer.lastSeen.location, 
								Map_GetLogicalLocation(TEAM==TEAM_RADIANT and Map_GetLogicalLocation(MAP_POINT_RADIANT_FOUNTAIN_CENTER) or Map_GetLogicalLocation(MAP_POINT_DIRE_FOUNTAIN_CENTER))
							), 600
						)
					)
			end
	},
}

local t_player_abilities = {}

local d 
d = {
	["ReponseNeeds"] = function()
		return nil, nil, {RESPONSE_TYPE_IMMOBILE, 4}, nil
	end,
	["CastAetherRemnantExtrapolated"] = function(gsiPlayer, aetherRemnant, aetherTarget) 
		if aetherTarget.hUnit:GetMovementDirectionStability() > 0.0 and (
					Unit_GetManaPercent(gsiPlayer) > 0.0 or	
						AbilityLogic_HighUseAllowOffensive(gsiPlayer, aetherRemnant, HIGH_USE_A_R_MANA, Unit_GetHealthPercent(aetherTarget))
				) then
			--[DEBUG]]print("Would try successful aether Remnant")
			local nearbyCreeps = Set_GetNearestEnemyCreepSetToLocation(gsiPlayer.lastSeen.location)
			local extrapolatedLocation = aetherTarget.hUnit:GetExtrapolatedLocation(EXTRAPOLATE_A_R_CAST_TIME)
			local directionOfAether = VEC_UNIT_DIRECTIONAL(extrapolatedLocation, ZEROED_VECTOR)
			local locationOfAether = Vector(extrapolatedLocation.x-directionOfAether.x*350, extrapolatedLocation.y-directionOfAether.y*350, 0)
			local distanceToCastLocation = Math_PointToPointDistance2D(gsiPlayer.lastSeen.location, locationOfAether)
			if distanceToCastLocation < aetherRemnant:GetCastRange() + 50 and (not nearbyCreeps or (nearbyCreeps.units[1] and not ENCASED_IN_RECT(locationOfAether, extrapolatedLocation, A_R_RADIUS_SAFE, nearbyCreeps, nil, true)[1])) then
				USE_ABILITY(gsiPlayer, aetherRemnant, locationOfAether, 350, nil)
				return true
			end
		end
		return false
	end,
	["resonant_pulse_damage"] = {[0] = 220, 70, 120, 170, 220},
	["ResonantPulseDamage"] = function(gsiPlayer) return d.resonant_pulse_damage[t_player_abilities[gsiPlayer.nOnTeam][3]:GetLevel()] end,
	["astral_step_range"] = {[0]=1100, 700, 900, 1100},
	["astral_step_restore_time"] = {[0]=HIGH_32_BIT, 30, 25, 20},
	["AstralStepRange"] = function(gsiPlayer) return d.astral_step_range[t_player_abilities[gsiPlayer.nOnTeam][4]:GetLevel()] end,
	["AstralStepMaxCharges"] = function() return ASTRAL_STEP_CHARGES end,
	["AstralStepChargeRestoreTime"] = function(gsiPlayer) return d.astral_step_restore_time[t_player_abilities[gsiPlayer.nOnTeam][4]:GetLevel()] end,
	["Initialize"] = function(gsiPlayer)
		AbilityLogic_CreatePlayerAbilitiesIndex(t_player_abilities, gsiPlayer, abilities)
		AbilityLogic_UpdateHighUseMana(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam])
		ChargedCooldown_RegisterCooldown(
				gsiPlayer,
				t_player_abilities[gsiPlayer.nOnTeam][4], 
				d.AstralStepMaxCharges,
				d.AstralStepChargeRestoreTime
			)
		gsiPlayer.InformLevelUpSuccess = d.InformLevelUpSuccess
	end,
	["InformLevelUpSuccess"] = function(gsiPlayer)
		AbilityLogic_UpdateHighUseMana(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam])
		AbilityLogic_UpdatePlayerAbilitiesIndex(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam], abilities)
	end,
	["AbilityThink"] = function(gsiPlayer)
		local locked, _, ability = UseAbility_IsPlayerLocked(gsiPlayer)
		--[DEBUG]]if locked then DEBUG_print(string.format("void_spirit locked by %s", ability:GetName())) end
		if not locked then
			local currActivityType = currentActivityType(gsiPlayer)
			local currTask = currentTask(gsiPlayer)
			local thisPlayerAbilities = t_player_abilities[gsiPlayer.nOnTeam]
			local aetherRemnant = thisPlayerAbilities[1]
			local dissimilate = thisPlayerAbilities[2]
			local resonantPulse = thisPlayerAbilities[3]
			local astralStep = thisPlayerAbilities[4]
			local playerHealthPercent = gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth
			--print("astral step range", d.AstralStepRange(gsiPlayer))
			local nearbyEnemies, outerEnemies = nearbyOuter(gsiPlayer.lastSeen.location, RESONANT_PULSE_RADIUS_HITS, d.AstralStepRange(gsiPlayer)+50)

			local resonantPulseBuff = gsiPlayer.hUnit:HasModifier("modifier_void_spirit_resonant_pulse_physical_buff")
			if currTask == fight_harass_task_handle then -- Harass: Resonant Pulse target in range
				--[DEBUG]]]print("harass pulse")
				if not resonantPulseBuff and #nearbyEnemies > 0 and AbilityLogic_AbilityCanBeCast(gsiPlayer, resonantPulse) and gsiPlayer.lastSeenMana > resonantPulse:GetManaCost() then
					-- TODO Do not use when currently up -- aghs with charges
					USE_ABILITY(gsiPlayer, resonantPulse, nil, 450, nil)
					Task_IncentiviseTask(gsiPlayer, fight_harass_task_handle, 24.0, 3.0)
					return
				end
			end
			if currActivityType > ACTIVITY_TYPE.CAREFUL then -- IncreaseSafety: Astral Step away, Disimilate dodge tracked projectiles, resonant pulse if enemies are nearby, Aether Remnant a nearby enemy hero. 
				local projectiles = gsiPlayer.hUnit:GetIncomingTrackingProjectiles()
				--[DEBUG]]print("projectiles:", #projectiles, playerHealthPercent)
				if (#projectiles > 0 and playerHealthPercent < 0.6) or playerHealthPercent < 0.45 and (nearbyEnemies[1] or outerEnemies[1]) then
					if AbilityLogic_AbilityCanBeCast(gsiPlayer, dissimilate) and AbilityLogic_HighUseAllowOffensive(gsiPlayer, dissimilate, HIGH_USE_DISSIMILATE_MANA, playerHealthPercent) then
						--[DEBUG]]print("Using safety dissimilate")
						USE_ABILITY(gsiPlayer, dissimilate, nil, 450, nil)
						return
					end
				end
				--[DEBUG]]print("astralStep charges", ChargedCooldown_AbilityCanBeCast(gsiPlayer, astralStep), ChargedCooldown_GetCurrentCharges(gsiPlayer, astralStep), nearbyEnemies[1], outerEnemies[1])
				if ChargedCooldown_AbilityCanBeCast(gsiPlayer, astralStep) and gsiPlayer.lastSeenMana > astralStep:GetManaCost() then 
					if nearbyEnemies[1] or outerEnemies[1]
							and (not gsiPlayer.time.data.theorizedDanger
									or gsiPlayer.time.data.theorizedDanger > 2) then
						--[DEBUG]]print("Using AstralStep", ChargedCooldown_GetCurrentCharges(gsiPlayer, astralStep), nearbyEnemies[1], outerEnemies[1])
						USE_ABILITY(gsiPlayer, astralStep, Map_GetTeamFountainLocation(), 450, nil, gsiPlayer.hUnit.Action_UseAbilityOnLocation)
					end
				end
				--[DEBUG]]print("resonantPulse check", AbilityLogic_AbilityCanBeCast(gsiPlayer, resonantPulse), gsiPlayer.lastSeenMana, ">", resonantPulse:GetManaCost(), nearbyEnemies[1], outerEnemies[1], #projectiles)
				if not resonantPulseBuff and AbilityLogic_AbilityCanBeCast(gsiPlayer, resonantPulse) and gsiPlayer.lastSeenMana > resonantPulse:GetManaCost() and (nearbyEnemies[1] or outerEnemies[1] or #projectiles > 0) then
					--[DEBUG]]print("use safe resonantPulse")
					USE_ABILITY(gsiPlayer, resonantPulse, nil, 450, nil)
					Task_IncentiviseTask(gsiPlayer, fight_harass_task_handle, 18.0, 3.0)
					return
				end
				if AbilityLogic_AbilityCanBeCast(gsiPlayer, aetherRemnant) and gsiPlayer.lastSeenMana > resonantPulse:GetManaCost() and (nearbyEnemies[1] or outerEnemies[1]) then
					--[DEBUG]]print("use safe aether remnant")
					if d.CastAetherRemnantExtrapolated(gsiPlayer, aetherRemnant, nearbyEnemies[1] or outerEnemies[1]) then
						return
					end
				end
			end
			local nearestCreepSet = NEAREST_CREEPS_TO_LOC(gsiPlayer.lastSeen.location)
			if nearbyEnemies[1] and AbilityLogic_AbilityCanBeCast(gsiPlayer, resonantPulse) then
				local nearestCreepSet = NEAREST_CREEPS_TO_LOC(gsiPlayer.lastSeen.location)
				if nearestCreepSet and Math_PointToPointDistance2D(gsiPlayer.lastSeen.location, nearestCreepSet.center) < 600 then
					local lowestHp, lowestCreep = LOWEST_CREEP_HEALTH(nearestCreepSet)
					if lowestHp < d.ResonantPulseDamage(gsiPlayer) and lowestCreep.creepType ~= CREEP_TYPE_SIEGE
							and Math_PointToPointDistance2D(gsiPlayer.lastSeen.location, lowestCreep.lastSeen.location) < RESONANT_PULSE_RADIUS_HITS then
						USE_ABILITY(gsiPlayer, resonantPulse, nil, 350)
						Task_IncentiviseTask(gsiPlayer, fight_harass_task_handle, 24.0, 3.0)
						return
					end
				end
			end
			if not nearbyEnemies[1] and currTask == push_task_handle and FightHarass_GetHealthDiffOutnumbered(gsiPlayer) > 1 then
				if nearestCreepSet and Math_PointToPointDistance2D(gsiPlayer.lastSeen.location, nearestCreepSet.center) < 600 then
					if AbilityLogic_AbilityCanBeCast(gsiPlayer, dissimilate) and gsiPlayer.lastSeenMana > HIGH_USE_DISSIMILATE_MANA*2 then
						USE_ABILITY(gsiPlayer, dissimilate, nil, 350)
						return
					end
				end
			end
			if currActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION
					or Unit_GetManaPercent(gsiPlayer) > 0.97 then -- FarmLane: Use efficient at-range damage when high mana
				--print("vs in 0.9")
				local aetherTarget = nearbyEnemies[1] or outerEnemies[1]
				if aetherTarget then -- n.b. Using implicit enemy found below
					if AbilityLogic_AbilityCanBeCast(gsiPlayer, aetherRemnant)  then
						if d.CastAetherRemnantExtrapolated(gsiPlayer, aetherRemnant, aetherTarget) then
							return
						end
					end

					local target, targetPercentHealth = Task_GetTaskObjective(gsiPlayer, fight_harass_task_handle)
					if not target then 
						target, targetPercentHealth = Unit_LowestHealthPercentPlayer(nearbyEnemies, outerEnemies) -- implicitly defined (aetherTarget codeblock)
					else
						targetPercentHealth = target.lastSeenHealth / target.maxHealth
					end
					--print("vs", d.AstralStepChargeRestoreTime(gsiPlayer), "-", ChargedCooldown_GetTimeUntilCharge(gsiPlayer, astralStep))
					if ChargedCooldown_AbilityCanBeCast(gsiPlayer, astralStep) and next_allowed_astral_step[gsiPlayer.nOnTeam] < GameTime() 
							and AbilityLogic_HighUseAllowOffensive(gsiPlayer, astralStep, HIGH_USE_A_S_MANA*(3-(ChargedCooldown_GetCurrentCharges(gsiPlayer, astralStep))), targetPercentHealth) then
						local directional = VEC_UNIT_DIRECTIONAL(gsiPlayer.lastSeen.location, target.lastSeen.location)
						local resultLocation = Vector_Addition(target.lastSeen.location, Vector_ScalarMultiply2D(directional, 180))
						--DebugDrawLine(gsiPlayer.lastSeen.location, resultLocation, 0, 255, 123)
						next_allowed_astral_step[gsiPlayer.nOnTeam] = GameTime() + A_S_DETONATE_TIME
						USE_ABILITY(gsiPlayer, astralStep, resultLocation, 350, nil)
					end
					if currActivityType <= ACTIVITY_TYPE.KILL or gsiPlayer.time.data.theorizedDanger and gsiPlayer.time.data.theorizedDanger < -1.0 then
						if #nearbyEnemies > 1 and AbilityLogic_AbilityCanBeCast(gsiPlayer, dissimilate)
								and AbilityLogic_HighUseAllowOffensive(gsiPlayer, dissimilate, HIGH_USE_DISSIMILATE_MANA, targetPercentHealth) then
							USE_ABILITY(gsiPlayer, dissimilate, nil, 350, nil)
							return
						elseif (not resonantPulseBuff or targetPercentHealth < 0.15) and AbilityLogic_AbilityCanBeCast(gsiPlayer, resonantPulse) and Math_PointToPointDistance2D(gsiPlayer.lastSeen.location, target.lastSeen.location) < RESONANT_PULSE_RADIUS_HITS and
								AbilityLogic_HighUseAllowOffensive(gsiPlayer, resonantPulse, HIGH_USE_R_P_MANA, targetPercentHealth) then
							USE_ABILITY(gsiPlayer, resonantPulse, nil, 350, nil)
							return
						end
					end
				end
			else --[[print("vs skipped 0.9")]] end
		end
	end
}

local hero_access = function(key) return d[key] end

do
	HeroData_SetHeroData(hero_data, abilities, hero_access)
end
