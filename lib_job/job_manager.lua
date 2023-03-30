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

-- Manages jobs via register, deregister, and run on commmand. E.g. team captain analytics
-- - and data-updates. Jobs return true if they are to be discarded.

local JOB_I__FUNCTION = 	1
local JOB_I__WORKING_SET = 2

local job_registry = {}

local ASCII_CAPS_START = 65
local ASCII_CAPS_END = 90

local t_unique_name_str = {}

local function update_job_activity(this)
	if Util_TableEmpty(job_registry[this.key]) then
		this.active = false
	end
end

local last_warn_print = 0
local function job_exists(registryEntry, jobKey)
	if registryEntry[jobKey] ~= nil then
		return true
	end
	if GameTime() - last_warn_print > 20.0 or last_warn_print == GameTime() then
		print("/VUL-FT/ [job_manager]: <WARN> job", jobKey, "not found.")
		last_warn_print = GameTime()
	end
end

-- Do all named and numerical indexed jobs for the domain given
function Job_DoAllJobs(this)
	local thisDomainJobs = job_registry[this.key]
	for k,tbl in pairs(thisDomainJobs) do
		local func, workingSet = unpack(tbl)
		if func(workingSet) then
--[[VERBOS]]if VERBOSE then VEBUG_print("[job_manager]: removing job_registry["..this.key.."]["..k.."].") end
			thisDomainJobs[k] = nil
			update_job_activity(this)
		end
	end
end

function Job_DoJob(this, jobKey)
	local thisDomainJobs = job_registry[this.key]
	if not job_exists(thisDomainJobs, jobKey) then return end
	local func, workingSet = unpack(thisDomainJobs[jobKey])
	if func and func(workingSet) then
--[[VERBOS]]if VERBOSE then VEBUG_print("[job_manager]: removing job_registry["..this.key.."]["..jobKey.."].") end
		thisDomainJobs[jobKey] = nil
		update_job_activity(this)
	end
end

-- Do the job at job_registry[this.key][1] -- Dequeue it if it returned true
function Job_DoQueuedJob(this)
	local thisDomainJobs = job_registry[this.key]
	local func, workingSet = unpack(thisDomainJobs[1])
	if func and func(workingSet) then
--[[VERBOS]]if VERBOSE then VEBUG_print("[job_manager]: removing job_registry["..this.key.."][1].") end
		thisDomainJobs[1] = nil
		for i=2,#thisDomainJobs,1 do -- e.g. #{["a"] = 321, [1] = 1, nil, 3, nil, nil, 6} == 3. (Lua #array algorithm will skip 1 nil at a time). So we still get the final numerical key to thisDomainJobs despite making index @ 1 = nil.
			thisDomainJobs[i-1] = thisDomainJobs[i]
			thisDomainJobs[i] = nil
		end
	end
	update_job_activity(this)
end

function Job_CreateUniqueName(desiredName)
	local thisName = t_unique_name_str[desiredName]
			and desiredName..RealTime()
			or desiredName
	while(t_unique_name_str[thisName]) do
		thisName = thisName..string.char(RandomInt(ASCII_CAPS_START, ASCII_CAPS_END))
	end
	t_unique_name_str[thisName] = true
	return thisName
end

function Job_CreateDomain(domainName)
	if type(domainName) == "string" then
--[[DEBUG]]if DEBUG and job_registry[domainName] then DEBUG_print("<WARN> [job_manager]: Overwriting a job domain handle for "..domainName) end
		local new = {}
		new.key = domainName
--[[VERBOSE]]if DEBUG then DEBUG_print("[job_manager]: CreateDomain"..Util_ParamString(domainName)) end
		new.DoAllJobs = Job_DoAllJobs
		new.DoJob = Job_DoJob
		new.DoQueuedJob = Job_DoQueuedJob
		new.RegisterJob = Job_RegisterJob
		new.DeregisterJob = Job_DeregisterJob
		new.IsJobRegistered = Job_IsJobRegistered
		new.ListJobKeys = Job_ListJobKeys
		new.DeleteDomain = Job_DeleteDomain
		new.active = false
		
		job_registry[domainName] = {}
		
		return new
	end
end

function Job_DeleteDomain(this)
	local thisJobDomain = job_registry[this.key]
	if thisJobDomain then
--[[VERBOSE]]if VERBOSE then VEBUG_print("[job_manager]: DeleteDomain"..Util_ParamString(this.key)) end
		for k,t in pairs(thisJobDomain) do
			t = nil
		end
		job_registry[this.key] = nil
		this.IsJobRegistered = false
		this.deleted = true -- helpful for job domains that are known to be temporary if they are deleted outside of their owning module
		this = nil
	end
end

-------- Job_RegisterJob(jobDomain, func[, workingSet][, jobName])
function Job_RegisterJob(this, ...)
	local thisJobDomain = job_registry[this.key]
	if thisJobDomain then
		local func, workingSet, jobName = ...
--[[VERBOS]]if VERBOSE then VEBUG_print("[job_manager]: Job_RegisterJob"..Util_ParamString(this.key, func, workingSet or 'nil', jobName)) end
		if type(func) == "function" then
			if type(jobName) == "string" then
--[[VERBOSE]]if VERBOSE and thisJobDomain[jobName] then VEBUG_print("[job_manager]: Overwriting job with given name '"..(name or 'nil').."' for domain '"..(domainName or 'nil').."'. Job_RegisterJob"..Util_ParamString(this, func, jobName)) end
				thisJobDomain[jobName] = {func, workingSet}
			else
				table.insert(thisJobDomain, {func, workingSet})
			end
			this.active = true
		else
			print("/VUL-FT/ <WARN> Incorrect parameters. Expected Job_RegisterJob(this, func[, jobName]). Got "..Util_ParamString(this, func, jobName))
		end
	else
		print("/VUL-FT/ <WARN> Attempted registering job on a domain that does not exist. Job_RegisterJob"..Util_ParamString(this, func, jobName))
		return false
	end
end

function Job_DeregisterJob(this, jobKey)
	local thisJobDomain = job_registry[this.key]
	if thisJobDomain then
--[[VERBOS]]if VERBOSE then VEBUG_print("[job_manager]: Job_DeregisterJob"..Util_ParamString(this.key, jobKey)) end
		thisJobDomain[jobKey] = nil
		update_job_activity(this)
	else
		print("/VUL-FT/ <WARN> Job deregister attempted on job domain '"..(this.key or 'nil').."' does not exist: Job_DeregisterJob"..Util_ParamString(this, jobKey))
		return false
	end
end

function Job_IsJobRegistered(this, jobKey)
	local thisJobDomain = job_registry[this.key]
	if thisJobDomain and thisJobDomain[jobKey] then
		return true
	end
	return false
end

function Job_ListJobKeys(this)
	local thisJobDomain = job_registry[this.key]
	INFO_print(string.format("Jobs for '%s'...", this.key))
	for k,_ in pairs(thisJobDomain) do
		INFO_print(string.format('\t%s', k))
	end
end

function Job_UnpackableRegisterJobParameters(this, func, workingSet, jobName)
	return {func, workingSet, jobName}
end
