local hero_data = {
	"grimstroke",
	{1, 3, 2, 3, 3, 2, 3, 2, 2, 6, 4, 4, 1, 1, 1, 7, 4, 10, 11},
	{
		"item_ward_observer","item_branches","item_tango","item_blood_grenade","item_magic_stick","item_clarity","item_boots","item_energy_booster","item_arcane_boots","item_magic_wand","item_void_stone","item_wind_lace","item_aether_lens","item_tranquil_boots","item_cloak","item_glimmer_cape","item_aghanims_shard","item_staff_of_wizardry","item_fluffy_hat","item_force_staff","item_point_booster","item_staff_of_wizardry","item_ogre_axe","item_ultimate_scepter","item_mystic_staff","item_sheepstick","item_ultimate_scepter_2","item_cyclone","item_mystic_staff",
	},
	{ {3,3,3,3,1,}, {4,4,4,4,5,}, 0.1 },
	{
		"Stroke of Fate","Phantom's Embrace","Ink Swell","Soulbind","+65 Phantom's Embrace DPS","-5.0s Ink Swell Cooldown","+25.0% Soulbind Spell Damage","+16% Ink Swell Movement Speed","+1000 Stroke of Fate Cast Range","+3 Hits to Kill Phantom","+150 Ink Swell Radius","+60% Stroke of Fate Damage",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_STRATEGY_TIME then return hero_data end

local abilities = {
		[0] = {"grimstroke_dark_artistry", ABILITY_TYPE.SLOW + ABILITY_TYPE.NUKE},
		{"grimstroke_ink_creature", ABILITY_TYPE.NUKE + ABILITY_TYPE.DEGEN},
		{"grimstroke_spirit_walk", ABILITY_TYPE.STUN + ABILITY_TYPE.NUKE + ABILITY_TYPE.MOBILITY + ABILITY_TYPE.AOE},
		{"grimstroke_dark_portrait", ABILITY_TYPE.SUMMON},
		[5] = {"grimstroke_soul_chain", ABILITY_TYPE.SLOW + ABILITY_TYPE.ROOT + ABILITY_TYPE.DEGEN + ABILITY_TYPE.AOE},
}

local ZEROED_VECTOR = ZEROED_VECTOR
local playerRadius = Set_GetEnemyHeroesInPlayerRadius
local ENCASED_IN_RECT = Set_GetEnemiesInRectangle
local CURRENT_TASK = Task_GetCurrentTaskHandle
local CAN_BE_CAST = AbilityLogic_AbilityCanBeCast
local CHARGE_CAN_BE_CAST = ChargedCooldown_AbilityCanBeCast
local USE_ABILITY = UseAbility_RegisterAbilityUseAndLockToScore
local VEC_POINT_DISTANCE = Vector_PointDistance2D
local VEC_UNIT_DIRECTIONAL = Vector_UnitDirectionalPointToPoint2D
local ACTIVITY_TYPE = ACTIVITY_TYPE
local HANDLE_AUTOCAST_GENERIC = AbilityLogic_HandleAutocastGeneric
local AOHK = AbilityLogic_AllowOneHitKill
local ANY_HARM = FightClimate_AnyIntentToHarm
local CURRENT_ACTIVITY_TYPE = Blueprint_GetCurrentTaskActivityType
local TASK_OBJECTIVE = Task_GetTaskObjective
local HEALTH_PERCENT = Unit_GetHealthPercent
local SET_HERO_ENEMY = SET_HERO_ENEMY
local ABILITY_LOCKED = UseAbility_IsPlayerLocked
local CROWDED_RATING = Set_GetCrowdedRatingToSetTypeAtLocation
local NEARBY_OUTER = Set_GetEnemyHeroesInPlayerRadiusAndOuter
local NEARBY_ENEMY = Set_GetEnemyHeroesInPlayerRadius
local HIGH_USE = AbilityLogic_HighUseAllowOffensive
local SPELL_SUCCESS = AbilityLogic_CastOnTargetWillSucceed
local max = math.max
local min = math.min

local push_handle = Push_GetTaskHandle()
local fight_harass_handle = FightHarass_GetTaskHandle()

local S_O_F_CAST_POINT = 0.6
local S_O_F_TRAVEL_SPEED = 2400
local S_C_BIND_RADIUS = 600

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
		local darkArt = playerAbilities[1]
		local phantom = playerAbilities[2]
		local inkSwell = playerAbilities[3]
		local darkPortrait = playerAbilities[4]
		local soulChain = playerAbilities[5]

		local darkArtRadius = darkArt:GetAOERadius()
		darkArtRadius = darkArtRadius and darkArtRadius > 0 and darkArtRadius or 120

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

		local nearbyEnemies = NEARBY_ENEMY(gsiPlayer, soulChain:GetCastRange() + S_C_BIND_RADIUS, 2)

		local fhtMgkDmgFactor = fhtReal and SPELL_SUCCESS(gsiPlayer, fht, darkArt)

		local arbitraryEnemy = nearbyEnemies[1]

		local waitSoulChain = CAN_BE_CAST(gsiPlayer, soulChain) and nearbyEnemies[2]
		--print("GRIM")
		--print(soulChain:GetCastRange() + S_C_BIND_RADIUS, waitSoulChain)
		if waitSoulChain then
			local nearestLinking
			local nearestLinkingDist = 0xFFFF
			for i=1,#nearbyEnemies do
				local ithEnemy = nearbyEnemies[i]
				local ithEnemyToPlayerDist = VEC_POINT_DISTANCE(playerLoc, ithEnemy.lastSeen.location)
				if ithEnemyToPlayerDist < nearestLinkingDist then
					for k=i+1,#nearbyEnemies do
						if VEC_POINT_DISTANCE(ithEnemy.lastSeen.location,
									nearbyEnemies[k].lastSeen.location
								) < S_C_BIND_RADIUS*0.9 then
							nearestLinking = ithEnemy
							nearestLinkingDist = ithEnemyToPlayerDist
						end
					end
				end
			end
			--print(nearestLinking, nearestLinkingDist)
			if nearestLinking
					and HIGH_USE(gsiPlayer, soulChain, highUse,
							nearestLinking.lastSeenHealth/nearestLinking.maxHealth
					) then
				waitSoulChain = nearestLinkingDist < phantom:GetCastRange()*1.15
						and nearestLinking
						or false
				if nearestLinkingDist < soulChain:GetCastRange() then
					USE_ABILITY(gsiPlayer, soulChain, nearestLinking, 400, nil)
					return;
				end
			end
		end
		if not waitSoulChain and CAN_BE_CAST(gsiPlayer, phantom) then
			-- TODO "GetThreateningSpellcaster" "GetThreateningAttacker"
			local phantomCastRange = phantom:GetCastRange()
			if currentActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION then
				if fhtReal and fhtMgkDmgFactor > 0 and distToFht < phantomCastRange
						and HIGH_USE(gsiPlayer, phantom, highUse, fhtHpp) then
					USE_ABILITY(gsiPlayer, phantom, fht, 400, nil)
					return;
				else
					for i=1,#nearbyEnemies do
						local thisEnemy = nearbyEnemies[i]
						if thisEnemy ~= fht and not pUnit_IsNullOrDead(thisEnemy)
								and SPELL_SUCCESS(gsiPlayer, thisEnemy, phantom) > 0
								and VEC_POINT_DISTANCE(playerLoc, thisEnemy.lastSeen.location)
										< phantomCastRange+40
								and ( HIGH_USE(gsiPlayer, phantom, highUse,
										thisEnemy.lastSeenHealth / thisEnemy.maxHealth
									) or gsiPlayer.lastSeenMana > phantom:GetManaCost()
										and thisEnemy.hUnit:HasModifier("modifier_grimstroke_soul_chain")
								) then
							USE_ABILITY(gsiPlayer, phantom, fht, 400, nil)
							return;
						end
					end
				end
			elseif arbitraryEnemy and currentActivityType >= ACTIVITY_TYPE.FEAR then
				local nearestEnemy = Set_GetNearestEnemyHeroToLocation(playerLoc)
				if nearestEnemy and SPELL_SUCCESS(gsiPlayer, nearestEnemy, phantom) > 0
						and VEC_POINT_DISTANCE(playerLoc, nearestEnemy.lastSeen.location)
								< phantomCastRange + 40
						and HIGH_USE(gsiPlayer, phantom, highUse, playerHpp) then
					USE_ABILITY(gsiPlayer, phantom, nearestEnemy, 400, nil)
					return;
				end
			end
		end
		if CAN_BE_CAST(gsiPlayer, inkSwell) and arbitraryEnemy then
			local crowdedCenter, crowdedRating = CROWDED_RATING(arbitraryEnemy.lastSeen.location,
					SET_HERO_ENEMY
				)
			local clearForLaunchHero = Team_GetClearForLaunchHero()
			if clearForLaunchHero and VEC_POINT_DISTANCE(playerLoc, clearForLaunchHero.lastSeen.location)
					< inkSwell:GetCastRange()*1.05 then
				USE_ABILITY(gsiPlayer, inkSwell, clearForLaunchHero, 400, nil)
				return;
			end
			local frontAllied, closenessToCenter =  Set_GetNearestAlliedHeroToLocation(crowdedCenter)
			if frontAllied and closenessToCenter < inkSwell:GetSpecialValueInt("radius") then
				USE_ABILITY(gsiPlayer, inkSwell, frontAllied, 400, nil)
				return;
			end
		end
		if CAN_BE_CAST(gsiPlayer, darkArt) then
			-- TODO
			if fhtReal and HIGH_USE(gsiPlayer, darkArt, highUse, fhtHpp) then
				local extrapolatedFht = fhtHUnit:GetExtrapolatedLocation(
						( S_O_F_CAST_POINT + distToFht*1.15 / S_O_F_TRAVEL_SPEED)
							* max(0.125, fhtHUnit:GetMovementDirectionStability())
					)
				local darkArtRange = darkArt:GetSpecialValueInt("abilitycastrange")
				darkArtRange = darkArtRange > 1000 and darkArtRange or darkArt:GetCastRange()
				local score, hitsBetter = ScoreLocs_StripHeroes( gsiPlayer, nearbyEnemies, darkArt,
						playerLoc, Vector((extrapolatedFht.x-playerLoc.x)*darkArtRange,
								(extrapolatedFht.y-playerLoc.y)*darkArtRange ), darkArtRadius,
						fht, 0.45, 0.75, 0.2, 1.0, S_O_F_TRAVEL_SPEED )

				if score > 0 and hitsBetter then
					DebugDrawLine(playerLoc, hitsBetter, 0, 255, 0)
					DebugDrawLine(playerLoc, extrapolatedFht, 255, 0, 0)
					if VEC_POINT_DISTANCE(playerLoc, hitsBetter) < darkArt:GetCastRange() then
						USE_ABILITY(gsiPlayer, darkArt, hitsBetter, 400, nil)
						return;
					end
				end
			end
			local danger, known, theory= Analytics_GetTheoreticalDangerAmount(gsiPlayer)
			if currentTask == push_handle and CAN_BE_CAST(gsiPlayer, darkArt)
					and danger < -1.5
					and #known == 0 and #theory == 0
					and gsiPlayer.lastSeenMana > highUse*max(1.33, (1.5 + danger*1.5)) then
				local nearbyEnemyCreepSet = Set_GetNearestEnemyCreepSetToLocation(playerLoc)
				if nearbyEnemyCreepSet and nearbyEnemyCreepSet.units[1] then
					local crowdedCenter, crowdedRating = CROWDED_RATING(nearbyEnemyCreepSet.center, SET_HERO_ENEMY)
					if crowdedRating > 2 and VEC_POINT_DISTANCE(playerLoc, crowdedCenter) then
						USE_ABILITY(gsiPlayer, darkArt, crowdedCenter, 400, nil)
						return;
					end
				end
			end
		end
		if arbitraryTarget and CAN_BE_CAST(gsiPlayer, darkPortrait) then
			local portraitHighScore = 0
			local portraitTarget
			for i=1,#nearbyEnemies do
				thisEnemy = nearbyEnemies[i]
				local thisScore = not thisEnemy.hUnit:IsNull()
						and sqrt(thisEnemy.lastSeenHealth)
								* sqrt(thisEnemy.hUnit:GetArmor())
								* thisEnemy:GetAttackDamage()
				if thisScore > portraitHighScore then
					portraitTarget = thisEnemy
					portraitHighScore = thisScore
				end
			end
			if portraitTarget and HIGH_USE(gsiPlayer, darkPortrait, highUse,
						portraitTarget.lastSeenHealth / portraitTarget.maxHealth
					) then
				USE_ABILITY(gsiPlayer, darkPortrait, portraitTarget, 400, nil)
				return;
			end
		end
	end,
}

local hero_access = function(key) return d[key] end

do
	HeroData_SetHeroData(hero_data, abilities, hero_access)
end


