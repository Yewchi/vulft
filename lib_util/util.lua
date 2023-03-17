require(GetScriptDirectory().."/lib_util/string")

CPP_TO_LUA_ARRAY_OFFSET = 1
HIGH_32_BIT = 0x80000000
LOW_32_BIT = -0x80000000
EMPTY_TABLE = {}

DEBUG = false
VERBOSE = true and DEBUG
TEST = true and DEBUG

RELEASE_STAGE = "Alpha"
VERSION = "v0.5-230311"

VULFT_VERSION = RELEASE_STAGE
		--[[DEV]].."-Dev"
		..(DEBUG and "-Debug" or "")..(TEST and "-Test" or "").." "..VERSION

VULFT_STR = "/VUL-FT/"
ALERT_STR = "[!]"
INFO_STR = "[#]"

DRAW_EMOTES = false

require(GetScriptDirectory().."/lib_util/time")

Time_startTimeOfDarkSim = GameTime()

local INFO_PRE = VULFT_STR.." "..INFO_STR.." "
function INFO_print(str)
	print(INFO_PRE..str)
end

local ERROR_PRE = VULFT_STR.." "..ALERT_STR.." <ERROR> "
function ERROR_print(str, printTraceback)
	print(ERROR_PRE..str)
	if printTraceback then
		print(debug.traceback())
	end
end

local ALERT_PRE = VULFT_STR.." "..ALERT_STR.." "
function ALERT_print(str)
	print(ALERT_PRE..str)
end
WARN_print = ALERT_print

function DOMINATE_SetDominateFunc(gsiPlayer, funcName, dominateFunc, dominated)
	ALERT_print(string.format("%s Dominated: %s %s %s.",
			dominated and ALERT_STR or INFO_STR,
			gsiPlayer.shortName,
			funcName or "?()",
			dominated and "on." or "off." )
		)
	gsiPlayer.disabledAndDominatedFunc = dominated and dominateFunc or nil
	gsiPlayer.disabledAndDominatedFuncName = dominated and funcName or nil
end

function DOMINATE_print(gsiPlayer, str)
	ALERT_print(string.format("%s(%s) \"%s\"", gsiPlayer.disabledAndDominatedFuncName, gsiPlayer.shortName, str))
end

function Util_TableRemoveUnordered(tbl, i)
	tbl[i] = tbl[#tbl]
	tbl[#tbl] = nil
end

function Util_ThrowError()
	local throw
	throw=throw+0
end

local function draw_from_table(t1, t2)
	local t2NextSize = #t2
	for i=#t1,1,-1 do
		t2NextSize = t2NextSize+1
		t2[t2NextSize] = t1[i]
		t1[i] = nil
	end
end
function Util_ShiftElementsToLowerTblsOfTbl(tbl, startIndex, endIndex)
	startIndex = startIndex or 1
	endIndex = endIndex or #tbl
	if TEST then print("shift elements", startIndex, endIndex) end
	if endIndex - startIndex < 2 then return false end
	draw_from_table(tbl[startIndex+1], tbl[startIndex]) -- (t1[] -->> t2[])
	for i=startIndex+1,endIndex-1 do
		tbl[i] = tbl[i+1]
	end
	tbl[endIndex] = nil
end

function Util_Printable(val)
	local t = type(val)
	if val == nil then return "nil"
	elseif t == "number" then return val
	elseif t == "string" then return string.format('"%s"', val)
	elseif t == "boolean" then return (val and "true" or "false")
	elseif t == "table" then
		return tostring(val)..(type(val.shortName) == "string"
				and ": '"..val.shortName.."'" or ""
			)
	elseif t == "function" then return "[func]"
	elseif t == "userdata" then return "[ud]"
	elseif t == "thread" then return "[thread]"
	end
	return "[WHAT THE F***]"
end

local table_print_time_limit = 0
local exiting_time_limit = false
function printable_table(tbl, depthAllowed)
	if depthAllowed == nil then depthAllowed = 7 
	elseif depthAllowed <= 0 then 
		return Util_Printable(tbl)..", "
	elseif exiting_time_limit then return "&"
	elseif RealTime() > table_print_time_limit then
		exiting_time_limit = true
		return "&!!!!!!WOOOO DATA!&&&&&"
	end
	if type(tbl) ~= "table" then
		return Util_Printable(tbl)..",\n"
	end
	
	local str = "{\n"
	local theseTabs = ""
	for i=depthAllowed,7,1 do
		theseTabs = theseTabs.."\t"
	end
	if depthAllowed == 1 then str = str..theseTabs end -- once this \n for inline final array or key pair
	for k,v in pairs(tbl) do
		if depthAllowed > 1 then str = str..theseTabs end -- each \n
		str = str.."["..Util_Printable(k).."]="..Util_PrintableTable(v, depthAllowed - 1)
	end
	if depthAllowed ~= 1 then str = str..theseTabs end -- once for everything but final depth inline close block
	return str.."}\n"
end

function Util_PrintableTable(tbl, depthAllowed)
	table_print_time_limit = RealTime() + 0.0001
	exiting_time_limit = false
	return printable_table(tbl, depthAllowed)
end

function Util_TablePrint(tbl, depth)
	local newLineSplit = Util_PrintableTable(tbl, depth)
	newLineSplit = newLineSplit:gmatch("[^\n]+")
	
	for sub in newLineSplit do
		print(sub)
	end
end

function Util_TableEmpty(tbl)
	if tbl == nil then return true end
	for _,_ in pairs(tbl) do
		return false
	end
	return true
end

function Util_TableCopyArray(t1, t2) -- t1 <- t2. Elements in t1 greater than the #(t2)+2'th index remain in t2
	for i=1,#t2,1 do
		t1[i] = t2[i]
	end
end

function Util_ParamString(...)
	local args = {...}
	local paramString = "("
	for i=1,#args,1 do
		paramString = paramString..Util_Printable(args[i])
		if i < #args then
			paramString = paramString..", "
		end
	end
	return paramString..")"
end

function Util_PrintModifiers(gsiUnit)
	if not gsiUnit.hUnit then
		ALERT_print("[util]: Attempted to print an invalid safe unit.")
		return;
	end
	local mod_count = gsiUnit.hUnit:NumModifiers()
	INFO_print(
			string.format( "[util]: '%s' %d modifiers%s",
				Util_Printable(gsiUnit.shortName),
				mod_count,
				mod_count > 0 and ": {" or "."
			)
		);
	if mod_count > 0 then
		for i=0,mod_count-1 do
			print(
					string.format( "\t%d: %s",
						i,
						gsiUnit.hUnit:GetModifierName(i)
					)
				);
		end
		print("}")
	end
end

function Util_CauseError(msg)
	ALERT_print(string.format("Throwing 0nil error: \"%s\"", msg or "[no msg]"))
	local throws=0+nil
end

if DEBUG
--[[DEV]] or true
		then
	require(GetScriptDirectory().."/lib_util/debug")
end

-- EPILESPY AND SEIZURE WARNING -- Setting to true may inlude very fast flashing for low-throttle updates. This is intended to be informational to the programmer, please take care as this is not intended to be a subscriber experience and I make no guarentees for your health or safety when using debug = true.
USER_HAS_NO_EPILEPSY_RISK_DEBUG_THROTTLES = false
