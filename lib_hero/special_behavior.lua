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

local t_behavior = {}

-- Hand an as-generic-as-possible func to run in designated parts of the code.
-- -| Should be rubick functional, e.g. Rubick will stand correctly during
-- -| fight_harass Blade Fury
-- Designations are not tracked anywhere, grep -rne ialB.*Reg
-------- SpecialBehavior_RegisterBehavior()
function SpecialBehavior_RegisterBehavior(name, func)
	if not t_behavior[name] then
		t_behavior[name] = {}
	end
	table.insert(t_behavior[name], func)
end

function SpecialBehavior_ReplaceBehavior(name, oldFunc, func)
	local behs = t_behavior[name]
	for i=1,#behs do
		if behs[i] == oldFunc then
			table.remove(behs, i)
		end
	end
	if func then
		table.insert(behs, func)
	end
end

function SpecialBehavior_GetBooleanOr(name, default, ...)
	local behs = t_behavior[name]
	if not behs then return default; end
	for i=1,#behs do
		if behs[i](...) then
			return true
		end
	end
	return false;
end

function SpecialBehavior_GetBooleanAnd(name, default, ...)
	local behs = t_behavior[name]
	if not behs then return default; end
	for i=1,#behs do
		if not behs[i](...) then
			return false
		end
	end
	return true;
end
