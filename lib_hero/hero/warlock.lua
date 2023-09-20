local hero_data = {
	"warlock",
	{1, 3, 1, 3, 3, 4, 3, 1, 1, 5, 2, 4, 2, 2, 7, 2, 4, 9, 11},
	{
		"item_ward_sentry","item_ward_sentry","item_faerie_fire","item_blood_grenade","item_branches","item_branches","item_branches","item_tango","item_tango","item_magic_wand","item_boots","item_medallion_of_courage","item_wind_lace","item_solar_crest","item_ancient_janggo","item_aghanims_shard","item_tranquil_boots","item_boots_of_bearing","item_fluffy_hat","item_force_staff","item_gem","item_cornucopia","item_refresher","item_staff_of_wizardry","item_ogre_axe","item_blade_of_alacrity","item_ultimate_scepter",
	},
	{ {1,1,1,1,1,}, {5,5,5,5,5,}, 0.1 },
	{
		"Fatal Bonds","Shadow Word","Upheaval","Chaotic Offering","+4% Fatal Bonds Damage","+75 Upheaval Radius","+12 Upheaval Attack Speed per second on Allies","+18 Shadow Word Heal/Damage","Summons a Golem on death","450 Shadow Word AoE","+20 Chaotic Offering Golems Armor","80% Magic Resistance for Chaotic Offering Golems",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
	[0] = {"warlock_fatal_bonds", ABILITY_TYPE.DEGEN + ABILITY_TYPE.AOE + ABILITY_TYPE.NUKE},
		{"warlock_shadow_word", ABILITY_TYPE.NUKE + ABILITY_TYPE.HEAL},
		{"warlock_upheaval", ABILITY_TYPE.SLOW + ABILITY_TYPE.AOE},
		[5] = {"warlock_rain_of_chaos", ABILITY_TYPE.STUN + ABILITY_TYPE.NUKE + ABILITY_TYPE.SUMMON + ABILITY_TYPE.AOE},
}

local FATAL_BONDS_CHAIN_DIST = 700

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
local HIGH_USE = AbilityLogic_HighUseAllowOffensive
local SPELL_SUCCESS = AbilityLogic_CastOnTargetWillSucceed

local fight_harass_handle = FightHarass_GetTaskHandle()

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
		if ABILITY_LOCKED(gsiPlayer) then
			return;
		end
		local thisPlayerAbilities = t_player_abilities[gsiPlayer.nOnTeam]
		local fatalBonds = thisPlayerAbilities[1]
		local shadowWord = thisPlayerAbilities[2]
		local upheaval = thisPlayerAbilities[3]
		local rainOfChaos = thisPlayerAbilities[4]

		local highUse = gsiPlayer.highUseManaSimple
		local currentTask = CURRENT_TASK(gsiPlayer)
		local currentActivityType = CURRENT_ACTIVITY_TYPE(gsiPlayer)
		local fht = TASK_OBJECTIVE(gsiPlayer, fight_harass_handle)
		local fhtReal = fht and fht.hUnit.IsNull and not fht.hUnit:IsNull()
		local fhtHpp = fht and HEALTH_PERCENT(fht)

		local playerLoc = gsiPlayer.lastSeen.location
		local fhtLoc = fhtReal and fht.lastSeen.location

		local nearbyEnemies, outerEnemies = NEARBY_OUTER(gsiPlayer.lastSeen.location, 1100, 1600)
		local nearbyAllies = Set_GetAlliedHeroesInPlayerRadius(gsiPlayer, 900)

		--print("WARLOCK RUNNING")
		if fhtReal and currentActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION--[[ TODO or you are in a fear mode and (should be able to escape, or are definitely dead) and with active outgoing team damage / fight activity... --]] then
			--print("aggressive warlock")
			--print(#nearbyEnemies, fhtReal)
			if fhtReal and CAN_BE_CAST(gsiPlayer, fatalBonds) then
				--print("fatalBonds can cast", fatalBonds:GetCastRange())
				local fatalBondsCastRange = fatalBonds:GetCastRange()

				local creeps, creepSetDist = Set_GetNearestEnemyCreepSetToLocation(fhtLoc)
				creeps = creeps and creeps.units
				local utilizationOfBonds =
						(creeps and fatalBondsCastRange*1.5 > creepSetDist and #creeps or 0) + #nearbyEnemies*2
				--print(#creeps, #nearbyEnemies, creepSetDist, utilizationOfBonds)
				if nearbyEnemies[1]
							and utilizationOfBonds > 3 then
					--print("running fatal bonds")
					local chainTbl = creeps and creeps[1]
							and Set_NumericalIndexUnion(creeps, nearbyEnemies) or nearbyEnemies

					local chainSucceeds, chainingUnit = AbilityLogic_WillChainCastHit(gsiPlayer,
							fht, fatalBonds:GetCastRange(),
							chainTbl, fatalBonds:GetSpecialValueInt("count"), FATAL_BONDS_CHAIN_DIST,
							0, true
						)
				--	local t = RealTime()
				--	for i=1,5000 do
				--		AbilityLogic_WillChainCastHit(gsiPlayer,
				--			fht, fatalBonds:GetCastRange(),
				--			chainTbl, fatalBonds:GetSpecialValueInt("count"), FATAL_BONDS_CHAIN_DIST,
				--			0, true
				--		)
				--  end
				--	local timeTaken = RealTime() - t
				--	totalTimeTaken = (0 or totalTimeTaken) + timeTaken
				--	runs = (0 or runs) + 1
				--	print(timeTaken, "avg", totalTimeTaken / runs,"total", totalTimeTaken, "info:", #creeps, #nearbyEnemies, #chainTbl, runs, "WillChainCastHit #########################################################")
					if chainSucceeds
							and HIGH_USE(gsiPlayer, fatalBonds,
								highUse - (fatalBonds:GetManaCost() / utilizationOfBonds), fhtHpp
							) then
						USE_ABILITY(gsiPlayer, fatalBonds, chainingUnit, 400, nil)
						return;
					end
				end
			end
			if fhtReal and CAN_BE_CAST(gsiPlayer, rainOfChaos) then
				local crowdedCenter, crowdedRating = CROWDED_RATING(gsiPlayer.lastSeen.location, SET_HERO_ENEMY)
				if HIGH_USE(gsiPlayer, rainOfChaos, highUse - rainOfChaos:GetManaCost(), fhtHpp) then
					-- TODO TODO TODO Need a 'stakes' analysis to query start of team-fights for good stuns;
					-- - If in an even match-up with long fights, smarter ability use is better; if in a
					-- - dire situation, saving may be the better idea, i.e. don't feed golem.
					local stunnedUnits = NEARBY_ENEMY(gsiPlayer, rainOfChaos:GetSpecialValueInt("aoe"))
					if #stunnedUnits > 0 then
						USE_ABILITY(gsiPlayer, rainOfChaos, crowdedCenter, 400, nil)
						return;
					end
				end
			end
		end
		-- TODO Improve
		if CAN_BE_CAST(gsiPlayer, shadowWord) then	
			local lowestHealthUnit, lowestHealthPercent = Unit_LowestHealthPercentPlayer(nearbyEnemies, nearbyAllies)
			local shadowWordDuration = shadowWord:GetSpecialValueFloat("duration")
			local shadowWordDamage = shadowWord:GetSpecialValueFloat("damage")
			--print(shadowWordDuration, shadowWordDamage)
			if lowestHealthUnit
					and (
							lowestHealthUnit.team == ENEMY_TEAM
							or shadowWordDamage*shadowWordDuration*0.85
								< (lowestHealthUnit.maxHealth - lowestHealthUnit.lastSeenHealth)
					) and HIGH_USE(gsiPlayer, shadowWord, highUse*2 - shadowWord:GetManaCost(), lowestHealthPercent)
					and Math_PointToPointDistance2D(playerLoc, lowestHealthUnit.lastSeen.location)
					and not Unit_IsNullOrDead(lowestHealthUnit) then
				USE_ABILITY(gsiPlayer, shadowWord, lowestHealthUnit, 400, nil, nil, nil, nil,
						gsiPlayer.hUnit.Action_UseAbilityOnEntity
					)
				return
			end
		end
		if CAN_BE_CAST(gsiPlayer, rainOfChaos) then
			for i=1,#nearbyAllies do
				if CURRENT_TASK(nearbyAllies[i]) == fight_harass_handle then
					local crowdedCenter, crowdedRating = CROWDED_RATING(gsiPlayer.lastSeen.location, SET_HERO_ENEMY)
					if HIGH_USE(gsiPlayer, rainOfChaos, highUse - rainOfChaos:GetManaCost(), fhtHpp or 1.0) then
						-- TODO TODO TODO Need a 'stakes' analysis to query start of team-fights for good stuns;
						-- - If in an even match-up with long fights, smarter ability use is better; if in a
						-- - dire situation, saving may be the better idea, i.e. don't feed golem.
						local stunnedUnits = NEARBY_ENEMY(gsiPlayer, rainOfChaos:GetSpecialValueInt("aoe"))
						if #stunnedUnits > 0 then
							USE_ABILITY(gsiPlayer, rainOfChaos, crowdedCenter, 400, nil)
							return;
						end
					end
				end
			end
		end
				--[[
				local fhtMgkDmgFactor = SPELL_SUCCESS(gsiPlayer, fht, )
				if fhtMkgDmgFactor > 0 and HIGH_USE(gsiPlayer, nethertoxin, highUse - nethertoxin:GetManaCost(),
							fhtHpp + fhtHpp*(0.75 - fhtMgkDmgFactor))
						and Math_PointToPointDistance2D(playerLoc, fhtLoc)
								< nethertoxin:GetCastRange()-50 then
					local moveStability = fht.hUnit:GetMovementDirectionStability()
					if moveStability < 0.1 or moveStability > 0.75 then
						local predictedLoc = fht.hUnit:GetExtrapolatedLocation(0.75)
						-- TODO Break consideration; implement better per-enemy-hero determinations
						USE_ABILITY(gsiPlayer, nethertoxin, predictedLoc, 400, nil)
						return;
					end
				end
			end
			if fhtReal and CAN_BE_CAST(gsiPlayer, viperStrike) then
				local viperStrikeDamage = viperStrike:GetSpecialValueFloat("damage")
						* viperStrike:GetSpecialValueInt("duration")
				local afterVsHpp = (fht.lastSeenHealth - viperStrikeDamage) / fht.maxHealth
				print("viper strike dmg", viperStrikeDamage)
				if Math_PointToPointDistance2D(playerLoc, fhtLoc) < gsiPlayer.attackRange+50
						and HIGH_USE(gsiPlayer, viperStrike, highUse - viperStrike:GetManaCost(), fhtHpp)
						and afterVsHpp > 0.0 and afterVsHpp < 0.75 then
					USE_ABILITY(gsiPlayer, viperStrike, fht, 400, nil)
					return;
				end
			end
		elseif currentActivityType > ACTIVITY_TYPE.CAREFUL then

		end
		--]]
	end,
}

local hero_access = function(key) return d[key] end

do
	HeroData_SetHeroData(hero_data, abilities, hero_access)
end
