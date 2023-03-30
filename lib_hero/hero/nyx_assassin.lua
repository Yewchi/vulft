local hero_data = {
	"nyx_assassin",
	{1, 3, 1, 3, 1, 4, 1, 3, 3, 2, 2, 4, 2, 2, 7, 5, 4, 9, 11},
	{
		"item_tango","item_quelling_blade","item_branches","item_enchanted_mango","item_faerie_fire","item_branches","item_magic_wand","item_ring_of_health","item_pers","item_meteor_hammer","item_boots","item_arcane_boots","item_staff_of_wizardry","item_crown","item_dagon_5","item_aghanims_shard","item_dagon_2L","item_dagon_3L","item_dagon_4L","item_dagon_5L","item_ghost",
	},
	{ {3,3,3,3,3,}, {3,3,3,4,4,}, 0.1 },
	{
		"Impale","Mana Burn","Spiked Carapace","Vendetta","+8% Spell Amplification","+0.25s Impale Stun Duration","+0.5s Spiked Carapace Reflect Duration","+0.5x Mana Burn Intelligence Multiplier","+0.6s Spiked Carapace Stun Duration","+130 Impale Damage","+300 Mana Burn Radius","Vendetta Unobstructed Pathing",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"nyx_assassin_impale", ABILITY_TYPE.NUKE + ABILITY_TYPE.STUN},
		{"nyx_assassin_mana_burn", ABILITY_TYPE.NUKE + ABILITY_TYPE.DEGEN},
		{"nyx_assassin_spiked_carapace", ABILITY_TYPE.NUKE + ABILITY_TYPE.SHIELD},
		{"nyx_assassin_burrow", ABILITY_TYPE.SHIELD + ABILITY_TYPE.UTILITY},
		{"nyx_assassin_unburrow", ABILITY_TYPE.MOBILITY + ABILITY_TYPE.UTILITY},
		[5] = {"nyx_assassin_vendetta", ABILITY_TYPE.ATTACK_MODIFIER + ABILITY_TYPE.INVIS},
}

local ZEROED_VECTOR = ZEROED_VECTOR
local playerRadius = Set_GetEnemyHeroesInPlayerRadius
local ENCASED_IN_RECT = Set_GetEnemiesInRectangle
local CURRENT_TASK = Task_GetCurrentTaskHandle
local INCENTIVISE_TASK = Task_IncentiviseTask
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
local HIGH_USE = AbilityLogic_HighUseAllowOffensive
local SPELL_SUCCESS = AbilityLogic_CastOnTargetWillSucceed

local IMPALE_TRAVEL_SPEED = 1600
local IMPALE_CAST_POINT = 0.3

local max = math.max
local min = math.min
local abs = math.abs

local fight_harass_handle = FightHarass_GetTaskHandle()
local increase_safety_handle = IncreaseSafety_GetTaskHandle()
local avoid_hide_handle = AvoidHide_GetTaskHandle()
local leech_exp_handle = LeechExperience_GetTaskHandle()

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
	end,
	["impale_range"] = {[true] = 1225, [false] = 700},
	["ImpaleRange"] = function(isBurrowed) return d.impale_range[isBurrowed] end,
	["AbilityThink"] = function(gsiPlayer) 
		if ABILITY_LOCKED(gsiPlayer) then
			return;
		end
		local thisPlayerAbilities = t_player_abilities[gsiPlayer.nOnTeam]
		local impale = thisPlayerAbilities[1]
		local manaBurn = thisPlayerAbilities[2]
		local spikedCarapace = thisPlayerAbilities[3]
		local vendetta = thisPlayerAbilities[6]

		local highUse = gsiPlayer.highUseManaSimple
		local currentTask = CURRENT_TASK(gsiPlayer)
		local currentActivityType = CURRENT_ACTIVITY_TYPE(gsiPlayer)
		local fht = TASK_OBJECTIVE(gsiPlayer, fight_harass_handle)
		local fhtReal = fht and fht.hUnit.IsNull and not fht.hUnit:IsNull()
		local fhtHpp = fht and HEALTH_PERCENT(fht)

		local playerLoc = gsiPlayer.lastSeen.location
		local playerHpp = HEALTH_PERCENT(gsiPlayer)

		local distToFht = fhtReal and Vector_PointDistance(playerLoc, fht.lastSeen.location)

		local impaleRange = d.ImpaleRange(gsiPlayer.hUnit:HasModifier("modifier_nyx_assassin_burrow"))

		local nearbyEnemies, outerEnemies = NEARBY_OUTER(playerLoc, impaleRange, 1600, 2)

		local fhtMgkDmgFactor = fhtReal and SPELL_SUCCESS(gsiPlayer, fht, impale)

		gsiPlayer.trueSighted = gsiPlayer.hUnit:HasModifier("modifier_item_dustofappearance")
		gsiPlayer.hasAssassinStrike = gsiPlayer.hUnit:HasModifier("modifier_nyx_assassin_vendetta")

		local breakingStealthDisallowed = gsiPlayer.hUnit:IsInvisible() and not gsiPlayer.trueSighted

		if gsiPlayer.hasAssassinStrike then
			Task_IncentiviseTask(gsiPlayer, fight_harass_handle, 60, 15)
			Task_IncentiviseTask(gsiPlayer, increase_safety_handle, 30, 15)
			Task_IncentiviseTask(gsiPlayer, avoid_hide_handle, 30, 15)
			Task_IncentiviseTask(gsiPlayer, leech_exp_handle, 30, 15)
		end

if TEST then 
		for i=1,gsiPlayer.hUnit:NumModifiers() do
			print(gsiPlayer.hUnit:GetModifierName(i))
		end
end

		-- spiked carapace
		if CAN_BE_CAST(gsiPlayer, spikedCarapace)
					and HIGH_USE(gsiPlayer, spikedCarapace, highUse - spikedCarapace:GetManaCost(), playerHpp) then
			local damageRecorded, numHeroesAttacking = Analytics_GetTotalDamageNumberAttackers(gsiPlayer)
			if (numHeroesAttacking > 0
						and (currentActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION
							or currentActivityType > ACTIVITY_TYPE.CAREFUL))
					or numHeroesAttacking > 1 then
				USE_ABILITY(gsiPlayer, spikedCarapace, nil, 400, nil)
				return;
			end
		end
		if currentActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION then
			if fhtReal and CAN_BE_CAST(gsiPlayer, vendetta)
					and Math_PointToPointDistance2D(playerLoc, fht.lastSeen.location) < 2000
					and HIGH_USE(gsiPlayer, vendetta, highUse - vendetta:GetManaCost(), fhtHpp) then
				USE_ABILITY(gsiPlayer, vendetta, nil, 400, nil)
				return;
			end
			if fhtReal and not breakingStealthDisallowed
					and CAN_BE_CAST(gsiPlayer, impale) and fhtMgkDmgFactor > 0
					and HIGH_USE(gsiPlayer, impale, highUse - impale:GetManaCost(), fhtHpp) then
				local extrapolatedTime = IMPALE_CAST_POINT + distToFht / IMPALE_TRAVEL_SPEED
				local extrapolatedLoc = fht.hUnit:GetExtrapolatedLocation(extrapolatedTime)
				if Math_PointToPointDistance2D(playerLoc, extrapolatedLoc) < impaleRange then
						USE_ABILITY(gsiPlayer, impale, extrapolatedLoc,
								400, nil, nil, nil, nil, gsiPlayer.hUnit.Action_UseAbilityOnLocation)
					return;
				end
			end
			if not breakingStealthDisallowed and CAN_BE_CAST(gsiPlayer, manaBurn) then
				local bestTarget
				local bestTargetHpp = 1.0
				local highestTargetScore = 0
				local burnMultiplier = manaBurn:GetSpecialValueFloat("float_multiplier")
				for i=1,#nearbyEnemies do
					local thisEnemy = nearbyEnemies[i]
					if not pUnit_IsNullOrDead(thisEnemy) then
						local thisDamage = thisEnemy.hUnit:GetAttributeValue(ATTRIBUTE_INTELLECT)*burnMultiplier
						local trueDamage = min(thisDamage, thisEnemy.lastSeenMana)
								* SPELL_SUCCESS(gsiPlayer, thisEnemy, manaBurn)
						local healthRemainingFactor = (trueDamage / thisDamage)
								* (1 - abs((thisEnemy.lastSeenHealth - trueDamage) / thisEnemy.maxHealth))
						local thisScore = trueDamage * healthRemainingFactor
						if thisScore > highestTargetScore then
							highestTargetScore = thisScore
							bestTarget = thisEnemy
							bestTargetHpp = thisEnemy.lastSeenHealth / thisEnemy.maxHealth
						end
					end
				end
				if HIGH_USE(gsiPlayer, manaBurn, highUse - manaBurn:GetManaCost(), bestTargetHpp) then
					USE_ABILITY(gsiPlayer, manaBurn, bestTarget, 400, nil)
					return;
				end
			end
		end
		if currentActivityType > ACTIVITY_TYPE.CAREFUL then
			--print("nyx / can use breaks-stealth:", nearbyEnemies[1], breakingStealthDisallowed, CAN_BE_CAST(gsiPlayer, impale),
			--		HIGH_USE(gsiPlayer, impale, highUse - impale:GetManaCost(), playerHpp))

			if nearbyEnemies[1] and not breakingStealthDisallowed
					and CAN_BE_CAST(gsiPlayer, impale) and SPELL_SUCCESS(gsiPlayer, nearbyEnemies[1], impale) > 0
					and HIGH_USE(gsiPlayer, impale, highUse - impale:GetManaCost(), playerHpp) then
				local crowdingCenter, crowdedRating
						= CROWDED_RATING(nearbyEnemies[1].lastSeen.location, SET_HERO_ENEMY)
				local crowdedEnemy = Set_GetNearestEnemyHeroToLocation(
						Vector_PointBetweenPoints(playerLoc, crowdingCenter)
					)
				print("crowded center:", crowdedEnemy)
				if crowdedEnemy then
					local distToCrowded = Vector_PointDistance(playerLoc, crowdedEnemy.lastSeen.location)
					local extrapolatedTime = IMPALE_CAST_POINT + distToCrowded / IMPALE_TRAVEL_SPEED
					local extrapolatedLoc = crowdedEnemy.hUnit:GetExtrapolatedLocation(extrapolatedTime)
					if Math_PointToPointDistance2D(playerLoc, extrapolatedLoc)
							< impaleRange then
						USE_ABILITY(gsiPlayer, impale, extrapolatedLoc,
								400, nil, nil, nil, nil, gsiPlayer.hUnit.Action_UseAbilityOnLocation)
						return;
					end
				end
			end
			if CAN_BE_CAST(gsiPlayer, vendetta)
					and HIGH_USE(gsiPlayer, vendetta, highUse - vendetta:GetManaCost(), playerHpp) then
				USE_ABILITY(gsiPlayer, vendetta, nil, 400, nil)
				return;
			end
		end
	end,
}

local hero_access = function(key) return d[key] end

do
	HeroData_SetHeroData(hero_data, abilities, hero_access)
end
