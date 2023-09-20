-- - #################################################################################### -
-- - - VUL-FT Full Takeover Bot Script for Dota 2 by yewchi // 'does stuff' on Steam
-- - - 
-- - - MIT License
-- - - 
-- - - Copyright (c) 2022 Michael, zyewchi@gmail.com, github.com/yewchi, gitlab.com/yewchi
-- - - 
-- - - Permission is hereby granted, free of charge, to any person obtaining a copy
-- - - of this software and associated documentation files (the "Software"), to deal
-- - - in the Software without restriction, including without limitation the rights
-- - - to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- - - copies of the Software, and to permit persons to whom the Software is
-- - - furnished to do so, subject to the following conditions:
-- - - 
-- - - The above copyright notice and this permission notice shall be included in all
-- - - copies or substantial portions of the Software.
-- - - 
-- - - THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- - - IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- - - FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- - - AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- - - LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- - - OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- - - SOFTWARE.
-- - #################################################################################### -

---- last_hit_projection constants
local FAR_PAST_DELETE_DAMAGE_NODE = 4.0

MINIMUM_RANGE_UNIT_RANGE = 200 -- TODO more correct way of finding if cats projectiles (and do melee units throw a projectile momentarily)
local DUMMY_ATTACKER_FOR_PROJECTILE_MAX = 0xFFFF -- Please do not cast more than 4 million projectiles at once.

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

local DEBUG = DEBUG
local VERBOSE = VERBOSE and false

local max = math.max
local insert = table.insert
local remove = table.remove
local next = next

local DEAGRO_UPDATE_PRIORITY
--

--     == LAST_HIT_PROJECTION ==
-- tables of incoming attacks and projectiles stored in a linked list
-- -|  time-wise left to right. Units are indexed in another table that
-- -|  declares the currently charging or latest attack in air. An attack
-- -|  may be created forwards of the current attack, this is the case for
-- -|  ranged units, maybe melee units and towers.
--
-- In-air attacks are corrected with the projectile from
-- -|  Projectile_GetNextAttackComplete(gsiUnit), and the nextNeeds (the
-- -|  attack after the in-air atack) is created once it is corrected once.
-- 
-- If the next attack releases while the currently tracked in-air is still
-- -|  flying, then the current attack is promoted to the new projectile,
-- -|  and the new nextNeeds will be computed and stored in that promoted,
-- -|  fresh, flying attack.
--
-- .'. only the most recent projectile is corrected, and once a following
-- -|  projectile is flying, the now-untracked is allowed to become inaccurate
-- -|  if there is some miscalculation of the time landing; common if target
-- -|  is moving.

local future_damage_lists = {} -- all of the attacks in the future, (and 4 seconds past for analytics)
local t_lists_with_recyclable_nodes = {}
local t_recyclable_fdls = {}
local t_recyclable_nodes = {} -- At one point before v0.7, this was keeping a table of almost every attack for the entire match. (:
local t_attacker_to_future_damage_node = {} -- the current pre-attack-point attacking behavior of a unit.

local job_domain_analytics

local next_projectile_hunit_ref = 0
-------------- get_dummy_projectile_hunit_ref()
local function get_dummy_projectile_hunit_ref()
	next_projectile_hunit_ref = next_projectile_hunit_ref + 1 % DUMMY_ATTACKER_FOR_PROJECTILE_MAX
	return next_projectile_hunit_ref
end

-------------- indicate_far_past_is_for_recycling()
local function indicate_far_past_is_for_recycling()
	local deleteOlderThan = GameTime() - FAR_PAST_DELETE_DAMAGE_NODE
	for atUnit,list in next,future_damage_lists do
		local currNode = list.oldestNode
		local foundOlderThan
		local n = 0
		while(currNode and currNode.timeLanding < deleteOlderThan) do
			n = n + 1 if n > 1000 then ERROR_print(false, not DEBUG, "[LHP] '%s' infinite future damage list caught.", atUnit) if atUnit.IsNull and not atUnit:IsNull() then DEBUG_KILLSWITCH = true TEAM_CAPTAIN_UNIT:ActionImmediate_Ping(atUnit:GetLocation().x, atUnit:GetLocation().y, false) end Util_TablePrint(future_damage_lists[atUnit]) Util_ThrowError() return end
			insert(t_recyclable_nodes, currNode.prevNode)
			currNode.prevNode = nil
			--future_damage_lists[atUnit].numAttacks = future_damage_lists[atUnit].numAttacks - 1
			future_damage_lists[atUnit].totalDmgRecently = future_damage_lists[atUnit].totalDmgRecently - currNode.damage
			if t_attacker_to_future_damage_node[currNode.fromUnit] == currNode then
				
				t_attacker_to_future_damage_node[currNode.fromUnit] = currNode.nextNeeds
			end
			currNode = currNode.nextNode
		end
		if not currNode then
			insert(t_recyclable_fdls, list)
			
			future_damage_lists[atUnit] = nil
		else
			currNode.prevNode = nil
			list.oldestNode = currNode
		end
	end
end

-------------- unstitch_and_recycle_node_simple()
local function unstitch_and_recycle_node_simple(node)
	if node.nextNeeds then
		if node.nextNeeds.nextNeeds then
			ERROR_print(false, not DEBUG, "[LHP] Too many next attacks (>2 total). future damage lists are over-linked, proliferating nodes, or nextNeeds has not been cleared.")
			Util_TablePrint(node)
			Util_ThrowError()
		end
		unstitch_and_recycle_node_simple(node.nextNeeds)
	end
	if node.head.firstNodeFromNow == node then
		if node.nextNeeds and node.nextNode == node.nextNeeds then
			node.head.firstNodeFromNow = node.nextNeeds.nextNode
		else
			node.head.firstNodeFromNow = node.nextNode
		end
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
	insert(t_recyclable_nodes, node.nextNeeds)
end

-- Let indicate_far_past_is_for_recycling take care of recycle list,
-- as it recurses once to nextNeeds
-------------- correct_unit_changed_target()
local function correct_unit_changed_target(node, fromUnit, atUnit)



	local attackerNode = t_attacker_to_future_damage_node[fromUnit]
	if attackerNode ~= node then
		unstitch_and_recycle_node_simple(attackerNode)
		if attackerNode.nextNode ~= node then
			WARN_print("[LHP] Units cannot attack two targets at once.")
			Util_TablePrint(node, DEBUG and 7 or 1)
			print(debug.traceback())
		end
	else
		unstitch_and_recycle_node_simple(node)
	end
	
	node.head.futureDamage = max(0, node.head.futureDamage - node.damage)

	t_attacker_to_future_damage_node[fromUnit] = nil
	insert(t_recyclable_nodes, node)
end

-------------- correct_attacker_node_for_projectile()
local function correct_attacker_node_for_projectile(attackerNode, timeLanding)
	
	attackerNode.timeLanding = timeLanding
	attackerNode.needsProjectileCorrection = false
	local head = attackerNode.head
	local currNode = attackerNode
	local m = 1
	while(currNode.prevNode) do
		m=m+1 if m > 1000 then ERROR_print(true, not DEBUG, "[LHP] V") DEBUG_KILLSWITCH = true TEAM_CAPTAIN_UNIT:ActionImmediate_Ping(currNode.fromUnit:GetLocation().x, currNode.fromUnit:GetLocation().y, false) return end
		if currNode.prevNode.timeLanding > timeLanding then
			currNode = currNode.prevNode
			-- the projectile node will be shifted back, below #shiftback, earlier
			-- -| than this node, repeating
		else break; end
	end
	if currNode ~= attackerNode then
		-- the projectile is earlier than pre-release approx.
		-- #shiftback
		-- connect the made gap or new end
		if attackerNode.nextNode then
			-- gap
			attackerNode.nextNode.prevNode = attackerNode.prevNode
		end
		attackerNode.prevNode.nextNode = attackerNode.nextNode -- implied prev: currNode ~= attacker
		-- insert or new start
		if currNode.prevNode then
			-- insert at true time earlier (probably still in the future)
			currNode.prevNode.nextNode = attackerNode
		end
		attackerNode.prevNode = currNode.prevNode -- prev or nil
		-- link to the 1-higher node
		currNode.prevNode = attackerNode
		attackerNode.nextNode = currNode
	else -- else check if later
		-- currNode == attackerNode
		local m = 1
		while(currNode.nextNode) do
			m=m+1 if m > 1000 then ERROR_print(true, not DEBUG, "[LHP] W") DEBUG_KILLSWITCH = true TEAM_CAPTAIN_UNIT:ActionImmediate_Ping(currNode.fromUnit:GetLocation().x, currNode.fromUnit:GetLocation().y, false) return end
			if currNode.nextNode.timeLanding < currNode.timeLanding then
				currNode = currNode.nextNode
				-- the projectile node will be shifted forward, below #shiftforward,
				-- -| after this node, repeating
			else break; end
		end
		if currNode ~= attackerNode then
			-- the projectile is later than pre-release approx.
			-- #shiftforward
			if attackerNode.prevNode then
				-- connect the made gap
				attackerNode.prevNode.nextNode = attackerNode.nextNode
			end
			attackerNode.nextNode.prevNode = attackerNode.prevNode -- implied nextNode
			if currNode.nextNode then
				-- insert at true time later
				currNode.nextNode.prevNode = attackerNode
			end
			attackerNode.nextNode = currNode.nextNode
			attackerNode.prevNode = currNode
			currNode.nextNode = attackerNode
		end
	end
	local m = 1
	currNode = head.oldestNode
	local m = 1
	while(currNode.prevNode) do -- no prev, break;
		m=m+1 if m > 1000 then ERROR_print(true, not DEBUG, "[LHP] X") DEBUG_KILLSWITCH = true TEAM_CAPTAIN_UNIT:ActionImmediate_Ping(currNode.fromUnit:GetLocation().x, currNode.fromUnit:GetLocation().y, false) return end
		currNode = currNode.prevNode
	end
	head.oldestNode = currNode
	--currNode = head.firstNodeFromNow and head.firstNodeFromNow.prevNode or currNode
	-- ^| 'or oldest', and can only shift by 1
	head.firstNodeFromNow = nil
	local m = 1
	while(currNode) do
		m=m+1 if m > 1000 then ERROR_print(true, not DEBUG, "[LHP] Y") DEBUG_KILLSWITCH = true TEAM_CAPTAIN_UNIT:ActionImmediate_Ping(currNode.fromUnit:GetLocation().x, currNode.fromUnit:GetLocation().y, false) return end
		if currNode.timeLanding
				>= GameTime() then
			head.firstNodeFromNow = currNode
			return;
		end
		currNode = currNode.nextNode
	end
end

-------------- insert_new_attack_time_node()
local function insert_new_attack_time_node(atUnit, damage, timeLanding, fromUnit, attackPointPercent, needsProjectileCorrection) -- Ensure nextNode, prevNode are set at least once (because recycling)
	-- create a new potential attack node, to be confirmed by update_current_attacks__job
	
	local new = remove(t_recyclable_nodes) or {}








	new.damage = damage
	new.timeLanding = timeLanding
	new.lastSeenAnimCycle = fromUnit:GetAnimCycle()
	new.fromUnit = fromUnit
	new.attackPointPercent = attackPointPercent
	new.needsProjectileCorrection = needsProjectileCorrection
	new.nextNeeds = nil
	new.nextNode = nil
	new.prevNode = nil
	
	local prevAttackNode = t_attacker_to_future_damage_node[fromUnit]
	if not prevAttackNode or prevAttackNode.head.atUnit ~= atUnit then
		t_attacker_to_future_damage_node[fromUnit] = new
	end
	
	if not future_damage_lists[atUnit] then
		local newDamageList = remove(t_recyclable_fdls) or {}
		
		future_damage_lists[atUnit] = newDamageList
		
		newDamageList.firstNodeFromNow = new
		newDamageList.oldestNode = new
		newDamageList.totalDmgRecently = new.damage
		newDamageList.futureDamage = new.damage
		newDamageList.atUnit = atUnit
	else
		local thisUnitDamageList = future_damage_lists[atUnit]
		
		--print(thisUnitDamageList.firstNodeFromNow, thisUnitDamageList.oldestNode)
		local currNode = thisUnitDamageList.firstNodeFromNow or thisUnitDamageList.oldestNode
		local m = 0
		while(currNode) do
			m = m + 1 if m > 1000 then Util_TablePrint(thisUnitDamageList) ERROR_print(true, not DEBUG, "[LHP] '%s' infinite future damage list caught.", atUnit) if atUnit.IsNull and not atUnit:IsNull() then DEBUG_KILLSWITCH = true GetBot():ActionImmediate_Ping(atUnit:GetLocation().x, atUnit:GetLocation().y, false) end return end
			if currNode.timeLanding >= timeLanding then
				if currNode.prevNode then
					currNode.prevNode.nextNode = new
					new.prevNode = currNode.prevNode
				end
				new.nextNode = currNode
				currNode.prevNode = new
				if thisUnitDamageList.firstNodeFromNow == currNode then -- new attack landing soonest in future
					--[DEV]]if timeLanding < GameTime() then DEBUG_KILLSWITCH = true ERROR_print("[LHP] Z") end
					thisUnitDamageList.firstNodeFromNow = new
				end
				if thisUnitDamageList.oldestNode == currNode then -- implies list only includes future attacks
					thisUnitDamageList.oldestNode = new
				end
				break;
			elseif currNode.nextNode == nil then
				currNode.nextNode = new
				new.prevNode = currNode
				if not thisUnitDamageList.firstNodeFromNow then
					thisUnitDamageList.firstNodeFromNow = new
				end
				break;
			end
			currNode = currNode.nextNode
		end
		thisUnitDamageList.totalDmgRecently = thisUnitDamageList.totalDmgRecently + new.damage
		thisUnitDamageList.futureDamage = thisUnitDamageList.futureDamage + new.damage
	end
	
	new.head = future_damage_lists[atUnit]
	



		
	return new
end

-- Shift to the current future, remove attacks if no longer attacking the unit.
-------------- update_current_attacks__job()
local function update_current_attacks__job(workingSet)
	if workingSet.throttle:allowed() then
		local currTime = GameTime()
		for atUnit,list in next,future_damage_lists do
			local currNode = list.firstNodeFromNow
			local m = 0
			-- Shift to future
			while(currNode) do
				m = m + 1 if m > 1000 then ERROR_print(true, not DEBUG, "[LHP] '%s' infinite future damage list caught.", atUnit) DEBUG_KILLSWITCH = true if atUnit.IsNull and not atUnit:IsNull() then TEAM_CAPTAIN_UNIT:ActionImmediate_Ping(atUnit:GetLocation().x, atUnit:GetLocation().y, false) end return end
				if currNode.timeLanding >= currTime then
					break
				end
				--print("jump up to", currNode.nextNode and currNode.nextNode.timeLanding)
				list.firstNodeFromNow = currNode.nextNode
				local futureDmg = list.futureDamage - currNode.damage
				list.futureDamage = futureDmg < 0 and 0 or futureDmg
				currNode = currNode.nextNode
			end
		end
		local m = 0
		local currTime = GameTime()
		-- Remove changed target
		for fromUnit,node in next,t_attacker_to_future_damage_node do
			m = m + 1; if m > 1000 then DEBUG_KILLSWITCH = true; ERROR_print(true, not DEBUG, "[LHP] L"); TEAM_CAPTAIN_UNIT:ActionImmediate_Ping(fromUnit:GetLocation().x, fromUnit:GetLocation().x, true); return; end

			local atUnit = node.head.atUnit
			local isNullOrDead = Unit_IsNullOrDead(fromUnit) or not fromUnit:CanBeSeen()
			local switchedTarget = not isNullOrDead and fromUnit:GetAttackTarget() ~= atUnit
			if switchedTarget or isNullOrDead or not fromUnit:IsTower() then
				local currAnim = not isNullOrDead and fromUnit:GetAnimCycle() or 0.0
				local isMelee = not isNullOrDead and (fromUnit:GetAttackProjectileSpeed() == 0
						or fromUnit:GetAttackRange() < 249) --[[RANGED BAKE]] --[[MELEE BAKE]]
				
				
				if node.timeLanding < currTime and not isNullOrDead then
					
					
					-- Promote to next attack
					
					t_attacker_to_future_damage_node[fromUnit] = node.nextNeeds
					node.nextNeeds = nil
				elseif (--[[currAnim+0.015 < node.lastSeenAnimCycle]]
							(needsProjectileCorrection or isMelee)
							and ( isNullOrDead 
								or (switchedTarget and currAnim > 0)
							)
						) then
					
					-- Delete the changed target attack for melee or pre-projectile
					correct_unit_changed_target(node, fromUnit, atUnit)
				end
				--if currAnim - 
				node.lastSeenAnimCycle = currAnim
			end
		end
	end
end

local set_working_tbl = {}
-------------- create_future_damage_lists__job()
local function create_future_damage_lists__job(workingSet)
	if workingSet.throttle:allowed() then
		local sets = set_working_tbl; sets[1] = nil;
		Set_NumericalIndexUnion( sets,
				Set_GetCreepSetsNearAlliedHeroes(),
				Set_GetEnemyHeroSetsNearAlliedHeroes(),
				Set_GetTowersNearAlliedHeroes()
			)
		indicate_far_past_is_for_recycling()

		local foundOneLowHealthAttackingTower = false
		local fortHasNotAlerted = true

		for i=1,#sets,1 do
			local sendOneUnagroablePushAlert = true -- push_lane taking advantage of full attack check
			local sendOneTeamIsSieged = true
			local thisSetUnits = sets[i].units
			local currTime = GameTime()
			local setSize = #thisSetUnits

			for i=1,setSize,1 do
				local gsiUnit = thisSetUnits[i]

				if not Unit_IsNullOrDead(gsiUnit) and gsiUnit.hUnit:CanBeSeen() then 
					local attackerNode = t_attacker_to_future_damage_node[gsiUnit.hUnit]

					
					-- See #node_logistics for explanation of needsProjectileCorrection logic 
					local hUnitAttacked, timeTilAttackLands, needsProjectileLater
							= Projectile_GetNextAttackComplete(gsiUnit,
									attackerNode and (attackerNode.needsProjectileCorrection
										or attackerNode.nextNeeds and true
									)
								)

--[DEV]]print("future damage3:", hUnitAttacked, timeTilAttackLands, needsProjectileLater)
					if timeTilAttackLands then
						if hUnitAttacked:IsBuilding() then
							-- buildings

							local buildingTeam = not hUnitAttacked:IsNull()
									and hUnitAttacked:GetTeam()
							if sendOneUnagroablePushAlert and buildingTeam == ENEMY_TEAM
									and gsiUnit.creepType ~= CREEP_TYPE_SIEGE then
								if setSize > 1
										or setSize == 1 and gsiUnit.lastSeenHealth
												> hUnitAttacked:GetAttackDamage()*3 then
									PushLane_InformUnagroablePush(hUnitAttacked)
									sendOneUnagroablePushAlert = false
								else
									foundOneLowHealthAttackingTower = true
								end
							end
							if fortHasNotAlerted and hUnitAttacked:GetTeam() == TEAM
									and string.find(hUnitAttacked:GetUnitName(), "fort") then
								-- Alert fort under attack
								Team_FortUnderAttack(gsiUnit)
								fortHasNotAlerted = false
							end
							if sendOneTeamIsSieged and buildingTeam == TEAM then
								LanePressure_InformTeamIsSieged(hUnitAttacked)
								sendOneTeamIsSieged = false
							end
						end
						-- Inform friendly heroes to prioritize deagroing towers
						if hUnitAttacked:IsHero() then
							if gsiUnit.type == UNIT_TYPE_HERO then
								local gsiAttacked = Unit_GetSafeUnit(hUnitAttacked)
								if gsiAttacked then
									FightClimate_RegisterRecentHeroAggression(gsiUnit,
											gsiAttacked, false
										)
								end
							elseif hUnitAttacked:GetTeam() == TEAM then
								if gsiUnit.type == UNIT_TYPE_BUILDING then
									
									DEAGRO_UPDATE_PRIORITY(
											GSI_GetPlayerNumberOnTeam(
												hUnitAttacked:GetPlayerID()
											)
										)
								end
							end
						end
						-- #node_logistics -- NB. GetNextAttackComplete needsProjectileLater is
						-- -| a logical linkage between the files. It's advice from projectile.lua
						-- -- Every attack node is first created without a projectile.
						-- -- Projectiles in air are not processed if the attacker was not visible
						-- -| before the attack point.
						-- -- Also, this will skip attacks deterministically if the unit is able to
						-- -| get three projectiles in the air at a time, but by this point, last
						-- -| hitting is not really very difficult or important.
						-- -- I have no idea what happens with weaver.
						-- -- See notes in following
						if not attackerNode then
							-- Insert the first attack in landing time order
							
							local actualDamage = Lhp_GetActualFromUnitToUnitAttackOnce(
									gsiUnit.hUnit, hUnitAttacked
								)
							insert_new_attack_time_node(hUnitAttacked, actualDamage,
									timeTilAttackLands + currTime, gsiUnit.hUnit,
									gsiUnit.attackPointPercent, needsProjectileLater
								)
						elseif attackerNode.needsProjectileCorrection then
							-- Asked for needing projectile update of a first or nextNeeds
							-- -| promoted attack, got a true projectile
							
							if not needsProjectileLater then
								correct_attacker_node_for_projectile(attackerNode,
										timeTilAttackLands + currTime
									)
							end
						else
							-- have attackerNode, the attackerNode does not need a projectile
							local attackIsAfterAttackerNode --nb. 'after timelanding' !all in attackIsAfterAttackerNode{} set
									= timeTilAttackLands + currTime
										> attackerNode.timeLanding + gsiUnit.halfSecAttack
							if not attackerNode.nextNeeds then
								-- Asked for not needing projectile, as it is updated with one
								-- -| or melee, got the next releasing attack, which may be
								-- -| current if the unit is not ranged
								
								if not needsProjectileLater and attackIsAfterAttackerNode then
									
									-- if not the current charging up attack, store next.
									-- -| attackerNode will not be promoted for the unit
									local actualDamage = Lhp_GetActualFromUnitToUnitAttackOnce(
											gsiUnit.hUnit, hUnitAttacked
										)
									attackerNode.nextNeeds
											= insert_new_attack_time_node(hUnitAttacked, actualDamage,
													timeTilAttackLands + currTime, gsiUnit.hUnit,
													gsiUnit.attackPointPercent, gsiUnit.isRanged
												)
								end
							elseif not attackIsAfterAttackerNode then
								-- Asked for needing projectile as we already have a next
								-- -| needs, update the live, and only projectile
								
								correct_attacker_node_for_projectile(attackerNode,
										timeTilAttackLands + currTime
									)
							else
								-- Asked for needing update projectil of the attackerNode,
								-- -| as we already have a nextNeeds, but the returned
								-- -| projectile was a new projectile. Consider the
								-- -| attackerNode to be accurate from here on, and
								-- -| promote the attackerNode to the new projectile
								-- -| in flight's attack, and correct it to a true
								-- -| projectile, no longer needsProjectileCorrection.
								
								t_attacker_to_future_damage_node[gsiUnit.hUnit]
										= attackerNode.nextNeeds
								correct_attacker_node_for_projectile(attackerNode.nextNeeds,
										timeTilAttackLands + currTime
									)
								attackerNode.nextNeeds = nil
							end
						end -- ends #node_logistics
					end -- if foundAttack
				end -- if not nullOrDead
			end -- for setUnits
		end -- for sets
	end -- if throttle:allowed()
end

-------- Analytics_RegisterAnalyticsJobDomainToLhp()
function Analytics_RegisterAnalyticsJobDomainToLhp(analyticsJobDomain)
	job_domain_analytics = analyticsJobDomain
	DEAGRO_UPDATE_PRIORITY = Deagro_UpdatePriority
	Analytics_RegisterAnalyticsJobDomainToLhp = nil
	Projectile_Initialize()
end

-------- LHP_UpdateHunit()
function LHP_UpdateHunit(previousHunit, newHunit) -- New rule is no 


	local attackNode = t_attacker_to_future_damage_node[previousHunit]
	if attackNode then -- attacking?
		-- update any pre attack-point attack by the unit
		t_attacker_to_future_damage_node[newHunit] = attackNode
		t_attacker_to_future_damage_node[previousHunit] = nil
		attackNode.fromUnit = newHunit
	end
	local attackedList = future_damage_lists[previousHunit]
	if attackedList then -- attacked?
		attackedList.atUnit = newHunit
		future_damage_lists[newHunit] = attackedList
	end
	future_damage_lists[newHunit] = attackedList
	future_damage_lists[previousHunit] = nil

end

-------- Analytics_CreateUpdateLastHitProjectionCurrentAttacks()
function Analytics_CreateUpdateLastHitProjectionCurrentAttacks()
	job_domain_analytics:RegisterJob(
			update_current_attacks__job,
			{["throttle"] = Time_CreateThrottle(0.00)},
			"JOB_UPDATE_LHP_CURRENT_ATTACKS"
		)
	Analytics_CreateUpdateLastHitProjectionCurrentAttacks = nil
end

-------- Analytics_CreateUpdateLastHitProjectionFutureDamageLists()
function Analytics_CreateUpdateLastHitProjectionFutureDamageLists()
	job_domain_analytics:RegisterJob(
			create_future_damage_lists__job,
			{["throttle"] = Time_CreateThrottle(0.00)}, 
			"JOB_UPDATE_LHP_FUTURE_DAMAGE_LISTS"
		)
	Analytics_CreateUpdateLastHitProjectionFutureDamageLists = nil
end


local BFURY_CREEP_DMG_MELEE = 15
local BFURY_CREEP_DMG_RANGED = 4
local HATCHET_CREEP_DMG_MELEE = 8
local HATCHET_CREEP_DMG_RANGED = 4
local DMG_TYPE_HERO = 1
local DMG_TYPE_MELEE = 2
local DMG_TYPE_PIERCE = 3
local DMG_TYPE_SIEGE = 4
local dmg_types = { --[[DAMAGE TYPE BAKE]]
	[1] = {1, 1, 1, 0.5},
	[2] = {0.75, 1, 1, 0.7},
	[3] = {0.5, 1.5, 1.5, 0.5*0.7},
	[4] = {1, 1, 1, 2.5}
}
local type_index = {
	["hero"] = 1,
	["creep_irresolute"] = 2,
	["creep_piercing"] = 3,
	["creep_siege"] = 4
}

function Lhp_GetAttackMultiplier(hUnitAttacking, hUnitAttacked)
	
end

-------- Lhp_GetActualFromUnitToUnitAttackOnce()
function Lhp_GetActualFromUnitToUnitAttackOnce(hUnitAttacking, hUnitAttacked) -- Primative
	local dmg_types = dmg_types
	local type_index = type_index
	local attackerType = hUnitAttacking:IsHero() and "hero"
			or hUnitAttacking:IsCreep() and hUnitAttacking:GetAbilityInSlot(0)
				and hUnitAttacking:GetAbilityInSlot(0):GetName()
			or hUnitAttacking:IsTower() and type_index["creep_siege"]
	attackerType = type_index[attackerType] or hUnitAttacking:IsCreep()
				and type_index["creep_irresolute"]
			or type_index["hero"]
	local defenderType = hUnitAttacked:IsHero() and "hero"
			or hUnitAttacked:IsCreep() and hUnitAttacked:GetAbilityInSlot(0)
				and hUnitAttacked:GetAbilityInSlot(0):GetName()
			or hUnitAttacked:IsTower() and type_index["creep_siege"]
	defenderType = type_index[defenderType] or hUnitAttacked:IsCreep()
				and type_index["creep_irresolute"]
			or type_index["hero"]

	local attackMultiplier = dmg_types[attackerType][defenderType]






	
	--local dmgMultiplier = hUnitAttacked():GetUnitName():find("iege")
			--and 
	if hUnitAttacking:IsHero() then
		local attackDmg = hUnitAttacking:GetAttackDamage()
		if false or hUnitAttacked:IsCreep() then -- hatchet seems overshooting, probably incorporated in actual damage func, dunno, 7.33 is out :O
			-- Add hatchet dmg
			local itemSlot = hUnitAttacking:FindItemSlot("item_bfury")
			if itemSlot >= 0 and itemSlot <= ITEM_END_INVENTORY_INDEX
					and (hUnitAttacking:GetTeam() ~= TEAM or hUnitAttacking:GetItemInSlot(itemSlot):GetCooldownTimeRemaining() == 0) then
				attackDmg = attackDmg + (hUnitAttacking:GetAttackRange() > 350
						and BFURY_CREEP_DMG_RANGED or BFURY_CREEP_DMG_MELEE)
				--print(hUnitAttacking:GetUnitName(), "has bfury dmg to", attackDmg)
			else
				itemSlot = hUnitAttacking:FindItemSlot("item_quelling_blade")
				if itemSlot >= 0 and itemSlot <= ITEM_END_INVENTORY_INDEX
							and (hUnitAttacking:GetTeam() ~= TEAM or hUnitAttacking:GetItemInSlot(itemSlot):GetCooldownTimeRemaining() == 0) then
					attackDmg = attackDmg + (hUnitAttacking:GetAttackRange() > 350
							and HATCHET_CREEP_DMG_RANGED or HATCHET_CREEP_DMG_MELEE)
					--print(hUnitAttacking:GetUnitName(), "has hatchet dmg to", attackDmg)
				end
			end
		end
		if hUnitAttacked:IsTower() then
			
		end
		return hUnitAttacked:GetActualIncomingDamage(
				attackDmg
					* attackMultiplier, 
				DAMAGE_TYPE_PHYSICAL
			)
	end
	return hUnitAttacked:GetActualIncomingDamage(hUnitAttacking:GetAttackDamage()
			* attackMultiplier, 
			DAMAGE_TYPE_PHYSICAL
		)
end


-------- Lhp_AttackNowForBestLastHit()
function Lhp_AttackNowForBestLastHit(gsiPlayer, gsiUnit, dontBreak) -- Requires units are not dead nor null
	local currTime = GameTime()
	local currNode = future_damage_lists[gsiUnit.hUnit] and future_damage_lists[gsiUnit.hUnit].firstNodeFromNow
	local timeProgressedHealth = gsiUnit.lastSeenHealth - Lhp_GetActualFromUnitToUnitAttackOnce(gsiPlayer.hUnit, gsiUnit.hUnit)*HERO_PHYSICAL_ATTACK_VARIANCE
	local startAttackTilHitDelta = Projectile_TimeToLandProjectile(gsiPlayer, gsiUnit)

	local unitHpRegen = gsiUnit.hUnit:GetHealthRegen()

	local currAttackTarget = gsiPlayer.hUnit:GetAttackTarget()
	local breakTooEarly = not dontBreak and currAttackTarget == gsiUnit.hUnit
			and gsiPlayer.hUnit:GetAnimActivity() >= 1503
			and gsiPlayer.hUnit:GetAnimActivity() <= 1505 --[[ANIMATION BAKE]]
	local attackingTakeAway = breakTooEarly and gsiPlayer.hUnit:GetAnimCycle() or 0
	local knownLanding = breakTooEarly and currTime + startAttackTilHitDelta
			- attackingTakeAway*gsiPlayer.hUnit:GetSecondsPerAttack()
	

	local trueProgressedHealth = timeProgressedHealth
			+ (knownLanding and knownLanding - currTime or startAttackTilHitDelta)
				* unitHpRegen -- wrong if attacking and asked don't break. it's only a few hp

	-- TODO TEST Time til facing is not bugged
	local landingTimeOfAttackNow = currTime + startAttackTilHitDelta
	local anyTowersDecrement = 0 -- Tower damage needs an overzealous standing position when it's not time to attack. (We do not project forwards further than the current flying attacks and the currently animated/predicted based on last-attack-time attacks)
	if trueProgressedHealth < 0 then
		
		return true, 0, trueProgressedHealth
	end
	local n = 0
	local m = 1
	local totalDmgFuture = 0
	local unusedPlayerDmg = 0


	while(currNode) do
		--if DEBUG and DEBUG_IsBotTheIntern() then print("currNode: ", m, currNode.fromUnit, currNode.fromUnit:GetUnitName()) end
		 n = n + 1 -- Running determine real future attacks (for a nasty est of how long till death if the target will not die from the future attacks plus our own)

		if currNode.fromUnit == gsiUnit.hUnit and ( not gsiUnit.isRanged
					or currNode.needsProjectileCorrection
				) then
			unusedPlayerDmg = currNode.damage
			goto NEXT_TPH;
		end
		timeProgressedHealth = timeProgressedHealth - currNode.damage
		trueProgressedHealth = timeProgressedHealth
				+ (currNode.timeLanding - currTime) * unitHpRegen 
		if bUnit_IsTower(currNode.fromUnit) then anyTowersDecrement = -1.5 end

		if trueProgressedHealth < 0 then
			if breakTooEarly and currNode.timeLanding > knownLanding then
				
				gsiPlayer.hUnit:Action_ClearActions(true)
				return false, 0, timeProgressedHealth
			end
			if currNode.timeLanding < landingTimeOfAttackNow then -- Return AttackNow! if it leads to a future with a < 0 HP creep, and that future was before our attack would land
				
				return true, 0, timeProgressedHealth
			else
				-- 1.5/n I think I put it there because it makes bots stand further away when there are only a few creeps attacking a unit "how long until I need to be in position to attack?"
			
				return false,
						currNode.timeLanding - landingTimeOfAttackNow,
						trueProgressedHealth
			end
		end
		::NEXT_TPH::
		totalDmgFuture = totalDmgFuture + currNode.damage
		if not currNode.nextNode then
			
			currNode.head.futureDamage = totalDmgFuture - unusedPlayerDmg
			
			return false,
					trueProgressedHealth / ( totalDmgFuture
							/ (currNode.timeLanding - currTime)
						) + anyTowersDecrement - startAttackTilHitDelta,
					trueProgressedHealth
		end
		currNode = currNode.nextNode
	end
	
	return timeProgressedHealth < 0,
			anyTowersDecrement
				+ (timeProgressedHealth < -1 and 0.0
					or (future_damage_lists[gsiUnit.hUnit]
						and future_damage_lists[gsiUnit.hUnit].oldestNode
						and 3)
					or 5
				) * (gsiUnit.lastSeenHealth / gsiUnit.maxHealth)^0.25
				- startAttackTilHitDelta*0.33,
			trueProgressedHealth
end

-------- Lhp_GetAnyLastHitsViableSimple()
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
				if Lhp_GetActualFromUnitToUnitAttackOnce(gsiPlayer.hUnit, gsiEnemyCreep.hUnit) > gsiEnemyCreep.lastSeenHealth and not cUnit_IsNullOrDead(gsiEnemyCreep) then
					-- if DEBUG_IsBotTheIntern() then print("returning" and creepSet.units or nil) end
					return gsiEnemyCreep
				end
			end
		end
	end
	return false
end

-------- Lhp_GetAnyDeniesViableSimple()
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

-------- Analytics_hUnitsLowGroundToTargetFactor()
function Analytics_hUnitsLowGroundToTargetFactor(hUnit, hTarget)
	return hUnit:GetLocation().z < hTarget:GetLocation().z and 0.75 or 1.0
end

-------- Analytics_GetNearFutureHealthPercent()
function Analytics_GetNearFutureHealthPercent(gsiUnit, t)
	local nearFutureHealth, attackCount = Analytics_GetNearFutureHealth(gsiUnit, t)
	return nearFutureHealth / gsiUnit.maxHealth, attackCount
end

-------- Analytics_GetNearFutureHealth()
function Analytics_GetNearFutureHealth(gsiUnit, t)
	t = t and t + GameTime() or DEFAULT_NEAR_FUTURE_HEALTH_PERCENT_TIME + GameTime() -- default 1.0s future
	local totalDamage = 0
	local currNode = future_damage_lists[gsiUnit.hUnit] and future_damage_lists[gsiUnit.hUnit].firstNodeFromNow
	local attackCount = 0
	local m=0
	while(currNode and currNode.timeLanding < t) do
		m=m+1 if m > 1000 then ERROR_print(false, not DEBUG, "[LHP] P") DEBUG_KILLSWITCH = true GetBot():ActionImmediate_Ping(gsiUnit.lastSeen.location.x, gsiUnit.lastSeen.location.y, false) Util_TablePrint(future_damage_lists[gsiUnit.hUnit]) Util_ThrowError() return end
		totalDamage = totalDamage + currNode.damage
		currNode = currNode.nextNode
		attackCount = attackCount + 1
	end
	return gsiUnit.lastSeenHealth - totalDamage, attackCount
end

-------- Lhp_GetMyAttacksNeededForKill()
function Lhp_GetMyAttacksNeededForKill(gsiPlayer, gsiUnit) -- TODO Confirm proc items and passives behavior, Probably redo with physical base attack + then add other abilities and items with their dmg types seperately
	return gsiUnit.lastSeenHealth / Lhp_GetActualFromUnitToUnitAttackOnce(gsiPlayer.hUnit, gsiUnit.hUnit)
end

-- function Analytics_GetNumberUnitsAttackingHUnit(hUnit)
	-- return future_damage_lists[hUnit] and future_damage_lists[hUnit].numAttacks or 0
-- end

-------- Analytics_GetTotalDamageInTimeline()
function Analytics_GetTotalDamageInTimeline(hUnit)
	return future_damage_lists[hUnit] and future_damage_lists[hUnit].totalDmgRecently or 0
end

-------- Analytics_GetFutureDamageInTimeline()
function Analytics_GetFutureDamageInTimeline(hUnit)
	return future_damage_lists[hUnit] and future_damage_lists[hUnit].futureDamage or 0
end

-------- Analytics_AttacksWho()
function Analytics_AttacksWho(hUnit)
	local list = t_attacker_to_future_damage_node[hUnit]
	return list and list.atUnit
end

local players_found = {}
-------- Analytics_GetTotalDamageNumberAttackers()
function Analytics_GetTotalDamageNumberAttackers(gsiPlayer) -- for team players
	local damageList = future_damage_lists[gsiPlayer.hUnit]
	if damageList then
		local currNode = damageList.oldestNode
		local numHeroesAttackingFriendly = 0
		local m = 1
		while(currNode) do
			m=m+1 if m > 1000 then ERROR_print(true, not DEBUG, "[LHP] Q") DEBUG_KILLSWITCH = true TEAM_CAPTAIN_UNIT:ActionImmediate_Ping(gsiPlayer.lastSeen.location.x, gsiPlayer.lastSeen.location.y, false) return end
			local thisUnit = currNode.fromUnit
			if not Unit_IsNullOrDead(thisUnit) and thisUnit:IsHero() then
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

-------- Analytics_RoshanOrHeroAttacksInTimeline()
function Analytics_RoshanOrHeroAttacksInTimeline(gsiUnit, offset)
	local damageList = future_damage_lists[gsiUnit.hUnit]
	if damageList then
		local currNode = offset and offset >= 0 and damageList.firstNodeFromNow
				or damageList.oldestNode
		local afterTime = offset and GameTime() + offset or 0
		local m = 1
		while(currNode) do
			m=m+1 if m > 1000 then ERROR_print(true, not DEBUG, "[LHP] R") DEBUG_KILLSWITCH = true TEAM_CAPTAIN_UNIT:ActionImmediate_Ping(gsiUnit.lastSeen.location.x, gsiUnit.lastSeen.location.y, false) return end
			if currNode.timeLanding >= afterTime then
				local thisUnit = currNode.fromUnit
				if not thisUnit:IsNull()
						and ((string.find(thisUnit:GetUnitName(), "hero")
							and IsHeroAlive(thisUnit:GetPlayerID())
						) or string.find(thisUnit:GetUnitName(), "roshan")) then
					return true
				end
			end
			currNode = currNode.nextNode
		end
	end
	return false
end

local hait_platter = {}
-- pnot indexed, contains damage list node
-- NB DATA MUST NOT PROPEGATE TO HUNIT USE OF HEROES FROM THE HAIT_PLATTER TABLE
-------- Analytics_HeroAttacksInTimeline()
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
	local m = m + 1
	while(currNode) do
		m=m+1 if m > 1000 then ERROR_print(true, not DEBUG, "[LHP] S") DEBUG_KILLSWITCH = true TEAM_CAPTAIN_UNIT:ActionImmediate_Ping(gsiUnit.lastSeen.location.x, gsiUnit.lastSeen.location.y, false) return end
		local thisUnit = currNode.fromUnit
		if not Unit_IsNullOrDead(thisUnit) and thisUnit:IsHero() and thisUnit.GetPlayerID then
			thisUnit = GSI_GetPlayerFromPlayerID(thisUnit:GetPlayerID())
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
-- NB DATA MUST NOT PROPEGATE TO HUNIT USE OF HEROES FROM THE HAIT_PLATTER TABLE
	return hait_platter, pastAttack, futureAttack
end

-------- Analytics_GetFutureDamageFromUnitType()
function Analytics_GetFutureDamageFromUnitType(hUnit, unitType)
	local damageList = future_damage_lists[hUnit]
	local totalDamage = 0
	if damageList then
		local currNode = damageList.oldestNode
		local currTime = GameTime()
		local m = 1
		while(currNode) do
			m=m+1 if m > 1000 then ERROR_print(true, not DEBUG, "[LHP] T") DEBUG_KILLSWITCH = true TEAM_CAPTAIN_UNIT:ActionImmediate_Ping(hUnit:GetLocation().x, hUnit:GetLocation().y, false) return end
			if currNode.timeLanding > currTime and Unit_GetUnitType(currNode.fromUnit) == unitType then
				totalDamage = totalDamage + currNode.damage
			end
			currNode = currNode.nextNode
		end
	end
	return totalDamage
end

-------- Analytics_GetMostDamagingUnitTypeToUnit()
function Analytics_GetMostDamagingUnitTypeToUnit(gsiUnit, limitPast)
	local damageList = future_damage_lists[gsiUnit.hUnit]
	limitPast = GameTime() - (limitPast or 4.1)
	if damageList then
		local currNode = damageList.oldestNode
		local damageTotal = {}
		local m = 1
		while (currNode) do -- Create the damage totals for types
			m=m+1 if m > 1000 then ERROR_print(true, not DEBUG, "[LHP] U") DEBUG_KILLSWITCH = true TEAM_CAPTAIN_UNIT:ActionImmediate_Ping(gsiUnit.lastSeen.location.x, gsiUnit.lastSeen.location.y, false) return end
			local unitType = Unit_GetUnitType(currNode.fromUnit)
			if currNode.timeLanding > limitPast then
				damageTotal[unitType] = (damageTotal[unitType] and damageTotal[unitType] or 0) + currNode.damage
			end
			currNode = currNode.nextNode
		end
		local highestValue = 0
		local highestType = UNIT_TYPE_NONE
		for k,v in next,damageTotal do -- compare
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

-------- Lhp_CageFightKillTime()
function Lhp_CageFightKillTime(gsiPlayer, gsiTarget) -- Time taken for this hero to kill a unit unassisted from it's current health.
	-- This needs to be upgraded 
	local hUnitPlayer = gsiPlayer.hUnit
	local hUnitTarget = gsiTarget.hUnit
	local unitAttacksNeeded = math.ceil(Lhp_GetMyAttacksNeededForKill(gsiPlayer, gsiTarget))
	
	return unitAttacksNeeded * hUnitPlayer:GetSecondsPerAttack() * Analytics_hUnitsLowGroundToTargetFactor(hUnitPlayer, hUnitTarget)
end

if DEBUG then
------------ DEBUG_LHP_DrawLhpTarget()
	function DEBUG_LHP_DrawLhpTarget(p, targ)
		local farmLaneObj = Task_GetTaskObjective(p, FarmLane_GetTaskHandle())
		local list = farmLaneObj and future_damage_lists[targ or farmLaneObj.hUnit]
		if not list then
			DebugDrawText(2, 200, "[]", 200, 100, 100)
			return;
		end

		local currNode = list.oldestNode
		local currTime = GameTime()
		local m=0
		DebugDrawText(2, 124, string.format("u&%s: %s",
					string.sub(tostring(farmLaneObj.hUnit), -8),
					string.sub(farmLaneObj.name, -14)
				), 155, 205, 255
			)
		while(currNode) do
			if m*85 > 1800 then return; end
			local c = currNode.timeLanding > currTime and 155 or 20
			DebugDrawText(2+m*85, 166, string.format("<>%s",
						string.sub(tostring(currNode.head), -8)
					), 155, 205, 255
				)
			DebugDrawText(2+m*85, 175, string.format("n&%-8.8s",
						string.sub(tostring(currNode), -8)
					), c, c+50, c+100
				)
			DebugDrawText(2+m*85, 185, string.format("[%-8.8s]%s",
						currNode.fromUnit:IsNull() and "nulled"
							or string.format("%s%s",
									string.sub(currNode.fromUnit:GetUnitName(), 16, 17),
									string.sub(currNode.fromUnit:GetUnitName(), -6, -1)
								),
						currNode.nextNode and "->" or ""
					), c, c+50, c+100
				)
			DebugDrawText(2+m*85, 195, string.format("u&%-8.8s",
						string.sub(tostring(currNode.fromUnit), -8)
					), c, c+50, c+100
				)
			DebugDrawText(2+m*85, 205, string.format("d%4d>%s",
						currNode.damage,
						currNode.nextNeeds and string.sub(tostring(currNode.nextNeeds), -4)
							or "____"
					), c, c+50, c+100
				)
			DebugDrawText(2+m*85, 215, string.format("t%s",
						string.sub(string.format("%.2f", currNode.timeLanding), -9)
					), c, c+50, c+100
				)
			currNode = currNode.nextNode
			m=m+1
		end
	end
end
