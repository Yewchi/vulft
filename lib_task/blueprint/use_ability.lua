-- Other tasks trigger the scoring, and essentially the highest scoring task request incentivises this task for it's purposes.
-- Abilities already in-cast are also incentivised. Probably needs some "this is taking way too long"

local PRIORITY_UPDATE_USE_ABILITY_THROTTLE = 0.071 -- Rotates. 

local QUEUED_ABILITY_I__ABILITY_OR_FUNC = 1
local QUEUED_ABILITY_I__TARGET = 2
local QUEUED_ABILITY_I__SCORE = 3
local QUEUED_ABILITY_I__COMBO_IDENTIFIER = 4
local QUEUED_ABILITY_I__ACTION_FUNC = 5
local QUEUED_ABILITY_I__EXPIRY = 6
local QUEUED_ABILITY_I__PREV_NODE = 7
local QUEUED_ABILITY_I__NEXT_NODE = 8

local XETA_SCORE_DO_NOT_RUN = XETA_SCORE_DO_NOT_RUN
local SPELL_SUCCESS = AbilityLogic_CastOnTargetWillSucceed

local queue_node_recyclable = {}

local t_abilities_queued = {} -- player number on team -> list head

local task_handle = Task_CreateNewTask()

local blueprint

local number_str = "number"

-- RULE OF USE Do not give me a hAbility that is already on the queue. It must be in a combo if there are to be multiple of the same ability used in a sequence.

---- On chosing a list: array benefit was only for score-based removal
local function free_queue_node(node)
	node[QUEUED_ABILITY_I__PREV_NODE] = false		 -- 5
	node[QUEUED_ABILITY_I__NEXT_NODE] = false		 -- 6 ... 
	table.insert(queue_node_recyclable, node)
end

local function alloc_or_recycle_queue_node(hAbility, target, score, comboIdentifier, actionFunc, elapseExpiry)
	local new = table.remove(queue_node_recyclable) or {}
	new[1] = hAbility							 -- 1
	new[2] = target								 -- 2
	new[3] = score or HIGH_32_BIT				 -- 3
	new[4] = comboIdentifier or false			 -- ..4 -- recycled node is clean
	if not comboIdentifier and not actionFunc then print("ACTION FUNC NIL", debug.traceback()) end
	new[5] = actionFunc
	new[6] = GameTime() + (elapseExpiry or (hAbility:GetCastPoint() + hAbility:GetChannelTime() + 1)) -- NB. 1 sec limit on combo behaviour -- UseAbility_RefreshQueueTop(gsiPlayer) for long sequences
	
	return new
end

local function take_and_sew_queue_node(pnot, node)
	local prevNode = node[QUEUED_ABILITY_I__PREV_NODE]
	local nextNode = node[QUEUED_ABILITY_I__NEXT_NODE]
	if prevNode then
		prevNode[QUEUED_ABILITY_I__NEXT_NODE] = nextNode
	else
		t_abilities_queued[pnot] = nextNode
	end
	if nextNode then
		nextNode[QUEUED_ABILITY_I__PREV_NODE] = prevNode
	else
		t_abilities_queued[pnot] = false
	end
	free_queue_node(node)
end

local registered_callbacks = {}
function UseAbility_RegisterCallbackFunc(gsiPlayer, ability, funcToCall)
	local pnot = gsiPlayer.nOnTeam
	local abilityName = ability:GetName()
	if not registered_callbacks[pnot] then
		registered_callbacks[pnot] = {}
	end
	local thisPlayerCallbacks = registered_callbacks[pnot]
	if not thisPlayerCallbacks[abilityName] then
		thisPlayerCallbacks[abilityName] = {}
	end
	table.insert(thisPlayerCallbacks[abilityName], funcToCall)
end

function UseAbility_IndicateCastCompleted(castInfo) -- Installed @ AbilityThink_Initialize()
	if VERBOSE then print("DOUBLE CALLBACKS?", castInfo.ability:GetName()) end
	local gsiPlayer = GSI_GetPlayerFromPlayerID(castInfo.player_id) if gsiPlayer.team ~= TEAM then return end 
	local currentlyCasting = gsiPlayer.hUnit:GetCurrentActiveAbility()
	local abilityName = castInfo.ability:GetName()
	
	-- process registered callbacks
	local callbacks = registered_callbacks[gsiPlayer.nOnTeam]
	callbacks = callbacks and callbacks[abilityName]
	if callbacks then
		if VERBOSE then print("found callback for", gsiPlayer.shortName, abilityName) end
		for i=1,#callbacks do
			callbacks[i](gsiPlayer, castInfo.ability, castInfo)
		end
	end
	-- if the cast is ending; or if it is not a channeling spell and we hit the cast point...
	if (not castInfo.channel_start or (currentlyCasting and currentlyCasting:GetName() ~= abilityName)) then
		local pnot = gsiPlayer.nOnTeam
		local currAbilityNode = t_abilities_queued[pnot]
		local i=1
		-- loop until we...
		while(currAbilityNode) do i = i + 1 if i>100 then DEBUG_KILLSWITCH = true ERR_print("use_ability: UseAbility_IndicateCastCompleted KILLSWITCH") return end
			local thisAbilityOrFunc = currAbilityNode[QUEUED_ABILITY_I__ABILITY_OR_FUNC]
			if type(thisAbilityOrFunc) == "table" then
				-- ... find the event spell highest in the queue and remove it
				if thisAbilityOrFunc.GetName and thisAbilityOrFunc:GetName() == abilityName then
					if ChargedCooldown_IsChargedCooldown(gsiPlayer, thisAbilityOrFunc) then -- usually false >>>
						ChargedCooldown_ExistsDecrementCharges(gsiPlayer, thisAbilityOrFunc)
					end
					take_and_sew_queue_node(pnot, t_abilities_queued[pnot])
					return
				end
			end
			currAbilityNode = currAbilityNode[QUEUED_ABILITY_I__NEXT_NODE]
		end
	end
end


-------- UseAbility_SetComboScore(...)
-- - For reprioritizing combos that have been put to sleep by
-- - - dropping their score to XETA_SCORE_DO_NOT_RUN. Invoker
-- - - e.g. should continue movement when enemies are in a
-- - - long tornado airtime.
function UseAbility_SetComboScore(gsiPlayer, comboIdentifier)
	local currNode = t_abilities_queued[gsiPlayer.nOnTeam]
	local i = 1
	while(currNode) do i = i + 1
		if i>100 then DEBUG_KILLSWITCH = true print("UseAbility_SetComboScore KILLSWITCH") Util_ThrowError() end
		local nextNode = currNode[QUEUED_ABILITY_I__NEXT_NODE]
		if currNode[QUEUED_ABILITY_I__COMBO_IDENTIFIER] == comboIdentifier then
			take_and_sew_queue_node(gsiPlayer.nOnTeam, currNode)
			if VERBOSE then VEBUG_print(string.format("use_ability: Popped %s front ability comboId:'%s'.", gsiPlayer.shortName, comboIdentifier)) end
			return;
		end
		currNode = nextNode
	end
end

function UseAbility_PopComboQueue(gsiPlayer, comboIdentifier)
	local currNode = t_abilities_queued[gsiPlayer.nOnTeam]
	local i = 1
	while(currNode) do i = i + 1 if i>100 then DEBUG_KILLSWITCH = true print("UseAbility_ClearQueuedAbilities KILLSWITCH")  return end
		local nextNode = currNode[QUEUED_ABILITY_I__NEXT_NODE]
		if currNode[QUEUED_ABILITY_I__COMBO_IDENTIFIER] == comboIdentifier then
			take_and_sew_queue_node(gsiPlayer.nOnTeam, currNode)
			if VERBOSE then VEBUG_print(string.format("use_ability: Popped %s front ability comboId:'%s'.", gsiPlayer.shortName, comboIdentifier)) end
			return;
		end
		currNode = nextNode
	end
end

-- function UseAbility_IncrementPreviousCharges(gsiPlayer, hAbility)
	-- local currAbilityNode = t_abilities_queued[pnot]
	-- while(currAbilityNode) do
		-- if currAbilityNode[QUEUED_ABILITY_I__ABILITY_OR_FUNC]:GetName() == hAbility:GetName() then
			-- currAbilityNode[QUEUED_ABILITY_I__PREV_CHARGES] = currAbilityNode[QUEUED_ABILITY_I__PREV_CHARGES] + 1
			-- return
		-- end
	-- end
-- end

function UseAbility_ClearQueuedComboAbilities(gsiPlayer, comboIdentifier)
	local currNode = t_abilities_queued[gsiPlayer.nOnTeam]
	local pnot = gsiPlayer.nOnTeam
	local i = 1
	while(currNode) do i = i + 1 if i>100 then DEBUG_KILLSWITCH = true print("UseAbility_ClearQueuedAbilities KILLSWITCH")  return end
		local nextNode = currNode[QUEUED_ABILITY_I__NEXT_NODE]
		if currNode[QUEUED_ABILITY_I__COMBO_IDENTIFIER] == comboIdentifier then
			if VERBOSE then print('clearing', currNode) end
			take_and_sew_queue_node(pnot, currNode)
		end
		currNode = nextNode
	end
	if VERBOSE then VEBUG_print(string.format("use_ability: Cleared %s combo with comboId:'%s'.", gsiPlayer.shortName, comboIdentifier)) end
end

function UseAbility_ClearQueuedAbilities(gsiPlayer, scoreBreaking)
	local currNode = t_abilities_queued[gsiPlayer.nOnTeam]
	local pnot = gsiPlayer.nOnTeam
	if not scoreBreaking then -- clear list
		local i = 1
		while(currNode) do i = i + 1 if i>100 then DEBUG_KILLSWITCH = true print("UseAbility_ClearQueuedAbilities KILLSWITCH")  return end
			local nextNode = currNode[QUEUED_ABILITY_I__NEXT_NODE]
			free_queue_node(currNode)
			currNode = nextNode
		end
		t_abilities_queued[gsiPlayer.nOnTeam] = false
	else -- clear list of abilities with low score
		while(currNode) do
			local nextNode = currNode[QUEUED_ABILITY_I__NEXT_NODE]
			if abilityLock[QUEUED_ABILITY_I__SCORE] <= scoreBreaking then -- n.b. will not clear no-score-given ability uses if "<" but not "<="
				--if abilityLock[QUEUED_ABILITY_I__COMBO_IDENTIFIER] then
				--	Combo_InformClearingCombo(gsiPlayer, abilityLock[QUEUED_ABILITY_I__COMBO_IDENTIFIER])
				--end
				take_and_sew_queue_node(pnot, currNode)
			end
			currNode = nextNode
		end
	end
	if VERBOSE then VEBUG_print(string.format("use_ability: Cleared %s ability queue. Abilities remaining: %s", gsiPlayer.shortName, tostring(t_abilities_queued[pnot]))) end
end

function UseAbility_RegisterAbilityUseAndLockToScore(gsiPlayer, abilityOrFunc, target, scoreToBreak, comboIdentifier, doNotCastPointSkip, skipQueue, elapseExpiry, forceAbilityFunc)
	local nOnTeam = gsiPlayer.nOnTeam
	scoreToBreak = scoreToBreak or HIGH_32_BIT

	local isAbility = type(abilityOrFunc) == "table" and true or false
	local actionFunc = forceAbilityFunc

	print(Util_Printable(abilityOrFunc), type(abilityOrFunc))
	
	if isAbility and not forceAbilityFunc then
		actionFunc = AbilityLogic_GetBestFitCastFunc(gsiPlayer, abilityOrFunc, target)
	end

	if TEST then print("use_ability: [RegisterAbilityUseAndLockToScore]", gsiPlayer.shortName, isAbility and abilityOrFunc:GetName() or 'func', target, target and target.shortName, isAbility, actionFunc, forceAbilityFunc) end

	if skipQueue or (isAbility and not doNotCastPointSkip and abilityOrFunc:GetCastPoint() == 0) then -- e.g. spells with 0.0 cast point can be cast immediately even if other spells are to be cast -- TODO Does it need a facing direction? Probably should have target-in-range check and ability-needs-correct-facing-direction -- doNotCastPointSkip is because we may queue stun -> safety TP type behaviour.
		local nextNode = t_abilities_queued[nOnTeam]
		t_abilities_queued[nOnTeam] = alloc_or_recycle_queue_node(abilityOrFunc, target, scoreToBreak, comboIdentifier, actionFunc, elapseExpiry)
		t_abilities_queued[nOnTeam][QUEUED_ABILITY_I__NEXT_NODE] = nextNode
		if nextNode then nextNode[QUEUED_ABILITY_I__PREV_NODE] = t_abilities_queued[nOnTeam] end
	else
		local stepNode = t_abilities_queued[nOnTeam]
		if stepNode then -- usually stepNode == nil -> assign new ability
			local i = 1
			while(stepNode and stepNode[QUEUED_ABILITY_I__NEXT_NODE]) do  i = i + 1 if i > 98 then Util_TablePrint({stepNode[1]:GetName(), stepNode}) if i>100 then DEBUG_KILLSWITCH = true ERROR_print("use_ability: UseAbility_RegisterAbilityUseAndLockToScore KILLSWITCH") return  end end
				stepNode = stepNode[QUEUED_ABILITY_I__NEXT_NODE]
			end
			local newNode = alloc_or_recycle_queue_node(abilityOrFunc, target, scoreToBreak, comboIdentifier, actionFunc, elapseExpiry or 1)
			stepNode[QUEUED_ABILITY_I__NEXT_NODE] = newNode
			newNode[QUEUED_ABILITY_I__PREV_NODE] = stepNode
		else
			t_abilities_queued[nOnTeam] = alloc_or_recycle_queue_node(abilityOrFunc, target, scoreToBreak, comboIdentifier, actionFunc, elapseExpiry or 1)
		end
	end
end

-- return: isLocked, isHAbility, abilityOrFunc
function UseAbility_IsPlayerLocked(gsiPlayer)
	local nextAbilityNode = t_abilities_queued[gsiPlayer.nOnTeam]
	if nextAbilityNode then
		return	true,
				type(nextAbilityNode[QUEUED_ABILITY_I__ABILITY_OR_FUNC]) == "table" and true or false,
				nextAbilityNode[QUEUED_ABILITY_I__ABILITY_OR_FUNC]
	else
		return false, false, nil
	end
end

function UseAbility_RefreshQueueTop(gsiPlayer) 
	-- Call this inside of combo functions that may run over 1s long. (Expiry gives castpoint + channel time + 1s). Combo function include it's own fallback cancellation logic if used
	local topNode = t_abilities_queued[gsiPlayer.nOnTeam]
	if topNode then
		topNode[QUEUED_ABILITY_I__EXPIRY] = GameTime() + 1
	end
end

local function estimated_time_til_completed(gsiPlayer, objective)
	return 0.3 -- don't care
end
local next_player = 1
local function task_init_func(taskJobDomain)
	if VERBOSE then VEBUG_print(string.format("use_ability: Initialized with handle #%d.", task_handle)) end

	Task_RegisterTask(task_handle, PLAYERS_ALL, blueprint.run, blueprint.score, blueprint.init)

	taskJobDomain:RegisterJob(
			function(workingSet)
				if workingSet.throttle:allowed() then
					Task_SetTaskPriority(task_handle, next_player, TASK_PRIORITY_TOP)
					next_player = Task_RotatePlayerOnTeam(next_player)
				end
			end,
			{["throttle"] = Time_CreateThrottle(PRIORITY_UPDATE_USE_ABILITY_THROTTLE)},
			"JOB_TASK_SCORING_PRIORITY_USE_ABILITY"
		)
	Blueprint_RegisterTaskActivityType(task_handle, ACTIVITY_TYPE["NOT_APPLICABLE"])
	task_init_func = nil
	return task_handle, estimated_time_til_completed
end
Blueprint_RegisterTask(task_init_func)

blueprint = {
	run = function(gsiPlayer, objective, xetaScore)
		local thisAbilityOrFuncNode = t_abilities_queued[gsiPlayer.nOnTeam]
		if not thisAbilityOrFuncNode then --[[print("expectedNode,", tostring(objective))--]] return XETA_SCORE_DO_NOT_RUN end
		
		local abilityOrFunc = thisAbilityOrFuncNode[QUEUED_ABILITY_I__ABILITY_OR_FUNC]
		local target = thisAbilityOrFuncNode[QUEUED_ABILITY_I__TARGET]
		local expired = thisAbilityOrFuncNode[QUEUED_ABILITY_I__EXPIRY] < GameTime()

		if VERBOSE then print(type(abilityOrFunc) == "table" and abilityOrFunc:GetName(), target, target and target.x, target and target.lastSeen, target and target.center) end
		
		if VERBSOSE then VEBUG_print(string.format("[use_ability]: '%s' abilityOrFunc type = %s.", gsiPlayer.shortName, type(abilityOrFunc))) end
		local isAbility = type(abilityOrFunc) == "table" and true or false
		
		local currentlyCasting = gsiPlayer.hUnit:GetCurrentActiveAbility()
		
		--[[DEBUG]]if DEBUG  and not currentlyCasting then print("use_ability: [run]", not isAbility and "<func>" or abilityOrFunc:GetName(), target, isAbility and (ChargedCooldown_IsChargedCooldown(gsiPlayer, abilityOrFunc) and ChargedCooldown_GetCurrentCharges(gsiPlayer, abilityOrFunc) or "n/a")) end
		-- Check expiry
		::CHECK_EXPIRED:: -- relies: registered func success -> clean up
		if expired
				or isAbility
					and (
							( not AbilityLogic_AbilityCanBeCast(gsiPlayer, abilityOrFunc)
							and not (currentlyCasting and currentlyCasting:GetName() == abilityOrFunc:GetName())
							) 
						or SPELL_SUCCESS(gsiPlayer, target, abilityOrFunc) == 0
						) then
			if DEBUG then
				INFO_print(
					string.format("%s killed use_ability '%s' because %s || ( !(%s and %s) && !%s ) || !%s",
							gsiPlayer.shortName,
							isAbility and abilityOrFunc:GetName() or "<func>",
							expired,
							isAbility and abilityOrFunc:IsFullyCastable() or "##",
							isAbility and abilityOrFunc:GetCooldownTimeRemaining() == 0 or "##",
							currentlyCasting and currentlyCasting:GetName() == isAbility
									and abilityOrFunc:GetName() or "",
							isAbility and SPELL_SUCCESS(gsiPlayer, target, abilityOrFunc) or "##"
						)
					)
			end
			if expired and thisAbilityOrFuncNode[QUEUED_ABILITY_I__COMBO_IDENTIFIER] then
				UseAbility_ClearQueuedComboAbilities(
						gsiPlayer,
						thisAbilityOrFuncNode[QUEUED_ABILITY_I__COMBO_IDENTIFIER]
					)
			else
				take_and_sew_queue_node(gsiPlayer.nOnTeam, thisAbilityOrFuncNode)
			end
			return select(2, (blueprint.score(gsiPlayer, objective, xetaScore)))
		end
		-- Run()
		if not isAbility then
			-- CustomRun()
			local runResult, newScore = abilityOrFunc(gsiPlayer, target)
			if runResult then
				if runResult == true then
					expired = true
					goto CHECK_EXPIRED;
				else
					UseAbility_PopComboQueue(
							gsiPlayer,
							thisAbilityOrFuncNode[QUEUED_ABILITY_I__COMBO_IDENTIFIER]
						)
				end
			elseif newScore then
				thisAbilityOrFuncNode[QUEUED_ABILITY_I__SCORE] = newScore
				return newScore
			end
		elseif target then
			-- Action_Use...()
			if target.hUnit then
				if not Unit_IsNullOrDead(target) then
					thisAbilityOrFuncNode[QUEUED_ABILITY_I__ACTION_FUNC](
							gsiPlayer.hUnit, abilityOrFunc, target.hUnit
						)
				else
					return XETA_SCORE_DO_NOT_RUN
				end
			else
				thisAbilityOrFuncNode[QUEUED_ABILITY_I__ACTION_FUNC](gsiPlayer.hUnit, abilityOrFunc, target)
			end
		elseif thisAbilityOrFuncNode[QUEUED_ABILITY_I__ACTION_FUNC] == gsiPlayer.hUnit.Action_UseAbility then
			thisAbilityOrFuncNode[QUEUED_ABILITY_I__ACTION_FUNC](gsiPlayer.hUnit, abilityOrFunc)
		else
			thisAbilityOrFuncNode[QUEUED_ABILITY_I__ACTION_FUNC](gsiPlayer.hUnit, abilityOrFunc, target)
		end
		return xetaScore
	end,
	
	score = function(gsiPlayer, prevObjective, prevScore)
		local thisPlayerQueuedAbilities = t_abilities_queued[gsiPlayer.nOnTeam]
		if thisPlayerQueuedAbilities then
			return gsiPlayer, t_abilities_queued[gsiPlayer.nOnTeam][QUEUED_ABILITY_I__SCORE]
		else
			return false, XETA_SCORE_DO_NOT_RUN
		end
	end,
	
	init = function(gsiPlayer, objective, extrapolatedXeta)
		return extrapolatedXeta
	end
}

function UseAbility_GetTaskHandle()
	return task_handle
end
