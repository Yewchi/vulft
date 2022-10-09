-- All broadly-used types pertaining to tasks (and some functions to iterate and run each functions-of-types)

TASK_DISALLOW_OBJECTIVE_FUNCS = {}
TASK_DISALLOW_ANY_OBJECTIVE_FUNCS = {}

DENIAL_TYPE_FARM_LANE_CREEP =		0x0000
DENIAL_TYPE_FARM_LANE_CREEP_SET =	0x0001
DENIAL_TYPE_FARM_JUNGLE_SET =		0x0100


function TaskType_CancelAnyConfirmedDenialsSelf(gsiPlayer)
	for _,func in pairs(TASK_DISALLOW_ANY_OBJECTIVE_FUNCS) do
		func(gsiPlayer)
	end
end


function TaskType_Initialize()
	TASK_DISALLOW_OBJECTIVE_FUNCS[DENIAL_TYPE_FARM_LANE_CREEP] = 		Farm_CancelConfirmedDenial
	TASK_DISALLOW_OBJECTIVE_FUNCS[DENIAL_TYPE_FARM_LANE_CREEP_SET] = 	Farm_CancelConfirmedDenial
	TASK_DISALLOW_OBJECTIVE_FUNCS[DENIAL_TYPE_FARM_JUNGLE_SET] = 		Farm_CancelConfirmedDenialJungle

	TASK_DISALLOW_ANY_OBJECTIVE_FUNCS[DENIAL_TYPE_FARM_LANE_CREEP] = 		Farm_CancelAnyConfirmedDenials
	TASK_DISALLOW_ANY_OBJECTIVE_FUNCS[DENIAL_TYPE_FARM_LANE_CREEP_SET] = 	Farm_CancelAnyConfirmedDenials
	TASK_DISALLOW_ANY_OBJECTIVE_FUNCS[DENIAL_TYPE_FARM_JUNGLE_SET] = 		Farm_CancelAnyConfirmedDenialsJungle
end