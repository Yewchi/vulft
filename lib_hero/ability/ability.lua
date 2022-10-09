-- As gsiPlayer is to hPlayerUnit, gsiAbility is to a set of hAbilities, usually 1. This gives: Bane may hold a gsiAbility
--- to abilities={"brai" for nuking heroes. 
MAX_ABILITY_SLOT = 23

ABILITY_I__ABILITY_NAME = 1
ABILITY_I__ABILITY_BIT_FLAGS = 2
ABILITY_I__H_ABILITY = 3
ABILITY_I__ADDITIONAL_FLAGS = 4

TOTAL_TALENT_CHOICES = 8

require(GetScriptDirectory().."/lib_hero/ability/ability_logic")
require(GetScriptDirectory().."/lib_hero/ability/charge_cooldown_tracking")
require(GetScriptDirectory().."/lib_hero/ability/ability_generics")

local t_skill_build_previous_ability_points_avail = {} -- used frame to frame to confirm we can step to the next skill

local I_SKILL_BUILD_RESOLVED = 0

local t_player_skill_build = {} -- {0, 1, 2, 0, 1, 5, ..., 5, 8, 10}
local t_player_ability_name_indices = {} -- {"Flux", "Magnetic Field",...,"+12s Tempest Double Duration"}
local t_player_abilities = {}
local t_enemy_skill_build = {}
local t_enemy_ability_name_indices = {}
local t_enemy_abilities = {}

local t_enemy_ability_cooldown = {} -- Idea would be to process discrete data with inaccuracies and another layer of bot-brain-memory. The conclusion of the idea is a simulated communication channel between the bots, which may incorporate personalities and randomized "how-im-feeling-todays", to essentially randomize when they may or may not behave engage in behaviours that players engage in by saying and responding to statements like "Queen of Pain ulti [approximately] off cd, care."

local job_domain

-- O(n^2)  (init only, each bot)
local function resolve_skill_build_string_indices_to_slot_build(gsiPlayer)
	if t_player_ability_name_indices[gsiPlayer.nOnTeam][1] == "" then return false end -- skill build is from default
	local hUnit = gsiPlayer.hUnit
	local playerSkillBuild = t_player_skill_build[gsiPlayer.nOnTeam]
	local playerAbilityNameIndices = t_player_ability_name_indices[gsiPlayer.nOnTeam]
	local abilityNameIndexToDotaSlot = {}
	local numFound = 0
	local specialBonusIndex = HIGH_32_BIT
	local checkSpecialBonus = false
	local n=1

	if playerSkillBuild[I_SKILL_BUILD_RESOLVED] then
		return true -- The hero must've been selected twice for some reason
	end
	-- Check regular abilities
	while(n<=#playerAbilityNameIndices) do -- iterate all abilities/talents that have been selected for the skill build
		if not checkSpecialBonus then
			local abilityName = playerAbilityNameIndices[n]
			if VERBOSE then VEBUG_print(string.format("ability: (resolve) searching for \"%s\"", abilityName)) end
			local iHighestMatch = -1
			local highestMatchingScore = 0
			local highestMatchingName = nil
			for i=0,math.min(MAX_ABILITY_SLOT,specialBonusIndex),1 do -- iterate the named abilities/slot
				local thisAbility = hUnit:GetAbilityInSlot(i)
				if AbilityLogic_IsLikelyAbilityPointInvestibleType(thisAbility) then
					if specialBonusIndex > MAX_ABILITY_SLOT and 
							(thisAbility:GetName()):find("special_bonus") then
						specialBonusIndex = i
						break
					end
					local thisScore = 
							String_CompareAbilityStringToBuiltIn(
								abilityName, 
								thisAbility:GetName()
							)
					if thisScore > highestMatchingScore then -- set the highest matching string score
						iHighestMatch = i
						highestMatchingScore = thisScore
						highestMatchingName = abilityName
					end
				end
			end
			if highestMatchingName == nil then return false end
			abilityNameIndexToDotaSlot[n] = iHighestMatch -- save the true InSlot# -> (readable) AbilityName
			numFound = numFound + 1
			if numFound == 4 or gsiPlayer.shortName == "invoker" and numFound == 3 then -- MAGIC_INVOKER
				n = n + 1
				break
			end
		end
		n = n + 1
	end
	local endSpecialBonus = specialBonusIndex+7
	if not playerAbilityNameIndices[n+7] or not hUnit:GetAbilityInSlot(endSpecialBonus) then 
		WARN_print("[ability]: name index or ability slot out-of-bounds.") 
		return 
	end
	while(specialBonusIndex<endSpecialBonus+7) do
		abilityNameIndexToDotaSlot[n] = specialBonusIndex
		abilityNameIndexToDotaSlot[n+1] = specialBonusIndex+1
		n = n+2; specialBonusIndex = specialBonusIndex+2
		-- local abilityName1 = playerAbilityNameIndices[n]
		-- local abilityName2 = playerAbilityNameIndices[n+1]
		-- if not abilityName2 or not hUnit:GetAbilityInSlot(specialBonusIndex+1) then break end
		-- local talentOne = hUnit:GetAbilityInSlot(specialBonusIndex):GetName()
		-- local talentTwo = hUnit:GetAbilityInSlot(specialBonusIndex+1):GetName()
		-- print(specialBonusIndex, talentOne, specialBonusIndex+1, talentTwo)
		-- print("Check 1", abilityName1)
		-- local indexOffset1, winningSearchKey1 = 
				-- String_CompareTalentStringToBuiltInTier(abilityName1, talentOne, talentTwo)
		-- print("Check 2", abilityName2)
		-- local indexOffset2, winningSearchKey2 =
				-- String_CompareTalentStringToBuiltInTier(abilityName2, talentOne, talentTwo)
		-- print("", "is", indexOffset1, winningSearchKey1, indexOffset2, winningSearchKey2)
		-- abilityNameIndexToDotaSlot[n] = specialBonusIndex+indexOffset1
		-- abilityNameIndexToDotaSlot[n+1] = specialBonusIndex+indexOffset2
		-- specialBonusIndex = specialBonusIndex + 2
		-- n = n + 2
	end
	for i=1,#playerSkillBuild,1 do 	-- allocate the dota ability slots to our name indicies skill build
		playerSkillBuild[i] = abilityNameIndexToDotaSlot[playerSkillBuild[i]]
	end
	playerSkillBuild[I_SKILL_BUILD_RESOLVED] = true
	return true
end

function Ability_HandleAbilityUpgrades(gsiPlayer) -- TODO Locks ability points if next skill up in build is the same-tier opposite talent already chosen.
--if GetBot():GetPlayerID() == 3 then print(GetBot():GetAbilityInSlot(6):GetName()) end
	if gsiPlayer.hUnit:GetAbilityPoints() > 0 then
		AbilityLogic_HandleLevelAbility(gsiPlayer, t_player_skill_build[gsiPlayer.nOnTeam])
	end
end

function Ability_PassPlayerAbilityData(gsiPlayer, skillBuild, abilityNameIndices, abilities)
	-- store data
	--print("PRELOAD", Util_PrintableTable(skillBuild), Util_PrintableTable(abilityNameIndices), Util_PrintableTable(abilities))
	local pnot = gsiPlayer.nOnTeam
	if gsiPlayer.team == TEAM then
		-- load to local tbls
		t_player_skill_build[pnot] = skillBuild -- reformated below
		t_player_ability_name_indices[pnot] = abilityNameIndices -- the reformat search key indices
		t_player_abilities[pnot] = abilities
		-- Resolve Lua-Array string indices to Dota ability slot#s.
		resolve_skill_build_string_indices_to_slot_build(gsiPlayer)
		-- Confirm skill build validity (will attempt fix); set starting build index (i.e. for reloads)
		AbilityLogic_TryConfirmValidSkillBuild(gsiPlayer, t_player_skill_build)
		AbilityLogic_SetCurrentSkillBuildIndex(gsiPlayer, t_player_skill_build)
		AbilityLogic_UpdateSnapshotFindLeveled(gsiPlayer, true)
	else
		-- load to local tbls
		t_enemy_skill_build[pnot] = skillBuild
		t_enemy_ability_name_indices[pnot] = abilityNameIndices
		t_enemy_abilities[pnot] = abilities
		local responseNeeds = HeroData_RequestHeroKeyValue(gsiPlayer.shortName, "ResponseNeeds")
		if responseNeeds then
			FightClimate_RegisterResponseType(t_enemy_abilities, {responseNeeds()})
		end
	end

	-- Load abilities into ABILITY_TYPE bitflag tables for fast get stun, slow, degen, passive, heal, etc
	local iAbility = 0
	while (iAbility < MAX_ABILITY_SLOT) do
		local abilityData = abilities[iAbility]
		if abilityData then
			-- Load to AbilityLogic
			AbilityLogic_LoadAbilityToPlayer(gsiPlayer, abilities[iAbility])
			-- Inform FightModerate of the ability for initation scores
			FightModerate_InformAbilityForInitiationScores(gsiPlayer, abilities[iAbility]) 
		end
		iAbility = iAbility + 1
	end
end

function Ability_GetSkillBuildTable()
	return t_player_skill_build
end
