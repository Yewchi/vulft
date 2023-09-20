local hero_data = {
	"drow_ranger",
	{1, 3, 1, 2, 3, 5, 3, 3, 1, 7, 1, 5, 2, 2, 9, 2},
	{
		"item_tango","item_branches","item_slippers","item_branches","item_branches","item_magic_stick","item_magic_wand","item_wraith_band","item_boots","item_boots_of_elves","item_gloves","item_power_treads","item_blade_of_alacrity","item_belt_of_strength","item_dragon_lance","item_ogre_axe","item_staff_of_wizardry","item_ultimate_scepter","item_broadsword","item_blitz_knuckles","item_invis_sword","item_lesser_crit","item_silver_edge","item_force_staff","item_hurricane_pike","item_yasha","item_manta","item_butterfly","item_aghanims_shard","item_mithril_hammer","item_ultimate_scepter_2","item_black_king_bar","item_moon_shard",
	},
	{ {1,1,1,1,1,}, {1,1,1,1,1,}, 0.1 },
	{
		"Frost Arrows","Gust","Multishot","Glacier","Marksmanship","+15% Gust Self Movement Speed","+15 Frost Arrow Damage","Gust Reveals Invisible Units","-8s Multishot Cooldown","+25% Multishot Damage","-4s Gust Cooldown","+12% Marksmanship Chance","+1 Multishot Wave",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"drow_ranger_frost_arrows", ABILITY_TYPE.ATTACK_MODIFIER},
		{"drow_ranger_wave_of_silence", ABILITY_TYPE.UTILITY + ABILITY_TYPE.DEGEN + ABILITY_TYPE.AOE},
		{"drow_ranger_multishot", ABILITY_TYPE.NUKE + ABILITY_TYPE.AOE},
		[5] = {"drow_ranger_marksmanship", ABILITY_TYPE.PASSIVE},
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

local GUST_EXTRAPOLATE = 0.25 + 900 / 1150
local MULTISHOT_EXTRAPOLATE = 0.5

local fight_harass_handle = FightHarass_GetTaskHandle()

local t_player_abilities = {}

local d
d = {
	["ReponseNeeds"] = function()
		return nil, REASPONSE_TYPE_DISPEL, nil, {RESPONSE_TYPE_KNOCKBACK, 4}
	end,
	["Initialize"] = function(gsiPlayer)
		AbilityLogic_CreatePlayerAbilitiesIndex(t_player_abilities, gsiPlayer, abilities)
		AbilityLogic_UpdateHighUseMana(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam])
		gsiPlayer.InformLevelUpSuccess = d.InformLevelUpSuccess
	end,
	["InformLevelUpSuccess"] = function(gsiPlayer)
		AbilityLogic_UpdateHighUseMana(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam])
		AbilityLogic_UpdatePlayerAbilitiesIndex(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam], abilities)
	end,
	["AbilityThink"] = function(gsiPlayer) 
		if UseAbility_IsPlayerLocked(gsiPlayer) then
			return;
		end
		local playerAbilities = t_player_abilities[gsiPlayer.nOnTeam]
		local frostArrows = playerAbilities[1]
		local gust = playerAbilities[2]
		local multishot = playerAbilities[3]
		local marksmanship = playerAbilities[4]

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

		local nearbyEnemies, outerEnemies = NEARBY_OUTER(playerLoc, gust:GetCastRange(), 
				gsiPlayer.attackRange*2, 2
			)

		HANDLE_AUTOCAST_GENERIC(gsiPlayer, frostArrows)

		if CAN_BE_CAST(gsiPlayer, gust) then
			if fhtReal and currentActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION then
				local extrapolatedFht = fhtHUnit:GetExtrapolatedLocation(GUST_EXTRAPOLATE)
				if VEC_POINT_DISTANCE(playerLoc, extrapolatedFht) < gust:GetCastRange()*0.95 then
					local crowdedCenter, crowdedRating = CROWDED_RATING(extrapolatedFht, SET_HERO_ENEMY)
					if crowdedRating > 1.5 then -- if / else, save it for more enemies, with bugs
						if VEC_POINT_DISTANCE(playerLoc, crowdedCenter) < gust:GetCastRange()
								and HIGH_USE(gsiPlayer, gust, highUse, fhtHpp/crowdedRating) then
							USE_ABILITY(gsiPlayer, gust, crowdedCenter, 400, nil)
							return;
						end
					elseif SPELL_SUCCESS(gsiPlayer, fht, gust)
							and HIGH_USE(gsiPlayer, gust, highUse, fhtHpp) then
						USE_ABILITY(gsiPlayer, gust, crowdedCenter, 400, nil)
						return;
					end
				end
			elseif currentActivityType >= ACTIVITY_TYPE.FEAR
					and nearbyEnemies[1]
					and HIGH_USE(gsiPlayer, gust, highUse, playerHpp) then
				local crowdedCenter, crowdedRating = CROWDED_RATING(
						nearbyEnemies[1].lastSeen.location, SET_HERO_ENEMY
					)
				local castSucceeds = false
				for i=1,#nearbyEnemies do
					if SPELL_SUCCESS(gsiPlayer, nearbyEnemies[i], gust) then
						castSucceeds = true
						break;
					end
				end
				if castSucceeds
						and VEC_POINT_DISTANCE(playerLoc, crowdedCenter)
							< gust:GetCastRange()*0.9 then
					USE_ABILITY(gsiPlayer, gust, crowdedCenter, 400, nil)
					return;
				end
			end
		end
		if CAN_BE_CAST(gsiPlayer, multishot) then
			if fhtReal and currentActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION then
				local extrapolatedFht = fhtHUnit:GetExtrapolatedLocation(MULTISHOT_EXTRAPOLATE)
				if VEC_POINT_DISTANCE(playerLoc, extrapolatedFht)
						< gsiPlayer.attackRange*1.25 then
					local crowdedCenter, crowdedRating = CROWDED_RATING(extrapolatedFht, SET_HERO_ENEMY)
					if crowdedRating > 1.5 then -- if / else, save it for more enemies, with bugs
						if VEC_POINT_DISTANCE(playerLoc, crowdedCenter) < gsiPlayer.attackRange*1.5
								and HIGH_USE(gsiPlayer, multishot, highUse, fhtHpp/crowdedRating) then
							USE_ABILITY(gsiPlayer, multishot, crowdedCenter, 400, nil)
							return;
						end
					elseif HIGH_USE(gsiPlayer, multishot, highUse, fhtHpp) then
						USE_ABILITY(gsiPlayer, multishot, crowdedCenter, 400, nil)
						return;
					end
				end
			end
		end
	end,
}

local hero_access = function(key) return d[key] end

do
	HeroData_SetHeroData(hero_data, abilities, hero_access)
end
