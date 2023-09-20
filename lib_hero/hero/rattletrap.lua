local hero_data = {
	"rattletrap",
	{1, 2, 1, 3, 1, 4, 1, 3, 3, 3, 5, 4, 2, 2, 8, 2, 4, 9},
	{
		"item_blood_grenade","item_ward_sentry","item_magic_stick","item_tango","item_faerie_fire","item_clarity","item_ward_observer","item_magic_wand","item_boots","item_wind_lace","item_tranquil_boots","item_cloak","item_headdress","item_ring_of_health","item_pipe","item_cloak","item_shadow_amulet","item_glimmer_cape","item_blade_mail","item_heart",
	},
	{ {5,5,3,4,4,}, {4,4,4,4,2,}, 0.1 },
	{
		"Battery Assault","Power Cogs","Rocket Flare","Hookshot","-2s Rocket Flare Cooldown","-3s Power Cogs Cooldown","+2 Power Cogs Hit To Kill","+24 Battery Assault Damage","Rocket Flare True Sight","+75 Rocket Flare Damage","Debuff Immunity Inside Power Cogs","-0.25s Battery Assault Interval",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"rattletrap_battery_assault", ABILITY_TYPE.NUKE + ABILITY_TYPE.STUN},
		{"rattletrap_flare", ABILITY_TYPE.NUKE + ABILITY_TYPE.SMITE},
		{"rattletrap_power_cogs", ABILITY_TYPE.NUKE + ABILITY_TYPE.DEGEN + ABILITY_TYPE.SLOW},
		[5] = {"rattletrap_", ABILITY_TYPE.STUN + ABILITY_TYPE.MOBILITY + ABILITY_TYPE.NUKE},
}

local ZEROED_VECTOR = ZEROED_VECTOR
local playerRadius = Set_GetEnemyHeroesInPlayerRadius
local ENCASED_IN_RECT = Set_GetEnemiesInRectangle
local currentTask = Task_GetCurrentTaskHandle
local GSI_AbilityCanBeCast = GSI_AbilityCanBeCast
local CROWDED_RATING = Set_GetCrowdedRatingToSetTypeAtLocation
local USE_ABILITY = UseAbility_RegisterAbilityUseAndLockToScore
local INCENTIVISE = Task_IncentiviseTask
local VEC_UNIT_DIRECTIONAL = Vector_UnitDirectionalPointToPoint
local POINT_DISTANCE = Vector_PointDistance
local ACTIVITY_TYPE = ACTIVITY_TYPE
local currentActivityType = Blueprint_GetCurrentTaskActivityType
local currentTask = Task_GetCurrentTaskHandle
local HIGH_USE = AbilityLogic_HighUseAllowOffensive

local fight_harass_handle = FightHarass_GetTaskHandle()
local push_handle = Push_GetTaskHandle()

local t_player_abilities = {}

local NEARBY_RANGE = 800
local LSA_CAST_TIME = 0.45 + 0.5
local LSA_EXTRAPOLATE = LSA_CAST_TIME - (0.35 + 0.15) -- time to decypher animation type, time to react
local LSA_RADIUS = 250
local DRAGON_SLAVE_EXTRAPOLATED = 0.45 + 0.5*1275 / 1075

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
		local battery = playerAbilities[1]
		local flare = playerAbilities[2]
		local cogs = playerAbilities[3]
		local hookshot = playerAbilities[4]
		local highUse = gsiPlayer.highUseManaSimple
		local playerHealthPercent = gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth

		local fierySoulStacks = gsiPlayer.hUnit:HasModifier("modifier_rattletrap_battery_assault")

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
			if AbilityLogic_AbilityCanBeCast(gsiPlayer, dragonSlave)
					and Vector_PointDistance(playerLoc, fhtLoc) < 1100
					and HIGH_USE(gsiPlayer, dragonSlave, highUse - dragonSlave:GetManaCost(), fhtPercHp) then
				local extrapolatedFht = fht.hUnit:GetExtrapolatedLocation(DRAGON_SLAVE_EXTRAPOLATED)
				USE_ABILITY(gsiPlayer, dragonSlave, extrapolatedFht, 400, nil)
				return;
			end
			if fhtReal then
				local fhtStability = fht.hUnit:GetMovementDirectionStability()
				if AbilityLogic_AbilityCanBeCast(gsiPlayer, lsa)
						and fhtStability == 0 or fhtStability > 0.6
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
				and nearbyEnemies[1] and AbilityLogic_AbilityCanBeCast(gsiPlayer, lsa)
				and HIGH_USE(gsiPlayer, lsa, highUse - lsa:GetManaCost(), playerHealthPercent) then
			if nearbyEnemies[1].hUnit.IsNull and not nearbyEnemies[1].hUnit:IsNull() then
				local projectedLoc = nearbyEnemies[1].hUnit:GetExtrapolatedLocation(LSA_EXTRAPOLATE)
				USE_ABILITY(gsiPlayer, lsa, projectedLoc, 400, nil)
				return;
			end
		end
		if currTask == push_handle and AbilityLogic_AbilityCanBeCast(gsiPlayer, dragonSlave)
				and HIGH_USE(gsiPlayer, dragonSlave, (highUse - dragonSlave:GetManaCost())*2.5, 1-playerHealthPercent) then 
			local nearbyCreeps = Set_GetNearestEnemyCreepSetAtLaneLoc(
					gsiPlayer.lastSeen.location, Map_GetBaseOrLaneLocation(gsiPlayer.lastSeen.location)
				)
			if nearbyCreeps then
				USE_ABILITY(gsiPlayer, dragonSlave, nearbyCreeps.center, 400, nil)
				return;
			end
		end
		if AbilityLogic_AbilityCanBeCast(gsiPlayer, langua) and fhtReal 
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
	end,
}

local hero_access = function(key) return d[key] end

do
	HeroData_SetHeroData(hero_data, abilities, hero_access)
end
