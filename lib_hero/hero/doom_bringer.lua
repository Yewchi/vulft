local hero_data = {
	"doom_bringer",
	{2, 1, 2, 3, 2, 4, 2, 1, 1, 1, 6, 4, 3, 3, 7, 3, 4, 9, 11},
	{
		"item_gauntlets","item_gauntlets","item_magic_stick","item_branches","item_branches","item_ring_of_health","item_vanguard","item_boots","item_magic_wand","item_gloves","item_arcane_boots","item_gloves","item_hand_of_midas","item_soul_booster","item_void_stone","item_octarine_core","item_aghanims_shard","item_blink","item_aghanims_shard","item_cornucopia","item_cornucopia","item_refresher","item_ultimate_scepter","item_overwhelming_blink","item_desolator","item_ultimate_scepter_2",
	},
	{ {3,3,3,3,3,}, {3,3,3,3,3,}, 0.1 },
	{
		"Devour","Scorched Earth","Infernal Blade","Doom","Devour grants +15% Magic Resistance","+15 Scorched Earth Damage","+7% Scorched Earth Movement Speed","Devour Can Target Ancients","-12.0s Scorched Earth Cooldown","+1.8% Infernal Blade Damage","Doom applies Mute","Doom applies Break",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"doom_bringer_devour", ABILITY_TYPE.BUFF, 0},
		{"doom_bringer_scorched_earth", ABILITY_TYPE.NUKE + ABILITY_TYPE.AOE + ABILITY_TYPE.MOBILITY, 0.1},
		{"doom_bringer_infernal_blade", ABILITY_TYPE.NUKE + ABILITY_TYPE.STUN + ABILITY_TYPE.ATTACK_MODIFIER, 0.1},
		[5] = {"doom_bringer_doom", ABILITY_TYPE.NUKE + ABILITY_TYPE.DEGEN, 0.2},
}

local ZEROED_VECTOR = ZEROED_VECTOR
local playerRadius = Set_GetEnemyHeroesInPlayerRadius
local ENCASED_IN_RECT = Set_GetEnemiesInRectangle
local CURRENT_TASK = Task_GetCurrentTaskHandle
local CAN_BE_CAST = AbilityLogic_AbilityCanBeCast
local CHARGE_CAN_BE_CAST = ChargedCooldown_AbilityCanBeCast
local USE_ABILITY = UseAbility_RegisterAbilityUseAndLockToScore
local VEC_POINT_DISTANCE = Vector_PointDistance
local VEC_UNIT_DIRECTIONAL = Vector_UnitDirectionalPointToPoint
local ACTIVITY_TYPE = ACTIVITY_TYPE
local HANDLE_AUTOCAST_GENERIC = AbilityLogic_HandleAutocastGeneric
local AOHK = AbilityLogic_AllowOneHitKill
local ANY_HARM = FightClimate_AnyIntentToHarm
local CURRENT_ACTIVITY_TYPE = Blueprint_GetCurrentTaskActivityType
local TASK_OBJECTIVE = Task_GetTaskObjective
local HEALTH_PERCENT = Unit_GetHealthPercent
local SET_ENEMY_HERO = SET_ENEMY_HERO
local ABILITY_LOCKED = UseAbility_IsPlayerLocked
local CROWDED_RATING = Set_GetCrowdedRatingToSetTypeAtLocation
local HANDLE_AUTOCAST_GENERIC = AbilityLogic_HandleAutocastGeneric
local NEARBY_OUTER = Set_GetEnemyHeroesInPlayerRadiusAndOuter
local NEARBY_ENEMY = Set_GetEnemyHeroesInPlayerRadius
local HIGH_USE = AbilityLogic_HighUseAllowOffensive
local SPELL_SUCCESS = AbilityLogic_CastOnTargetWillSucceed
local DETECT_NEUTRALS_ABILITY = AbilityLogic_DetectValidNeutralsAbilityUse
local max = math.max
local min = math.min
local sqrt = math.sqrt

local fight_harass_handle = FightHarass_GetTaskHandle()

local ANCIENT_DEVOUR_TALENT_SLOT = 9

local t_player_abilities = {}

local next_score_dooming = 0

local d
d = {
	["SetBetterDevourAuto"] = function(gsiPlayer, devour, creepToEat)
		-- TODO
		local takeNewAbilities = true
		if takeNewAbilities then
			if not devour:GetAutoCastState() then
				devour:ToggleAutoCast()
			end
		elseif devour:GetAutoCastState() then
			devour:ToggleAutoCast()
		end
	end,
	["GetBestDevourCreep"] = function(creeps, difficultyLimit, maxCreepLevel)
		local bestCreep
		local bestCreepHealth = 0
		--print("Doom find best devour", #creeps, difficultyLimit, maxCreepLevel)
		for i=1,#creeps do
			local thisCreep = creeps[i]
			--print("creep", i, thisCreep, thisCreep:GetLevel(), maxCreepLevel)
			if thisCreep:GetLevel() <= maxCreepLevel
					and (difficultyLimit == SPAWNER_TYPE["ancient"]
							or not thisCreep:IsAncientCreep()
						) then
				local thisMaxHealth = thisCreep:GetMaxHealth()
				--print(thisMaxHealth)
				if thisMaxHealth > bestCreepHealth then
					bestCreep = thisCreep
					bestCreepHealth = thisMaxHealth
				end
			end
		end
		return bestCreep
	end,
	["devour_max_level"] = {[0] = 6, 4, 5, 6, 6},
	["ReponseNeeds"] = function()
		return nil, REASPONSE_TYPE_DISPEL, nil, {RESPONSE_TYPE_KNOCKBACK, 4}
	end,
	["Initialize"] = function(gsiPlayer)
		AbilityLogic_CreatePlayerAbilitiesIndex(t_player_abilities, gsiPlayer, abilities)
		AbilityLogic_UpdateHighUseMana(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam])
		gsiPlayer.InformLevelUpSuccess = d.InformLevelUpSuccess
	end,
	["InformLevelUpSuccess"] = function(gsiPlayer)
		AbilityLogic_UpdateHighUseMana(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam])
		AbilityLogic_UpdatePlayerAbilitiesIndex(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam], abilities)
	end,
	["AbilityThink"] = function(gsiPlayer) 
		local isLocked, isCombo = UseAbility_IsPlayerLocked(gsiPlayer)
		if isCombo then
			return;
		end
		local playerAbilities = t_player_abilities[gsiPlayer.nOnTeam]
		local devour = playerAbilities[1]
		local scorchedEarth = playerAbilities[2]
		local lvlDeath = playerAbilities[3] -- named retrospectively for my favourite ability, (...chicken fire spirits, magnetize and tether)
		local doom = playerAbilities[4]
		local acquired1 = gsiPlayer.hUnit:GetAbilityInSlot(3)
		local acquired2 = gsiPlayer.hUnit:GetAbilityInSlot(4)

		local highUse = gsiPlayer.highUseManaSimple * (aquired1 and 0.75 or 1)
		local currentTask = CURRENT_TASK(gsiPlayer)
		local currentActivityType = CURRENT_ACTIVITY_TYPE(gsiPlayer)
		local fht = TASK_OBJECTIVE(gsiPlayer, fight_harass_handle)
		local fhtReal = fht and fht.hUnit.IsNull and not fht.hUnit:IsNull()
		local fhtHUnit = fhtReal and fht.hUnit
		local fhtHpp = fht and fht.lastSeenHealth / fht.maxHealth
		local fhtLoc = fht and fht.lastSeen.location

		local playerHUnit = gsiPlayer.hUnit
		local playerLoc = gsiPlayer.lastSeen.location
		local playerHpp = HEALTH_PERCENT(gsiPlayer)

		local distToFht = fht and VEC_POINT_DISTANCE(playerLoc, fhtLoc)

		local nearbyEnemies, outerEnemies = NEARBY_OUTER(playerLoc, scorchedEarth:GetCastRange()*1.33,
				1200, 2
			)

		local danger = Analytics_GetTheoreticalDangerAmount(gsiPlayer)

		local arbitraryEnemy = nearbyEnemies[1] or outerEnemies[1]

		HANDLE_AUTOCAST_GENERIC(gsiPlayer, lvlDeath)

		if CAN_BE_CAST(gsiPlayer, devour) and not isLocked then
			local difficultyLimit = playerHUnit:GetAbilityInSlot(ANCIENT_DEVOUR_TALENT_SLOT)
			difficultyLimit = difficultyLimit and difficultyLimit:IsTrained()
					and SPAWNER_TYPE["ancient"] or SPAWNER_TYPE["large"] or false
			local spawnerLoc, availability, creeps = FarmJungle_GetNearestUncertainUncleared(
					gsiPlayer,
					difficultyLimit
				)
			if spawnerLoc then
				USE_ABILITY(gsiPlayer, function()
							if not CAN_BE_CAST(gsiPlayer, devour) then return true end
							playerLoc = gsiPlayer.lastSeen.location
							spawnerLoc, availability, creeps = FarmJungle_GetNearestUncertainUncleared(
									gsiPlayer,
									difficultyLimit
								)
							--DebugDrawLine(playerLoc, spawnerLoc, 255, 255, 255)
							--print("diffic", difficultyLimit, spawnerLoc, playerLoc, creeps, creeps[1])
							if spawnerLoc then
								playerHUnit:Action_MoveDirectly(spawnerLoc)
							end
							if not spawnerLoc or VEC_POINT_DISTANCE(playerLoc, spawnerLoc) > 2000 then
								local nearbyCreeps = playerHUnit:GetNearbyNeutralCreeps(600)
								for i=1,#nearbyCreeps do
									if string.find(nearbyCreeps[i]:GetUnitName(), "_ranged")
											or string.find(nearbyCreeps[i]:GetUnitName(), "_siege") then
										playerHUnit:Action_UseAbiltyOnEntity(nearbyCreeps[i])
										break;
									end
								end
								danger = Analytics_GetTheoreticalDangerAmount(
										gsiPlayer
									)
								return false, -danger*10;
							end
							if creeps and creeps[1] then
								playerLoc = gsiPlayer.lastSeen.location
								local bestCreep = d.GetBestDevourCreep(creeps, difficultyLimit,
										d.devour_max_level[devour:GetLevel()])
								if bestCreep then
									danger = Analytics_GetTheoreticalDangerAmount(
											gsiPlayer
										)
									return 1, 60
											- 2*Xeta_CostOfTravelToLocation(gsiPlayer, spawnerLoc)
													/ (1 + 2^(-danger))
								else
									difficultyLimit = max(1, difficultyLimit - 1)
								end
							end
							return false
						end,
						nil, 60 - Xeta_CostOfTravelToLocation(gsiPlayer, spawnerLoc), "DOOM_BRINGER_DEVOUR",
						nil, nil, 20
					)
				USE_ABILITY(gsiPlayer, function()
							if not CAN_BE_CAST(gsiPlayer, devour) then return true end
							spawnerLoc, availability, creeps = FarmJungle_GetNearestUncertainUncleared(
									gsiPlayer,
									difficultyLimit
								)
							local bestCreep = d.GetBestDevourCreep(creeps, difficultyLimit,
									d.devour_max_level[devour:GetLevel()])
							if bestCreep then
								--print("Using devour on creep")
								gsiPlayer.hUnit:Action_UseAbilityOnEntity(devour, bestCreep)
							else
								return true
							end
						end,
						nil, 500, "DOOM_BRINGER_DEVOUR", nil, nil, 22
					)
			end
		end
		if CAN_BE_CAST(gsiPlayer, scorchedEarth) then
			if fht and currentActivityType == ACTIVITY_TYPE.CONTROLLED_AGGRESSION
					and HIGH_USE(gsiPlayer, scorchedEarth, highUse, fhtHpp)
					and VEC_POINT_DISTANCE(playerLoc, fhtLoc) < 600
							+ max(0, (fht.currentMovementSpeed - gsiPlayer.currentMovementSpeed)*5)
					or currentActivityType == ACTIVITY_TYPE.FEAR
					and HIGH_USE(gsiPlayer, scorchedEarth, highUse, playerHpp) then
				USE_ABILITY(gsiPlayer, scorchedEarth, nil, 500, nil, nil, true)
				return;
			end
		end
		--print("DOOM")
		if CAN_BE_CAST(gsiPlayer, doom) and nearbyEnemies[1] then
			local bestScore = 0
			local bestTarget
			local bestDistance
			local doomCastRange = doom:GetCastRange()
			local dangerFactor = 1/(1+2^(-danger))
			for i=1,#nearbyEnemies do
				local thisEnemy = nearbyEnemies[i]
				local distToEnemy = VEC_POINT_DISTANCE(playerLoc, thisEnemy.lastSeen.location)
				local distanceDanger = max(0, (distToEnemy
						- doomCastRange)) * dangerFactor
				local thisScore = sqrt(thisEnemy.lastSeenHealth/thisEnemy.maxHealth)
							* thisEnemy.lastSeenMana
							* Analytics_GetPowerLevel(thisEnemy)
							* (not thisEnemy.hUnit:IsNull() and thisEnemy.hUnit:IsStunned()
									and 0.35 or 1
								)
						- distanceDanger
				if thisScore > bestScore then
					bestScore = thisScore
					bestTarget = thisEnemy
					bestDistance = distToEnemy
				end
			end
			if bestTarget and bestDistance < doom:GetCastRange()*1.1
					and HIGH_USE(gsiPlayer, doom, highUse,
							 bestTarget.lastSeenHealth / bestTarget.maxHealth
								- (#nearbyEnemies+#outerEnemies)/10
						) then
				USE_ABILITY(gsiPlayer, doom, bestTarget, 500, nil, nil, true)
				return;
			end
		end
		
		if acquired1 then
			
			local neutralsTarget = DETECT_NEUTRALS_ABILITY(gsiPlayer, acquired1)
			
			if neutralsTarget and HIGH_USE(gsiPlayer, acquired1, highUse*1.5, playerHpp) then
				USE_ABILITY(gsiPlayer, acquired1,
						neutralsTarget ~= true and neutralsTarget or nil, 400, nil, nil, true)
				return;
			end
		end
		
		if acquired2 then
			local neutralsTarget = DETECT_NEUTRALS_ABILITY(gsiPlayer, acquired2)
			if neutralsTarget and HIGH_USE(gsiPlayer, acquired1, highUse*1.5, playerHpp) then
				USE_ABILITY(gsiPlayer, acquired1,
						neutralsTarget ~= true and neutralsTarget or nil, 400, nil, nil, true)
				return;
			end
		end
	end,
}

local hero_access = function(key) return d[key] end

do
	HeroData_SetHeroData(hero_data, abilities, hero_access)
end
