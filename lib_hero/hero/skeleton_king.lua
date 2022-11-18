local hero_data = {
	"skeleton_king",
	{1, 2, 2, 3, 2, 4, 2, 3, 3, 3, 1, 4, 1, 1, 7, 5, 4, 9, 11},
	{
		"item_gauntlets","item_magic_stick","item_quelling_blade","item_branches","item_enchanted_mango","item_bracer","item_boots","item_magic_wand","item_chainmail","item_blades_of_attack","item_phase_boots","item_gloves","item_helm_of_iron_will","item_armlet","item_mithril_hammer","item_ogre_axe","item_black_king_bar","item_relic","item_radiance","item_blink","item_overwhelming_blink","item_buckler","item_assault","item_staff_of_wizardry","item_ogre_axe","item_blade_of_alacrity","item_point_booster","item_ultimate_scepter","item_refresher",
	},
	{ {1,1,1,1,2,}, {1,1,1,1,2,}, 0.1 },
	{
		"Wraithfire Blast","Vampiric Spirit","Mortal Strike","Reincarnation","+8% Vampiric Spirit Lifesteal","-25%% Summon Skeleton Duration/-25%% Cooldown","+0.7s Wraithfire Blast Stun Duration","+26 Skeletons Attack Damage","+25% Cleave","+6 Minimum Skeletons Spawned","-2.0s Mortal Strike Cooldown","Reincarnation Casts Wraithfire Blast",
	}
}
--@EndAutomatedHeroData
if GetGameState() <= GAME_STATE_HERO_SELECTION then return hero_data end

local abilities = {
		[0] = {"skeleton_king_hellfire_blast", ABILITY_TYPE.STUN, ABILITY_TYPE.NUKE},
		{"skeleton_king_vampiric_aura", ABILITY_TYPE.PASSIVE, ABILITY_TYPE.SUMMON},
		{"skeleton_king_mortal_strike", ABILITY_TYPE.PASSIVE},
		[5] = {"skeleton_king_reincarnation", ABILITY_TYPE.PASSIVE},
}

local ZEROED_VECTOR = ZEROED_VECTOR
local playerRadius = Set_GetEnemyHeroesInPlayerRadius
local ENCASED_IN_RECT = Set_GetEnemiesInRectangle
local currentTask = Task_GetCurrentTaskHandle
local GSI_AbilityCanBeCast = GSI_AbilityCanBeCast
local USE_ABILITY = UseAbility_RegisterAbilityUseAndLockToScore
local INCENTIVISE = Task_IncentiviseTask
local VEC_UNIT_DIRECTIONAL = Vector_UnitDirectionalPointToPoint
local ACTIVITY_TYPE = ACTIVITY_TYPE
local currentActivityType = Blueprint_GetCurrentTaskActivityType
local currentTask = Task_GetCurrentTaskHandle
local HIGH_USE = AbilityLogic_HighUseAllowOffensive

local fight_harass_handle = FightHarass_GetTaskHandle()
local push_handle = Push_GetTaskHandle()

local t_player_abilities = {}

local ABILITY_USE_RANGE = 800
local OUTER_RANGE = 1600

local d = {
	["ReponseNeeds"] = function()
		return nil, REASPONSE_TYPE_DISPEL, nil, {RESPONSE_TYPE_KNOCKBACK, 4}
	end,
	["Initialize"] = function(gsiPlayer)
		AbilityLogic_CreatePlayerAbilitiesIndex(t_player_abilities, gsiPlayer, abilities)
		AbilityLogic_UpdateHighUseMana(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam])
		gsiPlayer.powLevelModifier = function(gsiPlayer, powerLevel)
				local rez = gsiPlayer.hUnit:GetAbilityInSlot(5)
				if rez and rez:IsKnown() then
					if rez:IsCooldownAvailable() and gsiPlayer.lastSeenMana > rez:GetManaCost() then
						local inverseHealthPower = (1.33-(gsiPlayer.lastSeenHealth/gsiPlayer.maxHealth))
						INCENTIVISE(gsiPlayer, fight_harass_handle, inverseHealthPower*70, 15)
						return powerLevel*inverseHealthPower
					end
				end
			end
		return
	end,
	["InformLevelUpSuccess"] = function(gsiPlayer)
		AbilityLogic_UpdateHighUseMana(gsiPlayer, t_player_abilities[gsiPlayer.nOnTeam])
	end,
	["AbilityThink"] = function(gsiPlayer) 
		if UseAbility_IsPlayerLocked(gsiPlayer) then
			return;
		end
		local playerAbilities = t_player_abilities[gsiPlayer.nOnTeam]
		local hellfireBlast = playerAbilities[1]
		local vampiricAura = playerAbilities[2]
		local reincarnation = playerAbilities[4]
		local highUse = gsiPlayer.highUseManaSimple
		local playerHealthPercent = gsiPlayer.lastSeenHealth / gsiPlayer.maxHealth

		local currActivityType = currentActivityType(gsiPlayer)
		local currTask = currentTask(gsiPlayer)
		local nearbyEnemies, outerEnemies
				= Set_GetEnemyHeroesInLocRadOuter(gsiPlayer.lastSeen.location, ABILITY_USE_RANGE, OUTER_RANGE, 6)
		local fightHarassTarget = Task_GetTaskObjective(gsiPlayer, fight_harass_handle)
		local fhtPercHp = fightHarassTarget and fightHarassTarget.lastSeenHealth / fightHarassTarget.maxHealth or 1.0
		local reincarnationCost = reincarnation:GetManaCost()
		local rezSeemsNeeded
		if gsiPlayer.theorizedDanger then
			if not nearbyEnemies[2] and not outerEnemies[1] and gsiPlayer.theorizedDanger < 0.5 then
				rezSeemsNeeded = false
			else
				rezSeemsNeeded = min(0.33, playerHealthPercent) * min(-gsiPlayer.theorizedDanger, 0.2)
			end
		else
			rezSeemsNeeded = playerHealthPercent < 0.45
		end
		if currActivityType <= ACTIVITY_TYPE.CONTROLLED_AGGRESSION
				and AbilityLogic_AbilityCanBeCast(gsiPlayer, hellfireBlast)
				and (not rezSeemsNeeded or gsiPlayer.lastSeenMana - hellfireBlast:GetManaCost() > reincarnationCost)
				and HIGH_USE(gsiPlayer, hellfireBlast, highUse - hellfireBlast:GetManaCost(), fhtPercHp) then
			USE_ABILITY(gsiPlayer, hellfireBlast, fightHarassTarget, 400, nil)
			return;
		end
		if currTask == push_handle and not nearbyEnemies[1] and not outerEnemies[1] then
			if AbilityLogic_AbilityCanBeCast(gsiPlayer, hellfireBlast)
					and (not rezSeemsNeeded or gsiPlayer.lastSeenMana - vampiricAura:GetManaCost() > reincarnationCost)
					and HIGH_USE(gsiPlayer, vampiricAura, highUse - vampiricAura:GetManaCost(), 1.0) then
				USE_ABILITY(gsiPlayer, vampiricAura, nil, 400, nil)
				return;
			end
		elseif currActivityType > ACTIVITY_TYPE.CAREFUL
				and nearbyEnemies[1] and AbilityLogic_AbilityCanBeCast(gsiPlayer, hellfireBlast)
				and (not rezSeemsNeeded or gsiPlayer.lastSeenMana - hellfireBlast:GetManaCost() > reincarnationCost)
				and HIGH_USE(
								gsiPlayer, hellfireBlast, highUse - hellfireBlast:GetManaCost(), playerHealthPercent
							) then
			USE_ABILITY(gsiPlayer, hellfireBlast, fightHarassTarget, 400, nil)
			return;
		end
	end,
}

local hero_access = function(key) return d[key] end

do
	HeroData_SetHeroData(hero_data, abilities, hero_access)
end
