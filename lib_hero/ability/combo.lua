

local ud_string = "userdata" -- could be always indexed, don't know. Might as well avoid the garbage frame otherwise

local COMBO_I__COMBO_IDENTIFIER = 1
local COMBO_I__INSTRUCTIONS = 2
local COMBO_I__QUEUE_INDEX = 3

local t_combo = {}

local t_queued_combo = {} -- Expected size, most often only 1, 2, almost impossible for over 3 elements. 

local function remove_queued_combo(queue, combo)
	local prevQueueIndex = combo[COMBO_I__QUEUE_INDEX]
	local currQueueIndex = prevQueueIndex + 1
	combo[COMBO_I__QUEUE_INDEX] = combo[COMBO_I__QUEUE_INDEX] + HIGH_32_BIT -- sets combo to not-in-queue
	
	while(currQueueIndex<=#t_queued_combo) do -- this will usually 1 <= 2 --> EXIT_SUCCESS
		t_queued_combo[prevQueueIndex] = t_queued_combo[currQueueIndex] -- cascade
		t_queued_combo[prevQueueIndex][COMBO_I__QUEUED_INDEX] = t_queued_combo[prevQueueIndex][COMBO_I__QUEUED_INDEX] - 1
	end
end

function Combo_InformClearingCombo(gsiPlayer, comboIndex)
	local thisCombo = t_combo[gsiPlayer.nOnTeam][comboIndex]
	
	if thisCombo then
		remove_queued_combo(t_queued_combo[gsiPlayer.nOnTeam], thisCombo)
	end
end

function Combo_QueueComboAndLockToScore(gsiPlayer, comboIndex)

end

function Combo_RegisterComboList()
end