local hero_data = {
	"techies",
	{1, 3, 1, 3, 1, 4, 1, 3, 3, 5, 2, 4, 2, 2, 7, 2, 4, 10},
	{
		"item_branches","item_magic_stick","item_tango","item_circlet","item_branches","item_branches","item_ward_observer","item_magic_wand","item_boots","item_arcane_boots","item_wind_lace","item_cloak","item_glimmer_cape","item_wraith_band","item_headdress","item_chainmail","item_mekansm","item_belt_of_strength","item_robe","item_ancient_janggo","item_guardian_greaves","item_gem","item_lotus_orb",
	},
	{ {3,3,3,5,5,}, {4,4,4,4,4,}, 0.1 },
	{
		"Sticky Bomb","Reactive Tazer","Blast Off!","Proximity Mines","+20% Magic Resistance","-3s Proximity Mines Cooldown","+200 Blast Off! Damage","+3 Mana Regen","+125 Sticky Bomb Latch/Explosion Radius","-15s Blast Off! Cooldown","+252 Damage","-0.8s Proximity Mines Activation Delay",
	}
}
--@EndAutomatedHeroData
-- it can be assumed why I'm using techies as a placeholder copy-paste template
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

		local nearbyEnemies, outerEnemies = NEARBY_OUTER(gsiPlayer.lastSeen.location, RESONANT_PULSE_RADIUS_HITS, d.AstralStepRange(gsiPlayer)+50)

		HANDLE_AUTOCAST_GENERIC(gsiPlayer, poisonAttack)
		
		if currentActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION then
			if CAN_BE_CAST(gsiPlayer, nethertoxin) and HIGH_USE(gsiPlayer, nethertoxing, highUse, fhtHpp) then
				local crowdingCenter, crowdedRating = CROWDED_RATING(fht.lastSeen.location, SET_HERO_ENEMY)
				if crowdedRating > 1.75 then
					USE_ABILITY(gsiPlayer, nethertoxin, crowdingCenter, 400, nil)
					return;
				end
			end
		elseif currentActivityType > ACTIVITY_TYPE.CAREFUL then

		end
	end,
}

local hero_access = function(key) return d[key] end

do
	HeroData_SetHeroData(hero_data, abilities, hero_access)
end
