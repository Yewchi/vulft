local hero_data = {
	"lion",
	{1, 3, 1, 2, 1, 4, 1, 3, 3, 6, 2, 4, 2, 2, 8, 3, 4, 10, 12},
	{
		"item_tango","item_branches","item_branches","item_branches","item_magic_stick","item_blood_grenade","item_ward_sentry","item_ward_sentry","item_boots","item_tranquil_boots","item_magic_wand","item_blink","item_point_booster","item_ogre_axe","item_staff_of_wizardry","item_ultimate_scepter","item_ghost","item_kaya","item_ethereal_blade","item_diadem","item_voodoo_mask","item_dagon_5","item_dagon_3L",
	},
	{ {1,1,1,3,3,}, {5,5,5,4,4,}, 0.1 },
	{
		"Earth Spike","Hex","Mana Drain","Finger of Death","+10% Mana Drain Slow","+65 Earth Spike Damage","-2s Hex Cooldown","+70 Max Health Per Finger of Death Kill","+20 Finger of Death Damage Per Kill","Earth Spike affects a 30º cone","Mana Drain Deals Damage","+250 AoE Hex",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"lion_impale", ABILITY_TYPE.NUKE + ABILITY_TYPE.STUN + ABILITY_TYPE.AOE},
		{"lion_voodoo", ABILITY_TYPE.STUN + ABILITY_TYPE.SLOW + ABILITY_TYPE.DEGEN},
		{"lion_mana_drain", ABILITY_TYPE.SLOW + ABILITY_TYPE.DEGEN},
		[5] = {"lion_finger_of_death", ABILITY_TYPE.NUKE},
}

local ZEROED_VECTOR = ZEROED_VECTOR
local playerRadius = Set_GetEnemyHeroesInPlayerRadius
local ENCASED_IN_RECT = Set_GetEnemiesInRectangle
local currentTask = Task_GetCurrentTaskHandle
local CROWDED_RATING = Set_GetCrowdedRatingToSetTypeAtLocation
local USE_ABILITY = UseAbility_RegisterAbilityUseAndLockToScore
local INCENTIVISE = Task_IncentiviseTask
local POINT_DISTANCE_2D = Vector_PointDistance2D
local VEC_UNIT_DIRECTIONAL = Vector_UnitDirectionalPointToPoint
local ACTIVITY_TYPE = ACTIVITY_TYPE
local CAST_SUCCESS = AbilityLogic_CastOnTargetWillSucceed
local currentActivityType = Blueprint_GetCurrentTaskActivityType
local currentTask = Task_GetCurrentTaskHandle
local HIGH_USE = AbilityLogic_HighUseAllowOffensive

local fight_harass_handle = FightHarass_GetTaskHandle()
local push_handle = Push_GetTaskHandle()

local t_player_abilities = {}

local ABILITY_USE_RANGE = 600
local OUTER_RANGE = 1600

local LION_FOD_COUNT_DMG = 40
local DISALLOW_STUN_EARTH_SPIKE_DURATION = 2
local DISALLOW_STUN_HEX_DURATION = 0.5

local t_no_double_stun_expire = {}

local function set_disallow_stun_target(gsiPlayer, gsiEnemy, duration)
	local disallowTbl = t_no_double_stun_expire[gsiPlayer.nOnTeam]
	disallowTbl[1] = gsiEnemy
	disallowTbl[2] = GameTime() + duration
end

local function get_disallow_stun_target(gsiPlayer)
	local disallowTbl = t_no_double_stun_expire[gsiPlayer.nOnTeam]
	if disallowTbl[1] then
		if disallowTbl[2] < GameTime() then
			disallowTbl[1] = nil
		else
			return disallowTbl[1]
		end
	end
	return false
end

local d
d = {
	["ReponseNeeds"] = function()
		return nil, REASPONSE_TYPE_DISPEL, nil, {RESPONSE_TYPE_KNOCKBACK, 4}
	end,
	["Initialize"] = function(gsiPlayer)
		AbilityLogic_CreatePlayerAbilitiesIndex(t_player_abilities, gsiPlayer, abilities)
		AbilityLogic_UpdateHighUseMana(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam])
		gsiPlayer.InformLevelUpSuccess = d.InformLevelUpSuccess
		t_no_double_stun_expire[gsiPlayer.nOnTeam] = {}
	end,
	["InformLevelUpSuccess"] = function(gsiPlayer)
		AbilityLogic_UpdateHighUseMana(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam])
		AbilityLogic_UpdatePlayerAbilitiesIndex(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam], abilities)
	end,
	["AbilityThink"] = function(gsiPlayer) 
		local playerAbilities = t_player_abilities[gsiPlayer.nOnTeam]
		local earthSpike = playerAbilities[1]
		local hex = playerAbilities[2]
		local drain = playerAbilities[3]
		local foD = playerAbilities[4]
		local foDKillCounterIndex = gsiPlayer.hUnit:GetModifierByName("modifier_lion_finger_of_death_kill_counter")
		local foDNetDmg = foD:GetSpecialValueInt("damage")
				+ (foDKillCounterIndex and gsiPlayer.hUnit:GetModifierStackCount(foDKillCounterIndex)
					or 0)*foD:GetSpecialValueInt("damage_per_kill")
		if UseAbility_IsPlayerLocked(gsiPlayer) then
			-- TODO Break drain if you should kill the target instead, there are no allies killing them.
			local currActiveAbility = gsiPlayer.hUnit:GetCurrentActiveAbility()
			if currActiveAbility and currActiveAbility:GetName() == "lion_mana_drain" then
				if Analytics_GetTotalDamageInTimeline(gsiPlayer.hUnit) > gsiPlayer.lastSeenHealth/10
						and gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth < 0.8 then
					UseAbility_ClearQueuedAbilities(gsiPlayer)
				elseif AbilityLogic_AbilityCanBeCast(gsiPlayer, foD) then
					local foDRangeEnemies = Set_GetEnemyHeroesInPlayerRadius(gsiPlayer, foD:GetCastRange()*0.95)
					if AbilityLogic_HighestPowerOHK(gsiPlayer, foD, foDRangeEnemies, foDNetDmg) then
						UseAbility_ClearQueuedAbilities(gsiPlayer)
					end
				end
			else
				return;
			end
		end

		local playerLoc = gsiPlayer.lastSeen.location
		local highUse = gsiPlayer.highUseManaSimple
		local playerHealthPercent = gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth

		--print("lion high use", highUse)

		local currActivityType = currentActivityType(gsiPlayer)
		local currTask = currentTask(gsiPlayer)
		local nearbyEnemies, outerEnemies
				= Set_GetEnemyHeroesInLocRadOuter(gsiPlayer.lastSeen.location, ABILITY_USE_RANGE, OUTER_RANGE, 6)
		local danger, knownE, theoryE = Analytics_GetTheoreticalDangerAmount(gsiPlayer)
		local fht = Task_GetTaskObjective(gsiPlayer, fight_harass_handle)
		local fhtReal = fht
				and fht.hUnit.IsNull and not fht.hUnit:IsNull()
		local fhtHpp = fhtReal and fht.lastSeenHealth / fht.maxHealth
		local distToFht = fhtReal and POINT_DISTANCE_2D(fht.lastSeen.location, playerLoc)
		local disallowTarget = get_disallow_stun_target(gsiPlayer)


		local fhtPercHp = fht and fht.lastSeenHealth / fht.maxHealth or 1.0
		if currActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION and fht then
			-- TODO Range of unit target vs high additional range of point target
			if AbilityLogic_AbilityCanBeCast(gsiPlayer, earthSpike)
					and fhtReal and not (fht.hUnit:IsHexed() or fht.hUnit:IsStunned())
					and disallowTarget ~= fht
					and CAST_SUCCESS(gsiPlayer, fht, earthSpike) > 0
					and HIGH_USE(gsiPlayer, earthSpike, highUse - earthSpike:GetManaCost(), fhtPercHp) then
				local crowdingCenter, crowdedRating
						= CROWDED_RATING(fht.lastSeen.location, SET_HERO_ENEMY)
				set_disallow_stun_target(gsiPlayer, fht, DISALLOW_STUN_EARTH_SPIKE_DURATION)
				USE_ABILITY(gsiPlayer, earthSpike, fht, 400, nil)
				return;
			end
			if AbilityLogic_AbilityCanBeCast(gsiPlayer, hex)
					and fhtReal and not fht.hUnit:IsStunned()
					and disallowTarget ~= fht
					and CAST_SUCCESS(gsiPlayer, fht, hex) > 0
					and HIGH_USE(gsiPlayer, hex, highUse - hex:GetManaCost(), fhtPercHp) then
				set_disallow_stun_target(gsiPlayer, fht, DISALLOW_STUN_HEX_DURATION)
				USE_ABILITY(gsiPlayer, hex, fht, 400, nil)
				return;
			end
		end
		local succeedsUnits = AbilityLogic_GetCastSucceedsUnits(gsiPlayer, nearbyEnemies, earthSpike)
		local arbitrarySucceedsHero = succeedsUnits[1] and not pUnit_IsNullOrDead(succeedsUnits[1])
				and succeedsUnits[1] or false
		
		if currActivityType >= ACTIVITY_TYPE.CAREFUL
				and arbitrarySucceedsHero and AbilityLogic_AbilityCanBeCast(gsiPlayer, earthSpike)
				and disallowTarget ~= arbitrarySucceedsHero
				and not (arbitrarySucceedsHero.hUnit:IsStunned() or arbitrarySucceedsHero.hUnit:IsHexed())
				and HIGH_USE(gsiPlayer, earthSpike, highUse - earthSpike:GetManaCost(), playerHealthPercent) then
			-- TODO in strip
			set_disallow_stun_target(gsiPlayer, arbitrarySucceedsHero, DISALLOW_STUN_EARTH_SPIKE_DURATION)
			USE_ABILITY(gsiPlayer, earthSpike, arbitrarySucceedsHero, 400, nil)
			return;
		end
		if currTask == push_handle and AbilityLogic_AbilityCanBeCast(gsiPlayer, earthSpike)
				and HIGH_USE(gsiPlayer, earthSpike, highUse - earthSpike:GetManaCost(), 1-playerHealthPercent)
				and (not gsiPlayer.theoreticalDanger or gsiPlayer.theoreticalDanger < 0) 
				and #knownE + #theoryE == 0 then
			local nearbyCreeps = Set_GetNearestEnemyCreepSetAtLaneLoc(
					gsiPlayer.lastSeen.location, Map_GetBaseOrLaneLocation(gsiPlayer.lastSeen.location)
				)

			if nearbyCreeps then
				-- TODO USE_ABILITY queue with move to loc facing from vector between two random creeps
				local crowdingCenter, crowdedRating
						= CROWDED_RATING(nearbyCreeps.center, SET_CREEP_ENEMY, nearbyCreeps.units, 250)
				if crowdedRating > 2 then
					USE_ABILITY(gsiPlayer, earthSpike, crowdingCenter, 400, nil)
					return;
				end
			end
		end
		local foDKillCounterIndex = gsiPlayer.hUnit:GetModifierByName("modifier_lion_finger_of_death_kill_counter")
		if AbilityLogic_AbilityCanBeCast(gsiPlayer, foD) and fhtReal 
				and gsiPlayer.lastSeenMana > foD:GetManaCost()
				and AbilityLogic_AllowOneHitKill(
						gsiPlayer,
						fht,
						foD:GetCastRange(),
						foDNetDmg,
						foD:GetDamageType()
					) then
			USE_ABILITY(gsiPlayer, foD, fht, 400, nil)
			return;
		end
		if currActivityType > ACTIVITY_TYPE.CAREFUL
				and arbitrarySucceedsHero and AbilityLogic_AbilityCanBeCast(gsiPlayer, hex)
				and disallowTarget ~= arbitrarySucceedsHero
				and HIGH_USE(gsiPlayer, hex, highUse - hex:GetManaCost(), playerHealthPercent)
				and not pUnit_IsNullOrDead(arbitrarySucceedsHero)
				and not (arbitrarySucceedsHero.hUnit:IsStunned() or arbitrarySucceedsHero.hUnit:IsHexed()) then
			set_disallow_stun_target(gsiPlayer, arbitrarySucceedsHero, DISALLOW_STUN_HEX_DURATION)
			USE_ABILITY(gsiPlayer, hex, arbitrarySucceedsHero, 400, nil)
			return;
		end
		if currActivityType <= ACTIVITY_TYPE.CAREFUL
				and arbitrarySucceedsHero and AbilityLogic_AbilityCanBeCast(gsiPlayer, drain)
				and HIGH_USE(gsiPlayer, drain, highUse - drain:GetManaCost(), playerHealthPercent) then
			USE_ABILITY(gsiPlayer, drain, nearbyEnemies[1], 400, nil)
			return;
		end
		if fhtReal and gsiPlayer.lastSeenMana > gsiPlayer.maxMana*0.75
				and HIGH_USE(gsiPlayer, earthSpike, highUse, fhtHpp)
				and disallowTarget ~= fht
				and not (fht.hUnit:IsStunned() or fht.hUnit:IsHexed())
				and distToFht < earthSpike:GetCastRange() then
			set_disallow_stun_target(gsiPlayer, fht, DISALLOW_STUN_EARTH_SPIKE_DURATION)
			USE_ABILITY(gsiPlayer, earthSpike, fht, 400, nil)
			return;
		end
	end,
}

local hero_access = function(key) return d[key] end

do
	HeroData_SetHeroData(hero_data, abilities, hero_access)
end
