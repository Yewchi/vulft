local hero_data = {
	"abaddon",
	{2, 1, 1, 2, 2, 4, 2, 1, 1, 6, 3, 4, 3, 3, 7, 3, 4, 9, 12},
	{
		"item_blood_grenade","item_enchanted_mango","item_tango","item_branches","item_quelling_blade","item_branches","item_branches","item_boots","item_chainmail","item_phase_boots","item_magic_wand","item_robe","item_oblivion_staff","item_ogre_axe","item_echo_sabre","item_blitz_knuckles","item_broadsword","item_shadow_amulet","item_broadsword","item_invis_sword","item_blades_of_attack","item_silver_edge","item_belt_of_strength","item_basher","item_diadem","item_gem","item_lifesteal","item_harpoon","item_ultimate_orb","item_ultimate_orb","item_skadi","item_claymore","item_satanic",
	},
	{ {1,1,1,3,3,}, {5,5,4,1,3,}, 0.1 },
	{
		"Mist Coil","Aphotic Shield","Curse of Avernus","Borrowed Time","+15% Curse of Avernus Movement Slow","+7 Strength","+55 Damage","+40 Mist Coil Heal/Damage","+100 Aphotic Shield Barrier Amount","+400 DPS Borrowed Time Immolation","-1 Curse of Avernus Attacks Required","+400 AoE Mist Coil",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"abaddon_death_coil", ABILITY_TYPE.HEAL + ABILITY_TYPE.NUKE, 0},
		{"abaddon_aphotic_shield", ABILITY_TYPE.SHIELD, 0.2},
		{"abaddon_frostmourne", ABILITY_TYPE.PASSIVE, 0.1},
		[5] = {"abaddon_borrowed_time", ABILITY_TYPE.PASSIVE, 0.5},
}

local high_use

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
local NEARBY_OUTER = Set_GetEnemyHeroesInPlayerRadiusAndOuter
local NEARBY_ENEMY = Set_GetEnemyHeroesInPlayerRadius
local HIGH_USE = AbilityLogic_HighUseAllowOffensive
local SPELL_SUCCESS = AbilityLogic_CastOnTargetWillSucceed
local LOWEST_HPP_PLAYER = Unit_LowestHealthPercentPlayer
local SAVE_JIT = FightClimate_GetIntentCageFightSaveJIT

local max = math.max
local min = math.min

local push_handle = Push_GetTaskHandle()
local fight_harass_handle = FightHarass_GetTaskHandle()

local enemy_players = GSI_GetTeamPlayers(ENEMY_TEAM)

local t_player_abilities = {}

local d
d = {
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
		if UseAbility_IsPlayerLocked(gsiPlayer) then
			return;
		end
		--print("Aba high use", gsiPlayer.highUseManaSimple)
		local playerAbilities = t_player_abilities[gsiPlayer.nOnTeam]
		local mistCoil = playerAbilities[1]
		local aphoticShield = playerAbilities[2]
		local borrowedTime = playerAbilities[4]
		
		local mistCoilCastRange = mistCoil:GetCastRange()
		local aphoticShieldCastRange = aphoticShield:GetCastRange()

		local highUse = gsiPlayer.highUseManaSimple
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

		local nearbyEnemies, outerEnemies = NEARBY_OUTER(playerLoc, mistCoilCastRange*1.1,
				1300, 2
			)

		local fhtMgkDmgFactor = fhtReal and SPELL_SUCCESS(gsiPlayer, fht, mistCoil)

		local arbitraryEnemy = nearbyEnemies[1] or outerEnemies[1]

		local nearbyAllies = Set_GetAlliedHeroesInPlayerRadius(gsiPlayer, aphoticShieldCastRange*1.1, false)
		local lowestAllied, lowestAlliedHpp

		if CAN_BE_CAST(gsiPlayer, mistCoil) then
			local lowestEnemy, lowestEnemyHpp = LOWEST_HPP_PLAYER(nearbyEnemies)
			local allowSelfHurt = playerHpp > 0.5
					or not FightClimate_AnyIntentToHarm(gsiPlayer, enemy_players)
			--print(mistCoil:GetSpecialValueInt("damage"))
			if #nearbyEnemies + #outerEnemies <= 1 then
				-- If we kill a sole enemy with mist coil, secure kill instead of heal allied low
				if lowestEnemy 
						and HIGH_USE(gsiPlayer, mistCoil, highUse, lowestEnemyHpp) then
					USE_ABILITY(gsiPlayer, mistCoil, lowestEnemy, 500, nil)
					return;
				end
			end
			lowestAllied, lowestAlliedHpp = LOWEST_HPP_PLAYER(nearbyAllies)
			local enemyIsLower = lowestEnemyHpp < lowestAlliedHpp
			local lowestPlayer = enemyIsLower and lowestEnemy or lowestAllied
			local lowestPlayerHpp = enemyIsLower and lowestEnemyHpp or lowestAlliedHpp
			--print("ABA ABIL", lowestPlayer, lowestPlayerHpp, lowestEnemy, lowestAllied, lowestEnemyHpp, lowestAlliedHpp)

			if lowestPlayer and lowestPlayerHpp < 0.65
					and HIGH_USE(gsiPlayer, mistCoil, highUse, lowestPlayerHpp) then
				USE_ABILITY(gsiPlayer, mistCoil, lowestPlayer, 500, nil)
				return;
			end
		end
		if CAN_BE_CAST(gsiPlayer, aphoticShield) then
			nearbyEnemies = #nearbyEnemies > 1 and Set_NumericalIndexUnion(nil, nearbyEnemies,
					outerEnemies
				) or outerEnemies
			-- NB. nearbyEnemies set changed
			local _, saveUnit = SAVE_JIT(
				gsiPlayer, nil, nearbyEnemies, aphoticShield:GetCastRange(), true
			)
			if saveUnit and HIGH_USE(gsiPlayer, aphoticShield, highUse, 
							saveUnit.lastSeenHealth / saveUnit.maxHealth
					) then
				USE_ABILITY(gsiPlayer, aphoticShield, saveUnit, 500, nil)
				return;
			end
			if not lowestAlliedHpp then
				if not nearbyAllies[1] then
					lowestAllied, lowestAlliedHpp = gsiPlayer, playerHpp
				else
					lowestAllied, lowestAlliedHpp = LOWEST_HPP_PLAYER(nearbyAllies)
				end
			end
			if lowestAllied and arbitraryEnemy
					and HIGH_USE(gsiPlayer, aphoticShield, highUse, lowestAlliedHpp) then
				-- TODO spammy?
				USE_ABILITY(gsiPlayer, aphoticShield, lowestAllied, 500, nil)
				return;
			end
		end

	--		if currentActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION then
	--			if fhtReal and fhtMgkDmgFactor > 0
	--					and try_spirit_siphon_target(gsiPlayer, siphon, fht) then
	--				return;
	--			else
	--				for i=1,#nearbyEnemies do
	--					local thisEnemy = nearbyEnemies[i]
	--					if thisEnemy ~= fht and SPELL_SUCCESS(gsiPlayer, thisEnemy, siphon) > 0
	--							and try_spirit_siphon_target(gsiPlayer, siphon, thisEnemy) then
	--						return;
	--					end
	--				end
	--			end
	--		elseif arbitraryEnemy and currentActivityType >= ACTIVITY_TYPE.FEAR then
	--			for i=1,#nearbyEnemies do
	--				local thisEnemy = nearbyEnemies[i]
	--				if SPELL_SUCCESS(gsiPlayer, thisEnemy, siphon) > 0
	--						and try_spirit_siphon_target(gsiPlayer, siphon, thisEnemy) then
	--					return;
	--				end
	--			end
	--		end
	--	end
	--	if CAN_BE_CAST(gsiPlayer, cryptSwarm) then
	--		if fhtReal and currentActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION
	--				and fhtMgkDmgFactor > 0 then
	--			-- TODO
	--			local extrapolatedFht = fhtHUnit:GetExtrapolatedLocation(0.5)
	--			-- Loosely uses the extended range of the circle at the cast location, may miss
	--			if VEC_POINT_DISTANCE(playerLoc, extrapolatedFht) < CRYPT_SWARM_RANGE*0.9 then
	--				local crowdedCenter, crowdedRating = CROWDED_RATING(extrapolatedFht, SET_HERO_ENEMY)
	--				if crowdedRating > 1.5 then -- if / else, save it for more enemies, with bugs
	--					if VEC_POINT_DISTANCE(playerLoc, crowdedCenter) < CRYPT_SWARM_RANGE
	--							and HIGH_USE(gsiPlayer, cryptSwarm, highUse, fhtHpp/crowdedRating) then
	--						USE_ABILITY(gsiPlayer, cryptSwarm, crowdedCenter, 400, nil)
	--						return;
	--					end
	--				elseif HIGH_USE(gsiPlayer, cryptSwarm, highUse, fhtHpp) then
	--					USE_ABILITY(gsiPlayer, cryptSwarm, extrapolatedFht, 400, nil)
	--					return;
	--				end
	--			end
	--		end
	--		if currentTask == push_handle
	--				and Analytics_GetTheoreticalDangerAmount(gsiPlayer) < -2
	--				and HIGH_USE(gsiPlayer, cryptSwarm, highUse, playerHpp) then
	--			local nearbyCreepSet = Set_GetNearestEnemyCreepSetToLocation(playerLoc)
	--			if nearbyEnemyCreepSet and nearbyEnemyCreepSet.units[1] then
	--				local crowdedCenter, crowdedRating = CROWDED_RATING(nearbyEnemyCreepSet.center)
	--				if crowdedRating > 2 and VEC_POINT_DSTANCE(playerLoc, crowdedCenter) then
	--					USE_ABILITY(gsiPlayer, cryptSwarm, crowdedCenter, 400, nil)
	--					return;
	--				end
	--			end
	--		end
	--	end
	--	if CAN_BE_CAST(gsiPlayer, exorcism) then
	--		if (fhtReal and currentActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION
	--						and distToFht < 900
	--				) or (currentTask == push_handle and playerHUnit:GetAttackTarget()
	--						and playerHUnit:GetAttackTarget():IsBuilding()
	--				) then
	--			USE_ABILITY(gsiPlayer, exorcism, nil, 400, nil)
	--			return;
	--		end
	--	end
	end,
}

local hero_access = function(key) return d[key] end

do
	HeroData_SetHeroData(hero_data, abilities, hero_access)
end


