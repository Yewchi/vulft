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

-- We do need hAbility:GetCurrentCharges() to return the ability 
--- charges, not -1 (as with void spirit astral step).

-- local CHARGE_CD_I__CHARGES = 1
-- local CHARGE_CD_I__RESTORE_TIME = 2
-- local CHARGE_CD_I__GET_RESTORE_TIME = 3
-- local CHARGE_CD_I__GET_CHARGE_LIMIT = 4

local t_charges
do
	t_charges = {}
	for pnot=1, TEAM_NUMBER_OF_PLAYERS do
		t_charges[pnot] = {}
	end
end

local function update_charges(gsiPlayer, hAbility)
	local thisChargeCd = t_charges[gsiPlayer.nOnTeam][hAbility:GetName()]
	--if not thisChargeCd then Util_TablePrint(t_charges) Util_TablePrint(gsiPlayer.hUnit:GetAbilityByName("void_spirit_astral_step")) end
	local maxCharges = thisChargeCd[3](gsiPlayer, hAbility)
	if thisChargeCd[1] < maxCharges
			and thisChargeCd[2] and GameTime() > thisChargeCd[2] then
		--print("update_charges will increment", hAbility:GetName(), thisChargeCd[1], "next increment would be", GameTime() + thisChargeCd[4](gsiPlayer, hAbility))
		--DebugDrawText(1000, 700, string.format("%s %s +1", gsiPlayer.shortName, hAbility:GetName()), 80, 80, 255)
		thisChargeCd[1] = thisChargeCd[1] + 1
		thisChargeCd[2] = thisChargeCd[1] == maxCharges and false or GameTime() + thisChargeCd[4](gsiPlayer, hAbility)
		-- UseAbility_IncrementPreviousCharges(gsiPlayer, hAbility) -- usually bounce back
	end
end

function ChargedCooldown_ExistsDecrementCharges(gsiPlayer, hAbility)
	--print("CHARGES: Decrement", hAbility:GetName(), gsiPlayer.nOnTeam, t_charges[gsiPlayer.nOnTeam])
	local thisChargeCd = t_charges[gsiPlayer.nOnTeam][hAbility:GetName()]
	if thisChargeCd == nil then return end
	--print("CHARGES: Decrement", math.max(0, thisChargeCd[1] - 1))
	--DebugDrawText(1000, 700, string.format("%s %s -1", gsiPlayer.shortName, hAbility:GetName()), 80, 80, 255)
	thisChargeCd[1] = math.max(0, thisChargeCd[1] - 1)
	thisChargeCd[2] = thisChargeCd[2] and thisChargeCd[2] or GameTime() + thisChargeCd[4](gsiPlayer, hAbility) -- if this is a drop from max charges, we set the next restore time, else use the prev time.
end

function ChargedCooldown_GetCooldownTimeRemaining(gsiPlayer, hAbility)
	update_charges(gsiPlayer, hAbility) -- << The only reason this func exists; soft update throttle.
	return hAbility:GetCooldownTimeRemaining()
end

function ChargedCooldown_GetTimeUntilCharge(gsiPlayer, hAbility)
	update_charges(gsiPlayer, hAbility)
	local thisChargeCd = t_charges[gsiPlayer.nOnTeam][hAbility:GetName()]
	return thisChargeCd and thisChargeCd[1] and thisChargeCd[1] < thisChargeCd[3](gsiPlayer, hAbility) and thisChargeCd[2] and thisChargeCd[2] - GameTime() or 0
end

function ChargedCooldown_AbilityCanBeCast(gsiPlayer, hAbility)
	update_charges(gsiPlayer, hAbility) -- << The only reason this func exists; soft update throttle.
	return hAbility:IsFullyCastable() and hAbility:GetCooldownTimeRemaining() == 0
end

function ChargedCooldown_GetCurrentCharges(gsiPlayer, hAbility) -- << the reason this module exists
	update_charges(gsiPlayer, hAbility)
	return t_charges[gsiPlayer.nOnTeam][hAbility:GetName()][1]
end

function ChargedCooldown_IsChargedCooldown(gsiPlayer, hAbility)
	return t_charges[gsiPlayer.nOnTeam][hAbility:GetName()] and true or false
end

function ChargedCooldown_CheckChargesSetMax(gsiPlayer, hAbility) -- used on level-up
	local thisChargesCd = t_charges[gsiPlayer.nOnTeam][hAbility:GetName()]
	if thisChargesCd then
		thisChargesCd[1] = thisChargesCd[3](gsiPlayer, hAbility)
	end
end

function ChargedCooldown_RegisterCooldown(gsiPlayer, hAbility, getChargeLimit, getRestoreTime)
	local offCd = hAbility:GetCooldownTimeRemaining() == 0
	t_charges[gsiPlayer.nOnTeam][hAbility:GetName()] = {
			offCd and 1 or 0, -- i.e. if it's off cd, we may only assume it has at least 1 charge
			offCd and GameTime() + getRestoreTime(gsiPlayer), 
			getChargeLimit,
			getRestoreTime
	}
	--print("Init Charge Cooldown", hAbility:GetCooldownTimeRemaining(), Util_PrintableTable(t_charges[gsiPlayer.nOnTeam][hAbility:GetName()]))
end
