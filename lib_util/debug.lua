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

-- EPILEPSY AND SEIZURE WARNING when DEBUG == true -- 

PRINT_ANALYSIS = Time_CreateThrottle(10.0) or nil

DEBUG_KILLSWITCH = nil

TEAM_COLORS = {
		[TEAM_RADIANT] = {
			{20, 20, 220}, {20,220,200}, {145, 60, 150}, {200, 210, 30}, {230, 130, 20}
		},
		[TEAM_DIRE] = {
			{250, 120, 240}, {140, 235, 75}, {30, 175, 230}, {75, 160, 70}, {170, 100, 50}
		}
	}

ARC_DISABLE_FRAMES = 0

DEBUG_SHORTNAME = "zuus"

MAP_COORDS_TO_SCREEN_SCALE = 0.08
MAP_COORDS_TO_MINIMAP_SCALE = 0.015

function DEBUG_Init()
	local team = GSI_GetTeamPlayers(TEAM_RADIANT)
	for i=1,5 do
		team[i].DBGColor = TEAM_COLORS[TEAM_RADIANT][i]
	end
	team = GSI_GetTeamPlayers(TEAM_DIRE)
	for i=1,5 do
		team[i].DBGColor = TEAM_COLORS[TEAM_DIRE][i]
	end

	DEBUG_Init = nil
end

local sin = math.sin
local cos = math.cos
local rad = math.rad
local deg = math.deg
local min = math.min
local max = math.max
local ceil = math.ceil
local floor = math.floor
local acos = math.acos
local pi = math.pi
local pi2 = pi*2

local grey = {128, 128, 128}
function GetDBGColor(gsiPlayer, rbg)
	return gsiPlayer.DBGColor and gsiPlayer.DBGColor[rbg] or grey[rbg]
end

function DEBUG_print(str, ...)
	print(string.format("/VUL-FT/ <DEBUG> "..str, ...))
end

function VEBUG_print(str, ...)
	print(string.format("/VUL-FT/ <VERBOSE> "..str, ...))
end

function TEBUG_print(str, ...)
	print(string.format("/VUL-FT/ <TEST> "..str, ...))
end

function DEBUG_IsBotTheIntern()
	return GSI_GetBot().shortName == DEBUG_SHORTNAME
end

function DEBUG_PrintUntilErroredNone(gsiUnit)
	DEBUG_KILLSWITCH = true
	print("PrintUntilError: --", GameTime())
	Util_TablePrint(gsiUnit)
	print(gsiUnit)
	print(gsiUnit.hUnit)
	print(gsiUnit.name, gsiUnit.type, gsiUnit.lastSeenHealth, gsiUnit.typeIsNone, gsiUnit.needsVisibleData)
	print(gsiUnit.lastSeen.location)
	TEAM_CAPTAIN_UNIT:ActionImmediate_Ping(gsiUnit.lastSeen.location.x, gsiUnit.lastSeen.location.y, true)
	print(gsiUnit.hUnit.GetName and gsiUnit:GetName() or gsiUnit:GetUnitName())
	print(gsiUnit.hUnit:GetLocation())
end

function DEBUG_PersistDrawText()
end

local task_store = {}
local rotate = {}
for i=1, #GetTeamPlayers(GetBot():GetTeam()) do
	task_store[i] = {}
	rotate[i] = 1
	for j=1,10 do
		task_store[i][j] = {}
		table.insert(task_store[i][j], {0, 0, 0})
	end
end
function VEBUG_PlayerFrameProgressBarStart(pnot, offsetx, offsety, force)
	if not DEBUG and not force then return end
	offsety = (offsety or 75) + (pnot-1)*10
	if TEAM_IS_RADIANT then
		DebugDrawText((offsetx or 300), offsety, "[", 100, 255, 100)
	else
		DebugDrawText((offsetx or 430), offsety, "[", 255, 100, 100)
	end
end
function VEBUG_PlayerFrameProgressBar(pnot, progress, offsetx, offsety)
	if not DEBUG and not force then return end
	offsety = (offsety or 75) + (pnot-1)*10
	if TEAM_IS_RADIANT then
		offsetx = (offsetx or 200) + 8 + progress
		DebugDrawText(offsetx, offsety, progress < 100 and "|" or "|]", 100, 255, 100)
	else
		offsetx = (offsetx or 430) + 8 + progress
		DebugDrawText(offsetx, offsety, progress < 100 and "|" or "|]", 255, 100, 100)
	end
end
function DEBUG_TaskDiagnostic(g, o, s)
	local pnot = g.nOnTeam
	if o == true then
		print(string.format("Diagnose Task %s\n", g.shortName))
		print("#", "$", "t")
		for i=1,10 do
			print(task_score[pnot][i][1], task_score[pnot][i][2], task_score[pnot][i][3],
					task_score[pnot][i%10+1][3] < task_score[pnot][i][3] and "<<" or "")
		end
	else
		task_score[g.nOnTeam][rotate[i]][1] = o
		task_score[g.nOnTeam][rotate[i]][2] = s
		task_score[g.nOnTeam][rotate[i]][3] = GameTime()
		rotate[i] = rotate[i] % 10 + 1
	end
end

function DEBUG_GetObjNumElements(obj, size, depth)
	size = size or 0
	depth = depth or 0
	print(size)
	if type(obj) ~= "table" or obj.hUnit or depth==5 then
		return size+1
	end
	for k,v in pairs(obj) do
		print(k, Util_PrintableTable(v, 2))
		size = DEBUG_GetObjNumElements(v, size+1, depth+1)
	end
	return size
end

local PASSABLE_most_recent_player_ping = Vector(0,0,0)
function DEBUG_QuestionPassableTerrain(job_domain, humanPlayer)	
	Communication_Question(
		job_domain, 
		humanPlayer, 
		{
			[1] = {
				"Ping a terrain.", 
				function(workingSet) 
					local thisLocation = humanPlayer.hUnit:GetMostRecentPing().location
					if thisLocation.x ~= PASSABLE_most_recent_player_ping.x
							or thisLocation.y ~= PASSABLE_most_recent_player_ping.y then
						TEAM_CAPTAIN_UNIT.Chat(string.format("%s: v(%.2f, %.2f, %.2f), ht-%d, lane-%d",
									(IsLocationPassable(thisLocation) and "Passable" or "Impassable"), 
									thisLocation.x,
									thisLocation.y,
									thisLocation.z,
									GetHeightLevel(thisLocation),
									Map_GetLaneValueOfMapPoint(thisLocation)
								),
								false
							)
						return 1
					end
					print(thisLocation, thisLocation and thisLocation.x)
					PASSABLE_most_recent_player_ping = thisLocation
				end
			},
		}
	)
end
function DEBUG_QuestionSetNewIntern(job_domain, humanPlayer)	
	Communication_Question(
		job_domain, 
		humanPlayer, 
		{
			[1] = {
				"Intern switch on.", 
				function(workingSet) 
					ARC_DISABLE_FRAMES = 100
					local newIntern = GSI_GetPlayerByName(workingSet.hHumanAsked.comms.intern)
					if newIntern then
						print(newIntern.shortName, newIntern)
						TEAM_CAPTAIN_UNIT.Chat(string.format("Setting Intern: \"%s\"", newIntern.shortName), false)
						DEBUG_SHORTNAME = newIntern.shortName
					end
					workingSet.hHumanAsked.comms.intern = nil
					return 1
				end
			},
		}
	)
	InstallChatCallback(
			function(event)
				if event.player_id == humanPlayer.playerID then
					humanPlayer.comms.intern = event.string
					humanPlayer.comms.mostRecentChatText = event
				end
			end
		)
end
function DEBUG_QuestionSetDebug(job_domain, humanPlayer)
	Communication_Question(
		job_domain, 
		humanPlayer, 
		{
			[1] = {
				"Intern switch on.", 
				function(workingSet) 
					local debugMsg = workingSet.hHumanAsked.comms.debugMsg
					if debugMsg then
						if string.find(string.lower(debugMsg), " off") then
							DEBUG = false
							VERBOSE = false
						elseif string.find(string.lower(debugMsg), " on") then
							DEBUG = true
							if string.find(string.lower(debugMsg), "-v") then
								VERBOSE = true
							end
						end
						workingSet.hHumanAsked.comms.debugMsg = nil
					end
					return 1
				end
			},
		}
	)
	InstallChatCallback(
			function(event)
				if event.player_id == humanPlayer.playerID then
					humanPlayer.comms.mostRecentChatText = event
					if type(event.string) == "string"
							and string.find(string.lower(event.string), "debug") then
						humanPlayer.comms.debugMsg = event.string
					end
				end
			end
		)
end

function DEBUG_DumbSlowAttackMove(job_domain)
	job_domain:RegisterJob(
			function(workingSet)
				workingSet.a = workingSet.a + 1
				if workingSet.throttle:allowed() then
					if(TEAM == TEAM_DIRE) then GetBot():Action_AttackMove(Vector(2220,math.min(workingSet.a, 0.0),0)) end
				end
			end,
			{["throttle"] = Time_CreateThrottle(5.5),
			["a"] = -3850},
			"JOB_DUMB_SLOW_ATTACK_MOVE"
		)
end

function DEBUG_XetaValueTest() -- Outdated
	if TEAM == TEAM_RADIANT and PRINT_ANALYSIS:allowed() then 
		local thisCreep = GetUnitList(UNIT_LIST_ALLIED_CREEPS)[10]
		if thisCreep then 
			print(thisCreep:GetUnitName(), thisCreep:GetBountyXP(), Xeta_EvaluateObjectiveCompletion(XETA_CREEP_KILL, 30.0, 5.0, THIS_BOT, thisCreep))
		end
		local thisBot = GSI_GetTeamPlayers(ENEMY_TEAM)[1]
		print("Xeta for hero kill on", thisBot.shortName, ":", Xeta_EvaluateObjectiveCompletion(XETA_HERO_KILL, 15.0, 1.0, GSI_GetTeamPlayers(TEAM)[1], thisBot))
	end
end

function DEBUG_CreepPriorityTest()
	local thisBot = GSI_GetBot()
	local myLaneCreepSets = Set_GetEnemyCreepSetsInLane(Team_GetRoleBasedLane(thisBot))
	if myLaneCreepSets and thisBot.lastSeen.location then
		local highestValueCreepXeta = 0
		local highestValueCreep = myLaneCreepSets[1].units[1]
		local previousPlayerForMyHighestValueCreep = nil
		for s=1,#myLaneCreepSets,1 do
			local thisSet = myLaneCreepSets[s]
			local thisSetUnits = thisSet.units
			for u=1,#thisSetUnits,1 do
				local thisCreep = thisSetUnits[u]
				local thisXeta = Xeta_EvaluateObjectiveCompletion(XETA_CREEP_KILL, Math_ETA(thisBot, thisCreep:GetLocation())+Lhp_CageFightKillTime(thisBot, thisCreep), 1.0, thisBot, thisCreep)
				if thisXeta > highestValueCreepXeta then
					if thisBot.isCaptain then
						local x, y = Math_ScreenCoordsToCartesianCentered(thisCreep:GetLocation().x - thisBot.hUnit:GetLocation().x, thisBot.hUnit:GetLocation().y - thisCreep:GetLocation().y, 0.6)
						-- DebugDrawText(x, y, string.format("%.2f", thisXeta), TEAM==TEAM_DIRE and 255 or 30, TEAM==TEAM_RADIANT and 255 or 30, 30)
					end
					local allowedTakeOver, thisPreviousPlayer = 
							Farm_CheckTakeOverLastHitRequest(thisBot, thisCreep, highestValueCreepXeta*0.9)
					if allowedTakeOver then
						if thisPreviousPlayer ~= nil then
							print(thisBot.shortName, "taking over from", thisPreviousPlayer.shortName)
						end
						previousPlayerForMyHighestValueCreep = thisPreviousPlayer
						highestValueCreepXeta = thisXeta
						highestValueCreep = thisCreep
					end
				end
			end
		end
		
		--if PRINT_ANALYSIS:allowed() or PRINT_ANALYSIS.next == GameTime() + PRINT_ANALYSIS.c then print(thisBot.shortName, "found creep value $"..highestValueCreepXeta) end
		if previousPlayerForMyHighestValueCreep ~= thisBot then
			Farm_SetLastHitRequest(thisBot, highestValueCreep, highestValueCreepXeta)
			thisBot.hUnit:Action_AttackUnit(highestValueCreep, false)
		end
	end
end

function DEBUG_GreenLineWhenIncomingCreepPlusMyAttackKills()
	local thisBot = GSI_GetBot()
	local targetCreep = GetAttackTarget()
	
	if targetCreep:GetHealth() then
	end
end

local gary
local garyhUnit
local garyThrottle = Time_CreateThrottle(-10.0)
local garyLastAttackSeen = 0
local animCycleAtRelease = 0
local currentProjectile
local catchNextProjectileLands = false
local locOfProjectileAtRelease = Vector(-0, -0, -0)
local landingTime = 0
local getsHitClosest = Vector(-0, -0, -0)
local closestGetsHitDist = 0xFFFF
local velocity = 0
local radius = 0
function DEBUG_IsGary(gsiUnit) return gary == gsiUnit end
function DEBUG_CreepAdventure()
	if garyThrottle:allowed() then
		if not gary then
			gary = Set_GetAlliedCreepSetsInLane(2)
			if gary[1] then
				for i=1,#(gary[1].units),1 do
					print("GAZ", gary[1], gary[1].units[i])
					if gary[1].units[i].creepType == CREEP_TYPE_SIEGE then
						gary = gary[1].units[i]
						break
					end
				end
			end
			gary = GSI_GetLowestTierTeamLaneTower(ENEMY_TEAM, 2)
			gary = GSI_GetPlayerByName("venomancer")
			if not gary or gary.hUnit == nil then gary = nil return end
			garyhUnit = gary.hUnit
			TEAM_CAPTAIN_UNIT:ActionImmediate_Chat("Starting debug creep tracking", true)
		end
		if Unit_IsNullOrDead(gary) then 
			DebugDrawText(0, 600, string.format(" :( "), 255, 255, 255)
			return
		end
		local lastAttackRelease = garyhUnit:GetLastAttackTime()
		local unitAttacked = garyhUnit:GetAttackTarget()
		local projSpeed = garyhUnit:GetAttackProjectileSpeed()
		if garyLastAttackSeen ~= lastAttackRelease then
			animCycleAtRelease = garyhUnit:GetAnimCycle()
			garyLastAttackSeen = lastAttackRelease
			catchNextProjectileLands = true
		end
		local incomingProjectiles = garyhUnit:GetIncomingTrackingProjectiles()
		for i=0,#incomingProjectiles do
			if incomingProjectiles[i] then
				local dist2D = Vector_PointDistance2D(incomingProjectiles[i].location, garyhUnit:GetLocation())
				if dist2D < closestGetsHitDist then
					getsHitClosest = incomingProjectiles[i].location
					closestGetsHitDist = dist2D
				end
			end
		end

		if unitAttacked then
			currentProjectile = unitAttacked:GetIncomingTrackingProjectiles()
			for i=0,#currentProjectile do
				if currentProjectile[i] then
					if currentProjectile[i].caster == garyhUnit then
						currentProjectile = currentProjectile[i] -- #attProj
						break;
					end
				end
				if i == #currentProjectile then currentProjectile = nil end
			end
			if currentProjectile then -- #attProj
				landingTime = catchNextProjectileLands and GameTime() or landingTime
				locOfProjectileAtRelease = catchNextProjectileLands and currentProjectile.location or locOfProjectileAtRelease
				catchNextProjectileLands = false
			end
		end
		DebugDrawText(0, 600, 
				string.format("long name:%s\n"..
						"time:%s\n"..
						"address:%s\n"..
						"location:(%d, %d, %d)\n"..
						"closestGetsHitProjectile:(%d, %d, %d)\n"..
						"locProjectileRelease:(%d, %d, %d)\n"..
						"reductionDistToTarget:%.1f\n"..
						"attacking:%s\n"..
						"animCycle:%.4f\n"..
						"attackPoint:%.2f\n"..
						"attackPointPercent:%.4f\n"..
						"attackRange:%d\n"..
						"projectileSpeed:%d\n"..
						"TTLProj:%.2f\n"..
						"GNACProj:%.2f\n"..
						"lastAttackTime:%.4f\n"..
						"actionType:%d\n"..
						"animActivity:%d\n"..
						"animCycleAtRelease:%.4f\n"..
						"landingTime:%.4f\n"..
						"timeInAir:%.4f\n"..
						"expected2D:%.4f\n"..
						"expected3D:%.4f\n"..
						"rangeToTarget:%.4f",
					gary.name, 
					GameTime(),
					tostring(garyhUnit),
					garyhUnit:GetLocation().x, garyhUnit:GetLocation().y, garyhUnit:GetLocation().z,
					getsHitClosest.x, getsHitClosest.y, getsHitClosest.z,
					locOfProjectileAtRelease.x, locOfProjectileAtRelease.y, locOfProjectileAtRelease.z,
					unitAttacked and Vector_PointDistance(garyhUnit:GetLocation(), unitAttacked:GetLocation())
							- Vector_PointDistance(locOfProjectileAtRelease, unitAttacked:GetLocation()) or -0,
					tostring(garyhUnit:GetAttackTarget()), 
					garyhUnit:GetAnimCycle(),
					gary.attackPointPercent * garyhUnit:GetSecondsPerAttack(),
					gary.attackPointPercent,
					garyhUnit:GetAttackRange(),
					projSpeed,
					unitAttacked and Unit_GetSafeUnit(unitAttacked) and select(1,unitAttacked and Projectile_TimeToLandProjectile(gary,
							Unit_GetSafeUnit(unitAttacked)
						)) or -0,
					select(2, Projectile_GetNextAttackComplete(gary)) or -0,
					garyhUnit:GetLastAttackTime(),
					garyhUnit:GetCurrentActionType(),
					garyhUnit:GetAnimActivity(),
					animCycleAtRelease,
					landingTime,
					landingTime - garyhUnit:GetLastAttackTime(),
					unitAttacked and Vector_PointDistance2D(garyhUnit:GetLocation(), unitAttacked:GetLocation()) / projSpeed or 0,
					unitAttacked and Vector_PointDistance(garyhUnit:GetLocation(), unitAttacked:GetLocation()) / projSpeed or 0,
					unitAttacked and Vector_PointDistance(
							garyhUnit:GetAttackTarget():GetLocation(), garyhUnit:GetLocation()) or 0.0000
				),
				255, 255, 255
			)
		DebugDrawCircle(gary.lastSeen.location, 20, 200, 200, 255)
		if not gary.sadAndDead then
			if not garyhUnit:IsAlive() then
				gary.sadAndDead = true
			end
			--print(garyhUnit:GetLocation(), gary.lastSeen.location, gary.lastSeenHealth, gary.isNull(garyhUnit), gary.hUnit:IsNull(), garyhUnit:IsDead())
		else
			--print(gary, garyhUnit, gary.lastSeen.location, gary.lastSeenHealth, gary.isNull(garyhUnit), gary.hUnit:IsNull())
			--print(garyhUnit:IsNull())
		end
	end
end

local xNice = 0
local DBGColor = {0, 0, 0}
local DBGNiceT = 0
function DEBUG_NicePrint(str, ...)
	local TC = Captain_GetCaptain()
	if not TC then return end;
	if DBGNiceT < TC.time.currFrame then
		DBGNiceT = TC.time.currFrame + (TC.time.nextFrame - TC.time.currFrame)/2
		DebugDrawText(950, 85, string.format("redraw %.3f; nF %.3f; cF %.3f; gt %.3f",
					DBGNiceT, TC.time.nextFrame, TC.time.currFrame, GameTime()
				),
				DBGColor[1], DBGColor[2], DBGColor[3]
			)
		xNice = 9
	end
	
	DebugDrawText(950, 85+xNice, string.format(str, ...), DBGColor[1], DBGColor[2], DBGColor[3])
	
	xNice = xNice + 9
end

function DEBUG_StartTestParty()
	local p = GSI_GetTeamPlayers(TEAM)
	for i=1,#p do
		if true or i~=4 then
			DOMINATE_SetDominateFunc(p[i], "DEBUG_TestParty", DEBUG_TestParty, true)
		end
	end
end

local stage = 0
local dbgTpTbl = {}
function DEBUG_TestParty(gsiPlayer)
	TEST_PARTY = true
	TEST_PARTY_PRINT = false
	Time_IndicateNewFrame(gsiPlayer)
	local vadd = Vector_Addition
	local vsca = Vector_ScalarMultiply
	local vfdeg = Vector_UnitDirectionalFacingDegrees
	local vdist = Vector_PointDistance
	local vud = Vector_UnitDirectionalPointToPoint
	local vufu = Vector_UnitFacingUnit
	local vec = Vector
	local dnp = DEBUG_NicePrint

	local t = dbgTpTbl
	local h = gsiPlayer.hUnit
	local m = h.Action_MoveDirectly
	local a = h.Action_AttackUnit

	local pl = h:GetLocation()

	local curr = GameTime()

	local tpN = 4

	local nE = Set_GetEnemyHeroesInPlayerRadius(gsiPlayer, 2000)
	local targ = GSI_GetTeamPlayers(ENEMY_TEAM)[tpN]
	local th = targ.hUnit
	local targReal = th and not targ.needsVisibleData and not th:IsNull() and th:IsAlive()
	local targLoc = targReal and th:GetLocation()

	local isatt = not TEAM_IS_RADIANT  -- will be attacking

	print("n", #nE, gsiPlayer.nOnTeam, tpN)
	
	local bountyLoc = GetRuneSpawnLocation(RUNE_BOUNTY_2) or TEAM_FOUNTAIN
	local thatSide = GetTeam() == gsiPlayer.nOnTeam % 2 + 2
	if gsiPlayer.nOnTeam ~= tpN then
		local meMoveTo = vadd(bountyLoc, vsca(
				vec(sin(thatSide and -1 or 1)*gsiPlayer.nOnTeam/1.59,
					cos(thatSide and -1 or 1)*gsiPlayer.nOnTeam/1.59
				),
				600)
			)
		m(h, meMoveTo)
		print(gsiPlayer.shortName, "might move to", meMoveTo)
		local distDesig = vdist(pl, meMoveTo)
		if distDesig > 1450 then
			gsiPlayer.DBGGetBackTime = curr + 8
		elseif not gsiPlayer.DBGresetTreeCut or gsiPlayer.DBGresetTreeCut < curr then
			if gsiPlayer.nOnTeam == 3 then
				print("333333", gsiPlayer.shortName, distDesig)
				local creeps = h:GetNearbyCreeps(1600, true)
				if creeps[1] then
					a(h, creeps[1], false)
				end
			elseif gsiPlayer.nOnTeam >= 4 then
				local trees = h:GetNearbyTrees(1500)
				local hatchet = h:FindItemSlot("item_quelling_blade")
				print("44545454545", #trees, trees[1], hatchet)
				hatchet = hatchet > -1 and hatchet < 9 and h:GetItemInSlot(hatchet)
				print("44545454545", hatchet)
				if trees[1] and hatchet then
					if curr % 10 < 2 then
						m(h, meMoveTo)
					elseif curr % 3 < 1 then
						h:Action_UseAbilityOnTree(hatchet, trees[1])
					else
						h:Action_MoveDirectly(GetTreeLocation(trees[1]))
					end
				end
			end
		end
		if gsiPlayer.nOnTeam == 5 then
			h:ActionImmediate_PurchaseItem("item_ward_observer")
			local ob = h:GetItemInSlot(h:FindItemSlot("item_ward_observer"))
			if ob then
				local offset = RandomInt(-500, 500)
				h:Action_UseAbilityOnLocation(ob, Vector(bountyLoc.x + offset, bountyLoc.y + offset))
			end
		end
		m(h, meMoveTo)
		return;
	end
	t.ttlStartsNow = targReal and Projectile_TimeToLandProjectile(gsiPlayer, targ)
	gnacTarg, t.ttlLive, needs = Projectile_GetNextAttackComplete(gsiPlayer, t.startHitsT1 ~= nil)
	if isatt then
		-- [[ PRINTS ]]
		dnp("stage: %d", stage)
		DEBUG_NicePrint("@%s, dist %s, facingToUnit-1to1 %s, animActivity %s",
				targReal and string.sub(targ.shortName, 1, 5), targReal and vdist(pl, targ.hUnit:GetLocation()),
				vufu(gsiPlayer, targ), h:GetAnimActivity())
		dnp("targVec (%.3f, %.3f, %.3f), acquiredTarget %s", targReal and targLoc.x or -0, targReal and targLoc.y or -0, targReal and targLoc.z or -1, Util_Printable(h:GetAttackTarget()))
		dnp("secPAttk %s, atkPnt %s, atkReleaseSec %s, animCycle %s",  h:GetSecondsPerAttack(), h:GetAttackPoint(),
				h:GetSecondsPerAttack()*h:GetAttackPoint(), h:GetAnimCycle())
		dnp("projectileSpeed %s, vulftAttackPoint %s, vulftReleaseSec %s", h:GetAttackProjectileSpeed(),
				gsiPlayer.attackPointPercent, h:GetSecondsPerAttack()*gsiPlayer.attackPointPercent)
		dnp("lastAttack %s", h:GetLastAttackTime())
		dnp("trueRange %s", h:GetAttackRange())
		dnp("RangeStartAttack %s", t.startDist0)
		dnp("ttlStartsNow %s; ttlStartsNowEnd %s; ttlLive %s; ttlLiveEnd %s", t.ttlStartsNow,
				t.ttlStartsNow and curr+t.ttlStartsNow, t.ttlLive, t.ttlLive and curr+t.ttlLive)
		dnp("startDeg %s; startTtl %s; landsT %s", t.startDeg0, t.startTtl0, t.startLands0)
		dnp("projectileStart %s; projectileLandsEst %s", t.startProj1, t.startHitsT1)
		dnp("projInformed: %s", t.startHitsFlyingT1)
		dnp("gnacT %s; gnacHits %s; gnacNeeds %s", Util_Printable(gnacTarg), t.ttlLive, needs)
	end

	print(gsiPlayer.shortName, "TEST OF TEAM")


	local moveTo = t.moveTo or vadd(bountyLoc, vsca(vec(sin((TEAM_IS_RADIANT and pi*1.5 or pi*0.5)), 0), 600))
	if not isatt then
		m(h, moveTo)
		Lhp_AttackNowForBestLastHit(gsiPlayer, GSI_GetTeamPlayers(TEAM)[1])
		DEBUG_LHP_DrawLhpTarget(GSI_GetTeamPlayers(TEAM)[1], GSI_GetTeamPlayers(TEAM)[1].hUnit)
	elseif stage == 0 and isatt then
		-- [[ STAGE 0 ]]
		local delay = t.delay
		m(h, moveTo)
		local distNow = vdist(pl, moveTo)
		if targReal and distNow < 50 then
			t.delay = t.delay or curr + 0.5
			if t.delay < curr and not t.startDist0 then
				t.startDist0 = vdist(pl, th:GetLocation())
				t.startDeg0 = vufu(gsiPlayer, targ)
				t.startTtl0 = Projectile_TimeToLandProjectile(gsiPlayer, targ)
				t.startLands0 = curr + t.startTtl0
				stage = 1
				a(h, th, false)
			end
		end
	elseif stage == 1 then
		-- [[ STAGE 1 ]]
		if not gnacTarg then return; end
		local projectiles = th:GetIncomingTrackingProjectiles()
		local thisProj = projectiles and projectiles[1]
		if not t.startHitsT1 then
			if gnacTarg and needs then
				t.startHitsT1 = curr + t.ttlLive
			end
		elseif not needs and thisProj and thisProj.caster == h then
			local locP = thisProj.location
			t.startProj1 = locP
			t.startHitsFlyingT1 = curr + t.ttlLive
			
			--h:Action_ClearActions(true)
			--stage = 2
		end
		a(h, th, false)
	end
end

function DEBUG_DrawCreepData(gsiCreep)
	DebugDrawCircle(gsiCreep.lastSeen.location, 5, gsiCreep.hUnit:GetTeam() == TEAM_DIRE and 255 or 30, gsiCreep.hUnit:GetTeam() == TEAM_RADIANT and 255 or 30, 30)
end

function DEBUG_PlayerIDDominate(playerID, func)
	print("DOING THAT")
	if playerID == -1 then
		local players = GSI_GetTeamPlayers(TEAM)
		for i=1,#players do
			DOMINATE_SetDominateFunc(players[i], "DEBUGOneWay", func, true)
		end
		return;
	end
	DOMINATE_SetDominateFunc(GSI_GetPlayerFromPlayerID(playerID), "DEBUG_PlayerIDDominate", func, true)
end

function DEBUG_GetPlayerIDRune(gsiPlayer)
	local function print_info()
		if GetBot():GetPlayerID() == 5 then
			for i=-1,7 do
				print("Rune status:", i, GetRuneStatus(i))
			end
		end
		print("POWERUP1", RUNE_POWERUP_1, "POWERUP2", RUNE_POWERUP_2,
				"BOUNTY1", RUNE_BOUNTY_1, "BOUNTY2", RUNE_BOUNTY_2,
				"BOUNTY3", RUNE_BOUNTY_3, "BOUNTY4", RUNE_BOUNTY_4
			)
	end

	if gsiPlayer.playerID == 3 then
		for i=15,15 do
			local units = GetUnitList(i)
			if units then
				for j=1,#units do
					local l = units[j]:GetLocation()
					print(i, units[j]:GetUnitName(), units[j]:GetHealth())
					if units[j]:GetHealth() == 0 then
						print("::::", units[j]:GetName())
						for k,v in pairs(units[j]) do
							print(k, v)
						end
						DebugDrawCircle(l, 80, 255, 255, 255)
					else
						DebugDrawCircle(l, 80, 255, 0, 0)
					end
				end
			end
		end
	end

	print_info()
	local gt = math.floor(GameTime()%10)
	if RandomInt(1,4) == 10 then
		print(GetBot():GetPlayerID(), "tries grab", -20 + 10*gt + (GetBot():GetPlayerID()))
		GetBot():Action_PickUpRune(GetBot():GetPlayerID() % 8)
	end
end

local dnc_locations
local dnc_draw_x
local dnc_draw_y
local DNC_UNIT_LENGTH = 25
local HALF_DNC_UNIT_LENGTH = DNC_UNIT_LENGTH / 2
local bot_last_time = {GameTime(), GameTime(), GameTime(), GameTime()}
local bot_i = {}
local bot_j = {}
local dnc_direction_flip = {1, 1, 1, 1}
function DEBUG_DNCMoveNext(gsiPlayer)
	local nOnTeam = gsiPlayer.nOnTeam
	local iBot = bot_i[nOnTeam]
	local jBot = bot_j[nOnTeam]
	local currTime = GameTime()
	if dnc_locations[iBot][jBot] or currTime-bot_last_time[nOnTeam] > 5 then
		bot_last_time[nOnTeam] = currTime
		if iBot >= 16000/DNC_UNIT_LENGTH and dnc_diretion_flip[nOnTeam] == 1 or iBot >= 16000/DNC_UNIT_LENGTH and dnc_direction_flip[nOnTeam] then
			bot_j[nOnTeam] = jBot + 1
			dnc_direction_flip[nOnTeam] = dnc_direction_flip[nOnTeam] == 1 and -1 or 1
		end
	end
	bot_last_time[nOnTeam] = 0
	gsiPlayer.hUnit:Action_MoveDirectly(Vector(bot_i[gsiPlayer.nOnTeam], bot_j[gsiPlayer.nOnTeam], 0))
end
function DEBUG_DNCPathingAllowedReportLocation(location, pathingAllowed)
	if divide_and_conquer_locations == nil then
		dnc_locations = {}
		for n=1,4,1 do
			bot_i[n] = (n-1)*16000/4/DNC_UNIT_LENGTH
			bot_j[n] = 0
		end
		for unitX=0,16000/DNC_UNIT_LENGTH,1 do
			dnc_locations[unitX] = {}
		end
		InstallChatCallback(
					function(args) 
						if args.player_id == 0 then
							if args.string == "dnc -draw" then 
								local xVal = string.gmatch(args, "dnc -draw [%d]")
								print(xVal)	
							elseif args.string == "dnc -nodraw" then
								dnc_draw_x = nil -- & set draw conditional false
								dnc_draw_y = nil
							end
						end
					end
				)
	end
	if location then
		dnc_locations[(location.x - 8000) / DNC_UNIT_LENGTH][(location.y - 8000) / DNC_UNIT_LENGTH] = pathingAllowed
	end
	if dnc_draw_x and GetBot():GetPlayerID() == 1 or GetBot:GetPlayerID() == 5 then
		for x=0,16000/DNC_UNIT_LENGTH,1 do
			for y=0,16000/DNC_UNIT_LENGTH,1 do
				DebugDrawCircle(Vector(x*DNC_UNIT_LENGTH+HALF_DNC_UNIT_LENGTH, y*DNC_UNIT_LENGTH+HALF_DNC_UNIT_LENGTH, 0), HALF_DNC_UNIT_LENGTH, dnc_locations[x][y] and 50 or 255, dnc_locations[x][y] and 255 or 50, dnc_locations[x][y] == nil and 255 or 0)
			end
		end
	end	
end

function DEBUG_DrawLaneCurve()
	local prevPoint, currPoint
	local bottomSpawner = Map_GetLogicalLocation(MAP_POINT_RADIANT_BOTTOM_SPAWNER)
	prevPoint = Vector(X_TO_Y_SIDE_LANE_FACTOR*lane_value_sigmoid_early(0.0)+bottomSpawner.x, lane_value_sigmoid_late(0.0)+bottomSpawner.y, 256)
	for progress=0.0,1.0,0.01 do
		local x = (X_TO_Y_SIDE_LANE_FACTOR*lane_value_sigmoid_early(progress))+bottomSpawner.x
		local y = lane_value_sigmoid_late(progress)+bottomSpawner.y
		currPoint = Vector(x, y, 128)
		local intensity = Math_PointToPointDistance2D(currPoint, prevPoint) * 255 / 650
		if progress > 0.415 and progress < 0.425 then DebugDrawCircle(currPoint, 200, intensity, 50, intensity) 
		elseif progress > 0.575 and progress < 0.585 then DebugDrawCircle(currPoint, 200, intensity, 50, intensity) end
		DebugDrawLine(prevPoint, currPoint, 0, 120, intensity)
		prevPoint = currPoint
	end
	local topSpawner = Map_GetLogicalLocation(MAP_POINT_RADIANT_TOP_SPAWNER)
	prevPoint = Vector(X_TO_Y_SIDE_LANE_FACTOR*lane_value_sigmoid_late(0.0)+topSpawner.x, lane_value_sigmoid_early(0.0)+topSpawner.y, 256)
	for progress=0.0,1.0,0.01 do
		local x = (X_TO_Y_SIDE_LANE_FACTOR*lane_value_sigmoid_late(progress))+topSpawner.x
		local y = lane_value_sigmoid_early(progress)+topSpawner.y
		currPoint = Vector(x, y, 128)
		local intensity = Math_PointToPointDistance2D(currPoint, prevPoint) * 255 / 650
		DebugDrawLine(prevPoint, currPoint, 0, 120, intensity)
		if progress > 0.415 and progress < 0.425 then DebugDrawCircle(Vector(x, y, 0), 200, intensity, 50, intensity) 
		elseif progress > 0.575 and progress < 0.585 then DebugDrawCircle(Vector(x, y, 0), 200, intensity, 50, intensity) end
		prevPoint = currPoint
	end
	-- Dire
	local prevPoint, currPoint
	local bottomSpawner = Map_GetLogicalLocation(MAP_POINT_DIRE_BOTTOM_SPAWNER)
	prevPoint = Vector(-X_TO_Y_SIDE_LANE_FACTOR*lane_value_sigmoid_late(0.0)+bottomSpawner.x, -lane_value_sigmoid_early(0.0)+bottomSpawner.y, 256)
	for progress=0.0,1.0,0.01 do
		local x = -(X_TO_Y_SIDE_LANE_FACTOR*lane_value_sigmoid_late(progress))+bottomSpawner.x
		local y = -lane_value_sigmoid_early(progress)+bottomSpawner.y
		currPoint = Vector(x, y, 128)
		local intensity = Math_PointToPointDistance2D(currPoint, prevPoint) * 255 / 650
		if progress > 0.415 and progress < 0.425 then DebugDrawCircle(currPoint, 200, 50, intensity, intensity) 
		elseif progress > 0.575 and progress < 0.585 then DebugDrawCircle(currPoint, 200, 50, intensity, intensity) end
		DebugDrawLine(prevPoint, currPoint, 120, 0,  intensity)
		prevPoint = currPoint
	end
	local topSpawner = Map_GetLogicalLocation(MAP_POINT_DIRE_TOP_SPAWNER)
	prevPoint = Vector(-X_TO_Y_SIDE_LANE_FACTOR*lane_value_sigmoid_early(0.0)+topSpawner.x, -lane_value_sigmoid_late(0.0)+topSpawner.y, 256)
	for progress=0.0,1.0,0.01 do
		local x = -(X_TO_Y_SIDE_LANE_FACTOR*lane_value_sigmoid_early(progress))+topSpawner.x
		local y = -lane_value_sigmoid_late(progress)+topSpawner.y
		currPoint = Vector(x, y, 128)
		local intensity = Math_PointToPointDistance2D(currPoint, prevPoint) * 255 / 650
		DebugDrawLine(prevPoint, currPoint, 120, 0,  intensity)
		if progress > 0.415 and progress < 0.425 then DebugDrawCircle(Vector(x, y, 0), 200, 50, intensity,  intensity) 
		elseif progress > 0.575 and progress < 0.585 then DebugDrawCircle(Vector(x, y, 0), 200, 50, intensity,  intensity) end
		prevPoint = currPoint
	end
end

function DEBUG_DrawLhpTarget(gsiPlayer)
	DEBUG_LHP_DrawLhpTarget(gsiPlayer)
end

local trees = GetBot():GetNearbyTrees(1600)
local treesIndex = 1
function DEBUG_PrintPassableTrees()
	if treesIndex > #trees then return end
	local thisTreeLoc = GetTreeLocation(trees[treesIndex])
	TEAM_CAPTAIN_UNIT:ActionImmediate_Ping(thisTreeLoc.x, thisTreeLoc.y, IsLocationPassable(thisTreeLoc))
	treesIndex = treesIndex + 1
end

function DEBUG_DevBehaviorOverride()
end

NastyCheck = {}
--[[]]
NastyCheck["TaskScoring"] = {
		function(stage, ...)
			args={...}
			if TEAM_IS_RADIANT then
				return
			end
			local enemies = GSI_GetTeamPlayers(ENEMY_TEAM)
			for i=1,5 do
				print(args[1], test_wtf[i], enemies[i].lastSeen.location)
			end
		end,
		nil -- if any relevant data tbl
	}
--]]
function DEBUG_NastyCheck(key, stage, ...)
	if NastyCheck[key] then
		if VERBOSE then VEBUG_print("NastyCheck '"..key.."'#"..(stage or 'n/a')) end
		NastyCheck[key][1](stage, ...)
	end
end
