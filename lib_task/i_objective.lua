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
	dUnit.expires = expires
	dUnit.lastSeen = {["location"] = loc}
	dUnit.radius = radius
	dUnit.lastSeenHealth = 1.0
	dUnit.IsNullOrDead = return_false
	dUnit.maxHealth = 1.0
	dUnit.Key = Unit_Key
	dUnit.type = UNIT_TYPE_IMAGINARY -- TODO refactor to .isImaginary, may need to know a type of obj
	
	return dUnit
end
