local hero_data = {
	"zuus",
	{1, 3, 1, 2, 1, 5, 1, 2, 2, 2, 6, 5, 3, 3, 8, 3, 5, 10, 12, 13},
	{
		"item_tango","item_enchanted_mango","item_faerie_fire","item_branches","item_ward_observer","item_branches","item_bottle","item_ring_of_basilius","item_magic_wand","item_boots","item_veil_of_discord","item_arcane_boots","item_staff_of_wizardry","item_aether_lens","item_kaya","item_ghost","item_ethereal_blade","item_point_booster","item_staff_of_wizardry","item_ogre_axe","item_blade_of_alacrity","item_ultimate_scepter","item_ogre_axe","item_black_king_bar","item_cornucopia","item_cornucopia","item_refresher","item_dagon_2","item_dagon_3","item_dagon_4","item_dagon_5","item_octarine_core","item_aghanims_shard","item_ultimate_scepter_2","item_sheepstick",
	},
	{ {2,2,2,2,2,}, {2,2,2,2,2,}, 0.1 },
	{
		"Arc Lightning","Lightning Bolt","Heavenly Jump","Lightning Hands","Thundergod's Wrath","-4s Heavenly Jump Cooldown","+250 Health","+30 Movement Speed after Heavenly Jump","+1 Heavenly Jump Target","+6% Arc Lightning Current Health As Damage","+0.5s Lightning Bolt Ministun","325 AOE Lightning Bolt","+150 Thundergod's Wrath Flat Damage",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"zuus_arc_lightning", ABILITY_TYPE.NUKE + ABILITY_TYPE.AOE},
		{"zuus_lightning_bolt", ABILITY_TYPE.NUKE + ABILITY_TYPE.STUN},
		{"zuus_heavenly_jump", ABILITY_TYPE.PASSIVE},
		{"zuus_cloud", ABILITY_TYPE.SMITE + ABILITY_TYPE.STUN + ABILITY_TYPE.NUKE + ABILITY_TYPE.AOE},
		{"zuus_lightning_hands", ABILITY_TYPE.MOBILITY + ABILITY_TYPE.SLOW},
		[5] = {"zuus_thundergods_wrath", ABILITY_TYPE.NUKE + ABILITY_TYPE.SMITE},
}

local ZEROED_VECTOR = ZEROED_VECTOR
local playerRadius = Set_GetEnemyHeroesInPlayerRadius
local ENCASED_IN_RECT = Set_GetEnemiesInRectangle
local CURRENT_TASK = Task_GetCurrentTaskHandle
local CAN_BE_CAST = AbilityLogic_AbilityCanBeCast
local USE_ABILITY = UseAbility_RegisterAbilityUseAndLockToScore
local VEC_UNIT_DIRECTIONAL = Vector_UnitDirectionalPointToPoint
local ACTIVITY_TYPE = ACTIVITY_TYPE
local HANDLE_AUTOCAST_GENERIC = AbilityLogic_HandleAutocastGeneric
local CURRENT_ACTIVITY_TYPE = Blueprint_GetCurrentTaskActivityType
local TASK_OBJECTIVE = Task_GetTaskObjective
local HEALTH_PERCENT = Unit_GetHealthPercent
local SET_ENEMY_HERO = SET_ENEMY_HERO
local ABILITY_LOCKED = UseAbility_IsPlayerLocked
local CROWDED_RATING = Set_GetCrowdedRatingToSetTypeAtLocation
local NEARBY_OUTER = Set_GetEnemyHeroesInPlayerRadiusAndOuter
local NEARBY_ENEMY = Set_GetEnemyHeroesInPlayerRadius
local POINT_DISTANCE = Vector_PointDistance
local HIGH_USE = AbilityLogic_HighUseAllowOffensive
local SPELL_SUCCESS = AbilityLogic_CastOnTargetWillSucceed

local fight_harass_handle = FightHarass_GetTaskHandle()
local push_handle = Push_GetTaskHandle()
local search_fog_handle = SearchFog_GetTaskHandle()

local t_player_abilities = {}

local ABILITY_USE_RANGE = 850
local OUTER_RANGE = 1600

local ARC_JUMP_DIST = 490
local LB_ACQUISITION_RANGE = 325

local fight_harass_handle = FightHarass_GetTaskHandle()
local push_handle = Push_GetTaskHandle()

local t_enemy_players

local d
d = {
	["heavenly_jump_jump_dist"] = {700, 700, 800, 900, 1000},
	["ReponseNeeds"] = function()
		return nil, REASPONSE_TYPE_DISPEL, nil, {RESPONSE_TYPE_KNOCKBACK, 4}
	end,
	["Initialize"] = function(gsiPlayer)
		AbilityLogic_CreatePlayerAbilitiesIndex(t_player_abilities, gsiPlayer, abilities)
		AbilityLogic_UpdateHighUseMana(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam])
		t_enemy_players = GSI_GetTeamPlayers(ENEMY_TEAM)
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
		local arc = playerAbilities[1]
		local bolt = playerAbilities[2]
		local mamaMia = playerAbilities[3]
		local cloud = playerAbilities[4]
		local static = playerAbilities[5]
		local smite = playerAbilities[6]

		--[[print("ZUUS STUFF")
		print(""..cloud:GetName())
		print(""..mamaMia:GetName())
		--]]
		local highUse = gsiPlayer.highUseManaSimple
		local playerHpp = gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth
		local playerLoc = gsiPlayer.lastSeen.location

		local hUnitPlayer = gsiPlayer.hUnit

		local currActivityType = CURRENT_ACTIVITY_TYPE(gsiPlayer)
		local currTask = CURRENT_TASK(gsiPlayer)
		local nearbyEnemies, outerEnemies
				= NEARBY_OUTER(gsiPlayer.lastSeen.location, ABILITY_USE_RANGE, OUTER_RANGE, 6)
		local fht = TASK_OBJECTIVE(gsiPlayer, fight_harass_handle)
		local fhtReal = fht
				and fht.hUnit.IsNull and not fht.hUnit:IsNull()
		local fhtPercHp = fht
				and fht.lastSeenHealth / fht.maxHealth or 1.0
		local fhtMagicRes = fhtReal
				and SPELL_SUCCESS(gsiPlayer, fht, arc) or 0 
		local fhtLoc = fhtReal and fht.lastSeen.location

		if currActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION and fhtReal and fhtMagicRes > 0.33 then
			--local boltCastRange = bolt:GetSpecialValueInt("abilitycastrange")
			local boltCastRange = bolt:GetCastRange()
			--print("zuus", boltCastRange, CAN_BE_CAST(gsiPlayer, bolt))
			if CAN_BE_CAST(gsiPlayer, bolt)
					and Math_PointToPointDistance2D(playerLoc, fhtLoc)
						< boltCastRange + LB_ACQUISITION_RANGE*0.66
					and HIGH_USE(gsiPlayer, bolt, highUse - bolt:GetManaCost(), fhtPercHp) then
				local castLoc =
						Math_PointToPointDistance2D(playerLoc, fhtLoc) < boltCastRange
						and fhtLoc
						or Vector_ScalePointToPointByFactor(playerLoc, fhtLoc, 1, boltCastRange)
				USE_ABILITY(gsiPlayer, bolt, castLoc, 400, nil, nil, nil, nil, gsiPlayer.hUnit.Action_UseAbilityOnLocation)
				return;
			end
			if CAN_BE_CAST(gsiPlayer, arc) and not hUnitPlayer:GetAttackTarget()
					and HIGH_USE(gsiPlayer, arc, highUse - arc:GetManaCost(), fhtPercHp) then
				--print("running arc")
				local creeps = Set_GetNearestEnemyCreepSetToLocation(gsiPlayer.lastSeen.location)
				creeps = creeps and creeps.units
				local chainTbl = Set_NumericalIndexUnion(nil, nearbyEnemies, outerEnemies, creeps)
				if chainTbl[1] then
					local chainSucceeds, chainingUnit = AbilityLogic_WillChainCastHit(gsiPlayer,
							fht, arc:GetCastRange(), chainTbl, arc:GetSpecialValueInt("jumps"),
							ARC_JUMP_DIST
						)
					if chainSucceeds then
						USE_ABILITY(gsiPlayer, arc, chainingUnit, 400, nil)
						return;
					end
				end
			end
		elseif currActivityType >= ACTIVITY_TYPE.FEAR then
			local closestActive
			local closestDist = 0xFFFF
			for i=1,#nearbyEnemies do
				local thisEnemy = nearbyEnemies[i]
				if not Unit_IsNullOrDead(thisEnemy)
						and not (thisEnemy.hUnit:IsStunned() or thisEnemy.hUnit:IsRooted()) then
					local thisDist = POINT_DISTANCE(playerLoc, thisEnemy.lastSeen.location)
					if thisDist < closestDist then
						closestDist = thisDist
						closestActive = thisEnemy
					end
				end
			end
			if closestActive then
				if CAN_BE_CAST(gsiPlayer, cloud)
						and HIGH_USE(gsiPlayer, cloud, highUse, playerHpp) then
					USE_ABILITY(gsiPlayer, cloud,
							Vector_Addition(
									playerLoc,
									Vector_ScalarMultiply(
											Vector_UnitDirectionalFacingDirection(
													hUnitPlayer:GetFacing()
												),
											150
										)
								),
							400, nil
						)
					return;
				end
				if CAN_BE_CAST(gsiPlayer, mamaMia)
						and HIGH_USE(gsiPlayer, mamaMia, highUse, playerHpp)
						and hUnitPlayer:GetMovementDirectionStability() > 0.8 then
					USE_ABILITY(gsiPlayer, mamaMia, nil, 400, nil)
				end
				if CAN_BE_CAST(gsiPlayer, bolt)
						and HIGH_USE(gsiPlayer, bolt, highUse, playerHpp) then
					USE_ABILITY(gsiPlayer, bolt, closestActive.lastSeen.location, 400, nil,
							nil, nil, nil, Action_UseAbilityOnLocation
						)
					return;
				end
			end
		end
		local smiteFearEffect = 0
		local smiteDmg = smite:GetSpecialValueInt("damage")
		if CAN_BE_CAST(gsiPlayer, smite) then
			for i=1,#t_enemy_players do
				local thisEnemyPlayer = t_enemy_players[i]
				local mgkDmgMultiplier = SPELL_SUCCESS(gsiPlayer, thisEnemyPlayer, smite)
				if not pUnit_IsNullOrDead(thisEnemyPlayer)
						and mgkDmgMultiplier > 0.33 then
					local smiteDmgTaken = mgkDmgMultiplier*smiteDmg
					local thisEnemyHealth = thisEnemyPlayer.lastSeenHealth
					if not isSuperDeadAlready -- TODO stakes, registered incoming to enemy damage
							and smiteDmgTaken > thisEnemyHealth then
						USE_ABILITY(gsiPlayer, smite, nil, 400, nil)
						return;
					end
					if not enemyHeroFightStakesAreLow -- TODO stakes
							and thisEnemyPlayer.hUnit:TimeSinceDamagedByAnyHero() < 2 then
						local smiteDamage
						smiteFearEffect = smiteFearEffect
								+ 1.5 * (smiteDmgTaken / thisEnemyHealth)
									* (1-((thisEnemyHealth - smiteDmgTaken) / thisEnemyPlayer.maxHealth))
					end
				end
				if smiteFearEffect > 1 then
					INFO_print(string.format(
							"Zeus smiting to discourage aggression / turn fight. Fear effect: %.2f", smiteFearEffect
						) )
					USE_ABILITY(gsiPlayer, smite, nil, 400, nil)
					return;
				end
			end
		end
		if CAN_BE_CAST(gsiPlayer, arc) then
			local creeps = Set_GetNearestEnemyCreepSetToLocation(gsiPlayer.lastSeen.location)
			creeps = creeps and creeps.units
			if creeps and creeps[1] and gsiPlayer.time.data.theorizedDanger
					and gsiPlayer.time.data.theorizedDanger < -1.5 and currTask == push_handle
					and HIGH_USE(gsiPlayer, arc, highUse*3.5 - arc:GetManaCost(), 1 - playerHpp) then
				local nearestCreep = Set_GetSetUnitNearestToLocation(playerLoc, creeps)
				if Vector_PointDistance2D(gsiPlayer.lastSeen.location, nearestCreep.lastSeen.location)
						< arc:GetCastRange() * 1.15 then
					USE_ABILITY(gsiPlayer, arc, nearestCreep, 400, nil)
					return;
				end
			end
		end
		if CAN_BE_CAST(gsiPlayer, cloud) then
			-- TODO
			for i=1,#t_enemy_players do
				thisEnemyPlayer = t_enemy_players[i]
				local hUnit = thisEnemyPlayer.hUnit
				if hUnit and not hUnit:IsNull() and hUnit:IsAlive()
						and thisEnemyPlayer.lastSeenHealth
								< 500
						and HIGH_USE(gsiPlayer, cloud, highUse - cloud:GetManaCost(),
								thisEnemyPlayer.lastSeenHealth / thisEnemyPlayer.maxHealth
							) then
					local extrapolated = hUnit:GetExtrapolatedLocation(1)
					USE_ABILITY(gsiPlayer, cloud, extrapolated, 400, nil)
					return;
				end
			end
		end
		if CAN_BE_CAST(gsiPlayer, bolt) and not currTask == fight_harass_handle 
				and HIGH_USE(gsiPlayer, bolt, highUse, 0) then
			local bez = SearchFog_GetNearbyBezier(gsiPlayer.lastSeen.location, bolt:GetCastRange())
			
			if bez then
				for i=1,#bez do
					
					local bezi = bez[i]
					if bezi and bezi.val and POINT_DISTANCE(playerLoc, bezi.val)
								< bolt:GetCastRange() then
						USE_ABILITY(gsiPlayer, bolt, bezi.val, 400, nil)
						return;
					end
				end
			end
		end
	end,
}

local hero_access = function(key) return d[key] end

do
	HeroData_SetHeroData(hero_data, abilities, hero_access)
end
