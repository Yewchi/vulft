local hero_data = {
	"bristleback",
	{2, 3, 2, 1, 2, 4, 2, 3, 3, 6, 3, 4, 1, 1, 8, 1, 4, 10, 12},
	{
		"item_quelling_blade","item_magic_stick","item_branches","item_branches","item_tango","item_enchanted_mango","item_ring_of_health","item_vanguard","item_boots","item_soul_ring","item_magic_wand","item_belt_of_strength","item_gloves","item_power_treads","item_point_booster","item_ogre_axe","item_staff_of_wizardry","item_ultimate_scepter","item_platemail","item_pers","item_energy_booster","item_lotus_orb","item_voodoo_mask","item_bloodstone","item_aghanims_shard","item_reaver","item_heart","item_assault","item_black_king_bar","item_ultimate_scepter_2",
	},
	{ {3,3,3,2,1,}, {3,3,3,2,1,}, 0.1 },
	{
		"Viscous Nasal Goo","Quill Spray","Bristleback","Warpath","+20 Damage","+1.5 Mana Regen","+150 Goo Cast Range","+8%/+8% Bristleback Back/Side Damage Reduction","+25 Health Regen","+25 Quill Stack Damage","+12% Spell Lifesteal","+18 Warpath Damage Per Stack",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"bristleback_viscous_nasal_goo", ABILITY_TYPE.SLOW},
		{"bristleback_quill_spray", ABILITY_TYPE.NUKE + ABILITY_TYPE.AOE},
		{"bristleback_bristleback", ABILITY_TYPE.PASSIVE},
		[5] = {"bristleback_warpath", ABILITY_TYPE.PASSIVE},
}

local ZEROED_VECTOR = ZEROED_VECTOR
local playerRadius = Set_GetEnemyHeroesInPlayerRadius
local ENCASED_IN_RECT = Set_GetEnemiesInRectangle
local CURRENT_TASK = Task_GetCurrentTaskHandle
local CAN_BE_CAST = AbilityLogic_AbilityCanBeCast
local USE_ABILITY = UseAbility_RegisterAbilityUseAndLockToScore
local VEC_POINT_DISTANCE = Vector_PointDistance2D
local VEC_UNIT_DIRECTIONAL = Vector_UnitDirectionalPointToPoint2D
local ACTIVITY_TYPE = ACTIVITY_TYPE
local HANDLE_AUTOCAST_GENERIC = AbilityLogic_HandleAutocastGeneric
local CURRENT_ACTIVITY_TYPE = Blueprint_GetCurrentTaskActivityType
local TASK_OBJECTIVE = Task_GetTaskObjective
local HEALTH_PERCENT = Unit_GetHealthPercent
local SET_ENEMY_HERO = SET_ENEMY_HERO
local ABILITY_LOCKED = UseAbility_IsPlayerLocked
local CROWDED_RATING = Set_GetCrowdedRatingToSetTypeAtLocation
local INVALID_UNIT = Unit_IsNullOrDead
local NEARBY_OUTER = Set_GetEnemyHeroesInPlayerRadiusAndOuter
local NEARBY_ENEMY = Set_GetEnemyHeroesInPlayerRadius
local HIGH_USE = AbilityLogic_HighUseAllowOffensive
local SPELL_SUCCESS = AbilityLogic_CastOnTargetWillSucceed
local min = math.min
local max = math.max
local sqrt = math.sqrt

local Q_S_RANGE = 700
local V_G_RANGE = 600

local ABILITY_USE_RANGE = 675
local OUTER_RANGE = 1600

local fight_harass_handle = FightHarass_GetTaskHandle()

local function cast_goo(gsiPlayer, hAbility, target, score, comboIndentifier)
	if gsiPlayer.hUnit:HasScepter() then
		USE_ABILITY(gsiPlayer, hAbility, nil, score, comboIdentifier)
	end
	USE_ABILITY(gsiPlayer, hAbility, target, score, comboIdentifier)
end

local t_player_abilities = {}

local d
d = {
	["GetQuillsDamageTotal"] = function(hAbility, currentStacks, countCasting, timeRemaining)
		--print("bristleback quills spray level", hAbility:GetLevel())
		local countCasting = min(
				(timeRemaining - hAbility:GetCooldownTimeRemaining()) * hAbility:GetCooldown(),
				countCasting
			)
		local qsLevel = hAbility:GetLevel()
		local baseDmg = d.quill_spray_base_damage[qsLevel]
		local stackDmg = d.quill_spray_stack_damage[qsLevel]
		local approxStackReductionFactor = 1.05 - hAbility:GetCooldown() / d.quill_spray_stack_duration[qsLevel]
		local totalDmg = 0
		for i=1,countCasting do
			totalDmg = totalDmg + baseDmg + currentStacks*stackDmg
			currentStacks = (currentStacks + 1) * approxStackReductionFactor
		end
		return totalDmg
	end,
	["quill_spray_base_damage"] = {[0] = 0, 25, 45, 65, 85},
	["quill_spray_stack_damage"] = {[0] = 0, 28, 30, 32, 34},
	["quill_spray_stack_duration"] = {[0] = 14, 14, 14, 14, 14},
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
		local thisPlayerAbilities = t_player_abilities[gsiPlayer.nOnTeam]
		local goo = thisPlayerAbilities[1]
		local quills = thisPlayerAbilities[2]
		--print("bb durations", t_player_abilities[gsiPlayer.nOnTeam][1]:GetDuration(), t_player_abilities[gsiPlayer.nOnTeam][2]:GetDuration())
		--print(quills:GetCastRange())
		if UseAbility_IsPlayerLocked(gsiPlayer) then
			return;
		end
		local hUnit = gsiPlayer.hUnit
		local thisPlayerAbilities = t_player_abilities[gsiPlayer.nOnTeam]
		local goo = thisPlayerAbilities[1]
		local quills = thisPlayerAbilities[2]
		
		local gooCanCast = CAN_BE_CAST(gsiPlayer, goo)
		local quillsCanCast = CAN_BE_CAST(gsiPlayer, quills)

		if not (gooCanCast or quillsCanCast) then
			return;
		end

		local highUse = gsiPlayer.highUseManaSimple
		local playerHpp = gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth
		local playerLoc = gsiPlayer.lastSeen.location
		local nearbyEnemies, outerEnemies
				= NEARBY_OUTER(playerLoc, ABILITY_USE_RANGE, OUTER_RANGE, 1)
		local currTask = CURRENT_TASK(gsiPlayer)
		local currActivityType = CURRENT_ACTIVITY_TYPE(gsiPlayer)
		local fht = TASK_OBJECTIVE(gsiPlayer, fight_harass_handle)
		local fhtReal = fht and not INVALID_UNIT(fht)
		local fhtHpp = fhtReal and fht.lastSeenHealth / fht.maxHealth
		local fhtLoc = fhtReal and fht.lastSeen.location
		local distToFht = fhtReal and VEC_POINT_DISTANCE(playerLoc, fhtLoc)
		if quillsCanCast then
			local closestEnemy = Set_GetSetUnitNearestToLocation(playerLoc, nearbyEnemies)
			if fhtReal and currActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION
					and HIGH_USE(gsiPlayer, quills, highUse, fhtHpp)
					and VEC_POINT_DISTANCE(playerLoc, fhtLoc) < Q_S_RANGE*0.98 then
				USE_ABILITY(gsiPlayer, quills, nil, 400, nil)
				return;
			elseif currActivityType >= ACTIVITY_TYPE.FEAR
					and gsiPlayer.lastSeenMana > quills:GetManaCost() then
				local nearestEnemy, nearestDist = Set_GetSetUnitNearestToLocation(playerLoc, nearbyEnemies)
				if nearestDist < Q_S_RANGE*0.98 then
					USE_ABILITY(gsiPlayer, quills, nil, 400, nil)
					return;
				end
			end
		end
		if gooCanCast and fhtReal
				and (fht.currentMovementSpeed / gsiPlayer.currentMovementSpeed > 0.5 or fht.lastSeenHealth > 400)
				and HIGH_USE(gsiPlayer, goo, highUse*2, fhtHpp)
				and distToFht < V_G_RANGE*0.98 then
			cast_goo(gsiPlayer, goo, fht, 400, nil)
			return;
		end
		-- The smartest or dumbest part of this bot script
		local manaLossGoo = goo:GetManaCost() / goo:GetCooldown()
		local manaLossQuills = quills:GetManaCost() / quills:GetCooldown()
		local manaLossConstantCastRegen = manaLossGoo + manaLossQuills + gsiPlayer.hUnit:GetManaRegen()
		local danger = Analytics_GetTheoreticalDangerAmount(gsiPlayer)
		if danger < 1 and fhtReal and (nearbyEnemies[1] or outerEnemies[1]
						or FightClimate_ShouldInitiate
				) then -- TODO
			local valid, totalDps = GSI_GetTotalDpsOfUnits(nearbyEnemies, outerEnemies)
			--print("total dps", valid, totalDps)
			if not valid then
				return;
			end
			local goCrazyTime = gsiPlayer.lastSeenMana / manaLossConstantCastRegen
			local goCrazyGoo = (goCrazyTime - goo:GetCooldown()) / goo:GetCooldown()
			local goCrazyQuills = (goCrazyTime - quills:GetCooldown()) / quills:GetCooldown()
			local quillStacks = fhtReal and fht.hUnit:GetModifierByName("modifier_bristleback_quill_spray")
			quillStacks = quillStacks and fht.hUnit:GetModifierStackCount(quillStacks) or 0
			--print("unit quill stacks", quillStacks)
			local nearbyAllies = Set_GetAlliedHeroesInPlayerRadius(gsiPlayer, 1400)
			local nearbyAlliesDampeningDmg = sqrt(1 - min(5, 0.15*#nearbyAllies))
			local totalDamageInTimeline = Analytics_GetTotalDamageInTimeline(gsiPlayer.hUnit)
			local surviveTime = gsiPlayer.lastSeenHealth
					/ max(totalDps*nearbyAlliesDampeningDmg*Unit_GetArmorPhysicalFactor(gsiPlayer),
							totalDamageInTimeline
						)
			local goCrazyDmg = d.GetQuillsDamageTotal(quills, quillStacks, goCrazyQuills, surviveTime)
			goCrazyDmg = Unit_GetArmorPhysicalFactor(fht)*goCrazyDmg
			local crazyWorthRatio = goCrazyDmg / fht.lastSeenHealth
			crazyWorthRatio = crazyWorthRatio < 150 and crazyWorthRatio or 150
			--print(crazyWorthRatio, goCrazyDmg, surviveTime)
			if crazyWorthRatio > 1 then
				--print("incentivising bristle for go crazy")
				Task_IncentiviseTask(gsiPlayer, fight_harass_handle, max(20, surviveTime*2)*crazyWorthRatio, 5)
				if quillsCanCast and distToFht < Q_S_RANGE*0.98 then
					USE_ABILITY(gsiPlayer, quills, nil, 400, nil)
					return;
				elseif gooCanCast and distToFht < V_G_RANGE*0.98 then
					cast_goo(gsiPlayer, goo, fht, 400, nil)
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
