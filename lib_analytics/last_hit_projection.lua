---- last_hit_projection constants
local FAR_PAST_DELETE_DAMAGE_NODE = 4.0

MINIMUM_RANGE_UNIT_RANGE = 200 -- TODO more correct way of finding if cats projectiles (and do melee units throw a projectile momentarily)
local DUMMY_ATTACKER_FOR_PROJECTILE_MAX = 0xFFFF -- Please do not cast more than 4 million projectiles at once.
local LAST_HIT_DONT_MISS_BUFFER = 0.03 -- To stop heroes attacking at the very same frame of a damage instance

local PLAUSIBLE_CREEP_HP_REGEN_AURA = 2.0 -- Headdress
local HIGHEST_NATURAL_LANE_CREEP_REGEN = 2.0 -- Range creep
local HIGH_EST_EARLY_GAME_TIME_TO_LAND_ATTACK = 1.4 -- With shot-in-the-dark slow heroes, lina was 1.32s
local FAST_NASTY_MOVEMENT_MODIFIER = 1.2
local DEATH_WISH_HP_REGEN_BUFFER = HIGH_EST_EARLY_GAME_TIME_TO_LAND_ATTACK * FAST_NASTY_MOVEMENT_MODIFIER * (HIGHEST_NATURAL_LANE_CREEP_REGEN + PLAUSIBLE_CREEP_HP_REGEN_AURA) 
local RATIO_MINIMUM_TO_AVG_ATTACK = 39/((45+39)/2)
local HERO_PHYSICAL_ATTACK_VARIANCE = 4*(1-RATIO_MINIMUM_TO_AVG_ATTACK)/5 + RATIO_MINIMUM_TO_AVG_ATTACK -- ~~ 0.943 (real min-avg ratio is ~~ 0.92

local DEFAULT_NEAR_FUTURE_HEALTH_PERCENT_TIME = 1.0 -- The time to look ahead for health percent states if none is passed to Analytics_GetNearFutureHealthPercent()

local TRY_KEEP_NODE_AS_FUTURE_BEFORE_LANDING_BUFFER = 0.02

local FightClimate_RegisterRecentHeroAggresion = FightClimate_RegisterRecentHeroAggresion
local UNIT_TYPE_CREEP = UNIT_TYPE_CREEP
local UNIT_TYPE_BUILDING = UNIT_TYPE_BUILDING
local UNIT_TYPE_HERO = UNIT_TYPE_HERO
local TEAM = TEAM
local ENEMY_TEAM = ENEMY_TEAM
local Projectile_GetNextAttackComplete = Projectile_GetNextAttackComplete
local GSI_GetSafeUnit = GSI_GetSafeUnit
local EMPTY_TABLE = EMPTY_TABLE
local GameTime = GameTime

local DEAGRO_UPDATE_PRIORITY
--

-- Many ideas and iterations thrown at the wall. Linear regression of the derivative of health loss was the
-- one I never explored. Solution is a table of incoming attacks and projectiles stored in a linked list
-- time-wise left to right. Units are indexed in another table to their node, for fast anim cycle comparison
-- and

local future_damage_lists = {}
local t_lists_with_recyclable_nodes = {}
local t_next_recyclable_nodes = {}
local t_attacker_to_future_damage_node = {}

local job_domain_analytics

local next_projectile_hunit_ref = 0
local function get_dummy_projectile_hunit_ref()
	next_projectile_hunit_ref = next_projectile_hunit_ref + 1 % DUMMY_ATTACKER_FOR_PROJECTILE_MAX
	return next_projectile_hunit_ref
end

local function indicate_far_past_is_for_recycling()
	local deleteOlderThan = GameTime() - FAR_PAST_DELETE_DAMAGE_NODE
	for atUnit,list in pairs(future_damage_lists) do
		local currNode = list.oldestNode
		local foundOlderThan
		local n = 0
		while(currNode and currNode.timeLanding < deleteOlderThan) do
			n = n + 1 if n > 1000 then print("D", currNode) TEAM_CAPTAIN_UNIT:ActionImmediate_Ping(atUnit:GetLocation().x, atUnit:GetLocation().y, false) future_damage_lists[atUnit] = nil return end
			currNode.prevNode = nil
			--future_damage_lists[atUnit].numAttacks = future_damage_lists[atUnit].numAttacks - 1
			future_damage_lists[atUnit].totalDmgRecently = future_damage_lists[atUnit].totalDmgRecently - currNode.damage
			currNode = currNode.nextNode
		end
		if not currNode then
			future_damage_lists[atUnit] = nil
			return
		end
		currNode.prevNode = nil
		list.oldestNode = currNode
	end
end

local function recycle_or_create_node() -- Breaking this func taught me that Dota may miss the top-level stack dump (recycle_or_create_node was indicating a complaint of "arg#1 not a table", it was an incorrectly spelt table.remove(t_lists_with_ruhcyclubul_nodes).
	-- if #t_next_recyclable_nodes > 0 then
		-- return table.remove(t_next_recyclable_nodes)
	-- elseif #t_lists_with_recyclable_nodes > 0 then
		-- t_next_recyclable_nodes = table.remove(t_lists_with_recyclable_nodes)
		-- return recycle_or_create_node() -- check if there were any elements in that remove
	-- end
	
	-- TURNED OFF -- RARE INCORRECT LOOPBACK CAUSING LEAK -- 
	
	return {}
end

local function insert_new_attack_time_node(atUnit, damage, timeLanding, fromUnit, attackPointPercent) -- Ensure nextNode, prevNode are set at least once (because recycling)
	local new = recycle_or_create_node() 
	new.damage = damage
	new.timeLanding = timeLanding
	new.lastSeenAnimCycle = fromUnit:GetAnimCycle()
	new.fromUnit = fromUnit
	new.attackPointPercent = attackPointPercent
	new.nextNode = nil
	new.prevNode = nil
	
	t_attacker_to_future_damage_node[fromUnit] = new
	
	if not future_damage_lists[atUnit] then
		local newDamageList = {}
		future_damage_lists[atUnit] = newDamageList
		newDamageList.firstNodeFromNow = new
		newDamageList.oldestNode = new
		--newDamageList.numAttacks = 1
		newDamageList.totalDmgRecently = new.damage
		newDamageList.atUnit = atUnit
	else
		local thisUnitDamageList = future_damage_lists[atUnit]
		local currNode = thisUnitDamageList.firstNodeFromNow or thisUnitDamageList.oldestNode
		local n = 0
		while(currNode) do
			n = n + 1 if n > 1000 then print("A") TEAM_CAPTAIN_UNIT:ActionImmediate_Ping(atUnit:GetLocation().x, atUnit:GetLocation().y, false) return end
			if currNode.timeLanding >= timeLanding then
				if currNode.prevNode then
					currNode.prevNode.nextNode = new
					new.prevNode = currNode.prevNode
				end
				new.nextNode = currNode
				currNode.prevNode = new
				if thisUnitDamageList.firstNodeFromNow == currNode then -- new attack landing soonest in future
					thisUnitDamageList.firstNodeFromNow = new
				end
				if thisUnitDamageList.oldestNode == currNode then -- implies list only includes future attacks
					thisUnitDamageList.oldestNode = new
				end
				--thisUnitDamageList.numAttacks = thisUnitDamageList.numAttacks + 1
				thisUnitDamageList.totalDmgRecently = thisUnitDamageList.totalDmgRecently + new.damage
				break
			elseif currNode.nextNode == nil then
				currNode.nextNode = new
				new.prevNode = currNode
				--thisUnitDamageList.numAttacks = thisUnitDamageList.numAttacks + 1
				thisUnitDamageList.totalDmgRecently = thisUnitDamageList.totalDmgRecently + new.damage
				break
			end
			currNode = currNode.nextNode
		end
	end
	new.head = future_damage_lists[atUnit]
end

-- --[[BENCH]]local benchThrottle = Time_CreateThrottle(10)
local function update_current_vantage__job(workingSet) -- Shift to the current future, remove attacks that didn't complete their cycle.
	if workingSet.throttle:allowed() then
		-- if benchThrottle:allowed() then
			-- local sizeTable = 0
			-- local attackerSizeTable = 0
			-- for _,_ in pairs(future_damage_lists) do
				-- sizeTable = sizeTable + 1
			-- end
			-- for _,_ in pairs(t_attacker_to_future_damage_node) do
				-- attackerSizeTable = attackerSizeTable + 1
			-- end
			
			-- print("Size of LHP tables:", sizeTable, attackerSizeTable)
		-- end
		local currTime = GameTime()
		for atUnit,list in pairs(future_damage_lists) do
			local currNode = list.firstNodeFromNow
			local n = 0
			while(currNode) do
				n = n + 1 if n > 1000 then print("B") TEAM_CAPTAIN_UNIT:ActionImmediate_Ping(atUnit:GetLocation().x, atUnit:GetLocation().y, false) return end
				if currNode.timeLanding + TRY_KEEP_NODE_AS_FUTURE_BEFORE_LANDING_BUFFER > currTime then
					break
				end
				list.firstNodeFromNow = currNode.nextNode
				currNode = currNode.nextNode
			end
		end
		local n = 0
		for fromUnit,node in pairs(t_attacker_to_future_damage_node) do
--[DEBUG]]if TEAM==TEAM_DIRE and fromUnit:GetTeam() == TEAM and fromUnit:IsNull() == false and Map_GetLaneValueOfMapPoint(fromUnit:GetLocation()) == MAP_LOGICAL_MIDDLE_LANE then n = n + 1 DebugDrawText(0, 400+15*n, string.format(" t_attacker..[%s]=tL:%.3f ; aC:%.2f @ %s", tostring(fromUnit), node.timeLanding, node.lastSeenAnimCycle, tostring(node.head.atUnit)), 255, 255, 255) end 
			local atUnit = node.head.atUnit
			if fromUnit.GetUnitName then
				local isNullOrDead = Unit_IsNullOrDead(fromUnit)
				-- if fromUnit:IsTower() then print(fromUnit:GetAttackPoint(), fromUnit:GetUnitName(), fromUnit:GetAnimCycle()) end
				-- local switchedTarget = not isNullOrDead and fromUnit:GetAttackTarget() ~= nil and fromUnit:GetAttackTarget() ~= atUnit
				local currAnim = not isNullOrDead and fromUnit:GetAnimCycle() or 0.0 -- process any completions or cancels of attack animations, or if the unit is null, force clean-up.
				if currAnim-0.005 > node.attackPointPercent then -- Already hit or released
					--if a == 1503 or a == 1504 or a == 1505 then print("anim was attack") else print('anim was not attack') end
					--if TEAM_CAPTAIN_UNIT == GetBot() then print("AP complete. Hit from now is", node.timeLanding - currTime, "attack range is", fromUnit:GetAttackRange(), fromUnit) end
--[DEBUG]]if VERBOSE and not fromUnit:IsNull() then DebugDrawCircle(fromUnit:GetLocation(), 10, 255, 0, 255) end
					t_attacker_to_future_damage_node[fromUnit] = nil -- Allow any new attacks (below attack point) to be registered
				elseif currAnim+0.015 < node.lastSeenAnimCycle or isNullOrDead --[[or switchedTarget]] then
					-- print(not isNullOrDead and fromUnit:GetUnitName(), "cancelled attack. switch:", switchedTarget, "lastSeenAnimCycle:", node.lastSeenAnimCycle)
--[DEBUG]]if VERBOSE and not fromUnit:IsNull() then DebugDrawCircle(fromUnit:GetLocation(), 10, 255, 255, 255) end			
					if node.head.firstNodeFromNow == node then -- If this stopped attack was the next in time, update to the next attack
						node.head.firstNodeFromNow = node.nextNode
					end
					if node.head.oldestNode == node then
						node.head.oldestNode = node.nextNode
					end
					if node.prevNode then
						node.prevNode.nextNode = node.nextNode
					end
					if node.nextNode then 
						node.nextNode.prevNode = node.prevNode
					end
					
					if node.head.firstNodeFromNow == nil then
						future_damage_lists[atUnit] = nil
					end
					
					t_attacker_to_future_damage_node[fromUnit] = nil
					--if Map_GetLaneValueOfMapPoint(fromUnit:GetLocation()) == MAP_LOGICAL_MIDDLE_LANE then print(fromUnit, "open to attack -- cancelled", fromUnit:GetUnitName()) end
					table.insert(t_next_recyclable_nodes, node)
				end
				node.lastSeenAnimCycle = currAnim
			end
		end
	end
end

local function create_future_damage_lists__job(workingSet)
	if workingSet.throttle:allowed() then
		local sets = Set_NumericalIndexUnion( -- Temporary solution
					Set_GetCreepSetsNearAlliedHeroes(), Set_NumericalIndexUnion(
						Set_GetEnemyHeroSetsNearAlliedHeroes(), Set_GetTowersNearAlliedHeroes()
					)
				)
		indicate_far_past_is_for_recycling()
		
		--if DEBUG and DEBUG_BotIsTheIntern and sets then Util_TablePrint(sets) DEBUG_KILLSWITCH = 0 end
		local sendOneUnagroablePushAlert = true -- push_lane taking advantage of full attack check
		local foundOneLowHealthAttackingTower = false
		local DEBUGinternTarget = not TEAM_IS_RADIANT and
				Task_GetTaskObjective(GSI_GetTeamPlayers(TEAM)[4], FarmLane_GetTaskHandle()) or {}
--[DEBUG]]local n = 0
		for i=1,#sets,1 do
			local thisSetUnits = sets[i].units
			local currTime = GameTime()
			local setSize = #thisSetUnits
			-- if DEBUG and thisSetUnits[1] and thisSetUnits[1].dotaType == HERO_ENEMY then Util_TablePrint(thisSetUnits) end
			--if thisSetUnits == nil then print("line ~215 lhp killed") DEBUG_KILLSWITCH = true Util_TablePrint(sets) end -- DEV NOTE Cause of inf loop was an early return on creep found in Set_GetEnemiesInRectangle breaking recycle_empty's validity
			--print("FUTURE", GameTime())
			for i=1,setSize,1 do
			--local DEBUGunitTrackingOn = false
				local gsiUnit = thisSetUnits[i]
--				if not Unit_IsNullOrDead(gsiUnit) and gsiUnit.hUnit:GetAttackTarget() == DEBUGinternTarget.hUnit then
--					DEBUGunitTrackingOn = true
--					--print("future damage1:", gsiUnit.shortName, "->", DEBUGinternTarget.hUnit, true)
--				end
--[DEBUG]]local yeah = currTime - gsiUnit.hUnit:GetLastAttackTime() > (1 - gsiUnit.attackPointPercent) * gsiUnit.hUnit:GetSecondsPerAttack()
--[DEBUG]]if TEAM==TEAM_DIRE and gsiUnit.hUnit:GetTeam() == TEAM and gsiUnit.hUnit:IsNull() == false and Map_GetLaneValueOfMapPoint(gsiUnit.hUnit:GetLocation()) == MAP_LOGICAL_MIDDLE_LANE then n = n + 1 DebugDrawText(0, 600+15*n, string.format("[%s]: %.3f > %.3f", tostring(gsiUnit.hUnit), currTime - gsiUnit.hUnit:GetLastAttackTime(), (1 - gsiUnit.attackPointPercent) * gsiUnit.hUnit:GetSecondsPerAttack()), yeah and 100 or 255, yeah and 255 or 100, 255) end
				if not Unit_IsNullOrDead(gsiUnit) then 
--					if DEBUGunitTrackingOn then
--						--print("future damage2:", not t_attacker_to_future_damage_node[gsiUnit.hUnit], GSI_UnitCanStartAttack(gsiUnit))
--					end
					if not t_attacker_to_future_damage_node[gsiUnit.hUnit] and GSI_UnitCanStartAttack(gsiUnit) then -- true if the unit is not charging up an attack and we exceeded the attack backswing time from the previous attack execution
						local hUnitAttacked, timeTilAttackLands = Projectile_GetNextAttackComplete(gsiUnit)
--						if DEBUGunitTrackingOn then
--							--print("future damage3:", hUnitAttacked, timeTilAttackLands)
--						end
						if timeTilAttackLands then
							if hUnitAttacked:IsBuilding() and sendOneUnagroablePushAlert and gsiUnit.team == TEAM and gsiUnit.creepType ~= CREEP_TYPE_SIEGE then
								if setSize > 1
										or setSize == 1 and gsiUnit.lastSeenHealth > hUnitAttacked:GetAttackDamage()*3 then
									PushLane_InformUnagroablePush(hUnitAttacked)
									sendOneUnagroablePushAlert = false
								else
									foundOneLowHealthAttackingTower = true
								end
							end
							-- Inform friendly heroes to prioritize deagroing towers
							if hUnitAttacked:IsHero() then
								if gsiUnit.type == UNIT_TYPE_HERO then
									local gsiAttacked = Unit_GetSafeUnit(hUnitAttacked)
									if gsiAttacked then
										FightClimate_RegisterRecentHeroAggression(gsiUnit, gsiAttacked, false)
									end
								elseif hUnitAttacked:GetTeam() == TEAM then
									if gsiUnit.type == UNIT_TYPE_BUILDING then
										if VERBOSE then VEBUG_print(string.format("lhp: triggering deagro priority for %s", hUnitAttacked:GetUnitName())) end
										DEAGRO_UPDATE_PRIORITY(GSI_GetPlayerNumberOnTeam(hUnitAttacked:GetPlayerID()))
									end
								end
							end
							-- Insert the attack in landing time order
							local actualDamage = Lhp_GetActualFromUnitToUnitAttackOnce(gsiUnit.hUnit, hUnitAttacked)
--							if DEBUGunitTrackingOn then
--								--print("future damage3:", hUnitAttacked, actualDamage, timeTilAttackLands, currTime, timeTilAttackLands+currTime, gsiUnit.hUnit, gsiUnit.attackPointPercent)
--								DebugDrawLine(hUnitAttacked:GetLocation(), gsiUnit.lastSeen.location, 100, 255, 255)
--							end
							if VERBOSE and hUnitAttacked:IsBuilding() then print("building dmg incoming", hUnitAttacked:GetLocation(), actualDamage, timeTilAttackLands) end
							insert_new_attack_time_node(hUnitAttacked, actualDamage, timeTilAttackLands + currTime, gsiUnit.hUnit, gsiUnit.attackPointPercent)
							-- Increment the flagging table for any players under attack (triggers consider drop-agro movement)
						end
					end
--					if DEBUGtrackingOn and gsiUnit == DEBUGinternTarget then
--						DebugDrawText(800, 400, ""..Unit_GetTimeTilNextAttackStart(gsiUnit), 255, 255, 255)
--					end
--					if DEBUGtrackingOn then DebugDrawCircle(gsiUnit.lastSeen.location, 30, Unit_GetTimeTilNextAttackStart(gsiUnit)*80, Unit_GetTimeTilNextAttackStart(gsiUnit)*80, 250) end
				end
			end
		end
	end
end

function Analytics_RegisterAnalyticsJobDomainToLhp(analyticsJobDomain)
	job_domain_analytics = analyticsJobDomain
	DEAGRO_UPDATE_PRIORITY = Deagro_UpdatePriority
	Analytics_RegisterAnalyticsJobDomainToLhp = nil
end

function Analytics_CreateUpdateLastHitProjectionCurrentVantage()
	job_domain_analytics:RegisterJob(
			update_current_vantage__job,
			{["throttle"] = Time_CreateThrottle(0.00)},
			"JOB_UPDATE_LHP_CURRENT_VANTAGE"
		)
	Analytics_CreateUpdateLastHitProjectionCurrentVantage = nil
end

function Analytics_CreateUpdateLastHitProjectionFutureDamageLists()
	job_domain_analytics:RegisterJob(
			create_future_damage_lists__job,
			{["throttle"] = Time_CreateThrottle(0.00)}, 
			"JOB_UPDATE_LHP_FUTURE_DAMAGE_LISTS"
		)
	Analytics_CreateUpdateLastHitProjectionCurrentVantage = nil
end

local BFURY_CREEP_DMG_MELEE = 15
local BFURY_CREEP_DMG_RANGED = 4
local HATCHET_CREEP_DMG_MELEE = 12
local HATCHET_CREEP_DMG_RANGED = 4
function Lhp_GetActualFromUnitToUnitAttackOnce(hUnitAttacking, hUnitAttacked) -- Primative
	if hUnitAttacking:IsHero() then
		local attackDmg = hUnitAttacking:GetAttackDamage()
		local itemSlot = hUnitAttacking:FindItemSlot("item_bfury")
		if itemSlot >= 0 and itemSlot <= ITEM_END_INVENTORY_INDEX
				and hUnitAttacking:GetItemInSlot(itemSlot):IsCooldownReady() then
			attackDmg = attackDmg + (hUnitAttacking:GetAttackRange() > 350
					and BFURY_CREEP_DMG_RANGED or BFURY_CREEP_DMG_MELEE)
			--print(hUnitAttacking:GetUnitName(), "has bfury dmg to", attackDmg)
		else
			itemSlot = hUnitAttacking:FindItemSlot("item_quelling_blade")
			if itemSlot >= 0 and itemSlot <= ITEM_END_INVENTORY_INDEX
						and hUnitAttacking:GetItemInSlot(itemSlot):IsCooldownReady() then
				attackDmg = attackDmg + (hUnitAttacking:GetAttackRange() > 350
						and HATCHET_CREEP_DMG_RANGED or HATCHET_CREEP_DMG_MELEE)
				--print(hUnitAttacking:GetUnitName(), "has hatchet dmg to", attackDmg)
			end
		end
		return hUnitAttacked:GetActualIncomingDamage(
				attackDmg
					* hUnitAttacking:GetAttackCombatProficiency(hUnitAttacked), 
				DAMAGE_TYPE_PHYSICAL
			)
	end
	return hUnitAttacked:GetActualIncomingDamage(hUnitAttacking:GetAttackDamage()
			* hUnitAttacking:GetAttackCombatProficiency(hUnitAttacked), 
			DAMAGE_TYPE_PHYSICAL
		)
end

function Lhp_AttackNowForBestLastHit(gsiPlayer, gsiUnit) -- Requires units are not dead nor null
	local currTime = GameTime()
	local currNode = future_damage_lists[gsiUnit.hUnit] and future_damage_lists[gsiUnit.hUnit].firstNodeFromNow
	local timeProgressedHealth = gsiUnit.lastSeenHealth - Lhp_GetActualFromUnitToUnitAttackOnce(gsiPlayer.hUnit, gsiUnit.hUnit)*HERO_PHYSICAL_ATTACK_VARIANCE + DEATH_WISH_HP_REGEN_BUFFER
	local attackNowProjectileLandTime = Projectile_TimeToLandProjectile(gsiPlayer, gsiUnit)
	local landingTimeOfAttackNow = currTime + attackNowProjectileLandTime
	local anyTowersDecrement = 0 -- Tower damage needs an overzealous standing position when it's not time to attack. (We do not project forwards further than the current flying attacks and the currently animated/predicted based on last-attack-time attacks)
	if timeProgressedHealth < 0 then
		return true, 0
	end
	local n = 0
	local m = 1
--[[DEBUG]]if DEBUG and DEBUG_IsBotTheIntern() and gsiUnit.team == ENEMY_TEAM then DebugDrawText(0, 250, string.format(" %.3f-[%s]: %d, %d, %.3f", currTime, gsiPlayer.shortName, gsiUnit.lastSeenHealth, timeProgressedHealth, landingTimeOfAttackNow), 255, 255, 255) end
	while(currNode) do
		 n = n + 1 -- Running determine real future attacks (for a nasty est of how long till death if the target will not die from the future attacks plus our own)
--[DEBUG]]m = m + 1 if m > 1000 then print("C") TEAM_CAPTAIN_UNIT:ActionImmediate_Ping(gsiUnit:GetLocation().x, gsiUnit:GetLocation().y, false) return end
		timeProgressedHealth = timeProgressedHealth - currNode.damage
		if bUnit_IsTower(currNode.fromUnit) then anyTowersDecrement = -1.5 end
--[[DEBUG]]if DEBUG and DEBUG_IsBotTheIntern() and gsiUnit.team == ENEMY_TEAM then DebugDrawText(0, 250 + 150*(currNode.timeLanding - currTime), string.format(" %.3f-[%s]: %d, %d, %s, %.2f", currNode.timeLanding, tostring(currNode.fromUnit), timeProgressedHealth, currNode.damage, currNode.fromUnit:GetUnitName(), currNode.fromUnit:GetAnimCycle()), (landingTimeOfAttackNow > currNode.timeLanding and 0 or 255), 255, 255) end
		if timeProgressedHealth < 0 then
			if currNode.timeLanding < landingTimeOfAttackNow then -- Return AttackNow! if it leads to a future with a < 0 HP creep, and that future was before our attack would land
				return true, 0
			else
				-- 1.5/n I think I put it there because it makes bots stand further away when there are only a few creeps attacking a unit "how long until I need to be in position to attack?"
				return false, timeProgressedHealth*gsiUnit.lastSeenHealth
						/ (gsiUnit.maxHealth*(timeProgressedHealth - gsiUnit.lastSeenHealth))
						+ anyTowersDecrement
			end
		end
		if not currNode.nextNode then
			return false, timeProgressedHealth*gsiUnit.lastSeenHealth
						/ (gsiUnit.maxHealth*(gsiUnit.lastSeenHealth - timeProgressedHealth))
						+ anyTowersDecrement
		end
		currNode = currNode.nextNode
	end
	return timeProgressedHealth < 0, anyTowersDecrement
			+ (timeProgressedHealth < -1 and 0.0
				or (future_damage_lists[gsiUnit.hUnit] and future_damage_lists[gsiUnit.hUnit].oldestNode
					and 1.5)
				or 2.5
			) * gsiUnit.lastSeenHealth / gsiUnit.maxHealth
end

function Lhp_GetAnyLastHitsViableSimple(gsiPlayer)
	local creepSet, dist
			= Set_GetNearestEnemyCreepSetAtLaneLoc(
				gsiPlayer.lastSeen.location,
				Team_GetRoleBasedLane(gsiPlayer)
			)
	-- if DEBUG_IsBotTheIntern() then print("trying enter", creepSet and creepSet.units or nil) end
	if creepSet then
		local viableAttackRange = gsiPlayer.hUnit:GetAttackRange()+200
		local creepSetUnits = creepSet.units
		-- if DEBUG_IsBotTheIntern() then print("in set", creepSet.units, #creepSet.units) print("check dist", dist, "<", gsiPlayer.hUnit:GetAttackRange()+100) end
		if dist < viableAttackRange then
			for i=1,#creepSetUnits,1 do
				local gsiEnemyCreep = creepSetUnits[i]
				-- if DEBUG_IsBotTheIntern() then print("in creep", gsiEnemyCreep.shortName) print("dmg vs health one shot", Lhp_GetActualFromUnitToUnitAttackOnce(gsiPlayer.hUnit, gsiEnemyCreep.hUnit), ">", gsiEnemyCreep.lastSeenHealth) end
				if Lhp_GetActualFromUnitToUnitAttackOnce(gsiPlayer.hUnit, gsiEnemyCreep.hUnit) > gsiEnemyCreep.lastSeenHealth then
					-- if DEBUG_IsBotTheIntern() then print("returning" and creepSet.units or nil) end
					return gsiEnemyCreep
				end
			end
		end
	end
	return false
end

function Lhp_GetAnyDeniesViableSimple(gsiPlayer)
	local creepSet, dist = Set_GetNearestAlliedCreepSetInLane(gsiPlayer, Team_GetRoleBasedLane(gsiPlayer))
	if creepSet then
		local playerAttackDamage = gsiPlayer.hUnit:GetAttackDamage()
		local viableAttackRange = gsiPlayer.hUnit:GetAttackRange()+200
		local creepSetUnits = creepSet.units
		if dist < viableAttackRange then
			for i=1,#creepSetUnits,1 do
				local gsiAlliedCreep = creepSetUnits[i]
				if not cUnit_IsNullOrDead(gsiAlliedCreep)
						and Unit_GetHealthPercent(gsiAlliedCreep) < 0.3
						and Analytics_GetNearFutureHealth(gsiAlliedCreep, 2)
							< playerAttackDamage then
					return gsiAlliedCreep
				end
			end
		end
	end
	return false
end

function Analytics_hUnitsLowGroundToTargetFactor(hUnit, hTarget)
	return hUnit:GetLocation().z < hTarget:GetLocation().z and 0.75 or 1.0
end

function Analytics_GetNearFutureHealthPercent(gsiUnit, t)
	local nearFutureHealth, attackCount = Analytics_GetNearFutureHealth(gsiUnit, t)
	return nearFutureHealth / gsiUnit.maxHealth, attackCount
end

function Analytics_GetNearFutureHealth(gsiUnit, t)
	t = t and t + GameTime() or DEFAULT_NEAR_FUTURE_HEALTH_PERCENT_TIME + GameTime() -- default 1.0s future
	local totalDamage = 0
	local currNode = future_damage_lists[gsiUnit.hUnit] and future_damage_lists[gsiUnit.hUnit].firstNodeFromNow
	local attackCount = 0
	while(currNode and currNode.timeLanding < t) do
		totalDamage = totalDamage + currNode.damage
		currNode = currNode.nextNode
		attackCount = attackCount + 1
	end
	return gsiUnit.lastSeenHealth - totalDamage, attackCount
end

function Lhp_GetMyAttacksNeededForKill(gsiPlayer, gsiUnit) -- TODO Confirm proc items and passives behaviour, Probably redo with physical base attack + then add other abilities and items with their dmg types seperately
	return gsiUnit.lastSeenHealth / Lhp_GetActualFromUnitToUnitAttackOnce(gsiPlayer.hUnit, gsiUnit.hUnit)
end

-- function Analytics_GetNumberUnitsAttackingHUnit(hUnit)
	-- return future_damage_lists[hUnit] and future_damage_lists[hUnit].numAttacks or 0
-- end

function Analytics_GetTotalDamageInTimeline(hUnit)
	return future_damage_lists[hUnit] and future_damage_lists[hUnit].totalDmgRecently or 0
end

local players_found = {}
function Analytics_GetTotalDamageNumberAttackers(gsiPlayer) -- for team players
	local damageList = future_damage_lists[gsiPlayer.hUnit]
	if damageList then
		local currNode = damageList.oldestNode
		local numHeroesAttackingFriendly = 0
		while(currNode) do
			local thisUnit = currNode.fromUnit
			if not thisUnit:IsNull() and thisUnit:IsHero() then
				players_found[GSI_GetPlayerFromPlayerID(thisUnit:GetPlayerID()).nOnTeam] = true
				numHeroesAttackingFriendly = numHeroesAttackingFriendly + 1
			end
			currNode = currNode.nextNode
		end
		for pnot=1,ENEMY_TEAM_NUMBER_OF_PLAYERS do players_found[pnot] = false end
		return damageList.totalDmgRecently, numHeroesAttackingFriendly
	end
	return 0, 0
end

function Analytics_RoshanOrHeroAttacksInTimeline(gsiUnit)
	local damageList = future_damage_lists[gsiUnit.hUnit]
	if damageList then
		local currNode = damageList.oldestNode
		while(currNode) do
			local thisUnit = currNode.fromUnit
			if not Unit_IsNullOrDead(thisUnit) and (string.find(thisUnit:GetUnitName(), "hero") or string.find(thisUnit:GetUnitName(), "roshan")) then
				return true
			end
			currNode = currNode.nextNode
		end
	end
	return false
end

local hait_platter = {}
-- pnot indexed, contains damage list node
function Analytics_HeroAttacksInTimeline(gsiUnit) 
	local damageList = future_damage_lists[gsiUnit.hUnit]
	if not damageList then return EMPTY_TABLE, false, false end
	local numberUnitsEnemyPlayers = gsiUnit.team == TEAM and ENEMY_TEAM_NUMBER_OF_PLAYERS or TEAM_NUMBER_OF_PLAYERS
	for i=1,numberUnitsEnemyPlayers do hait_platter[i] = nil end
	local pastAttack = false
	local futureAttack = false
	local timesAttacked = 0
	local currTime = GameTime()
	local currNode = damageList.oldestNode
	while(currNode) do
		local thisUnit = currNode.fromUnit
		if string.find(thisUnit:GetUnitName(), "hero") then
			hait_platter[thisUnit.nOnTeam] = currNode.timeLanding
			timesAttacked = timesAttacked + 1
			if currNode.timeLanding > currTime then
				futureAttacks = true
			else
				pastAttacks = true
			end
		end
		currNode = currNode.nextNode
	end
	return hait_platter, pastAttack, futureAttack
end

function Analytics_GetFutureDamageFromUnitType(hUnit, unitType)
	local damageList = future_damage_lists[hUnit]
	if damageList then
		local currNode = damageList.oldestNode
		local totalDamage = 0
		local currTime = GameTime()
		while(currNode) do
			if currNode.timeLanding > currTime and Unit_GetUnitType(currNode.fromUnit) == unitType then
				totalDamage = totalDamage + currNode.damage
			end
			currNode = currNode.nextNode
		end
	end
	return totalDamage
end

function Analytics_GetMostDamagingUnitTypeToUnit(gsiUnit)
	local damageList = future_damage_lists[gsiUnit.hUnit]
	if damageList then
		local currNode = damageList.oldestNode
		local damageTotal = {}
		while (currNode) do -- Create the damage totals for types
			local unitType = Unit_GetUnitType(currNode.fromUnit)
			damageTotal[unitType] = (damageTotal[unitType] and damageTotal[unitType] or 0) + currNode.damage
			currNode = currNode.nextNode
		end
		local highestValue = 0
		local highestType = UNIT_TYPE_NONE
		for k,v in pairs(damageTotal) do -- compare
			if v > highestValue then
				highestValue = v
				highestType = k
			end
		end
		-- if gsiUnit.shortName == "arc_warden" then print(Util_PrintableTable(damageList, 2)) print("arc is scared of", highestType, "from", highestValue, "damage") end
		return highestType, highestValue
	end
	return nil, 0
end

function Lhp_CageFightKillTime(gsiPlayer, gsiTarget) -- Time taken for this hero to kill a unit unassisted from it's current health.
	-- This needs to be upgraded 
	local hUnitPlayer = gsiPlayer.hUnit
	local hUnitTarget = gsiTarget.hUnit
	local unitAttacksNeeded = math.ceil(Lhp_GetMyAttacksNeededForKill(gsiPlayer, gsiTarget))
	
	return unitAttacksNeeded * hUnitPlayer:GetSecondsPerAttack() * Analytics_hUnitsLowGroundToTargetFactor(hUnitPlayer, hUnitTarget)
end
