local hero_data = {
	"weaver",
	{2, 3, 2, 1, 2, 4, 2, 3, 3, 3, 6, 4, 1, 1, 8, 1, 4, 9, 12},
	{
		"item_circlet","item_branches","item_quelling_blade","item_branches","item_slippers","item_tango","item_wraith_band","item_boots_of_elves","item_gloves","item_boots","item_power_treads","item_javelin","item_maelstrom","item_magic_wand","item_dragon_lance","item_mithril_hammer","item_ogre_axe","item_black_king_bar","item_lesser_crit","item_greater_crit","item_staff_of_wizardry","item_crown","item_crown","item_gem","item_gungir","item_ultimate_orb","item_ultimate_orb","item_skadi","item_ultimate_orb","item_pers","item_sphere","item_claymore","item_aghanims_shard","item_reaver",
	},
	{ {1,1,1,1,1,}, {1,1,1,1,1,}, 0.1 },
	{
		"The Swarm","Shukuchi","Geminate Attack","Time Lapse","+50 Shukuchi Damage","+9 Strength","+20 Mana Break","+2 Swarm Attacks to Kill","+90 Geminate Attack Damage","+0.5 Swarm Armor Reduction","+2 Shukuchi Charges","+1 Geminate Attack",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_HERO_SELECTION then return hero_data end

local abilities = {
		[0] = {"weaver_the_swarm", ABILITY_TYPE.NUKE + ABILITY_TYPE.DEGEN + ABILITY_TYPE.AOE},
		{"weaver_shukuchi", ABILITY_TYPE.NUKE + ABILITY_TYPE.INVIS + ABILITY_TYPE.MOBILITY},
		{"weaver_geminate_attack", ABILITY_TYPE.PASSIVE},
		[5] = {"weaver_time_lapse", ABILITY_TYPE.HEAL},
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
local CURR_TASK_SCORE = Task_GetCurrentTaskScore
local CAN_BE_CAST = AbilityLogic_AbilityCanBeCast
local currentActivityType = Blueprint_GetCurrentTaskActivityType
local currentTask = Task_GetCurrentTaskHandle
local HIGH_USE = AbilityLogic_HighUseAllowOffensive
local VEC_POINT_DISTANCE = Vector_PointDistance
local min = math.min

local fight_harass_handle = FightHarass_GetTaskHandle()
local push_handle = Push_GetTaskHandle()

local t_player_abilities = {}

local ABILITY_USE_RANGE = 600
local OUTER_RANGE = 1400

local SWARM_TRAVEL_SPEED = 750

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
			return;
		end
		local playerAbilities = t_player_abilities[gsiPlayer.nOnTeam]
		local swarm = playerAbilities[1]
		local shukuchi = playerAbilities[2]
		local geminate = playerAbilities[3]
		local timeLapse = playerAbilities[4]
		local highUse = gsiPlayer.highUseManaSimple
		local playerHealthPercent = gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth
		local isInvis = gsiPlayer.hUnit:IsInvisible()

		if CAN_BE_CAST(gsiPlayer, geminate) then
			INCENTIVISE(gsiPlayer, fight_harass_handle, 14, 9)
		end

		local currActivityType = currentActivityType(gsiPlayer)
		local currTask = currentTask(gsiPlayer)
		local nearbyEnemies, outerEnemies
				= Set_GetEnemyHeroesInLocRadOuter(gsiPlayer.lastSeen.location, ABILITY_USE_RANGE, OUTER_RANGE, 6)
		local fht = Task_GetTaskObjective(gsiPlayer, fight_harass_handle)
		local fhtReal = fht
				and fht.hUnit.IsNull and not fht.hUnit:IsNull()
		local fhtPercHp = fht
				and fht.lastSeenHealth / fht.maxHealth or 1.0
		local arbitraryEnemy = nearbyEnemies[1] or outerEnemies[1]

		if arbitraryEnemy and CAN_BE_CAST(gsiPlayer, timeLapse) then
			local currTaskScore = CURR_TASK_SCORE(gsiPlayer)
			local recentDmgTaking = Analytics_GetTotalDamageInTimeline(gsiPlayer.hUnit)
			local score = min(400, 600*(1-playerHealthPercent)*recentDmgTaking
					/ gsiPlayer.maxHealth)
					* (gsiPlayer.hUnit:HasModifier("modifier_weaver_shukuchi")
							and 0.33 or 1)
			-- TODO the theory behind scoring 600*(percentage of max health in damage taken recently)
			-- -| is to score above any use_ability queued abilities. I even doubt this is set up
			-- -| correctly (not just per maths, but also variables passed to USE_ABILITY) as is.
			if playerHealthPercent < 0.75 and score > currTaskScore*1.1
					and (
							playerHealthPercent < 0.33
							and recentDmgTaking > gsiPlayer.lastSeenHealth/5
							or recentDmgTaking > playerHealthPercent*0.5
						) then
				USE_ABILITY(gsiPlayer, timeLapse, nil, 500, nil)
			end
		end

		if currActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION then
			if gsiPlayer.hUnit:HasModifier("modifier_weaver_shukuchi") then
				-- TODO work around while UseAbility combos unfinished
				gsiPlayer.attackRange = 0
				INCENTIVISE(gsiPlayer, fight_harass_handle, 60, 30)
			end
			if fhtReal and not isInvis and CAN_BE_CAST(gsiPlayer, swarm)
					and HIGH_USE(gsiPlayer, swarm, highUse - swarm:GetManaCost(), fhtPercHp) then
				local extrapolatedTime
						= 0.3 + VEC_POINT_DISTANCE(
								gsiPlayer.lastSeen.location,
								fht.lastSeen.location
							) / SWARM_TRAVEL_SPEED
				local extrapolatedLoc = fht.hUnit:GetExtrapolatedLocation(extrapolatedTime)

				USE_ABILITY(gsiPlayer, swarm, extrapolatedLoc, 500, nil)
				return;
			end
			if fhtReal and (not geminate:IsCooldownReady() or
					Math_PointToPointDistance2D(gsiPlayer.lastSeen.location, fht.lastSeen.location)
						> gsiPlayer.attackRange
					) then
				if CAN_BE_CAST(gsiPlayer, shukuchi)
						and HIGH_USE(gsiPlayer, shukuchi, highUse - shukuchi:GetManaCost(), fhtPercHp) then
					USE_ABILITY(gsiPlayer, shukuchi, nil, 400, nil)
					-- TODO work around while UseAbility combos unfinished
					gsiPlayer.attackRange = 50
					INCENTIVISE(gsiPlayer, fight_harass_handle, 60, 30)
					return;
				end
			end
		end
		if currActivityType > ACTIVITY_TYPE.CAREFUL then
			if nearbyEnemies[1] and CAN_BE_CAST(gsiPlayer, shukuchi)
					and HIGH_USE(gsiPlayer, shukuchi, highUse - shukuchi:GetManaCost(), playerHealthPercent) then
				if nearbyEnemies[1].hUnit.IsNull and not nearbyEnemies[1].hUnit:IsNull() then
					USE_ABILITY(gsiPlayer, shukuchi, nil, 500, nil)
					return;
				end
			end
		end
	end,
}

local hero_access = function(key) return d[key] end

do
	HeroData_SetHeroData(hero_data, abilities, hero_access)
end
