local hero_data = {
	"invoker",
	{2, 1, 2, 1, 2, 1, 2, 1, 2, 3, 2, 3, 2, 3, 3, 3, 3, 3, 4, 8, 5, 1, 1, 1, 11, 1},
	{
		"item_circlet","item_branches","item_ward_observer","item_circlet","item_branches","item_tango","item_branches","item_magic_wand","item_bracer","item_belt_of_strength","item_gloves","item_boots","item_power_treads","item_urn_of_shadows","item_crown","item_fluffy_hat","item_spirit_vessel","item_gloves","item_hand_of_midas","item_staff_of_wizardry","item_fluffy_hat","item_force_staff","item_dragon_lance","item_hurricane_pike","item_octarine_core","item_gem","item_sheepstick","item_blink","item_aghanims_shard","item_arcane_blink",
	},
	{ {2,2,2,2,3,}, {2,2,2,2,4,}, 0.1 },
	{
		"Quas","Wex","Exort","+50 Ice Wall DPS","-6s Tornado Cooldown","+50 Forged Spirit Attack Speed","-8s Cold Snap Cooldown","+2 Chaos Meteors","+30 Alacrity Damage/Speed","Radial Deafening Blast","x2x Quas/Wex/Exort passive effects",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"invoker_quas", ABILITY_TYPE.UTILITY},
		{"invoker_wex", ABILITY_TYPE.UTILITY},
		{"invoker_exort", ABILITY_TYPE.UTILITY},
		[5] = {"invoker_invoke", ABILITY_TYPE.UTILITY},
		[6] = {"invoker_cold_snap", ABILITY_TYPE.STUN},
		[7] = {"invoker_ghost_walk", ABILITY_TYPE.INVIS},
		[8] = {"invoker_tornado", ABILITY_TYPE.AOE + ABILITY_TYPE.NUKE},
		[9] = {"invoker_emp", ABILITY_TYPE.NUKE + ABILITY_TYPE.DEGEN + ABILITY_TYPE.AOE},
		[10] = {"invoker_alacrity", ABILITY_TYPE.ATTACK_MODIFIER + ABILITY_TYPE.BUFF},
		[11] = {"invoker_chaos_meteor", ABILITY_TYPE.NUKE + ABILITY_TYPE.AOE},
		[12] = {"invoker_sun_strike", ABILITY_TYPE.NUKE + ABILITY_TYPE.SMITE},
		[13] = {"invoker_forge_spirits", ABILITY_TYPE.SUMMON},
		[14] = {"invoker_ice_wall", ABILITY_TYPE.UTILITY},
		[15] = {"invoker_deafening_blast", ABILITY_TYPE.NUKE + ABILITY_TYPE.DEGEN + ABILITY_TYPE.AOE}
}

local d

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
local HIGH_USE_SAFE = AbilityLogic_HighUseAllowSafe
local SPELL_SUCCESS = AbilityLogic_CastOnTargetWillSucceed
local max = math.max
local min = math.min

local SILENCE_MAX_HIT_RANGE = 900 + 425
local SILENCE_TRAVEL_SPEED = 1000
local CRYPT_SWARM_RANGE = 1110

local push_handle = Push_GetTaskHandle()
local fight_harass_handle = FightHarass_GetTaskHandle()
local zonedef_handle = ZoneDefend_GetTaskHandle()

local t_player_abilities = {}

local t_player_invoked = {}

local SD_I__INVOKE_ORBS = 1
local SD_I__AOE_ST = 2
local SD_I__DMG = 3
local SD_I__CONTROL = 4
-- SD_I__IMPACT How well it will swing a fight.
local SD_I__IMPACT = 5
-- SD_I__MANA_INEFFICIENCY Generally, the more required of the player, the greater the ineffiency.
-- - Be inefficient when scared, the fight is large, or the hero is frightening; and when commited.
-- - Be inefficient when a spell has high confidence to accurately hit
local SD_I__MANA_INEFFICIENCY = 6

local t_spell_number = {
	"invoker_cold_snap",
	"invoker_ghost_walk",
	"invoker_tornado",
	"invoker_emp",
	"invoker_alacrity",
	"invoker_chaos_meteor",
	"invoker_sun_strike",
	"invoker_forge_spirits",
	"invoker_ice_wall",
	"invoker_deafening_blast"
}
-- orbs effects table = { [SPELL_NUM] = { orbs_effect_for_fight, orbs_effect_for_scrappy, orbs_effect_for_dfensive}, }
local t_quas_effects_priority = {
	{0.025, 0.110, 0.015}, -- CS
	{0.000, 0.000, 0.250}, -- GW, re: defensive wex score going over target max 1 score: invis is invis.
	{0.070, 0.040, 0.030}, -- T
	{0.000, 0.000, 0.000}, -- EMP
	{0.000, 0.000, 0.000}, -- A
	{0.000, 0.000, 0.000}, -- CM
	{0.000, 0.000, 0.000}, -- SS
	{0.035, 0.025, 0.000}, -- FS Probably just going to ignore double summon to keep logic simple. 
	{0.055, 0.035, 0.050}, -- IW
	{0.045, 0.010, 0.015}, -- DB
}
local t_wex_effects_priority = {
	{0.000, 0.000, 0.000}, -- CS
	{0.000, 0.000, 0.250}, -- GW
	{0.100, 0.080, 0.020}, -- T
	{0.110, 0.100, 0.000}, -- EMP
	{0.040, 0.070, 0.000}, -- A
	{0.030, 0.015, 0.000}, -- CM
	{0.000, 0.000, 0.000}, -- SS
	{0.000, 0.000, 0.000}, -- FS
	{0.000, 0.000, 0.000}, -- IW
	{0.105, 0.080, 0.110}, -- DB Unsure if this should be higher than invis
}
local t_exort_effects_priority = {
	{0.000, 0.000, 0.000}, -- CS
	{0.000, 0.000, 0.000}, -- GW
	{0.000, 0.000, 0.000}, -- T
	{0.000, 0.000, 0.000}, -- EMP
	{0.040, 0.090, 0.000}, -- A
	{0.110, 0.075, 0.000}, -- CM
	{0.040, 0.080, 0.000}, -- SS Offensive score assumes it is used intelligently, hitting 1
	{0.035, 0.065, 0.000}, -- FS
	{0.025, 0.035, 0.005}, -- IW
	{0.030, 0.020, 0.005}, -- DB
}
local t_orb_effects_priorities = {
	t_quas_effects_priority,
	t_wex_effects_priority,
	t_exort_effects_priority
}

local TORNADO_TRAVEL_SPEED = 1000 -- A note because Invoker is notable: these types of values are hard-coded because internal game values are usually not updated, the value exists but is outdated, or doesn't exist

local t_player_choice_tables = {}
local INVO_MODE_I__OFF = 1
local INVO_MODE_I__SCR = 2
local INVO_MODE_I__DEF = 3

local t_player_orb_levels = {}

local INVO_SD_I__INVOKE_ORBS = 1
local INVO_SD_I__L_FO = 2
local INVO_SD_I__L_SO = 3
local INVO_SD_I__L_DE = 4
local spell_data_hard_code = {
	["invoker_cold_snap"] = {1, 1, 1},
	["invoker_ghost_walk"] = {1, 1, 2},
	["invoker_tornado"] = {1, 2, 2},
	["invoker_emp"] = {2, 2, 2},
	["invoker_alacrity"] = {2, 2, 3},
	["invoker_chaos_meteor"] = {2, 3, 3},
	["invoker_sun_strike"] = {3, 3, 3},
	["invoker_forge_spirits"] = {1, 3, 3},
	["invoker_ice_wall"] = {1, 1, 3},
	["invoker_deafening_blast"] = {1, 2, 3},
}

local t_player_card_ready = {}

local t_player_card_to_set = {}

local t_enemy_players

--local ability_hit_secure = {
--	{"invoker_tornado", function(hAbility) hAbility:GetLevel()*d[

local REPRIORITIZE_CHOICES = function(gsiPlayer)
	local choices = t_player_choice_tables[gsiPlayer.nOnTeam]
	local effectsPriorities = t_orb_effects_priorities
	local playerOrbLevels = t_player_orb_levels[gsiPlayer.nOnTeam]
	for iModeType=1,3 do
		for iSpell=1,#t_spell_number do
			local spellInModeScore = 0
			for iOrb=1,3 do
				-- Add up each orb's currently leveled effectiveness for the spell in that mode
				spellInModeScore = spellInModeScore
						+ (effectsPriorities[iOrb][iSpell][iModeType] * playerOrbLevels[iOrb])
			end
			choices[iModeType][iSpell] = spellInModeScore
		end
	end
	if VERBOSE then print("INVO - Printing  reprioritized spell choices. time taken:"); Util_TablePrint(choices) end
end

local FIND_BEST_OFFENSIVE_COMBO = function(gsiPlayer, abilityScoreTbl)
	local highestScore = 0
	local setComboTbl = t_player_card_to_set[gsiPlayer.nOnTeam]
	for i=1,4 do
		setComboTbl[i] = nil
	end
	for i=1,#abilityScoreTbl do
		local isInvoked = false
		--if abilityScoreTbl[i]* > highestScore then 
	end
end

local FIND_BEST_SCRAPPY_COMBO = function(gsiPlayer, abilityScoreTbl)
end

local FIND_BEST_DEFENSIVE_COMBO = function(gsiPlayer, abilityScoreTbl)
end

local PREPARE_SET_COMBO = function(gsiPlayer, combo, playerAbilities) 
	--local invokeCount = combo[
	local invoked1 = gsiPlayer.hUnit:GetAbilityInSlot(3)
	local invoked2 = gsiPlayer.hUnit:GetAbilityInSlot(4)
	-- TODO REMOVE THIS NOTE AFTER YOU set the score of the non-invoking or casting ability
	-- - combo function via the 'return nextFunc, newScore' ability func prototype def.
	-- - Set the new score to something obscenely low so that we don't try to use ability
	-- - and the use_ability function is clutched by finding that required states are valid
	-- - in the TryAbility function. Basically it prevents invo from being crazy CPU intense.
	-- - A combo def .'. needs to set TryAbility's checking function to clutch the use_ability
	-- - funcs, or else it will always expire.
	-- === Invoking ===
	if invoked1 and invoked1:GetName() == card[CARD_I__INVOKES][1]
			and (invokeCount == 1
					or invoked2 and invoked2:GetName() == card[CARD_I__INVOKES][2]
				) then
		print("Carl card is already ready")
		t_player_card_ready[gsiPlayer.nOnTeam] = card
		return
	end
	-- Register the invoke combo 
	for i=1,min(2, invokeCount) do
		for QWEnd=1,3 do
			USE_ABILITY(gsiPlayer,
					playerAbilities[
							invoke_requires[card[CARD_I__INVOKES][i]][QWEnd]
						],
					nil, 400, "INVOKER_INVOKING_COMBO", nil, nil, 0.25*QWEnd
				)
		end
		-- TODO Lua memory and scope handling here is interesting. How is correct variable context kept?
		USE_ABILITY(gsiPlayer,
				function()
					local invokeThisName = highestScoreCard[CARD_I__INVOKES][i]
					if not CAN_BE_CAST(gsiPlayer, invoke) then
						-- TEST not sure if this is always true
						local ability = gsiPlayer.hUnit:GetAbilityInSlot(2+i) -- Lua moment
						if ability and ability:GetName() == invokeThisName then
							t_player_card_ready[gsiPlayer.nOnTeam] = card
							print("Carl card is found casted ready", invokeThisName)
						else
							print("Carl card wasn't right but invoke not castable",
									ability and ability:GetName(), invokeThisName
								)
						end
						return true
					end
					gsiPlayer.hUnit:Action_UseAbility(invoke)
				end,
				nil, 400, "INVOKER_INVOKING_COMBO", nil, nil, 1
			)
	end
end

local USE_CARD = function(gsiPlayer, card, playerAbilities)
	-- === Casting === -- = Optional (invoke_count > 2) then interveve card invoking and casting during combo
	-- Check for good use, register the invoked spells as a combo if the situation is right.
	local invoked1 = gsiPlayer.hUnit:GetAbilityInSlot(3)
	local invoked2 = gsiPlayer.hUnit:GetAbilityInSlot(4)
	if invokeCount == 1 then
		-- TEST do not know if always true invoked1
		USE_ABILITY(gsiPlayer, invoked1, target, 400, card[CARD_I__EXPIRES][1])
	elseif invokeCount == 2 then
		USE_ABILITY(gsiPlayer, invoked1, target, 400, "INVOKER_CASTING_COMBO",
				nil, nil, card[CARD_I__EXPIRES][1]
			)
		-- TODO needs wait time added to elapseExpiry for euls, tornado combos calculated by
		-- -- (<tornado/euls airtime> - <next spell lead up>)
		USE_ABILITY(gsiPlayer, invoked2, target, 400, "INVOKER_CASTING_COMBO",
				nil, nil, card[CARD_I__EXPIRES][2]
			)
	elseif invokeCount == 3 then
		if true then return false end
		USE_ABILITY(gsiPlayer, invoked1, target, 400, "INVOKER_CASTING_COMBO",
				nil, nil, card[CARD_I__EXPIRES][1]
			)
		-- NOTE: Not abstracted because it is Lua.
		for QWEnd=1,3 do
			USE_ABILITY(gsiPlayer,
					playerAbilities[
							invoke_requires[highestScoreCard[CARD_I__INVOKES][i]][QWEnd]
						],
					nil, 400, "INVOKER_INVOKING_COMBO", nil, nil, 0.25*QWEnd
				)
		end
		-- TODO Lua memory and scope handling here is interesting. How is correct variable context kept?
		USE_ABILITY(gsiPlayer,
					function()
						local invokeThisName = highestScoreCard[CARD_I__INVOKES][3]
						if not CAN_BE_CAST(gsiPlayer, invoke) then
							-- TEST not sure if this is always true
							local ability = gsiPlayer.hUnit:GetAbilityInSlot(3)
							if ability and ability:GetName() == invokeThisName then
								t_player_card_ready[gsiPlayer.nOnTeam] = highestScoreCard
								print("Carl card is found casted ready", invokeThisName)
							else
								print("Carl card wasn't right but invoke not castable", ability and ability:GetName(), invokeThisName)
							end
							return true
						end
						playerHUnit:Action_UseAbility(invoke)
					end,
					nil, 400, "INVOKER_INVOKING_COMBO", nil, nil, 1
				)
	end
	--t_player_card_ready[gsiPlayer.nOnTeam] = false
end

d = {
	["tornado_airtime_at_level"] = {1.6, 0.85, 1.1, 1.35, 1.6, 1.85, 2.1, 2.35, 2.6},
	["TornadoAirtime"] = function(gsiPlayer)
			local quas = gsiPlayer.hUnit:GetAbilityByName("invoker_quas")
			local level = quas and quas:GetLevel() or 0
			return d.tornado_airtime_at_level[level]
	end,
	["tornado_distance_at_level"] = {2600, 800, 1200, 1600, 2000, 2400, 2800, 3200},
	["TornadoDistance"] = function(gsiPlayer)
			local wex = gsiPlayer.hUnit:GetAbilityByName("invoker_wex")
			local level = wex and wex:GetLevel() or 0
			return d.tornado_distance_at_level[level]
	end,
	["sunstrike_damage_at_level"] = {300, 120, 180, 240, 300, 360, 420, 480},
	["SunstrikeDamage"] = function(gsiPlayer)
			local export = gsiPlayer.hUnit:GetAbilityByName("invoker_exort")
			local level = exort and exort:GetLevel() or 0
			return d.tornado_distance_at_level[level]
	end,
	["ReponseNeeds"] = function()
		return nil, REASPONSE_TYPE_DISPEL, nil, {RESPONSE_TYPE_KNOCKBACK, 4}
	end,
	["Initialize"] = function(gsiPlayer)
		AbilityLogic_CreatePlayerAbilitiesIndex(t_player_abilities, gsiPlayer, abilities)
		AbilityLogic_UpdateHighUseMana(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam])
		local playerHUnit = gsiPlayer.hUnit
		t_player_invoked[gsiPlayer.nOnTeam] = {
				playerHUnit:GetAbilityInSlot(3),
				playerHUnit:GetAbilityInSlot(4)
			}
		t_enemy_players = GSI_GetTeamPlayers(ENEMY_TEAM)
		t_player_orb_levels[gsiPlayer.nOnTeam] = {
				playerHUnit:GetAbilityInSlot(0):GetLevel(),
				playerHUnit:GetAbilityInSlot(1):GetLevel(),
				playerHUnit:GetAbilityInSlot(2):GetLevel(),
			}
		t_player_choice_tables[gsiPlayer.nOnTeam] = {{}, {}, {}}
		REPRIORITIZE_CHOICES(gsiPlayer)
		t_player_card_to_set[gsiPlayer.nOnTeam] = {}
		gsiPlayer.InformLevelUpSuccess = d.InformLevelUpSuccess
	end,
	["InformLevelUpSuccess"] = function(gsiPlayer)
		AbilityLogic_UpdateHighUseMana(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam])
		REPRIORITIZE_CHOICES(gsiPlayer)
		AbilityLogic_UpdatePlayerAbilitiesIndex(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam], abilities)
	end,
	["AbilityThink"] = function(gsiPlayer) 
		local isLocked, isCombo = UseAbility_IsPlayerLocked(gsiPlayer)
		if true then return end
		if isCombo then
			-- TODO breaking code should probably be here. Set a flag or break func when using a combo
			return;
		end
		local playerAbilities = t_player_abilities[gsiPlayer.nOnTeam]
		local quas = playerAbilities[1]
		local wex = playerAbilities[2]
		local exort = playerAbilities[3]
		local invoke = playerAbilities[4]
		local invoked1 = gsiPlayer.hUnit:GetAbilityInSlot(3)
		local invoked2 = gsiPlayer.hUnit:GetAbilityInSlot(4)

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

		local nearbyEnemies, outerEnemies = NEARBY_OUTER(playerLoc, 1000,
				2600, 8
			)

		local allEnemies = Set_Get

		local danger = Analytics_GetTheoreticalDangerAmount(gsiPlayer)

		local arbitraryEnemy = nearbyEnemies[1] or outerEnemies[1]

		local choiceTbls = t_player_choice_tables[gsiPlayer.nOnTeam]

		-- create a combo around best-fit spell
		if currentActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION then
			if #nearbyEnemies*1 + #outerEnemies*0.67 > 2 then
				local mostEffectiveSpell
						= HIGHEST_SPELL_EFFECT(gsiPlayer, choiceTbls[INVO_MODE_I__OFF])
				-- make a custom combo around the spell, appropriate to our mana
				--local combo = PREPARE_OFFENSIVE_COMBO_FOR_SPELL(gsiPlayer, )
			else
				local mostEffectiveSpell
						= HIGHEST_SPELL_EFFECT(gsiPlayer, choiceTbls[INVO_MODE_I__SCR])
				local combo = PREPARE_OFFENSIVE_COMBO_FOR_SPELL()
			end
		else
			local mostEffectiveSpell, highestSingleUse
						= HIGHEST_SPELL_EFFECT(gsiPlayer, choiceTbls[INVO_MODE_I__DEF])

		end

		local highestScoreCard
		local highestScore = 0
		
		for i=1,#cards do
			highestScoreCard = cards[1]	
		end

		-- Main invoking and casting system
		if highestScoreCard then
			if t_player_card_ready[gsiPlayer.nOnTeam] ~= highestScoreCard then
				-- === Invoking ===
				PREPARE_CARD(gsiPlayer, highestScoreCard, playerAbilities)
			else
				-- === Casting ===
				local useNow, target = card[CARD_I__QUERY_USE](gsiPlayer, fht)
				if useNow then
					USE_CARD(gsiPlayer, highestScoreCard, playerAbilities)
				end
			end
		end

		for i=0,playerHUnit:NumModifiers()-1 do
			local modifierName = playerHUnit:GetModifierName(i)
			if modifierName then
				print("invo mod!", i, modifierName)
			end
		end

		for i=1,23 do
			print(i, "invo!", playerAbilities[i] and playerAbilities[i]:GetName())
		end
	end,
}

local hero_access = function(key) return d[key] end

do
	HeroData_SetHeroData(hero_data, abilities, hero_access)
end
