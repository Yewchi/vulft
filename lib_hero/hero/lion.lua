local hero_data = {
	"lion",
	{1, 2, 1, 2, 1, 4, 1, 3, 3, 3, 3, 4, 2, 2, 8, 6, 4, 9, 12},
	{
		"item_faerie_fire","item_magic_stick","item_tango","item_faerie_fire","item_enchanted_mango","item_ward_sentry","item_boots","item_wind_lace","item_tranquil_boots","item_magic_wand","item_blink","item_staff_of_wizardry","item_fluffy_hat","item_force_staff","item_aghanims_shard","item_gem","item_staff_of_wizardry","item_staff_of_wizardry","item_ogre_axe","item_blade_of_alacrity","item_ultimate_scepter","item_gem",
	},
	{ {1,1,1,4,3,}, {5,5,5,5,4,}, 0.1 },
	{
		"Earth Spike","Hex","Mana Drain","Finger of Death","+10% Mana Drain Slow","+65 Earth Spike Damage","Mana Drain Restores Allies","+70 Max Health Per Finger of Death Kill","+20 Finger of Death Damage Per Kill","-2s Hex Cooldown","Mana Drain Deals Damage","+250 AoE Hex",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_HERO_SELECTION then return hero_data end

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
local GSI_AbilityCanBeCast = GSI_AbilityCanBeCast
local CROWDED_RATING = Set_GetCrowdedRatingToSetTypeAtLocation
local USE_ABILITY = UseAbility_RegisterAbilityUseAndLockToScore
local INCENTIVISE = Task_IncentiviseTask
local VEC_UNIT_DIRECTIONAL = Vector_UnitDirectionalPointToPoint
local ACTIVITY_TYPE = ACTIVITY_TYPE
local currentActivityType = Blueprint_GetCurrentTaskActivityType
local currentTask = Task_GetCurrentTaskHandle
local HIGH_USE = AbilityLogic_HighUseAllowOffensive

local fight_harass_handle = FightHarass_GetTaskHandle()
local push_handle = Push_GetTaskHandle()

local t_player_abilities = {}

local ABILITY_USE_RANGE = 600
local OUTER_RANGE = 1600

local LION_FOD_COUNT_DMG = 40

local d = {
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
			if currActiveAbility and currActiveAbility:GetName() == "lion_mana_drain" then
				if Analytics_GetTotalDamageInTimeline(gsiPlayer.hUnit) > gsiPlayer.lastSeenHealth/20
						and gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth < 0.8 then
					UseAbility_ClearQueuedAbilities(gsiPlayer)
				end
			else
				return;
			end
		end
		local playerAbilities = t_player_abilities[gsiPlayer.nOnTeam]
		local earthSpike = playerAbilities[1]
		local hex = playerAbilities[2]
		local drain = playerAbilities[3]
		local foD = playerAbilities[4]
		local highUse = gsiPlayer.highUseManaSimple
		local playerHealthPercent = gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth

		--print("lion high use", highUse)

		local currActivityType = currentActivityType(gsiPlayer)
		local currTask = currentTask(gsiPlayer)
		local nearbyEnemies, outerEnemies
				= Set_GetEnemyHeroesInLocRadOuter(gsiPlayer.lastSeen.location, ABILITY_USE_RANGE, OUTER_RANGE, 6)
		local fightHarassTarget = Task_GetTaskObjective(gsiPlayer, fight_harass_handle)
		local fhtReal = fightHarassTarget
				and fightHarassTarget.hUnit.IsNull and not fightHarassTarget.hUnit:IsNull()
		local fhtPercHp = fightHarassTarget and fightHarassTarget.lastSeenHealth / fightHarassTarget.maxHealth or 1.0
		if currActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION and fightHarassTarget then
			-- TODO Range of unit target vs high additional range of point target
			if AbilityLogic_AbilityCanBeCast(gsiPlayer, earthSpike)
					and fhtReal and not fightHarassTarget.hUnit:IsHexed()
					and HIGH_USE(gsiPlayer, earthSpike, highUse - earthSpike:GetManaCost(), fhtPercHp) then
				local crowdingCenter, crowdedRating
						= CROWDED_RATING(fightHarassTarget.lastSeen.location, SET_HERO_ENEMY)
				USE_ABILITY(gsiPlayer, earthSpike, fightHarassTarget, 400, nil)
				return;
			end
			if AbilityLogic_AbilityCanBeCast(gsiPlayer, hex)
					and fhtReal and not fightHarassTarget.hUnit:IsStunned()
					and HIGH_USE(gsiPlayer, hex, highUse - hex:GetManaCost(), fhtPercHp) then
				USE_ABILITY(gsiPlayer, hex, fightHarassTarget, 400, nil)
				return;
			end
		end
		if currActivityType > ACTIVITY_TYPE.CAREFUL
				and nearbyEnemies[1] and AbilityLogic_AbilityCanBeCast(gsiPlayer, earthSpike)
				and HIGH_USE(gsiPlayer, earthSpike, highUse - earthSpike:GetManaCost(), playerHealthPercent) then
			USE_ABILITY(gsiPlayer, earthSpike, nearbyEnemies[1], 400, nil)
			return;
		end
		if currTask == push_handle and AbilityLogic_AbilityCanBeCast(gsiPlayer, earthSpike)
				and HIGH_USE(gsiPlayer, earthSpike, highUse - earthSpike:GetManaCost(), 1-playerHealthPercent)
				and (not gsiPlayer.theoreticalDanger or gsiPlayer.theoreticalDanger < 0) then
			local nearbyCreeps = Set_GetNearestEnemyCreepSetAtLaneLoc(
					gsiPlayer.lastSeen.location, Map_GetBaseOrLaneLocation(gsiPlayer.lastSeen.location)
				)
			if nearbyCreeps then
				-- TODO USE_ABILITY queue with move to loc facing from vector between two random creeps
				USE_ABILITY(gsiPlayer, earthSpike, nearbyCreeps.center, 400, nil)
				return;
			end
		end
		local foDKillCounterIndex = gsiPlayer.hUnit:GetModifierByName("modifier_lion_finger_of_death_kill_counter")
		if AbilityLogic_AbilityCanBeCast(gsiPlayer, foD) and fhtReal 
				and gsiPlayer.lastSeenMana > foD:GetManaCost()
				and AbilityLogic_AllowOneHitKill(
						gsiPlayer,
						fightHarassTarget,
						foD:GetCastRange(),
						foD:GetSpecialValueInt("damage")
							+ (foDKillCounterIndex and gsiPlayer.hUnit:GetModifierStackCount(foDKillCounterIndex)
								or 0)*LION_FOD_COUNT_DMG,
						foD:GetDamageType()
					) then
			USE_ABILITY(gsiPlayer, foD, fightHarassTarget, 400, nil)
			return;
		end
		if currActivityType <= ACTIVITY_TYPE.CAREFUL
				and nearbyEnemies[1] and AbilityLogic_AbilityCanBeCast(gsiPlayer, drain)
				and HIGH_USE(gsiPlayer, earthSpike, highUse - drain:GetManaCost(), playerHealthPercent) then
			USE_ABILITY(gsiPlayer, drain, nearbyEnemies[1], 400, nil)
			return;
		end
	end,
}

local hero_access = function(key) return d[key] end

do
	HeroData_SetHeroData(hero_data, abilities, hero_access)
end
