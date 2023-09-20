local hero_data = {
	"sniper",
	{2, 3, 2, 3, 2, 1, 2, 3, 3, 6, 4, 4, 1, 1, 7, 1, 4, 9, 11},
	{
		"item_ward_observer","item_circlet","item_quelling_blade","item_branches","item_magic_stick","item_faerie_fire","item_wraith_band","item_magic_wand","item_boots_of_elves","item_gloves","item_boots","item_power_treads","item_javelin","item_maelstrom","item_dragon_lance","item_ogre_axe","item_mithril_hammer","item_ogre_axe","item_black_king_bar","item_lesser_crit","item_shadow_amulet","item_silver_edge","item_aghanims_shard","item_eagle","item_talisman_of_evasion","item_butterfly","item_javelin","item_blitz_knuckles","item_monkey_king_bar","item_sphere","item_gem","item_satanic",
	},
	{ {2,2,2,2,2,}, {2,2,2,2,2,}, 0.1 },
	{
		"Shrapnel","Headshot","Take Aim","Assassinate","+1.0s Take Aim Duration","+30 Headshot Damage","+30 Attack Speed","+-15% Shrapnel Movement Slow","+25 Headshot Knockback Distance","+25 Shrapnel DPS","+100 Attack Range","+6 Shrapnel Charges",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"sniper_shrapnel", ABILITY_TYPE.NUKE + ABILITY_TYPE.SLOW + ABILITY_TYPE.AOE},
		{"sniper_headshot", ABILITY_TYPE.PASSIVE},
		{"sniper_take_aim", ABILITY_TYPE.ATTACK_MODIFIER},
		{"sniper_concussive_grenade", ABILITY_TYPE.NUKE + ABILITY_TYPE.AOE + ABILITY_TYPE.SLOW},
		[5] = {"sniper_assassinate", ABILITY_TYPE.NUKE},
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
local NEARBY_OUTER = Set_GetEnemyHeroesInPlayerRadiusAndOuter
local NEARBY_ENEMY = Set_GetEnemyHeroesInPlayerRadius
local HIGH_USE = AbilityLogic_HighUseAllowOffensive
local SPELL_SUCCESS = AbilityLogic_CastOnTargetWillSucceed

local fight_harass_handle = FightHarass_GetTaskHandle()

local t_player_abilities = {}

local max = math.max

local SHRAPNEL_LANDS_DELAY = 0.3 + 1.2 + 0.5
local SHRAPNEL_DURATION = 10
local SHRAPNEL_RADIUS = 450
local SHRAPNEL_CHARGE_TALENT_INDEX = 13
local SHRAPNEL_CHARGE_TALENT_INCREASE = 6

local SHRAPNELS_ACTIVE_I__LOC = 1
local SHRAPNELS_ACTIVE_I__EXPIRES = 2
local t_player_shrapnels_active = {}

local function add_new_shrapnel(shrapnelsActive, location)
	table.insert(shrapnelsActive, {location, GameTime() + SHRAPNEL_DURATION})
end

local function remove_expired_shrapnels(shrapnelsActive)
	local i=1
	while(i<#shrapnelsActive) do
		if shrapnelsActive[i]
				and shrapnelsActive[i][SHRAPNELS_ACTIVE_I__EXPIRES] < GameTime() then
			table.remove(shrapnelsActive, i)
		else
			i = i + 1
		end
	end
end

local function try_cast_extrapolated_shrapnel(gsiPlayer, shrapnel, shrapnelsActive, targetUnit)
	if not targetUnit.hUnit or targetUnit.hUnit:IsNull() or not targetUnit.hUnit:IsAlive() then
		return false
	end
	local extrapolatedLoc = targetUnit.hUnit:GetExtrapolatedLocation(SHRAPNEL_LANDS_DELAY)*max(0.33, targetUnit.hUnit:GetMovementDirectionStability())
--	print("TRY SHRAP")
--	print(VEC_POINT_DISTANCE(
--				gsiPlayer.lastSeen.location,
--				extrapolatedLoc
--			), shrapnel:GetCastRange())
	if VEC_POINT_DISTANCE(
				gsiPlayer.lastSeen.location,
				extrapolatedLoc
			) > shrapnel:GetCastRange() then
		return false
	end
	for i=1,#shrapnelsActive do
		--[[print(VEC_POINT_DISTANCE(
						shrapnelsActive[i][SHRAPNELS_ACTIVE_I__LOC],
						extrapolatedLoc
					), SHRAPNEL_RADIUS + 100)--]]
		if VEC_POINT_DISTANCE(
						shrapnelsActive[i][SHRAPNELS_ACTIVE_I__LOC],
						extrapolatedLoc
					) < SHRAPNEL_RADIUS + 100 then
			return false
		end
	end
	add_new_shrapnel(shrapnelsActive, extrapolatedLoc)
	USE_ABILITY(gsiPlayer, shrapnel, extrapolatedLoc, 400, nil)
	return true;
end

local d
d = {
	["ShrapnelChargeRestoreTime"] = function() return 35 end,
	["ShrapnelMaxCharges"] = function(gsiPlayer)
		if gsiPlayer.hUnit and not gsiPlayer.hUnit:IsNull() then
			local shrapnelCharges = gsiPlayer.hUnit:GetAbilityInSlot(SHRAPNEL_CHARGE_TALENT_INDEX)
			if shrapnelCharges and shrapnelCharges:IsTrained() then
				return 3 + SHRAPNEL_CHARGE_TALENT_INCREASE
			else
				return 3
			end
		end
	end,
	["assassinate_damage"] = {[0] = 650, 320, 485, 650},
	["AssassinateDamage"] = function(gsiPlayer)
		return d.assassinate_damage[min(3, floor(gsiPlayer.level/6))]
	end,
	["ReponseNeeds"] = function()
		return nil, REASPONSE_TYPE_DISPEL, nil, {RESPONSE_TYPE_KNOCKBACK, 4}
	end,
	["Initialize"] = function(gsiPlayer)
		t_player_shrapnels_active[gsiPlayer.nOnTeam] = {}
		AbilityLogic_CreatePlayerAbilitiesIndex(t_player_abilities, gsiPlayer, abilities)
		AbilityLogic_UpdateHighUseMana(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam])
		ChargedCooldown_RegisterCooldown(
				gsiPlayer,
				t_player_abilities[gsiPlayer.nOnTeam][1], 
				d.ShrapnelMaxCharges,
				d.ShrapnelChargeRestoreTime
			)
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
		local shrapnel = playerAbilities[1]
		local takeAim = playerAbilities[3]
		local frag = playerAbilities[4]
		local assas = playerAbilities[5]

		local shrapnelsActive = t_player_shrapnels_active[gsiPlayer.nOnTeam]

		remove_expired_shrapnels(shrapnelsActive)

		local highUse = gsiPlayer.highUseManaSimple
		local currentTask = CURRENT_TASK(gsiPlayer)
		local currentActivityType = CURRENT_ACTIVITY_TYPE(gsiPlayer)
		local fht = TASK_OBJECTIVE(gsiPlayer, fight_harass_handle)
		local fhtReal = fht and fht.hUnit.IsNull and not fht.hUnit:IsNull()
		local fhtHUnit = fhtReal and fht.hUnit
		local fhtHpp = fht and fht.lastSeenHealth / fht.maxHealth

		local playerHUnit = gsiPlayer.hUnit
		local playerLoc = gsiPlayer.lastSeen.location
		local playerHpp = HEALTH_PERCENT(gsiPlayer)

		local nearbyEnemies, outerEnemies = NEARBY_OUTER(playerLoc, shrapnel:GetCastRange(), 
				assas:GetCastRange(), 2
			)

		local fhtMgkDmgFactor = fhtReal and SPELL_SUCCESS(gsiPlayer, fht, shrapnel)

		-- TODO magic immunity
		if CHARGE_CAN_BE_CAST(gsiPlayer, shrapnel) then
			if fhtReal and fhtMgkDmgFactor > 0
					and currentActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION
					and	not fhtHUnit:HasModifier("modifier_sniper_shrapnel_slow")
					and HIGH_USE(gsiPlayer, shrapnel, highUse, fhtHpp)
					and try_cast_extrapolated_shrapnel(gsiPlayer, shrapnel, shrapnelsActive, fht) then
				return;
			end
			if currentActivityType >= ACTIVITY_TYPE.FEAR
					and nearbyEnemies[1] and HIGH_USE(gsiPlayer, shrapnel, highUse, playerHpp) then
				local nearestEnemy, nearestDist = Set_GetSetUnitNearestToLocation(playerLoc, nearbyEnemies)
				local nearestMgkDmgFactor = SPELL_SUCCESS(gsiPlayer, nearestEnemy, shrapnel)
				if nearestMgkDmgFactor > 0 and
						try_cast_extrapolated_shrapnel(gsiPlayer, shrapnel, shrapnelsActive, nearestEnemy) then
					return;
				end
			end
		end
		-- TODO Assassinate
		if CAN_BE_CAST(gsiPlayer, assas)
				and not ANY_HARM(gsiPlayer, nearbyEnemies) then
			local assassinateDamage = d.assassinate_damage[assas:GetLevel()]
			if fhtReal
					and (not fht.illusionsUp or fht.knownNonIllusionUnit == fht.hUnit)
					and HIGH_USE(gsiPlayer, assas, highUse, fhtHpp)
					and AOHK(gsiPlayer, fht, gsiPlayer.attackRange, assassinateDamage,
							assas:GetDamageType(), nearbyEnemies
						) then
				USE_ABILITY(gsiPlayer, assas, fht, 400, nil)
				return;
			end
		--	local bestTarget
		--	local attackRange = playerHUnit:GetAttackRange()
		--	for i=1,#nearbyEnemies do
		--		local thisEnemy = nearbyEnemies[i]
		--		if VEC_POINT_DISTANCE(playerLoc, thisEnemy.lastSeen.location) > attackRange*0.9
		--				and thisEnemy.currentMovementSpeed / gsiPlayer.currentMovementSpeed > 0.66
		--				and
		--		end
		--	end
		end
	end,
}

local hero_access = function(key) return d[key] end

do
	HeroData_SetHeroData(hero_data, abilities, hero_access)
end


