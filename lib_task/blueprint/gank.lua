local avoid_hide_handle
local avoid_hide_run
local fight_harass_handle
local fight_harass_run
local push_handle
local GET_TASK_OBJ = Task_GetTaskObjective
local GET_TASK_SCORE = Task_GetTaskScore
local MINIMUM_ALLOWED_USE_TP_INSTEAD = MINIMUM_ALLOWED_USE_TP_INSTEAD
local TPSCROLL_CD = ITEM_COOLDOWN["item_tpscroll"]
local max = math.max
local min = math.min

function Gank_RegisterEnemyCluster(enemiesTbl, safetyOfLane)
	-- TODO temp, simplistic
	if #enemiesTbl == 1 and safetyOfLane > 0.5
end
