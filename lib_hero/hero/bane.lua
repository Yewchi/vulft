local hero_data = {
	"bane",
	{2, 3, 2, 3, 2, 4, 2, 3, 3, 1, 1, 4, 1, 1, 7, 5, 4, 9},
	{
		"item_ward_observer","item_branches","item_faerie_fire","item_branches","item_enchanted_mango","item_tango","item_ward_sentry","item_boots","item_bottle","item_boots","item_arcane_boots","item_magic_wand","item_point_booster","item_ogre_axe","item_staff_of_wizardry","item_ultimate_scepter","item_aghanims_shard","item_blink","item_aether_lens",
	},
	{ {1,1,2,3,3,}, {5,5,2,4,4,}, 0.1 },
	{
		"Enfeeble","Brain Sap","Nightmare","Fiend's Grip","Nightmare Damage Heals Bane","+20% Enfeeble Cast Range Reduction","-3s Brain Sap Cooldown","+5% Fiend's Grip Max Mana Drain","-3s Nightmare Cooldown","+30 Movement Speed","+200 Brain Sap Damage/Heal","+5s Fiend's Grip Duration",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"bane_enfeeble", ABILITY_TYPE.DEGEN + ABILITY_TYPE.AOE + ABILITY_TYPE.UNIT_TARGET},
		{"bane_brain_sap", ABILITY_TYPE.NUKE + ABILITY_TYPE.HEAL + ABILITY_TYPE.UNIT_TARGET},
		{"bane_nightmare", ABILITY_TYPE.ROOT + ABILITY_TYPE.DEGEN + ABILITY_TYPE.UNIT_TARGET},
		{"bane_nightmare_end", ABILITY_TYPE.SECONDARY},
		[5] = {"bane_fiends_grip", ABILITY_TYPE.STUN + ABILITY_TYPE.NUKE + ABILITY_TYPE.UNIT_TARGET},
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
local max = math.max
local min = math.min
local sqrt = math.sqrt

local fight_harass_handle = FightHarass_GetTaskHandle()
local push_handle = Push_GetTaskHandle()

local t_player_abilities = {}

local d
d = {
	["ReponseNeeds"] = function()
		return nil, REASPONSE_TYPE_DISPEL, nil, {RESPONSE_TYPE_KNOCKBACK, 4}
	end,
	["Initialize"] = function(gsiPlayer)
		AbilityLogic_CreatePlayerAbilitiesIndex(t_player_abilities, gsiPlayer, abilities)
		AbilityLogic_UpdateHighUseMana(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam])
	end,
	["InformLevelUpSuccess"] = function(gsiPlayer)
		AbilityLogic_UpdateHighUseMana(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam])
	end,
	["AbilityThink"] = function(gsiPlayer) 
		if UseAbility_IsPlayerLocked(gsiPlayer) then
			local currActiveAbility = gsiPlayer.hUnit:GetCurrentActiveAbility()
			if currActiveAbility and currActiveAbility:GetName() == "bane_fiends_grip" then
				if Analytics_GetTotalDamageInTimeline(gsiPlayer.hUnit) > gsiPlayer.lastSeenHealth/4
						and gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth < 0.33 then
					UseAbility_ClearQueuedAbilities(gsiPlayer)
				end
			else
				
				return;
			end
		end
		local playerAbilities = t_player_abilities[gsiPlayer.nOnTeam]
		local enfeeble = playerAbilities[1]
		local brainSap = playerAbilities[2]
		local nightmare = playerAbilities[3]
		local nightmareEnd = playerAbilities[4]
		local grip = playerAbilities[5]

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

		local nearbyEnemies, outerEnemies = NEARBY_OUTER(playerLoc, brainSap:GetCastRange()*1.1,
				enfeeble:GetCastRange(), 2
			)

		local danger = Analytics_GetTheoreticalDangerAmount(gsiPlayer)

		local arbitraryEnemy = nearbyEnemies[1] or outerEnemies[1]
		if CAN_BE_CAST(gsiPlayer, brainSap) then
			local brainSapCastRange = brainSap:GetCastRange()*1.05
			if fhtReal and currentActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION
					and HIGH_USE(gsiPlayer, brainSap, highUse, fhtHpp) 
					and VEC_POINT_DISTANCE(playerLoc, fhtLoc) < brainSapCastRange then
				USE_ABILITY(gsiPlayer, brainSap, fht, 500, nil)
				return;
			elseif nearbyEnemies[1] and currentActivityType >= ACTIVITY_TYPE.FEAR then
				local inRangeLowest
				local inRangeLowestHpp = 1.1
				for i=1,#nearbyEnemies do
					local thisEnemy = nearbyEnemies[i]
					local thisHpp = thisEnemy.lastSeenHealth / thisEnemy.maxHealth
					if VEC_POINT_DISTANCE(playerLoc, thisEnemy.lastSeen.location)
									< brainSapCastRange
							and thisHpp < inRangeLowestHpp then
						inRangeLowestHpp = thisHpp
						inRangeLowest = thisEnemy
					end
				end
				if inRangeLowest and HIGH_USE(gsiPlayer, brainSap, highUse, inRangeLowestHpp) then
					USE_ABILITY(gsiPlayer, brainSap, inRangeLowest, 500, nil)
					return;
				end
			end
			if not arbitraryEnemy and currentTask == push_handle
					and HIGH_USE(gsiPlayer, brainSap, highUse*4, playerHpp) then
				local obj = TASK_OBJECTIVE(gsiPlayer, push_handle)
				if obj and obj.type == UNIT_TYPE_CREEP and danger < -0.5 and obj.lastSeenHealth > 200 then
					USE_ABILITY(gsiPlayer, brainSap, obj, 500, nil)
					return;
				end
			end
		end
		local multipleEnemies = #nearbyEnemies + #outerEnemies > 1
		if arbitraryEnemy and nightmare:GetName() == "bane_nightmare"
				and CAN_BE_CAST(gsiPlayer, nightmare) then
			--print("bane in 1")
			local nearby = NEARBY_ENEMY(gsiPlayer, nightmare:GetCastRange()*1.5)
			local saveFromUnit, saveUnit = FightClimate_GetIntentCageFightSaveJIT(
					gsiPlayer, nil, nearby, nightmare:GetCastRange(), true
				)
			if saveFromUnit then
				--print("bane in 3")
				local saveActivityType = CURRENT_ACTIVITY_TYPE(saveUnit)
				if saveActivityType >= ACTIVITY_TYPE.FEAR and HIGH_USE(
							gsiPlayer, nightmare, highUse,
							saveUnit.lastSeenHealth / saveUnit.maxHealth
						) then
					USE_ABILITY(gsiPlayer, nightmare, saveFromUnit, 500, nil)
					return;
				end
			end
			if multipleEnemies then
				--print("bane in 2")
				if currentActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION then
					--print("bane in 4")
					local inRangeHighestPower
					local inRangeHighestPowerAmount = 0
					for i=1,#nearby do
						local thisEnemy = nearby[i]
						local thisPower = Analytics_GetPowerLevel(thisEnemy)
						if thisPower > inRangeHighestPowerAmount then
							inRangeHighestPower = thisEnemy
							inRangeHighestPowerAmount = thisPower
						end
					end
					if inRangeHighestPower and HIGH_USE(gsiPlayer, nightmare, highUse,
								0.33
							) then
						USE_ABILITY(gsiPlayer, nightmare, inRangeHighestPower, 500, nil)
						return;
					end
				end
			else
				--TODO safety / solo kill
			end
		end
		if arbitraryEnemy and CAN_BE_CAST(gsiPlayer, enfeeble) then
		end
		if arbitraryEnemy and CAN_BE_CAST(gsiPlayer, grip)
				and (not multipleEnemies
						or not FightClimate_AnyIntentToHarm(gsiPlayer, nearbyEnemies)
					) then
			if fhtReal and currentActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION
					and HIGH_USE(gsiPlayer, grip, highUse, fhtHpp) then
				USE_ABILITY(gsiPlayer, grip, fht, 500, nil, nil, 6)
				return;
			end
			-- TODO strategic grip
		end
	end,
}

local hero_access = function(key) return d[key] end

do
	HeroData_SetHeroData(hero_data, abilities, hero_access)
end

