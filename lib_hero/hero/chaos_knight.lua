local hero_data = {
	"chaos_knight",
	{1, 3, 2, 3, 3, 4, 3, 2, 2, 2, 1, 4, 1, 1, 7, 5, 4, 10, 11},
	{
		"item_enchanted_mango","item_magic_stick","item_branches","item_branches","item_branches","item_branches","item_gloves","item_boots","item_power_treads","item_gloves","item_blades_of_attack","item_armlet","item_magic_wand","item_quarterstaff","item_robe","item_oblivion_staff","item_ogre_axe","item_echo_sabre","item_mithril_hammer","item_black_king_bar","item_blink","item_echo_sabre","item_aghanims_shard","item_blitz_knuckles","item_claymore","item_orchid","item_mage_slayer","item_bloodthorn","item_overwhelming_blink",
	},
	{ {1,1,1,1,1,}, {1,1,1,1,1,}, 0.1 },
	{
		"Chaos Bolt","Reality Rift","Chaos Strike","Phantasm","+22% Chaos Strike Lifesteal","+225 Reality Rift Pull Distance","-3s Chaos Bolt Cooldown","--75% Phantasm Illusion Incoming Damage","+0.5 Min/Max Chaos Bolt Duration","Reality Rift Pierces Spell Immune","+10% Chaos Strike Chance","+10.0s Phantasm Duration",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"chaos_knight_chaos_bolt", ABILITY_TYPE.NUKE + ABILITY_TYPE.STUN, 0.2},
		{"chaos_knight_reality_rift", ABILITY_TYPE.SLOW + ABILITY_TYPE.DEGEN, 0.1},
		{"chaos_knight_chaos_strike", ABILITY_TYPE.PASSIVE, 0.1},
		[5] = {"chaos_knight_phantasm", ABILITY_TYPE.BUFF, 0.2},
}

local ZEROED_VECTOR = ZEROED_VECTOR
local playerRadius = Set_GetEnemyHeroesInPlayerRadius
local ENCASED_IN_RECT = Set_GetEnemiesInRectangle
local CURRENT_TASK = Task_GetCurrentTaskHandle
local CAN_BE_CAST = AbilityLogic_AbilityCanBeCast
local CHARGE_CAN_BE_CAST = ChargedCooldown_AbilityCanBeCast
local USE_ABILITY = UseAbility_RegisterAbilityUseAndLockToScore
local VEC_POINT_DISTANCE = Vector_PointDistance
local VEC_UNIT_DIRECTIONAL = Vector_UnitDirectionalPointToPoint
local ACTIVITY_TYPE = ACTIVITY_TYPE
local HANDLE_AUTOCAST_GENERIC = AbilityLogic_HandleAutocastGeneric
local AOHK = AbilityLogic_AllowOneHitKill
local ANY_HARM = FightClimate_AnyIntentToHarm
local CURRENT_ACTIVITY_TYPE = Blueprint_GetCurrentTaskActivityType
local TASK_OBJECTIVE = Task_GetTaskObjective
local HEALTH_PERCENT = Unit_GetHealthPercent
local SET_ENEMY_HERO = SET_ENEMY_HERO
local ABILITY_LOCKED = UseAbility_IsPlayerLocked
local CROWDED_RATING = Set_GetCrowdedRatingToSetTypeAtLocation
local NEARBY_OUTER = Set_GetEnemyHeroesInPlayerRadiusAndOuter
local NEARBY_ENEMY = Set_GetEnemyHeroesInPlayerRadius
local HIGH_USE = AbilityLogic_HighUseAllowOffensive
local SPELL_SUCCESS = AbilityLogic_CastOnTargetWillSucceed
local max = math.max
local min = math.min
local sqrt = math.sqrt

local fight_harass_handle = FightHarass_GetTaskHandle()

local t_player_abilities = {}

local ILLUSION_SEARCH_RADIUS = 1375

local BOT_MODE_NONE = BOT_MODE_NONE
local CHAOS_KNIGHT_INTERNAL_STR = "npc_dota_hero_chaos_knight"

local d = {
	["ReponseNeeds"] = function()
		return nil, REASPONSE_TYPE_DISPEL, nil, {RESPONSE_TYPE_KNOCKBACK, 4}
	end,
	["Initialize"] = function(gsiPlayer)
		AbilityLogic_CreatePlayerAbilitiesIndex(t_player_abilities, gsiPlayer, abilities)
		AbilityLogic_UpdateHighUseMana(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam])
	end,
	["InformLevelUpSuccess"] = function(gsiPlayer)
		AbilityLogic_UpdateHighUseMana(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam])
	end,
	["AbilityThink"] = function(gsiPlayer) 
		if UseAbility_IsPlayerLocked(gsiPlayer) then
			return;
		end
		local playerAbilities = t_player_abilities[gsiPlayer.nOnTeam]
		local bolt = playerAbilities[1]
		local rift = playerAbilities[2]
		local phantasm = playerAbilities[4]

		local highUse = gsiPlayer.highUseManaSimple
		local currentTask = CURRENT_TASK(gsiPlayer)
		local currentActivityType = CURRENT_ACTIVITY_TYPE(gsiPlayer)
		local fht = TASK_OBJECTIVE(gsiPlayer, fight_harass_handle)
		local fhtReal = fht and fht.hUnit.IsNull and not fht.hUnit:IsNull()
		local fhtHUnit = fhtReal and fht.hUnit
		local fhtHpp = fht and fht.lastSeenHealth / fht.maxHealth
		local fhtLoc = fht and fht.lastSeen.location

		local playerHUnit = gsiPlayer.hUnit
		local playerLoc = gsiPlayer.lastSeen.location
		local playerHpp = HEALTH_PERCENT(gsiPlayer)

		local distToFht = fht and VEC_POINT_DISTANCE(playerLoc, fhtLoc)

		local nearbyEnemies, outerEnemies = NEARBY_OUTER(playerLoc, rift:GetCastRange(), 1200, 2)

		local danger = Analytics_GetTheoreticalDangerAmount(gsiPlayer)

		local arbitraryEnemy = nearbyEnemies[1] or outerEnemies[1]
		
		local dotaAllies = playerHUnit:GetNearbyHeroes(ILLUSION_SEARCH_RADIUS, false, BOT_MODE_NONE)
		local chaosKnightCount = 0
		for i=1,#dotaAllies do
			if dotaAllies[i]:GetUnitName() == CHAOS_KNIGHT_INTERNAL_STR then
				chaosKnightCount = chaosKnightCount + 1
			end
		end

		--print("ck 1", fhtReal, CAN_BE_CAST(gsiPlayer, phantasm))
		if fhtReal and CAN_BE_CAST(gsiPlayer, phantasm) then
			if currentActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION
					and distToFht < 1300
					and HIGH_USE(gsiPlayer, phantasm, highUse, fhtHpp) then
				local armlet = playerHUnit:FindItemSlot("item_armlet")
				armlet = armlet ~= -1 and playerHUnit:GetItemInSlot(armlet) or false
				--print("ck 2", armlet)
				local previousMaxHealth = 0
				if not playerHUnit:HasModifier("modifier_ancient_apparition_ice_blast")
						and armlet then
					--print("ck 3, registering phantasm")
					USE_ABILITY(gsiPlayer, function()
								if not CAN_BE_CAST(gsiPlayer, phantasm) then return true end
								if not CAN_BE_CAST(gsiPlayer, armlet) then return 1 end
								if armlet:GetAutoCastState() then
									--DebugDrawText(500, 500, "running armlet"..previousMaxHealth, 255, 255, 255)
									local newMaxHealth = playerHUnit:GetMaxHealth()
									if newMaxHealth > previousMaxHealth then
										previousMaxHealth = newMaxHealth
									else
										return 1
									end
								else
									armlet:ToggleAutoCast()
								end
								return false
							end,
							nil, 500, "CHAOS_KNIGHT_ARMLET_PHANTASM",
							nil, nil, 1.5
						)
					USE_ABILITY(gsiPlayer, phantasm, nil, 500, "CHAOS_KNIGHT_ARMLET_PHANTASM", nil, nil, 1)
				else
					USE_ABILITY(gsiPlayer, phantasm, nil, 500, nil)
				end
				return;
			end
		end
		-- TODO Defensive rift into displaced enemy towards fountain
		if fhtReal and CAN_BE_CAST(gsiPlayer, rift)
				and distToFht < rift:GetCastRange()
				and not playerHUnit:GetAttackTarget()
				and distToFht > gsiPlayer.attackRange
				and currentActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION
				and HIGH_USE(gsiPlayer, rift, highUse, fhtHpp) then
			USE_ABILITY(gsiPlayer, rift, fht, 500, nil)
			return;
		end
		if arbitraryEnemy and CAN_BE_CAST(gsiPlayer, bolt) then
			if fhtReal and currentActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION
					and HIGH_USE(gsiPlayer, bolt, highUse, fhtHpp)
					and distToFht < bolt:GetCastRange() then
				USE_ABILITY(gsiPlayer, bolt, fht, 500, nil)
				return;
			end
			if currentActivityType < ACTIVITY_TYPE.CAREFUL then
				local saveFromUnit, saveUnit = FightClimate_GetIntentCageFightSaveJIT(
						gsiPlayer, nil, nearby, bolt:GetCastRange(), true
					)
				if saveFromUnit and HIGH_USE(
								gsiPlayer, bolt, highUse,
								saveFromUnit.lastSeenHealth / saveFromUnit.maxHealth
						) then
					DebugDrawCircle(saveFromUnit.lastSeen.location, bolt:GetCastRange(), 0, 255, 0)
					USE_ABILITY(gsiPlayer, bolt, saveFromUnit, 500, nil)
					return;
				end
			elseif HIGH_USE(gsiPlayer, bolt, highUse, playerHpp) then
				local nearestEnemy, distToNearest = Set_GetSetUnitNearestToLocation(playerLoc, nearbyEnemies)
				if distToNearest < bolt:GetCastRange() then
					USE_ABILITY(gsiPlayer, bolt, nearestEnemy, 500, nil)
					return;
				end
			end
		end
	end,
}

local hero_access = function(key) return d[key] end

do
	HeroData_SetHeroData(hero_data, abilities, hero_access)
end


