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

-- Imaginary objectives -- there's some good stuff over here soon.

VERY_UNTHREATENING_UNIT = {team=TEAM, lastSeen={location=Vector(12000, 12000, 12000)}, lastSeenHealth = 1000, maxHealth = 1000, attackRange = 1, type = UNIT_TYPE_IMAGINARY}

local function return_false() return false end
local function return_true() return true end

function iObjective_NewImaginarySafeUnit(loc, radius, expires, name)
	local dUnit = {}
	
	dUnit.hUnit = {GetLocation = function(self) return self.lastSeen.location end}
	
	dUnit.IsNull = return_false
	dUnit.IsAlive = return_true
	dUnit.name = name or "dummy"
	dUnit.shortName = name
	dUnit.expires = expires
	dUnit.lastSeen = {["location"] = loc}
	dUnit.radius = radius
	dUnit.lastSeenHealth = 1.0
	dUnit.IsNullOrDead = return_false
	dUnit.maxHealth = 1.0
	dUnit.Key = Unit_Key
	dUnit.type = UNIT_TYPE_IMAGINARY -- TODO refactor to .isImaginary, may need to know a type of obj
	dUnit.isImaginary = true
	
	return dUnit
end
