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


local min = math.min
local max = math.max
local sqrt = math.sqrt
local floor = math.floor

local TEAM_NUMBER_OF_PLAYERS = TEAM_NUMBER_OF_PLAYERS
local team_players

local t_player_ability_movemods = {} -- Abilities that increase allied covered ground over time.
local t_player_ability_slowmods = {} -- Abilities that decrease enemy covered ground when neck and neck over time.
local t_player_last_update = {}
local t_saved_catch_data = {}
local t_saved_catch_data_expires = {}

local MOD_I__ABILITY = 1
local MOD_I__10_MIN_ADDITIONAL_STATIC_VALUE = 2 -- how much the ability used on cooldown effects avg
		-- -| mvspd over 10 minutes, optional as a simplistic replacement for a func
local MOD_I__FUNC = 3 -- a function which takes the player and ability as argument, opt
-- - One or the other of the above optionals are required. Lua.

local function update_theoretical_movespeeds()

end

function CatchRelease_RegisterModifierAbilities(gsiPlayer, moveModsTbl, slowModTbl)
	local validData = true
	if type(gsiPlayer) ~= "table" then
		validData = false
	end
	if validData then
		if moveModTbl then
			for i=1,#moveModTbl do
				if type(moveModTbl[2]) ~= "number" and type(moveModTbl[3]) ~= "function" then
					validData = false
				end
			end
		end
		if validData and slowModTbl then
			for i=1,#slowModsTbl do
				if type(moveModTbl[2]) ~= "number" and type(moveModTbl[3]) ~= "function" then
					validData = false
				end
			end
		end
	end
	if not validData then
		INFO_print(string.format("[catch_release] Invalid data for RegMMA(%s, %s, %s). Printing traceback:\n%s",
						Util_Printable(gsiPlayer), Util_Printable(moveModsTbl),
						Util_Printable(slowModTbl), debug.traceback()
					)
			)
		return false;
	end
	t_player_ability_movemods[gsiPlayer.nOnTeam] = moveModsTbl
	t_player_ability_slowmods[gsiPlayer.nOnTeam] = slowModsTbl
	return true;
end

function update_group_theoretical_movespeed(groupOfAllies)
	if t_player_next_update[pnot] > currTime then
		t_player_next_update[pnot] = currTime + 0.661
		-- Update this player's theoretical movespeed.
		-- Lua. (readability)
		local gsiPlayer = teamPlayers[i]
		local hUnit = gsiPlayer.hUnit
		local currentMovespeed = gsiPlayer.currentMovementSpeed
		local additionalMovespeed = 0
		local itemCache = gsiPlayer.usableItemCache
		if itemCache.blink then
			-- Lua. (extensibility)
			additionalMovespeed = additionalMovespeed
			-- 7.30e arith':
					+ 80 * max(0.25, (15-itemCache.blink:GetCooldownTimeRemaining())/15)
		end
		if itemCache.phaseBoots and not hUnit:HasModifier("modifier_item_phase_boots_active") then
			additionalMovespeed = additionalMovespeed
					+ currentMovespeed
						* (gsiPlayer.isRanged and 0.3 or 0.6)
						-- Lua. (extensibility)
						* max(0.25, (8-itemCache.phaseBoots:GetCooldownTimeRemaining())/8)
		end
		local movemods = playerAbilityMovemods[i]
		if movemods then
			for k=1,#movemods do
				local thisMovemod = movemods[k]
				if thisMovemod[2] then
					local thisAbility = thisMovemod[1]
					local cd = thisAbility:GetCooldown()
					local cdtr = thisAbility:GetCooldownTimeRemaining()
					additionalMovespeed = additionalMovespeed
							+ thisMovemod[2]
								* max(0.25, ((cd-cdtr)/cd))
				else
					additionalMovespeed = additionalMovespeed
							+ thisMovemod[3](gsiPlayer, thisMovemod[1])
								* max(0.25, ((cd-cdtr)/cd))
				end
				totalMovespeed = totalMovespeed
			end
		end
	end
end

local reuse_allies_group_tbl = {}
function CatchRelease_CanWeCatch(gsiPlayer, targetUnit, groupOfAllies)
	local currTime = GameTime()
	local pnot = gsiPlayer.nOnTeam

	groupOfAllies = groupOfAllies or Set_GetAlliedHeroesInLocRad(
			gsiPlayer, targetUnit.lastSeen.location, 1600, -- Lua. (extensibility)
			true
		)
	
	local key = 0
	for i=1,#groupOfAllies do
		-- nb. MAX PLAYERS
		key = key + 2^(groupOfAllies[i].nOnTeam+7) + targetUnit.nOnTeam -- Lua. (extens.) Limits max players to 63.
	end
	local expires = t_saved_catch_data_expires[key]
	if t_saved_catch_data[key] and (not expires or expires < currTime) then
		-- Update whether catching is possible, and in how long
		
	end
end

function Analytics_RegisterGetKnownTheorizedEngageablesToPowerLevel(jobDomain)
	for i=1,TEAM_NUMBER_OF_PLAYERS do
		t_player_next_update[i] = 0
		t_saved_catch_data_expires[i] = 0
	end
	Analytics_RegisterGetKnownTheorizedEngageablesToPowerLevel = nil
end
