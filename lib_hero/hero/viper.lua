local hero_data = {
	"viper",
	{1, 3, 1, 2, 1, 4, 1, 3, 3, 2, 5, 4, 2, 2, 7, 3, 4, 10, 11},
	{
		"item_branches","item_branches","item_circlet","item_magic_stick","item_slippers","item_wraith_band","item_wraith_band","item_magic_wand","item_boots","item_boots_of_elves","item_power_treads","item_blade_of_alacrity","item_belt_of_strength","item_dragon_lance","item_fluffy_hat","item_staff_of_wizardry","item_hurricane_pike","item_blade_of_alacrity","item_yasha","item_manta","item_aghanims_shard","item_ultimate_orb","item_ultimate_orb","item_skadi","item_quarterstaff","item_butterfly","item_blade_of_alacrity","item_point_booster","item_staff_of_wizardry","item_ogre_axe","item_ultimate_scepter",
	},
	{ {2,2,2,3,3,}, {2,2,2,3,3,}, 0.1 },
	{
		"Poison Attack","Nethertoxin","Corrosive Skin","Viper Strike","+5% Poison Attack Magic Resistance Reduction","+18 Corrosive Skin Damage Per Second","+40 Nethertoxin Min/Max Damage","+15% Corrosive Skin Magic Resistance","+80 Viper Strike DPS","+25%% Poison Attack slow/damage","Become Universal","-50%% Viper Strike manacost/cooldown",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"viper_poison_attack", ABILITY_TYPE.ATTACK_MODIFIER},
		{"viper_nethertoxin", ABILITY_TYPE.NUKE + ABILITY_TYPE.AOE + ABILITY_TYPE.DEGEN},
		{"viper_corrosive_skin", ABILITY_TYPE.PASSIVE},
		[5] = {"viper_viper_strike", ABILITY_TYPE.NUKE + ABILITY_TYPE.SLOW},
}

local ZEROED_VECTOR = ZEROED_VECTOR
local playerRadius = Set_GetEnemyHeroesInPlayerRadius
local ENCASED_IN_RECT = Set_GetEnemiesInRectangle
local CURRENT_TASK = Task_GetCurrentTaskHandle
local CAN_BE_CAST = AbilityLogic_AbilityCanBeCast
local USE_ABILITY = UseAbility_RegisterAbilityUseAndLockToScore
local VEC_UNIT_DIRECTIONAL = Vector_UnitDirectionalPointToPoint
local ACTIVITY_TYPE = ACTIVITY_TYPE
local HANDLE_AUTOCAST_GENERIC = AbilityLogic_HandleAutocastGeneric
local CURRENT_ACTIVITY_TYPE = Blueprint_GetCurrentTaskActivityType
local TASK_OBJECTIVE = Task_GetTaskObjective
local HEALTH_PERCENT = Unit_GetHealthPercent
local SET_ENEMY_HERO = SET_ENEMY_HERO
local ABILITY_LOCKED = UseAbility_IsPlayerLocked
local CROWDED_RATING = Set_GetCrowdedRatingToSetTypeAtLocation
local NEARBY_OUTER = Set_GetEnemyHeroesInPlayerRadiusAndOuter
local HIGH_USE = AbilityLogic_HighUseAllowOffensive
local SPELL_SUCCESS = AbilityLogic_CastOnTargetWillSucceed
local push_handle = Push_GetTaskHandle()

local NETHERTOXIN_CAST_RANGE = 900

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
		if ABILITY_LOCKED(gsiPlayer) then
			return;
		end
		local thisPlayerAbilities = t_player_abilities[gsiPlayer.nOnTeam]
		local poisonAttack = thisPlayerAbilities[1]
		local nethertoxin = thisPlayerAbilities[2]
		local viperStrike = thisPlayerAbilities[4]

		local highUse = gsiPlayer.highUseManaSimple
		local currentTask = CURRENT_TASK(gsiPlayer)
		local currentActivityType = CURRENT_ACTIVITY_TYPE(gsiPlayer)
		local fht = TASK_OBJECTIVE(gsiPlayer, fight_harass_handle)
		local fhtReal = fht and fht.hUnit.IsNull and not fht.hUnit:IsNull()
		local fhtHpp = fht and HEALTH_PERCENT(fht)

		local playerLoc = gsiPlayer.lastSeen.location
		local fhtLoc = fhtReal and fht.lastSeen.location

		local nearbyEnemies, outerEnemies = NEARBY_OUTER(gsiPlayer.lastSeen.location, NETHERTOXIN_CAST_RANGE, 1600)

		HANDLE_AUTOCAST_GENERIC(gsiPlayer, poisonAttack)
		
		if currentActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION then
			if fhtReal and CAN_BE_CAST(gsiPlayer, nethertoxin) then
				local crowdingCenter, crowdedRating = CROWDED_RATING(fht.lastSeen.location, SET_HERO_ENEMY)
				if HIGH_USE(gsiPlayer, nethertoxin, highUse - crowdedRating*nethertoxin:GetManaCost(), fhtHpp)
						and crowdedRating > 1.5
						and Math_PointToPointDistance2D(playerLoc, crowdingCenter)
								< nethertoxin:GetCastRange()-50 then
					USE_ABILITY(gsiPlayer, nethertoxin, crowdingCenter, 400, nil)
					return;
				end
				local fhtMgkDmgFactor = SPELL_SUCCESS(gsiPlayer, fht, nethertoxin)
				if fhtMgkDmgFactor > 0 and HIGH_USE(gsiPlayer, nethertoxin, highUse - nethertoxin:GetManaCost(),
							fhtHpp + fhtHpp*(0.75 - fhtMgkDmgFactor))
						and Math_PointToPointDistance2D(playerLoc, fhtLoc)
								< nethertoxin:GetCastRange()-50 then
					local moveStability = fht.hUnit:GetMovementDirectionStability()
					if moveStability < 0.1 or moveStability > 0.75 then
						local predictedLoc = fht.hUnit:GetExtrapolatedLocation(0.75)
						-- TODO Break consideration; implement better per-enemy-hero determinations
						USE_ABILITY(gsiPlayer, nethertoxin, predictedLoc, 400, nil)
						return;
					end
				end
			end
			--print(fhtReal, CAN_BE_CAST(gsiPlayer, viperStrike))
			if fhtReal and CAN_BE_CAST(gsiPlayer, viperStrike) then
				local viperStrikeDamage = viperStrike:GetSpecialValueFloat("damage")
						* viperStrike:GetSpecialValueInt("duration")
				local afterVsHpp = (fht.lastSeenHealth - viperStrikeDamage) / fht.maxHealth
				--print("viper strike dmg", viperStrikeDamage)
				if Math_PointToPointDistance2D(playerLoc, fhtLoc) < gsiPlayer.attackRange+50
						and HIGH_USE(gsiPlayer, viperStrike, highUse - viperStrike:GetManaCost(), fhtHpp)
						and afterVsHpp > 0.0 and afterVsHpp < 0.75 then
					USE_ABILITY(gsiPlayer, viperStrike, fht, 400, nil)
					return;
				end
			end
		elseif currentActivityType > ACTIVITY_TYPE.CAREFUL then

		end
		if CAN_BE_CAST(gsiPlayer, nethertoxin) then
			local currDanger = gsiPlayer.time.data.theorizedDanger
			if currentTask == push_handle and currDanger and currDanger < -1 then
				local nearbyCreeps = Set_GetNearestEnemyCreepSetAtLaneLoc(
						playerLoc, Map_GetBaseOrLaneLocation(playerLoc)
					)
				if nearbyCreeps then
					USE_ABILITY(gsiPlayer, nethertoxin, nearbyCreeps.center, 400, nil)
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
