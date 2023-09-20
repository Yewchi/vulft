local hero_data = {
	"lina",
	{1, 3, 1, 2, 1, 4, 1, 2, 2, 6, 2, 4, 3, 3, 8, 3, 4, 9, 11},
	{
		"item_ward_observer","item_faerie_fire","item_tango","item_branches","item_branches","item_branches","item_bottle","item_boots","item_arcane_boots","item_void_stone","item_aether_lens","item_wind_lace","item_staff_of_wizardry","item_robe","item_kaya","item_void_stone","item_staff_of_wizardry","item_cyclone","item_aghanims_shard","item_ghost","item_ethereal_blade","item_staff_of_wizardry","item_ogre_axe","item_blade_of_alacrity","item_ultimate_scepter","item_blink","item_wind_waker","item_mystic_staff","item_arcane_blink","item_sheepstick","item_refresher","item_ultimate_scepter_2",
	},
	{ {2,2,2,2,3,}, {2,2,2,2,4,}, 0.1 },
	{
		"Dragon Slave","Light Strike Array","Fiery Soul","Laguna Blade","+20 Damage","-3.5s Dragon Slave Cooldown","+275 Health","+150 Light Strike Array Damage","+11% Spell Amplification","+1/+1% Fiery Soul Per Stack","-25s Laguna Blade Cooldown","Laguna Blade damage is Pure",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"lina_dragon_slave", ABILITY_TYPE.NUKE + ABILITY_TYPE.AOE},
		{"lina_light_strike_array", ABILITY_TYPE.NUKE + ABILITY_TYPE.STUN},
		{"lina_fiery_soul", ABILITY_TYPE.PASSIVE},
		{"lina_flame_cloak", ABILITY_TYPE.SHIELD + ABILITY_TYPE.BUFF},
		[5] = {"lina_laguna_blade", ABILITY_TYPE.NUKE},
}

local ZEROED_VECTOR = ZEROED_VECTOR
local playerRadius = Set_GetEnemyHeroesInPlayerRadius
local ENCASED_IN_RECT = Set_GetEnemiesInRectangle
local currentTask = Task_GetCurrentTaskHandle
local CAN_BE_CAST = AbilityLogic_AbilityCanBeCast
local CROWDED_RATING = Set_GetCrowdedRatingToSetTypeAtLocation
local USE_ABILITY = UseAbility_RegisterAbilityUseAndLockToScore
local INCENTIVISE = Task_IncentiviseTask
local VEC_UNIT_DIRECTIONAL = Vector_UnitDirectionalPointToPoint
local POINT_DISTANCE = Vector_PointDistance
local POINT_DISTANCE_2D = Vector_PointDistance2D
local ACTIVITY_TYPE = ACTIVITY_TYPE
local currentActivityType = Blueprint_GetCurrentTaskActivityType
local currentTask = Task_GetCurrentTaskHandle
local HIGH_USE = AbilityLogic_HighUseAllowOffensive

local fight_harass_handle = FightHarass_GetTaskHandle()
local push_handle = Push_GetTaskHandle()

local t_player_abilities = {}

local ABILITY_USE_RANGE = 800
local OUTER_RANGE = 1600
local LSA_CAST_TIME = 0.45 + 0.5
local LSA_EXTRAPOLATE = LSA_CAST_TIME - (0.35 + 0.15) -- time to decypher animation type, time to react
local DRAGON_SLAVE_EXTRAPOLATED = 0.45 + 0.5*1275 / 1075
local DRAGON_SLAVE_HIT_RANGE = 1225

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
		local playerAbilities = t_player_abilities[gsiPlayer.nOnTeam]
		local dragonSlave = playerAbilities[1]
		local lsa = playerAbilities[2]
		local flameCloak = playerAbilities[4]
		local langua = playerAbilities[5]
		local highUse = gsiPlayer.highUseManaSimple
		local playerHealthPercent = gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth

		local LSA_RADIUS = lsa:GetAOERadius()

		

		local fierySoulStacks = gsiPlayer.hUnit:HasModifier("modifier_lina_fiery_soul")

		local playerLoc = gsiPlayer.lastSeen.location
		local currActivityType = currentActivityType(gsiPlayer)
		local currTask = currentTask(gsiPlayer)
		local nearbyEnemies, outerEnemies
				= Set_GetEnemyHeroesInLocRadOuter(gsiPlayer.lastSeen.location, ABILITY_USE_RANGE, OUTER_RANGE, 6)
		local fht = Task_GetTaskObjective(gsiPlayer, fight_harass_handle)
		local fhtReal = fht
				and fht.hUnit.IsNull and not fht.hUnit:IsNull()
		local fhtPercHp = fht
				and fht.lastSeenHealth / fht.maxHealth or 1.0
		local fhtLoc = fhtReal and fht.lastSeen.location
		if fhtReal and currActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION then
			if CAN_BE_CAST(gsiPlayer, dragonSlave)
					and Vector_PointDistance(playerLoc, fhtLoc) < 1100
					and HIGH_USE(gsiPlayer, dragonSlave, highUse - dragonSlave:GetManaCost(), fhtPercHp) then
				local extrapolatedFht = fht.hUnit:GetExtrapolatedLocation(DRAGON_SLAVE_EXTRAPOLATED)
				USE_ABILITY(gsiPlayer, dragonSlave, extrapolatedFht, 400, nil)
				return;
			end
			if fhtReal then
				local fhtStability = fht.hUnit:GetMovementDirectionStability()
				if CAN_BE_CAST(gsiPlayer, lsa)
						and (fhtStability == 0 or fhtStability > 0.6)
						and HIGH_USE(gsiPlayer, lsa, highUse - lsa:GetManaCost(), fhtPercHp) then
					local extrapolatedFht = fht.hUnit:GetExtrapolatedLocation(LSA_EXTRAPOLATE)
					local crowdingCenter, crowdedRating
							= CROWDED_RATING(extrapolatedFht, SET_HERO_ENEMY)
					local castLoc = crowdingCenter
					if crowdedRating < 1.5 or Vector_PointDistance(extrapolatedFht, crowdingCenter)
							> LSA_RADIUS*0.75 then
						castLoc = extrapolatedFht
					end
					if Math_PointToPointDistance2D(gsiPlayer.lastSeen.location, castLoc)
									< lsa:GetCastRange() then
						USE_ABILITY(gsiPlayer, lsa, castLoc, 400, nil)
						return;
					end
				end
			end
		end
		if currActivityType > ACTIVITY_TYPE.CAREFUL
				and nearbyEnemies[1] and CAN_BE_CAST(gsiPlayer, lsa)
				and HIGH_USE(gsiPlayer, lsa, highUse - lsa:GetManaCost(), playerHealthPercent) then
			if nearbyEnemies[1].hUnit.IsNull and not nearbyEnemies[1].hUnit:IsNull() then
				local projectedLoc = nearbyEnemies[1].hUnit:GetExtrapolatedLocation(LSA_EXTRAPOLATE)
				USE_ABILITY(gsiPlayer, lsa, projectedLoc, 400, nil)
				return;
			end
		end
		if currTask == push_handle and CAN_BE_CAST(gsiPlayer, dragonSlave)
				and HIGH_USE(gsiPlayer, dragonSlave, (highUse - dragonSlave:GetManaCost())*2.5, 1-playerHealthPercent) then 
			local nearbyCreeps = Set_GetNearestEnemyCreepSetAtLaneLoc(
					gsiPlayer.lastSeen.location, Map_GetBaseOrLaneLocation(gsiPlayer.lastSeen.location)
				)
			if nearbyCreeps and POINT_DISTANCE_2D(playerLoc, nearbyCreeps.center) < DRAGON_SLAVE_HIT_RANGE then
				USE_ABILITY(gsiPlayer, dragonSlave, nearbyCreeps.center, 400, nil)
				return;
			end
		end










		if CAN_BE_CAST(gsiPlayer, langua) and fhtReal 
				and gsiPlayer.lastSeenMana > langua:GetManaCost()
				and AbilityLogic_AllowOneHitKill(
						gsiPlayer,
						fht,
						langua:GetCastRange(),
						langua:GetSpecialValueInt("damage"),
						langua:GetDamageType()
					) then
			USE_ABILITY(gsiPlayer, langua, fht, 400, nil)
			return;
		end
		if CAN_BE_CAST(gsiPlayer, flameCloak)
				and (currActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION
					and FightClimate_GetEnemiesTotalHeat(nearbyEnemies) > 3
					or (currActivityType > ACTIVITY_TYPE.FEAR
						and Analytics_GetFutureDamageInTimeline(gsiPlayer.hUnit) > 0
					)
				) then
			USE_ABILITY(gsiPlayer, flameCloak, nil, 400, nil)
			return;
		end
	end,
}

local hero_access = function(key) return d[key] end

do
	HeroData_SetHeroData(hero_data, abilities, hero_access)
end
