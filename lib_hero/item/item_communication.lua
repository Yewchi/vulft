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

local STR__GIVE_ME_YOUR_BOTTLE = "%s, give me your bottle to refill"
RegisterLocalize(STR__GIVE_ME_YOUR_BOTTLE,
		"zh", "%s, 把你的魔瓶子给我，让我重新装满它",
		"ru", "%s, дай мне свою Bottle, чтобы наполнить ее."
	)
local STR__GIVE_BOTTLE_BACK = "give me back my bottle, please"
local STR__GIVE_BOTTLE_ANGRY = "bottle %s!"
local STR__GIVE_BOTTLE_FAR_AWAY = ":| you stole it"
RegisterLocalize(STR__GIVE_BOTTLE_BACK,
		"zh", "请把我的魔瓶还给我",
		"ru", "Верните мне мою Bottle, пожалуйста"
	)
RegisterLocalize(STR__GIVE_BOTTLE_ANGRY,
		"zh", "哎呀！ 魔瓶, %s",
		"ru", "Эй %s! Что за...."
	)
RegisterLocalize(STR__GIVE_BOTTLE_FAR_AWAY,
		"zh", "你偷了它 :|",
		"ru", "чувак, почему :|"
	)

local t_rapiers = {}
local t_gems = {}
local t_jungle = {}

ITEM_MSG_I__FROM_PLAYER = 1
ITEM_MSG_I__TO_PLAYER = 2
ITEM_MSG_I__ABOUT_PLAYER = 3
ITEM_MSG_I__ABOUT_OBJECTIVE = 4
ITEM_MSG_I__ABOUT_ITEM_NAME = 5
ITEM_MSG_I__MSG_TYPE = 6
ITEM_MSG_I__ALLOW_PORTS = 7
ITEM_MSG_I__EXPIRES = 8
ITEM_MSG_I__COMPLY_FUNCTION = 9
ITEM_MSG_I__SCORE_FUNCTION = 10
ITEM_MSG_I__DATA = 11

local t_player_outbox = {}
local t_player_inbox = {}

ICOMMS_DONT_GRAB_IT = 1
ICOMMS_GRAB_IT = 2
ICOMMS_DROP_IT_NOW = 3
ICOMMS_BRING_ME_THAT = 4
ICOMMS_TAKE_THIS = 5

local t_team_players
local t_enemy_players

function ItemComms_CreateMessage(fromPlayer, toPlayer, aboutPlayer, aboutItemName,
			msgType, allowPorts, expires, complyFunc
		)

end

function ItemComms_Initialize()
	t_team_players = GSI_GetTeamPlayers(TEAM)
	t_enemy_players = GSI_GetTeamPlayers(ENEMY_TEAM)
	ItemComms_Initialize = nil
end

function ItemComms_ICanFillBottleAtLoc(gsiPlayer, location)
	local hasFree, freeSlot = Item_HaveFreeInventorySlot(gsiPlayer)
	if not hasFree then
		return false
	end
	if freeSlot > ITEM_END_INVENTORY_INDEX then
		local bestSwitch = Item_GetBestSwitchOutInInventory(gsiPlayer)
	end
		

	local teamPlayers = t_team_players
	local fillMovementSpeed = gsiPlayer.currentMovementSpeed
	
	for i=1,#teamPlayers do
		local thisPlayer = teamPlayers[i]
		local thisPlayerBottle = thisPlayer.usableItemCache.bottle
		if thisPlayerBottle then
			if Vector_PointDistance(thisPlayer.lastSeen.location, location)
							/ (thisPlayer.currentMovementSpeed + fillMovementSpeed)
						< 5
					and gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth
							- (3 - thisPlayerBottle:GetCurrentCharges()) * 0.15 < 0.69 then
				ItemComms_CreateMessage(gsiPlayer, thisPlayer, thisPlayer, location, thisPlayerBottle:GetName(),
							ICOMMS_BRING_ME_THAT, false, 10,
							function(gsiPlayerGives)
					--			if Vector_PointDistance(gsiPlayer.lastSeen.location,
					--						gsiPlayerGives.lastSeen.location
					--					) > 1400 then
					--				
							end
						)
			end
		end
	end
end

function ItemComms_IHaveSomeonesBottle(gsiPlayer)

end

function ItemComms_ISeeThisRapier(gsiPlayer, itemObj)
	
end

function ItemComms_ICantUseThisRapier(gsiPlayer, hItem)

end

function ItemComms_IOwnThisRapier(gsiPlayer, hItem)
	
end

function ItemComms_IWantMyRapier(gsiPlayer)

end

function ItemComms_IDontWantToHoldThisGem(gsiPlayer)

end

function ItemComms_ICanHoldGem(gsiPlayer)

end

function ItemComms_CheckCommunications(gsiPlayer)

end
