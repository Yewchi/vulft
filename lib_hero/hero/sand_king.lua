local hero_data = {
	"sand_king",
	{1, 2, 2, 5, 2, 4, 2, 1, 1, 1, 3, 4, 3, 3, 7, 3, 4, 9, 12},
	{
		"item_quelling_blade","item_tango","item_gauntlets","item_magic_stick","item_branches","item_branches","item_branches","item_boots","item_magic_wand","item_tranquil_boots","item_belt_of_strength","item_robe","item_wind_lace","item_ancient_janggo","item_blink","item_headdress","item_point_booster","item_ogre_axe","item_blade_of_alacrity","item_ultimate_scepter","item_ring_of_health","item_cloak","item_boots_of_bearing","item_pipe","item_gem","item_aghanims_shard",
	},
	{ {3,3,3,3,3,}, {3,3,3,3,3,}, 0.1 },
	{
		"Burrowstrike","Sand Storm","Caustic Finale","Epicenter","+20 Sand Storm Damage Per Second","+0.4s Burrowstrike Stun","+125 Sand Storm Radius","+120.0 Caustic Finale Damage","-2.0s Burrowstrike Cooldown","+100/+100 Base/Incremental Radius of Epicenter","+5 Epicenter Pulses","35% Sand Storm Slow and Blind",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"sandking_burrowstrike", ABILITY_TYPE.STUN + ABILITY_TYPE.NUKE + ABILITY_TYPE.AOE + ABILITY_TYPE.MOBILITY + ABILITY_TYPE.UNIT_TARGET + ABILITY_TYPE.POINT_TARGET},
		{"sandking_sand_storm", ABILITY_TYPE.UTILITY + ABILITY_TYPE.AOE + ABILITY_TYPE.NUKE},
		{"sandking_caustic_finale", ABILITY_TYPE.PASSIVE},
		[5] = {"sandking_epicenter", ABILITY_TYPE.NUKE + ABILITY_TYPE.AOE + ABILITY_TYPE.DEGEN + ABILITY_TYPE.SLOW},
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
local VEC_ADD = Vector_Addition
local VEC_SCALAR_MULTIPLY = Vector_ScalarMultiply
local ACTIVITY_TYPE = ACTIVITY_TYPE
local currentActivityType = Blueprint_GetCurrentTaskActivityType
local currentTask = Task_GetCurrentTaskHandle
local HIGH_USE = AbilityLogic_HighUseAllowOffensive
local FOUNTAIN_LOC = Map_GetTeamFountainLocation()
local SPELL_SUCCESS = AbilityLogic_CastOnTargetWillSucceed
local PUNIT_NULLED = pUnit_IsNullOrDead

local fight_harass_handle = FightHarass_GetTaskHandle()
local push_handle = Push_GetTaskHandle()

local t_player_abilities = {}

local ABILITY_USE_RANGE = 700
local OUTER_RANGE = 1600

local EPICENTER_START_RANGE = 500
local EPICENTER_END_RANGE = 750

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
		local burrow = playerAbilities[1]
		local storm = playerAbilities[2]
		local epicenter = playerAbilities[4]
		local highUse = gsiPlayer.highUseManaSimple
		local playerHealthPercent = gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth

		local pUnit = gsiPlayer.hUnit
		local playerLoc = gsiPlayer.lastSeen.location
		local currActivityType = currentActivityType(gsiPlayer)
		local currTask = currentTask(gsiPlayer)
		local nearbyEnemies, outerEnemies
				= Set_GetEnemyHeroesInLocRadOuter(gsiPlayer.lastSeen.location, ABILITY_USE_RANGE, OUTER_RANGE, 6)
		local nearbyAllies
				= Set_GetAlliedHeroesInLocRad(gsiPlayer, gsiPlayer.lastSeen.location,
					ABILITY_USE_RANGE, false
				)
		local fightHarassTarget = Task_GetTaskObjective(gsiPlayer, fight_harass_handle)
		local fhtReal = fightHarassTarget and not PUNIT_NULLED(fightHarassTarget)
		local fhtPercHp = fightHarassTarget
				and fightHarassTarget.lastSeenHealth / fightHarassTarget.maxHealth or 1.0
		local fhtMagicRes = fhtReal
				and SPELL_SUCCESS(gsiPlayer, fightHarassTarget, burrow) or 0
		local fhtLoc = fightHarassTarget and fightHarassTarget.lastSeen.location
		local distToFht = fhtReal and
				Vector_PointDistance(playerLoc, fhtLoc)
		local blink = gsiPlayer.usableItemCache.blink
		local canCastBurrow = AbilityLogic_AbilityCanBeCast(gsiPlayer, burrow)
			
		if currActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION and fightHarassTarget then
			if blink and blink:GetCooldownTimeRemaining() == 0 and pUnit:HasModifier("modifier_sand_king_epicenter")
					and fhtReal and distToFht > (canCastBurrow and burrow:GetCastRange() or 450) then
				local toUnitVec = VEC_UNIT_DIRECTIONAL(playerLoc, fhtLoc)
				local blinkTo = VEC_ADD(
						playerLoc,
						VEC_SCALAR_MULTIPLY(
							toUnitVec,
							distToFht+200
						)
					)
				if IsLocationPassable(blinkTo) and IsLocationPassable(fhtLoc) then
					pUnit:Action_UseAbilityOnLocation(blink, blinkTo)
				else
					pUnit:Action_UseAbilityOnLocation(blink, fhtLoc)
				end
			end
			local crowdingCenter, crowdedRating = CROWDED_RATING(fightHarassTarget.lastSeen.location, SET_HERO_ENEMY)
			local epicenterDamage = epicenter:GetSpecialValueInt("epicenter_damage")
					* epicenter:GetSpecialValueInt("epicenter_pulses")
			local afterEpicenterRemainingHpp =
					(fightHarassTarget.lastSeenHealth - epicenterDamage*fhtMagicRes) / fightHarassTarget.maxHealth
			if AbilityLogic_AbilityCanBeCast(gsiPlayer, epicenter)
					and ( crowdedRating > 1
						or ( fhtMagicRes > 0.33
								and afterEpicenterRemainingHpp < 0.1111*(1+#nearbyAllies)
								and afterEpicenterRemainingHpp > -(gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth)
							)
					) and Math_PointToPointDistance(gsiPlayer.lastSeen.location, fightHarassTarget.lastSeen.location)
							< ( (blink and blink:GetCooldownTimeRemaining() == 0 and blink:GetCastRange() or 0) +
									(burrow:GetCooldownTimeRemaining() == 0 and burrow:GetCastRange()*0.5 or 0) +
									EPICENTER_START_RANGE/2
							)
					and HIGH_USE(gsiPlayer, epicenter, highUse - epicenter:GetManaCost()*crowdedRating, fhtPercHp) then
				USE_ABILITY(gsiPlayer, epicenter, nil, 400, nil)
				return;
			end
			if AbilityLogic_AbilityCanBeCast(gsiPlayer, burrow)
					and ( HIGH_USE(gsiPlayer, burrow, highUse - burrow:GetManaCost(), fhtPercHp)
							or (gsiPlayer.lastSeenMana > burrow:GetManaCost()
								and pUnit:HasModifier("modifer_sand_king_epicenter")
							)
					) and Vector_PointDistance(gsiPlayer.lastSeen.location, fightHarassTarget.lastSeen.location) <
						burrow:GetCastRange()*0.95 then
				USE_ABILITY(gsiPlayer, burrow, fightHarassTarget.lastSeen.location, 400, nil)
				return;
			end
			if AbilityLogic_AbilityCanBeCast(gsiPlayer, storm)
					and (
							(fhtReal and (fightHarassTarget.hUnit:IsStunned() or fightHarassTarget.hUnit:IsRooted()))
						or
							HIGH_USE(gsiPlayer, storm, highUse - storm:GetManaCost()*crowdedRating, fhtPercHp)
					) and Vector_PointDistance(gsiPlayer.lastSeen.location, crowdingCenter) < 200 then
				USE_ABILITY(gsiPlayer, storm, nil, 400, nil)
				return;
			end
		elseif currActivityType > ACTIVITY_TYPE.CAREFUL then
			if nearbyEnemies[1] then
				if not pUnit:IsRooted() and AbilityLogic_AbilityCanBeCast(gsiPlayer, burrow)
						and HIGH_USE(gsiPlayer, burrow, highUse - burrow:GetManaCost(), playerHealthPercent) then
					local burrowRange = burrow:GetCastRange()
					local towardsFountain = VEC_UNIT_DIRECTIONAL(gsiPlayer.lastSeen.location, FOUNTAIN_LOC)
					local fullRangeEscape = VEC_ADD(
							gsiPlayer.lastSeen.location, VEC_SCALAR_MULTIPLY(towardsFountain, burrowRange)
						)
					USE_ABILITY(gsiPlayer, burrow, fullRangeEscape, 400, nil)
					return;
				elseif AbilityLogic_AbilityCanBeCast(gsiPlayer, storm)
						and HIGH_USE(gsiPlayer, storm, highUse - storm:GetManaCost(), playerHealthPercent) then
					USE_ABILITY(gsiPlayer, storm, nil, 400, nil)
					return;
				end
			end
		end
		-- TODO PUSH
	end,
}

local hero_access = function(key) return d[key] end

do
	HeroData_SetHeroData(hero_data, abilities, hero_access)
end
