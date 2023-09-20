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

-- require(GetScriptDirectory().."/lib_hero/item/item_communication")

ITEM_MAX_PLAYER_STORAGE = 16
ITEM_INVENTORY_AND_BACKPACK_STORAGE = 9
ITEM_MAX_COURIER_STORAGE = ITEM_INVENTORY_AND_BACKPACK_STORAGE

TPSCROLL_SLOT = 15
--NEUTRAL_ITEM_SLOT = 16

ITEM_END_INVENTORY_INDEX = 5
ITEM_END_BACKPACK_INDEX = 8
ITEM_END_STASH_INDEX = 14

ITEM_NAME_SEARCH_START = 6 -- "item_[.+]"

ITEM_HAVE_AGHS_SHARD_MYSTERIOUS = 114

ITEM_ARMLET_HEALTH_DRAIN_PER_SECOND = 45

ITEM_UPGRADES = {
	"item_abyssal_blade",
	"item_aeon_disk",
	"item_aether_lens",
	"item_ancient_janggo",
	"item_arcane_blink",
	"item_arcane_boots",
	"item_armlet",
	"item_assault",
	"item_basher",
	"item_bfury",
	"item_black_king_bar",
	"item_blade_mail",
	"item_bloodstone",
	"item_bloodthorn",
	"item_bracer",
	"item_buckler",
	"item_butterfly",
	"item_crimson_guard",
	"item_cyclone",
	"item_dagon",
	"item_desolator",
	"item_diffusal_blade",
	"item_dragon_lance",
	"item_echo_sabre",
	"item_eternal_shroud",
	"item_ethereal_blade",
	"item_falcon_blade",
	"item_force_staff",
	"item_glimmer_cape",
	"item_greater_crit",
	"item_guardian_greaves",
	"item_gungir",
	"item_hand_of_midas",
	"item_headdress",
	"item_heart",
	"item_heavens_halberd",
	"item_helm_of_the_dominator",
	"item_helm_of_the_overlord",
	"item_holy_locket",
	"item_hood_of_defiance", "item_hurricane_pike",
	"item_invis_sword",
	"item_kaya",
	"item_kaya_and_sange",
	"item_lesser_crit",
	"item_lotus_orb",
	"item_maelstrom",
	"item_mage_slayer",
	"item_manta",
	"item_mask_of_madness",
	"item_medallion_of_courage",
	"item_mekansm",
	"item_meteor_hammer",
	"item_mjollnir",
	"item_monkey_king_bar",
	"item_moon_shard",
	"item_null_talisman",
	"item_nullifier",
	"item_oblivion_staff",
	"item_octarine_core",
	"item_orb_of_corrosion",
	"item_orchid",
	"item_overwhelming_blink",
	"item_pers",
	"item_phase_boots",
	"item_pipe",
	"item_power_treads",
	"item_radiance",
	"item_rapier",
	"item_refresher",
	"item_ring_of_basilius",
	"item_rod_of_atos",
	"item_sange",
	"item_sange_and_yasha",
	"item_satanic",
	"item_sheepstick",
	"item_shivas_guard",
	"item_silver_edge",
	"item_skadi",
	"item_solar_crest",
	"item_soul_booster",
	"item_soul_ring",
	"item_sphere",
	"item_spirit_vessel",
	"item_swift_blink",
	"item_tranquil_boots",
	"item_travel_boots",
	"item_ultimate_scepter",
	"item_urn_of_shadows",
	"item_vanguard",
	"item_veil_of_discord",
	"item_vladmir",
	"item_wind_waker",
	"item_witch_blade",
	"item_wraith_band",
	"item_yasha",
	"item_yasha_and_kaya",
}

ITEMS_GOODIES = { -- While totally safe, at a few steps distance, the score of picking up functional items bought by a player.
	["item_rapier"] = 350,
	["item_gem"] = 180
}

ITEM_COOLDOWN = {
	["item_abyssal_blade"] = 35,
	["item_ancient_janggo"] = 30,
	["item_arcane_boots"] = 55,
	["item_black_king_bar"] = 70,
	["item_blade_mail"] = 25,
	["item_blink"] = 15,
	["item_bloodstone"] = 85,
	["item_bloodthorn"] = 15,
	["item_dagon"] = 35,
	["item_dagon_2"] = 35,
	["item_dagon_3"] = 35,
	["item_dagon_4"] = 35,
	["item_dagon_5"] = 35,
	["item_diffusal_blade"] = 15,
	["item_echo_sabre"] = 5,
	["item_etheral_blade"] = 20,
	["item_force_staff"] = 23,
	["item_glimmer_cape"] = 14,
	["item_guardian_greaves"] = 40,
	["item_hand_of_midas"] = 90,
	["item_heavens_halberd"] = 18,
	["item_helm_of_the_dominator"] = 45,
	["item_hood_of_defiance"] = 60,
	["item_hurricane_pike"] = 23,
	["item_manta"] = 45,
	["item_mask_of_madness"] = 16,
	["item_mekansm"] = 65,
	["item_meteor_hammer"] = 24,
	["item_necronomicon"] = 80,
	["item_necronomicon_2"] = 80,
	["item_necronomicon_3"] = 80,
	["item_nullifier"] = 11,
	["item_orchid"] = 18,
	["item_phase_boots"] = 8,
	["item_pipe"] = 60,
	["item_refresher"] = 160,
	["item_satanic"] = 35,
	["item_sheepstick"] = 22,
	["item_shivas_guard"] = 30,
	["item_silver_edge"] = 18,
	["item_solar_crest"] = 12,
	["item_soul_ring"] = 25,
	["item_sphere"] = 12,
	["item_tpscroll"] = 80,
	["item_urn_of_shadows"] = 7,
	["item_veil_of_discord"] = 25,
}

USABLE_ITEMS_FOR_INDEXING = {
	["item_abyssal_blade"] = "abyssalBlade",
	["item_ancient_janggo"] = "drums",
	["item_arcane_blink"] = "blink",
	["item_armlet"] = "armlet",
	["item_bfury"] = "hatchet",
	["item_black_king_bar"] = "bkb",
	["item_blade_mail"] = "bladeMail",
	["item_blink"] = "blink",
	["item_blood_grenade"] = "bloodGrenade",
	["item_bloodstone"] = "bloodstone",
	["item_bloodthorn"] = "bloodthorn",
	["item_bottle"] = "bottle",
	["item_branches"] = "branches",
	["item_buckler"] = "buckler",
	["item_cheese"] = "cheese",
	["item_crimson_guard"] = "crimsonGuard",
	["item_cyclone"] = "euls",
	["item_dagon"] = "dagon",
	["item_dagon_2"] = "dagon",
	["item_dagon_2L"] = "dagon",
	["item_dagon_3"] = "dagon",
	["item_dagon_3L"] = "dagon",
	["item_dagon_4"] = "dagon",
	["item_dagon_4L"] = "dagon",
	["item_dagon_5"] = "dagon",
	["item_dagon_5L"] = "dagon",
	["item_diffusal_blade"] = "diffusalBlade",
	["item_diffusal_blade_2"] = "diffusalBlade",
	["item_diffusal_blade_2L"] = "diffusalBlade",
	["item_disperser"] = "diffusalBlade",
	["item_dust"] = "dust",
	["item_eternal_shroud"] = "hood",
	["item_ethereal_blade"] = "etherealBlade",
	["item_force_staff"] = "forceStaff",
	["item_ghost"] = "ghostScepter",
	["item_glimmer_cape"] = "glimmerCape",
	["item_gungir"] = "gungir",
	["item_hand_of_midas"] = "midas",
	["item_harpoon"] = "harpoon",
	["item_heavens_halberd"] = "heavensHalberd",
	["item_helm_of_the_dominator"] = "hotd",
	["item_helm_of_the_overlord"] = "hoto",
	["item_hood_of_defiance"] = "hood",
	["item_hurricane_pike"] = "forceStaff",
	["item_invis_sword"] = "shadowBlade",
	["item_lotus_orb"] = "lotusOrb",
	["item_manta"] = "manta",
	["item_mask_of_madness"] = "mom",
	["item_medallion_of_courage"] = "medallion",
	["item_meteor_hammer"] = "meteorHammer",
	["item_mjollnir"] = "mjollnir",
	["item_moon_shard"] = "moonShard",
	["item_necronomicon"] = "necronomicon",
	["item_nullifier"] = "nullifier",
	["item_orchid"] = "orchid",
	["item_overwhelming_blink"] = "blink",
	["item_pavise"] = "pavise",
	["item_phase_boots"] = "phaseBoots",
	["item_pipe"] = "pipe",
	["item_power_treads"] = "powerTreads",
	["item_quelling_blade"] = "hatchet",
	["item_radiance"] = "radiance",
	["item_refresher"] = "refresher",
	["item_refresher_shard"] = "refresherShard",
	["item_rod_of_atos"] = "rodOfAtos",
	["item_satanic"] = "satanic",
	["item_shadow_amulet"] = "shadowAmulet",
	["item_sheepstick"] = "sheepstick",
	["item_shivas_guard"] = "shivas",
	["item_silver_edge"] = "shadowBlade",
	["item_solar_crest"] = "medallion",
	["item_soul_ring"] = "soulRing",
	["item_sphere"] = "linkens",
	["item_spirit_vessel"] = "urn",
	["item_swift_blink"] = "blink",
	["item_urn_of_shadows"] = "urn",
	["item_veil_of_discord"] = "veil",
	["item_ward_dispenser"] = "wards",
	["item_ward_observer"] = "wards",
	["item_ward_sentry"] = "wards",
	["item_wind_waker"] = "euls",
}

INVIS_ITEMS = {
	"item_glimmer",
	"item_invis_sword",
	"item_shadow_amulet",
	"item_silver_edge"
}

ITEMS_BOOTS = {
	["item_boots"] = true,
	["item_phase_boots"] = true,
	["item_arcane_boots"] = true,
	["item_guardian_greaves"] = true,
	["item_tranquil_boots"] = true,
	["item_tranquil_boots2"] = true,
	["item_travel_boots"] = true,
	["item_travel_boots_2"] = true,
	["item_boots_of_bearing"] = true,
	["item_power_treads"] = true
}

ITEM_WAVE_CLEAR_NOT_ATTACK = {
	["item_radiance"] = true,
	["item_meteor_hammer"] = true,
	["item_assault"] = true,
}

ITEM_WAVE_CLEAR_ATTACK = {
	["item_gungir"] = true,
	["item_maelstrom"] = true,
	["item_mjollnir"] = true,
	["item_bfury"] = true
}

ITEMS_JUNGLE = {
	["item_tier1_token"] = 1,
	["item_tier2_token"] = 2,
	["item_tier3_token"] = 3,
	["item_tier4_token"] = 4,
	["item_tier5_token"] = 5,
	["item_keen_optic"] = 1,
	["item_grove_bow"] = 2,
	["item_quickening_charm"] = 3,
	["item_black_powder_bag"] = 3, -- Blast Rig
	["item_philosophers_stone"] = 2,
	["item_dagger_of_ristul"] = 2, -- Dagger of Ristul
	["item_specialists_array"] = 2, -- Specialist's Array
	["item_force_boots"] = 5,
	["item_desolator_2"] = 5, -- Stygian Desolator
	["item_seer_stone"] = 5,
	["item_greater_mango"] = 1,
	["item_elixer_healing"] = 1,
	["item_vampire_fangs"] = 1,
	["item_craggy_coat"] = 1,
	["item_timeless_relic"] = 4,
	["item_mirror_shield"] = 5,
	["item_ironwood_tree"] = 1,
	["item_royal_jelly"] = 1,
	["item_pupils_gift"] = 2,
	["item_repair_kit"] = 1,
	["item_mind_breaker"] = 3,
	["item_third_eye"] = 1,
	["item_spell_prism"] = 4,
	["item_horizon"] = 1,
	["item_bullwhip"] = 2,
	["item_princes_knife"] = 1,
	["item_spider_legs"] = 1,
	["item_helm_of_the_undying"] = 1,
	["item_mango_tree"] = 1,
	["item_imp_claw"] = 1,
	["item_flicker"] = 4,
	["item_spy_gadget"] = 1,
	["item_ocean_heart"] = 1,
	["item_broom_handle"] = 1,
	["item_trusty_shovel"] = 1,
	["item_nether_shawl"] = 2,
	["item_dragon_scale"] = 2,
	["item_essence_ring"] = 1,
	["item_clumsy_net"] = 1,
	["item_enchanted_quiver"] = 3,
	["item_ninja_gear"] = 4,
	["item_spy_gadget"] = 4, -- Telescope
	["item_illusionsts_cape"] = 1, -- as spelt
	["item_havoc_hammer"] = 4,
	["item_panic_button"] = 1,
	["item_apex"] = 5,
	["item_demonicon"] = 5, -- Book of the Dead
	["item_ballista"] = 1,
	["item_woodland_striders"] = 1,
	["item_trident"] = 1,
	["item_fallen_sky"] = 5,
	["item_force_field"] = 5, -- Arcanist's Armor
	["item_pirate_hat"] = 5, -- Pirate Hat
	["item_ex_machina"] = 5, -- Ex Machina
	["item_giants_ring"] = 5, -- Giant's Ring
	["item_book_of_shadows"] = 5, -- Book of Shadows
	["item_heavy_blade"] = 5, -- Witchbane
	["item_pirate_hat"] = 5,
	["item_dimentional_doorway"] = 1,
	["item_faded_broach"] = 1,
	["item_paladin_sword"] = 3,
	["item_minotaur_horn"] = 1,
	["item_orb_of_destruction"] = 1,
	["item_the_leveller"] = 1,
	["item_titan_sliver"] = 3,
	["item_chipped_vest"] = 1,
	["item_wizard_glass"] = 1,
	["item_gloves_of_travel"] = 1,
	["item_sorcerers_staff"] = 1,
	["item_ceremonial_robe"] = 3, -- Ceremonial Robe
	["item_psychic_headband"] = 3, -- Psychic Headband
	["item_ogre_seal_totem"] = 3, -- Ogre Seal Totem
	["item_elven_tunic"] = 3,
	["item_cloak_of_flames"] = 3,
	["item_venom_gland"] = 1,
	["item_trickster_cloak"] = 4,
	["item_gladiator_helm"] = 1,
	["item_possessed_mask"] = 1,
	["item_force_field"] = 1,
	["item_force_boots"] = 5, -- Force Boots
	["item_black_powder_bag"] = 1,
	["item_ascetic_cap"] = 4,
	["item_pogo_stick"] = 1, -- Tumbler's Toy
	["item_seeds_of_serenity"] = 1,
	["item_lance_of_pursuit"] = 1,
	["item_occult_bracelet"] = 1, -- Occult Bracelet
	["item_paintball"] = 1,
	["item_heavy_blade"] = 1,
	["item_unstable_wand"] = 1, -- Pig Pole
	["item_misericorde"] = 1,
	["item_ancient_perseverance"] = 1,
	["item_oakheart"] = 1,
	["item_stormcrafter"] = 4,
	["item_overflowing_elixir"] = 1,
	["item_mysterious_hat"] = 1, -- Fairy's Trinket
	["item_satchel"] = 1,
	["item_star_mace"] = 1,
	["item_penta_edged_sword"] = 4,
	["item_vambrace"] = 2,
	["item_misericorde"] = 2, -- Brigand's Blade
	["item_eye_of_the_vizier"] = 2, -- Eye of the Vizier
	["item_witless_shako"] = 1,
	["item_ring_of_aquila"] = 2,
	["item_lance_of_pursuit"] = 1,
}

ITEM_POWER_TREADS_STATE_STAT = {
	[0] = ATTRIBUTE_STRENGTH,
	[1] = ATTRIBUTE_INTELLECT,
	[2] = ATTRIBUTE_AGILITY
}

require(GetScriptDirectory().."/lib_hero/item/item_logic")

local ITEM_MAX_PLAYER_STORAGE = ITEM_MAX_PLAYER_STORAGE
local ITEM_INVENTORY_AND_BACKPACK_STORAGE = ITEM_INVENTORY_AND_BACKPACK_STORAGE
local ITEM_MAX_COURIER_STORAGE = ITEM_INVENTORY_AND_BACKPACK_STORAGE

local TPSCROLL_SLOT = TPSCROLL_SLOT
local NEUTRAL_ITEM_SLOT = NEUTRAL_ITEM_SLOT

local ITEM_END_INVENTORY_INDEX = ITEM_END_BACKPACK_INDEX
local ITEM_END_BACKPACK_INDEX = ITEM_END_BACKPACK_INDEX
local ITEM_END_STASH_INDEX = ITEM_END_STASH_INDEX

local ITEM_NAME_SEARCH_START = ITEM_NAME_SEARCH_START

local DEFAULT_ITEM_EXISTS_PNOT = 1

local ITEM_COOLDOWN = ITEM_COOLDOWN
local Math_GetRandStandardDeviation = Math_GetRandStandardDeviation

-- TODO complete / automate value determination
ITEM_DEFINES = {
	["BLINK_DISTANCE"] = 1200
}

local t_inventory = {} -- 
local t_enemy_last_seen_inventory = {}

do
	for i=1,ENEMY_TEAM_NUMBER_OF_PLAYERS do
		t_enemy_last_seen_inventory[i] = {}
	end
end

function Item_Initialize()
	ItemComms_Initialize()
	Item_Initialize = nil
end

function Item_UpdateKnownInventory(gsiEnemy)
	local pnot = gsiEnemy.nOnTeam
	local hUnit = gsiEnemy.hUnit
	local thisEnemyInventory = t_enemy_last_seen_inventory[pnot]
	for i=0,ITEM_END_BACKPACK_INDEX do
		local thisSlotItem = hUnit:GetItemInSlot(i)
		if thisSlotItem and not thisEnemyInventory[thisSlotItem:GetName()] then
			-- Create this new item
			local newItemKnownTable = {}
			-- Delete old components for the item
			-- - destructive to non-active use compnoents, but they aren't tracked for cooldowns anyways.
			local itemComponents = GetItemComponents(thisSlotItem:GetName())
			local checkCooldownGuessed = true
			for i=1,#itemComponents do
				local component = itemComponents[i]
				if thisEnemyInventory[component] then
					local cooldownGuessed = thisEnemyInventory[component][DEFAULT_ITEM_EXISTS_PNOT]
					if checkCooldownGuessed and cooldownGuessed > 0 then
						for pnot=1,TEAM_NUMBER_OF_PLAYERS do
							newItemKnownTable[pnot] = thisEnemyInventory[component][pnot]
						end
					end
				end
				thisEnemyInventory[component] = nil -- TODO no reason not to use recycling
			end
		end
	end
end

function Item_UpdateKnownCooldown(gsiEnemy, hItem)
	local pnot = gsiEnemy.nOnTeam
	local storedCooldownTime = ITEM_COOLDOWN[hItem:GetName()]
	if storedCooldownTime then
		local playerItemTable = t_enemy_last_seen_inventory[pnot][hItem:GetName()]
		if not playerItemTable then
			local thisEnemyInventory = t_enemy_last_seen_inventory[pnot]
			local thisEnemyInventoryItem = {}
			for i=1,TEAM_NUMBER_OF_PLAYERS do
				thisEnemyInventoryItem[i] = 0
			end
			thisEnemyInventory[hItem:GetName()] = thisEnemyInventoryItem
		end
	end
end

require(GetScriptDirectory().."/lib_hero/item/item_communication")
